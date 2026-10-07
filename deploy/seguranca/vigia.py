#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Vigia de segurança do servidor gc_turnkey.

Corre de 10 em 10 minutos (timer do systemd, como root) e procura sinais de
invasão ou de descuido no servidor. SÓ LÊ: não altera nada no sistema, não
apaga, não bloqueia, não envia dados para fora (o único envio é o aviso
opcional por Telegram, se o configurares).

Como é "inteligente":
  1. Aprende o que é NORMAL neste servidor (quem entra por SSH e de onde, que
     portas estão abertas, que contentores correm, que chaves SSH e tarefas
     agendadas existem, que ficheiros tem a app…) e avisa do que MUDA.
  2. Tem regras duras para o que nunca é normal (mineradores de criptomoedas,
     programas a correr a partir de /tmp, 2.º utilizador root, ficheiros da app
     alterados sem atualização…).
  3. Liga os pontos: uma chave SSH nova + um login de um sítio novo, ou muitas
     tentativas falhadas seguidas de um acesso, sobem para "possível intrusão".
  4. Explica em português simples o que significa e o que fazer.

Resultado: <data>/seguranca_vigia.json (lido pela app: Configurações →
Segurança e backups) e, se configurado, aviso imediato no Telegram.

Uso:
  vigia.py                 uma ronda (o que estiver "a horas" de correr)
  vigia.py --tudo          força todas as verificações já
  vigia.py aceitar         "o estado atual é o normal" (aprende tudo de novo)
  vigia.py estado          mostra o último resultado
  vigia.py --simular F.json   usa factos de um ficheiro (testes/demonstração)
Só biblioteca padrão do Python 3 (Debian já traz).
"""
import argparse
import hashlib
import ipaddress
import json
import os
import re
import sqlite3
import subprocess
import sys
import time
import urllib.parse
import urllib.request

VERSAO_VIGIA = 1

GRAV_PESO = {'critico': 40, 'atencao': 10, 'info': 1}
JANELA_HIST = 7 * 86400          # quanto tempo se guardam eventos (7 dias)
MAX_EVENTOS = 20000

# --- listas de "nunca é normal" ------------------------------------------------
NOMES_MALWARE = {
    'xmrig', 'xmr-stak', 'minerd', 'cpuminer', 'cpuminer-multi', 'ccminer',
    'nanominer', 't-rex', 'lolminer', 'phoenixminer', 'ethminer', 'kdevtmpfsi',
    'kinsing', 'kthreaddi', 'sysupdate', 'networkservice', 'dbused', 'solr.sh',
    'watchbog', 'rkhunter-fake', 'minergate', 'bfgminer', 'cgminer', 'sgminer',
}
PORTAS_MINERACAO = {3333, 4444, 5555, 7777, 14433, 14444, 45700, 9999}
PASTAS_SUSPEITAS = ('/tmp/', '/var/tmp/', '/dev/shm/', '/run/shm/')
# programas que podem usar muito CPU durante muito tempo sem ser nada de mal
CPU_PERMITIDOS = {
    'ffmpeg', 'immich', 'postgres', 'rclone', 'tar', 'gzip', 'zip', 'unzip',
    'apt', 'apt-get', 'dpkg', 'unattended-upgr', 'dockerd', 'containerd',
    'node', 'python3', 'python', 'pocketbase', 'machine-learning', 'java',
    'redis-server', 'mariadbd', 'mysqld', 'tailscaled', 'sha256sum', 'find',
}
# padrões de comandos que quase só se veem em ataques (procurados em cron,
# unidades systemd e ficheiros de arranque; nunca se guarda nem mostra o texto)
PADROES_SUSPEITOS = [
    (re.compile(r'(curl|wget)[^|\n]*\|\s*(ba|z)?sh', re.I), 'descarrega e executa um programa da internet'),
    (re.compile(r'base64\s+(-d|--decode)', re.I), 'esconde comandos em base64'),
    (re.compile(r'/dev/tcp/', re.I), 'abre uma ligação de rede à mão'),
    (re.compile(r'\bnc(at)?\b[^\n]*\s-(e|c)\b', re.I), 'dá uma consola remota (netcat)'),
    (re.compile(r'(/tmp/|/dev/shm/|/var/tmp/)\S+', re.I), 'executa algo a partir de uma pasta temporária'),
    (re.compile(r'\b(xmrig|minerd|cpuminer|kinsing|kdevtmpfsi)\b', re.I), 'menciona um minerador de criptomoedas'),
    (re.compile(r'chmod\s+\+?[0-7]*[sx7]+[^\n]*\s/(tmp|dev/shm)', re.I), 'torna executável um ficheiro temporário'),
]
LIMITE_IP_FALHAS = 10             # falhas de SSH de um IP (24 h) que já é ataque
LIMITE_FALHAS_JANELA = 30         # falhas de SSH numa ronda (10 min) que já é invulgar
LIMITE_AUTH_APP = 25              # falhas de login na app numa ronda


# =============================================================================
# utilitários
# =============================================================================
def sh(cmd, timeout=25):
    """Corre um comando só de leitura e devolve o texto; nunca lança erro."""
    try:
        r = subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout, errors='replace'
        )
        return r.stdout or ''
    except Exception:
        return ''


def ler(caminho, limite=3_000_000):
    try:
        with open(caminho, 'rb') as f:
            return f.read(limite).decode('utf-8', 'replace')
    except Exception:
        return ''


def sha(texto):
    if isinstance(texto, str):
        texto = texto.encode('utf-8', 'replace')
    return hashlib.sha256(texto).hexdigest()


def sha_ficheiro(caminho):
    try:
        h = hashlib.sha256()
        with open(caminho, 'rb') as f:
            for bloco in iter(lambda: f.read(1 << 20), b''):
                h.update(bloco)
        return h.hexdigest()
    except Exception:
        return ''


def classe_ip(s):
    """loopback | tailscale | privado | publico | desconhecido."""
    try:
        ip = ipaddress.ip_address(str(s).strip('[]').split('%')[0])
    except Exception:
        return 'desconhecido'
    if ip.is_loopback:
        return 'loopback'
    if ip.version == 4 and ip in ipaddress.ip_network('100.64.0.0/10'):
        return 'tailscale'
    if ip.version == 6 and ip in ipaddress.ip_network('fd7a:115c:a1e0::/48'):
        return 'tailscale'
    if ip.is_private or ip.is_link_local:
        return 'privado'
    return 'publico'


def ip_permitido(ip, permitidos):
    try:
        a = ipaddress.ip_address(ip)
    except Exception:
        return False
    for p in permitidos or []:
        try:
            if a in ipaddress.ip_network(p, strict=False):
                return True
        except Exception:
            continue
    return False


ORIGENS = [
    # prefixo do id -> verificação que o (re)avalia
    (('utilizadores:', 'utilizadores-removido', 'grupos_privilegiados', 'uid0:', 'sem-senha:'), 'contas'),
    (('chaves_ssh', 'cron', 'unidades', 'rc_shell', 'sudoers', 'sshd', 'ld-preload', 'padrao:'), 'persistencia'),
    (('portas', 'containers', 'docker_portas_abertas', 'tailscale', 'mineracao:'), 'rede'),
    (('malware:', 'proc-tmp:', 'cpu:'), 'processos'),
    (('suid',), 'suid'),
    (('tmp-exec:',), 'tmp_exec'),
    (('superusers', 'owners_admins', 'app-forca-bruta', 'app-sondas', 'app-erros'), 'pb'),
    (('app-integridade', 'env-'), 'app'),
    (('atualizacoes', 'reboot', 'sem-auto-updates', 'disco', 'unidade-falhou:', 'ssh-senha'), 'higiene'),
    (('ssh-',), 'ssh'),
]


def origem_de(id_):
    for prefixos, nome in ORIGENS:
        if id_.startswith(prefixos):
            return nome
    return ''


def achado(id_, gravidade, categoria, titulo, detalhe, fazer, aprender=None, itens=None):
    """Um alerta. `aprender` = (conjunto, item) a aprender como normal se a
    pessoa disser "já verifiquei"."""
    return {
        'id': id_,
        'gravidade': gravidade,
        'categoria': categoria,
        'titulo': titulo,
        'detalhe': detalhe,
        'fazer': fazer,
        'aprender': list(aprender) if aprender else None,
        'itens': itens or [],
    }


# =============================================================================
# parsers (puros — testados com amostras)
# =============================================================================
RE_SSH_FALHA = re.compile(r'Failed (\S+) for (invalid user )?(\S+) from (\S+) port \d+')
RE_SSH_OK = re.compile(r'Accepted (\S+) for (\S+) from (\S+) port \d+')
RE_SSH_INVALIDO = re.compile(r'Invalid user (\S*) from (\S+)')
RE_SSH_PREAUTH = re.compile(r'(?:Connection closed|Disconnected) by (?:authenticating user (\S+) |invalid user (\S+) )?(\S+) port \d+ \[preauth\]')
RE_UNIX = re.compile(r'^(\d{9,11})(?:\.\d+)?\s')


def parse_ssh(linhas):
    """Linhas do journal (`-o short-unix`) ou do auth.log → eventos
    {ts, tipo: falha|ok|invalido|preauth, user, ip, metodo}."""
    ev = []
    for linha in linhas:
        m = RE_UNIX.match(linha)
        ts = int(m.group(1)) if m else None
        if 'sshd' not in linha:
            continue
        m = RE_SSH_OK.search(linha)
        if m:
            ev.append({'ts': ts, 'tipo': 'ok', 'metodo': m.group(1), 'user': m.group(2), 'ip': m.group(3)})
            continue
        m = RE_SSH_FALHA.search(linha)
        if m:
            ev.append({'ts': ts, 'tipo': 'falha', 'metodo': m.group(1), 'user': m.group(3), 'ip': m.group(4)})
            continue
        m = RE_SSH_INVALIDO.search(linha)
        if m:
            ev.append({'ts': ts, 'tipo': 'invalido', 'metodo': '', 'user': m.group(1), 'ip': m.group(2)})
            continue
        m = RE_SSH_PREAUTH.search(linha)
        if m:
            ev.append({'ts': ts, 'tipo': 'preauth', 'metodo': '', 'user': m.group(1) or m.group(2) or '', 'ip': m.group(3)})
    return ev


def parse_ss_escuta(texto):
    """`ss -H -lntup` → [{proto, addr, porta, proc}]."""
    out = []
    for linha in texto.splitlines():
        p = linha.split()
        if len(p) < 5:
            continue
        proto = p[0].lower()
        if proto not in ('tcp', 'udp'):
            continue
        local = p[4]
        if ':' not in local:
            continue
        addr, _, porta = local.rpartition(':')
        if not porta.isdigit():
            continue
        proc = ''
        m = re.search(r'users:\(\("([^"]+)"', linha)
        if m:
            proc = m.group(1)
        out.append({'proto': proto, 'addr': addr.strip('[]'), 'porta': int(porta), 'proc': proc})
    return out


def parse_ss_ligacoes(texto):
    """`ss -H -ntp state established` → [{remoto, porta, proc}].
    (Com ou sem a coluna do estado: procura os dois endereços ip:porta.)"""
    out = []
    for linha in texto.splitlines():
        enderecos = [t for t in linha.split() if re.fullmatch(r'\S+:\d+', t) and not t.startswith('users:')]
        if len(enderecos) < 2:
            continue
        addr, _, porta = enderecos[1].rpartition(':')
        proc = ''
        m = re.search(r'users:\(\("([^"]+)"', linha)
        if m:
            proc = m.group(1)
        out.append({'remoto': addr.strip('[]'), 'porta': int(porta), 'proc': proc})
    return out


def parse_passwd(texto):
    out = {}
    for linha in texto.splitlines():
        p = linha.split(':')
        if len(p) >= 7 and p[2].isdigit():
            out[p[0]] = {'uid': int(p[2]), 'shell': p[6]}
    return out


def parse_shadow_vazios(texto):
    """Utilizadores sem palavra-passe nenhuma (campo vazio)."""
    out = []
    for linha in texto.splitlines():
        p = linha.split(':')
        if len(p) >= 2 and p[1] == '':
            out.append(p[0])
    return out


def parse_grupos(texto, grupos=('sudo', 'wheel', 'docker', 'adm')):
    out = []
    for linha in texto.splitlines():
        p = linha.split(':')
        if len(p) >= 4 and p[0] in grupos:
            for u in p[3].split(','):
                if u:
                    out.append(f'{p[0]}:{u}')
    return out


def parse_ps(texto):
    """`ps -eo pid=,user=,pcpu=,comm=,args=` → [{pid,user,cpu,comm,args}]."""
    out = []
    for linha in texto.splitlines():
        p = linha.split(None, 4)
        if len(p) < 4:
            continue
        try:
            out.append({
                'pid': int(p[0]), 'user': p[1], 'cpu': float(p[2].replace(',', '.')),
                'comm': p[3], 'args': p[4] if len(p) > 4 else '',
            })
        except ValueError:
            continue
    return out


def parse_docker(texto):
    out = []
    for linha in texto.splitlines():
        linha = linha.strip()
        if not linha.startswith('{'):
            continue
        try:
            j = json.loads(linha)
        except Exception:
            continue
        out.append({
            'nome': j.get('Names', ''), 'imagem': j.get('Image', ''),
            'portas': j.get('Ports', ''),
        })
    return out


def portas_docker_expostas(portas_txt):
    """Portas publicadas em 0.0.0.0/[::] (qualquer interface) numa linha do docker."""
    out = []
    for m in re.finditer(r'(?:0\.0\.0\.0|\[::\]):(\d+)(?:-\d+)?->', portas_txt or ''):
        out.append(int(m.group(1)))
    return sorted(set(out))


def parse_tailscale(texto):
    """`tailscale status --json` → conjunto "nome|so" dos aparelhos da rede."""
    try:
        j = json.loads(texto)
    except Exception:
        return None
    out = set()
    for _, p in (j.get('Peer') or {}).items():
        nome = (p.get('HostName') or p.get('DNSName') or '?')
        out.add(f"{nome}|{p.get('OS') or ''}")
    me = j.get('Self') or {}
    if me:
        out.add(f"{me.get('HostName') or '?'}|{me.get('OS') or ''}")
    return out


def padroes_suspeitos(texto):
    """Nomes dos padrões suspeitos encontrados (sem devolver o texto)."""
    return sorted({desc for rx, desc in PADROES_SUSPEITOS if rx.search(texto or '')})


def chaves_ssh(texto):
    """Linhas de authorized_keys → hashes curtos (nunca a chave)."""
    out = []
    for linha in texto.splitlines():
        l = linha.strip()
        if not l or l.startswith('#'):
            continue
        partes = l.split()
        # [opções] tipo chave [comentário]
        blob = ''
        for i, p in enumerate(partes):
            if p.startswith(('ssh-', 'ecdsa-', 'sk-')) and i + 1 < len(partes):
                blob = partes[i + 1]
                break
        out.append(sha(blob or l)[:16])
    return out


# =============================================================================
# recolha de factos (cada uma isolada: se falha, só essa verificação falha)
# =============================================================================
class Config:
    def __init__(self, raiz, dados, estado_dir, conf):
        self.raiz = raiz
        self.dados = dados
        self.estado_dir = estado_dir
        self.conf = conf

    def lista(self, chave):
        return [x.strip() for x in self.conf.get(chave, '').split(',') if x.strip()]


def carregar_conf(caminho):
    conf = {}
    for linha in ler(caminho).splitlines():
        linha = linha.strip()
        if linha and not linha.startswith('#') and '=' in linha:
            k, _, v = linha.partition('=')
            conf[k.strip()] = v.strip().strip('"').strip("'")
    return conf


def home_dirs():
    out = ['/root']
    for nome, d in parse_passwd(ler('/etc/passwd')).items():
        if d['uid'] >= 1000 and os.path.isdir(f'/home/{nome}'):
            out.append(f'/home/{nome}')
    return out


def coletar_ssh(cfg, desde):
    texto = sh(['journalctl', '-u', 'ssh', '-u', 'sshd', '--since', f'@{int(desde)}',
                '-o', 'short-unix', '--no-pager', '-q'], 30)
    if not texto.strip():
        # sistemas sem journal do ssh: tenta o auth.log
        texto = '\n'.join(ler('/var/log/auth.log').splitlines()[-4000:])
    return parse_ssh(texto.splitlines())


def coletar_contas(cfg):
    passwd = parse_passwd(ler('/etc/passwd'))
    return {
        'utilizadores': sorted(f"{u}|{d['uid']}|{d['shell']}" for u, d in passwd.items()
                               if d['uid'] >= 1000 or d['uid'] == 0 or u == 'root'),
        'uid0': sorted(u for u, d in passwd.items() if d['uid'] == 0),
        'sem_senha': parse_shadow_vazios(ler('/etc/shadow')),
        'grupos_privilegiados': sorted(parse_grupos(ler('/etc/group'))),
    }


def coletar_persistencia(cfg):
    chaves, cron, unidades, rc, suspeitos = [], [], [], [], []
    for h in home_dirs():
        for ks in ('authorized_keys', 'authorized_keys2'):
            for c in chaves_ssh(ler(f'{h}/.ssh/{ks}')):
                chaves.append(f'{h}|{c}')
        for rcf in ('.bashrc', '.profile', '.bash_profile', '.zshrc'):
            t = ler(f'{h}/{rcf}')
            if t:
                rc.append(f'{h}/{rcf}#{sha(t)[:16]}')
                for p in padroes_suspeitos(t):
                    suspeitos.append((f'{h}/{rcf}', p))
    ficheiros_cron = ['/etc/crontab']
    for pasta in ('/etc/cron.d', '/etc/cron.hourly', '/etc/cron.daily', '/etc/cron.weekly',
                  '/etc/cron.monthly', '/var/spool/cron/crontabs', '/var/spool/cron'):
        try:
            for n in sorted(os.listdir(pasta)):
                p = os.path.join(pasta, n)
                if os.path.isfile(p):
                    ficheiros_cron.append(p)
        except Exception:
            pass
    for p in ficheiros_cron:
        t = ler(p)
        if t:
            cron.append(f'{p}#{sha(t)[:16]}')
            for pat in padroes_suspeitos(t):
                suspeitos.append((p, pat))
    for pasta in ['/etc/systemd/system', '/usr/local/lib/systemd/system'] + [f'{h}/.config/systemd/user' for h in home_dirs()]:
        try:
            for n in sorted(os.listdir(pasta)):
                p = os.path.join(pasta, n)
                if os.path.isfile(p) and n.endswith(('.service', '.timer', '.socket')):
                    t = ler(p)
                    unidades.append(f'{p}#{sha(t)[:16]}')
                    for pat in padroes_suspeitos(t):
                        suspeitos.append((p, pat))
        except Exception:
            pass
    ldpre = ler('/etc/ld.so.preload').strip()
    rclocal = ler('/etc/rc.local')
    if rclocal:
        rc.append(f'/etc/rc.local#{sha(rclocal)[:16]}')
        for p in padroes_suspeitos(rclocal):
            suspeitos.append(('/etc/rc.local', p))
    sudoers = ler('/etc/sudoers')
    try:
        for n in sorted(os.listdir('/etc/sudoers.d')):
            sudoers += ler(os.path.join('/etc/sudoers.d', n))
    except Exception:
        pass
    sshd = ler('/etc/ssh/sshd_config')
    try:
        for n in sorted(os.listdir('/etc/ssh/sshd_config.d')):
            sshd += ler(os.path.join('/etc/ssh/sshd_config.d', n))
    except Exception:
        pass
    return {
        'chaves_ssh': sorted(chaves), 'cron': sorted(cron), 'unidades': sorted(unidades),
        'rc_shell': sorted(rc), 'suspeitos': sorted(set(suspeitos)),
        'ld_preload': bool(ldpre), 'sudoers': [f'sudoers#{sha(sudoers)[:16]}'],
        'sshd': [f'sshd_config#{sha(sshd)[:16]}'],
        'sshd_texto': sshd[:20000],
    }


def coletar_rede(cfg):
    escuta = parse_ss_escuta(sh(['ss', '-H', '-lntup']))
    portas = sorted({f"{e['proto']}|{e['addr']}|{e['porta']}" for e in escuta})
    ligacoes = parse_ss_ligacoes(sh(['ss', '-H', '-ntp', 'state', 'established']))
    docker = parse_docker(sh(['docker', 'ps', '--format', '{{json .}}']))
    ts = parse_tailscale(sh(['tailscale', 'status', '--json'])) if sh(['which', 'tailscale']).strip() else None
    return {
        'portas': portas,
        'escuta_detalhe': escuta,
        'ligacoes': ligacoes,
        'containers': sorted(f"{c['nome']}|{c['imagem']}" for c in docker),
        'docker_portas_abertas': sorted(
            f"{c['nome']}|{p}" for c in docker for p in portas_docker_expostas(c['portas'])),
        'tailscale': sorted(ts) if ts is not None else None,
    }


def coletar_processos(cfg):
    procs = parse_ps(sh(['ps', '-eo', 'pid=,user=,pcpu=,comm=,args=', '--sort=-pcpu'], 15))
    suspeitos = []
    for p in procs[:400]:
        try:
            exe = os.readlink(f"/proc/{p['pid']}/exe")
        except Exception:
            exe = ''
        p['exe'] = exe
    return {'processos': procs[:60], 'processos_exe': [
        {'pid': p['pid'], 'comm': p['comm'], 'exe': p.get('exe', ''), 'user': p['user']}
        for p in procs[:400] if p.get('exe')
    ], 'suspeitos': suspeitos}


def coletar_suid(cfg):
    texto = sh(['find', '/', '-xdev', '-type', 'f', '-perm', '/6000',
                '-not', '-path', '/proc/*', '-not', '-path', '/var/lib/docker/*',
                '-not', '-path', '/var/lib/containerd/*'], 90)
    return {'suid': sorted(l.strip() for l in texto.splitlines() if l.strip())[:500]}


def coletar_tmp_exec(cfg):
    out = []
    for pasta in ('/tmp', '/var/tmp', '/dev/shm'):
        texto = sh(['find', pasta, '-maxdepth', '3', '-type', 'f', '-perm', '/111', '-mtime', '-2'], 20)
        out += [l.strip() for l in texto.splitlines() if l.strip()]
    return {'tmp_exec': sorted(out)[:50]}


def coletar_app(cfg):
    """Impressão digital dos ficheiros da app instalada."""
    base = cfg.raiz
    ficheiros = {}
    alvos = ['hooks', 'migrations', 'backup', 'seguranca']
    for a in alvos:
        for dp, _, fs in os.walk(os.path.join(base, a)):
            for f in fs:
                p = os.path.join(dp, f)
                ficheiros[os.path.relpath(p, base).replace(os.sep, '/')] = sha_ficheiro(p)
    for f in ('compose.yaml', 'Dockerfile', 'gc_turnkey.sh', 'VERSAO.txt'):
        p = os.path.join(base, f)
        if os.path.isfile(p):
            ficheiros[f] = sha_ficheiro(p)
    for dp, _, fs in os.walk(os.path.join(base, 'web')):
        for f in fs:
            if f.endswith('.gz'):
                continue
            p = os.path.join(dp, f)
            ficheiros[os.path.relpath(p, base).replace(os.sep, '/')] = sha_ficheiro(p)
    versao = ler(os.path.join(base, 'VERSAO.txt'))
    m = re.search(r'App:\s+(v[\w.\-]+)', versao)
    env = os.path.join(base, '.env')
    modo_env = None
    try:
        modo_env = oct(os.stat(env).st_mode & 0o777)
    except Exception:
        pass
    return {
        'app_ficheiros': ficheiros,
        'app_versao': m.group(1) if m else '',
        'env_modo': modo_env,
        'env_hash': sha_ficheiro(env),
    }


def _ro(caminho):
    uri = 'file:' + urllib.parse.quote(caminho) + '?mode=ro'
    return sqlite3.connect(uri, uri=True, timeout=3)


def coletar_pb(cfg, desde):
    out = {'superusers': None, 'owners_admins': None, 'logs': None}
    try:
        c = _ro(os.path.join(cfg.dados, 'data.db'))
        try:
            out['superusers'] = sorted(r[0] for r in c.execute('SELECT email FROM _superusers'))
            out['owners_admins'] = sorted(
                f'{r[0]}|{r[1]}' for r in c.execute(
                    "SELECT email, papel FROM users WHERE papel IN ('owner','admin')"))
        finally:
            c.close()
    except Exception:
        pass
    try:
        c = _ro(os.path.join(cfg.dados, 'auxiliary.db'))
        try:
            desde_iso = time.strftime('%Y-%m-%d %H:%M:%S', time.gmtime(desde))
            linhas = c.execute(
                "SELECT json_extract(data,'$.status'), json_extract(data,'$.url'), "
                "json_extract(data,'$.method'), json_extract(data,'$.userIP') "
                "FROM _logs WHERE created >= ? AND json_extract(data,'$.status') IS NOT NULL LIMIT 20000",
                (desde_iso,)).fetchall()
            out['logs'] = [list(x) for x in linhas]
        finally:
            c.close()
    except Exception:
        pass
    return out


def coletar_higiene(cfg):
    upg = sh(['apt-get', '-s', 'upgrade'], 40)
    seg = [l for l in upg.splitlines() if l.startswith('Inst ') and 'security' in l.lower()]
    reboot = os.path.exists('/var/run/reboot-required')
    reboot_idade = 0
    if reboot:
        try:
            reboot_idade = int((time.time() - os.stat('/var/run/reboot-required').st_mtime) / 86400)
        except Exception:
            pass
    unatt = 'enabled' in sh(['systemctl', 'is-enabled', 'unattended-upgrades']) or \
        os.path.exists('/etc/apt/apt.conf.d/20auto-upgrades')
    falhas = [l.split()[1] if l.startswith('●') else l.split()[0]
              for l in sh(['systemctl', '--failed', '--no-legend', '--plain']).splitlines() if l.strip()]
    st = os.statvfs('/') if hasattr(os, 'statvfs') else None
    disco = round(100 - 100 * st.f_bavail / st.f_blocks, 1) if st and st.f_blocks else None
    return {
        'atualizacoes_seguranca': len(seg), 'reboot_pendente_dias': reboot_idade if reboot else None,
        'auto_updates': bool(unatt), 'unidades_falhadas': falhas[:20], 'disco_usado_pct': disco,
        'fail2ban': 'active' in sh(['systemctl', 'is-active', 'fail2ban']),
    }


# =============================================================================
# estado persistente
# =============================================================================
def carregar_json(caminho, padrao):
    try:
        with open(caminho, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception:
        return padrao


def gravar_json(caminho, obj, modo=0o600):
    tmp = caminho + '.tmp'
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    with open(tmp, 'w', encoding='utf-8') as f:
        json.dump(obj, f, ensure_ascii=False, indent=1, sort_keys=True)
    try:
        os.chmod(tmp, modo)
    except Exception:
        pass
    os.replace(tmp, caminho)


# =============================================================================
# análise (pura: factos + baseline + histórico → achados)
# =============================================================================
CONJUNTOS = {
    # chave: (gravidade, categoria, título "novo", fazer)
    'utilizadores': ('atencao', 'contas', 'Apareceu um utilizador novo no servidor',
                     'Se foste tu a criá-lo, clica "Já verifiquei". Se não, é suspeito: bloqueia-o (sudo usermod -L NOME), vê o que fez (last NOME) e muda as palavras-passe e chaves SSH.'),
    'grupos_privilegiados': ('critico', 'contas', 'Alguém ganhou poderes de administrador (sudo/docker)',
                             'Quem está nos grupos sudo ou docker controla o servidor inteiro. Se não foste tu, remove-o do grupo (sudo gpasswd -d NOME GRUPO) e trata como intrusão.'),
    'chaves_ssh': ('critico', 'persistencia', 'Há uma chave SSH nova autorizada a entrar no servidor',
                   'Uma chave nova em authorized_keys é a forma mais comum de um intruso garantir que volta. Se não a puseste tu, remove essa linha do ficheiro e muda as chaves e palavras-passe.'),
    'cron': ('atencao', 'persistencia', 'Uma tarefa agendada (cron) foi criada ou alterada',
             'Vê o ficheiro indicado (cat). Se é tua ou do sistema, clica "Já verifiquei". Se não reconheces, apaga-a e investiga como foi parar lá.'),
    'unidades': ('atencao', 'persistencia', 'Um serviço ou timer do systemd foi criado ou alterado',
                 'Vê o ficheiro indicado (systemctl cat NOME). Se é teu, clica "Já verifiquei"; se não, desativa-o (systemctl disable --now NOME) e investiga.'),
    'rc_shell': ('atencao', 'persistencia', 'Um ficheiro de arranque da consola mudou (.bashrc, .profile…)',
                 'Estes ficheiros correm a cada login; um intruso usa-os para esconder comandos. Vê o conteúdo e, se não foste tu, repõe-o.'),
    'sudoers': ('critico', 'contas', 'As regras do sudo foram alteradas',
                'Alguém mudou quem pode ser administrador. Vê com "sudo visudo -c" e "sudo cat /etc/sudoers /etc/sudoers.d/*". Se não foste tu, trata como intrusão.'),
    'sshd': ('atencao', 'acesso', 'A configuração do acesso SSH mudou',
             'Vê o que mudou em /etc/ssh/sshd_config*. Se não foste tu, repõe-a e reinicia o SSH.'),
    'portas': ('atencao', 'rede', 'Há uma porta nova à escuta no servidor',
               'Uma porta nova pode ser um serviço novo teu (ok) ou uma porta de acesso de um intruso. Vê qual é o programa (sudo ss -tlnp) e, se não o reconheces, pára-o.'),
    'containers': ('atencao', 'rede', 'Há um contentor Docker novo ou diferente',
                   'Vê com "docker ps -a" e "docker inspect NOME". Contentores desconhecidos são uma forma comum de instalar mineradores. Se não é teu, remove-o (docker rm -f NOME).'),
    'docker_portas_abertas': ('atencao', 'rede', 'Um contentor abriu uma porta para toda a rede',
                              'Um contentor com porta em 0.0.0.0 fica acessível a quem chegar ao servidor. Se não é intencional, publica só em 127.0.0.1 no compose.'),
    'tailscale': ('atencao', 'rede', 'Há um aparelho novo na rede Tailscale',
                  'Quem entra na tua rede Tailscale chega ao servidor. Se não reconheces o aparelho, remove-o no painel do Tailscale (login.tailscale.com → Machines).'),
    'suid': ('atencao', 'sistema', 'Apareceu um programa com poderes especiais (setuid/setgid)',
             'Programas setuid novos são uma técnica clássica para ganhar acesso de administrador. Se não vieram de uma atualização tua, investiga (ls -l; dpkg -S).'),
    'superusers': ('critico', 'app', 'Há um novo superutilizador na base de dados da app',
                   'Um superutilizador controla tudo no painel /_/. Se não foste tu, apaga-o no painel, muda a tua palavra-passe e vê os registos da app.'),
    'owners_admins': ('atencao', 'app', 'Mudaram os proprietários/administradores da app',
                      'Confirma em Configurações → Equipa que a lista está certa. Se foste tu, clica "Já verifiquei".'),
}


def _rotulo(chave, item):
    """Texto legível de um item de conjunto (sem hashes nem segredos)."""
    if chave in ('cron', 'unidades', 'rc_shell', 'sudoers', 'sshd'):
        return item.split('#')[0]
    if chave == 'utilizadores':
        p = item.split('|')
        return f'{p[0]} (uid {p[1]})' if len(p) > 1 else item
    if chave == 'chaves_ssh':
        return item.split('|')[0] + ' (chave ' + item.split('|')[-1][:6] + '…)'
    if chave == 'portas':
        p = item.split('|')
        return f'{p[0]} {p[1]}:{p[2]}' if len(p) == 3 else item
    if chave == 'containers':
        return item.replace('|', ' (') + ')'
    if chave == 'docker_portas_abertas':
        n, _, p = item.partition('|')
        return f'{n} → porta {p}'
    if chave == 'tailscale':
        return item.replace('|', ' (') + ')'
    return item


def _portas_sensiveis_novas(item):
    """Uma porta nova em 0.0.0.0/:: que não seja local."""
    p = item.split('|')
    return len(p) == 3 and p[1] in ('0.0.0.0', '::', '*')


def analisar(f, base, hist, agora, cfg_ips=None, primeira=False, anteriores=None, reavaliadas=None):
    """Devolve (achados, baseline_novo, hist_novo, notas).

    f     = factos recolhidos (algumas chaves podem faltar)
    base  = baseline guardado ({'conjuntos': {...}, 'app': {...}})
    hist  = histórico {'ssh': [[ts,tipo,ip,user],...], 'cpu': {...}, 'vistos': {...}}
    """
    cfg_ips = cfg_ips or []
    achados = []
    notas = []
    conj_base = base.get('conjuntos', {}) if base else {}
    conj_novo = dict(conj_base)
    hist = hist or {}
    hist.setdefault('ssh', [])
    hist.setdefault('cpu', {})
    hist.setdefault('auth_app', [])
    hist.setdefault('primeiro_visto', {})

    # ---------- 1. conjuntos que mudam face ao normal -------------------------
    for chave, (grav, cat, titulo, fazer) in CONJUNTOS.items():
        if chave not in f or f[chave] is None:
            continue
        atual = set(f[chave])
        if primeira or chave not in conj_base:
            conj_novo[chave] = sorted(atual)
            continue
        antigo = set(conj_base[chave])
        novos = sorted(atual - antigo)
        removidos = sorted(antigo - atual)
        conj_novo[chave] = sorted(antigo)   # só aprende com "já verifiquei"
        if chave in ('cron', 'unidades', 'rc_shell', 'sudoers', 'sshd'):
            # um ficheiro alterado aparece como "removido + novo" com o mesmo caminho:
            # não interessa o que saiu, só o que ficou diferente
            removidos = [r for r in removidos if r.split('#')[0] not in {n.split('#')[0] for n in novos}]
        for n in novos:
            g = grav
            tit = titulo
            if chave == 'portas':
                if not _portas_sensiveis_novas(n):
                    g = 'info'
            if chave == 'utilizadores' and (n.split('|')[1] == '0'):
                g = 'critico'
            achados.append(achado(
                f'{chave}:{n}', g, cat, tit, _rotulo(chave, n), fazer, aprender=(chave, n)))
        for r in removidos:
            achados.append(achado(
                f'{chave}-removido:{r}', 'info', cat,
                'Algo que existia desapareceu', _rotulo(chave, r),
                'Normal se foste tu a remover ou a atualizar. Clica "Já verifiquei" para o vigia aprender.',
                aprender=(chave + '#remover', r)))

    # ---------- 2. regras duras (sem baseline) ---------------------------------
    for u in f.get('uid0', []) or []:
        if u != 'root':
            achados.append(achado(
                f'uid0:{u}', 'critico', 'contas',
                f'O utilizador "{u}" tem poderes de root (uid 0)',
                'Só "root" devia ter uid 0. Outro utilizador assim é uma porta traseira típica.',
                f'Se não o criaste tu, é uma intrusão: bloqueia-o (sudo usermod -L {u}), muda todas as palavras-passe e restaura de um backup limpo se necessário.'))
    for u in f.get('sem_senha', []) or []:
        achados.append(achado(
            f'sem-senha:{u}', 'critico', 'contas',
            f'O utilizador "{u}" não tem palavra-passe',
            'Uma conta sem palavra-passe entra sem pedir nada (em alguns serviços).',
            f'Define uma palavra-passe (sudo passwd {u}) ou bloqueia a conta (sudo passwd -l {u}).'))
    if f.get('ld_preload'):
        achados.append(achado(
            'ld-preload', 'critico', 'persistencia',
            'Existe /etc/ld.so.preload', 'Este ficheiro raramente existe e é usado por rootkits para se esconderem.',
            'Vê o conteúdo (cat /etc/ld.so.preload). Se não o criaste tu, trata como intrusão grave: copia os dados e reinstala o servidor.'))
    for ficheiro, padrao in f.get('suspeitos', []) or []:
        achados.append(achado(
            f'padrao:{ficheiro}:{padrao}', 'critico', 'persistencia',
            'Um ficheiro de arranque faz algo típico de ataques',
            f'{ficheiro}: {padrao}.',
            'Abre o ficheiro e confirma o que faz. Se não o escreveste tu, apaga a linha e investiga como lá chegou.',
            aprender=('padrao', f'{ficheiro}|{padrao}')))
    # processos
    for p in f.get('processos_exe', []) or []:
        exe = p.get('exe', '')
        comm = (p.get('comm') or '').lower()
        if comm in NOMES_MALWARE or os.path.basename(exe).lower() in NOMES_MALWARE:
            achados.append(achado(
                f'malware:{comm}', 'critico', 'processos',
                f'Está a correr "{p.get("comm")}", um programa típico de mineração/ataque',
                f'Processo {p.get("pid")} do utilizador {p.get("user")}.',
                'Isto quase nunca é legítimo. Pára-o (sudo kill -9 PID), procura como entrou (cron, contentores, chaves SSH) e muda as palavras-passe.'))
        elif any(exe.startswith(d) or exe.replace(' (deleted)', '').startswith(d) for d in PASTAS_SUSPEITAS):
            achados.append(achado(
                f'proc-tmp:{os.path.basename(exe)}', 'critico', 'processos',
                'Um programa está a correr a partir de uma pasta temporária',
                f'{p.get("comm")} (processo {p.get("pid")}, utilizador {p.get("user")}) corre de {os.path.dirname(exe)}.',
                'Programas legítimos não correm de /tmp ou /dev/shm. Pára o processo, guarda uma cópia do ficheiro para análise e investiga a origem.'))
    # CPU alto sustentado (precisa de várias rondas seguidas)
    cpus = hist['cpu']
    vistos = set()
    for p in f.get('processos', []) or []:
        comm = (p.get('comm') or '')
        if p.get('cpu', 0) >= 90 and comm.lower() not in CPU_PERMITIDOS:
            vistos.add(comm)
            cpus[comm] = cpus.get(comm, 0) + 1
    for k in list(cpus):
        if k not in vistos:
            del cpus[k]
    for comm, n in cpus.items():
        if n >= 6:   # ~1 hora seguida
            achados.append(achado(
                f'cpu:{comm}', 'atencao', 'processos',
                f'"{comm}" está há mais de 1 hora a usar quase todo o processador',
                'Os mineradores de criptomoedas fazem exatamente isto.',
                'Vê o que é (ps aux | grep ' + comm + '). Se não o reconheces, pára-o e investiga.'))
    # ligações a portas de mineração
    for c in f.get('ligacoes', []) or []:
        if c.get('porta') in PORTAS_MINERACAO and classe_ip(c.get('remoto')) == 'publico':
            achados.append(achado(
                f'mineracao:{c.get("remoto")}:{c.get("porta")}', 'critico', 'rede',
                'O servidor está ligado a um endereço de mineração de criptomoedas',
                f'Ligação a {c.get("remoto")}:{c.get("porta")} (programa: {c.get("proc") or "?"}).',
                'Descobre o programa (sudo ss -tnp) e pára-o. É o sinal clássico de um servidor invadido para minerar.'))
    for ex in f.get('tmp_exec', []) or []:
        achados.append(achado(
            f'tmp-exec:{ex}', 'atencao', 'sistema',
            'Há um ficheiro executável novo numa pasta temporária', ex,
            'Vê o que é (file, strings). Executáveis em /tmp ou /dev/shm são típicos de ataques.',
            aprender=('tmp_exec', ex)))

    # ---------- 3. SSH ---------------------------------------------------------
    ssh_ev = [e for e in (f.get('ssh') or []) if e.get('ts')]
    for e in ssh_ev:
        hist['ssh'].append([e['ts'], e['tipo'], e['ip'], e['user']])
    hist['ssh'] = [x for x in hist['ssh'] if x[0] >= agora - JANELA_HIST][-MAX_EVENTOS:]
    falhas_24h = {}
    for ts, tipo, ip, user in hist['ssh']:
        if tipo in ('falha', 'invalido') and ts >= agora - 86400:
            falhas_24h[ip] = falhas_24h.get(ip, 0) + 1
    ips_conhecidos = set(conj_base.get('ssh_ips', []))
    novos_ips = set()
    for e in ssh_ev:
        if e['tipo'] == 'ok':
            ip, user = e['ip'], e['user']
            cl = classe_ip(ip)
            if cl == 'publico' and not ip_permitido(ip, cfg_ips):
                achados.append(achado(
                    f'ssh-publico:{ip}:{user}', 'critico', 'acesso',
                    f'Entrada por SSH vinda da internet pública ({ip})',
                    f'Utilizador "{user}", método {e["metodo"]}. O servidor devia ser acessível só pela rede Tailscale/local.',
                    'Se não foste tu: muda já as palavras-passe e chaves, e fecha a porta 22 ao exterior (firewall do router/ufw).',
                    aprender=('ssh_ips', ip)))
            if user == 'root':
                achados.append(achado(
                    f'ssh-root:{ip}', 'atencao' if cl != 'publico' else 'critico', 'acesso',
                    'Alguém entrou por SSH como "root"', f'Origem {ip}.',
                    'Entrar diretamente como root não é boa prática. Desativa-o (PermitRootLogin no) e usa um utilizador normal com sudo.',
                    aprender=('ssh_ips', ip)))
            if falhas_24h.get(ip, 0) >= 5:
                achados.append(achado(
                    f'ssh-forca-bruta-ok:{ip}', 'critico', 'acesso',
                    f'Entrada por SSH depois de {falhas_24h[ip]} tentativas falhadas ({ip})',
                    f'O IP {ip} falhou várias vezes e depois entrou como "{user}". Isto é o padrão de uma palavra-passe adivinhada.',
                    'Muda já a palavra-passe do utilizador, desativa o login por palavra-passe (só chaves) e verifica o que essa sessão fez (last; history).'))
            if ip not in ips_conhecidos and not primeira:
                novos_ips.add(ip)
                if cl != 'publico':
                    achados.append(achado(
                        f'ssh-ip-novo:{ip}', 'atencao', 'acesso',
                        f'Primeiro acesso por SSH vindo de {ip}', f'Utilizador "{user}" (rede {cl}).',
                        'Se é um dos teus aparelhos, clica "Já verifiquei" e o vigia aprende-o. Se não, muda as credenciais.',
                        aprender=('ssh_ips', ip)))
            ips_conhecidos_hora = hist.setdefault('horas_ssh', [0] * 24)
            hora = time.localtime(e['ts']).tm_hour
            total_hist = sum(ips_conhecidos_hora)
            if total_hist >= 15 and ips_conhecidos_hora[hora] == 0:
                achados.append(achado(
                    f'ssh-hora:{ip}:{hora}', 'atencao', 'acesso',
                    f'Entrada por SSH a uma hora invulgar ({hora:02d}h)',
                    f'Origem {ip}, utilizador "{user}". Nunca antes entraste a esta hora.',
                    'Se foste tu, ignora ("Já verifiquei"). Se não, trata como acesso indevido.',
                    aprender=('ssh_hora', str(hora))))
            ips_conhecidos_hora[hora] += 1
    # tentativas falhadas a rebentar
    janela = [e for e in ssh_ev if e['tipo'] in ('falha', 'invalido')]
    por_ip = {}
    for e in janela:
        por_ip[e['ip']] = por_ip.get(e['ip'], 0) + 1
    for ip, n in por_ip.items():
        if falhas_24h.get(ip, 0) >= LIMITE_IP_FALHAS:
            achados.append(achado(
                f'ssh-ataque:{ip}', 'atencao', 'acesso',
                f'Tentativas repetidas de entrar por SSH ({falhas_24h[ip]} em 24 h) vindas de {ip}',
                f'Rede {classe_ip(ip)}. Alguém está a tentar adivinhar palavras-passe.',
                'Se o IP é público, o SSH está exposto: fecha a porta 22 ao exterior e instala fail2ban. Se é interno, descobre que aparelho é.'))
    if len(janela) >= LIMITE_FALHAS_JANELA and not por_ip.get('x'):
        achados.append(achado(
            'ssh-pico', 'atencao', 'acesso', f'{len(janela)} tentativas falhadas de SSH nos últimos 10 minutos',
            'Muito acima do normal.', 'Vê quem (journalctl -u ssh) e confirma que o SSH não está exposto à internet.'))

    # ---------- 4. a app (PocketBase) ------------------------------------------
    app = f.get('app_ficheiros')
    if app is not None:
        app_base = (base or {}).get('app', {})
        versao = f.get('app_versao', '')
        if primeira or not app_base:
            notas.append('Ficheiros da app aprendidos como normais.')
        elif app_base.get('versao') != versao:
            notas.append(f'App atualizada para {versao or "?"}: ficheiros novos aprendidos.')
        else:
            antigos = app_base.get('ficheiros', {})
            mudados = sorted(k for k in app if k in antigos and app[k] != antigos[k])
            novos_f = sorted(k for k in app if k not in antigos)
            sumidos = sorted(k for k in antigos if k not in app)
            if mudados or novos_f or sumidos:
                lista = [f'alterado: {x}' for x in mudados[:6]] + [f'novo: {x}' for x in novos_f[:6]] + \
                        [f'em falta: {x}' for x in sumidos[:6]]
                crit = any(x.startswith(('hooks/', 'migrations/', 'web/index', 'web/flutter', 'gc_turnkey.sh', 'compose.yaml', 'Dockerfile', 'seguranca/')) for x in mudados + novos_f)
                achados.append(achado(
                    'app-integridade', 'critico' if crit else 'atencao', 'app',
                    'Ficheiros da app mudaram sem haver uma atualização',
                    'Mudou código da app (hooks/migrations/web) com a mesma versão instalada.',
                    'Se atualizaste a app à mão, clica "Já verifiquei". Se não, alguém alterou o código: restaura a app do pacote original (sha256sum) e investiga.',
                    aprender=('app', 'ficheiros'), itens=lista))
        if f.get('env_modo') and f['env_modo'] not in ('0o600', '0o640', '0o400'):
            achados.append(achado(
                'env-permissoes', 'atencao', 'app', 'O ficheiro .env (segredos) está legível por outros utilizadores',
                f'Permissões {f["env_modo"]}.', 'Corrige com: chmod 600 /opt/gc_turnkey/.env'))
        envh = f.get('env_hash')
        antes = (base or {}).get('app', {}).get('env_hash')
        if envh and antes and envh != antes:
            achados.append(achado(
                'env-mudou', 'info', 'app', 'O ficheiro .env (segredos) foi alterado',
                'A chave de cifra, as chaves de IA ou o SMTP podem ter mudado.',
                'Normal se mudaste uma chave. Clica "Já verifiquei" para o vigia aprender.',
                aprender=('app', 'env')))
    # logs da app
    logs = f.get('logs')
    if logs is not None:
        falhas_auth = sum(1 for st, url, m, ip in logs if st in (400, 401, 403, 429) and url and 'auth-with-password' in url)
        # o normal desta app = a mediana das rondas anteriores (sem a atual)
        anteriores_auth = hist['auth_app']
        mediana = sorted(anteriores_auth)[len(anteriores_auth) // 2] if anteriores_auth else 0
        hist['auth_app'] = (anteriores_auth + [falhas_auth])[-144:]
        if falhas_auth >= LIMITE_AUTH_APP and falhas_auth >= 5 * max(mediana, 1):
            achados.append(achado(
                'app-forca-bruta', 'atencao', 'app',
                f'{falhas_auth} falhas de início de sessão na app numa ronda',
                f'O normal aqui são cerca de {mediana}. Alguém pode estar a tentar adivinhar palavras-passe.',
                'Confirma em Configurações → Equipa se há contas estranhas, liga a verificação em 2 passos e vê quem acede à rede Tailscale.'))
        sondas = [url for st, url, m, ip in logs if url and re.search(r'(\.\./|%2e%2e|/\.env|/\.git|wp-login|phpmyadmin|/etc/passwd|cmd=|union\s+select)', url, re.I)]
        if len(sondas) >= 3:
            achados.append(achado(
                'app-sondas', 'atencao', 'app', f'{len(sondas)} pedidos à app com cara de ataque (procuram ficheiros ou falhas)',
                'Por exemplo pedidos a /.env, ../ ou wp-login.', 'Vê de onde vêm; se alguém na tua rede Tailscale está a fazer isto, é um aparelho comprometido ou alguém a testar.'))
        cincos = sum(1 for st, *_ in logs if isinstance(st, int) and st >= 500)
        if cincos >= 30:
            achados.append(achado(
                'app-erros', 'info', 'app', f'{cincos} erros do servidor da app numa ronda',
                'Pode ser um problema da app ou alguém a forçá-la.', 'Vê os logs (bash gc_turnkey.sh logs).'))

    # ---------- 5. higiene -----------------------------------------------------
    h = f.get('higiene')
    if h:
        nseg = h.get('atualizacoes_seguranca', 0)
        pv = hist['primeiro_visto']
        if nseg > 0:
            pv.setdefault('upd_seg', agora)
            if agora - pv['upd_seg'] > 7 * 86400:
                achados.append(achado(
                    'atualizacoes', 'atencao', 'sistema',
                    f'{nseg} atualizações de segurança por instalar há mais de 7 dias',
                    'Falhas conhecidas ficam por corrigir.', 'Corre: sudo apt update && sudo apt upgrade (e ativa as automáticas: sudo apt install unattended-upgrades).'))
        else:
            pv.pop('upd_seg', None)
        if h.get('reboot_pendente_dias') is not None and h['reboot_pendente_dias'] > 14:
            achados.append(achado(
                'reboot', 'atencao', 'sistema', f'O servidor precisa de reiniciar há {h["reboot_pendente_dias"]} dias',
                'Uma atualização de segurança do sistema só fica ativa depois de reiniciar.', 'Reinicia numa altura calma: sudo reboot.'))
        if h.get('auto_updates') is False:
            achados.append(achado(
                'sem-auto-updates', 'info', 'sistema', 'As atualizações automáticas de segurança não estão ativas',
                'Sem elas, as falhas de segurança só se corrigem quando te lembrares.', 'Instala: sudo apt install unattended-upgrades'))
        if h.get('disco_usado_pct') is not None and h['disco_usado_pct'] >= 90:
            achados.append(achado(
                'disco', 'atencao', 'sistema', f'O disco está {h["disco_usado_pct"]}% cheio',
                'Um disco cheio pára a base de dados e os backups (e pode ser sinal de ficheiros lixo).', 'Liberta espaço (docker system df; journalctl --vacuum-size=200M).'))
        for u in h.get('unidades_falhadas', []) or []:
            if 'gc_turnkey' in u:
                achados.append(achado(
                    f'unidade-falhou:{u}', 'atencao', 'sistema', f'O serviço {u} falhou',
                    'Uma tarefa do gc_turnkey (backup, vigia…) não correu bem.', f'Vê: journalctl -u {u} -n 30'))
        if re.search(r'^\s*PasswordAuthentication\s+yes', f.get('sshd_texto') or '', re.M) and not h.get('fail2ban'):
            achados.append(achado(
                'ssh-senha', 'info', 'acesso', 'O SSH aceita palavra-passe (e não há fail2ban)',
                'Quem chegar ao SSH pode tentar adivinhar palavras-passe.',
                'Idealmente só chaves SSH (PasswordAuthentication no) ou instala o fail2ban.'))

    # ---------- 5b. o que não foi reavaliado nesta ronda mantém-se ----------------
    # (as verificações lentas não correm de 10 em 10 minutos; os eventos de SSH
    #  só aparecem uma vez, por isso ficam 24 h)
    if anteriores and not primeira:
        ids = {a['id'] for a in achados}
        for a in anteriores:
            if a['id'] in ids or a['id'] == 'incidente':
                continue
            nome = origem_de(a['id'])
            if nome == 'ssh':
                if agora - a.get('desde', agora) < 86400:
                    achados.append(achado(a['id'], a['gravidade'], a['categoria'], a['titulo'], a['detalhe'],
                                          a['fazer'], aprender=a.get('aprender'), itens=a.get('itens')))
            elif nome and reavaliadas is not None and nome not in reavaliadas:
                achados.append(achado(a['id'], a['gravidade'], a['categoria'], a['titulo'], a['detalhe'],
                                      a['fazer'], aprender=a.get('aprender'), itens=a.get('itens')))

    # ---------- 6. ligar os pontos ----------------------------------------------
    ativos = {a['id'] for a in achados}
    def tem(prefixos):
        return any(i.startswith(prefixos) for i in ativos)
    sinais = []
    persist = tem(('chaves_ssh:', 'cron:', 'unidades:', 'padrao:', 'utilizadores:', 'uid0:', 'sudoers:', 'ld-preload'))
    acesso = tem(('ssh-ip-novo', 'ssh-publico', 'ssh-forca-bruta-ok', 'ssh-hora'))
    proc = tem(('malware:', 'proc-tmp:', 'mineracao:', 'cpu:', 'tmp-exec:'))
    codigo = tem(('app-integridade', 'superusers:'))
    if persist and acesso:
        sinais.append('uma forma de voltar a entrar (chave/utilizador/tarefa nova) + um acesso novo ou suspeito')
    if persist and proc:
        sinais.append('persistência nova + um programa suspeito a correr')
    if codigo and (acesso or persist):
        sinais.append('código da app alterado + acessos/persistência novos')
    if proc and tem(('mineracao:', 'malware:')) and tem(('containers:', 'docker_portas_abertas:')):
        sinais.append('mineração + contentor novo')
    if sinais:
        achados.insert(0, achado(
            'incidente', 'critico', 'incidente', 'POSSÍVEL INTRUSÃO: vários sinais ao mesmo tempo',
            'Mais do que um sinal de alarme ao mesmo tempo (ver abaixo).',
            '1) Não desligues nada ainda. 2) Muda já as palavras-passe e chaves SSH. 3) Remove o acesso suspeito (chave, utilizador, aparelho Tailscale). '
            '4) Guarda os registos (journalctl > /tmp/log.txt). 5) Se houver dúvida, restaura de um backup limpo.',
            itens=sinais))

    # ---------- 7. ips SSH aprendidos nesta ronda ---------------------------------
    conj_novo['ssh_ips'] = sorted(ips_conhecidos | ({e['ip'] for e in ssh_ev if e['tipo'] == 'ok'} if primeira else set()))
    if primeira:
        # nada é alerta na primeira ronda, mas aprende-se tudo
        # só as regras duras (o que nunca é normal) valem sem saber o que é normal
        duras = ('uid0:', 'sem-senha:', 'malware:', 'proc-tmp:', 'mineracao:', 'ld-preload', 'padrao:',
                 'ssh-publico:', 'ssh-forca-bruta-ok:')
        achados = [a for a in achados if a['id'].startswith(duras)]
        notas.append('Primeira ronda: o estado atual foi aprendido como "normal".')

    novo_base = {'conjuntos': conj_novo, 'app': (base or {}).get('app', {})}
    if app is not None:
        pode_atualizar = primeira or not novo_base['app'] or novo_base['app'].get('versao') != f.get('app_versao', '')
        if pode_atualizar:
            novo_base['app'] = {'versao': f.get('app_versao', ''), 'ficheiros': app, 'env_hash': f.get('env_hash', '')}
    return achados, novo_base, hist, notas


# =============================================================================
# aceitar ("já verifiquei") e silenciar
# =============================================================================
def aplicar_aceites(achados, base, f, aceites_ids):
    """Quem disse "já verifiquei" a um achado faz o vigia aprender esse item."""
    restantes = []
    aprendidos = []
    for a in achados:
        if a['id'] in aceites_ids and a.get('aprender'):
            chave, item = a['aprender']
            if chave == 'app':
                if item == 'ficheiros':
                    base.setdefault('app', {})
                    base['app']['ficheiros'] = f.get('app_ficheiros', {})
                    base['app']['versao'] = f.get('app_versao', '')
                elif item == 'env':
                    base.setdefault('app', {})['env_hash'] = f.get('env_hash', '')
            elif chave.endswith('#remover'):
                real = chave.split('#')[0]
                s = set(base['conjuntos'].get(real, []))
                s.discard(item)
                base['conjuntos'][real] = sorted(s)
            elif chave in ('padrao', 'tmp_exec', 'ssh_hora'):
                base['conjuntos'].setdefault('aceites_' + chave, [])
                base['conjuntos']['aceites_' + chave] = sorted(set(base['conjuntos']['aceites_' + chave]) | {item})
            else:
                s = set(base['conjuntos'].get(chave, []))
                s.add(item)
                base['conjuntos'][chave] = sorted(s)
            aprendidos.append(a['id'])
        elif a['id'] in aceites_ids:
            aprendidos.append(a['id'])      # sem o que aprender: só silencia
        else:
            restantes.append(a)
    return restantes, aprendidos


def filtrar_aceites_fixos(achados, base):
    """Itens já aceites (padrões, tmp, horas) não voltam a alertar."""
    out = []
    for a in achados:
        ap = a.get('aprender')
        if ap and ap[0] in ('padrao', 'tmp_exec', 'ssh_hora'):
            if ap[1] in base['conjuntos'].get('aceites_' + ap[0], []):
                continue
        out.append(a)
    return out


def estado_global(achados):
    if any(a['gravidade'] == 'critico' for a in achados):
        return 'critico'
    if any(a['gravidade'] == 'atencao' for a in achados):
        return 'atencao'
    return 'ok'


def pontuacao(achados):
    return min(100, sum(GRAV_PESO.get(a['gravidade'], 0) for a in achados))


# =============================================================================
# avisos
# =============================================================================
def enviar_telegram(conf, texto):
    token = conf.get('TELEGRAM_BOT_TOKEN')
    chat = conf.get('TELEGRAM_CHAT_ID')
    if not token or not chat:
        return False
    try:
        dados = urllib.parse.urlencode({'chat_id': chat, 'text': texto[:3800]}).encode()
        urllib.request.urlopen(
            urllib.request.Request(f'https://api.telegram.org/bot{token}/sendMessage', data=dados), timeout=15)
        return True
    except Exception:
        return False


def texto_alerta(novos, nome_servidor):
    linhas = [f'🔐 Vigia gc_turnkey ({nome_servidor})']
    for a in novos[:8]:
        icone = '🚨' if a['gravidade'] == 'critico' else '⚠️'
        linhas.append(f'{icone} {a["titulo"]}' + (f' — {a["detalhe"]}' if a['detalhe'] else ''))
    linhas.append('Abre a app: Configurações → Segurança e backups.')
    return '\n'.join(linhas)


# =============================================================================
# ronda
# =============================================================================
VERIFICACOES = [
    # nome, a cada quantos segundos
    ('ssh', 600), ('processos', 600), ('rede', 600), ('pb', 600),
    ('contas', 3600), ('persistencia', 3600), ('app', 3600),
    ('tmp_exec', 3600), ('suid', 86400), ('higiene', 86400),
]


def correr(cfg, forcar=False, simular=None, agora=None, enviar=True):
    agora = agora or int(time.time())
    est_dir = cfg.estado_dir
    base_p = os.path.join(est_dir, 'baseline.json')
    hist_p = os.path.join(est_dir, 'historico.json')
    run_p = os.path.join(est_dir, 'rondas.json')
    saida_p = os.path.join(cfg.dados, 'seguranca_vigia.json')
    base = carregar_json(base_p, None)
    hist = carregar_json(hist_p, {})
    rondas = carregar_json(run_p, {'ultimo': {}, 'alertados': {}, 'ssh_ate': agora - 900, 'aceites_vistos': []})
    primeira = base is None
    if primeira:
        rondas['ssh_ate'] = agora - 30 * 86400   # aprende com o último mês de entradas
    if primeira:
        base = {'conjuntos': {}, 'app': {}}
    verif = {}
    factos = {}
    if simular is not None:
        factos = simular
    else:
        for nome, cada in VERIFICACOES:
            if not forcar and not primeira and agora - rondas['ultimo'].get(nome, 0) < cada - 30:
                continue
            try:
                if nome == 'ssh':
                    factos['ssh'] = coletar_ssh(cfg, rondas.get('ssh_ate', agora - 900))
                elif nome == 'contas':
                    factos.update(coletar_contas(cfg))
                elif nome == 'persistencia':
                    factos.update(coletar_persistencia(cfg))
                elif nome == 'rede':
                    factos.update(coletar_rede(cfg))
                elif nome == 'processos':
                    factos.update(coletar_processos(cfg))
                elif nome == 'suid':
                    factos.update(coletar_suid(cfg))
                elif nome == 'tmp_exec':
                    factos.update(coletar_tmp_exec(cfg))
                elif nome == 'app':
                    factos.update(coletar_app(cfg))
                elif nome == 'pb':
                    factos.update(coletar_pb(cfg, rondas['ultimo'].get('pb', agora - 900)))
                elif nome == 'higiene':
                    factos['higiene'] = coletar_higiene(cfg)
                verif[nome] = {'ok': True, 'quando': agora}
                rondas['ultimo'][nome] = agora
            except Exception as e:
                verif[nome] = {'ok': False, 'quando': agora, 'erro': str(e)[:120]}
        rondas['ssh_ate'] = agora
    anteriores = carregar_json(saida_p, {}).get('achados', [])
    todas = primeira or forcar or simular is not None
    reavaliadas = {n for n, _ in VERIFICACOES} if todas else {n for n, v in verif.items() if v.get('ok')}
    achados, base, hist, notas = analisar(
        factos, base, hist, agora, cfg_ips=cfg.lista('IPS_PERMITIDOS'), primeira=primeira,
        anteriores=anteriores, reavaliadas=reavaliadas)
    achados = filtrar_aceites_fixos(achados, base)

    # "já verifiquei" vindos da app (ficheiro escrito pelo PocketBase)
    acks = carregar_json(os.path.join(cfg.dados, 'seguranca_acks.json'), {'ids': []})
    novos_ids = []
    for x in acks.get('ids', []):
        chave = f"{x.get('id')}@{x.get('quando')}"
        if chave not in rondas['aceites_vistos']:
            novos_ids.append(x.get('id'))
            rondas['aceites_vistos'].append(chave)
    rondas['aceites_vistos'] = rondas['aceites_vistos'][-500:]
    if novos_ids:
        # consumidos: esvazia o ficheiro (no mesmo ficheiro, para manter o dono
        # e as permissões) — assim a app só mostra "a aprender" até à ronda seguinte
        try:
            with open(os.path.join(cfg.dados, 'seguranca_acks.json'), 'w', encoding='utf-8') as fh:
                json.dump({'ids': []}, fh)
        except Exception:
            pass
    com_aprender = {a['id'] for a in achados if a.get('aprender')}
    silenciados = rondas.setdefault('silenciados', {})
    for i in novos_ids:
        if i not in com_aprender:
            silenciados[i] = agora + 86400      # sem nada a aprender: cala 24 h
    for k in [k for k, ate in silenciados.items() if ate <= agora]:
        del silenciados[k]
    achados, aprendidos = aplicar_aceites(achados, base, factos, set(novos_ids))
    achados = [a for a in achados if a['id'] not in silenciados]

    # datas (desde quando) e novos alertas
    desde = rondas.setdefault('desde', {})
    for a in achados:
        a['desde'] = desde.setdefault(a['id'], agora)
        a['vezes'] = rondas.setdefault('vezes', {}).get(a['id'], 0) + 1
    for k in list(desde):
        if k not in {a['id'] for a in achados}:
            del desde[k]
    rondas['vezes'] = {a['id']: a['vezes'] for a in achados}
    alertados = rondas.setdefault('alertados', {})
    novos = [a for a in achados if a['gravidade'] in ('critico', 'atencao') and a['id'] not in alertados]
    for a in novos:
        alertados[a['id']] = agora
    for k in list(alertados):
        if k not in {a['id'] for a in achados}:
            del alertados[k]
    if enviar and novos and not primeira:
        nome = sh(['hostname']).strip() or 'servidor'
        enviar_telegram(cfg.conf, texto_alerta(novos, nome))

    achados.sort(key=lambda a: ({'critico': 0, 'atencao': 1, 'info': 2}[a['gravidade']], a['desde']))
    resultado = {
        'versao': VERSAO_VIGIA,
        'quando': agora,
        'estado': estado_global(achados),
        'pontuacao': pontuacao(achados),
        'achados': [{k: a[k] for k in ('id', 'gravidade', 'categoria', 'titulo', 'detalhe', 'fazer', 'desde', 'vezes', 'itens')} for a in achados],
        'verificacoes': {**{k: v for k, v in (carregar_json(saida_p, {}).get('verificacoes', {})).items()}, **verif},
        'notas': notas,
        'baseline_criado': primeira,
    }
    gravar_json(base_p, base)
    gravar_json(hist_p, hist)
    gravar_json(run_p, rondas)
    gravar_json(saida_p, resultado, modo=0o644)
    return resultado


def principal():
    ap = argparse.ArgumentParser(description='Vigia de segurança do gc_turnkey')
    ap.add_argument('comando', nargs='?', default='correr', choices=['correr', 'aceitar', 'estado'])
    ap.add_argument('--tudo', action='store_true', help='corre todas as verificações já')
    ap.add_argument('--simular', help='ficheiro JSON com factos (testes/demonstração)')
    ap.add_argument('--raiz', default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    ap.add_argument('--dados', default=None)
    ap.add_argument('--estado-dir', default='/var/lib/gc_turnkey-vigia')
    ap.add_argument('--conf', default='/etc/gc_turnkey-vigia.conf')
    ap.add_argument('--sem-aviso', action='store_true')
    a = ap.parse_args()
    dados = a.dados or os.path.join(a.raiz, 'data')
    cfg = Config(a.raiz, dados, a.estado_dir, carregar_conf(a.conf))
    if a.comando == 'estado':
        print(json.dumps(carregar_json(os.path.join(dados, 'seguranca_vigia.json'), {}), ensure_ascii=False, indent=1))
        return 0
    if a.comando == 'aceitar':
        for n in ('baseline.json',):
            try:
                os.remove(os.path.join(cfg.estado_dir, n))
            except FileNotFoundError:
                pass
        print('O estado atual vai ser aprendido como normal na próxima ronda.')
    simular = None
    if a.simular:
        simular = carregar_json(a.simular, {})
    r = correr(cfg, forcar=a.tudo or a.comando == 'aceitar', simular=simular, enviar=not a.sem_aviso)
    print(f"Vigia: {r['estado']} — {len(r['achados'])} achado(s), pontuação {r['pontuacao']}")
    for x in r['achados']:
        print(f"  [{x['gravidade']}] {x['titulo']} — {x['detalhe']}")
    return 0


if __name__ == '__main__':
    try:
        sys.exit(principal())
    except KeyboardInterrupt:
        sys.exit(130)
