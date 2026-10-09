"""Servidor de ENSAIO local (PocketBase descartável) para ver a app no browser.

    python scripts/ensaio.py            # arranca (cria a conta de teste se faltar)
    python scripts/ensaio.py --build    # compila a app web antes de arrancar
    python scripts/ensaio.py parar      # pára o servidor

Fica tudo em `.ensaio/` (fora do git): a base de dados, o registo, o PID e as
credenciais de teste (`.ensaio/credenciais.txt`, geradas ao acaso, só valem
neste servidor). A app serve-se em http://127.0.0.1:8813 (pasta `build/web`).

Para ligar a IA ou outras chaves só no ensaio, põe linhas CHAVE=valor em
`.ensaio/env` (por exemplo GEMINI_API_KEY=...).
Só biblioteca padrão do Python.
"""
import json
import os
import secrets
import signal
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

for _f in (sys.stdout, sys.stderr):
    try:
        _f.reconfigure(encoding='utf-8')  # acentos certos na consola do Windows
    except Exception:
        pass

RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
ENS = os.path.join(RAIZ, '.ensaio')
DADOS = os.path.join(ENS, 'pb')
PID = os.path.join(ENS, 'pb.pid')
LOG = os.path.join(ENS, 'pb.log')
CRED = os.path.join(ENS, 'credenciais.txt')
ENVF = os.path.join(ENS, 'env')
PORTA = 8813
BASE = f'http://127.0.0.1:{PORTA}'
PB = os.path.join(RAIZ, 'pb', 'bin', 'pocketbase.exe' if os.name == 'nt' else 'pocketbase')


def chamar(metodo, caminho, corpo=None, token=None):
    req = urllib.request.Request(
        BASE + caminho,
        data=json.dumps(corpo).encode() if corpo is not None else None,
        method=metodo,
        headers={'Content-Type': 'application/json', **({'Authorization': token} if token else {})},
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return json.loads(r.read() or b'null')
    except urllib.error.HTTPError as e:
        raise RuntimeError(f'{metodo} {caminho} -> {e.code} {e.read().decode()[:200]}')


def a_correr():
    try:
        urllib.request.urlopen(BASE + '/api/health', timeout=2)
        return True
    except Exception:
        return False


def ler_env():
    env = dict(os.environ)
    env['GC_TURNKEY_DEV'] = '1'  # contas novas ficam verificadas (só no ensaio!)
    if os.path.exists(ENVF):
        for linha in open(ENVF, encoding='utf-8'):
            t = linha.strip()
            if t and not t.startswith('#') and '=' in t:
                k, v = t.split('=', 1)
                env[k.strip()] = v.strip()
    return env


def parar():
    if os.path.exists(PID):
        try:
            pid = int(open(PID).read().strip())
            if os.name == 'nt':
                subprocess.run(['taskkill', '/PID', str(pid), '/F'], capture_output=True)
            else:
                os.kill(pid, signal.SIGTERM)
            print('servidor de ensaio parado')
        except Exception as e:
            print('não consegui parar:', e)
        os.remove(PID)
    else:
        print('não há servidor de ensaio a correr (sem .ensaio/pb.pid)')


def credenciais():
    if os.path.exists(CRED):
        d = dict(l.strip().split('=', 1) for l in open(CRED, encoding='utf-8') if '=' in l)
        return d
    d = {
        'SUPER_EMAIL': 'ensaio@super.test',
        'SUPER_SENHA': secrets.token_urlsafe(14),
        'USER_EMAIL': 'ensaio@loja.test',
        'USER_SENHA': secrets.token_urlsafe(14),
    }
    with open(CRED, 'w', encoding='utf-8') as f:
        for k, v in d.items():
            f.write(f'{k}={v}\n')
    return d


def arrancar(compilar):
    os.makedirs(ENS, exist_ok=True)
    if compilar:
        print('a compilar a app web (cerca de 1 minuto)…')
        import re
        pub = open(os.path.join(RAIZ, 'pubspec.yaml'), encoding='utf-8').read()
        versao = re.search(r'^version:\s*(\d+\.\d+\.\d+)', pub, re.M).group(1)
        subprocess.run(
            ['flutter', 'build', 'web', '--release', '--dart-define=PB_URL=origin', f'--dart-define=APP_VERSION={versao}'],
            cwd=RAIZ, check=True, shell=(os.name == 'nt'),
        )
    if not os.path.isdir(os.path.join(RAIZ, 'build', 'web')):
        sys.exit('falta build/web: corre com --build')
    cred = credenciais()
    comum = ['--dir', DADOS, '--hooksDir', os.path.join(RAIZ, 'pb', 'hooks'), '--migrationsDir', os.path.join(RAIZ, 'pb', 'migrations')]
    env = ler_env()
    if not a_correr():
        # superutilizador (cria/atualiza) e arranque
        subprocess.run([PB, 'superuser', 'upsert', cred['SUPER_EMAIL'], cred['SUPER_SENHA']] + comum, cwd=RAIZ, env=env, capture_output=True)
        log = open(LOG, 'ab')
        flags = (0x00000008 | 0x00000200) if os.name == 'nt' else 0  # DETACHED | NEW_PROCESS_GROUP
        p = subprocess.Popen(
            [PB, 'serve', f'--http=127.0.0.1:{PORTA}', '--publicDir', os.path.join(RAIZ, 'build', 'web')] + comum,
            cwd=RAIZ, env=env, stdout=log, stderr=log, creationflags=flags,
        )
        open(PID, 'w').write(str(p.pid))
        for _ in range(60):
            if a_correr():
                break
            time.sleep(0.5)
        else:
            sys.exit(f'o servidor não arrancou; vê {LOG}')
    # conta de teste (proprietária de uma empresa de teste)
    su = chamar('POST', '/api/collections/_superusers/auth-with-password', {'identity': cred['SUPER_EMAIL'], 'password': cred['SUPER_SENHA']})['token']
    achados = chamar('GET', '/api/collections/users/records?perPage=1&filter=' + urllib.parse.quote(f'email="{cred["USER_EMAIL"]}"'), token=su)['items']
    if not achados:
        chamar('POST', '/api/collections/users/records', {
            'email': cred['USER_EMAIL'], 'password': cred['USER_SENHA'], 'passwordConfirm': cred['USER_SENHA'], 'nome': 'Ensaio',
        })
        achados = chamar('GET', '/api/collections/users/records?perPage=1&filter=' + urllib.parse.quote(f'email="{cred["USER_EMAIL"]}"'), token=su)['items']
    u = achados[0]
    if not u.get('aprovado'):
        chamar('PATCH', f'/api/collections/users/records/{u["id"]}', {'aprovado': True}, token=su)
    if not u.get('empresa'):
        tok = chamar('POST', '/api/collections/users/auth-with-password', {'identity': cred['USER_EMAIL'], 'password': cred['USER_SENHA']})['token']
        chamar('POST', '/api/gc_turnkey/onboarding', {'nome': 'Loja de Ensaio', 'moeda': 'EUR', 'regra': 'cima'}, token=tok)
    print(f'\nServidor de ensaio a correr: {BASE}/')
    print(f'  Conta da app:  {cred["USER_EMAIL"]}  /  {cred["USER_SENHA"]}')
    print(f'  Superutilizador ({BASE}/_/): {cred["SUPER_EMAIL"]}  /  {cred["SUPER_SENHA"]}')
    print('  Parar: python scripts/ensaio.py parar')


if __name__ == '__main__':
    args = sys.argv[1:]
    if 'parar' in args:
        parar()
    else:
        arrancar('--build' in args)
