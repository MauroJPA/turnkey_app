# Pendentes (fila de trabalho)

Última versão fechada: **1.70.0** (ver CHANGELOG). Cada item abaixo = **uma versão própria**
(editar → `bash scripts/verificar.sh` → pubspec + CHANGELOG + docs/CHECKLIST_TESTES.md → commit com caminhos
explícitos → `git branch -f develop main` → `git tag vX.Y.Z`). No fim: `powershell -File scripts\empacotar-producao.ps1`
e dar ao Mauro o SHA-256 + comando de publicação.

1. ~~1.67.0 — Formatos de cookie e categorias de receita sem páginas próprias~~ (feito).
2. ~~1.68.0~~ (feito; docs/wip removido) **Finanças simplificadas + página Contabilidade.** *(trabalho a meio, guardado em `docs/wip/`: `1.68.0-contabilidade.patch` (aplicar com `git apply`) + `contabilidade_screen.dart.txt` (copiar para `lib/src/features/finance/presentation/contabilidade_screen.dart`). Falta: rotas no `router.dart` (usar `ContabilidadeScreen(secao: …)` em painelFinanceiro/dre/custosFixos/equipamentos/numerosMagicos + nova `Routes.relatorios`), `HelpTopic.contabilidade`, catálogo (uma só entrada «Contabilidade»; sai custosFixos/equipamentos/numerosMagicos; Início usa `acessivel('financeiro')` nos pagamentos), testes `navegacao_test`, docs.)* Nova página "Contabilidade" (faturação, IVA,
   números da empresa, relatório geral, compras do período, DRE) e simplificar Painel financeiro / Custos fixos /
   Equipamentos / Números mágicos / DRE / Análise de vendas (menos páginas soltas, tudo a poucos toques).
3. ~~1.69.0 — Revisão final de interface~~ (feito): alinhamentos de texto e botões, tamanhos, consistência (pedido do
   Mauro: "veja e reveja tudo… alinhamentos de textos, botões, etc."); ver cada ecrã em largura de telemóvel.
4. Empacotar a versão final e entregar SHA-256 + comando de publicação.

## Notas para quem retomar
- Pacote publicado no servidor ainda é o **1.48.2**; tudo depois está só empacotado/commitado. Antes do deploy:
  `df -h /` no servidor. Migrations novas até `1790950000`.
- NFC do quiosque só funciona em Chrome/Android com **HTTPS**.
- Estilo de trabalho: respostas em português; botões nunca soltos num `Row` (usar `Expanded`/`Wrap` com
  `minimumSize: Size(0, 44)`); erros ao utilizador sempre com `mensagemAmigavel(e)`.
- Servidor de teste local: `pb/bin/pocketbase.exe serve --http=127.0.0.1:8813 --dir=<scratch>/haccpdb
  --hooksDir=pb/hooks --migrationsDir=pb/migrations --publicDir=build/web` com `GC_TURNKEY_DEV=1`
  (conta de teste `haccp@t.local`).
