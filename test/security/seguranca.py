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
    permitidas = {'preferencias_utilizador', 'sugestoes'}
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
        s, r, _ = call('PATCH', f'/api/collections/faturas/records/{fat[0]}', raw=corpo, ctype=ct, tok=tok['editorA'])
        if s == 200:
            nome = r.get('ficheiro', '')
            check('/' not in nome and '..' not in nome, 'nome de ficheiro malicioso é normalizado', nome)
        grande = b'\x89PNG\r\n\x1a\n' + b'0' * (9 * 1024 * 1024)
        corpo, ct = multipart({}, {'ficheiro': ('grande.png', grande, 'image/png')})
        s, r, _ = call('PATCH', f'/api/collections/faturas/records/{fat[0]}', raw=corpo, ctype=ct, tok=tok['editorA'])
        check(s != 200, 'ficheiro acima do tamanho máximo é recusado', f'status {s}')
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
    for cab in ('Strict-Transport-Security', 'X-Content-Type-Options', 'X-Frame-Options', 'Content-Security-Policy'):
        if not h.get(cab):
            aviso(f'cabeçalho {cab} ausente', 'pôr no proxy/host (ver docs/SEGURANCA.md)')
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
ia_modo = {'modo': 'tres', 'chamadas': {}}


class _GeminiFalso(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def do_POST(self):
        modelo = self.path.split('/models/')[-1].split(':')[0]
        ia_modo['chamadas'][modelo] = ia_modo['chamadas'].get(modelo, 0) + 1
        self.rfile.read(int(self.headers.get('Content-Length', 0)))

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
    if os.name == 'nt':
        open(os.path.join(pasta, 'qpdf.cmd'), 'w').write('@"%s" "%%~dp0fake_qpdf.py" %%*\r\n' % sys.executable)
    else:
        f = os.path.join(pasta, 'qpdf')
        open(f, 'w').write('#!/bin/sh\nexec "%s" "$(dirname "$0")/fake_qpdf.py" "$@"\n' % sys.executable)
        os.chmod(f, 0o755)
    global _pasta_qpdf
    _pasta_qpdf = pasta
    return {
        'GEMINI_API_KEY': 'chave-falsa', 'GC_TURNKEY_AI_PROVIDER': 'gemini',
        'GC_TURNKEY_GEMINI_URL': f'http://127.0.0.1:{PORTA_IA}/v1beta/models/',
        'GC_TURNKEY_AI_MODEL': 'modelo-a', 'GC_TURNKEY_AI_MODEL_FALLBACK': 'modelo-b,modelo-c',
        'GC_TURNKEY_AI_ESPERAS': '0,0',
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
    finally:
        srv.shutdown()


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


def main():
    arrancar()
    try:
        preparar()
        teste_isolamento()
        teste_papeis()
        teste_endpoints()
        teste_uploads()
        teste_aprovacao()
        teste_segredos()
        teste_sem_chave()
        teste_faturas_ia()
        teste_produtos()
        teste_produto_na_receita()
        teste_juntar()
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
