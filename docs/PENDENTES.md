# Pendentes (fila de trabalho)

Última versão fechada: **1.66.0** (ver CHANGELOG). Cada item abaixo = **uma versão própria**
(editar → `bash scripts/verificar.sh` → pubspec + CHANGELOG + docs/CHECKLIST_TESTES.md → commit com caminhos
explícitos → `git branch -f develop main` → `git tag vX.Y.Z`). No fim: `powershell -File scripts\empacotar-producao.ps1`
e dar ao Mauro o SHA-256 + comando de publicação.

1. **1.67.0 — Formatos de cookie e categorias de receita sem páginas próprias.**
   - Formato: escolhido na ficha técnica (e nas receitas, onde se usa) num seletor que também **cria** o formato
     (nome, massa g, recheio g) na hora; editar e remover (automático quando nenhuma ficha o usa).
     Sai `Routes.cookieFormats` (`/opcoes/formatos`) do catálogo/rotas (redirect para as fichas).
   - Categorias de receita: seletor ao criar/editar receita, com criar/editar/remover (remover sozinho quando
     nenhuma receita a usa). Sai `Routes.categoriasReceita`.
   - Filtros das listas (receitas, fichas, ingredientes…) mais ágeis (chips, um toque).
2. **1.68.0 — Finanças simplificadas + página Contabilidade.** Nova página "Contabilidade" (faturação, IVA,
   números da empresa, relatório geral, compras do período, DRE) e simplificar Painel financeiro / Custos fixos /
   Equipamentos / Números mágicos / DRE / Análise de vendas (menos páginas soltas, tudo a poucos toques).
3. **1.69.0 — Revisão final de interface**: alinhamentos de texto e botões, tamanhos, consistência (pedido do
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
