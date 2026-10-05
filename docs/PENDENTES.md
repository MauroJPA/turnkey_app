# Pendentes (fila de trabalho)

Última versão fechada: **1.85.0** (ver CHANGELOG). Cada item abaixo = **uma versão própria**
(editar → `bash scripts/verificar.sh` → pubspec + CHANGELOG + docs/CHECKLIST_TESTES.md → commit com caminhos
explícitos → `git branch -f develop main` → `git tag vX.Y.Z`). No fim: `powershell -File scripts\empacotar-producao.ps1`
e dar ao Mauro o SHA-256 + comando de publicação.

Fila atual (pedido do Mauro em 06/10/2026, **cada item = uma versão**, por esta ordem; marcar ~~feito~~ ao fechar):

- ~~**1.81.0**~~ (feito) Temperatura do forno em cada ficha técnica (campo) + mostrar "°C e minutos" ao assar (Contagem/forno, Produção).
- ~~**1.82.0**~~ (feito) Alerta de variação de preço: quando uma fatura sobe um ingrediente mais de X % (limiar configurável), mostrar as
  fichas afetadas e o impacto nas margens (cartão no Início + lista "Variações de preço").
- ~~**1.83.0**~~ (feito) Aprovações dentro da app (só o operador da plataforma): listar contas por aprovar, aprovar/recusar, sem usar `/_/`.
- ~~**1.84.0**~~ (feito) Cartão "Estado dos backups" para administradores (script de backup escreve um ficheiro de estado; aviso se falhar/atrasar).
- ~~**1.85.0**~~ (feito) Avisos e resumo diário (HACCP por fazer, stock baixo, pagamentos) por **email** e **Telegram** (WhatsApp só no código,
  desligado: a API é paga).
- **1.86.0** Rastreabilidade por lote com QR na etiqueta (lote do ingrediente → lote do produto; Reg. 178/2002).
- **1.87.0** Rentabilidade por sabor e canal (ranking de lucro por unidade e por hora de forno, com os canais e as taxas).
- **1.88.0** Tabela de preços para revendedores (PDF e texto para WhatsApp, preço + IVA, desconto por volume) a partir dos canais.
- **1.89.0** "Quantos assar amanhã": sugestão por dia da semana e desperdício + predição estatística/IA que melhora com o histórico.
- **1.90.0** Quiosque offline: guarda os registos no aparelho se o Wi-Fi cair e envia depois.
- No fim: empacotar, dar SHA-256 + comando; atualizar docs/SEGURANCA.md se houver novos endpoints.

## Notas para quem retomar
- Pacote publicado no servidor ainda é o **1.48.2**; tudo depois está só empacotado/commitado. Antes do deploy:
  `df -h /` no servidor. Migrations novas até `1790970000`.
- NFC do quiosque só funciona em Chrome/Android com **HTTPS**.
- Estilo de trabalho: respostas em português; botões nunca soltos num `Row` (usar `Expanded`/`Wrap` com
  `minimumSize: Size(0, 44)`); erros ao utilizador sempre com `mensagemAmigavel(e)`.
- Servidor de teste local: `pb/bin/pocketbase.exe serve --http=127.0.0.1:8813 --dir=<scratch>/haccpdb
  --hooksDir=pb/hooks --migrationsDir=pb/migrations --publicDir=build/web` com `GC_TURNKEY_DEV=1`
  (conta de teste `haccp@t.local`).
