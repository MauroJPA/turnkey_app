# Pendentes (fila de trabalho)

Última versão fechada: **2.5.0** (ver CHANGELOG). Cada item abaixo = **uma versão própria**
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
- ~~**1.86.0**~~ (feito) Rastreabilidade por lote com QR na etiqueta (lote do ingrediente → lote do produto; Reg. 178/2002).
- ~~**1.87.0**~~ (feito) Rentabilidade por sabor e canal (ranking de lucro por unidade e por hora de forno, com os canais e as taxas).
- ~~**1.88.0**~~ (feito) Tabela de preços para revendedores (PDF e texto para WhatsApp, preço + IVA, desconto por volume) a partir dos canais.
- ~~**1.89.0**~~ (feito) "Quantos assar amanhã": sugestão por dia da semana e desperdício + predição estatística/IA que melhora com o histórico.
- ~~**1.90.0**~~ (feito) Quiosque offline: guarda os registos no aparelho se o Wi-Fi cair e envia depois.
- ~~**1.92.0**~~ (feito) Pessoas → Ponto: entrada/pausa/saída (quiosque com NFC, também offline, e na app), horas do mês, correções do administrador, CSV.
- ~~**1.93.0**~~ (feito) Pessoas → Férias: mapa de férias e ausências (pedidos, aprovação, saldo de dias, calendário da equipa).
- ~~**1.94.0**~~ (feito) Pessoas → Notas: anotações da equipa (livro de ocorrências / recados) com fixar e arquivar.
- No fim: empacotar, dar SHA-256 + comando; atualizar docs/SEGURANCA.md se houver novos endpoints.

## Fila 2.x — UI/UX mais ágil (aprovada pelo Mauro em 06/10/2026; branch `ux-2`, cada item = uma versão, por esta ordem)
Princípio: prático, ágil, menos cliques e menos ecrã; nenhuma funcionalidade desaparece.
- ~~**2.0.0**~~ (feito) Início "Hoje": saudação, 3 atalhos à escolha, "Precisa de ti" com o botão que resolve na própria linha, "Para saber" fechado.
- ~~**2.1.0**~~ (feito) Menu "Mais" agrupado por tarefa + pesquisa global (páginas, ingredientes, fichas) em vez da grelha de mosaicos.
- ~~**2.2.0**~~ (feito) Opções em grupos com estado ("Vendus sem sincronizar", "Backup ok"); cada grupo abre uma página curta.
- ~~**2.3.0**~~ (feito) Hubs com poucos separadores (Contabilidade 8 → 3, etc.) e lembrar o último separador de cada hub.
- ~~**2.4.0**~~ (feito) "Plano de amanhã" em 3 passos: o que assar → agendar → compras, num só caminho.

## Fila aprovada pelo Mauro em 06/10/2026 (cada item = uma versão; princípio: ágil, poupar tempo, nunca atrapalhar a rotina)
- ~~**1.95.0**~~ (feito) Escala semanal da equipa (mapa de horário): horário habitual por pessoa + exceções por dia; horas previstas × marcadas no Ponto.
- ~~**1.96.0**~~ (feito) Dias de trabalho e férias nos avisos: resumo diário e HACCP "por fazer" ignoram folgas; quem está de férias não atrasa.
- ~~**1.97.0**~~ (feito) Aviso de "saída por marcar" no resumo diário e no Início.
- ~~**1.98.0**~~ (feito) Quantos assar → agendar a produção com um toque; comparar a previsão com o vendido real.
- ~~**1.99.0**~~ (feito) Alertas de validade por lote (ingredientes e produtos), usando os lotes e o stock.
- ~~**1.100.0**~~ (feito) Saúde dos dados: fichas sem preço/tempo/temperatura, ingredientes sem preço.
- ~~**1.101.0**~~ (feito) Importação diária automática das vendas do Vendus.
- ~~**1.102.0**~~ (feito) App que abre sem Wi-Fi (service worker).
- ~~**1.103.0**~~ (feito) Segurança: 2 passos, teste de restauro dos backups, espaço em disco no cartão de backups.
- ~~**1.104.0**~~ (feito) Comparador de preços entre fornecedores.
- ~~**1.105.0**~~ (feito) Custo do desperdício por motivo e sabor.
- ~~**1.106.0**~~ (feito) Formações e certificados das pessoas, com validade e aviso.

## Fila aprovada pelo Mauro em 06/10/2026 (2.ª ronda, depois da 1.106)
- ~~**1.107.0**~~ (feito) Resumo semanal para o proprietário (vendas, margem, desperdício, horas, o que caduca).
- ~~**1.108.0**~~ (feito) Sugestão de preço quando um ingrediente sobe (margem alvo, aplicar com um toque).
- ~~**1.109.0**~~ (feito) Lista de compras automática a partir do "Quantos assar" e do stock (com o fornecedor mais barato).
- ~~**1.110.0**~~ (feito) Renovação de certificados: do aviso ao "Nova formação" já preenchido.

## Notas para quem retomar
- Pacote publicado no servidor ainda é o **1.48.2**; tudo depois está só empacotado/commitado. Antes do deploy:
  `df -h /` no servidor. Migrations novas até `1790970000`.
- NFC do quiosque só funciona em Chrome/Android com **HTTPS**.
- Estilo de trabalho: respostas em português; botões nunca soltos num `Row` (usar `Expanded`/`Wrap` com
  `minimumSize: Size(0, 44)`); erros ao utilizador sempre com `mensagemAmigavel(e)`.
- Servidor de teste local: `pb/bin/pocketbase.exe serve --http=127.0.0.1:8813 --dir=<scratch>/haccpdb
  --hooksDir=pb/hooks --migrationsDir=pb/migrations --publicDir=build/web` com `GC_TURNKEY_DEV=1`
  (conta de teste `haccp@t.local`).
