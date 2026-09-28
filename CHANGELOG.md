# Changelog — turnkey_app

Versões da app (Flutter) + schema/hooks do PocketBase. Datas em AAAA-MM-DD.

## 1.21.0 — 2026-09-28 — Faturas: corrigir marca/fornecedor de linhas já aplicadas

- **Bug corrigido: o fornecedor não ficava gravado quando o produto já existia.** Ao aplicar uma fatura, se a
  descrição já batia certo com um produto de compra (marca) que já tinha sido criado antes, o **fornecedor**
  da fatura nunca era gravado nesse produto — só acontecia ao criar o produto pela primeira vez. A marca já
  funcionava bem (preenchia sempre que estava em branco); o fornecedor agora segue a mesma regra.
- **Corrigir marca/fornecedor mesmo com a fatura já aplicada/confirmada** — só o **proprietário** e o
  **administrador**, para o caso de algo passar despercebido e só se notar depois, olhando de novo para a
  fatura em PDF/imagem. As linhas já aplicadas deixam de aparecer só como um número resumido: abrem numa
  lista, cada uma com a marca/fornecedor gravados e um lápis para corrigir (endpoint novo
  `/api/gc_turnkey/faturas/{id}/corrigir-item`). Ao contrário de aplicar a fatura normalmente, esta correção
  **substitui sempre** o que já lá estava — é uma correção explícita, não um preenchimento automático.
- `faturas_itens` passa a guardar a que **produto de compra** (marca) uma linha de ingrediente ficou ligada, e
  a marca/fornecedor que ficaram gravados — para a correção saber onde mexer mesmo muito depois de aplicada
  (migration `1707955216_faturas_itens_produto_marca`).
- Cada correção fica no histórico da fatura, com os valores antes e depois e quem a fez.
- Testes: `test/faturas_pendente_embalagem_test.dart` (`ItemFaturaAnterior.fromRecord` com produto/marca/
  fornecedor) e uma secção nova em `test/security/seguranca.py` — reproduz o bug antigo (fatura sem
  fornecedor, depois outra com fornecedor sobre o mesmo produto), confirma que fica corrigido, e testa o
  endpoint `/corrigir-item`: editor e viewer recusados, fatura de outra empresa recusada, proprietário e
  administrador conseguem corrigir e a correção substitui o valor antigo.

## 1.20.1 — 2026-09-28 — Embalagens: quantidade do múltiplo

- Quando o **uso** é **Múltiplo**, aparece agora uma escolha rápida da quantidade (2, 3, 4, 5, 6, 8, 10, 12 —
  chips) tanto no ecrã de **Embalagens** como ao criar uma embalagem nova na revisão de uma fatura. Escolher
  **Individual** fixa a quantidade em 1 automaticamente; para outros valores continua a dar para escrever à mão
  no campo "Uma peça embala quantas unidades?" (Embalagens) — a quantidade é o próprio `rende_unidades` que já
  existia, só ficou mais fácil de escolher quando é um múltiplo.

## 1.20.0 — 2026-09-28 — Embalagens: característica, uso e formatos de cookie

- **Característica na embalagem**, tal como já havia nos ingredientes: um texto livre para distinguir variantes
  ("kraft com janela", "transparente 250 ml"…). Editável no ecrã de Embalagens e ao criar uma embalagem nova
  diretamente na revisão de uma fatura.
- **Uso da embalagem** — lista fixa: **Individual**, **Múltiplo** (ex.: caixa de 6), **A granel** ou **Outro**.
  Opcional; ajuda a saber para que serve cada peça sem ter de adivinhar pelo nome.
- **Formatos de cookie a que se destina** — liga a embalagem a um ou mais **Formatos de cookie** já existentes
  (seleção múltipla por chips). Em branco = serve para qualquer formato.
- Migration `1707955215_embalagem_caracteristica_formato` (`embalagens.caracteristica`, `embalagens.uso`,
  `embalagens.formatos_cookie`).
- **Segurança da relação múltipla**: a regra declarativa do PocketBase só garante que *pelo menos um* dos
  formatos escolhidos é da mesma empresa quando o campo aceita vários valores — não que *todos* sejam. Foi
  acrescentado o hook `pb/hooks/embalagens_validacao.pb.js`, que confirma, um a um, que cada formato
  selecionado é da mesma empresa, tanto ao criar como ao alterar uma embalagem.
- A IA das faturas passou a reconhecer característica também em linhas de embalagem (ex.: "Saco kraft com
  janela" → nome genérico "Saco", característica "kraft com janela"); uso e formatos continuam a ser escolhidos
  à mão, por serem decisões da pessoa, não algo que se lê na fatura.
- Testes: `test/embalagem_test.dart` (enum, `fromRecord`, `toBody`) e uma secção nova em
  `test/security/seguranca.py` que prova especificamente que uma lista **mista** (um formato próprio + um de
  outra empresa) é recusada ao criar e ao atualizar — o isolamento genérico só testa um id sozinho, por isso
  não bastava para provar que o hook está a validar cada elemento da lista.

## 1.19.0 — 2026-09-28 — Faturas: aplicar por partes e embalagens

- **Aplicar só o que já sabes, sem bloquear a fatura.** Nem sempre há informação para decidir logo uma linha
  (falta a marca, o preço, ainda não sabes qual ingrediente é). Cada linha pode ficar **"Por rever depois"** —
  diferente de "Ignorar" (essa é definitiva, tipo portes ou descontos). Ao carregar em **Aplicar**, só as linhas
  decididas (Preço/Stock/Preço+Stock) são gravadas; as "por rever" ficam de fora, sem impedir as outras.
- **A fatura mostra quantas faltam.** Sem tudo decidido, fica com o chip **"N por rever"** em vez de "Analisada";
  só passa a "Confirmada" quando não sobra nenhuma. Reabrir a fatura mostra só as que faltam — as já aplicadas
  ficam resumidas numa linha ("N linha(s) já aplicada(s) antes"), sem precisares de as rever outra vez.
  Voltar a aplicar nunca duplica um preço ou um movimento de stock, mesmo reenviando tudo.
- **Embalagens também vêm nas faturas.** Uma linha pode agora ligar-se a uma **Embalagem** (caixa, saco,
  saqueta, adesivo…) em vez de um ingrediente ou consumível — terceiro botão "Embalagem" na revisão. A IA já
  distingue material de embalar (`tipo_item: "embalagem"`) e sugere o tipo; aplicar atualiza o preço por peça da
  embalagem (e aprende o texto da fatura, como os produtos e os consumíveis).
- Migration `1707955214_faturas_pendente_embalagem` (`faturas_itens.linha_index` e ação `pendente`;
  `faturas_itens.embalagem`; `faturas.pendentes_linhas`; `embalagens.nomes_fatura`).
- O endpoint `/aplicar` passa a identificar as linhas pelo índice, em vez de apagar e recriar tudo — dá para
  aplicar a mesma fatura várias vezes seguidas, cada vez só com o que já está pronto.
- Testes: secção 8d do `test/security/seguranca.py` (aplicar parcial, não duplicar, embalagens, isolamento —
  362 verificações, 0 falhas) e `test/faturas_pendente_embalagem_test.dart`.

## 1.18.0 — 2026-09-26 — Faturas: repetição automática, resumo do que entrou, corrigir e apagar (proprietário)

- **A análise repete sozinha.** Quando a IA falha numa janela de páginas (sobrecarga, rede), a app espera e volta a
  tentar, até 5 vezes (5, 10, 20, 30 e 45 s), e mostra o motivo e a contagem na barra: "Páginas 25–30: … Nova
  tentativa em 10 s (2 de 6)…". Só se falhar de vez pede "Continuar" (o que já foi lido fica guardado). O erro diz
  **em que páginas** falhou.
- **Resumo do que entrou.** No fim, o cartão diz quantas faturas são novas, quantas são **duplicadas** (já existiam),
  quantas ficaram sem linhas e as **páginas em que a IA não reconheceu nenhuma fatura**. "Ver o que entrou" lista cada
  documento (fornecedor, nº, data, páginas do PDF e estado). "Duplicada" (já estava na app) passou a ter chip próprio,
  diferente de "Erro" (a IA não conseguiu ler).
- **Corrigir dados de uma fatura** (fornecedor, número, data, total): só o **proprietário**, no lápis do ecrã de
  revisão ou no toque longo da lista. A alteração não refaz o que já foi aplicado aos preços/stock.
- **Apagar fatura: só o proprietário, e nada se perde.** Apagar passa a "esconder": a fatura e o ficheiro continuam na
  base de dados (entram nos backups) e o proprietário restaura-as em Faturas → ⋮ → **Faturas apagadas**. Uma fatura
  apagada não conta como duplicada nem vai para a contabilidade. "Limpar vazias, com erro…" também só esconde e só o
  proprietário o vê.
- **Histórico de alterações** por fatura (ícone do relógio): cada correção, apagar e restaurar ficam registados com
  quem fez e os valores **antes e depois** (`historico`, `entidade_tipo = fatura`). Fica na base de dados, por isso
  também nos backups.
- Os editores continuam a carregar e a analisar faturas e a aplicar preços/stock; já não alteram nem apagam faturas
  (regras da API: `update`/`delete` só para o proprietário).
- Migration `1707955213_faturas_edicao` (campos `apagada`, `apagada_em`, `apagada_por`; regras; tipo `fatura` no
  histórico) e hook `faturas_edicao.pb.js`.
- Testes: secção 8c do `test/security/seguranca.py` (edição, histórico, apagar/restaurar, permissões) e resumo do
  lote (346 verificações, 0 falhas); `test/analise_faturas_test.dart`.

## 1.17.2 — 2026-09-26 — Versão no menu do Início

- O menu dos três pontos (canto superior direito do **Início**) mostra, em letra pequena e discreta, a versão da
  app ("gc_turnkey · v1.17.2") por baixo de "Terminar sessão". Serve para confirmar se o telemóvel já atualizou.

## 1.17.1 — 2026-09-26 — Aviso de versão nova da app

- **Aviso "Há uma versão nova da app" com botão Atualizar.** Depois de o servidor ser atualizado, o telemóvel/browser
  podia continuar com a versão antiga em cache (por exemplo, a fatura grande ficava "Nova", sem análise). A app
  passa a comparar a sua versão com a do servidor (`version.json`, sem cache) ao abrir, de 10 em 10 minutos e ao
  voltar a ser vista; se houver uma versão mais nova mostra o aviso por cima da barra de navegação. **Atualizar**
  limpa a cache da app e recarrega.
- O script `empacotar-producao.ps1` grava a versão na app (`--dart-define=APP_VERSION`).
- A primeira vez precisa de um refresh manual (Ctrl+Shift+R, ou limpar os dados do site no telemóvel); a partir
  daí o aviso trata disto.

## 1.17.0 — 2026-09-26 — Faturas: ficheiros grandes e progresso à vista

- **Corrigido "Request entity too large" (413):** o limite do ficheiro de uma fatura era de 8 MB. Passa a **200 MB**,
  por isso um PDF de dezenas de páginas digitalizado no telemóvel (ex.: 93 páginas, 80 MB) já entra.
- **Análise por janelas de páginas, no servidor.** A app só envia o ficheiro; o servidor lê-o do armazenamento,
  corta-o em janelas de 6 páginas (`GC_TURNKEY_JANELA_PAGINAS`), manda cada uma à IA (o limite da Google é ~20 MB
  por pedido), **junta os documentos que atravessam duas janelas** e separa as faturas como antes (um ficheiro por
  documento). Se a IA falhar numa janela, o que já foi lido **fica guardado** e "Continuar" retoma de onde parou.
  Novas rotas: `/faturas/{id}/preparar`, `/analisar-parte` e `/concluir-analise`.
- **Progresso sempre visível:** ao enviar, aparece um cartão nas Faturas ("A enviar…", "A IA está a ler as
  páginas: 12 de 93…", "A separar as faturas…", "Pronto: N faturas") e uma **faixa por cima da barra de navegação**
  em qualquer ecrã. Corre em segundo plano enquanto a app estiver aberta. Se a app fechar a meio, a fatura aparece
  na lista com **Continuar (12/93)**.
- **Erros sem texto técnico:** já não aparece o `ClientException` com o endereço do servidor; mensagens em
  português ("O ficheiro é grande demais…", "Sem ligação ao servidor…").
- O envio deixou de copiar o ficheiro em memória (`toList()`) e a "análise de novo" já não descarrega o ficheiro.
- **IA:** instruções para faturas de grossistas (Makro, Recheio): a quantidade é a "Qt.Total"; preços por kg
  (quantidade com decimais / descrição em KG) leem-se em kg com embalagem de 1 kg; guias de remessa sem preços
  ficam sem linhas.
- Migration `1707955212_faturas_grandes` (ficheiro 200 MB, `dados_ia` até 5 MB).
- Testes: secção 8 do `test/security/seguranca.py` (janelas, retoma, falha da IA, documento que atravessa
  janelas; 332 verificações, 0 falhas) e `test/analise_faturas_test.dart`.
- Não testado: o `qpdf`/Gemini reais com o teu PDF de 93 páginas (aqui só há simulados). O `base64` usado é o da
  imagem Alpine.

## 1.16.0 — 2026-09-25 — Unidades (g, ml, un) e características dos ingredientes

- **Unidade de medida por ingrediente: gramas (por omissão), mililitros ou unidades.** Serve para bebidas e
  líquidos (ml) e para ovos, garrafas, sacos… (un). A **embalagem, as linhas de receita, o stock, as compras e o
  custo** ficam nessa unidade (preço por ml, por un…). Escolhe-se no formulário do ingrediente; em "un" pede o
  peso de cada unidade (para o peso e a nutrição).
- **Peso e nutrição sempre em gramas:** ml × densidade (a da nutrição, 1 g/ml se vazia) e un × peso da unidade.
  O peso da receita, a nutrição, o rendimento e a **ordem da lista de ingredientes do rótulo** usam estes pesos.
- **Faturas:** a IA lê a **unidade da embalagem** (g por omissão; ml para líquidos — "Leite 1L" = 1000 ml,
  "33 cl" = 330 ml; un para "cx 12 ovos") e as quantidades em L/cl/dl. Na revisão, o **Comprado** e a
  **Embalagem** têm seletor **g | ml | un**: em "un" contas embalagens (2 × 15 g = 30 g); g ↔ ml convertem-se
  com a densidade. Um ingrediente novo nasce na unidade certa (editável).
- **Características** ("Farinha de trigo" + **T55**, T65, integral, 70% cacau…): a IA separa-as do nome; ao criar
  um ingrediente novo pela fatura há o campo **Característica**. O emparelhamento distingue variedades: T55 nunca
  é ligado a T65. Os nomes mostram-se com a característica ("Farinha de trigo T55").
- Ecrãs com a unidade certa: receita (linhas), lista de ingredientes (preço por kg/L/un), stock, compras,
  mise en place, plano de produção e produtos de compra.
- Migration `1707955211_ingrediente_unidade` (campos `unidade` e `gramas_unidade` em `ingredientes`).
- Testes: secção 9g do `test/security/seguranca.py` (317 verificações, 0 falhas) e `test/unidades_test.dart`.
- Limites: mudar a unidade de um ingrediente já usado **não converte** o que já está guardado (o ecrã avisa);
  "un" só converte com "un" (não há conversão un ↔ g nas faturas; usa o mesmo tipo de unidade). Os valores
  nutricionais continuam por 100 g / 100 ml.

## 1.15.1 — 2026-09-25 — Faturas: quantidade em unidades ou gramas

- **Corrigido:** uma linha "2 un" de "Noz moscada 15 g" entrava como 2 g (e "1 un" de "Cravinho 14 g" como 1 g).
  Agora as unidades multiplicam pelo peso da embalagem: 2 × 15 g = **30 g**; 1 × 14 g = **14 g**.
- No campo **Comprado** da revisão há agora um seletor **g | un**: em "un" escreves o nº de embalagens e o ecrã
  mostra o total em gramas ("= 30 g"); mudar entre g e un converte o número que já escreveste. O que dá entrada
  no stock são sempre as gramas. Sem o peso da embalagem, pede-o.
- A IA passa a ser instruída a dar a quantidade tal como está na fatura (sem multiplicar). As faturas já lidas
  não precisam de ser lidas de novo: a conversão faz-se no ecrã.
- Testes: `test/invoice_ia_parse_test.dart`.

## 1.15.0 — 2026-09-25 — Nutrição própria por produto de compra

- **Cada produto de compra pode ter a sua própria informação nutricional** (energia, lípidos, saturados,
  hidratos, açúcares, fibra, proteína, sal; por 100 g ou 100 ml, com densidade). Ao editar o produto:
  "Nutrição própria do produto" → ligar "Usar estes valores" e preencher, ou **foto do rótulo (IA)**, que preenche
  os valores e acrescenta os alergénios lidos aos do produto.
- **Só conta quando a receita fixa esse produto**, e aí **substitui** a nutrição do ingrediente genérico. Receita
  em "Automático", ou que fixa outro produto (ou um sem nutrição própria), usa a do ingrediente.
- Aplica-se ao cálculo nutricional da receita (e, por cascata, das fichas técnicas e do rótulo). Se o produto
  fixado tem a nutrição própria ligada mas vazia, a receita fica "incompleta" (como um ingrediente sem dados).
- Quando os valores do produto mudam, as receitas que o fixam refazem a nutrição.
- Migration `1707955210_produto_nutricao` (campos `nutri_*`, `nutri_propria`, `nutri_base`, `nutri_densidade`).
- Testes: secção 9f do `test/security/seguranca.py` (313 verificações, 0 falhas) e `test/produto_nutricao_test.dart`.
- Com isto ficam completas as três partes dos produtos de compra: custo, alergénios e nutrição.

## 1.14.0 — 2026-09-25 — Alergénios por produto de compra

- **Cada produto de compra pode ter alergénios a mais** ("Contém também") e **vestígios** ("Pode conter"), ao
  editar o produto no ingrediente. Ex.: o chocolate da marca X "pode conter frutos de casca rija".
- **Só contam quando a receita fixa esse produto.** Juntam-se aos do ingrediente genérico (nunca os
  substituem). Uma receita em "automático", ou que fixa outro produto, leva apenas os alergénios do ingrediente.
- Aplica-se à declaração de alergénios da receita e da ficha técnica (recalculada quando o produto muda ou a
  linha deixa de fixá-lo) e ao **negrito dos alergénios na lista de ingredientes do rótulo** (o plano da ficha
  indica os produtos fixados pelas receitas).
- Na escolha do produto de uma linha de receita aparecem os alergénios do produto, e o "Automático" avisa que
  usa só os do ingrediente.
- Migration `1707955209_produto_alergenios` (campos `alergenios` e `alergenios_tracos` em `ingrediente_produtos`).
- Testes: secção 9e do `test/security/seguranca.py` (307 verificações, 0 falhas).
- Cuidado: em "automático" não conta o alergénio do produto que realmente compraste. Se um produto tem
  alergénios a mais, fixa-o nas receitas que o usam.
- Não incluído: os valores nutricionais continuam a ser os do ingrediente (não há nutrição por produto).

## 1.13.0 — 2026-09-25 — Lista de compras com o produto escolhido nas receitas

- **A lista de compras respeita o produto fixado nas receitas.** Se uma receita fixa "Farinha Sidul 1 kg" e
  outra fica em automático (compra mais recente: "Makro 5 kg"), a lista traz **uma linha por produto**, cada uma
  com a sua embalagem, o nº de embalagens a comprar, o custo estimado e o fornecedor do produto. O nome da
  linha inclui a marca ("Farinha — Sidul").
- O **stock continua a ser um só por ingrediente**: desconta-se do total e o que falta reparte-se pelos
  produtos, em proporção do que cada receita pede.
- Ao gerar de novo a lista de uma produção, as linhas de um produto que já não está fixado desaparecem.
- Migration `1707955208_lista_compras_produto` (campo `lista_compras.produto`, com a regra da mesma empresa).
- Testes: secção 9d do `test/security/seguranca.py` (298 verificações, 0 falhas).
- Ainda por fazer: nutrição/alergénios por produto.

## 1.12.0 — 2026-09-25 — Juntar ingredientes

- **Juntar com outro ingrediente**: no menu (⋮) de cada ingrediente comprado escolhes o ingrediente que fica e
  o outro passa a fazer parte dele. Serve para limpar duplicados ("Açúcar Sidul BCO", "Açúcar Makro") e ficar
  com um ingrediente genérico só ("Açúcar branco").
- O que passa para o ingrediente que fica: linhas de receitas e fichas (o produto fixado numa linha mantém-se),
  stock (soma-se), movimentos, lista de compras, linhas de faturas e os **produtos de compra** (com os nomes de
  fatura já aprendidos). Os alergénios (e vestígios) juntam-se: nunca se perde um aviso. O custo passa a ser o da
  compra mais recente e receitas/fichas refazem o custo.
- O ingrediente juntado vai para a **lixeira** (recuperável). Os ingredientes de fabrico próprio não se juntam.
- Endpoint `POST /api/gc_turnkey/ingredientes/juntar` (papel Leitura e outras empresas recusados).
- Testes: secção 9c do `test/security/seguranca.py` (289 verificações, 0 falhas).
- Ainda por fazer: nutrição/alergénios por produto e usar o produto fixado na lista de compras.

## 1.11.0 — 2026-09-25 — Escolher o produto de compra nas receitas

- **Cada linha de receita pode fixar um produto** do ingrediente genérico (ex.: "Açúcar branco" → "Sidul 1 kg").
  Sem produto fixado ("automático") a linha usa o custo do genérico, isto é, a compra mais recente.
- Na receita, o ícone do alfinete nas linhas com mais de um produto abre a escolha: mostra marca, embalagem,
  €/kg, data da compra e fornecedor, e marca o mais recente. Ao **adicionar** um ingrediente com vários
  produtos, pergunta logo qual usar (cancelar deixa em automático).
- **Custo:** a linha com produto fixado usa o preço/embalagem desse produto. Quando o preço do produto muda,
  as receitas que o fixam refazem o custo (mesmo que o do genérico não mude); apagar o produto devolve a
  linha ao custo do genérico. Um produto de outro ingrediente é ignorado. Duplicar uma receita mantém o produto.
- Migration `1707955207_receita_linha_produto` (campo `itens_receita.produto`, com a regra da mesma empresa).
- Testes: secção 9b do `test/security/seguranca.py` e `test/recipe_item_produto_test.dart`.
- Ainda não usa o produto fixado: a lista de compras (embalagens a comprar) e a nutrição/alergénios por produto.

## 1.10.1 — 2026-09-25 — Limpeza e insumos: anexar já na criação e apagar na lista

- **Anexar documentos logo ao criar** o produto: escolhes a FDS (PDF ou imagem) antes de guardar e ela segue
  ao guardar. Se algum ficheiro falhar, o produto fica guardado e o documento fica na lista "Por enviar" para
  tentar de novo.
- **Apagar produtos** diretamente na lista (ícone do caixote, com confirmação), além do botão Apagar da ficha.

## 1.10.0 — 2026-09-25 — Limpeza e insumos, com fichas de segurança

- **Nova página "Limpeza e insumos"** (chave `consumiveis`, entra na grelha do Início e nas permissões por
  página): produtos de limpeza, desinfeção, higiene e outros insumos, com categoria, marca, fornecedor,
  embalagem, preço e notas de uso.
- **Documentos por produto** (PDF ou imagem, até 20 MB): ficha de dados de segurança (FDS), ficha técnica,
  certificados e outros, cada um com título, versão e data. Os ficheiros são **protegidos** (só abrem com sessão
  e token de curta duração, como as faturas) e ficam nos backups.
- **Estado da FDS** em cada produto: "FDS ok", "Falta FDS" (exige e não tem), "FDS antiga" (a mais recente tem
  mais de 3 anos: aviso para confirmar se há revisão nova) e "Sem FDS" (não exige). Filtro "A precisar de FDS"
  e botão para copiar o registo de todos os produtos (CSV) para a fiscalização.
- **Faturas:** a IA distingue ingredientes de limpeza/insumos (`tipo_item`, `categoria_consumivel`). Na revisão
  cada linha tem "Ingrediente | Limpeza / insumo"; a linha liga-se a um produto existente (nome de fatura já
  aprendido ou semelhança) ou cria um novo (categoria sugerida). Mostra logo o estado da FDS e os documentos já
  anexados. O preço, a marca, o fornecedor e o nome da fatura ficam no produto (fatura mais antiga não muda o
  preço). No fim, lista os produtos a que **falta a FDS**, com atalho para a anexar.
- Migration `1707955206_consumiveis` (coleções `consumiveis` e `consumivel_documentos`; `faturas_itens.consumivel`).
- Testes: secção 10 do `test/security/seguranca.py` (isolamento, papéis, ficheiro protegido, HTML recusado,
  faturas) e testes do estado da FDS e do emparelhamento.
- Não incluído (fica para depois): exportar tudo num único ZIP/PDF, e stock de consumíveis.

## 1.9.0 — 2026-09-25 — Ingredientes genéricos e produtos de compra

- **Ingrediente genérico + produtos de compra.** Uma receita usa "Açúcar branco"; as compras (Sidul 1 kg,
  Makro 5 kg, …) são **produtos** desse ingrediente, cada um com marca, embalagem, preço e data. Açúcar
  branco, amarelo, demerara e mascavado continuam a ser ingredientes diferentes.
- **Custo do genérico = compra mais recente** (recalculado pelo servidor sempre que um produto muda, com a
  cascata de custos habitual). **Um stock por ingrediente genérico.**
- Ficha do ingrediente: secção **Produtos de compra** (adicionar/editar/apagar); o preço e a embalagem do
  ingrediente passam a ser só de leitura quando há produtos.
- **Faturas:** a IA propõe o **nome genérico** e a **marca** de cada linha ("Cravinho moído Margão pac 14gr" →
  "Cravinho em pó" / Margão). O emparelhamento usa, por ordem: nome de fatura já aprendido, nome genérico da
  IA, semelhança de palavras. O preço vai para o **produto** (cria-se um se a marca/embalagem for nova) e o
  nome da fatura é **aprendido** para a vez seguinte. Se o genérico não existe, cria-se na revisão (nome
  sugerido pela IA, editável). Fatura mais antiga que a compra registada não mexe no custo.
- Migration `1707955205_ingrediente_produtos` (cria os produtos a partir dos ingredientes comprados
  existentes, sem alterar custos).
- Testes: secção 9 do `test/security/seguranca.py` e testes do emparelhamento.
- Ainda por fazer (próxima versão): escolher o produto de cada linha de receita, ferramenta "juntar
  ingredientes" e nutrição/alergénios por produto.

## 1.8.0 — 2026-09-25 — Faturas: vários documentos por PDF e IA mais robusta

- **Um PDF com várias faturas** (fornecedores diferentes, ou o mesmo com datas/números diferentes) é dividido:
  a IA indica as páginas de cada documento e o servidor **corta o PDF** (com o `qpdf`, já incluído na imagem
  Docker) e cria **uma fatura por documento, cada uma com o seu ficheiro** (ex.: 8 páginas → págs. 1–2, 3–4 e
  5–8). Cada fatura passa pela deteção de duplicados. Se as páginas indicadas não fizerem sentido, ou não for
  PDF, ficam todas com o ficheiro inteiro e um aviso "confere as páginas".
- **Fornecedor opcional** ao carregar: a IA lê-o da fatura.
- **Gemini mais robusto:** quando a Google responde "muita procura" (429/500/503/504) repete 3 vezes (pausas
  de 3 s e 8 s) e passa a modelos de reserva (`GC_TURNKEY_AI_MODEL_FALLBACK`, por omissão
  `gemini-3.5-flash,gemini-3.5-flash-lite`); modelos retirados (404) são saltados; mensagem clara em português.
- Ecrã de erro da fatura com **"Tentar de novo"** (sem ter de apagar e voltar a enviar).
- Variáveis novas (opcionais): `GC_TURNKEY_AI_MODEL_FALLBACK`, `GC_TURNKEY_AI_ESPERAS`.
- Testes: `test/security/seguranca.py` passa a incluir um Gemini e um `qpdf` falsos (retentativas, reserva,
  divisão em 3 ficheiros, mesmo fornecedor com datas diferentes, páginas sobrepostas).

## 1.7.0 — 2026-09-25 — Renomeada para gc_turnkey

A aplicação passa a chamar-se **gc_turnkey** e deixa de ter o nome de uma empresa: a Gookie Cookies
é só mais uma empresa (utilizadora) da aplicação.

- Nome da app: título do browser, login, manifest, pacote Dart (`gc_turnkey`), classe `GcTurnkeyApp`,
  ids nativos (`com.gcturnkey.app`), nome da aplicação no PocketBase.
- **API:** as rotas passam de `/api/turnkey/…` para `/api/gc_turnkey/…`.
- **Variáveis de ambiente:** `TURNKEY_*` e `GOOKIE_*` passam a `GC_TURNKEY_*` (ex.: `GC_TURNKEY_ENC_KEY`,
  `GC_TURNKEY_DEV`, `GC_TURNKEY_AI_PROVIDER`). O `gc_turnkey.sh` migra o `.env` sozinho.
- **Servidor:** contentor/imagem/projeto `gc_turnkey`, script `gc_turnkey.sh`, pasta `/opt/gc_turnkey`,
  unidades `gc_turnkey-backup.*`, remoto rclone `gc_turnkey-crypt`, pacote `gc_turnkey-servidor-<versão>.tar.gz`.
  A instalação antiga (`gookie`) é removida pelo `atualizar` (os dados em `data/` ficam).
- **Páginas neutras:** "Produtos Gookie" passa a **Produtos** (rota `/produtos`); "produto/ingrediente Gookie"
  passa a "produto/ingrediente de fabrico próprio". Removido o critério `marca ~ 'Gookie'` do relink de espelhos.
- Como atualizar um servidor já instalado: `docs/SERVIDOR_LINUX.md`, secção "Atualizar da 1.6.x".

## 1.6.1 — 2026-09-25 — Servidor Linux (Docker)

O servidor de produção passa a ser um **Mini PC Debian com Docker** (e, mais tarde, uma máquina Linux
na nuvem), em vez de Windows.

- `deploy/`: `Dockerfile` (PocketBase 0.40.4 para amd64/arm64, SHA-256 conferido), `compose.yaml`
  (contentor `gookie`, só em 127.0.0.1, porta escolhida livre, `restart: unless-stopped`, healthcheck),
  `gookie.sh` (`instalar`, `superutilizador`, `estado`, `logs`, `backup-agora`, `restaurar`, `atualizar`).
- Acesso por **Tailscale** (`tailscale serve`); guia `docs/SERVIDOR_LINUX.md` (inclui mudar para a nuvem).
- Backups em Linux: `deploy/backup/*.sh` (rclone cifrado → Google Drive, timer systemd, USB com LUKS,
  teste de restauro em contentor).
- `scripts/empacotar-producao.ps1` cria `dist/gookie-servidor-<versão>.tar.gz` (LF nos scripts).
- Removidos os scripts de servidor Windows (`serve-producao.ps1`, `instalar-arranque.ps1`, `pb/backup/*.ps1`)
  e `docs/MINI_PC.md`; o `pb/serve.ps1` continua a servir o desenvolvimento no Windows.

## 1.6.0 — 2026-09-25 — Primeira versão para produção

Tudo o que entrou desde a 1.5.0, pronto para o Mini PC.

- **Navegação e permissões:** rodapé e grelha configuráveis, permissões por página e por
  nível (só o proprietário grava), cores e páginas escondidas por utilizador; seta de voltar
  em todas as páginas.
- **Produzir / Mise en place** com os **produtos finais** (fichas técnicas) e "produzir primeiro"
  (massa, recheios, coberturas).
- **Ingredientes:** informação nutricional na criação (manual, tabela INSA, foto lida por IA).
  **Receitas:** procedimento e imagens. **Fichas:** formato de cookie, CMV esperado e real,
  quebra do preço esperado vs real. Corrigido o ecrã vermelho ao deslizar para apagar.
- **Produtos Gookie:** declaração nutricional, lista de ingredientes completa e resumida
  (alergénios destacados, sem repetir quando já estão no nome), conservação por seleção.
- **Etiquetas 50 × 80 mm** (térmica): tamanho configurável com o mínimo medido, datas
  impressas ou em branco, lote opcional, ℮ opcional, produtor; definições guardadas por
  produto. **Falta confirmar a rotulagem com a ASAE** (`docs/ROTULAGEM_LEGAL.md`).
- **Segurança** (`docs/SEGURANCA.md`, `test/security/`): registo público já não escolhe
  empresa/papel (crítico), relações só dentro da mesma empresa, admin não rebaixa
  proprietários, faturas com ficheiro protegido, XSS no talão corrigido, limite de tentativas
  de login, **aprovação manual de novos registos**, **tokens de integrações cifrados por
  empresa** (Vendus) com chave-mestra `TURNKEY_ENC_KEY`.
- **PocketBase 0.40.4** (antes 0.35.0).
- **Backups:** backup noturno do PocketBase + cópia cifrada para o Google Drive + USB
  (`pb/backup/`).
- **Instalação no Mini PC:** `docs/MINI_PC.md`, `scripts/empacotar-producao.ps1` (zip com a app
  web + servidor), `pb/serve-producao.ps1`, `pb/instalar-arranque.ps1`. A app web passa a
  ser servida pelo próprio PocketBase (`--dart-define=PB_URL=origin`).
- Migrations novas: `1707523200` … `1707955204` (50 no total).

## 1.5.0 — 2026-09-08 — Fase 5: faturas com IA

Recolha de faturas de compra e listas de preços; a IA lê as linhas e a pessoa
confirma antes de aplicar aos ingredientes e ao inventário.

- **Nova fatura** por foto (telemóvel) ou **PDF**; tipo *Fatura* ou *Lista de preços*.
- **Análise por IA** com fornecedor selecionável por variável de ambiente
  (`TURNKEY_AI_PROVIDER`): **Google Gemini** por omissão (plano gratuito) ou
  **Anthropic Claude**. A chave vive só no servidor (`pb/hooks/ai.js`). Para
  adicionar outro fornecedor: uma função + um ramo no `switch`.
- **Ecrã de revisão** linha-a-linha: emparelhamento automático com o ingrediente
  pelo nome mais parecido, **criar ingrediente novo** ou **renomear um existente**
  para o nome da fatura (propaga a todas as receitas e fichas), ação por linha
  (Preço / Stock / Preço + Stock / Ignorar).
- **Aplicar**: atualiza preços (dispara a cascata de custos) e dá entrada no
  inventário (motivo *Compra*). O **preço só muda se a fatura for igual ou mais
  recente** do que a última atualização de preço do ingrediente — uma fatura
  antiga não estraga um preço mais recente (a entrada de stock é feita à mesma).
- **Fatura única**: recusa duplicados (mesmo fornecedor + número, ou fornecedor
  + data + total) — fica em *Erro* com "Abrir a original" / "Apagar".
- Ficheiro guardado como **`FT-NOMEFORNECEDOR-DDMMAAAA`** (data da fatura);
  `GET /api/turnkey/faturas/export` devolve o nome canónico em `nomeFicheiro`
  (base para a exportação para a contabilidade).
- Apagar fatura na lista (toque longo). Ajuda e checklist de testes atualizados.
- Schema: coleções `faturas` e `faturas_itens`
  (migração `1705968000_faturas.js`). Hooks: `faturas.pb.js`, `ai.js`.

> Requer no servidor: `TURNKEY_AI_PROVIDER` + a chave do fornecedor ativo
> (`GEMINI_API_KEY` ou `ANTHROPIC_API_KEY`). Ver `pb/DEPLOY.md`.

## 1.4.0 — Fase 4: design e personalização

- Tema por empresa (claro/escuro/automático) + cor da app + logótipo.
- Barra de navegação inferior fixa em todas as páginas + ecrã inicial tipo painel.
- Botão de ajuda `?` e "sugestão de melhoria" em todas as páginas.
- Página **Mise en place** (produzir agora, sem agendar): checklist, procedimentos
  e imagens, produtos intermédios, e registo na agenda/inventário/compras no fim.
- Relatório de produção com mise en place **por receita**.
- Produtos de fabrico próprio entram em produção (não na lista de compras).

## 1.3.0 — Fase 3: agenda e produção

- Navegar para a receita a partir do plano de produção.
- Receitas com **procedimento** passo-a-passo + **imagens**.
- Lista de compras por **embalagem** (compra sacos inteiros, mostra a necessidade
  exata) e com unidades automáticas (g / kg).
- **Produzir** como ponto de entrada da agenda (carrinho): várias receitas, kg de
  massa, formato de cookie, recheio, prioridade e hora limite.
- **Formatos de cookie** configuráveis em Configurações.
- Escala por percentagem: pedir X kg dá ingredientes que somam exatamente X kg.
- Fichas técnicas ligadas a formato → stock de produto acabado ao concluir.

## 1.2.0 — Fase 2: inventário e produções

- Inventário (ingredientes em g, produtos em unidades, itens livres) e movimentos.
- Produções: plano, lista de compras a partir do plano, concluir (baixa/entrada).

## 1.1.0 — Fase 1: custos, receitas e fichas técnicas

- Ingredientes, receitas (com sub-receitas), fichas técnicas.
- Cascata de custos automática ao mudar preços.
- Multi-empresa, papéis (owner/admin/editor/viewer), equipa.
