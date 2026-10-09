"""Fecha uma versão num só comando: pubspec, CHANGELOG, checklist, pendentes
e (se quiseres) commit e etiqueta.

    python scripts/fechar-versao.py 2.19.0 "Título curto" \\
        --changelog cl.md --checklist ck.md [--pendente "o que ficou feito"] \\
        [--verificar] [--commit] [--tag] [--simular]

  --changelog F   corpo da entrada do CHANGELOG (sem o cabeçalho "## ..."); "-" lê do stdin
  --checklist F   itens da checklist de testes ("- [ ] ..."); o cabeçalho "## N. Título"
                  e o número são postos pelo script (opcional)
  --pendente T    linha "feito" em docs/PENDENTES.md (opcional)
  --verificar     corre scripts/verificar.sh (completo) ANTES de mexer em nada e pára se falhar
  --commit        faz `git add` só dos caminhos certos (nunca `pb/` inteiro) e o commit
  --tag           cria a etiqueta vX.Y.Z (implica --commit)
  --simular       mostra o que faria, sem escrever nada

Os ficheiros mantêm as quebras de linha que tinham (CRLF/LF). Só biblioteca padrão.
"""
import argparse
import datetime
import os
import re
import subprocess
import sys

for _f in (sys.stdout, sys.stderr):
    try:
        _f.reconfigure(encoding='utf-8')  # acentos certos na consola do Windows
    except Exception:
        pass

RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
TRAILER = 'Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>'
# o que entra num commit de versão (explícito: nunca `git add pb` nem `git add .`)
CAMINHOS = ['CHANGELOG.md', 'docs', 'lib', 'test', 'pubspec.yaml', 'scripts', 'web', 'deploy',
            'pb/hooks', 'pb/migrations', 'pb/README.md', 'pb/DEPLOY.md', '.gitignore', 'CLAUDE.md', 'README.md']
PROIBIDOS = ('pb_data', '/.env', '.ensaio', 'dist/', 'build/')


def ler(p):
    with open(os.path.join(RAIZ, p), encoding='utf-8', newline='') as f:
        s = f.read()
    return s.replace('\r\n', '\n'), '\r\n' in s


def gravar(p, texto, crlf, simular):
    if simular:
        return
    with open(os.path.join(RAIZ, p), 'w', encoding='utf-8', newline='') as f:
        f.write(texto.replace('\n', '\r\n') if crlf else texto)


def corpo(arg):
    if not arg:
        return ''
    if arg == '-':
        return sys.stdin.read().strip('\n')
    with open(arg, encoding='utf-8') as f:
        return f.read().strip('\n')


def tupla(v):
    return tuple(int(x) for x in v.split('.'))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('versao')
    ap.add_argument('titulo')
    ap.add_argument('--changelog', required=True)
    ap.add_argument('--checklist')
    ap.add_argument('--pendente')
    ap.add_argument('--verificar', action='store_true')
    ap.add_argument('--commit', action='store_true')
    ap.add_argument('--tag', action='store_true')
    ap.add_argument('--simular', action='store_true')
    a = ap.parse_args()
    if not re.fullmatch(r'\d+\.\d+\.\d+', a.versao):
        sys.exit('A versão tem de ser X.Y.Z (ex.: 2.19.0).')
    if a.tag:
        a.commit = True
    sim = a.simular

    pub, crlf_pub = ler('pubspec.yaml')
    m = re.search(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)', pub, re.M)
    if not m:
        sys.exit('Não encontrei "version: X.Y.Z+N" no pubspec.yaml.')
    if tupla(a.versao) <= tupla(m.group(1)):
        sys.exit(f'A versão {a.versao} não é mais recente do que a atual ({m.group(1)}).')
    build = int(m.group(2)) + 1

    if a.verificar:
        print('== a correr scripts/verificar.sh (completo)…')
        r = subprocess.run(['bash', 'scripts/verificar.sh'], cwd=RAIZ)
        if r.returncode != 0:
            sys.exit('A verificação falhou: nada foi alterado.')

    # pubspec
    pub = pub.replace(m.group(0), f'version: {a.versao}+{build}', 1)
    gravar('pubspec.yaml', pub, crlf_pub, sim)

    # changelog
    cl, crlf_cl = ler('CHANGELOG.md')
    primeira = re.search(r'^## ', cl, re.M)
    if not primeira:
        sys.exit('CHANGELOG.md sem entradas ("## ...").')
    cab = f'## {a.versao} — {datetime.date.today().isoformat()} — {a.titulo}\n\n'
    cl = cl[:primeira.start()] + cab + corpo(a.changelog) + '\n\n' + cl[primeira.start():]
    gravar('CHANGELOG.md', cl, crlf_cl, sim)

    # checklist
    n = None
    if a.checklist:
        ck, crlf_ck = ler('docs/CHECKLIST_TESTES.md')
        n = max([int(x) for x in re.findall(r'^## (\d+)\. ', ck, re.M)] or [0]) + 1
        itens = corpo(a.checklist)
        itens = re.sub(r'^## .*\n*', '', itens, count=1)  # tira um cabeçalho que já venha no ficheiro
        alvo = '---\n\n## Notas / ajustes pedidos'
        if alvo not in ck:
            sys.exit('docs/CHECKLIST_TESTES.md: não encontrei o marcador "## Notas / ajustes pedidos".')
        ck = ck.replace(alvo, f'## {n}. {a.titulo}\n\n{itens}\n\n{alvo}', 1)
        gravar('docs/CHECKLIST_TESTES.md', ck, crlf_ck, sim)

    # pendentes
    pe, crlf_pe = ler('docs/PENDENTES.md')
    pe = re.sub(r'Última versão fechada: \*\*[\d.]+\*\*', f'Última versão fechada: **{a.versao}**', pe, count=1)
    if a.pendente:
        fim = '- No fim: empacotar'
        linha = f'- ~~**{a.versao}**~~ (feito) {a.pendente}\n'
        pe = pe.replace(fim, linha + fim, 1) if fim in pe else pe.rstrip('\n') + '\n' + linha
    gravar('docs/PENDENTES.md', pe, crlf_pe, sim)

    print(f'{"[simulação] " if sim else ""}versão {a.versao}+{build} · changelog'
          f'{f" · checklist n.º {n}" if n else ""} · pendentes')

    if a.commit and not sim:
        existentes = [c for c in CAMINHOS if os.path.exists(os.path.join(RAIZ, c))]
        subprocess.run(['git', 'add', '--'] + existentes, cwd=RAIZ, check=True)
        staged = subprocess.run(['git', 'diff', '--cached', '--name-only'], cwd=RAIZ, capture_output=True, text=True).stdout.split()
        mau = [f for f in staged if any(p in '/' + f for p in PROIBIDOS)]
        if mau:
            subprocess.run(['git', 'reset', '-q'], cwd=RAIZ)
            sys.exit('Ficheiros que nunca devem ir para o git: ' + ', '.join(mau) + ' (nada foi commitado).')
        msg = f'{a.versao}: {a.titulo}\n\n{TRAILER}\n'
        subprocess.run(['git', 'commit', '-q', '-m', msg], cwd=RAIZ, check=True)
        print('commit feito:', subprocess.run(['git', 'log', '--oneline', '-1'], cwd=RAIZ, capture_output=True, text=True, encoding='utf-8').stdout.strip())
        if a.tag:
            subprocess.run(['git', 'tag', f'v{a.versao}'], cwd=RAIZ, check=True)
            print(f'etiqueta v{a.versao} criada')
    elif not a.commit:
        print('Falta: verificar (bash scripts/verificar.sh), commit e etiqueta — ou volta a correr com --commit --tag.')
    print('Para publicar: powershell -File scripts\\empacotar-producao.ps1 (e scripts/publicar-producao.sh).')


if __name__ == '__main__':
    main()
