#!/usr/bin/env python3
"""Testes de segurança do PocketBase do turnkey_app (repetíveis).

Arranca um PocketBase DESCARTÁVEL (dados temporários, porta 8197, sem
TURNKEY_DEV) com as migrations e hooks do projeto, cria duas empresas com
utilizadores de todos os papéis e tenta o que NÃO deve ser possível.

    python test/security/seguranca.py            # arranca o seu próprio servidor
    PB_URL=http://127.0.0.1:8197 PB_SUPER=email:pass python test/security/seguranca.py

Nunca apontar para a produção: cria e apaga dados de teste.
Saída: FALHA (tem de se corrigir), AVISO (risco de configuração/implantação),
OK. Código de saída 1 se houver FALHA.
"""
import io
import json
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
PB_BIN = os.path.join(RAIZ, 'pb', 'bin', 'pocketbase.exe' if os.name == 'nt' else 'pocketbase')
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
    env = {k: v for k, v in os.environ.items() if k != 'TURNKEY_DEV'}
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
    return [n for n, c in cols.items() if not n.startswith('_') and n not in ('users', 'empresas')
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
        check(not r.get('verified'), 'registo novo não vem verificado (sem TURNKEY_DEV)')
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
        s, _, _ = call('POST', '/api/turnkey/team/members',
                       {'email': f'x{quem}@seg.local', 'password': 'Teste12345!', 'papel': 'viewer'}, tok[quem])
        check(s == 403, f'equipa: {quem} não cria membros', f'status {s}')
        s, _, _ = call('PATCH', f'/api/turnkey/team/members/{users["viewerA"]}', {'papel': 'admin'}, tok[quem])
        check(s == 403, f'equipa: {quem} não muda papéis', f'status {s}')
    s, r, _ = call('POST', '/api/turnkey/team/members',
                   {'email': 'novoadmin@seg.local', 'password': 'Teste12345!', 'papel': 'admin'}, tok['adminA'])
    if s == 200:
        s2, r2, _ = call('GET', f'/api/collections/users/records/{r["id"]}', tok=su)
        check(r2.get('papel') != 'admin', 'equipa: admin não cria outro admin', f'papel={r2.get("papel")}')
    s, r, _ = call('POST', '/api/turnkey/team/members',
                   {'email': 'curta@seg.local', 'password': '123', 'papel': 'viewer'}, tok['ownerA'])
    check(s == 400, 'equipa: palavra-passe curta recusada', f'status {s}')
    s, r, _ = call('POST', '/api/turnkey/team/members',
                   {'email': 'ownera@seg.local', 'password': 'Teste12345!', 'papel': 'viewer'}, tok['ownerA'])
    check(s in (400, 409), 'equipa: email repetido não dá erro 500', f'status {s}')
    # o admin não mexe em proprietários nem noutros admins
    s, _, _ = call('PATCH', f'/api/turnkey/team/members/{users["ownerA2"]}', {'papel': 'viewer'}, tok['adminA'])
    check(s == 403, 'equipa: admin não rebaixa um proprietário', f'status {s}')
    call('PATCH', f'/api/collections/users/records/{users["ownerA2"]}', {'papel': 'owner'}, su)
    s, _, _ = call('POST', '/api/turnkey/team/members',
                   {'email': 'admin2@seg.local', 'password': 'Teste12345!', 'papel': 'admin'}, tok['ownerA'])
    s, r, _ = call('GET', "/api/collections/users/records?filter=email='admin2@seg.local'", tok=su)
    if r.get('items'):
        a2 = r['items'][0]['id']
        s, _, _ = call('PATCH', f'/api/turnkey/team/members/{a2}', {'papel': 'viewer'}, tok['adminA'])
        check(s == 403, 'equipa: admin não rebaixa outro admin', f'status {s}')
    s, _, _ = call('PATCH', f'/api/turnkey/team/members/{users["viewerA"]}', {'papel': 'viewer'}, tok['ownerB'])
    check(s in (403, 404), 'equipa: owner de B não mexe em utilizadores de A', f'status {s}')
    # último proprietário
    call('PATCH', f'/api/collections/users/records/{users["ownerA2"]}', {'papel': 'viewer'}, su)
    s, _, _ = call('PATCH', f'/api/turnkey/team/members/{users["ownerA"]}', {'papel': 'viewer'}, tok['ownerA'])
    check(s == 400, 'equipa: não se remove o último proprietário', f'status {s}')


# ---------------------------------------------------------------------------
# 3. endpoints próprios
# ---------------------------------------------------------------------------
ROTAS = [
    ('POST', '/api/turnkey/admin/recompute'),
    ('POST', '/api/turnkey/admin/relink-espelhos'),
    ('POST', '/api/turnkey/faturas/{faturas}/analisar'),
    ('POST', '/api/turnkey/faturas/{faturas}/aplicar'),
    ('GET', '/api/turnkey/faturas/export'),
    ('POST', '/api/turnkey/inventario/ajustar'),
    ('GET', '/api/turnkey/producoes/{producoes}/plano'),
    ('POST', '/api/turnkey/producoes/{producoes}/lista-compras'),
    ('POST', '/api/turnkey/producoes/{producoes}/concluir'),
    ('GET', '/api/turnkey/fichas/resolver'),
    ('GET', '/api/turnkey/receitas/{receitas}/plano'),
    ('GET', '/api/turnkey/fichas/{fichas_tecnicas}/plano'),
    ('POST', '/api/turnkey/ingredientes/{ingredientes}/rotulo'),
    ('POST', '/api/turnkey/nutricao/ler-rotulo'),
    ('POST', '/api/turnkey/ingredientes/auto-insa'),
    ('POST', '/api/turnkey/onboarding'),
    ('POST', '/api/turnkey/team/members'),
    ('PATCH', '/api/turnkey/team/members/{users}'),
    ('POST', '/api/turnkey/vendus/sincronizar'),
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
    sec('3. Endpoints próprios (/api/turnkey/*)')
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
        s, _, _ = call('POST', '/api/turnkey/admin/recompute', {}, tok[quem])
        check(s == 403, f'admin/recompute: {quem} recusado', f'status {s}')
    s, _, _ = call('POST', '/api/turnkey/admin/recompute', {'empresa': empresas['B']}, tok['adminA'])
    s2, r2, _ = call('POST', '/api/turnkey/admin/recompute', {'empresa': empresas['B']}, tok['adminA'])
    check(s in (200, 400), 'admin/recompute: admin de A só afeta a própria empresa (ignora o corpo)')
    for quem in ('viewerA',):
        for rota in ('/api/turnkey/inventario/ajustar', '/api/turnkey/vendus/sincronizar',
                     '/api/turnkey/ingredientes/auto-insa'):
            s, _, _ = call('POST', rota, {}, tok[quem])
            check(s in (400, 403), f'{rota}: Leitura não escreve', f'status {s}')
    ing = dados.get(('ingredientes', 'A'))
    if ing:
        # dados inválidos / enormes: nunca 500
        lixo = [{'ingredienteId': ing[0], 'quantidade': 'abc'}, {'ingredienteId': ing[0], 'quantidade': 1e308},
                {'ingredienteId': ing[0], 'quantidade': -5}, {'ingredienteId': {'$ne': 1}, 'quantidade': 1},
                {'ingredienteId': 'x' * 100000}, [], 'texto', {'quantidade': None}]
        for i, corpo in enumerate(lixo):
            s, r, _ = call('POST', '/api/turnkey/inventario/ajustar', corpo, tok['editorA'])
            check(s != 500, f'inventario/ajustar com dados inválidos #{i}: sem erro 500', f'status {s}')
    s, r, _ = call('POST', '/api/turnkey/inventario/ajustar', raw=b'{isto nao e json', tok=tok['editorA'])
    check(s in (400, 403, 422), 'inventario/ajustar com JSON inválido: erro 4xx', f'status {s}')
    s, r, _ = call('POST', '/api/turnkey/nutricao/ler-rotulo', {'imagemBase64': 'A' * 12_000_000}, tok['editorA'])
    check(s in (400, 413, 503, 403, 422), 'ler-rotulo com corpo enorme: recusado ou sem IA', f'status {s}')


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


def main():
    arrancar()
    try:
        preparar()
        teste_isolamento()
        teste_papeis()
        teste_endpoints()
        teste_uploads()
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
