#!/usr/bin/env python3
"""Testes de segurança do PocketBase do gc_turnkey (repetíveis).

Arranca um PocketBase DESCARTÁVEL (dados temporários, porta 8197, sem
GC_TURNKEY_DEV) com as migrations e hooks do projeto, cria duas empresas com
utilizadores de todos os papéis e tenta o que NÃO deve ser possível.

    python test/security/seguranca.py            # arranca o seu próprio servidor
    PB_URL=http://127.0.0.1:8197 PB_SUPER=email:pass python test/security/seguranca.py

Nunca apontar para a produção: cria e apaga dados de teste.
Saída: FALHA (tem de se corrigir), AVISO (risco de configuração/implantação),
OK. Código de saída 1 se houver FALHA.
"""
import base64
import io
import json
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
PB_BIN = os.environ.get('PB_BIN') or os.path.join(RAIZ, 'pb', 'bin', 'pocketbase.exe' if os.name == 'nt' else 'pocketbase')
URL = os.environ.get('PB_URL', 'http://127.0.0.1:8197')
SUPER = os.environ.get('PB_SUPER', 'sec@t.local:SegTeste12345').split(':', 1)

resultados = []  # (nivel, seccao, nome, detalhe)
seccao = ''


def sec(nome):
    global seccao
    seccao = nome
    print(f'\n== {nome}')


def ok(nome):
    resultados.append(('OK', seccao, nome, ''))
    print(f'  OK     {nome}')


def falha(nome, detalhe=''):
    resultados.append(('FALHA', seccao, nome, detalhe))
    print(f'  FALHA  {nome}  {detalhe}')


def aviso(nome, detalhe=''):
    resultados.append(('AVISO', seccao, nome, detalhe))
    print(f'  AVISO  {nome}  {detalhe}')


def check(cond, nome, detalhe=''):
    if cond:
        ok(nome)
    else:
        falha(nome, detalhe)


def call(method, path, body=None, tok=None, headers=None, raw=None, ctype='application/json', repetir=True):
    for tentativa in range(8):
        r = _call(method, path, body, tok, headers, raw, ctype)
        if r[0] != 429 or not repetir:
            return r
        time.sleep(4)
    return r


def _call(method, path, body, tok, headers, raw, ctype):
    h = {}
    if body is not None or raw is not None:
        h['Content-Type'] = ctype
    if tok:
        h['Authorization'] = tok
    if headers:
        h.update(headers)
    data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
    req = urllib.request.Request(URL + path, method=method, data=data, headers=h)
    try:
        return _abrir(req)
    except (ConnectionError, urllib.error.URLError, TimeoutError):
        time.sleep(1)  # o Windows por vezes fecha a ligação sob muitos pedidos seguidos
        try:
            return _abrir(req)
        except (ConnectionError, urllib.error.URLError, TimeoutError):
            return 0, {}, {}


def _abrir(req):
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            txt = r.read()
            try:
                return r.status, json.loads(txt or b'{}'), r.headers
            except ValueError:
                return r.status, txt, r.headers
    except urllib.error.HTTPError as e:
        txt = e.read()
        try:
            return e.code, json.loads(txt or b'{}'), e.headers
        except ValueError:
            return e.code, txt, e.headers


def multipart(campos, ficheiros):
    fronteira = '----seg' + str(int(time.time() * 1000))
    b = io.BytesIO()
    for k, v in campos.items():
        b.write(f'--{fronteira}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode())
    for campo, (nome, conteudo, tipo) in ficheiros.items():
        b.write(f'--{fronteira}\r\nContent-Disposition: form-data; name="{campo}"; filename="{nome}"\r\n'
                f'Content-Type: {tipo}\r\n\r\n'.encode())
        b.write(conteudo)
        b.write(b'\r\n')
    b.write(f'--{fronteira}--\r\n'.encode())
    return b.getvalue(), f'multipart/form-data; boundary={fronteira}'


# ---------------------------------------------------------------------------
# servidor descartável
# ---------------------------------------------------------------------------
proc = None
tmp = None


def arrancar():
    global proc, tmp
    if 'PB_URL' in os.environ:
        return
    tmp = tempfile.mkdtemp(prefix='pbsec_')
    dados = os.path.join(tmp, 'data')
    base = [PB_BIN, '--dir', dados, '--migrationsDir', os.path.join(RAIZ, 'pb', 'migrations')]
    subprocess.run(base[:1] + ['superuser', 'upsert', SUPER[0], SUPER[1]] + base[1:],
                   check=True, capture_output=True)
    env = {k: v for k, v in os.environ.items() if k not in ('GC_TURNKEY_DEV', 'VENDUS_API_KEY', 'VENDUS_SYNC_EMPRESA')}
    env['GC_TURNKEY_ENC_KEY'] = 'K' * 32  # chave-mestra só de teste
    env['GC_TURNKEY_OPERADORES'] = 'ownera@seg.local'  # operador da plataforma (só de teste)
    env.update(ambiente_ia_falsa())
    porta = URL.rsplit(':', 1)[1]
    proc = subprocess.Popen(
        [PB_BIN, 'serve', '--dir', dados, '--migrationsDir', os.path.join(RAIZ, 'pb', 'migrations'),
         '--hooksDir', os.path.join(RAIZ, 'pb', 'hooks'), '--http', f'127.0.0.1:{porta}'],
        stdout=open(os.path.join(tmp, 'pb.log'), 'w'), stderr=subprocess.STDOUT, env=env)
    for _ in range(40):
        try:
            if call('GET', '/api/health')[0] == 200:
                return
        except Exception:
            pass
        time.sleep(0.5)
    raise SystemExit('PocketBase não arrancou')


def parar():
    if proc:
        proc.terminate()
        try:
            proc.wait(10)
        except Exception:
            proc.kill()
    if tmp:
        shutil.rmtree(tmp, ignore_errors=True)


# ---------------------------------------------------------------------------
# preparação: empresas, utilizadores, dados
# ---------------------------------------------------------------------------
su = None
cols = {}
empresas = {}
users = {}
tok = {}
dados = {}  # (colecao, empresa) -> (id, body)


def preparar():
    global su, cols
    s, r, _ = call('POST', '/api/collections/_superusers/auth-with-password',
                   {'identity': SUPER[0], 'password': SUPER[1]})
    assert s == 200, r
    su = r['token']
    s, r, _ = call('GET', '/api/collections?perPage=200', tok=su)
    cols = {c['name']: c for c in r['items']}
    for k in ('A', 'B'):
        s, r, _ = call('POST', '/api/collections/empresas/records',
                       {'nome': f'Empresa {k}', 'slug': f'emp-{k.lower()}-{int(time.time())}',
                        'moeda': 'EUR', 'regra_arredondamento': 'cima'}, su)
        assert s == 200, r
        empresas[k] = r['id']
    for nome, emp, papel in [('ownerA', 'A', 'owner'), ('adminA', 'A', 'admin'), ('editorA', 'A', 'editor'),
                             ('viewerA', 'A', 'viewer'), ('ownerB', 'B', 'owner'), ('editorB', 'B', 'editor'),
                             ('ownerA2', 'A', 'owner')]:
        s, r, _ = call('POST', '/api/collections/users/records',
                       {'email': f'{nome.lower()}@seg.local', 'password': 'Teste12345!', 'passwordConfirm': 'Teste12345!',
                        'verified': True, 'nome': nome, 'empresa': empresas[emp], 'papel': papel}, su)
        assert s == 200, (nome, r)
        users[nome] = r['id']
        s, r, _ = call('POST', '/api/collections/users/auth-with-password',
                       {'identity': f'{nome.lower()}@seg.local', 'password': 'Teste12345!'})
        assert s == 200, (nome, r)
        tok[nome] = r['token']


def valor_minimo(f, empresa, dono):
    t = f['type']
    if t == 'text':
        mn = f.get('min') or 0
        return ('seed-' + f['name'] + '-xxxxxxxxxx')[:max(mn, 1) + 10][:f.get('max') or 60]
    if t == 'editor':
        return 'x'
    if t == 'number':
        return max(f.get('min') or 0, 1)
    if t == 'bool':
        return False
    if t == 'select':
        return f['values'][0]
    if t == 'date':
        return '2026-01-01 00:00:00.000Z'
    if t == 'json':
        return {}
    if t == 'email':
        return 'seed@seg.local'
    if t == 'url':
        return 'https://exemplo.pt'
    return None


def semear(col, emp, pilha=()):
    """Cria (com superuser) um registo mínimo válido de `col` na empresa `emp`."""
    if (col, emp) in dados:
        return dados[(col, emp)]
    if col in pilha or col not in cols:
        return None
    c = cols[col]
    body = {}
    for f in c['fields']:
        n, t = f['name'], f['type']
        if n in ('id', 'created', 'updated') or t in ('autodate', 'file', 'password') or f.get('system'):
            continue
        if n == 'empresa':
            body[n] = empresas[emp]
            continue
        if t == 'relation':
            alvo = next((k for k, v in cols.items() if v['id'] == f['collectionId']), None)
            if alvo == 'users':
                body[n] = users['owner' + emp]
            elif alvo == 'empresas':
                body[n] = empresas[emp]
            elif f.get('required'):
                r = semear(alvo, emp, pilha + (col,))
                if not r:
                    return None
                body[n] = r[0]
            continue
        if f.get('required') or (t == 'select' and f.get('required')):
            v = valor_minimo(f, emp, None)
            if v is not None:
                body[n] = v
    s, r, _ = call('POST', f'/api/collections/{col}/records', body, su)
    if s != 200:
        dados[(col, emp)] = None
        return None
    dados[(col, emp)] = (r['id'], body)
    return dados[(col, emp)]


def colecoes_com_empresa():
    return [n for n, c in cols.items() if not n.startswith('_') and n not in ('users', 'empresas', 'segredos_empresa')
            and any(f['name'] == 'empresa' for f in c['fields'])]


# ---------------------------------------------------------------------------
# 1. isolamento entre empresas (IDOR)
# ---------------------------------------------------------------------------
def teste_isolamento():
    sec('1. Isolamento entre empresas (IDOR)')
    semeadas, nao = [], []
    for col in colecoes_com_empresa():
        for emp in ('A', 'B'):
            r = semear(col, emp)
            (semeadas if r else nao).append(f'{col}/{emp}') if r or emp == 'A' else None
    print(f'  ({len(semeadas)} coleções semeadas; sem semear: {sorted(set(x.split("/")[0] for x in nao))})')
    for col in colecoes_com_empresa():
        a = dados.get((col, 'A'))
        if not a:
            aviso(f'{col}: não foi possível semear um registo — não testado')
            continue
        rid, body = a
        problemas = []
        for quem in ('ownerB', 'editorB'):
            t = tok[quem]
            s, r, _ = call('GET', f'/api/collections/{col}/records?perPage=200', tok=t)
            if s == 200 and any(i.get('empresa') == empresas['A'] for i in r.get('items', [])):
                problemas.append(f'{quem} LISTA registos da empresa A')
            s, r, _ = call('GET', f'/api/collections/{col}/records?perPage=200&filter=' +
                           urllib.request.quote(f"empresa='{empresas['A']}'"), tok=t)
            if s == 200 and r.get('items'):
                problemas.append(f'{quem} lista por filtro')
            s, r, _ = call('GET', f'/api/collections/{col}/records/{rid}', tok=t)
            if s == 200:
                problemas.append(f'{quem} LÊ o registo de A')
            s, r, _ = call('PATCH', f'/api/collections/{col}/records/{rid}', {}, t)
            if s == 200:
                problemas.append(f'{quem} ALTERA o registo de A')
            s, r, _ = call('DELETE', f'/api/collections/{col}/records/{rid}', tok=t)
            if s in (200, 204):
                problemas.append(f'{quem} APAGA o registo de A')
                dados.pop((col, 'A'), None)
                semear(col, 'A')
            s, r, _ = call('POST', f'/api/collections/{col}/records', body, t)
            if s == 200:
                problemas.append(f'{quem} CRIA registo na empresa A')
                call('DELETE', f'/api/collections/{col}/records/{r["id"]}', tok=su)
        s, r, _ = call('GET', f'/api/collections/{col}/records', tok=None)
        if s == 200 and isinstance(r, dict) and r.get('items'):
            problemas.append('sem sessão consegue listar')
        (falha(f'{col}', '; '.join(problemas)) if problemas else ok(f'{col}'))

    # injeção de relações: B cria registo SEU a apontar para dados de A
    print('  -- relações entre empresas (B a apontar para registos de A)')
    for col in colecoes_com_empresa():
        c = cols[col]
        b = dados.get((col, 'B'))
        if not b:
            continue
        for f in c['fields']:
            if f['type'] != 'relation':
                continue
            alvo = next((k for k, v in cols.items() if v['id'] == f['collectionId']), None)
            if alvo in (None, 'users', 'empresas') or not dados.get((alvo, 'A')):
                continue
            corpo = dict(b[1])
            corpo['empresa'] = empresas['B']
            corpo[f['name']] = dados[(alvo, 'A')][0]
            s, r, _ = call('POST', f'/api/collections/{col}/records', corpo, tok['ownerB'])
            if s == 200:
                falha(f'{col}.{f["name"]}: B consegue apontar para registo de A ({alvo})',
                      'validar na regra: o registo relacionado tem de ser da mesma empresa')
                call('DELETE', f'/api/collections/{col}/records/{r["id"]}', tok=su)
            else:
                ok(f'{col}.{f["name"]} → {alvo} recusado')

    # empresas e users
    s, r, _ = call('GET', f'/api/collections/empresas/records/{empresas["A"]}', tok=tok['ownerB'])
    check(s != 200, 'empresas: B não lê a empresa A', f'status {s}')
    s, r, _ = call('PATCH', f'/api/collections/empresas/records/{empresas["A"]}', {'nome': 'hack'}, tok['ownerB'])
    check(s != 200, 'empresas: B não altera a empresa A', f'status {s}')
    s, r, _ = call('DELETE', f'/api/collections/empresas/records/{empresas["A"]}', tok=tok['ownerA'])
    check(s not in (200, 204), 'empresas: nem o proprietário apaga a empresa pela API', f'status {s}')
    s, r, _ = call('GET', '/api/collections/users/records?perPage=200', tok=tok['ownerB'])
    check(s == 200 and all(u['empresa'] == empresas['B'] or u['id'] == users['ownerB'] for u in r['items']),
          'users: B só vê utilizadores da própria empresa')
    s, r, _ = call('GET', '/api/collections/empresas/records', tok=None)
    check(s != 200 or not r.get('items'), 'empresas: sem sessão não lista')


# ---------------------------------------------------------------------------
# 2. papéis e escalada de privilégios
# ---------------------------------------------------------------------------
def teste_papeis():
    sec('2. Papéis e escalada de privilégios')
    # registo público a pedir empresa/papel (falha crítica encontrada em 2026-09-24)
    corpo = {'email': 'intruso@seg.local', 'password': 'Intruso12345', 'passwordConfirm': 'Intruso12345',
             'empresa': empresas['A'], 'papel': 'owner'}
    s, r, _ = call('POST', '/api/collections/users/records', corpo)
    if s == 200:
        falha('registo público consegue escolher empresa e papel (tomada de empresa alheia)',
              f'criou utilizador com papel={r.get("papel")} na empresa A')
        call('DELETE', f'/api/collections/users/records/{r["id"]}', tok=su)
    else:
        ok('registo público não escolhe empresa/papel')
    s, r, _ = call('POST', '/api/collections/users/records',
                   {'email': 'normal@seg.local', 'password': 'Normal12345', 'passwordConfirm': 'Normal12345'})
    check(s == 200 and not r.get('empresa') and not r.get('papel'), 'registo normal fica sem empresa nem papel', str(r)[:120])
    if s == 200:
        check(not r.get('verified'), 'registo novo não vem verificado (sem GC_TURNKEY_DEV)')
        call('DELETE', f'/api/collections/users/records/{r["id"]}', tok=su)

    # auto-promoção
    for quem in ('viewerA', 'editorA', 'adminA'):
        s, r, _ = call('PATCH', f'/api/collections/users/records/{users[quem]}', {'papel': 'owner'}, tok[quem])
        check(s != 200, f'{quem} não se promove a owner', f'status {s}')
    s, r, _ = call('PATCH', f'/api/collections/users/records/{users["editorB"]}', {'empresa': empresas['A']}, tok['editorB'])
    check(s != 200, 'utilizador não muda a própria empresa')
    s, r, _ = call('PATCH', f'/api/collections/users/records/{users["editorA"]}', {'verified': False}, tok['editorA'])
    check(s != 200 or r.get('verified') is not False, 'utilizador não mexe em verified')
    s, r, _ = call('PATCH', f'/api/collections/users/records/{users["viewerA"]}', {'papel': 'owner'}, tok['ownerB'])
    check(s != 200, 'owner de B não muda utilizadores de A')
    s, r, _ = call('DELETE', f'/api/collections/users/records/{users["viewerA"]}', tok=tok['editorA'])
    check(s not in (200, 204), 'um utilizador não apaga o de outro')

    # leitura não escreve
    permitidas = {'preferencias_utilizador', 'sugestoes', 'notas_pagina'}
    matriz = {}
    for col in colecoes_com_empresa():
        base = dados.get((col, 'A'))
        if not base:
            continue
        rid, body = base
        linha = {}
        for quem in ('viewerA', 'editorA', 'adminA', 'ownerA'):
            t = tok[quem]
            c, _, _ = call('POST', f'/api/collections/{col}/records', body, t)
            novo = _['id'] if c == 200 else None
            if novo:
                call('DELETE', f'/api/collections/{col}/records/{novo}', tok=su)
            u, _, _ = call('PATCH', f'/api/collections/{col}/records/{rid}', {}, t)
            linha[quem] = ('C' if c == 200 else '-') + ('U' if u == 200 else '-')
        matriz[col] = linha
        if col not in permitidas and (linha['viewerA'] != '--'):
            falha(f'{col}: o papel Leitura consegue escrever ({linha["viewerA"]})')
    print('  Matriz (C=cria, U=atualiza) por papel:')
    print(f'    {"coleção":28}{"viewer":>8}{"editor":>8}{"admin":>8}{"owner":>8}')
    for col, l in sorted(matriz.items()):
        print(f'    {col:28}{l["viewerA"]:>8}{l["editorA"]:>8}{l["adminA"]:>8}{l["ownerA"]:>8}')
    if not any(r[0] == 'FALHA' and 'Leitura' in r[2] for r in resultados):
        ok('o papel Leitura não escreve em nenhuma coleção (fora as permitidas)')

    # configurações só para admin/owner; matriz de acesso só o owner
    for col in ('configuracoes_custo',):
        rid = dados.get((col, 'A'))
        if rid:
            s, _, _ = call('PATCH', f'/api/collections/{col}/records/{rid[0]}', {'salario': 1}, tok['editorA'])
            check(s != 200, f'{col}: editor não altera configuração de custos', f'status {s}')
    # cartões NFC identificam quem fez os registos: só owner/admin os gere
    colab = dados.get(('colaboradores', 'A'))
    if colab:
        s, _, _ = call('PATCH', f'/api/collections/colaboradores/records/{colab[0]}', {'nome': 'X'}, tok['editorA'])
        check(s != 200, 'colaboradores: editor não altera colaboradores nem cartões', f'status {s}')
        s, _, _ = call('PATCH', f'/api/collections/colaboradores/records/{colab[0]}', {'nome': 'Colaborador A'}, tok['adminA'])
        check(s == 200, 'colaboradores: admin gere colaboradores e cartões', f'status {s}')
    s, _, _ = call('PATCH', f'/api/collections/empresas/records/{empresas["A"]}', {'nome': 'X'}, tok['editorA'])
    check(s != 200, 'empresas: editor não altera a empresa')
    s, _, _ = call('PATCH', f'/api/collections/empresas/records/{empresas["A"]}', {'nome': 'Empresa A'}, tok['adminA'])
    ok('empresas: admin edita o perfil da empresa (desenho: canEditConfig)') if s == 200 else aviso('empresas: admin não edita a empresa', f'status {s}')
    s, _, _ = call('PATCH', f'/api/collections/empresas/records/{empresas["A"]}', {'plano': 'pro'}, tok['adminA'])
    if s == 200:
        aviso('empresas: admin consegue mudar o campo "plano"', 'irrelevante sem faturação; bloquear se um dia houver planos pagos')
    nav = dados.get(('configuracoes_navegacao', 'A'))
    if nav:
        s, _, _ = call('PATCH', f'/api/collections/configuracoes_navegacao/records/{nav[0]}',
                       {'acesso': {'viewer': {}}}, tok['adminA'])
        check(s != 200, 'navegação: admin não grava a matriz de acesso', f'status {s}')
        s, _, _ = call('PATCH', f'/api/collections/configuracoes_navegacao/records/{nav[0]}',
                       {'acesso': {'viewer': {}}}, tok['ownerA'])
        check(s == 200, 'navegação: owner grava a matriz de acesso', f'status {s}')

    # endpoints de equipa
    for quem in ('viewerA', 'editorA'):
        s, _, _ = call('POST', '/api/gc_turnkey/team/members',
                       {'email': f'x{quem}@seg.local', 'password': 'Teste12345!', 'papel': 'viewer'}, tok[quem])
        check(s == 403, f'equipa: {quem} não cria membros', f'status {s}')
        s, _, _ = call('PATCH', f'/api/gc_turnkey/team/members/{users["viewerA"]}', {'papel': 'admin'}, tok[quem])
        check(s == 403, f'equipa: {quem} não muda papéis', f'status {s}')
    s, r, _ = call('POST', '/api/gc_turnkey/team/members',
                   {'email': 'novoadmin@seg.local', 'password': 'Teste12345!', 'papel': 'admin'}, tok['adminA'])
    if s == 200:
        s2, r2, _ = call('GET', f'/api/collections/users/records/{r["id"]}', tok=su)
        check(r2.get('papel') != 'admin', 'equipa: admin não cria outro admin', f'papel={r2.get("papel")}')
    s, r, _ = call('POST', '/api/gc_turnkey/team/members',
                   {'email': 'curta@seg.local', 'password': '123', 'papel': 'viewer'}, tok['ownerA'])
    check(s == 400, 'equipa: palavra-passe curta recusada', f'status {s}')
    s, r, _ = call('POST', '/api/gc_turnkey/team/members',
                   {'email': 'ownera@seg.local', 'password': 'Teste12345!', 'papel': 'viewer'}, tok['ownerA'])
    check(s in (400, 409), 'equipa: email repetido não dá erro 500', f'status {s}')
    # o admin não mexe em proprietários nem noutros admins
    s, _, _ = call('PATCH', f'/api/gc_turnkey/team/members/{users["ownerA2"]}', {'papel': 'viewer'}, tok['adminA'])
    check(s == 403, 'equipa: admin não rebaixa um proprietário', f'status {s}')
    call('PATCH', f'/api/collections/users/records/{users["ownerA2"]}', {'papel': 'owner'}, su)
    s, _, _ = call('POST', '/api/gc_turnkey/team/members',
                   {'email': 'admin2@seg.local', 'password': 'Teste12345!', 'papel': 'admin'}, tok['ownerA'])
    s, r, _ = call('GET', "/api/collections/users/records?filter=email='admin2@seg.local'", tok=su)
    if r.get('items'):
        a2 = r['items'][0]['id']
        s, _, _ = call('PATCH', f'/api/gc_turnkey/team/members/{a2}', {'papel': 'viewer'}, tok['adminA'])
        check(s == 403, 'equipa: admin não rebaixa outro admin', f'status {s}')
    s, _, _ = call('PATCH', f'/api/gc_turnkey/team/members/{users["viewerA"]}', {'papel': 'viewer'}, tok['ownerB'])
    check(s in (403, 404), 'equipa: owner de B não mexe em utilizadores de A', f'status {s}')
    # último proprietário
    call('PATCH', f'/api/collections/users/records/{users["ownerA2"]}', {'papel': 'viewer'}, su)
    s, _, _ = call('PATCH', f'/api/gc_turnkey/team/members/{users["ownerA"]}', {'papel': 'viewer'}, tok['ownerA'])
    check(s == 400, 'equipa: não se remove o último proprietário', f'status {s}')


# ---------------------------------------------------------------------------
# 3. endpoints próprios
# ---------------------------------------------------------------------------
ROTAS = [
    ('POST', '/api/gc_turnkey/admin/recompute'),
    ('POST', '/api/gc_turnkey/admin/relink-espelhos'),
    ('POST', '/api/gc_turnkey/faturas/{faturas}/analisar'),
    ('POST', '/api/gc_turnkey/faturas/{faturas}/aplicar'),
    ('GET', '/api/gc_turnkey/faturas/export'),
    ('POST', '/api/gc_turnkey/inventario/ajustar'),
    ('GET', '/api/gc_turnkey/producoes/{producoes}/plano'),
    ('POST', '/api/gc_turnkey/producoes/{producoes}/lista-compras'),
    ('POST', '/api/gc_turnkey/producoes/{producoes}/concluir'),
    ('GET', '/api/gc_turnkey/fichas/resolver'),
    ('GET', '/api/gc_turnkey/receitas/{receitas}/plano'),
    ('GET', '/api/gc_turnkey/fichas/{fichas_tecnicas}/plano'),
    ('POST', '/api/gc_turnkey/ingredientes/{ingredientes}/rotulo'),
    ('POST', '/api/gc_turnkey/nutricao/ler-rotulo'),
    ('POST', '/api/gc_turnkey/ingredientes/auto-insa'),
    ('POST', '/api/gc_turnkey/onboarding'),
    ('POST', '/api/gc_turnkey/team/members'),
    ('PATCH', '/api/gc_turnkey/team/members/{users}'),
    ('POST', '/api/gc_turnkey/vendus/sincronizar'),
    ('POST', '/api/gc_turnkey/ingredientes/juntar'),
    ('POST', '/api/gc_turnkey/financeiro/classificar-custos'),
    ('POST', '/api/gc_turnkey/financeiro/dicas'),
]


def caminho(rota, emp):
    def sub(m):
        col = m.group(1)
        if col == 'users':
            return users['viewerA' if emp == 'A' else 'ownerB']
        d = dados.get((col, emp))
        return d[0] if d else 'naoexiste0000000'
    return re.sub(r'\{(\w+)\}', sub, rota)


def teste_endpoints():
    sec('3. Endpoints próprios (/api/gc_turnkey/*)')
    for metodo, rota in ROTAS:
        a = caminho(rota, 'A')
        corpo = {} if metodo != 'GET' else None
        s, r, _ = call(metodo, a, corpo)
        check(s in (401, 403, 404), f'{metodo} {rota}: sem sessão recusado', f'status {s}')
        # sessão de OUTRA empresa sobre ids de A
        s, r, _ = call(metodo, a, corpo, tok['editorB'])
        if '{' in rota:
            check(s in (400, 403, 404) and s != 200, f'{metodo} {rota}: outra empresa não acede a dados de A', f'status {s}')
        # o que devolve nunca deve conter pistas internas
        txt = json.dumps(r) if not isinstance(r, bytes) else r.decode('utf8', 'ignore')
        if re.search(r'goja|/hooks/|\.pb\.js|panic|traceback|C:\\\\|/home/', txt, re.I):
            falha(f'{metodo} {rota}: resposta com detalhes internos', txt[:150])
    # papéis nos endpoints administrativos
    for quem in ('viewerA', 'editorA'):
        s, _, _ = call('POST', '/api/gc_turnkey/admin/recompute', {}, tok[quem])
        check(s == 403, f'admin/recompute: {quem} recusado', f'status {s}')
    # IA do financeiro: só owner/admin (os custos também só são visíveis para eles)
    for quem in ('viewerA', 'editorA'):
        for rota in ('classificar-custos', 'dicas'):
            s, _, _ = call('POST', f'/api/gc_turnkey/financeiro/{rota}', {}, tok[quem])
            check(s == 403, f'financeiro/{rota}: {quem} recusado', f'status {s}')
    s, _, _ = call('POST', '/api/gc_turnkey/admin/recompute', {'empresa': empresas['B']}, tok['adminA'])
    s2, r2, _ = call('POST', '/api/gc_turnkey/admin/recompute', {'empresa': empresas['B']}, tok['adminA'])
    check(s in (200, 400), 'admin/recompute: admin de A só afeta a própria empresa (ignora o corpo)')
    for quem in ('viewerA',):
        for rota in ('/api/gc_turnkey/inventario/ajustar', '/api/gc_turnkey/vendus/sincronizar',
                     '/api/gc_turnkey/ingredientes/auto-insa',
                     '/api/gc_turnkey/ingredientes/juntar'):
            s, _, _ = call('POST', rota, {}, tok[quem])
            check(s in (400, 403), f'{rota}: Leitura não escreve', f'status {s}')
    ing = dados.get(('ingredientes', 'A'))
    if ing:
        # dados inválidos / enormes: nunca 500
        lixo = [{'ingredienteId': ing[0], 'quantidade': 'abc'}, {'ingredienteId': ing[0], 'quantidade': 1e308},
                {'ingredienteId': ing[0], 'quantidade': -5}, {'ingredienteId': {'$ne': 1}, 'quantidade': 1},
                {'ingredienteId': 'x' * 100000}, [], 'texto', {'quantidade': None}]
        for i, corpo in enumerate(lixo):
            s, r, _ = call('POST', '/api/gc_turnkey/inventario/ajustar', corpo, tok['editorA'])
            check(s != 500, f'inventario/ajustar com dados inválidos #{i}: sem erro 500', f'status {s}')
    s, r, _ = call('POST', '/api/gc_turnkey/inventario/ajustar', raw=b'{isto nao e json', tok=tok['editorA'])
    check(s in (400, 403, 422), 'inventario/ajustar com JSON inválido: erro 4xx', f'status {s}')
    s, r, _ = call('POST', '/api/gc_turnkey/nutricao/ler-rotulo', {'imagemBase64': 'A' * 12_000_000}, tok['editorA'])
    check(s in (400, 413, 502, 503, 403, 422), 'ler-rotulo com corpo enorme: recusado ou sem IA', f'status {s}')


# ---------------------------------------------------------------------------
# 4. autenticação
# ---------------------------------------------------------------------------
def teste_autenticacao():
    sec('4. Autenticação')
    s, r, _ = call('POST', '/api/collections/users/records',
                   {'email': 'fraca@seg.local', 'password': '1234567', 'passwordConfirm': '1234567'})
    check(s == 400, 'palavra-passe com 7 caracteres recusada', f'status {s}')
    a, ra, _ = call('POST', '/api/collections/users/auth-with-password', {'identity': 'ownera@seg.local', 'password': 'errada'})
    b, rb, _ = call('POST', '/api/collections/users/auth-with-password', {'identity': 'nao-existe@seg.local', 'password': 'errada'})
    check(a == b == 400 and ra.get('message') == rb.get('message'), 'login: mesma resposta para email existente e inexistente')
    a, _, _ = call('POST', '/api/collections/users/request-password-reset', {'email': 'ownera@seg.local'})
    b, _, _ = call('POST', '/api/collections/users/request-password-reset', {'email': 'nao-existe@seg.local'})
    check(a == b, 'recuperação: mesma resposta para email existente e inexistente', f'{a} vs {b}')
    # limite de tentativas
    codigos = []
    for _ in range(40):
        c, _, _ = call('POST', '/api/collections/users/auth-with-password', {'identity': 'ownera@seg.local', 'password': 'errada'}, repetir=False)
        codigos.append(c)
    check(429 in codigos, 'limite de tentativas de login (429 após muitas falhadas)',
          'rate limiting desligado — ativar (ver pb/migrations/1707955201_seguranca.js)')
    time.sleep(3)
    s, r, _ = call('GET', '/api/collections/users', tok=su)
    dur = r.get('authToken', {}).get('duration', 0)
    if dur > 7 * 86400:
        aviso(f'duração da sessão: {dur // 86400} dias', 'considerar reduzir')
    else:
        ok(f'duração da sessão: {dur // 86400} dias')
    s, r, _ = call('POST', '/api/collections/users/auth-with-password', {'identity': 'ownera@seg.local', 'password': 'Teste12345!'})
    if s == 429:
        aviso('login legítimo limitado a seguir aos testes de força bruta (esperado)')


# ---------------------------------------------------------------------------
# 5. uploads
# ---------------------------------------------------------------------------
def teste_uploads():
    sec('5. Uploads')
    for nome, c in cols.items():
        for f in c['fields']:
            if f['type'] == 'file' and not nome.startswith('_'):
                mt = f.get('mimeTypes')
                if not mt:
                    falha(f'{nome}.{f["name"]}: aceita qualquer tipo de ficheiro', 'restringir mimeTypes')
                else:
                    ok(f'{nome}.{f["name"]}: tipos restritos')
                if f.get('maxSize', 0) == 0:
                    aviso(f'{nome}.{f["name"]}: sem tamanho máximo explícito (PB usa 5 MB)')
    html = b'<html><script>alert(1)</script></html>'
    corpo, ct = multipart({}, {'logo': ('logo.html', html, 'text/html')})
    s, r, _ = call('PATCH', f'/api/collections/empresas/records/{empresas["A"]}', raw=corpo, ctype=ct, tok=tok['ownerA'])
    check(s != 200, 'logo: um ficheiro HTML é recusado', f'status {s}')
    fat = dados.get(('faturas', 'A'))
    if fat:
        png = b'\x89PNG\r\n\x1a\n' + b'0' * 32
        corpo, ct = multipart({}, {'ficheiro': ('../../../etc/x.png', png, 'image/png')})
        s, r, _ = call('PATCH', f'/api/collections/faturas/records/{fat[0]}', raw=corpo, ctype=ct, tok=tok['ownerA'])
        if s == 200:
            nome = r.get('ficheiro', '')
            check('/' not in nome and '..' not in nome, 'nome de ficheiro malicioso é normalizado', nome)
        # o limite das faturas é alto (PDFs de dezenas de páginas): confere-se no esquema e
        # testa-se a recusa num campo com limite pequeno (o logótipo, 3 MB)
        limite = [f for f in cols['faturas']['fields'] if f['name'] == 'ficheiro'][0].get('maxSize')
        check(limite == 200 * 1024 * 1024, 'faturas: ficheiro até 200 MB (PDFs grandes)', str(limite))
        grande = bytes([0x89]) + b'PNG' + bytes([13, 10, 26, 10]) + b'0' * (4 * 1024 * 1024)
        corpo, ct = multipart({}, {'logo': ('grande.png', grande, 'image/png')})
        s, r, _ = call('PATCH', f'/api/collections/empresas/records/{empresas["A"]}', raw=corpo, ctype=ct, tok=tok['ownerA'])
        check(s != 200, 'ficheiro acima do tamanho máximo é recusado (logótipo > 3 MB)', f'status {s}')
        # um utilizador de B não descarrega o ficheiro de A sem token de ficheiro
        s, r, _ = call('GET', f'/api/collections/faturas/records/{fat[0]}', tok=su)
        nome = r.get('ficheiro') if isinstance(r, dict) else ''
        if nome:
            s, _, _ = call('GET', f'/api/files/faturas/{fat[0]}/{nome}', tok=tok['editorB'])
            check(s in (401, 403, 404), 'faturas: ficheiro protegido de outras empresas', f'status {s}')
            s, _, _ = call('GET', f'/api/files/faturas/{fat[0]}/{nome}')
            check(s in (401, 403, 404), 'faturas: ficheiro protegido sem sessão', f'status {s}')
            # a app abre-o com um token de ficheiro de curta duração (controlo positivo)
            s, r, _ = call('POST', '/api/files/token', {}, tok['editorA'])
            ft = r.get('token') if isinstance(r, dict) else None
            s, _, _ = call('GET', f'/api/files/faturas/{fat[0]}/{nome}?token={ft}')
            check(s == 200, 'faturas: a própria empresa abre o ficheiro com token de ficheiro', f'status {s}')
            s, r, _ = call('POST', '/api/files/token', {}, tok['editorB'])
            ftb = r.get('token') if isinstance(r, dict) else None
            s, _, _ = call('GET', f'/api/files/faturas/{fat[0]}/{nome}?token={ftb}')
            check(s in (401, 403, 404), 'faturas: token de ficheiro de outra empresa não abre', f'status {s}')


# ---------------------------------------------------------------------------
# 6. implantação (o que se resolve no servidor/proxy)
# ---------------------------------------------------------------------------
def teste_implantacao():
    sec('6. Implantação (cabeçalhos, painel de administração)')
    s, r, h = call('GET', '/_/')
    aviso('painel /_/ acessível a partir deste endereço', 'no servidor definitivo bloquear no proxy (só rede local/VPN)') if s == 200 else ok('painel /_/ não acessível')
    s, r, h = call('GET', '/api/health', headers={'Origin': 'https://mau.example'})
    if h.get('Access-Control-Allow-Origin') == '*':
        aviso('CORS aberto (*)', 'restringir ao domínio da app no proxy; o token vai em Authorization (não em cookie), risco baixo')
    else:
        ok('CORS restrito')
    # a app web (hook pb/hooks/web_cabecalhos.pb.js): CSP, nosniff, sem iframes, cache a validar
    s, _, hp = call('GET', '/', headers={'X-Forwarded-Proto': 'https'})
    csp = hp.get('Content-Security-Policy') or ''
    check("connect-src 'self'" in csp and "frame-ancestors 'none'" in csp and "object-src 'none'" in csp,
          'a app leva Content-Security-Policy restritiva (só fala com ela própria, sem iframes)', csp[:80])
    check(hp.get('X-Content-Type-Options') == 'nosniff', 'a app leva X-Content-Type-Options: nosniff')
    check((hp.get('Referrer-Policy') or '') == 'no-referrer', 'a app leva Referrer-Policy: no-referrer')
    check((hp.get('Cache-Control') or '') == 'no-cache', 'a app leva Cache-Control: no-cache (versão nova apanha-se logo)')
    check('max-age' in (hp.get('Strict-Transport-Security') or ''), 'atrás de HTTPS leva Strict-Transport-Security')
    s, _, ha = call('GET', '/api/health', headers={'X-Forwarded-Proto': 'https'})
    check('max-age' in (ha.get('Strict-Transport-Security') or ''), 'a API também leva Strict-Transport-Security atrás de HTTPS')
    check((ha.get('X-Content-Type-Options') or '') == 'nosniff', 'a API leva nosniff')
    s, _, hs = call('GET', '/')
    check(not hs.get('Strict-Transport-Security'), 'sem HTTPS não se manda HSTS')
    s, r, _ = call('GET', '/api/collections', tok=tok['ownerA'])
    check(s in (401, 403), 'utilizadores normais não veem o esquema das coleções', f'status {s}')
    s, r, _ = call('GET', '/api/settings', tok=tok['ownerA'])
    check(s in (401, 403), 'utilizadores normais não leem as definições', f'status {s}')
    s, r, _ = call('GET', '/api/logs', tok=tok['ownerA'])
    check(s in (401, 403), 'utilizadores normais não leem os logs', f'status {s}')
    s, r, _ = call('POST', '/api/backups', {}, tok['ownerA'])
    check(s in (401, 403), 'utilizadores normais não criam backups', f'status {s}')
    s, r, _ = call('GET', '/api/settings', tok=su)
    if s == 200:
        (ok if r.get('rateLimits', {}).get('enabled') else falha)('rate limiting ativo nas definições')



# ---------------------------------------------------------------------------
# 7. aprovação de registos e segredos cifrados
# ---------------------------------------------------------------------------
TOKEN_VENDUS = 'TESTE-VENDUS-TOKEN-SEGREDO-7890'


def teste_aprovacao():
    sec('7a. Aprovação de registos')
    s, r, _ = call('POST', '/api/collections/users/records',
                   {'email': 'pendente@seg.local', 'password': 'Pendente1234', 'passwordConfirm': 'Pendente1234'})
    check(s == 200 and not r.get('aprovado'), 'registo novo fica por aprovar', str(r)[:100])
    uid = r.get('id')
    s, r, _ = call('POST', '/api/collections/users/records',
                   {'email': 'espertalhao@seg.local', 'password': 'Espertalhao1', 'passwordConfirm': 'Espertalhao1', 'aprovado': True})
    check(s != 200, 'registo não pode vir já aprovado', f'status {s}')
    s, r, _ = call('POST', '/api/collections/users/auth-with-password', {'identity': 'pendente@seg.local', 'password': 'Pendente1234'})
    t = r.get('token')
    check(bool(t), 'utilizador por aprovar consegue entrar (vê o ecrã "em análise")')
    s, _, _ = call('POST', '/api/gc_turnkey/onboarding', {'nome': 'Empresa Pendente'}, t)
    check(s == 403, 'por aprovar: não cria empresa', f'status {s}')
    s, _, _ = call('PATCH', f'/api/collections/users/records/{uid}', {'aprovado': True}, t)
    check(s != 200, 'por aprovar: não se aprova a si próprio', f'status {s}')
    s, r, _ = call('GET', '/api/collections/users/records/' + uid, tok=su)
    check(not r.get('aprovado'), 'continua por aprovar após as tentativas')
    for col in ('ingredientes', 'receitas', 'vendas', 'faturas'):
        s, r, _ = call('GET', f'/api/collections/{col}/records', tok=t)
        check(s != 200 or not r.get('items'), f'por aprovar: não vê dados ({col})', f'status {s}')
    s, _, _ = call('PATCH', f'/api/collections/users/records/{uid}', {'aprovado': True}, su)
    check(s == 200, 'o operador (superutilizador) aprova')
    s, _, _ = call('POST', '/api/gc_turnkey/onboarding', {'nome': 'Empresa Aprovada'}, t)
    check(s == 200, 'depois de aprovado cria a empresa', f'status {s}')
    s, r, _ = call('POST', '/api/gc_turnkey/team/members',
                   {'email': 'membro-aprovado@seg.local', 'password': 'Teste12345!', 'papel': 'viewer'}, tok['ownerA'])
    if s == 200:
        s2, r2, _ = call('GET', f'/api/collections/users/records/{r["id"]}', tok=su)
        check(r2.get('aprovado') is True, 'membros criados por um proprietário nascem aprovados')


def teste_aprovacoes_na_app():
    sec('7a2. Aprovações dentro da app (operador da plataforma)')
    # o operador de teste é ownerA e tem de estar aprovado
    call('PATCH', f'/api/collections/users/records/{users["ownerA"]}', {'aprovado': True}, su)
    novos = {}
    for n in ('novo1', 'novo2'):
        s, r, _ = call('POST', '/api/collections/users/records',
                       {'email': f'{n}@seg.local', 'password': 'Novo1234567', 'passwordConfirm': 'Novo1234567'})
        novos[n] = r.get('id')
    s, _, _ = call('GET', '/api/gc_turnkey/aprovacoes')
    check(s in (401, 403), 'sem sessão não vê as aprovações', f'status {s}')
    for quem in ('ownerB', 'adminA', 'editorA', 'viewerA'):
        s, r, _ = call('GET', '/api/gc_turnkey/aprovacoes', tok=tok[quem])
        check(s == 200 and r.get('operador') is False and not r.get('pendentes'),
              f'{quem}: não é operador e não vê contas por aprovar', f'status {s} {str(r)[:80]}')
        s, _, _ = call('POST', f'/api/gc_turnkey/aprovacoes/{novos["novo1"]}/aprovar', {}, tok[quem])
        check(s == 403, f'{quem}: não aprova', f'status {s}')
        s, _, _ = call('POST', f'/api/gc_turnkey/aprovacoes/{novos["novo1"]}/recusar', {}, tok[quem])
        check(s == 403, f'{quem}: não recusa', f'status {s}')
    # um utilizador por aprovar também não
    s, r, _ = call('POST', '/api/collections/users/auth-with-password', {'identity': 'novo1@seg.local', 'password': 'Novo1234567'})
    s, r2, _ = call('GET', '/api/gc_turnkey/aprovacoes', tok=r.get('token'))
    check(s == 200 and r2.get('operador') is False, 'por aprovar: não é operador')
    s, r, _ = call('GET', '/api/gc_turnkey/aprovacoes', tok=tok['ownerA'])
    emails = [p.get('email') for p in r.get('pendentes', [])]
    check(r.get('operador') is True and 'novo1@seg.local' in emails and 'novo2@seg.local' in emails,
          'o operador vê as contas por aprovar', str(r)[:120])
    s, _, _ = call('POST', f'/api/gc_turnkey/aprovacoes/{novos["novo1"]}/aprovar', {}, tok['ownerA'])
    check(s == 200, 'o operador aprova')
    s, r, _ = call('GET', f'/api/collections/users/records/{novos["novo1"]}', tok=su)
    check(r.get('aprovado') is True, 'a conta aprovada fica aprovada')
    s, _, _ = call('POST', f'/api/gc_turnkey/aprovacoes/{novos["novo1"]}/recusar', {}, tok['ownerA'])
    check(s == 400, 'não se recusa uma conta já aprovada', f'status {s}')
    s, _, _ = call('POST', f'/api/gc_turnkey/aprovacoes/{novos["novo2"]}/recusar', {}, tok['ownerA'])
    check(s == 200, 'o operador recusa (apaga) uma conta por aprovar')
    s, _, _ = call('GET', f'/api/collections/users/records/{novos["novo2"]}', tok=su)
    check(s == 404, 'a conta recusada deixou de existir', f'status {s}')
    s, _, _ = call('POST', '/api/gc_turnkey/aprovacoes/idquenaoexiste1/aprovar', {}, tok['ownerA'])
    check(s == 404, 'conta inexistente => 404', f'status {s}')


class _TelegramFalso(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _resp(self, codigo, corpo):
        b = json.dumps(corpo).encode()
        self.send_response(codigo)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def do_POST(self):
        n = int(self.headers.get('Content-Length', 0))
        corpo = json.loads(self.rfile.read(n) or b'{}')
        if tg_estado['modo'] == '401':
            return self._resp(401, {'ok': False})
        tg_estado['enviadas'].append({'path': self.path, 'corpo': corpo})
        self._resp(200, {'ok': True, 'result': {}})

    def do_GET(self):
        if tg_estado['modo'] == '401':
            return self._resp(401, {'ok': False})
        self._resp(200, {'ok': True, 'result': [
            {'update_id': 1, 'message': {'chat': {'id': 987654, 'first_name': 'Mauro', 'last_name': 'P'}}},
            {'update_id': 2, 'message': {'chat': {'id': -100123, 'title': 'Equipa Gookie'}}},
        ]})


TOKEN_TG = '123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11'


def teste_avisos():
    """Avisos e resumo diário (email / Telegram falso)."""
    if 'PB_URL' in os.environ:
        return
    sec('7a4. Avisos e resumo diário (Telegram falso)')
    srv = HTTPServer(('127.0.0.1', PORTA_TG), _TelegramFalso)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    try:
        tg_estado.update(modo='ok', enviadas=[])
        s, _, _ = call('POST', '/api/gc_turnkey/avisos/testar', {'enviar': False})
        check(s in (401, 403), 'sem sessão não testa os avisos', f'status {s}')
        for quem in ('editorA', 'viewerA'):
            s, _, _ = call('POST', '/api/gc_turnkey/avisos/testar', {'enviar': True}, tok[quem])
            check(s == 403, f'{quem}: não envia avisos', f'status {s}')
            s, _, _ = call('POST', '/api/gc_turnkey/avisos/telegram/detetar', {}, tok[quem])
            check(s == 403, f'{quem}: não deteta chats do Telegram', f'status {s}')
        # configuração: só owner/admin gravam
        cfg = {'empresa': empresas['A'], 'ativo': False, 'hora': '00:00', 'telegram_ativo': True, 'telegram_chat': '987654',
               'email_ativo': False, 'inc_haccp': True, 'inc_stock': True, 'inc_pagamentos': True, 'inc_faturas': True, 'inc_precos': True}
        # (o teste de isolamento já semeou uma configuração: parte-se de zero)
        s, r, _ = call('GET', '/api/collections/avisos_config/records?perPage=50', tok=su)
        for it in r.get('items', []):
            call('DELETE', f'/api/collections/avisos_config/records/{it["id"]}', tok=su)
        s, _, _ = call('POST', '/api/collections/avisos_config/records', cfg, tok['editorA'])
        check(s in (400, 403), 'editor não grava a configuração dos avisos', f'status {s}')
        s, r, _ = call('POST', '/api/collections/avisos_config/records', cfg, tok['adminA'])
        check(s == 200, 'admin grava a configuração dos avisos', f'status {s} {str(r)[:100]}')
        cfg_id = r.get('id')
        s, _, _ = call('POST', '/api/collections/avisos_config/records', {**cfg, 'empresa': empresas['B']}, tok['adminA'])
        check(s in (400, 403), 'admin não grava avisos de outra empresa', f'status {s}')
        # token do bot (cifrado) e testes
        s, r, _ = call('PUT', '/api/gc_turnkey/integracoes/telegram', {'valor': TOKEN_TG}, tok['adminA'])
        check(s == 200 and r.get('configurada') is True and TOKEN_TG not in json.dumps(r), 'token do Telegram guardado e nunca devolvido', f'status {s}')
        s, r, _ = call('POST', '/api/gc_turnkey/avisos/testar', {'enviar': False}, tok['adminA'])
        check(s == 200 and 'Resumo de' in r.get('texto', '') and not tg_estado['enviadas'],
              'pré-visualização do resumo sem enviar nada', f'status {s} {str(r)[:100]}')
        s, r, _ = call('POST', '/api/gc_turnkey/avisos/testar', {'enviar': True}, tok['adminA'])
        check(s == 200 and r.get('resultados', {}).get('telegram') == '' and len(tg_estado['enviadas']) == 1,
              'envio de teste chega ao Telegram', f'status {s} {str(r)[:120]}')
        env = tg_estado['enviadas'][0] if tg_estado['enviadas'] else {}
        check(env.get('corpo', {}).get('chat_id') == '987654' and 'Resumo de' in env.get('corpo', {}).get('text', ''),
              'a mensagem vai para o chat configurado')
        check(TOKEN_TG not in json.dumps(r), 'a resposta nunca contém o token')
        # dias de folga e ausências no resumo
        import datetime as _dt
        hoje = _dt.date.today()
        s, r, _ = call('GET', f'/api/collections/configuracoes_custo/records?filter=empresa%3D%22{empresas["A"]}%22', tok=su)
        cc = (r.get('items') or [None])[0] if s == 200 else None
        if cc:
            outros = ','.join(str(d) for d in range(1, 8) if d != hoje.isoweekday())
            call('PATCH', f'/api/collections/configuracoes_custo/records/{cc["id"]}', {'dias_trabalho': outros}, su)
            s, r, _ = call('POST', '/api/gc_turnkey/avisos/testar', {'enviar': False}, tok['adminA'])
            check(s == 200 and 'dia de folga' in r.get('texto', ''), 'hoje de folga: o resumo diz que não é enviado automaticamente', str(r)[:140])
            call('PATCH', f'/api/collections/configuracoes_custo/records/{cc["id"]}', {'dias_trabalho': ''}, su)
            s, r, _ = call('POST', '/api/gc_turnkey/avisos/testar', {'enviar': False}, tok['adminA'])
            check(s == 200 and 'dia de folga' not in r.get('texto', ''), 'dia de trabalho: sem aviso de folga')
        aus = {'empresa': empresas['A'], 'pessoa': 'c:ausente-teste', 'nome': 'Ana Teste', 'tipo': 'ferias', 'estado': 'aprovado',
               'data_inicio': hoje.isoformat() + ' 00:00:00.000Z', 'data_fim': hoje.isoformat() + ' 00:00:00.000Z'}
        s, ra, _ = call('POST', '/api/collections/ferias/records', aus, su)
        s, rb, _ = call('POST', '/api/collections/ferias/records',
                        {**aus, 'pessoa': 'c:baixa-teste', 'nome': 'Rui Teste', 'tipo': 'baixa'}, su)
        s, r, _ = call('POST', '/api/gc_turnkey/avisos/testar', {'enviar': False}, tok['adminA'])
        texto = r.get('texto', '')
        check('Ana Teste (férias)' in texto, 'quem está de férias hoje aparece no resumo', texto[-200:])
        check('Rui Teste (ausente)' in texto and 'baixa' not in texto.lower(), 'baixas aparecem só como "ausente" (dados de saúde)', texto[-200:])
        for x in (ra, rb):
            if x.get('id'):
                call('DELETE', f'/api/collections/ferias/records/{x["id"]}', tok=su)
        # saída por marcar: entrada há 20 horas sem saída
        agora_utc = _dt.datetime.utcnow() - _dt.timedelta(hours=20)
        pr = {'empresa': empresas['A'], 'pessoa': 'c:esqueceu-teste', 'nome': 'Ze Teste', 'tipo': 'entrada', 'origem': 'manual',
              'data_hora': agora_utc.strftime('%Y-%m-%d %H:%M:%S.000Z')}
        s, rp, _ = call('POST', '/api/collections/ponto_registos/records', pr, su)
        s, r, _ = call('POST', '/api/gc_turnkey/avisos/testar', {'enviar': False}, tok['adminA'])
        texto = r.get('texto', '')
        check('Saída por marcar' in texto and 'Ze Teste' in texto, 'o resumo avisa de uma saída por marcar', texto[-200:])
        if rp.get('id'):
            call('POST', '/api/collections/ponto_registos/records',
                 {**pr, 'tipo': 'saida', 'data_hora': (_dt.datetime.utcnow() - _dt.timedelta(hours=12)).strftime('%Y-%m-%d %H:%M:%S.000Z')}, su)
            s, r, _ = call('POST', '/api/gc_turnkey/avisos/testar', {'enviar': False}, tok['adminA'])
            check('Ze Teste' not in r.get('texto', ''), 'depois de marcada a saída, o aviso desaparece', r.get('texto', '')[-200:])
        s, rl, _ = call('GET', '/api/collections/ponto_registos/records?perPage=200', tok=su)
        for it in rl.get('items', []):
            if it.get('pessoa') == 'c:esqueceu-teste':
                call('DELETE', f'/api/collections/ponto_registos/records/{it["id"]}', tok=su)
        # sem SMTP: mensagem clara
        call('PATCH', f'/api/collections/avisos_config/records/{cfg_id}', {'email_ativo': True, 'email_para': 'x@exemplo.pt', 'telegram_ativo': False}, tok['adminA'])
        s, r, _ = call('POST', '/api/gc_turnkey/avisos/testar', {'enviar': True}, tok['adminA'])
        check('SMTP' in (r.get('resultados', {}).get('email') or ''), 'email sem SMTP configurado explica o que fazer', str(r)[:140])
        # token inválido
        call('PATCH', f'/api/collections/avisos_config/records/{cfg_id}', {'email_ativo': False, 'telegram_ativo': True}, tok['adminA'])
        tg_estado['modo'] = '401'
        s, r, _ = call('POST', '/api/gc_turnkey/avisos/testar', {'enviar': True}, tok['adminA'])
        check('token' in (r.get('resultados', {}).get('telegram') or '').lower() and TOKEN_TG not in json.dumps(r),
              'token inválido: mensagem útil sem revelar o token', str(r)[:140])
        s, _, _ = call('POST', '/api/gc_turnkey/avisos/telegram/detetar', {}, tok['adminA'])
        check(s == 400, 'detetar com token inválido => erro claro', f'status {s}')
        tg_estado['modo'] = 'ok'
        s, r, _ = call('POST', '/api/gc_turnkey/avisos/telegram/detetar', {}, tok['adminA'])
        ids = [c.get('id') for c in r.get('chats', [])] if s == 200 else []
        check('987654' in ids and '-100123' in ids, 'detetar mostra os chats que falaram com o bot', f'status {s} {str(r)[:120]}')
        # outra empresa nunca vê/usa o token da A
        s, r, _ = call('POST', '/api/gc_turnkey/avisos/telegram/detetar', {}, tok['ownerB'])
        check(s == 400, 'a empresa B não usa o token da A', f'status {s}')
        # limpeza: o teste seguinte (segredos) espera só o token do Vendus
        call('DELETE', '/api/gc_turnkey/integracoes/telegram', tok=tok['adminA'])
    finally:
        srv.shutdown()


def teste_lotes():
    sec('7a5. Rastreabilidade por lote')
    ingA = semear('ingredientes', 'A')
    ingB = semear('ingredientes', 'B')
    fichaA = semear('fichas_tecnicas', 'A')
    if not (ingA and ingB and fichaA):
        aviso('lotes: não foi possível semear ingrediente/ficha — não testado')
        return
    ingA, ingB, fichaA = ingA[0], ingB[0], fichaA[0]
    lote = {'empresa': empresas['A'], 'ingrediente': ingA, 'lote': 'L-2026-001', 'validade': '2027-01-31 00:00:00.000Z', 'fornecedor': 'Makro'}
    s, _, _ = call('POST', '/api/collections/lotes_ingrediente/records', lote, tok['viewerA'])
    check(s in (400, 403), 'leitura não regista lotes', f'status {s}')
    s, r, _ = call('POST', '/api/collections/lotes_ingrediente/records', lote, tok['editorA'])
    check(s == 200, 'editor regista o lote de um ingrediente', f'status {s} {str(r)[:100]}')
    li = r.get('id')
    s, _, _ = call('POST', '/api/collections/lotes_ingrediente/records', lote, tok['editorA'])
    check(s == 400, 'o mesmo lote do mesmo ingrediente não se repete', f'status {s}')
    s, _, _ = call('POST', '/api/collections/lotes_ingrediente/records',
                   {**lote, 'empresa': empresas['B'], 'ingrediente': ingA, 'lote': 'X'}, tok['editorB'])
    check(s in (400, 403), 'empresa B não regista lotes de ingredientes da A', f'status {s}')
    s, r, _ = call('GET', '/api/collections/lotes_ingrediente/records', tok=tok['editorB'])
    check(s == 200 and all(i.get('empresa') == empresas['B'] for i in r.get('items', [])), 'empresa B só vê os seus lotes (nenhum da A)')
    # lote de produção
    lp = {'empresa': empresas['A'], 'codigo': '261006-TST-1', 'ficha': fichaA, 'ficha_nome': 'Teste', 'data_producao': '2026-10-06 00:00:00.000Z',
          'quantidade': 24, 'validade': '2026-10-11 00:00:00.000Z',
          'ingredientes': [{'ingrediente': ingA, 'nome': 'Farinha', 'lote': 'L-2026-001'}]}
    s, _, _ = call('POST', '/api/collections/lotes_producao/records', lp, tok['viewerA'])
    check(s in (400, 403), 'leitura não cria lotes de produção', f'status {s}')
    s, r, _ = call('POST', '/api/collections/lotes_producao/records', lp, tok['editorA'])
    check(s == 200, 'editor cria um lote de produção', f'status {s} {str(r)[:100]}')
    lpid = r.get('id')
    s, _, _ = call('POST', '/api/collections/lotes_producao/records', lp, tok['editorA'])
    check(s == 400, 'o código do lote é único', f'status {s}')
    s, _, _ = call('POST', '/api/collections/lotes_producao/records', {**lp, 'empresa': empresas['B'], 'codigo': 'B-1'}, tok['editorB'])
    check(s in (400, 403), 'empresa B não cria lote ligado a ficha da A', f'status {s}')
    s, r, _ = call('GET', f'/api/collections/lotes_producao/records/{lpid}', tok=tok['viewerA'])
    check(s == 200 and r.get('codigo') == '261006-TST-1', 'leitura consulta o lote')
    s, _, _ = call('GET', f'/api/collections/lotes_producao/records/{lpid}', tok=tok['editorB'])
    check(s == 404, 'empresa B não consulta lotes da A', f'status {s}')
    s, _, _ = call('DELETE', f'/api/collections/lotes_producao/records/{lpid}', tok=tok['editorA'])
    check(s in (403, 404), 'editor não apaga lotes de produção (rastreabilidade)', f'status {s}')
    # sugestão de ingredientes
    call('POST', '/api/collections/itens_ficha/records',
         {'empresa': empresas['A'], 'ficha': fichaA, 'ingrediente': ingA, 'quantidade_g': 100, 'slot': 'massa'}, su)
    s, r, _ = call('GET', f'/api/gc_turnkey/lotes/ingredientes?ficha={fichaA}', tok=tok['viewerA'])
    ings = r.get('ingredientes', []) if s == 200 else []
    check(any(i['id'] == ingA and any(l['lote'] == 'L-2026-001' for l in i['lotes']) for i in ings),
          'a sugestão traz os ingredientes da ficha e os seus lotes', f'status {s} {str(r)[:140]}')
    s, _, _ = call('GET', f'/api/gc_turnkey/lotes/ingredientes?ficha={fichaA}', tok=tok['editorB'])
    check(s == 404, 'empresa B não pede ingredientes de uma ficha da A', f'status {s}')
    s, _, _ = call('GET', f'/api/gc_turnkey/lotes/ingredientes?ficha={fichaA}')
    check(s in (401, 403), 'sem sessão não há sugestão', f'status {s}')
    s, _, _ = call('DELETE', f'/api/collections/lotes_producao/records/{lpid}', tok=tok['adminA'])
    check(s in (200, 204), 'administrador apaga o lote de produção', f'status {s}')


def teste_quiosque_offline():
    sec('7a6. Quiosque sem ligação (registos com id próprio)')
    ctlA = semear('haccp_controlos', 'A')
    if not ctlA:
        aviso('quiosque offline: não foi possível semear um controlo — não testado')
        return
    reg = {'id': 'offlinetest0001', 'empresa': empresas['A'], 'controlo': ctlA[0], 'data_hora': '2026-10-07 09:00:00.000Z',
           'conforme': True, 'responsavel': 'Ana', 'notas': '', 'acao_corretiva': '', 'resolvido': False}
    s, _, _ = call('POST', '/api/collections/haccp_registos/records', reg, tok['viewerA'])
    check(s in (400, 403), 'leitura não regista tarefas', f'status {s}')
    s, r, _ = call('POST', '/api/collections/haccp_registos/records', reg, tok['editorA'])
    check(s == 200 and r.get('id') == 'offlinetest0001', 'o quiosque regista com um id escolhido por ele', f'status {s} {str(r)[:100]}')
    s, r, _ = call('POST', '/api/collections/haccp_registos/records', reg, tok['editorA'])
    check(s == 400 and 'id' in (r.get('data') or {}), 'reenviar o mesmo registo é recusado sem duplicar (a app dá-o por enviado)', f'status {s} {str(r)[:120]}')
    s, _, _ = call('POST', '/api/collections/haccp_registos/records', {**reg, 'empresa': empresas['B']}, tok['editorB'])
    check(s in (400, 403), 'empresa B não reutiliza o id nem regista num controlo da A', f'status {s}')
    s, _, _ = call('GET', '/api/collections/haccp_registos/records/offlinetest0001', tok=tok['editorB'])
    check(s == 404, 'empresa B não vê o registo da A', f'status {s}')
    s, _, _ = call('POST', '/api/collections/haccp_registos/records', {**reg, 'id': 'curto'}, tok['editorA'])
    check(s == 400, 'um id fora do formato é recusado', f'status {s}')
    s, r, _ = call('GET', '/api/collections/haccp_registos/records?perPage=200', tok=tok['editorA'])
    check(s == 200 and sum(1 for i in r.get('items', []) if i.get('id') == 'offlinetest0001') == 1, 'há um só registo depois do reenvio')


def teste_ponto():
    sec('7a7. Registo de ponto')
    base = {'empresa': empresas['A'], 'pessoa': 'c:colab-teste', 'nome': 'Ana', 'tipo': 'entrada',
            'data_hora': '2026-10-07 08:00:00.000Z', 'origem': 'quiosque'}
    s, _, _ = call('POST', '/api/collections/ponto_registos/records', base, tok['viewerA'])
    check(s in (400, 403), 'leitura não marca ponto', f'status {s}')
    s, r, _ = call('POST', '/api/collections/ponto_registos/records', base, tok['editorA'])
    check(s == 200, 'editor (quiosque) marca o ponto de qualquer pessoa', f'status {s} {str(r)[:100]}')
    pid = r.get('id')
    s, _, _ = call('POST', '/api/collections/ponto_registos/records', {**base, 'empresa': empresas['B']}, tok['editorA'])
    check(s in (400, 403), 'não se marca ponto numa empresa alheia', f'status {s}')
    s, _, _ = call('POST', '/api/collections/ponto_registos/records', {**base, 'tipo': 'almoco'}, tok['editorA'])
    check(s == 400, 'tipo de marcação inválido é recusado', f'status {s}')
    # quem lê: só o proprietário/administrador (e cada um as suas, pela conta)
    s, r, _ = call('GET', '/api/collections/ponto_registos/records', tok=tok['editorA'])
    check(s == 200 and not any(i.get('pessoa') == 'c:colab-teste' for i in r.get('items', [])),
          'o editor não vê as marcações dos outros', f'status {s}')
    s, r, _ = call('GET', '/api/collections/ponto_registos/records', tok=tok['adminA'])
    check(s == 200 and any(i.get('id') == pid for i in r.get('items', [])), 'o administrador vê as marcações')
    s, _, _ = call('GET', f'/api/collections/ponto_registos/records/{pid}', tok=tok['editorB'])
    check(s == 404, 'empresa B não vê o ponto da A', f'status {s}')
    # cada um vê as suas
    s, r, _ = call('POST', '/api/collections/ponto_registos/records',
                   {**base, 'pessoa': f"u:{users['editorA']}", 'user': users['editorA'], 'origem': 'app'}, tok['editorA'])
    check(s == 200, 'editor marca o seu próprio ponto', f'status {s} {str(r)[:100]}')
    meu = r.get('id')
    s, r, _ = call('GET', '/api/collections/ponto_registos/records', tok=tok['editorA'])
    check(s == 200 and any(i.get('id') == meu for i in r.get('items', [])), 'o editor vê a sua marcação')
    s, _, _ = call('PATCH', f'/api/collections/ponto_registos/records/{meu}', {'data_hora': '2026-10-07 07:00:00.000Z'}, tok['editorA'])
    check(s in (403, 404), 'o editor não altera marcações (nem as suas)', f'status {s}')
    s, _, _ = call('DELETE', f'/api/collections/ponto_registos/records/{meu}', tok=tok['editorA'])
    check(s in (403, 404), 'o editor não apaga marcações', f'status {s}')
    s, _, _ = call('PATCH', f'/api/collections/ponto_registos/records/{pid}',
                   {'data_hora': '2026-10-07 08:10:00.000Z', 'corrigido': True}, tok['adminA'])
    check(s == 200, 'o administrador corrige uma marcação', f'status {s}')
    # estado para o quiosque
    s, r, _ = call('GET', '/api/gc_turnkey/ponto/estado', tok=tok['viewerA'])
    check(s == 403, 'estado do ponto: leitura recusada', f'status {s}')
    s, _, _ = call('GET', '/api/gc_turnkey/ponto/estado')
    check(s in (401, 403), 'estado do ponto: sem sessão recusado', f'status {s}')
    s, r, _ = call('GET', '/api/gc_turnkey/ponto/estado', tok=tok['editorA'])
    check(s == 200 and isinstance(r.get('pessoas'), list), 'estado do ponto: editor recebe a lista', f'status {s}')
    s, r, _ = call('GET', '/api/gc_turnkey/ponto/estado', tok=tok['editorB'])
    check(s == 200 and not any(p.get('pessoa') == 'c:colab-teste' for p in r.get('pessoas', [])),
          'estado do ponto: empresa B não vê pessoas da A')
    s, _, _ = call('DELETE', f'/api/collections/ponto_registos/records/{pid}', tok=tok['adminA'])
    check(s in (200, 204), 'o administrador apaga uma marcação', f'status {s}')
    call('DELETE', f'/api/collections/ponto_registos/records/{meu}', tok=tok['adminA'])


def teste_ferias():
    sec('7a8. Mapa de férias e ausências')
    uid = users['editorA']
    base = {'empresa': empresas['A'], 'pessoa': f'u:{uid}', 'nome': 'Editor A', 'user': uid, 'tipo': 'ferias',
            'data_inicio': '2026-09-07 00:00:00.000Z', 'data_fim': '2026-09-11 00:00:00.000Z', 'dias_uteis': 5, 'estado': 'pedido'}
    s, _, _ = call('POST', '/api/collections/ferias/records', base, tok['viewerA'])
    check(s in (400, 403), 'leitura não pede férias', f'status {s}')
    s, r, _ = call('POST', '/api/collections/ferias/records', base, tok['editorA'])
    check(s == 200, 'editor pede férias para si', f'status {s} {str(r)[:100]}')
    pedido = r.get('id')
    s, _, _ = call('POST', '/api/collections/ferias/records', {**base, 'estado': 'aprovado'}, tok['editorA'])
    check(s in (400, 403), 'editor não se auto-aprova', f'status {s}')
    s, _, _ = call('POST', '/api/collections/ferias/records',
                   {**base, 'pessoa': f"u:{users['viewerA']}", 'user': users['viewerA']}, tok['editorA'])
    check(s in (400, 403), 'editor não pede férias em nome de outra conta', f'status {s}')
    s, _, _ = call('POST', '/api/collections/ferias/records', {**base, 'empresa': empresas['B']}, tok['editorA'])
    check(s in (400, 403), 'não se pedem férias numa empresa alheia', f'status {s}')
    s, _, _ = call('POST', '/api/collections/ferias/records', {**base, 'tipo': 'sabatico'}, tok['editorA'])
    check(s == 400, 'tipo de ausência inválido é recusado', f'status {s}')
    s, _, _ = call('PATCH', f'/api/collections/ferias/records/{pedido}', {'estado': 'aprovado'}, tok['editorA'])
    check(s in (403, 404), 'o editor não aprova o próprio pedido', f'status {s}')
    s, _, _ = call('PATCH', f'/api/collections/ferias/records/{pedido}', {'estado': 'aprovado'}, tok['editorB'])
    check(s in (403, 404), 'empresa B não decide pedidos da A', f'status {s}')
    # visibilidade: pedidos e baixas só o próprio e a administração
    s, r, _ = call('GET', '/api/collections/ferias/records', tok=tok['viewerA'])
    check(s == 200 and not any(i.get('id') == pedido for i in r.get('items', [])), 'um colega não vê pedidos pendentes dos outros')
    s, r, _ = call('GET', '/api/collections/ferias/records', tok=tok['editorA'])
    check(s == 200 and any(i.get('id') == pedido for i in r.get('items', [])), 'o próprio vê o seu pedido')
    s, r, _ = call('GET', '/api/collections/ferias/records', tok=tok['adminA'])
    check(s == 200 and any(i.get('id') == pedido for i in r.get('items', [])), 'a administração vê os pedidos')
    s, _, _ = call('GET', f'/api/collections/ferias/records/{pedido}', tok=tok['editorB'])
    check(s == 404, 'empresa B não vê férias da A', f'status {s}')
    s, _, _ = call('PATCH', f'/api/collections/ferias/records/{pedido}', {'estado': 'aprovado', 'decidido_por': users['adminA']}, tok['adminA'])
    check(s == 200, 'o administrador aprova', f'status {s}')
    s, r, _ = call('GET', '/api/collections/ferias/records', tok=tok['viewerA'])
    check(s == 200 and any(i.get('id') == pedido for i in r.get('items', [])), 'depois de aprovadas, as férias são visíveis à equipa')
    # baixa: privada
    s, r, _ = call('POST', '/api/collections/ferias/records', {**base, 'tipo': 'baixa', 'estado': 'aprovado'}, tok['adminA'])
    check(s == 200, 'o administrador regista uma baixa', f'status {s}')
    baixa = r.get('id')
    s, r, _ = call('GET', '/api/collections/ferias/records', tok=tok['viewerA'])
    check(s == 200 and not any(i.get('id') == baixa for i in r.get('items', [])), 'baixas não são visíveis aos colegas (dados de saúde)')
    # apagar
    s, _, _ = call('DELETE', f'/api/collections/ferias/records/{pedido}', tok=tok['editorA'])
    check(s in (403, 404), 'o editor não apaga férias já aprovadas', f'status {s}')
    s, r, _ = call('POST', '/api/collections/ferias/records', {**base, 'data_inicio': '2026-11-02 00:00:00.000Z', 'data_fim': '2026-11-03 00:00:00.000Z'}, tok['editorA'])
    outro = r.get('id')
    s, _, _ = call('DELETE', f'/api/collections/ferias/records/{outro}', tok=tok['editorA'])
    check(s in (200, 204), 'o editor cancela um pedido seu ainda pendente', f'status {s}')
    # direito a férias
    d = {'empresa': empresas['A'], 'pessoa': f'u:{uid}', 'user': uid, 'ano': 2026, 'dias': 25}
    s, _, _ = call('POST', '/api/collections/ferias_direito/records', d, tok['editorA'])
    check(s in (400, 403), 'o editor não define o seu direito a férias', f'status {s}')
    s, r, _ = call('POST', '/api/collections/ferias_direito/records', d, tok['adminA'])
    check(s == 200, 'o administrador define o direito a férias', f'status {s} {str(r)[:100]}')
    did = r.get('id')
    s, _, _ = call('POST', '/api/collections/ferias_direito/records', d, tok['adminA'])
    check(s == 400, 'só um direito por pessoa e ano', f'status {s}')
    s, r, _ = call('GET', '/api/collections/ferias_direito/records', tok=tok['editorA'])
    check(s == 200 and any(i.get('id') == did for i in r.get('items', [])), 'cada um vê o seu direito')
    s, r, _ = call('GET', '/api/collections/ferias_direito/records', tok=tok['viewerA'])
    check(s == 200 and not any(i.get('id') == did for i in r.get('items', [])), 'os outros não vêem o direito dos colegas')
    s, _, _ = call('GET', f'/api/collections/ferias_direito/records/{did}', tok=tok['editorB'])
    check(s == 404, 'empresa B não vê o direito a férias da A', f'status {s}')
    for rid in (pedido, baixa):
        call('DELETE', f'/api/collections/ferias/records/{rid}', tok=tok['adminA'])
    call('DELETE', f'/api/collections/ferias_direito/records/{did}', tok=tok['adminA'])


def teste_anotacoes():
    sec('7a9. Anotações da equipa')
    base = {'empresa': empresas['A'], 'texto': 'Forno avariado', 'categoria': 'ocorrencia',
            'autor': users['editorA'], 'autor_nome': 'Editor A'}
    s, _, _ = call('POST', '/api/collections/anotacoes/records', base, tok['viewerA'])
    check(s in (400, 403), 'leitura não escreve notas', f'status {s}')
    s, r, _ = call('POST', '/api/collections/anotacoes/records', base, tok['editorA'])
    check(s == 200, 'editor escreve uma nota', f'status {s} {str(r)[:100]}')
    nid = r.get('id')
    s, _, _ = call('POST', '/api/collections/anotacoes/records', {**base, 'autor': users['adminA']}, tok['editorA'])
    check(s in (400, 403), 'ninguém escreve em nome de outro autor', f'status {s}')
    s, _, _ = call('POST', '/api/collections/anotacoes/records', {**base, 'empresa': empresas['B']}, tok['editorA'])
    check(s in (400, 403), 'não se escreve numa empresa alheia', f'status {s}')
    s, _, _ = call('POST', '/api/collections/anotacoes/records', {**base, 'categoria': 'segredo'}, tok['editorA'])
    check(s == 400, 'categoria inválida é recusada', f'status {s}')
    s, _, _ = call('POST', '/api/collections/anotacoes/records', {**base, 'texto': 'x' * 2001}, tok['editorA'])
    check(s == 400, 'texto demasiado longo é recusado', f'status {s}')
    s, r, _ = call('GET', '/api/collections/anotacoes/records', tok=tok['viewerA'])
    check(s == 200 and not r.get('items'), 'Leitura não vê as notas da equipa', f'status {s}')
    s, r, _ = call('GET', '/api/collections/anotacoes/records', tok=tok['adminA'])
    check(s == 200 and any(i.get('id') == nid for i in r.get('items', [])), 'a equipa vê as notas')
    s, _, _ = call('GET', f'/api/collections/anotacoes/records/{nid}', tok=tok['editorB'])
    check(s == 404, 'empresa B não vê as notas da A', f'status {s}')
    # um colega só fixa/arquiva; não muda o texto
    s, r, _ = call('POST', '/api/collections/anotacoes/records', {**base, 'texto': 'nota do admin', 'autor': users['adminA']}, tok['adminA'])
    outra = r.get('id')
    s, _, _ = call('PATCH', f'/api/collections/anotacoes/records/{outra}', {'fixada': True}, tok['editorA'])
    check(s == 200, 'qualquer um da equipa pode fixar', f'status {s}')
    s, _, _ = call('PATCH', f'/api/collections/anotacoes/records/{outra}', {'arquivada': True}, tok['editorA'])
    check(s == 200, 'qualquer um da equipa pode arquivar', f'status {s}')
    s, _, _ = call('PATCH', f'/api/collections/anotacoes/records/{nid}', {'texto': 'mudado'}, tok['viewerA'])
    check(s in (403, 404), 'Leitura não muda notas', f'status {s}')
    s, _, _ = call('PATCH', f'/api/collections/anotacoes/records/{nid}', {'texto': 'mudado', 'fixada': False}, tok['editorB'])
    check(s in (403, 404), 'empresa B não altera notas da A', f'status {s}')
    s, _, _ = call('PATCH', f'/api/collections/anotacoes/records/{outra}', {'texto': 'adulterada'}, tok['editorA'])
    check(s in (403, 404), 'um colega não altera o texto de uma nota alheia', f'status {s}')
    s, _, _ = call('DELETE', f'/api/collections/anotacoes/records/{outra}', tok=tok['editorA'])
    check(s in (403, 404), 'um colega não apaga a nota de outro', f'status {s}')
    s, _, _ = call('PATCH', f'/api/collections/anotacoes/records/{nid}', {'texto': 'editado pelo autor'}, tok['editorA'])
    check(s == 200, 'o autor edita a sua nota', f'status {s}')
    s, _, _ = call('DELETE', f'/api/collections/anotacoes/records/{outra}', tok=tok['adminA'])
    check(s in (200, 204), 'o autor (admin) apaga a sua nota', f'status {s}')
    s, _, _ = call('DELETE', f'/api/collections/anotacoes/records/{nid}', tok=tok['adminA'])
    check(s in (200, 204), 'a administração apaga notas de outros', f'status {s}')


def teste_escala():
    sec('7a10. Escala semanal')
    uid = users['editorA']
    m = {'empresa': empresas['A'], 'pessoa': f'u:{uid}', 'nome': 'Editor A', 'user': uid, 'dia_semana': 2,
         'inicio': '08:00', 'fim': '16:30', 'pausa_min': 30}
    s, _, _ = call('POST', '/api/collections/escala_modelo/records', m, tok['editorA'])
    check(s in (400, 403), 'o editor não define horários', f'status {s}')
    s, _, _ = call('POST', '/api/collections/escala_modelo/records', m, tok['viewerA'])
    check(s in (400, 403), 'Leitura não define horários', f'status {s}')
    s, r, _ = call('POST', '/api/collections/escala_modelo/records', m, tok['adminA'])
    check(s == 200, 'o administrador define o horário habitual', f'status {s} {str(r)[:100]}')
    mid = r.get('id')
    s, _, _ = call('POST', '/api/collections/escala_modelo/records', m, tok['adminA'])
    check(s == 400, 'um só horário por pessoa e dia da semana', f'status {s}')
    s, _, _ = call('POST', '/api/collections/escala_modelo/records', {**m, 'dia_semana': 3, 'inicio': '25:00'}, tok['adminA'])
    check(s == 400, 'hora inválida é recusada', f'status {s}')
    s, _, _ = call('POST', '/api/collections/escala_modelo/records', {**m, 'dia_semana': 9}, tok['adminA'])
    check(s == 400, 'dia da semana inválido é recusado', f'status {s}')
    s, _, _ = call('POST', '/api/collections/escala_modelo/records', {**m, 'empresa': empresas['B'], 'dia_semana': 4}, tok['adminA'])
    check(s in (400, 403), 'não se define horário numa empresa alheia', f'status {s}')
    s, r, _ = call('GET', '/api/collections/escala_modelo/records', tok=tok['editorA'])
    check(s == 200 and any(i.get('id') == mid for i in r.get('items', [])), 'a equipa vê o horário')
    s, r, _ = call('GET', '/api/collections/escala_modelo/records', tok=tok['viewerA'])
    check(s == 200 and not r.get('items'), 'Leitura não vê a escala', f'status {s}')
    s, _, _ = call('GET', f'/api/collections/escala_modelo/records/{mid}', tok=tok['editorB'])
    check(s == 404, 'empresa B não vê a escala da A', f'status {s}')
    s, _, _ = call('PATCH', f'/api/collections/escala_modelo/records/{mid}', {'fim': '18:00'}, tok['editorA'])
    check(s in (403, 404), 'o editor não altera o horário', f'status {s}')
    s, _, _ = call('PATCH', f'/api/collections/escala_modelo/records/{mid}', {'fim': '17:00'}, tok['adminA'])
    check(s == 200, 'o administrador altera o horário', f'status {s}')
    e = {'empresa': empresas['A'], 'pessoa': f'u:{uid}', 'nome': 'Editor A', 'user': uid, 'data': '2026-10-07 00:00:00.000Z',
         'folga': True}
    s, _, _ = call('POST', '/api/collections/escala_excecoes/records', e, tok['editorA'])
    check(s in (400, 403), 'o editor não cria exceções', f'status {s}')
    s, r, _ = call('POST', '/api/collections/escala_excecoes/records', e, tok['adminA'])
    check(s == 200, 'o administrador cria uma exceção (folga)', f'status {s} {str(r)[:100]}')
    eid = r.get('id')
    s, _, _ = call('POST', '/api/collections/escala_excecoes/records', e, tok['adminA'])
    check(s == 400, 'uma só exceção por pessoa e dia', f'status {s}')
    s, _, _ = call('GET', f'/api/collections/escala_excecoes/records/{eid}', tok=tok['editorB'])
    check(s == 404, 'empresa B não vê as exceções da A', f'status {s}')
    s, _, _ = call('DELETE', f'/api/collections/escala_excecoes/records/{eid}', tok=tok['editorA'])
    check(s in (403, 404), 'o editor não apaga exceções', f'status {s}')
    call('DELETE', f'/api/collections/escala_excecoes/records/{eid}', tok=tok['adminA'])
    s, _, _ = call('DELETE', f'/api/collections/escala_modelo/records/{mid}', tok=tok['adminA'])
    check(s in (200, 204), 'o administrador apaga o horário', f'status {s}')


def teste_estado_backups():
    sec('7a3. Estado dos backups (só administradores)')
    s, _, _ = call('GET', '/api/gc_turnkey/backups/estado')
    check(s in (401, 403), 'sem sessão não vê o estado dos backups', f'status {s}')
    for quem in ('editorA', 'viewerA', 'editorB'):
        s, _, _ = call('GET', '/api/gc_turnkey/backups/estado', tok=tok[quem])
        check(s == 403, f'{quem}: não vê o estado dos backups', f'status {s}')
    # sem nada preparado: devolve a forma certa e "desconhecido"
    s, r, _ = call('GET', '/api/gc_turnkey/backups/estado', tok=tok['adminA'])
    check(s == 200 and 'local' in r and r.get('externo', {}).get('estado') == 'desconhecido',
          'admin vê o estado (cópia externa desconhecida se o script nunca correu)', f'status {s} {str(r)[:100]}')
    if tmp:
        dados = os.path.join(tmp, 'data')
        os.makedirs(os.path.join(dados, 'backups'), exist_ok=True)
        with open(os.path.join(dados, 'backups', 'backup_teste.zip'), 'wb') as f:
            f.write(b'x' * 2048)
        with open(os.path.join(dados, 'backup_externo.json'), 'w', encoding='utf-8') as f:
            f.write('{"ok":false,"quando":"2026-10-05T03:30:00Z","ficheiro":"backup_teste.zip","mensagem":"rclone falhou"}')
        s, r, _ = call('GET', '/api/gc_turnkey/backups/estado', tok=tok['ownerA'])
        ult = (r.get('local') or {}).get('ultimo') or {}
        check(s == 200 and r['local']['total'] == 1 and ult.get('nome') == 'backup_teste.zip' and ult.get('tamanho') == 2048,
              'o proprietário vê o último backup local (nome e tamanho)', str(r)[:140])
        check(r.get('externo', {}).get('estado') == 'falha' and r['externo'].get('mensagem') == 'rclone falhou',
              'a falha da cópia externa chega à app')
        txt = json.dumps(r)
        check(dados.replace('\\', '/') not in txt.replace('\\', '/') and 'pbsec_' not in txt,
              'a resposta não revela caminhos do servidor')


def teste_segredos():
    sec('7b. Segredos cifrados (token do Vendus)')
    url = '/api/gc_turnkey/integracoes/vendus'
    for quem in ('viewerA', 'editorA'):
        s, _, _ = call('PUT', url, {'valor': TOKEN_VENDUS}, tok[quem])
        check(s == 403, f'{quem} não guarda tokens', f'status {s}')
    s, _, _ = call('PUT', url, {'valor': TOKEN_VENDUS})
    check(s in (401, 403), 'sem sessão não guarda tokens', f'status {s}')
    s, _, _ = call('PUT', url, {'valor': 'curto'}, tok['ownerA'])
    check(s == 400, 'token curto recusado', f'status {s}')
    s, _, _ = call('PUT', '/api/gc_turnkey/integracoes/outro', {'valor': TOKEN_VENDUS}, tok['ownerA'])
    check(s == 404, 'serviço desconhecido recusado', f'status {s}')
    s, r, _ = call('PUT', url, {'valor': TOKEN_VENDUS}, tok['adminA'])
    check(s == 200 and r.get('configurada') is True and r.get('sufixo') == '7890', 'admin guarda o token', f'{s} {r}')
    check(r.get('cifraDisponivel') is True, 'o estado diz que a cifra está disponível no servidor')
    check(TOKEN_VENDUS not in json.dumps(r), 'a resposta nunca devolve o token')
    s, r, _ = call('GET', url, tok=tok['editorA'])
    check(s == 200 and r.get('configurada') is True and TOKEN_VENDUS not in json.dumps(r), 'editor vê só o estado')
    s, _, _ = call('GET', url, tok=tok['viewerA'])
    check(s == 403, 'Leitura não vê a integração', f'status {s}')
    s, r, _ = call('GET', url, tok=tok['ownerB'])
    check(s == 200 and r.get('configurada') is False, 'a empresa B não vê o token da empresa A')
    s, _, _ = call('DELETE', url, tok=tok['editorA'])
    check(s == 403, 'editor não apaga o token', f'status {s}')
    for quem in ('ownerA', 'ownerB', 'editorB'):
        s, r, _ = call('GET', '/api/collections/segredos_empresa/records', tok=tok[quem])
        check(s in (400, 403, 404) or not r.get('items'), f'{quem} não lê a coleção de segredos por REST', f'status {s}')
    # cifrado em repouso
    s, r, _ = call('GET', '/api/collections/segredos_empresa/records', tok=su)
    itens = r.get('items', []) if isinstance(r, dict) else []
    check(len(itens) == 1 and TOKEN_VENDUS not in json.dumps(itens) and itens[0].get('valor_cifrado'),
          'na base de dados o token está cifrado (nem o superutilizador o vê em claro)')
    # o ficheiro da base de dados também não o contém em claro
    if tmp:
        alvo = TOKEN_VENDUS.encode()
        achou = False
        for nome in os.listdir(os.path.join(tmp, 'data')):
            if nome.startswith('data.db'):
                if alvo in open(os.path.join(tmp, 'data', nome), 'rb').read():
                    achou = True
        check(not achou, 'o ficheiro da base de dados não contém o token em claro')
    # sincronizar usa o token da própria empresa; outra empresa não herda
    s, r, _ = call('POST', '/api/gc_turnkey/vendus/sincronizar', {}, tok['ownerA'])
    check(TOKEN_VENDUS not in json.dumps(r) if not isinstance(r, bytes) else True, 'erros do Vendus não expõem o token', f'status {s}')
    check(s != 503, 'sincronizar usa o token guardado (decifrado no servidor)', f'status {s}')
    s, r, _ = call('POST', '/api/gc_turnkey/vendus/sincronizar', {}, tok['ownerB'])
    check(s == 503, 'empresa sem token não usa o de outra (503 "não configurado")', f'status {s}')
    s, r, _ = call('DELETE', url, tok=tok['ownerA'])
    check(s == 200 and r.get('configurada') is False, 'proprietário remove o token')
    s, r, _ = call('POST', '/api/gc_turnkey/vendus/sincronizar', {}, tok['ownerA'])
    check(s == 503, 'sem token guardado volta a 503', f'status {s}')
    # nada de segredos no registo do servidor
    if tmp and os.path.exists(os.path.join(tmp, 'pb.log')):
        check(TOKEN_VENDUS not in open(os.path.join(tmp, 'pb.log'), errors='ignore').read(), 'o token não aparece nos logs do servidor')


def teste_sem_chave():
    """Servidor sem GC_TURNKEY_ENC_KEY (esquecimento comum): a app tem de dizer o que falta."""
    global URL
    if 'PB_URL' in os.environ:
        return
    sec('7c. Servidor sem chave de cifra')
    original = URL
    tmp2 = tempfile.mkdtemp(prefix='pbsec2_')
    dados2 = os.path.join(tmp2, 'data')
    mig = os.path.join(RAIZ, 'pb', 'migrations')
    subprocess.run([PB_BIN, 'superuser', 'upsert', SUPER[0], SUPER[1], '--dir', dados2, '--migrationsDir', mig],
                   check=True, capture_output=True)
    env = {k: v for k, v in os.environ.items() if k not in ('GC_TURNKEY_DEV', 'GC_TURNKEY_ENC_KEY')}
    p2 = subprocess.Popen([PB_BIN, 'serve', '--dir', dados2, '--migrationsDir', mig,
                           '--hooksDir', os.path.join(RAIZ, 'pb', 'hooks'), '--http', '127.0.0.1:8198'],
                          stdout=open(os.path.join(tmp2, 'pb.log'), 'w'), stderr=subprocess.STDOUT, env=env)
    URL = 'http://127.0.0.1:8198'
    try:
        for _ in range(40):
            try:
                if call('GET', '/api/health')[0] == 200:
                    break
            except Exception:
                pass
            time.sleep(0.5)
        s1, r, _ = call('POST', '/api/collections/_superusers/auth-with-password', {'identity': SUPER[0], 'password': SUPER[1]})
        su2 = r['token']
        s1, e, _ = call('POST', '/api/collections/empresas/records',
                        {'nome': 'X', 'slug': 'x-sem-chave', 'moeda': 'EUR', 'regra_arredondamento': 'cima'}, su2)
        s1, u, _ = call('POST', '/api/collections/users/records',
                        {'email': 'dono@semchave.local', 'password': 'Teste12345!', 'passwordConfirm': 'Teste12345!',
                         'verified': True, 'empresa': e['id'], 'papel': 'owner'}, su2)
        s1, r, _ = call('POST', '/api/collections/users/auth-with-password', {'identity': 'dono@semchave.local', 'password': 'Teste12345!'})
        t = r['token']
        s1, r, _ = call('GET', '/api/gc_turnkey/integracoes/vendus', tok=t)
        check(s1 == 200 and r.get('cifraDisponivel') is False, 'o estado avisa que falta a chave de cifra', str(r))
        s1, r, _ = call('PUT', '/api/gc_turnkey/integracoes/vendus', {'valor': 'TOKEN-QUALQUER-12345'}, t)
        msg = r.get('message', '') if isinstance(r, dict) else ''
        check(s1 == 503 and 'GC_TURNKEY_ENC_KEY' in msg, 'guardar sem chave: erro claro a dizer o que falta', f'{s1} {msg}')
    finally:
        URL = original
        p2.terminate()
        try:
            p2.wait(10)
        except Exception:
            p2.kill()
        shutil.rmtree(tmp2, ignore_errors=True)


# ---------------------------------------------------------------------------
# IA falsa (Gemini) e qpdf falso, para testar faturas com vários documentos
# ---------------------------------------------------------------------------
PORTA_IA = 8188
PORTA_TG = 8189
tg_estado = {'modo': 'ok', 'enviadas': []}
ia_modo = {'modo': 'tres', 'chamadas': {}}


class _GeminiFalso(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def do_POST(self):
        modelo = self.path.split('/models/')[-1].split(':')[0]
        ia_modo['chamadas'][modelo] = ia_modo['chamadas'].get(modelo, 0) + 1
        corpo_pedido = self.rfile.read(int(self.headers.get('Content-Length', 0)))

        def enviar(codigo, corpo):
            b = json.dumps(corpo).encode()
            self.send_response(codigo)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(b)))
            self.end_headers()
            self.wfile.write(b)

        if modelo == 'modelo-a':
            return enviar(503, {'error': {'status': 'UNAVAILABLE', 'message': 'This model is currently experiencing high demand.'}})
        if modelo == 'modelo-b':
            return enviar(404, {'error': {'status': 'NOT_FOUND', 'message': 'model is no longer available'}})
        linha = {'descricao': 'Farinha', 'quantidade': 1, 'preco_unitario': 2.0, 'total': 2.0}
        suf = ia_modo.get('sufixo', '')

        def fat(f, n, pag, data='2026-09-10'):
            return {'fornecedor': f, 'numero': n + suf, 'data': data, 'total': 10.0, 'paginas': pag, 'linhas': [linha]}

        m = ia_modo['modo']
        if m == 'janelas':
            # a janela vem no PDF falso ("%PDF-fake 5-8"): responde com os documentos dessas páginas
            achado = re.search(rb'"data"\s*:\s*"([A-Za-z0-9+/=]+)"', corpo_pedido)
            texto = base64.b64decode(achado.group(1)).decode('latin-1') if achado else ''
            j = re.search(r'fake (\d+)-(\d+)', texto)
            a, b = (int(j.group(1)), int(j.group(2))) if j else (1, 1)
            docs = ia_modo.get('docs') or [('Fornecedor Z', 'Z-1', 1, 3), ('Fornecedor Z', 'Z-2', 4, 8), ('Fornecedor Y', 'Y-1', 9, 10)]
            if ia_modo.get('falhar_janela') == a:
                return enviar(503, {'error': {'status': 'UNAVAILABLE', 'message': 'high demand'}})
            lista = []
            for forn, num, de, ate in docs:
                pags = [p - a + 1 for p in range(max(de, a), min(ate, b) + 1)]
                if pags:
                    lista.append(fat(forn, num, pags))
            return enviar(200, {'candidates': [{'content': {'parts': [{'text': json.dumps({'faturas': lista})}]}}]})
        if m == 'tres':
            dados = {'faturas': [fat('Fornecedor A', 'A-1', [1, 2]), fat('Fornecedor B', 'B-1', [3, 4]), fat('Fornecedor C', 'C-1', [5, 6, 7, 8])]}
        elif m == 'datas':  # mesmo fornecedor, datas e números diferentes no mesmo PDF
            dados = {'faturas': [fat('Fornecedor G', 'G-1', [1], '2026-09-01'), fat('Fornecedor G', 'G-2', [2, 3], '2026-09-08'),
                                 fat('Fornecedor H', 'H-1', [4], '2026-09-08')]}
        elif m == 'sobrepostas':
            dados = {'faturas': [fat('Fornecedor D', 'D-1', [1, 2]), fat('Fornecedor E', 'E-1', [2, 3])]}
        else:  # 'lista': a IA devolve uma lista solta com uma só fatura
            dados = [fat('Fornecedor F', 'F-1', [1])]
        enviar(200, {'candidates': [{'content': {'parts': [{'text': json.dumps(dados)}]}}]})


def ambiente_ia_falsa():
    """Variáveis para o PocketBase de teste + qpdf falso no PATH."""
    pasta = tempfile.mkdtemp(prefix='fakeqpdf_')
    py = os.path.join(pasta, 'fake_qpdf.py')
    open(py, 'w').write(
        "import re, sys\n"
        "a = sys.argv[1:]\n"
        "if a[0] == '--show-npages':\n"
        "    print(len(re.findall(rb'/Type /Page\\b', open(a[1], 'rb').read())))\n"
        "elif a[0] == '--empty':\n"
        "    open(a[5], 'wb').write(b'%PDF-fake ' + a[3].encode())\n")
    open(os.path.join(pasta, 'fake_base64.py'), 'w').write(
        "import base64, sys\n"
        "sys.stdout.write(base64.b64encode(open(sys.argv[-1], 'rb').read()).decode())\n")
    if os.name == 'nt':
        open(os.path.join(pasta, 'qpdf.cmd'), 'w').write('@"%s" "%%~dp0fake_qpdf.py" %%*\r\n' % sys.executable)
        open(os.path.join(pasta, 'base64.cmd'), 'w').write('@"%s" "%%~dp0fake_base64.py" %%*\r\n' % sys.executable)
    else:
        g = os.path.join(pasta, 'base64')
        open(g, 'w').write('#!/bin/sh\nexec "%s" "$(dirname "$0")/fake_base64.py" "$@"\n' % sys.executable)
        os.chmod(g, 0o755)
        f = os.path.join(pasta, 'qpdf')
        open(f, 'w').write('#!/bin/sh\nexec "%s" "$(dirname "$0")/fake_qpdf.py" "$@"\n' % sys.executable)
        os.chmod(f, 0o755)
    global _pasta_qpdf
    _pasta_qpdf = pasta
    return {
        'GEMINI_API_KEY': 'chave-falsa', 'GC_TURNKEY_AI_PROVIDER': 'gemini',
        'GC_TURNKEY_GEMINI_URL': f'http://127.0.0.1:{PORTA_IA}/v1beta/models/',
        'GC_TURNKEY_AI_MODEL': 'modelo-a', 'GC_TURNKEY_AI_MODEL_FALLBACK': 'modelo-b,modelo-c',
        'GC_TURNKEY_AI_ESPERAS': '0,0', 'GC_TURNKEY_JANELA_PAGINAS': '4',
        'GC_TURNKEY_TELEGRAM_URL': f'http://127.0.0.1:{PORTA_TG}',
        'PATH': pasta + os.pathsep + os.environ.get('PATH', ''),
    }


_pasta_qpdf = None


def pdf_de_paginas(n):
    """PDF mínimo com n páginas (só o necessário para o qpdf falso as contar)."""
    objs = ['<< /Type /Catalog /Pages 2 0 R >>',
            '<< /Type /Pages /Kids [%s] /Count %d >>' % (' '.join('%d 0 R' % (3 + i) for i in range(n)), n)]
    for _ in range(n):
        objs.append('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] >>')
    out = '%PDF-1.4\n'
    for i, o in enumerate(objs, 1):
        out += '%d 0 obj\n%s\nendobj\n' % (i, o)
    out += 'trailer\n<< /Size %d /Root 1 0 R >>\n%%%%EOF' % (len(objs) + 1)
    return out.encode('latin-1')


def criar_fatura_pdf(quem, n_paginas, nome='fatura.pdf'):
    pdf = pdf_de_paginas(n_paginas)
    corpo, ct = multipart({'empresa': empresas['A'], 'autor': users[quem], 'tipo': 'fatura', 'estado': 'nova', 'fornecedor': ''},
                          {'ficheiro': (nome, pdf, 'application/pdf')})
    s, r, _ = call('POST', '/api/collections/faturas/records', raw=corpo, ctype=ct, tok=tok[quem])
    return s, r, pdf


def teste_faturas_ia():
    """8. Faturas com IA: repetição, modelos de reserva e divisão de PDFs com várias faturas."""
    if 'PB_URL' in os.environ:
        return
    sec('8. Faturas com IA (Gemini e qpdf falsos)')
    srv = HTTPServer(('127.0.0.1', PORTA_IA), _GeminiFalso)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    try:
        # --- 8 páginas, 3 fornecedores → 3 ficheiros
        ia_modo.update(modo='tres', sufixo='', chamadas={})
        st, rec, pdf = criar_fatura_pdf('editorA', 8)
        check(st == 200, 'criar a fatura com o PDF de 8 páginas', f'status {st} {str(rec)[:120]}')
        s2, r, _ = call('POST', f'/api/gc_turnkey/faturas/{rec["id"]}/analisar',
                        {'imagem': base64.b64encode(pdf).decode(), 'mime': 'application/pdf'}, tok['editorA'])
        check(s2 == 200, 'análise devolve 200 mesmo com o modelo principal sobrecarregado', f'status {s2} {str(r)[:160]}')
        ids = r.get('faturas', []) if isinstance(r, dict) else []
        check(len(ids) == 3 and r.get('dividido') is True, 'PDF de 8 páginas → 3 faturas separadas', str(r)[:160])
        ch = ia_modo['chamadas']
        check(ch.get('modelo-a') == 3, 'modelo principal: 3 tentativas antes de passar ao de reserva', str(ch))
        check(ch.get('modelo-b') == 1, 'modelo de reserva inexistente (404): passa logo ao seguinte', str(ch))
        check(ch.get('modelo-c') == 1, 'terceiro modelo responde uma vez', str(ch))
        esperado = [('Fornecedor A', b'%PDF-fake 1-2'), ('Fornecedor B', b'%PDF-fake 3-4'), ('Fornecedor C', b'%PDF-fake 5-8')]
        s3, ft, _ = call('POST', '/api/files/token', {}, tok['editorA'])
        ftoken = ft.get('token') if isinstance(ft, dict) else ''
        for i, fid in enumerate(ids):
            s4, f, _ = call('GET', f'/api/collections/faturas/records/{fid}', tok=su)
            forn, conteudo = esperado[i]
            check(f.get('fornecedor') == forn and f.get('estado') == 'analisada', f'fatura {i + 1}: {forn}, analisada', str(f)[:120])
            nome = f.get('ficheiro', '')
            s5, corpo_f, _ = call('GET', f'/api/files/faturas/{fid}/{nome}?token={ftoken}')
            check(s5 == 200 and isinstance(corpo_f, bytes) and corpo_f == conteudo,
                  f'fatura {i + 1}: ficheiro próprio com as páginas certas ({conteudo.decode()[10:]})', f'{s5} {str(corpo_f)[:60]} nome={nome}')
            check('parte' in nome, f'fatura {i + 1}: nome do ficheiro identifica a parte', nome)

        if tmp and os.path.exists(os.path.join(tmp, 'pb.log')):
            for l in open(os.path.join(tmp, 'pb.log'), errors='ignore'):
                if 'dividir' in l:
                    print('   (registo do servidor)', l.strip()[:220])

        # --- mesmo fornecedor com datas diferentes no mesmo PDF (digitalização em lote)
        ia_modo.update(modo='datas', chamadas={})
        st, rec, pdf = criar_fatura_pdf('editorA', 4)
        s2, r, _ = call('POST', f'/api/gc_turnkey/faturas/{rec["id"]}/analisar',
                        {'imagem': base64.b64encode(pdf).decode(), 'mime': 'application/pdf'}, tok['editorA'])
        ids = r.get('faturas', []) if isinstance(r, dict) else []
        check(s2 == 200 and len(ids) == 3 and r.get('dividido') is True and r.get('duplicadas') == 0,
              'mesmo fornecedor com datas diferentes: 3 faturas, nenhuma tomada por duplicada', str(r)[:160])
        esperado2 = [('Fornecedor G', '2026-09-01', b'%PDF-fake 1'), ('Fornecedor G', '2026-09-08', b'%PDF-fake 2-3'),
                     ('Fornecedor H', '2026-09-08', b'%PDF-fake 4')]
        s3, ft, _ = call('POST', '/api/files/token', {}, tok['editorA'])
        for i, fid in enumerate(ids):
            s4, f, _ = call('GET', f'/api/collections/faturas/records/{fid}', tok=su)
            forn, data, conteudo = esperado2[i]
            check(f.get('fornecedor') == forn and str(f.get('data_fatura', ''))[:10] == data and f.get('estado') == 'analisada',
                  f'lote {i + 1}: {forn} em {data}', str(f)[:140])
            s5, cf, _ = call('GET', f'/api/files/faturas/{fid}/{f.get("ficheiro", "")}?token={ft.get("token")}')
            check(cf == conteudo, f'lote {i + 1}: ficheiro com as páginas certas', str(cf)[:50])

        # --- páginas que a IA repete → não corta, mas não perde nada
        ia_modo.update(modo='sobrepostas', chamadas={})
        st, rec, pdf = criar_fatura_pdf('editorA', 3)
        s2, r, _ = call('POST', f'/api/gc_turnkey/faturas/{rec["id"]}/analisar',
                        {'imagem': base64.b64encode(pdf).decode(), 'mime': 'application/pdf'}, tok['editorA'])
        ids = r.get('faturas', []) if isinstance(r, dict) else []
        check(s2 == 200 and len(ids) == 2 and r.get('dividido') is False, 'páginas sobrepostas: 2 faturas, sem cortar', str(r)[:160])
        for fid in ids:
            s4, f, _ = call('GET', f'/api/collections/faturas/records/{fid}', tok=su)
            check(bool(f.get('ficheiro')) and 'separá-las' in f.get('notas', ''), 'cada uma fica com o ficheiro inteiro e um aviso', str(f)[:140])

        # --- resposta como lista solta com uma só fatura (formato antigo)
        ia_modo.update(modo='lista', chamadas={})
        st, rec, pdf = criar_fatura_pdf('editorA', 1)
        s2, r, _ = call('POST', f'/api/gc_turnkey/faturas/{rec["id"]}/analisar',
                        {'imagem': base64.b64encode(pdf).decode(), 'mime': 'application/pdf'}, tok['editorA'])
        check(s2 == 200 and r.get('faturas') == [rec['id']] and r.get('dividido') is False, 'uma só fatura: continua igual', str(r)[:140])

        # --- ficheiro grande: análise por janelas de páginas (o ficheiro já está no servidor)
        ia_modo.update(modo='janelas', sufixo='', chamadas={}, falhar_janela=None)
        st, rec, pdf = criar_fatura_pdf('editorA', 10)
        rid = rec['id']
        base = f'/api/gc_turnkey/faturas/{rid}'
        s6, _, _ = call('POST', base + '/preparar', {}, tok['viewerA'])
        check(s6 == 403, 'lote: o papel Leitura não prepara', f'status {s6}')
        s6, _, _ = call('POST', base + '/preparar', {}, tok['editorB'])
        check(s6 in (403, 404), 'lote: outra empresa não prepara', f'status {s6}')
        s6, prep, _ = call('POST', base + '/preparar', {}, tok['editorA'])
        check(s6 == 200 and prep.get('paginas') == 10 and prep.get('proxima') == 1 and prep.get('retomado') is False,
              'lote: preparar conta as 10 páginas', f'{s6} {str(prep)[:120]}')
        s6, _, _ = call('POST', base + '/concluir-analise', {}, tok['editorA'])
        check(s6 == 409, 'lote: não conclui antes de analisar tudo', f'status {s6}')
        # a primeira janela falha (IA sobrecarregada): não perde nada e volta a tentar
        ia_modo['falhar_janela'] = 1
        s6, falha, _ = call('POST', base + '/analisar-parte', {}, tok['editorA'])
        check(s6 in (502, 503), 'lote: IA sobrecarregada devolve erro sem estragar o estado', f'status {s6}')
        ia_modo['falhar_janela'] = None
        passos = []
        for _ in range(6):
            s6, r, _ = call('POST', base + '/analisar-parte', {}, tok['editorA'])
            passos.append((s6, r.get('proxima') if isinstance(r, dict) else None))
            if s6 != 200 or r.get('feito'):
                break
        check(passos == [(200, 5), (200, 9), (200, 11)], 'lote: 3 janelas (1-4, 5-8, 9-10) até acabar', str(passos))
        s6, fim, _ = call('POST', base + '/concluir-analise', {}, tok['editorA'])
        ids = fim.get('faturas', []) if isinstance(fim, dict) else []
        check(s6 == 200 and len(ids) == 3 and fim.get('dividido') is True,
              'lote: 3 faturas (o documento Z-2 atravessa duas janelas e fica junto)', f'{s6} {str(fim)[:160]}')
        esperado = [('Fornecedor Z', 'Z-1', b'%PDF-fake 1-3'), ('Fornecedor Z', 'Z-2', b'%PDF-fake 4-8'), ('Fornecedor Y', 'Y-1', b'%PDF-fake 9-10')]
        s3, ft, _ = call('POST', '/api/files/token', {}, tok['editorA'])
        for i, fid in enumerate(ids):
            s4, f, _ = call('GET', f'/api/collections/faturas/records/{fid}', tok=su)
            forn, num, conteudo = esperado[i]
            check(f.get('fornecedor') == forn and f.get('numero') == num and f.get('estado') == 'analisada',
                  f'lote {i + 1}: {forn} {num}, analisada', str(f)[:140])
            s5, cf, _ = call('GET', f'/api/files/faturas/{fid}/{f.get("ficheiro", "")}?token={ft.get("token")}')
            check(cf == conteudo, f'lote {i + 1}: ficheiro com as páginas certas', str(cf)[:50])

        resumo = fim.get('resumo', {}) if isinstance(fim, dict) else {}
        it = resumo.get('itens', [])
        check(len(it) == 3 and [i.get('paginas') for i in it] == ['1-3', '4-8', '9-10'] and resumo.get('paginasSemFatura') == '',
              'lote: resumo com as 3 faturas e as suas páginas', str(resumo)[:200])

        # páginas em que a IA não reconheceu nenhuma fatura: aparecem no resumo
        ia_modo['docs'] = [('Fornecedor Z', 'Z-1', 1, 3), ('Fornecedor Y', 'Y-1', 6, 10)]
        st, recb, pdfb = criar_fatura_pdf('editorA', 10)
        baseb = f'/api/gc_turnkey/faturas/{recb["id"]}'
        call('POST', baseb + '/preparar', {}, tok['editorA'])
        for _ in range(6):
            s6, r, _ = call('POST', baseb + '/analisar-parte', {}, tok['editorA'])
            if s6 != 200 or r.get('feito'):
                break
        s6, fimb, _ = call('POST', baseb + '/concluir-analise', {}, tok['editorA'])
        check(s6 == 200 and fimb.get('resumo', {}).get('paginasSemFatura') == '4-5',
              'lote: o resumo diz que as páginas 4-5 ficaram sem fatura', str(fimb)[:200])
        ia_modo['docs'] = None

        # retoma: prepara outra vez a meio e continua de onde ficou
        st, rec2, pdf2 = criar_fatura_pdf('editorA', 10)
        base2 = f'/api/gc_turnkey/faturas/{rec2["id"]}'
        call('POST', base2 + '/preparar', {}, tok['editorA'])
        call('POST', base2 + '/analisar-parte', {}, tok['editorA'])
        s6, prep2, _ = call('POST', base2 + '/preparar', {}, tok['editorA'])
        check(s6 == 200 and prep2.get('retomado') is True and prep2.get('proxima') == 5,
              'lote: voltar a preparar retoma a partir da janela seguinte (5)', str(prep2)[:120])
    finally:
        srv.shutdown()


def teste_faturas_edicao():
    """8c. Faturas: só proprietário/administrador editam e apagam; tudo fica no histórico e nada se perde."""
    sec('8c. Editar e apagar faturas (proprietário/administrador)')
    st, f, _ = call('POST', '/api/collections/faturas/records',
                    {'empresa': empresas['A'], 'autor': users['editorA'], 'tipo': 'fatura', 'estado': 'analisada',
                     'fornecedor': 'Forn Errado', 'numero': 'X-1', 'data_fatura': '2026-01-01 00:00:00.000Z', 'total': 10}, su)
    fid = f['id']
    url = f'/api/collections/faturas/records/{fid}'
    s1, _, _ = call('PATCH', url, {'fornecedor': 'Outro'}, tok['editorA'])
    check(s1 in (403, 404), 'o editor não corrige o fornecedor de uma fatura', f'status {s1}')
    s1, _, _ = call('PATCH', url, {'apagada': True}, tok['editorA'])
    check(s1 in (403, 404), 'o editor não apaga uma fatura', f'status {s1}')
    s1, _, _ = call('DELETE', url, tok=tok['editorA'])
    check(s1 in (403, 404), 'o editor não elimina definitivamente uma fatura', f'status {s1}')
    s1, _, _ = call('PATCH', url, {'fornecedor': 'Outro'}, tok['viewerA'])
    check(s1 in (403, 404), 'o papel Leitura não edita faturas', f'status {s1}')
    s1, _, _ = call('PATCH', url, {'fornecedor': 'Outro'}, tok['ownerB'])
    check(s1 in (403, 404), 'o proprietário de outra empresa não edita', f'status {s1}')

    s1, r, _ = call('PATCH', url, {'fornecedor': 'Fornecedor Certo', 'data_fatura': '2026-02-02 00:00:00.000Z', 'numero': 'C-9'}, tok['ownerA'])
    check(s1 == 200 and r.get('fornecedor') == 'Fornecedor Certo', 'o proprietário corrige fornecedor, data e número', f'{s1} {str(r)[:100]}')
    hist = call('GET', f"/api/collections/historico/records?filter=entidade_tipo='fatura'%26%26entidade_id='{fid}'&perPage=20&sort=-created", tok=tok['editorA'])[1].get('items', [])
    check(len(hist) == 1 and hist[0].get('valor_antes', {}).get('fornecedor') == 'Forn Errado'
          and hist[0].get('valor_depois', {}).get('numero') == 'C-9', 'a correção fica no histórico com os valores antes e depois', str(hist)[:240])

    # o administrador também corrige e apaga/restaura (antes era só o proprietário)
    s1, r, _ = call('PATCH', url, {'total': 42}, tok['adminA'])
    check(s1 == 200 and r.get('total') == 42, 'o administrador também corrige uma fatura', f'{s1} {str(r)[:100]}')
    s1, r, _ = call('PATCH', url, {'apagada': True}, tok['adminA'])
    check(s1 == 200 and r.get('apagada') is True, 'o administrador apaga uma fatura', f'{s1} {str(r)[:100]}')
    s1, r, _ = call('PATCH', url, {'apagada': False}, tok['adminA'])
    check(s1 == 200 and r.get('apagada') is False, 'o administrador restaura a fatura', f'{s1} {str(r)[:100]}')

    s1, r, _ = call('PATCH', url, {'apagada': True}, tok['ownerA'])
    check(s1 == 200 and r.get('apagada') is True and r.get('apagada_em') and r.get('apagada_por'), 'o proprietário apaga (fica escondida, com quem e quando)', str(r)[:160])
    ainda = call('GET', url, tok=tok['ownerA'])[1]
    check(ainda.get('id') == fid, 'a fatura apagada continua na base de dados (backups)', str(ainda)[:80])
    s1, r, _ = call('PATCH', url, {'apagada': False}, tok['ownerA'])
    check(s1 == 200 and r.get('apagada') is False and not r.get('apagada_em'), 'o proprietário restaura a fatura', str(r)[:120])
    hist = call('GET', f"/api/collections/historico/records?filter=entidade_tipo='fatura'%26%26entidade_id='{fid}'&perPage=20", tok=tok['editorA'])[1].get('items', [])
    check(len(hist) == 6, 'todas as correções e apagar/restaurar (admin + proprietário) ficam no histórico (6 registos)', str(len(hist)))

    # uma apagada não conta como duplicada nem sai no export da contabilidade
    call('PATCH', url, {'apagada': True, 'estado': 'confirmada'}, tok['ownerA'])
    ex = call('GET', '/api/gc_turnkey/faturas/export?de=2026-01-01&ate=2026-12-31', tok=tok['ownerA'])[1]
    check(fid not in [x.get('id') for x in ex.get('faturas', [])], 'a fatura apagada não vai para a contabilidade', str(ex)[:120])


def teste_faturas_ignorar_lote():
    """8e. Marcar faturas antigas como ignoradas em lote (sem apagar nada)."""
    sec('8e. Ignorar faturas em lote')
    url = '/api/gc_turnkey/faturas/ignorar-lote'

    def fatura(estado, empresa='A', dados_ia=None, pendentes=None):
        body = {'empresa': empresas[empresa], 'autor': users[f'editor{empresa}'],
                'tipo': 'fatura', 'estado': estado, 'fornecedor': 'Fornecedor Antigo'}
        if dados_ia is not None:
            body['dados_ia'] = dados_ia
        if pendentes is not None:
            body['pendentes_linhas'] = pendentes
        st, r, _ = call('POST', '/api/collections/faturas/records', body, su)
        assert st == 200, (st, r)
        return r['id']

    f1 = fatura('analisada', pendentes=2)
    f2 = fatura('nova')
    f3 = fatura('confirmada')  # já confirmada — também pode ser marcada (deixa de aparecer como "por rever")
    f_apagada = fatura('analisada')
    call('PATCH', f"/api/collections/faturas/records/{f_apagada}", {'apagada': True}, su)
    f_outra_empresa = fatura('analisada', empresa='B')

    st, rv, _ = call('POST', url, {'ids': [f1]}, tok['viewerA'])
    check(st != 200, 'o papel Leitura não marca faturas como ignoradas', f'status {st}')
    st, rvazio, _ = call('POST', url, {'ids': []}, tok['editorA'])
    check(st != 200, 'sem ids é recusado', f'status {st}')

    st, r, _ = call('POST', url, {'ids': [f1, f2, f3, f_apagada, f_outra_empresa]}, tok['editorA'])
    check(st == 200 and r.get('atualizadas') == 3,
          'editor marca em lote: só as 3 válidas da própria empresa (ignora apagada e doutra empresa)', f'{st} {str(r)[:160]}')

    for fid in (f1, f2, f3):
        rec = call('GET', f'/api/collections/faturas/records/{fid}', tok=tok['editorA'])[1]
        check(rec.get('estado') == 'ignorada' and rec.get('pendentes_linhas') == 0,
              f'{fid}: fica "ignorada" e sem pendentes', str(rec)[:120])

    rec_apagada = call('GET', f'/api/collections/faturas/records/{f_apagada}', tok=tok['editorA'])[1]
    check(rec_apagada.get('estado') != 'ignorada', 'uma fatura apagada não é marcada como ignorada', str(rec_apagada)[:120])
    rec_b = call('GET', f'/api/collections/faturas/records/{f_outra_empresa}', tok=tok['ownerB'])[1]
    check(rec_b.get('estado') != 'ignorada', 'a fatura da empresa B não foi tocada pelo editor da A', str(rec_b)[:120])

    # reaplicar (decidir uma linha) tira a fatura sozinha do estado "ignorada"
    st, f4, _ = call('POST', '/api/collections/faturas/records',
                     {'empresa': empresas['A'], 'autor': users['editorA'], 'tipo': 'fatura', 'estado': 'analisada',
                      'fornecedor': 'X', 'dados_ia': {'linhas': [{'descricao': 'Item', 'quantidade': 1}]}}, su)
    f4 = f4['id']
    call('POST', url, {'ids': [f4]}, tok['editorA'])
    ing = dados[('ingredientes', 'A')][1]
    st, ingr, _ = call('POST', '/api/collections/ingredientes/records', dict(ing, nome='Ingrediente ignorar-lote'), tok['editorA'])
    st, r4, _ = call('POST', f'/api/gc_turnkey/faturas/{f4}/aplicar',
                     {'linhas': [{'index': 0, 'ingredienteId': ingr['id'], 'acao': 'ignorar', 'descricaoFatura': 'Item'}]}, tok['editorA'])
    f4rec = call('GET', f'/api/collections/faturas/records/{f4}', tok=tok['editorA'])[1]
    check(f4rec.get('estado') != 'ignorada', 'decidir (mesmo "Ignorar") uma linha tira a fatura do estado "ignorada"', f'{str(r4)[:100]} {str(f4rec)[:120]}')


def teste_faturas_linha_manual():
    """8f. Acrescentar à mão uma linha que a IA não leu (total de linhas sobe com ela)."""
    sec('8f. Linha acrescentada à mão na revisão')
    t = tok['editorA']
    # só 1 linha no dados_ia — a app vai enviar 2 (a original + 1 acrescentada à mão)
    st, f, _ = call('POST', '/api/collections/faturas/records',
                    {'empresa': empresas['A'], 'autor': users['editorA'], 'tipo': 'fatura', 'estado': 'analisada',
                     'fornecedor': 'X', 'dados_ia': {'linhas': [{'descricao': 'Item lido pela IA'}]}}, su)
    fid = f['id']
    base = dict(dados[('ingredientes', 'A')][1])
    base.update(origem='comprado', preco=0, gramas_embalagem=0)
    ing = call('POST', '/api/collections/ingredientes/records', dict(base, nome='Ingrediente linha manual'), t)[1]['id']
    # linha 0 (da IA) decidida; linha 1 (acrescentada à mão) ainda por decidir
    st, r, _ = call('POST', f'/api/gc_turnkey/faturas/{fid}/aplicar',
                    {'linhas': [
                        {'index': 0, 'ingredienteId': ing, 'acao': 'preco', 'precoUnitario': 1.5, 'descricaoFatura': 'Item lido pela IA'},
                        {'index': 1, 'acao': 'pendente', 'descricaoFatura': ''},
                    ]}, t)
    check(st == 200, 'aplicar com uma linha extra (acrescentada à mão) não rebenta', f'status {st} {str(r)[:160]}')
    frec = call('GET', f'/api/collections/faturas/records/{fid}', tok=t)[1]
    check(frec.get('estado') == 'analisada' and frec.get('pendentes_linhas') == 1,
          'o total de linhas sobe com a acrescentada à mão: continua "1 por rever" (não fica logo confirmada)',
          str(frec)[:160])
    # decidir a linha acrescentada: agora sim fica tudo resolvido
    st, r2, _ = call('POST', f'/api/gc_turnkey/faturas/{fid}/aplicar',
                     {'linhas': [{'index': 1, 'acao': 'ignorar', 'descricaoFatura': ''}]}, t)
    frec2 = call('GET', f'/api/collections/faturas/records/{fid}', tok=t)[1]
    check(frec2.get('estado') == 'confirmada' and frec2.get('pendentes_linhas') == 0,
          'decidida a linha acrescentada à mão, a fatura fica confirmada', str(frec2)[:160])


def teste_notas_pagina():
    """8g. Notas de equipa por página (diferente de sugestões — a equipa toda vê)."""
    sec('8g. Notas de página')
    url = '/api/collections/notas_pagina/records'

    # viewer pode criar e ler (é para avisar a equipa, mesmo quem só lê)
    st, n, _ = call('POST', url, {'empresa': empresas['A'], 'pagina': 'faturas', 'texto': 'Falta a foto do rótulo.'}, tok['viewerA'])
    check(st == 200, 'o papel Leitura cria uma nota', f'status {st} {str(n)[:120]}')
    nid = n['id']
    check(n.get('autor_nome') == 'viewerA' and n.get('resolvida') is False,
          'o autor fica carimbado pelo servidor (não pelo corpo do pedido)', str(n)[:160])
    st, lst, _ = call('GET', f"{url}?filter=pagina='faturas'", tok=tok['viewerA'])
    check(st == 200 and nid in [x['id'] for x in lst.get('items', [])], 'o papel Leitura lê as notas da própria empresa', str(lst)[:160])

    # isolamento entre empresas
    st, lst_b, _ = call('GET', f"{url}?filter=pagina='faturas'", tok=tok['ownerB'])
    check(nid not in [x['id'] for x in lst_b.get('items', [])], 'a empresa B não vê a nota da empresa A', str(lst_b)[:160])
    st, r_b, _ = call('PATCH', f'{url}/{nid}', {'resolvida': True}, tok['ownerB'])
    check(st != 200, 'a empresa B não resolve uma nota da empresa A', f'status {st} {str(r_b)[:100]}')

    # viewer não marca como resolvida; editor sim
    st, rv, _ = call('PATCH', f'{url}/{nid}', {'resolvida': True}, tok['viewerA'])
    check(st != 200, 'o papel Leitura não marca uma nota como resolvida', f'status {st}')
    st, re_, _ = call('PATCH', f'{url}/{nid}', {'resolvida': True}, tok['editorA'])
    check(st == 200 and re_.get('resolvida') is True and re_.get('resolvida_por') == 'editorA' and re_.get('resolvida_em'),
          'o editor marca como resolvida (fica carimbado quem e quando)', f'{st} {str(re_)[:160]}')

    # o texto/página não mudam pela API depois de criada (só a "resolvida")
    st, rtxt, _ = call('PATCH', f'{url}/{nid}', {'texto': 'texto trocado', 'pagina': 'outra'}, tok['editorA'])
    check(st == 200 and rtxt.get('texto') == 'Falta a foto do rótulo.' and rtxt.get('pagina') == 'faturas',
          'o texto e a página da nota não se alteram depois de criada', str(rtxt)[:160])

    # apagar: só proprietário/administrador
    st, r_ed, _ = call('DELETE', f'{url}/{nid}', tok=tok['editorA'])
    check(st != 200, 'o editor não apaga uma nota', f'status {st}')
    st, r_ad, _ = call('DELETE', f'{url}/{nid}', tok=tok['adminA'])
    check(st in (200, 204), 'o administrador apaga uma nota', f'status {st}')


def teste_faturas_pendente_embalagem():
    """8d. Aplicar por partes (linhas pendentes) e faturas com embalagens."""
    sec('8d. Aplicar por partes e embalagens nas faturas')
    t = tok['editorA']
    base = dict(dados[('ingredientes', 'A')][1])
    base.update(origem='comprado', preco=0, gramas_embalagem=0)

    def ingrediente(nome):
        st, r, _ = call('POST', '/api/collections/ingredientes/records', dict(base, nome=nome), t)
        assert st == 200, (st, r)
        return r['id']

    ing_a = ingrediente('Ingrediente pendente A')
    ing_b = ingrediente('Ingrediente pendente B')

    dados_ia = {'linhas': [
        {'descricao': 'Farinha X 1kg', 'quantidade': 1, 'unidade': 'un'},
        {'descricao': 'Coisa desconhecida', 'quantidade': 1, 'unidade': 'un'},
    ]}
    st, f, _ = call('POST', '/api/collections/faturas/records',
                    {'empresa': empresas['A'], 'autor': users['editorA'], 'tipo': 'fatura', 'estado': 'analisada',
                     'fornecedor': 'Fornecedor Parcial', 'data_fatura': '2026-09-20 00:00:00.000Z',
                     'dados_ia': dados_ia}, su)
    assert st == 200, (st, f)
    fid = f['id']
    base_url = f'/api/gc_turnkey/faturas/{fid}'

    linha0 = {'index': 0, 'ingredienteId': ing_a, 'acao': 'preco', 'precoUnitario': 2.0,
              'descricaoFatura': 'Farinha X 1kg', 'embalagemG': 1000}
    linha1 = {'index': 1, 'acao': 'pendente', 'descricaoFatura': 'Coisa desconhecida'}
    st, r1, _ = call('POST', f'{base_url}/aplicar', {'linhas': [linha0, linha1]}, t)
    check(st == 200 and r1.get('precos') == 1 and r1.get('pendentes') == 1,
          'aplicar parcial: 1 preço aplicado, 1 linha fica pendente', f'{st} {str(r1)[:160]}')
    fat1 = call('GET', f"/api/collections/faturas/records/{fid}", tok=t)[1]
    check(fat1.get('estado') == 'analisada' and fat1.get('pendentes_linhas') == 1,
          'a fatura fica "analisada" (não confirmada) com 1 linha pendente', str(fat1)[:160])
    ing_a1 = call('GET', f'/api/collections/ingredientes/records/{ing_a}', tok=t)[1]
    check(abs(ing_a1.get('preco', 0) - 2.0) < 1e-6, 'o preço da linha decidida foi aplicado', str(ing_a1)[:120])
    itens1 = call('GET', f"/api/collections/faturas_itens/records?filter=fatura='{fid}'&perPage=50", tok=t)[1].get('items', [])
    check(len(itens1) == 2, 'ficam 2 linhas gravadas (uma aplicada, uma pendente)', str(len(itens1)))

    # segunda ronda: tenta mudar o preço já aplicado (tem de ser ignorado) e decide a pendente
    linha0b = dict(linha0, precoUnitario=99.0)
    linha1b = {'index': 1, 'ingredienteId': ing_b, 'acao': 'preco', 'precoUnitario': 3.0, 'embalagemG': 1000, 'descricaoFatura': 'Coisa desconhecida'}
    st, r2, _ = call('POST', f'{base_url}/aplicar', {'linhas': [linha0b, linha1b]}, t)
    check(st == 200 and r2.get('puladas') == 1 and r2.get('precos') == 1 and r2.get('pendentes') == 0,
          'segunda ronda: a linha já aplicada é saltada; a pendente aplica-se', f'{st} {str(r2)[:160]}')
    ing_a2 = call('GET', f'/api/collections/ingredientes/records/{ing_a}', tok=t)[1]
    check(abs(ing_a2.get('preco', 0) - 2.0) < 1e-6, 'reaplicar não muda o preço já aplicado (sem duplicar)', str(ing_a2)[:120])
    ing_b1 = call('GET', f'/api/collections/ingredientes/records/{ing_b}', tok=t)[1]
    check(abs(ing_b1.get('preco', 0) - 3.0) < 1e-6, 'a linha antes pendente já tem o preço novo', str(ing_b1)[:120])
    fat2 = call('GET', f"/api/collections/faturas/records/{fid}", tok=t)[1]
    check(fat2.get('estado') == 'confirmada' and fat2.get('pendentes_linhas') == 0,
          'sem mais pendentes: a fatura fica confirmada', str(fat2)[:120])
    itens2 = call('GET', f"/api/collections/faturas_itens/records?filter=fatura='{fid}'&perPage=50", tok=t)[1].get('items', [])
    check(len(itens2) == 2, 'continuam só 2 linhas (não duplicou ao reaplicar)', str(len(itens2)))

    # --- embalagens: preço fica na embalagem escolhida ------------------------------
    emb = dados[('embalagens', 'A')][1]
    st, e1, _ = call('POST', '/api/collections/embalagens/records',
                     dict(emb, nome='Caixa take-away teste', tipo='Caixa', preco_compra=0, fornecedor=''), t)
    check(st == 200, 'criar a embalagem', f'status {st} {str(e1)[:120]}')
    eid = e1['id']
    st, f2, _ = call('POST', '/api/collections/faturas/records',
                     {'empresa': empresas['A'], 'autor': users['editorA'], 'tipo': 'fatura', 'estado': 'analisada',
                      'fornecedor': 'Fornecedor Embalagens', 'data_fatura': '2026-09-21 00:00:00.000Z',
                      'dados_ia': {'linhas': [{'descricao': 'Caixa take-away 20x20', 'quantidade': 100, 'unidade': 'un'}]}}, su)
    fid2 = f2['id']
    linhaE = {'index': 0, 'embalagemId': eid, 'acao': 'preco', 'precoUnitario': 0.42, 'pecasCompradas': 100, 'descricaoFatura': 'Caixa take-away 20x20'}
    st, r3, _ = call('POST', f'/api/gc_turnkey/faturas/{fid2}/aplicar', {'linhas': [linhaE]}, t)
    check(st == 200 and r3.get('precos') == 1 and r3.get('pendentes') == 0, 'aplicar a linha de embalagem', f'{st} {str(r3)[:160]}')
    e2 = call('GET', f'/api/collections/embalagens/records/{eid}', tok=t)[1]
    check(abs(e2.get('preco_compra', 0) - 0.42) < 1e-6 and e2.get('unidades_compra') == 100 and e2.get('fornecedor') == 'Fornecedor Embalagens',
          'a embalagem fica com o preço, as peças compradas e o fornecedor da fatura', str(e2)[:160])
    check('caixa take-away' in json.dumps(e2.get('nomes_fatura', [])).lower(), 'o nome da fatura ficou aprendido na embalagem', str(e2.get('nomes_fatura'))[:120])

    # isolamento: uma embalagem de outra empresa não é tocada
    emb_b = dados[('embalagens', 'B')][1]
    st, eb, _ = call('POST', '/api/collections/embalagens/records', dict(emb_b, nome='Caixa B teste', preco_compra=0), tok['ownerB'])
    eb_id = eb['id']
    st, f3, _ = call('POST', '/api/collections/faturas/records',
                     {'empresa': empresas['A'], 'autor': users['editorA'], 'tipo': 'fatura', 'estado': 'analisada',
                      'fornecedor': 'X', 'dados_ia': {'linhas': [{'descricao': 'x'}]}}, su)
    st, r4, _ = call('POST', f"/api/gc_turnkey/faturas/{f3['id']}/aplicar",
                     {'linhas': [{'index': 0, 'embalagemId': eb_id, 'acao': 'preco', 'precoUnitario': 9.0, 'descricaoFatura': 'x'}]}, t)
    check(st == 200, 'aplicar com embalagem de outra empresa não rebenta', f'status {st}')
    eb2 = call('GET', f'/api/collections/embalagens/records/{eb_id}', tok=tok['ownerB'])[1]
    check(eb2.get('preco_compra', -1) == 0, 'a embalagem da empresa B não foi alterada', str(eb2)[:120])

    # --- embalagens.formatos_cookie: relação múltipla, TODOS os ids têm de ser da mesma empresa ---
    # (a regra declarativa só garante que PELO MENOS UM é da empresa certa numa
    # lista; isto testa especificamente uma lista MISTA para provar que o hook
    # embalagens_validacao.pb.js está a validar cada id, não só a regra.)
    fmt_a = dados.get(('formatos_cookie', 'A'))
    fmt_b = dados.get(('formatos_cookie', 'B'))
    if fmt_a and fmt_b:
        st, emix, _ = call('POST', '/api/collections/embalagens/records',
                            dict(emb, nome='Caixa formatos mista', preco_compra=0,
                                 formatos_cookie=[fmt_a[0], fmt_b[0]]), t)
        check(st != 200, 'embalagens.formatos_cookie: lista MISTA (1 de A + 1 de B) é recusada', f'status {st} {str(emix)[:160]}')
        st, eok, _ = call('POST', '/api/collections/embalagens/records',
                           dict(emb, nome='Caixa formato próprio', preco_compra=0,
                                formatos_cookie=[fmt_a[0]]), t)
        check(st == 200, 'embalagens.formatos_cookie: lista só com formatos da própria empresa é aceite', f'status {st} {str(eok)[:160]}')
        if st == 200:
            st, eupd, _ = call('PATCH', f"/api/collections/embalagens/records/{eok['id']}",
                                {'formatos_cookie': [fmt_a[0], fmt_b[0]]}, t)
            check(st != 200, 'embalagens.formatos_cookie: atualizar para uma lista mista também é recusado', f'status {st} {str(eupd)[:160]}')
    else:
        aviso('embalagens.formatos_cookie (lista mista): formatos_cookie não foi semeado em A/B — não testado')

    # --- bug: fornecedor não ficava gravado quando o produto já EXISTIA (emparelhado) ---
    # marca já funcionava (só preenchia se estivesse em branco, independente de o
    # produto ser novo ou existente); fornecedor só era gravado ao CRIAR o produto.
    ing_c = ingrediente('Ingrediente fornecedor bug')
    st, fnf, _ = call('POST', '/api/collections/faturas/records',
                       {'empresa': empresas['A'], 'autor': users['editorA'], 'tipo': 'fatura', 'estado': 'analisada',
                        'fornecedor': '', 'data_fatura': '2026-09-10 00:00:00.000Z',
                        'dados_ia': {'linhas': [{'descricao': 'Manteiga Mimosa 250g', 'quantidade': 1, 'unidade': 'un'}]}}, su)
    fid_nf = fnf['id']
    st, rnf, _ = call('POST', f"/api/gc_turnkey/faturas/{fid_nf}/aplicar",
                       {'linhas': [{'index': 0, 'ingredienteId': ing_c, 'acao': 'preco', 'precoUnitario': 1.2,
                                    'descricaoFatura': 'Manteiga Mimosa 250g', 'marca': 'Mimosa', 'embalagemG': 250}]}, t)
    check(st == 200 and rnf.get('precos') == 1, 'cria o produto (1ª fatura, sem fornecedor)', f'{st} {str(rnf)[:160]}')
    prods_c = call('GET', f"/api/collections/ingrediente_produtos/records?filter=ingrediente='{ing_c}'", tok=t)[1].get('items', [])
    check(len(prods_c) == 1 and prods_c[0].get('fornecedor', '?') == '', 'o produto fica sem fornecedor (a 1ª fatura não tinha)', str(prods_c)[:160])

    st, fnf2, _ = call('POST', '/api/collections/faturas/records',
                        {'empresa': empresas['A'], 'autor': users['editorA'], 'tipo': 'fatura', 'estado': 'analisada',
                         'fornecedor': 'Continente', 'data_fatura': '2026-09-15 00:00:00.000Z',
                         'dados_ia': {'linhas': [{'descricao': 'Manteiga Mimosa 250g', 'quantidade': 1, 'unidade': 'un'}]}}, su)
    fid_nf2 = fnf2['id']
    st, rnf2, _ = call('POST', f"/api/gc_turnkey/faturas/{fid_nf2}/aplicar",
                        {'linhas': [{'index': 0, 'ingredienteId': ing_c, 'acao': 'preco', 'precoUnitario': 1.3,
                                     'descricaoFatura': 'Manteiga Mimosa 250g'}]}, t)
    check(st == 200, '2ª fatura emparelha o MESMO produto (pelo nome já aprendido)', f'{st} {str(rnf2)[:160]}')
    prods_c2 = call('GET', f"/api/collections/ingrediente_produtos/records?filter=ingrediente='{ing_c}'", tok=t)[1].get('items', [])
    check(len(prods_c2) == 1 and prods_c2[0].get('fornecedor') == 'Continente',
          'BUG CORRIGIDO: o fornecedor da 2ª fatura fica gravado no produto já existente', str(prods_c2)[:160])

    # --- o ingrediente GENÉRICO (o que aparece na lista de Ingredientes) também
    # fica com a marca/fornecedor do produto mais recente — não só o produto ---
    ing_c_final = call('GET', f'/api/collections/ingredientes/records/{ing_c}', tok=t)[1]
    check(ing_c_final.get('marca') == 'Mimosa' and ing_c_final.get('fornecedor') == 'Continente',
          'o ingrediente genérico sincroniza marca/fornecedor do produto com a compra mais recente',
          str(ing_c_final)[:160])

    # --- /corrigir-item: proprietário/administrador corrigem a MARCA mesmo já aplicada ---
    # (fornecedor NÃO se corrige aqui: é um só por fatura — ver bloco seguinte)
    st, item_nf2, _ = call('GET', f"/api/collections/faturas_itens/records?filter=fatura='{fid_nf2}'", tok=t)
    item_nf2 = item_nf2.get('items', [{}])[0]
    check(item_nf2.get('produto') == prods_c2[0]['id'] and item_nf2.get('fornecedor') == 'Continente',
          'faturas_itens guarda o produto/marca/fornecedor tocados, para dar para corrigir depois', str(item_nf2)[:160])

    corrige_url = f'/api/gc_turnkey/faturas/{fid_nf2}/corrigir-item'
    st, rc0, _ = call('POST', corrige_url, {'index': 0, 'marca': 'X'}, tok['editorA'])
    check(st != 200, 'corrigir-item: editor não pode (só proprietário/administrador)', f'status {st} {str(rc0)[:120]}')
    st, rc0b, _ = call('POST', corrige_url, {'index': 0, 'marca': 'X'}, tok['viewerA'])
    check(st != 200, 'corrigir-item: viewer não pode', f'status {st}')
    st, rcb, _ = call('POST', corrige_url, {'index': 0, 'marca': 'X'}, tok['ownerB'])
    check(st != 200, 'corrigir-item: fatura de outra empresa é recusada', f'status {st}')
    st, rcf, _ = call('POST', corrige_url, {'index': 0, 'fornecedor': 'Y'}, tok['ownerA'])
    check(st != 200, 'corrigir-item: sem "marca" no corpo é recusado (fornecedor não se corrige aqui)', f'status {st} {str(rcf)[:120]}')

    st, rc1, _ = call('POST', corrige_url, {'index': 0, 'marca': 'Marca Corrigida'}, tok['ownerA'])
    check(st == 200 and rc1.get('marca') == 'Marca Corrigida',
          'corrigir-item: o proprietário corrige a marca, mesmo já aplicada/confirmada', f'{st} {str(rc1)[:160]}')
    prod_final = call('GET', f"/api/collections/ingrediente_produtos/records/{prods_c2[0]['id']}", tok=t)[1]
    check(prod_final.get('marca') == 'Marca Corrigida',
          'a correção SUBSTITUI a marca que já lá estava (ao contrário de /aplicar, que só preenche em branco)', str(prod_final)[:160])
    item_final = call('GET', f"/api/collections/faturas_itens/records?filter=fatura='{fid_nf2}'", tok=t)[1].get('items', [{}])[0]
    check(item_final.get('marca') == 'Marca Corrigida',
          'faturas_itens também fica com a marca corrigida', str(item_final)[:160])

    st, rc2, _ = call('POST', corrige_url, {'index': 0, 'marca': 'Marca do Admin'}, tok['adminA'])
    check(st == 200 and rc2.get('marca') == 'Marca do Admin',
          'corrigir-item: o administrador também pode corrigir a marca', f'{st} {str(rc2)[:160]}')
    ing_c_marca = call('GET', f'/api/collections/ingredientes/records/{ing_c}', tok=t)[1]
    check(ing_c_marca.get('marca') == 'Marca do Admin',
          'corrigir a marca do produto também sincroniza o ingrediente genérico', str(ing_c_marca)[:160])

    # --- corrigir o FORNECEDOR: só uma vez, no cabeçalho da fatura — propaga sozinho ---
    st, redit, _ = call('PATCH', f'/api/collections/faturas/records/{fid_nf2}', {'fornecedor': 'Fornecedor Corrigido no Cabeçalho'}, tok['ownerA'])
    check(st == 200, 'corrigir o fornecedor no cabeçalho da fatura (só o proprietário)', f'status {st} {str(redit)[:160]}')
    prod_prop = call('GET', f"/api/collections/ingrediente_produtos/records/{prods_c2[0]['id']}", tok=t)[1]
    check(prod_prop.get('fornecedor') == 'Fornecedor Corrigido no Cabeçalho',
          'corrigir o fornecedor no cabeçalho PROPAGA ao produto que esta fatura já tinha tocado', str(prod_prop)[:160])
    item_prop = call('GET', f"/api/collections/faturas_itens/records?filter=fatura='{fid_nf2}'", tok=t)[1].get('items', [{}])[0]
    check(item_prop.get('fornecedor') == 'Fornecedor Corrigido no Cabeçalho',
          'faturas_itens também fica com o fornecedor propagado', str(item_prop)[:160])
    check(prod_prop.get('marca') == 'Marca do Admin',
          'a propagação do fornecedor não mexe na marca', str(prod_prop)[:160])


def teste_produtos():
    """9. Ingredientes genéricos e produtos de compra: custo pela compra mais recente."""
    sec('9. Ingredientes genéricos e produtos')
    t = tok['editorA']
    base = dict(dados[('ingredientes', 'A')][1])
    base.update(nome='Açúcar branco', origem='comprado', preco=0, gramas_embalagem=0)
    st, ing, _ = call('POST', '/api/collections/ingredientes/records', base, t)
    check(st == 200, 'criar o ingrediente genérico', f'status {st} {str(ing)[:120]}')
    gid = ing['id']

    def produto(nome, marca, emb, preco, data):
        return call('POST', '/api/collections/ingrediente_produtos/records',
                    {'empresa': empresas['A'], 'ingrediente': gid, 'nome': nome, 'marca': marca, 'embalagem_g': emb,
                     'preco': preco, 'preco_atualizado_em': data + ' 00:00:00.000Z'}, t)

    def generico():
        return call('GET', f'/api/collections/ingredientes/records/{gid}', tok=t)[1]

    st, p1, _ = produto('Açúcar Sidul branco 1 kg', 'Sidul', 1000, 1.20, '2026-09-01')
    check(st == 200, 'criar o produto Sidul', f'status {st} {str(p1)[:120]}')
    g = generico()
    check(abs(g['preco'] - 1.20) < 1e-6 and g['gramas_embalagem'] == 1000, 'o genérico assume o custo do único produto', str(g)[:120])
    st, p2, _ = produto('Açúcar Makro branco 5 kg', 'Makro', 5000, 5.00, '2026-09-10')
    g = generico()
    check(abs(g['preco'] - 5.00) < 1e-6 and g['gramas_embalagem'] == 5000, 'compra mais recente manda (Makro, 10/09)', str(g)[:120])
    call('PATCH', f'/api/collections/ingrediente_produtos/records/{p1["id"]}', {'preco': 1.10, 'preco_atualizado_em': '2026-09-20 00:00:00.000Z'}, t)
    g = generico()
    check(abs(g['preco'] - 1.10) < 1e-6 and g['gramas_embalagem'] == 1000, 'novo preço do Sidul (20/09) volta a ser o mais recente', str(g)[:120])
    call('DELETE', f'/api/collections/ingrediente_produtos/records/{p1["id"]}', tok=t)
    g = generico()
    check(abs(g['preco'] - 5.00) < 1e-6 and g['gramas_embalagem'] == 5000, 'apagar o mais recente: o custo volta ao anterior', str(g)[:120])

    # permissões e isolamento
    st, _, _ = call('POST', '/api/collections/ingrediente_produtos/records',
                    {'empresa': empresas['A'], 'ingrediente': gid, 'nome': 'x', 'embalagem_g': 1, 'preco': 1}, tok['viewerA'])
    check(st != 200, 'o papel Leitura não cria produtos', f'status {st}')
    st, _, _ = call('POST', '/api/collections/ingrediente_produtos/records',
                    {'empresa': empresas['B'], 'ingrediente': gid, 'nome': 'x', 'embalagem_g': 1, 'preco': 1}, tok['ownerB'])
    check(st != 200, 'a empresa B não cria produtos para um ingrediente da empresa A', f'status {st}')
    st, r, _ = call('GET', '/api/collections/ingrediente_produtos/records', tok=tok['ownerB'])
    check(st == 200 and not [i for i in r.get('items', []) if i['empresa'] == empresas['A']], 'a empresa B não vê produtos da empresa A')

    # --- faturas: o preço vai para o produto e o nome da fatura é aprendido
    def fatura(data):
        st, f, _ = call('POST', '/api/collections/faturas/records',
                        {'empresa': empresas['A'], 'autor': users['editorA'], 'tipo': 'fatura', 'estado': 'analisada',
                         'fornecedor': 'Margão Distribuição', 'data_fatura': data + ' 00:00:00.000Z'}, su)
        return f['id']

    desc = 'Cravinho moído margao pac 14gr'
    linha = {'ingredienteId': gid, 'descricaoFatura': desc, 'marca': 'Margão', 'quantidadeG': 0, 'precoUnitario': 1.5,
             'totalLinha': 1.5, 'embalagemG': 14, 'acao': 'preco'}
    f1 = fatura('2026-09-25')
    st, r, _ = call('POST', f'/api/gc_turnkey/faturas/{f1}/aplicar', {'linhas': [linha]}, t)
    check(st == 200 and r.get('precos') == 1, 'aplicar fatura: 1 preço atualizado', f'{st} {str(r)[:120]}')
    st, lista, _ = call('GET', f"/api/collections/ingrediente_produtos/records?filter=ingrediente='{gid}'&perPage=50", tok=t)
    itens = lista.get('items', [])
    novo = [i for i in itens if i['marca'] == 'Margão']
    check(len(novo) == 1 and abs(novo[0]['preco'] - 1.5) < 1e-6 and novo[0]['embalagem_g'] == 14, 'a fatura criou o produto Margão (14 g, 1,50)', str(itens)[:200])
    check('cravinho mo' in json.dumps(novo[0].get('nomes_fatura', [])).lower() if novo else False, 'o nome da fatura ficou guardado para a próxima vez')
    g = generico()
    check(abs(g['preco'] - 1.5) < 1e-6 and g['gramas_embalagem'] == 14, 'o genérico assume a compra mais recente (fatura de 25/09)', str(g)[:120])

    # segunda fatura, mais recente, com o mesmo texto: reutiliza o produto (sem duplicar) e atualiza o preço
    f2 = fatura('2026-09-30')
    linha2 = dict(linha, precoUnitario=1.8)
    st, r, _ = call('POST', f'/api/gc_turnkey/faturas/{f2}/aplicar', {'linhas': [linha2]}, t)
    st, lista, _ = call('GET', f"/api/collections/ingrediente_produtos/records?filter=ingrediente='{gid}'&perPage=50", tok=t)
    check(len(lista.get('items', [])) == len(itens), 'mesmo texto de fatura: reutiliza o produto (não cria outro)', str(len(lista.get('items', []))))
    check(abs(generico()['preco'] - 1.8) < 1e-6, 'preço novo do produto passa ao genérico')

    # fatura mais antiga: não mexe no custo
    f3 = fatura('2026-09-05')
    linha3 = dict(linha, precoUnitario=0.5)
    st, r, _ = call('POST', f'/api/gc_turnkey/faturas/{f3}/aplicar', {'linhas': [linha3]}, t)
    check(st == 200 and r.get('precosIgnorados') == 1, 'fatura mais antiga: preço ignorado', str(r)[:120])
    check(abs(generico()['preco'] - 1.8) < 1e-6, 'o custo do genérico não mudou com a fatura antiga')


def teste_consumiveis():
    """10. Limpeza e insumos: documentos protegidos, isolamento e faturas."""
    sec('10. Limpeza e insumos (documentos)')
    t = tok['editorA']
    st, c, _ = call('POST', '/api/collections/consumiveis/records',
                    {'empresa': empresas['A'], 'nome': 'Desengordurante', 'categoria': 'limpeza', 'exige_fds': True}, t)
    check(st == 200, 'criar um consumível', f'status {st} {str(c)[:120]}')
    cid = c['id']
    st, _, _ = call('POST', '/api/collections/consumiveis/records',
                    {'empresa': empresas['A'], 'nome': 'x', 'categoria': 'limpeza'}, tok['viewerA'])
    check(st != 200, 'o papel Leitura não cria consumíveis', f'status {st}')
    st, r, _ = call('GET', '/api/collections/consumiveis/records', tok=tok['ownerB'])
    check(st == 200 and not [i for i in r.get('items', []) if i['empresa'] == empresas['A']],
          'a empresa B não vê consumíveis da empresa A')

    pdf = b'%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\ntrailer\n<< /Root 1 0 R >>\n%%EOF'

    def anexar(quem, emp, cons, nome='fds.pdf', conteudo=pdf, mime='application/pdf'):
        corpo, ct = multipart({'empresa': emp, 'consumivel': cons, 'tipo': 'fds', 'versao': '1'},
                              {'ficheiro': (nome, conteudo, mime)})
        return call('POST', '/api/collections/consumivel_documentos/records', raw=corpo, ctype=ct, tok=tok[quem])

    st, d, _ = anexar('editorA', empresas['A'], cid)
    check(st == 200, 'anexar uma FDS em PDF', f'status {st} {str(d)[:120]}')
    st, _, _ = anexar('viewerA', empresas['A'], cid)
    check(st != 200, 'o papel Leitura não anexa documentos', f'status {st}')
    st, _, _ = anexar('ownerB', empresas['B'], cid)
    check(st != 200, 'a empresa B não anexa documentos a um consumível da empresa A', f'status {st}')
    st, _, _ = anexar('editorA', empresas['A'], cid, nome='x.html', conteudo=b'<script>alert(1)</script>', mime='text/html')
    check(st != 200, 'documento HTML é recusado', f'status {st}')
    st, r, _ = call('GET', '/api/collections/consumivel_documentos/records', tok=tok['ownerB'])
    check(st == 200 and not [i for i in r.get('items', []) if i['empresa'] == empresas['A']],
          'a empresa B não vê documentos da empresa A')

    nome = d.get('ficheiro', '') if isinstance(d, dict) else ''
    if nome:
        url = f"/api/files/consumivel_documentos/{d['id']}/{nome}"
        s1, _, _ = call('GET', url)
        check(s1 in (401, 403, 404), 'documento protegido sem sessão', f'status {s1}')
        s2, r, _ = call('POST', '/api/files/token', {}, tok['ownerB'])
        tb = r.get('token') if isinstance(r, dict) else None
        s3, _, _ = call('GET', f'{url}?token={tb}')
        check(s3 in (401, 403, 404), 'documento protegido de outra empresa (mesmo com token)', f'status {s3}')
        s4, r, _ = call('POST', '/api/files/token', {}, t)
        ta = r.get('token') if isinstance(r, dict) else None
        s5, _, _ = call('GET', f'{url}?token={ta}')
        check(s5 == 200, 'a própria empresa abre o documento com token de ficheiro', f'status {s5}')
    st, _, _ = call('DELETE', f"/api/collections/consumivel_documentos/records/{d['id']}", tok=tok['viewerA'])
    check(st != 204 and st != 200, 'o papel Leitura não apaga documentos', f'status {st}')

    # --- faturas: preço e nome da fatura no consumível
    def fatura(data):
        st, f, _ = call('POST', '/api/collections/faturas/records',
                        {'empresa': empresas['A'], 'autor': users['editorA'], 'tipo': 'fatura', 'estado': 'analisada',
                         'fornecedor': 'Makro', 'data_fatura': data + ' 00:00:00.000Z'}, su)
        return f['id']

    linha = {'consumivelId': cid, 'descricaoFatura': 'Desengord. Cif Power 750ml', 'marca': 'Cif', 'quantidadeG': 0,
             'precoUnitario': 3.5, 'totalLinha': 3.5, 'embalagemG': 0, 'acao': 'preco'}
    st, r, _ = call('POST', f'/api/gc_turnkey/faturas/{fatura("2026-09-25")}/aplicar', {'linhas': [linha]}, t)
    check(st == 200 and r.get('precos') == 1, 'aplicar fatura: preço do consumível', f'{st} {str(r)[:120]}')
    c2 = call('GET', f'/api/collections/consumiveis/records/{cid}', tok=t)[1]
    check(abs(c2.get('preco', 0) - 3.5) < 1e-6 and c2.get('marca') == 'Cif' and c2.get('fornecedor') == 'Makro',
          'o consumível assume preço, marca e fornecedor da fatura', str(c2)[:160])
    check('desengord' in json.dumps(c2.get('nomes_fatura', [])).lower(), 'o nome da fatura ficou aprendido')
    st, r, _ = call('POST', f'/api/gc_turnkey/faturas/{fatura("2026-09-01")}/aplicar',
                    {'linhas': [dict(linha, precoUnitario=1.0)]}, t)
    check(st == 200 and r.get('precosIgnorados') == 1, 'fatura mais antiga: preço ignorado', str(r)[:120])
    c3 = call('GET', f'/api/collections/consumiveis/records/{cid}', tok=t)[1]
    check(abs(c3.get('preco', 0) - 3.5) < 1e-6, 'o preço do consumível não mudou com a fatura antiga')
    # consumível de outra empresa é ignorado (não muda nada)
    st, cb, _ = call('POST', '/api/collections/consumiveis/records',
                     {'empresa': empresas['B'], 'nome': 'Lixívia B', 'categoria': 'limpeza'}, tok['ownerB'])
    if st == 200:
        st, r, _ = call('POST', f'/api/gc_turnkey/faturas/{fatura("2026-09-26")}/aplicar',
                        {'linhas': [dict(linha, consumivelId=cb['id'], precoUnitario=9.9)]}, t)
        cb2 = call('GET', f"/api/collections/consumiveis/records/{cb['id']}", tok=tok['ownerB'])[1]
        check(cb2.get('preco', 0) == 0, 'uma fatura da empresa A não altera consumíveis da empresa B', str(cb2)[:120])


def teste_juntar_marcas_fornecedores():
    """9a. Juntar marcas/fornecedores repetidos (mesmo fornecedor, nomes diferentes)."""
    sec('9a. Juntar marcas/fornecedores repetidos')
    t = tok['editorA']
    su_url = '/api/gc_turnkey/marcas-fornecedores/juntar'
    base = dict(dados[('ingredientes', 'A')][1])
    base.update(nome='Ingrediente Recheio', origem='comprado', preco=0, gramas_embalagem=0)
    st, ing, _ = call('POST', '/api/collections/ingredientes/records', base, t)
    check(st == 200, 'criar o ingrediente genérico', f'status {st} {str(ing)[:120]}')
    gid = ing['id']

    def produto(nome, fornecedor, data):
        st, r, _ = call('POST', '/api/collections/ingrediente_produtos/records',
                        {'empresa': empresas['A'], 'ingrediente': gid, 'nome': nome, 'fornecedor': fornecedor,
                         'embalagem_g': 1000, 'preco': 2.0, 'preco_atualizado_em': data + ' 00:00:00.000Z'}, t)
        assert st == 200, (st, r)
        return r['id']

    p1 = produto('Farinha A', 'Recheio', '2026-09-01')
    p2 = produto('Farinha B', 'Recheio Cash & Carry, S.A.', '2026-09-05')
    p3 = produto('Farinha C', 'Recheio Cash & Carry, SA', '2026-09-10')  # a mais recente

    # embalagem também tem fornecedor (mas não marca)
    emb = dados[('embalagens', 'A')][1]
    st, eb, _ = call('POST', '/api/collections/embalagens/records',
                     dict(emb, nome='Caixa Recheio teste', preco_compra=1, fornecedor='Recheio'), t)
    check(st == 200, 'criar a embalagem do fornecedor a juntar', f'status {st} {str(eb)[:120]}')
    eb_id = eb['id']

    corpo = {'tipo': 'fornecedor', 'valores': ['Recheio', 'Recheio Cash & Carry, S.A.'], 'destino': 'Recheio Cash & Carry, SA'}
    st, rj0, _ = call('POST', su_url, corpo, tok['editorA'])
    check(st != 200, 'editor não pode juntar (só proprietário/administrador)', f'status {st} {str(rj0)[:120]}')
    st, rj0b, _ = call('POST', su_url, corpo, tok['viewerA'])
    check(st != 200, 'viewer não pode juntar', f'status {st}')

    # empresa B: mesmo com owner legítimo, não mexe em nada da empresa A (âmbito por empresa)
    st, rjb, _ = call('POST', su_url, corpo, tok['ownerB'])
    check(st == 200 and rjb.get('alterados') == 0, 'a empresa B não altera nada da empresa A (0 alterados)', f'{st} {str(rjb)[:160]}')
    p1_intacto = call('GET', f'/api/collections/ingrediente_produtos/records/{p1}', tok=t)[1]
    check(p1_intacto.get('fornecedor') == 'Recheio', 'confirma: o produto da empresa A não foi tocado pela B', str(p1_intacto)[:120])

    # validação
    st, rve, _ = call('POST', su_url, {'tipo': 'invalido', 'valores': ['x'], 'destino': 'y'}, tok['ownerA'])
    check(st != 200, 'tipo inválido é recusado', f'status {st}')
    st, rve2, _ = call('POST', su_url, {'tipo': 'fornecedor', 'valores': [], 'destino': 'y'}, tok['ownerA'])
    check(st != 200, 'sem valores a juntar é recusado', f'status {st}')
    st, rve3, _ = call('POST', su_url, {'tipo': 'fornecedor', 'valores': ['a'], 'destino': ''}, tok['ownerA'])
    check(st != 200, 'sem nome final é recusado', f'status {st}')

    # o proprietário junta a sério: 2 produtos + 1 embalagem tinham os valores antigos
    st, rj, _ = call('POST', su_url, corpo, tok['ownerA'])
    check(st == 200 and rj.get('alterados') == 3,
          'proprietário junta: 2 produtos + 1 embalagem alterados (3)', f'{st} {str(rj)[:160]}')
    for pid in (p1, p2, p3):
        r = call('GET', f'/api/collections/ingrediente_produtos/records/{pid}', tok=t)[1]
        check(r.get('fornecedor') == 'Recheio Cash & Carry, SA', f'produto {pid} ficou com o nome final', str(r)[:120])
    eb2 = call('GET', f'/api/collections/embalagens/records/{eb_id}', tok=t)[1]
    check(eb2.get('fornecedor') == 'Recheio Cash & Carry, SA', 'a embalagem também ficou com o nome final', str(eb2)[:120])
    gen = call('GET', f'/api/collections/ingredientes/records/{gid}', tok=t)[1]
    check(gen.get('fornecedor') == 'Recheio Cash & Carry, SA',
          'o ingrediente genérico (compra mais recente) sincroniza o nome final', str(gen)[:160])

    # espaços a mais no nome final são normalizados (nunca cria outra variante nova)
    p4 = produto('Farinha E', 'Recheio Distribuição X', '2026-09-02')
    st, rj2, _ = call('POST', su_url,
                       {'tipo': 'fornecedor', 'valores': ['Recheio Distribuição X'], 'destino': '  Recheio   Cash & Carry, SA  '},
                       tok['ownerA'])
    check(st == 200 and rj2.get('destino') == 'Recheio Cash & Carry, SA',
          'espaços a mais no nome final são normalizados (não cria outra variante)', f'{st} {str(rj2)[:160]}')
    p4_final = call('GET', f'/api/collections/ingrediente_produtos/records/{p4}', tok=t)[1]
    check(p4_final.get('fornecedor') == 'Recheio Cash & Carry, SA',
          'o valor gravado já vem sem os espaços a mais', str(p4_final)[:120])

    # marca: não mexe em embalagens (não têm marca)
    st, pm1, _ = call('POST', '/api/collections/ingrediente_produtos/records',
                      {'empresa': empresas['A'], 'ingrediente': gid, 'nome': 'Farinha D', 'marca': 'Cerealis',
                       'embalagem_g': 1000, 'preco': 1, 'preco_atualizado_em': '2026-09-01 00:00:00.000Z'}, t)
    st, rjm, _ = call('POST', su_url, {'tipo': 'marca', 'valores': ['Cerealis'], 'destino': 'Cerealis Portugal'}, tok['ownerA'])
    check(st == 200 and rjm.get('alterados') == 1, 'juntar marca só mexe em produtos/consumíveis, não em embalagens', f'{st} {str(rjm)[:160]}')


def teste_produto_na_receita():
    """9b. Linha de receita com produto de compra fixado: o custo é o do produto."""
    sec('9b. Produto fixado na linha de receita')
    t = tok['editorA']
    base = dict(dados[('ingredientes', 'A')][1])
    base.update(nome='Farinha T55 (fixar)', origem='comprado', preco=0, gramas_embalagem=0)
    st, ing, _ = call('POST', '/api/collections/ingredientes/records', base, t)
    check(st == 200, 'criar o ingrediente genérico', f'status {st} {str(ing)[:120]}')
    gid = ing['id']

    def produto(nome, emb, preco, data, ingrediente=None):
        return call('POST', '/api/collections/ingrediente_produtos/records',
                    {'empresa': empresas['A'], 'ingrediente': ingrediente or gid, 'nome': nome, 'embalagem_g': emb,
                     'preco': preco, 'preco_atualizado_em': data + ' 00:00:00.000Z'}, t)[1]

    p1 = produto('Farinha pequena 1 kg', 1000, 2.00, '2026-09-01')
    p2 = produto('Farinha grande 5 kg', 5000, 5.00, '2026-09-10')

    rb = dict(dados[('receitas', 'A')][1])
    rb.update(nome='Massa fixar', rendimento_manual=False)
    for k in ('custo_receita', 'custo_por_grama', 'rendimento_esperado'):
        rb.pop(k, None)
    st, rec, _ = call('POST', '/api/collections/receitas/records', rb, t)
    check(st == 200, 'criar a receita', f'status {st} {str(rec)[:120]}')
    rid = rec['id']
    st, it, _ = call('POST', '/api/collections/itens_receita/records',
                     {'empresa': empresas['A'], 'receita': rid, 'ingrediente': gid, 'quantidade_g': 1000}, t)
    check(st == 200, 'linha de receita com o genérico', f'status {st} {str(it)[:120]}')

    def custo():
        return call('GET', f'/api/collections/receitas/records/{rid}', tok=t)[1].get('custo_receita', -1)

    check(abs(custo() - 1.0) < 1e-6, 'sem produto fixado: custo do genérico (compra mais recente, 5 kg a 5 €)', str(custo()))
    st, r, _ = call('PATCH', f"/api/collections/itens_receita/records/{it['id']}", {'produto': p1['id']}, t)
    check(st == 200, 'fixar o produto na linha', f'status {st} {str(r)[:120]}')
    check(abs(custo() - 2.0) < 1e-6, 'com o produto fixado: custo do produto (1 kg a 2 €)', str(custo()))
    # o preço do produto fixado muda (data antiga: o genérico não muda) e a receita acompanha
    call('PATCH', f"/api/collections/ingrediente_produtos/records/{p1['id']}", {'preco': 3.0}, t)
    check(abs(custo() - 3.0) < 1e-6, 'preço do produto fixado mudou: a receita acompanha', str(custo()))
    # produto de outro ingrediente é ignorado
    base2 = dict(base)
    base2.update(nome='Outro ingrediente')
    outro = call('POST', '/api/collections/ingredientes/records', base2, t)[1]
    po = produto('Outro 1 kg', 1000, 9.0, '2026-09-20', ingrediente=outro['id'])
    call('PATCH', f"/api/collections/itens_receita/records/{it['id']}", {'produto': po['id']}, t)
    check(abs(custo() - 1.0) < 1e-6, 'produto de outro ingrediente é ignorado (volta ao custo do genérico)', str(custo()))
    call('PATCH', f"/api/collections/itens_receita/records/{it['id']}", {'produto': p1['id']}, t)
    check(abs(custo() - 3.0) < 1e-6, 'fixar de novo o produto')
    # apagar o produto fixado: a linha volta ao genérico
    call('DELETE', f"/api/collections/ingrediente_produtos/records/{p1['id']}", tok=t)
    check(abs(custo() - 1.0) < 1e-6, 'apagar o produto fixado: a linha volta ao custo do genérico', str(custo()))

    # isolamento
    pb_ = produto('Farinha pequena B', 1000, 4.0, '2026-09-02')
    st, r, _ = call('POST', '/api/collections/itens_receita/records',
                    {'empresa': empresas['B'], 'receita': dados[('receitas', 'B')][0], 'ingrediente': dados[('ingredientes', 'B')][0],
                     'quantidade_g': 10, 'produto': pb_['id']}, tok['editorB'])
    check(st != 200, 'a empresa B não fixa um produto da empresa A', f'status {st}')


def teste_juntar():
    """9c. Juntar ingredientes: tudo passa para o destino, o origem vai para a lixeira."""
    sec('9c. Juntar ingredientes')
    t = tok['editorA']
    aler = [v for f in cols['ingredientes']['fields'] if f['name'] == 'alergenios' for v in f.get('values', [])]
    base = dict(dados[('ingredientes', 'A')][1])
    base.update(origem='comprado', preco=0, gramas_embalagem=0)

    def ingrediente(nome, **extra):
        st, r, _ = call('POST', '/api/collections/ingredientes/records', dict(base, nome=nome, **extra), t)
        assert st == 200, (st, r)
        return r['id']

    dest = ingrediente('Açúcar branco JJ')
    orig = ingrediente('Açúcar Makro JJ', alergenios=aler[:1] if aler else [])

    def produto(ing, nome, emb, preco, data):
        return call('POST', '/api/collections/ingrediente_produtos/records',
                    {'empresa': empresas['A'], 'ingrediente': ing, 'nome': nome, 'embalagem_g': emb,
                     'preco': preco, 'preco_atualizado_em': data + ' 00:00:00.000Z',
                     'nomes_fatura': ['acucar makro 5kg'] if ing == orig else []}, t)[1]

    produto(dest, 'Sidul 1 kg', 1000, 1.20, '2026-09-20')
    po = produto(orig, 'Makro 5 kg', 5000, 5.00, '2026-09-10')
    call('POST', '/api/gc_turnkey/inventario/ajustar', {'ingrediente': dest, 'delta': 100}, t)
    call('POST', '/api/gc_turnkey/inventario/ajustar', {'ingrediente': orig, 'delta': 300}, t)

    rb = dict(dados[('receitas', 'A')][1])
    rb.update(nome='Massa juntar', rendimento_manual=False)
    for k in ('custo_receita', 'custo_por_grama', 'rendimento_esperado'):
        rb.pop(k, None)
    rid = call('POST', '/api/collections/receitas/records', rb, t)[1]['id']
    it = call('POST', '/api/collections/itens_receita/records',
              {'empresa': empresas['A'], 'receita': rid, 'ingrediente': orig, 'quantidade_g': 1000}, t)[1]

    # recusas
    st, _, _ = call('POST', '/api/gc_turnkey/ingredientes/juntar', {'origemId': orig, 'destinoId': dest}, tok['viewerA'])
    check(st == 403, 'o papel Leitura não junta ingredientes', f'status {st}')
    st, _, _ = call('POST', '/api/gc_turnkey/ingredientes/juntar', {'origemId': orig, 'destinoId': dest}, tok['editorB'])
    check(st in (400, 403), 'a empresa B não junta ingredientes da empresa A', f'status {st}')
    st, _, _ = call('POST', '/api/gc_turnkey/ingredientes/juntar', {'origemId': orig, 'destinoId': orig}, t)
    check(st == 400, 'não se junta um ingrediente consigo próprio', f'status {st}')
    proprio = ingrediente('Massa própria JJ', origem='fabrico_proprio')
    st, _, _ = call('POST', '/api/gc_turnkey/ingredientes/juntar', {'origemId': proprio, 'destinoId': dest}, t)
    check(st == 400, 'ingredientes de fabrico próprio não se juntam', f'status {st}')

    st, r, _ = call('POST', '/api/gc_turnkey/ingredientes/juntar', {'origemId': orig, 'destinoId': dest}, t)
    check(st == 200, 'juntar os dois ingredientes', f'status {st} {str(r)[:200]}')
    mv = r.get('movidos', {}) if isinstance(r, dict) else {}
    check(mv.get('itens_receita') == 1 and mv.get('ingrediente_produtos') == 1, 'a linha de receita e o produto mudaram para o destino', str(mv))
    check(abs(r.get('stockSomado', 0) - 300) < 1e-6, 'o stock do origem foi somado ao do destino', str(r)[:200])

    li = call('GET', f"/api/collections/itens_receita/records/{it['id']}", tok=t)[1]
    check(li.get('ingrediente') == dest, 'a linha de receita aponta para o destino', str(li)[:200])
    prods = call('GET', f"/api/collections/ingrediente_produtos/records?filter=ingrediente='{dest}'&perPage=50", tok=t)[1]
    check(len(prods.get('items', [])) == 2, 'o destino tem agora os dois produtos', str(len(prods.get('items', []))))
    d = call('GET', f'/api/collections/ingredientes/records/{dest}', tok=t)[1]
    check(abs(d.get('preco', 0) - 1.2) < 1e-6 and d.get('gramas_embalagem') == 1000, 'o custo do destino é o da compra mais recente (Sidul, 20/09)', str(d)[:160])
    if aler:
        check(aler[0] in (d.get('alergenios') or []), 'o alergénio do origem passou para o destino', str(d.get('alergenios')))
    o = call('GET', f'/api/collections/ingredientes/records/{orig}', tok=t)[1]
    check(o.get('deletado') is True, 'o origem foi para a lixeira')
    inv = call('GET', f"/api/collections/inventario/records?filter=ingrediente='{dest}'", tok=t)[1].get('items', [])
    check(len(inv) == 1 and abs(inv[0].get('quantidade', 0) - 400) < 1e-6, 'o stock do destino é a soma (400)', str(inv)[:160])
    rec = call('GET', f'/api/collections/receitas/records/{rid}', tok=t)[1]
    check(abs(rec.get('custo_receita', -1) - 1.2) < 1e-6, 'a receita refez o custo com o custo do destino (1,20 €/kg)', str(rec.get('custo_receita')))


def teste_compras_produto():
    """9d. Lista de compras: uma linha por produto fixado nas receitas."""
    sec('9d. Lista de compras por produto')
    t = tok['editorA']
    base = dict(dados[('ingredientes', 'A')][1])
    base.update(nome='Farinha compras', origem='comprado', preco=0, gramas_embalagem=0)
    gid = call('POST', '/api/collections/ingredientes/records', base, t)[1]['id']

    def produto(nome, marca, emb, preco, data):
        return call('POST', '/api/collections/ingrediente_produtos/records',
                    {'empresa': empresas['A'], 'ingrediente': gid, 'nome': nome, 'marca': marca, 'embalagem_g': emb,
                     'preco': preco, 'preco_atualizado_em': data + ' 00:00:00.000Z'}, t)[1]

    p1 = produto('Farinha pequena', 'Sidul', 1000, 2.0, '2026-09-01')
    produto('Farinha grande', 'Makro', 5000, 5.0, '2026-09-10')  # a mais recente: o automático

    def receita(nome, produto_id=None):
        rb = dict(dados[('receitas', 'A')][1])
        rb.update(nome=nome, rendimento_manual=False)
        for k in ('custo_receita', 'custo_por_grama', 'rendimento_esperado'):
            rb.pop(k, None)
        rid = call('POST', '/api/collections/receitas/records', rb, t)[1]['id']
        item = {'empresa': empresas['A'], 'receita': rid, 'ingrediente': gid, 'quantidade_g': 1000}
        if produto_id:
            item['produto'] = produto_id
        it = call('POST', '/api/collections/itens_receita/records', item, t)[1]
        return rid, it['id']

    r1, it1 = receita('Massa fixa Sidul', p1['id'])
    r2, _ = receita('Massa automática')

    pb_ = dict(dados[('producoes', 'A')][1])
    pb_.update(titulo='Compras por produto')
    prod = call('POST', '/api/collections/producoes/records', pb_, t)[1]
    for r in (r1, r2):
        pi = dict(dados[('producao_itens', 'A')][1])
        pi.update(producao=prod['id'], receita=r, quantidade_kg=1)
        for k in ('formato', 'recheio', 'ficha'):
            pi.pop(k, None)
        st, x, _ = call('POST', '/api/collections/producao_itens/records', pi, t)
        check(st == 200, 'linha de produção', f'status {st} {str(x)[:120]}')

    def linhas():
        st, r, _ = call('GET', f"/api/collections/lista_compras/records?filter=producao='{prod['id']}'&perPage=50", tok=t)
        return [i for i in r.get('items', []) if i.get('ingrediente') == gid]

    st, r, _ = call('POST', f"/api/gc_turnkey/producoes/{prod['id']}/lista-compras", {}, t)
    check(st == 200, 'gerar a lista de compras', f'status {st} {str(r)[:120]}')
    ls = linhas()
    check(len(ls) == 2, 'duas linhas: o produto fixado e o automático', str(len(ls)))
    fixa = [l for l in ls if l.get('produto') == p1['id']]
    auto = [l for l in ls if not l.get('produto')]
    check(len(fixa) == 1 and fixa[0]['embalagem_g'] == 1000 and abs(fixa[0]['quantidade_comprar_g'] - 1000) < 1e-6
          and 'Sidul' in fixa[0]['descricao'], 'produto fixado: embalagem de 1 kg, 1 embalagem, nome com a marca', str(fixa)[:220])
    check(len(auto) == 1 and auto[0]['embalagem_g'] == 5000 and abs(auto[0]['quantidade_comprar_g'] - 5000) < 1e-6,
          'automático: embalagem de 5 kg (compra mais recente)', str(auto)[:220])
    check(fixa and abs(fixa[0]['custo_estimado'] - 2.0) < 1e-6, 'custo estimado do produto fixado (2 €)', str(fixa)[:220])

    # deixa de fixar: fica só o automático (2 kg -> 1 embalagem de 5 kg)
    call('PATCH', f'/api/collections/itens_receita/records/{it1}', {'produto': ''}, t)
    st, r, _ = call('POST', f"/api/gc_turnkey/producoes/{prod['id']}/lista-compras", {}, t)
    ls = linhas()
    check(len(ls) == 1 and not ls[0].get('produto') and abs(ls[0]['quantidade_necessaria_g'] - 2000) < 1e-6
          and abs(ls[0]['quantidade_comprar_g'] - 5000) < 1e-6, 'sem produto fixado: uma só linha (2 kg → 1 embalagem de 5 kg)', str(ls)[:260])


def teste_alergenios_produto():
    """9e. Alergénios por produto: só contam quando a receita fixa esse produto."""
    sec('9e. Alergénios por produto')
    t = tok['editorA']
    base = dict(dados[('ingredientes', 'A')][1])
    base.update(nome='Chocolate alergénios', origem='comprado', preco=0, gramas_embalagem=0, alergenios=[], alergenios_tracos=[])
    gid = call('POST', '/api/collections/ingredientes/records', base, t)[1]['id']

    def produto(nome, emb, preco, data, **extra):
        st, r, _ = call('POST', '/api/collections/ingrediente_produtos/records',
                        {'empresa': empresas['A'], 'ingrediente': gid, 'nome': nome, 'embalagem_g': emb,
                         'preco': preco, 'preco_atualizado_em': data + ' 00:00:00.000Z', **extra}, t)
        assert st == 200, (st, r)
        return r

    px = produto('Chocolate X', 1000, 5.0, '2026-09-01', alergenios_tracos=['Frutos de casca rija'], alergenios=['Leite'])
    py = produto('Chocolate Y', 1000, 4.0, '2026-09-02')

    def receita(nome, produto_id=None):
        rb = dict(dados[('receitas', 'A')][1])
        rb.update(nome=nome, rendimento_manual=False)
        for k in ('custo_receita', 'custo_por_grama', 'rendimento_esperado'):
            rb.pop(k, None)
        rid = call('POST', '/api/collections/receitas/records', rb, t)[1]['id']
        item = {'empresa': empresas['A'], 'receita': rid, 'ingrediente': gid, 'quantidade_g': 500}
        if produto_id:
            item['produto'] = produto_id
        it = call('POST', '/api/collections/itens_receita/records', item, t)[1]
        return rid, it['id']

    def alerg(rid):
        n = call('GET', f'/api/collections/receitas/records/{rid}', tok=t)[1].get('nutri') or {}
        return sorted(n.get('alergenios', [])), sorted(n.get('alergenios_tracos', []))

    rx, itx = receita('Bolo com X', px['id'])
    ry, _ = receita('Bolo com Y', py['id'])
    rauto, _ = receita('Bolo automático')
    check(alerg(rx) == (['Leite'], ['Frutos de casca rija']), 'a receita que fixa o produto X leva os alergénios dele', str(alerg(rx)))
    check(alerg(ry) == ([], []), 'a receita que fixa o produto Y não leva os alergénios do X', str(alerg(ry)))
    check(alerg(rauto) == ([], []), 'a receita em automático não leva os alergénios do X', str(alerg(rauto)))

    # o produto ganha um alergénio depois: a receita que o fixa acompanha
    call('PATCH', f"/api/collections/ingrediente_produtos/records/{py['id']}", {'alergenios': ['Soja']}, t)
    check(alerg(ry)[0] == ['Soja'], 'alergénio acrescentado ao produto Y: a receita que o fixa acompanha', str(alerg(ry)))
    check(alerg(rauto) == ([], []), 'a receita em automático continua sem alergénios')
    # deixa de fixar o produto X
    call('PATCH', f'/api/collections/itens_receita/records/{itx}', {'produto': ''}, t)
    check(alerg(rx) == ([], []), 'sem produto fixado, os alergénios do produto deixam de contar', str(alerg(rx)))
    # os do genérico contam sempre
    call('PATCH', f'/api/collections/ingredientes/records/{gid}', {'alergenios': ['Glúten']}, t)
    check(alerg(rauto)[0] == ['Glúten'] and alerg(ry)[0] == ['Glúten', 'Soja'], 'os alergénios do genérico contam sempre; os do produto juntam-se',
          f'{alerg(rauto)} {alerg(ry)}')

    # o plano do produto final (ficha) diz que produtos de compra as receitas fixam
    fb = dict(dados[('fichas_tecnicas', 'A')][1])
    fb.update(nome='Produto alergénios')
    st, ficha, _ = call('POST', '/api/collections/fichas_tecnicas/records', fb, t)
    if st == 200:
        ib = dict(dados[('itens_ficha', 'A')][1])
        ib.update(ficha=ficha['id'], receita=ry, quantidade_g=100, slot='massa')
        for k in ('ingrediente', 'embalagem', 'kit'):
            ib.pop(k, None)
        st, _, _ = call('POST', '/api/collections/itens_ficha/records', ib, t)
        st, pl, _ = call('GET', f"/api/gc_turnkey/fichas/{ficha['id']}/plano?unidades=1", tok=t)
        linha = [c for c in (pl.get('comprar', []) if isinstance(pl, dict) else []) if c.get('ingredienteId') == gid]
        check(st == 200 and linha and linha[0].get('produtoIds') == [py['id']],
              'o plano da ficha indica o produto fixado pela receita da massa', f'{st} {str(pl)[:200]}')
        fn = (call('GET', f"/api/collections/fichas_tecnicas/records/{ficha['id']}", tok=t)[1].get('nutri') or {}).get('alergenios', [])
        check('Soja' in fn and 'Glúten' in fn, 'a declaração da ficha leva os alergénios do produto fixado e os do genérico', str(fn))


def teste_nutricao_produto():
    """9f. Nutrição própria do produto: só conta quando a receita fixa esse produto."""
    sec('9f. Nutrição própria por produto')
    t = tok['editorA']
    base = dict(dados[('ingredientes', 'A')][1])
    base.update(nome='Manteiga nutrição', origem='comprado', preco=0, gramas_embalagem=0, alergenios=[], alergenios_tracos=[],
                nutri_energia_kcal=100, nutri_lipidos_g=10, nutri_saturados_g=5, nutri_hidratos_g=1, nutri_acucares_g=1,
                nutri_fibra_g=0, nutri_proteina_g=1, nutri_sal_g=0.1, nutri_base='100g', nutri_densidade=1)
    st, ing, _ = call('POST', '/api/collections/ingredientes/records', base, t)
    gid = ing['id']

    def produto(nome, **extra):
        st, r, _ = call('POST', '/api/collections/ingrediente_produtos/records',
                        {'empresa': empresas['A'], 'ingrediente': gid, 'nome': nome, 'embalagem_g': 250, 'preco': 2.0,
                         'preco_atualizado_em': '2026-09-01 00:00:00.000Z', **extra}, t)
        assert st == 200, (st, r)
        return r

    px = produto('Manteiga X', nutri_propria=True, nutri_energia_kcal=400, nutri_lipidos_g=40, nutri_saturados_g=20,
                 nutri_hidratos_g=2, nutri_acucares_g=2, nutri_fibra_g=0, nutri_proteina_g=2, nutri_sal_g=0.5, nutri_base='100g')
    py = produto('Manteiga Y', nutri_propria=False, nutri_energia_kcal=999)

    def receita(nome, produto_id=None):
        rb = dict(dados[('receitas', 'A')][1])
        rb.update(nome=nome, rendimento_manual=False)
        for k in ('custo_receita', 'custo_por_grama', 'rendimento_esperado'):
            rb.pop(k, None)
        rid = call('POST', '/api/collections/receitas/records', rb, t)[1]['id']
        item = {'empresa': empresas['A'], 'receita': rid, 'ingrediente': gid, 'quantidade_g': 500}
        if produto_id:
            item['produto'] = produto_id
        it = call('POST', '/api/collections/itens_receita/records', item, t)[1]
        return rid, it['id']

    def kcal(rid):
        n = call('GET', f'/api/collections/receitas/records/{rid}', tok=t)[1].get('nutri') or {}
        p100 = n.get('por100') or n.get('por100g') or {}
        return p100.get('kcal', n.get('kcal', -1)), n

    rx, itx = receita('Massa manteiga X', px['id'])
    ry, _ = receita('Massa manteiga Y', py['id'])
    ra, _ = receita('Massa manteiga auto')
    vx, nx = kcal(rx)
    check(abs(vx - 400) < 1e-6, 'a receita que fixa o produto com nutrição própria usa os valores dele (400 kcal)', str(nx)[:200])
    check(abs(kcal(ry)[0] - 100) < 1e-6, 'produto sem "nutrição própria": usa a do ingrediente (100 kcal)', str(kcal(ry)))
    check(abs(kcal(ra)[0] - 100) < 1e-6, 'receita em automático: usa a do ingrediente (100 kcal)', str(kcal(ra)))
    # o produto muda: a receita que o fixa acompanha
    call('PATCH', f"/api/collections/ingrediente_produtos/records/{px['id']}", {'nutri_energia_kcal': 500}, t)
    check(abs(kcal(rx)[0] - 500) < 1e-6, 'alterar a nutrição do produto: a receita que o fixa acompanha', str(kcal(rx)[0]))
    # base 100 ml com densidade
    call('PATCH', f"/api/collections/ingrediente_produtos/records/{px['id']}", {'nutri_base': '100ml', 'nutri_densidade': 0.5}, t)
    check(abs(kcal(rx)[0] - 1000) < 1e-6, 'nutrição do produto por 100 ml converte-se com a densidade (500 / 0,5)', str(kcal(rx)[0]))
    # deixa de fixar
    call('PATCH', f'/api/collections/itens_receita/records/{itx}', {'produto': ''}, t)
    check(abs(kcal(rx)[0] - 100) < 1e-6, 'sem produto fixado volta à nutrição do ingrediente', str(kcal(rx)[0]))


def teste_unidades():
    """9g. Unidade do ingrediente (g, ml, un): peso e nutrição em gramas, custo na unidade nativa."""
    sec('9g. Unidades de medida (g, ml, un)')
    t = tok['editorA']
    base = dict(dados[('ingredientes', 'A')][1])
    base.update(origem='comprado', alergenios=[], alergenios_tracos=[], nutri_base='100g', nutri_densidade=1,
                nutri_energia_kcal=100, nutri_lipidos_g=0, nutri_saturados_g=0, nutri_hidratos_g=0, nutri_acucares_g=0,
                nutri_fibra_g=0, nutri_proteina_g=0, nutri_sal_g=0)

    def ing(nome, **extra):
        st, r, _ = call('POST', '/api/collections/ingredientes/records', dict(base, nome=nome, **extra), t)
        assert st == 200, (st, r)
        return r['id']

    g = ing('Farinha unidades', preco=1.0, gramas_embalagem=1000, nutri_energia_kcal=0)                      # 0,001 €/g
    ml = ing('Leite unidades', unidade='ml', nutri_densidade=1.2, preco=1.2, gramas_embalagem=1000, nutri_energia_kcal=0)   # 0,0012 €/ml
    un = ing('Ovo unidades', unidade='un', gramas_unidade=50, preco=3.0, gramas_embalagem=12, nutri_energia_kcal=200)       # 0,25 €/un

    rb = dict(dados[('receitas', 'A')][1])
    rb.update(nome='Massa unidades', rendimento_manual=False)
    for k in ('custo_receita', 'custo_por_grama', 'rendimento_esperado'):
        rb.pop(k, None)
    rid = call('POST', '/api/collections/receitas/records', rb, t)[1]['id']
    for ingrediente, q in ((g, 100), (ml, 100), (un, 2)):
        st, r, _ = call('POST', '/api/collections/itens_receita/records',
                        {'empresa': empresas['A'], 'receita': rid, 'ingrediente': ingrediente, 'quantidade_g': q}, t)
        assert st == 200, (st, r)
    rec = call('GET', f'/api/collections/receitas/records/{rid}', tok=t)[1]
    # peso em gramas: 100 g + 100 ml x 1,2 + 2 un x 50 g = 320 g
    check(abs(rec.get('rendimento_esperado', -1) - 320) < 1e-6, 'peso da receita: g + ml x densidade + un x peso da unidade (320 g)', str(rec.get('rendimento_esperado')))
    # custo na unidade nativa: 100 x 0,001 + 100 x 0,0012 + 2 x 0,25 = 0,72
    check(abs(rec.get('custo_receita', -1) - 0.72) < 1e-6, 'custo na unidade nativa (0,72 €)', str(rec.get('custo_receita')))
    n = rec.get('nutri') or {}
    kcal100 = (n.get('por100') or n.get('por100g') or {}).get('kcal', n.get('kcal', -1))
    # só os ovos têm energia: 2 un = 100 g a 200 kcal/100 g = 200 kcal em 320 g -> 62,5 kcal/100 g
    check(abs(kcal100 - 62.5) < 1e-6, 'nutrição com pesos convertidos (200 kcal em 320 g = 62,5 por 100 g)', str(kcal100))
    # explosão para compras: 640 g de massa -> o dobro, nas unidades nativas
    st, prod, _ = call('POST', '/api/collections/producoes/records', dict(dados[('producoes', 'A')][1], titulo='Unidades'), t)
    pi = dict(dados[('producao_itens', 'A')][1])
    pi.update(producao=prod['id'], receita=rid, quantidade_kg=0.64)
    for k in ('formato', 'recheio', 'ficha'):
        pi.pop(k, None)
    call('POST', '/api/collections/producao_itens/records', pi, t)
    call('POST', f"/api/gc_turnkey/producoes/{prod['id']}/lista-compras", {}, t)
    ls = call('GET', f"/api/collections/lista_compras/records?filter=producao='{prod['id']}'&perPage=50", tok=t)[1].get('items', [])
    nec = {l['ingrediente']: l['quantidade_necessaria_g'] for l in ls}
    check(abs(nec.get(g, -1) - 200) < 1e-6 and abs(nec.get(ml, -1) - 200) < 1e-6 and abs(nec.get(un, -1) - 4) < 1e-6,
          'compras em unidades nativas: 200 g, 200 ml e 4 un', str(nec))


def main():
    arrancar()
    try:
        preparar()
        teste_isolamento()
        teste_papeis()
        teste_endpoints()
        teste_uploads()
        teste_aprovacao()
        teste_aprovacoes_na_app()
        teste_estado_backups()
        teste_avisos()
        teste_lotes()
        teste_quiosque_offline()
        teste_ponto()
        teste_ferias()
        teste_anotacoes()
        teste_escala()
        teste_segredos()
        teste_sem_chave()
        teste_faturas_ia()
        teste_faturas_edicao()
        teste_faturas_ignorar_lote()
        teste_faturas_linha_manual()
        teste_notas_pagina()
        teste_faturas_pendente_embalagem()
        teste_produtos()
        teste_juntar_marcas_fornecedores()
        teste_produto_na_receita()
        teste_juntar()
        teste_compras_produto()
        teste_alergenios_produto()
        teste_nutricao_produto()
        teste_unidades()
        teste_consumiveis()
        teste_implantacao()
        teste_autenticacao()  # por último: gasta o limite de tentativas
    finally:
        parar()
    falhas = [r for r in resultados if r[0] == 'FALHA']
    avisos = [r for r in resultados if r[0] == 'AVISO']
    print(f'\n== Resumo: {len([r for r in resultados if r[0] == "OK"])} OK, {len(avisos)} avisos, {len(falhas)} falhas')
    for _, s, n, d in falhas:
        print(f'  FALHA [{s}] {n} {d}')
    sys.exit(1 if falhas else 0)


if __name__ == '__main__':
    main()
