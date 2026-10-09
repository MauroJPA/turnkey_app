# gc_turnkey — guia para o Claude (lê isto primeiro)

ERP de uma pastelaria/loja de cookies (**Flutter web + PocketBase 0.40.x**). O dono, o Mauro, fala
português europeu: **responde sempre em português**, curto e direto. A app tem de ser **ágil, prática
e reduzir a complexidade** para quem a usa. Estás na pasta `turnkey_app` (a pasta-mãe `app_receitas2`
é OUTRO repositório, do GitLab — não lhe toques).

## Regras que nunca se quebram
- **Cada funcionalidade = uma versão** (etiqueta git `vX.Y.Z`). Linha atual: **2.x no ramo `ux-2`**
  (o `main` anda atrás; o GitHub é `MauroJPA/turnkey_app`). Quem publica no servidor é o Mauro.
- **WhatsApp só no código, nunca ligado.** Email e Telegram sim.
- **Erros de APIs externas nunca em bruto** para a interface (podem trazer URL/chave): mensagem amigável.
  Nos hooks, tirar `bot<token>` dos erros. Segredos só em `pb_data`/`.env`, nunca no git.
- **Botão num `Row`**: nunca `FilledButton`/`OutlinedButton` como filho não-`Expanded` (largura infinita).
- **`SnackBar` com ação** tem de levar `persist: false`, senão não desaparece sozinho (Flutter 3.47).
- Um hook do PocketBase (`pb/hooks/*.pb.js`) corre **isolado**: constantes e funções têm de estar DENTRO do
  handler, ou num módulo partilhado com `require(\`${__hooks}/x.js\`)`. `findFirstRecordByFilter` não aceita
  ordenação (usa `findRecordsByFilter(..., '-campo', 1, 0, params)`).
- Os `.freezed.dart` editam-se à mão (o `build_runner` está estragado).
- **Permissões por página**: `lib/src/features/navigation/domain/pagina_app.dart`; as sub-rotas herdam a
  da página-mãe.

## Fluxo de trabalho (poupa tempo e tokens)
1. **Uma sessão nova por funcionalidade** — sessões longas ficam caras e lentas. A memória
   (`~/.claude/projects/.../memory/`, índice `MEMORY.md`) e este ficheiro trazem o contexto.
2. **Durante o trabalho** (segundos): `bash scripts/verificar-rapido.sh [test/x_test.dart …]`
   (analyze + testes + sintaxe dos hooks + testes de node). Não corras o `verificar.sh` completo a cada passo.
3. **Ver no browser só quando o ecrã é novo** (lógica e relatórios: os testes bastam). Usa
   `python scripts/ensaio.py --build` (compila e arranca um PocketBase descartável em
   `http://127.0.0.1:8813`, com conta de teste; credenciais em `.ensaio/credenciais.txt`; parar com
   `python scripts/ensaio.py parar`).
4. **Fechar uma versão**: escreve o texto do changelog e da checklist num ficheiro temporário e corre
   `python scripts/fechar-versao.py X.Y.Z "Título" --changelog cl.md --checklist ck.md --pendente "…" --verificar --commit --tag`
   (corre o `verificar.sh` completo, atualiza pubspec/CHANGELOG/checklist/pendentes e faz commit + etiqueta
   só com os caminhos certos). Mexeste em texto visível ao utilizador? Atualiza também
   `lib/src/core/help/help_content.dart`. Segurança/endpoints novos → `docs/SEGURANCA.md`.
5. **Pacote** (só quando o Mauro vai publicar): `powershell -File scripts\empacotar-producao.ps1`
   → `dist/gc_turnkey-servidor-X.tar.gz` + SHA-256. Dá-lhe o comando:
   `bash scripts/publicar-producao.sh dist/gc_turnkey-servidor-X.tar.gz virusserver@192.168.1.151 /opt/gc_turnkey 2022`.
   Vários lotes podem ir num só pacote.
6. **Git**: `git add` sempre com caminhos explícitos (**nunca** `git add .` nem `git add pb`: há
   `pb/pb_data*` com dados). Só enviar para o GitHub quando o Mauro pedir.
7. Atualiza a memória (`pendentes-versoes.md`) no fim de um lote, não a cada passo.

## Comandos
```bash
flutter analyze && flutter test                    # o que o verificar-rapido faz
bash scripts/verificar.sh                          # COMPLETO (~3 min): + migrations + suíte de segurança
python test/security/seguranca.py                  # só a suíte de segurança (PocketBase descartável, portas 818x)
node test/seguranca/test_*.js                      # testes de node dos módulos dos hooks
dart format <ficheiros que mexeste>                # NUNCA numa pasta inteira (reformata ficheiros alheios)
```
Todos os testes de node ficam em `test/seguranca/`; os de Python em `test/seguranca/` e `test/security/`.

## Armadilhas conhecidas
- **Windows + Git Bash**: heredocs com apóstrofos/aspas falham no tool Bash → escreve scripts com a
  ferramenta de escrever ficheiros e corre-os. Caminhos longos (`git worktree add` num caminho fundo
  falha): usa um caminho curto (ex. `C:\Users\mauro\tm`).
- Os ficheiros de docs, `pubspec.yaml`, `CHANGELOG.md` e alguns `.dart`/`.py` são **CRLF**; os `.js` dos
  hooks e quase todo o `.dart` são LF. Os scripts de edição têm de preservar as quebras de linha.
- Em `lib/` não importes `prefs_locais.dart` (usa `dart:html`) em ficheiros que os testes de unidade
  carregam: põe a lógica pura em `domain/`.
- Browser de ensaio: o Flutter web é um canvas (sem árvore de acessibilidade): usa capturas. Depois de
  recompilar, desregista o service worker e recarrega (`navigator.serviceWorker.getRegistrations()` +
  `caches.delete`). As rotas são com `#/` (ex. `http://127.0.0.1:8813/#/contagem/fecho`). As capturas
  falham ao acaso: repete. Para ver uma folha comprida (`showModalBottomSheet`) aumenta o viewport
  (ex. 800 × 1900) em vez de rolar.
- `$dbx.exp` do PocketBase é **SQL** (`AND`, `COALESCE`), não a sintaxe de filtros (`&&`).
- No servidor, qualquer programa que escreva em `data/` (vigia, cópias externas) pode fazer o `tar` do
  backup dizer "file changed"; o `gc_turnkey.sh` já repete.

## Onde está cada coisa
- `lib/src/features/<feature>/{data,domain,application,presentation}`; widgets partilhados em `lib/src/core`.
- `pb/migrations` (schema; a última tem o maior número), `pb/hooks` (endpoints, crons, módulos `*.js`).
- `deploy/` (Docker, `gc_turnkey.sh`, backups, `seguranca/vigia.py`); `docs/` (SERVIDOR_LINUX, SEGURANCA,
  CHECKLIST_TESTES, PENDENTES, FLUXO_GIT, ROTULAGEM_LEGAL, BACKUPS).
- Versão: `pubspec.yaml`. Histórico: `CHANGELOG.md` (a mais recente em cima).
