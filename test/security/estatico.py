#!/usr/bin/env python3
"""Verificações estáticas de segurança (sem servidor): segredos no repositório
e no histórico, ficheiros sensíveis fora do git, hooks que devolvem erros em
bruto, opções de desenvolvimento, versões.

    python test/security/estatico.py
"""
import os
import re
import subprocess
import sys

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
os.chdir(RAIZ)
falhas = 0


def git(*a):
    return subprocess.run(['git', *a], capture_output=True, text=True, encoding='utf-8', errors='replace').stdout


def falha(msg):
    global falhas
    falhas += 1
    print('  FALHA ', msg)


def ok(msg):
    print('  OK    ', msg)


def aviso(msg):
    print('  AVISO ', msg)


PADROES = {
    'chave Google/Gemini': r'AIza[0-9A-Za-z_\-]{35}',
    'chave Anthropic/OpenAI': r'sk-(?:ant-|proj-)?[A-Za-z0-9_\-]{30,}',
    'chave privada': r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
    'token GitHub': r'gh[pousr]_[A-Za-z0-9]{30,}',
    'AWS': r'AKIA[0-9A-Z]{16}',
    'atribuição de segredo': r'(?i)(api[_-]?key|secret|token|passw(?:or)?d)\s*[:=]\s*["\'][A-Za-z0-9_\-/+=]{20,}["\']',
}

print('== Segredos nos ficheiros seguidos pelo git')
ficheiros = [f for f in git('ls-files').splitlines()
             if not f.endswith(('.png', '.jpg', '.ico', '.xlsx', '.ttf', '.otf', '.lock', '.exe', '.dill'))]
achados = []
for f in ficheiros:
    try:
        txt = open(f, encoding='utf-8', errors='ignore').read()
    except OSError:
        continue
    for nome, pad in PADROES.items():
        for m in re.finditer(pad, txt):
            linha = txt[:m.start()].count('\n') + 1
            achados.append((f, linha, nome))
# valores de exemplo (.env.example, testes) não contam
achados = [a for a in achados if '.example' not in a[0] and 'test/' not in a[0].replace('\\', '/')
           and 'seguranca.py' not in a[0] and 'estatico.py' not in a[0]]
if achados:
    for a in achados:
        falha(f'{a[0]}:{a[1]} parece conter {a[2]}')
else:
    ok('nenhum segredo nos ficheiros atuais')

print('== Segredos no histórico do git')
hist = git('log', '--all', '-p', '--no-color', '-U0')
achados = set()
for nome, pad in PADROES.items():
    for m in re.finditer(pad, hist):
        trecho = hist[max(0, m.start() - 200):m.start()]
        ficheiro = re.findall(r'\+\+\+ b/(\S+)', trecho)
        f = ficheiro[-1] if ficheiro else '?'
        if '.example' in f or 'seguranca.py' in f or 'estatico.py' in f or f.startswith('test/'):
            continue
        achados.add((f, nome))
if achados:
    for f, nome in sorted(achados):
        falha(f'histórico: {f} contém {nome} (rodar a chave; apagar do histórico se o repositório for partilhado)')
else:
    ok('nada no histórico')

print('== Ficheiros sensíveis fora do git')
seguidos = git('ls-files')
for padrao in ('pb/.env', 'pb/pb_data', '.env'):
    if any(l == padrao or l.startswith(padrao + '/') for l in seguidos.splitlines()):
        falha(f'{padrao} está no git')
    else:
        ok(f'{padrao} não está no git')
gi = ''
for g in ('.gitignore', 'pb/.gitignore'):
    if os.path.exists(g):
        gi += open(g, encoding='utf-8', errors='ignore').read()
for alvo in ('.env', 'pb_data'):
    (ok if alvo in gi else falha)(f'.gitignore ignora {alvo}')

print('== Hooks: erros devolvidos ao cliente')
for f in sorted(os.listdir('pb/hooks')):
    if not f.endswith('.js'):
        continue
    txt = open(os.path.join('pb/hooks', f), encoding='utf-8', errors='ignore').read()
    # mensagens em bruto de erros de rede/IA para dentro de uma resposta
    for m in re.finditer(r'(BadRequestError|ApiError|InternalServerError|json)\s*\([^;]*?(err|error|ex)\.(message|toString)|String\((err|error|ex)\)', txt):
        linha = txt[:m.start()].count('\n') + 1
        aviso(f'{f}:{linha} pode devolver a mensagem de um erro em bruto (pode conter URL/chave) — confirmar')
    if re.search(r'console\.log\([^)]*(getenv|API_KEY|apiKey|Authorization)', txt):
        falha(f'{f}: escreve uma chave/cabeçalho nos logs')
print('  (feito)')

print('== Opções de desenvolvimento')
sv = open('pb/serve.ps1', encoding='utf-8', errors='ignore').read() if os.path.exists('pb/serve.ps1') else ''
if 'GC_TURNKEY_DEV' in sv:
    aviso('pb/serve.ps1 liga GC_TURNKEY_DEV=1 (contas novas ficam verificadas) — em produção NÃO usar (ver docs/SEGURANCA.md)')
ex = open('pb/.env.example', encoding='utf-8', errors='ignore').read() if os.path.exists('pb/.env.example') else ''
if re.search(r'GC_TURNKEY_DEV\s*=\s*1', ex):
    falha('pb/.env.example liga GC_TURNKEY_DEV=1')

print('== Versões')
v = subprocess.run([os.path.join('pb', 'bin', 'pocketbase.exe' if os.name == 'nt' else 'pocketbase'), '--version'],
                   capture_output=True, text=True).stdout.strip()
print('  PocketBase:', v, '(confirmar em https://github.com/pocketbase/pocketbase/releases se há versão de segurança mais nova)')

print(f'\n== Resumo: {falhas} falha(s)')
sys.exit(1 if falhas else 0)
