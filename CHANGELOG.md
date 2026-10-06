# Changelog — turnkey_app

Versões da app (Flutter) + schema/hooks do PocketBase. Datas em AAAA-MM-DD.

## 1.94.0 — 2026-10-06 — Notas da equipa

Notas da equipa (Pessoas → Notas) e novos cartões no Início.

- **Notas**: um quadro partilhado para **recados**, **ocorrências** (avarias, reclamações, acidentes) e **lembretes**. Escreve, **fixa** no topo, **arquiva** quando está tratada (ficam em "Arquivadas" e podes voltar a abri-las), procura por texto, filtra por tipo.
- **Lembretes com dia**: a partir do dia escolhido aparece no Início o cartão **"Notas para hoje"**, até arquivares a nota.
- **Quem pode o quê**: toda a equipa (menos a Leitura) vê as notas e pode fixá-las/arquivá-las; só quem escreveu (ou a administração) altera o texto ou apaga.
- **Início**: novo cartão **"Férias por aprovar"** para o proprietário/administrador (só aparece se houver pedidos).
- Servidor: migration `1791050000_anotacoes` (coleção `anotacoes`). Sem endpoints novos.
- Testes: ordenação, filtros, lembretes, "há quanto tempo"; 18 verificações de segurança (autor, empresa, Leitura sem acesso, colega só fixa/arquiva, texto longo).

## 1.93.0 — 2026-10-06 — Mapa de férias

Mapa de férias e ausências (Pessoas → Férias).

- **Pedir férias**: escolhes as datas, a app calcula os **dias úteis** (segunda a sexta, sem feriados nacionais — a Páscoa e os feriados móveis estão calculados) e o pedido fica "Por aprovar" até o proprietário/administrador **aprovar ou recusar**. Podes apagar um pedido teu que ainda não foi decidido. A app avisa se as datas se sobrepõem a outra ausência da mesma pessoa.
- **Saldo**: direito (22 dias úteis por omissão), gozados, pedidos pendentes e quantos restam, por ano. A administração muda o direito de cada pessoa em **Direito a férias** (por exemplo, no ano de entrada).
- **Mapa do mês**: uma linha por pessoa e um quadrado por dia — verde = férias, verde claro = por aprovar, laranja = baixa, vermelho = falta; fins de semana e feriados mais escuros. Rola na horizontal.
- **Quem vê o quê**: a equipa vê as **férias aprovadas** dos colegas; **baixas, faltas e pedidos** só os vê a própria pessoa e a administração (dados pessoais/de saúde).
- **Administração**: "Registar férias / ausência" para qualquer pessoa (férias, baixa, falta, outro; com "Aprovar já"), lista **Por aprovar** com Aprovar/Recusar, e **Imprimir o mapa** de férias do ano (PDF, com o aviso de que deve ficar afixado de 15 de abril a 31 de outubro).
- Servidor: migration `1791040000_ferias` (coleções `ferias` e `ferias_direito`). Sem endpoints novos.
- Testes: Páscoa e feriados, dias úteis (fins de semana, feriados, mudança de ano), saldo, sobreposições, mapa em HTML com escape; 24 verificações de segurança novas (pedidos só para si, não se auto-aprovam, empresa, privacidade das baixas, direito a férias).

## 1.92.0 — 2026-10-06 — Registo de ponto

Registo de ponto: entrada, pausa e saída, na app e no quiosque.

- **Nova página "Pessoas"** (Início → Pessoas, ou no rodapé se a escolheres) com a secção **Ponto**. Vem escondida para o nível Leitura; o proprietário/administrador pode mudar as permissões em Configurações → Navegação e permissões.
- **O meu ponto**: botões Entrada → Início da pausa / Saída → Fim da pausa… só aparece o que faz sentido a seguir.
- **No quiosque**: depois de encostar o cartão (ou escolher o nome) aparece o cartão **Ponto** por cima das tarefas, com os botões Entrada / Pausa / Saída e a hora da última marcação. **Funciona sem ligação**: fica guardado no aparelho (com a hora real) e segue sozinho quando a ligação voltar, como as tarefas.
- **Quem está a trabalhar agora** e, por mês, as **horas de cada pessoa** (descontada a pausa), com os dias e avisos: *Falta a saída* (jornada com mais de 16 horas ou de um dia anterior: não conta até corrigir), *Pausa sem fim*, saída ou fim de pausa sem entrada. Jornadas que passam da meia-noite contam para o dia da entrada.
- **Correções** (proprietário/administrador): toca numa pessoa → dia → marcação para mudar a hora/tipo ou apagar, com motivo; a marcação fica assinalada "corrigida (era 08:03)". **Marcação manual** para quando alguém se esqueceu.
- **Copiar a folha do mês (CSV)** para uma folha de cálculo ou para a contabilista.
- **Privacidade**: o administrador lê todas as marcações; cada pessoa só lê as suas; quem marca no quiosque não consegue ler as dos outros (o quiosque só sabe qual foi a última marcação de cada um). A app regista as horas mas não é um sistema certificado de assiduidade.
- Servidor: migration `1791030000_ponto` (coleção `ponto_registos`) e `GET /api/gc_turnkey/ponto/estado`. Nova regra: os registos do quiosque já aceitam ponto na mesma fila de envio.
- Testes: cálculo das jornadas (pausas, meia-noite, esquecimentos, fora de ordem), totais e CSV, fila e estado do ponto sem ligação; 17 verificações de segurança novas (papéis, empresa, privacidade, correções).

## 1.91.0 — 2026-10-06 — Quantos assar: hoje e dias de trabalho

"Quantos assar" começa em **hoje** e respeita os dias de trabalho.

- **Hoje** é agora a primeira opção (antes só havia amanhã e os dias seguintes). Para hoje a app conta o que **já se vendeu hoje** e o stock que ainda há: só mostra o que falta assar para o resto do dia.
- **Dias de trabalho** (novo): em **Configurações → Dias de trabalho** escolhes os dias da semana em que trabalham (seg a dom; tem de haver pelo menos um) e guardas. Os dias de folga **deixam de aparecer** no "Quantos assar" e nunca recebem previsão; a página diz quais são os dias de trabalho.
- Se hoje for dia de folga, a página abre no próximo dia de trabalho. O histórico continua a ignorar os dias em que a loja não vendeu nada.
- Servidor: migration `1791020000_dias_trabalho` (campo `dias_trabalho` nas configurações da empresa; vazio = todos os dias). Sem endpoints novos.
- Testes: leitura/escrita e resumo dos dias, próximo dia de trabalho, configuração, previsão de folga/hoje.

## 1.90.2 — 2026-10-06 — Capacidade do forno mais clara

Capacidade do forno mais clara (Rentabilidade e Quantos assar).

- Na revisão com os dados reais, a média das fornadas era só de 2 unidades (fornadas de teste/parciais), o que dava "≈ 11 fornadas" e lucros por hora de forno enganadores.
- **Quantos assar** ganhou o **lápis** ao lado do total: escreves quantas unidades cabem no forno (fica guardado neste aparelho) e o número de fornadas passa a usar esse valor. Se a média das fornadas for muito baixa (menos de 6), a app avisa.
- **Rentabilidade** usa o mesmo valor (um só sítio para o definir); o campo passou a chamar-se "Por fornada" (o nome antigo aparecia cortado) e avisa quando a média é muito baixa.
- **Rentabilidade** diz agora quantos produtos não têm tempo de assadura na ficha (aparecem com "— /h").
- Sem alterações no servidor.

## 1.90.1 — 2026-10-06 — Ficha técnica: janela de edição com rolagem

Correção: a janela "Editar ficha" / "Nova ficha técnica" passa a rolar e o botão Guardar fica sempre visível.

- Com os campos novos (temperatura do forno, formato, característica…) a janela ficou mais alta do que o ecrã e não dava para chegar ao botão **Guardar**. Agora os campos rolam dentro da janela e o botão **Guardar/Criar** fica fixo por baixo, mesmo em ecrãs baixos.
- Sem alterações no servidor.

## 1.90.0 — 2026-10-06 — Quiosque offline

Quiosque offline: se o Wi-Fi cair, as tarefas continuam a poder ser registadas.

- **Registos guardados no aparelho**: sem ligação ao servidor, cada toque no quiosque fica guardado neste aparelho (com a hora real em que foi feito) e a tarefa passa a "Feito ✓". No topo aparece **"N por enviar"**.
- **Envio automático**: de 20 em 20 segundos a app tenta enviar o que ficou à espera (ou toca no aviso para tentar já). Cada registo leva um id próprio, por isso, se um envio chegou mas a resposta se perdeu, **nada se duplica**. Mantém a hora original.
- **Lista de tarefas e de pessoas em memória**: a última lista vista (tarefas, estados e pessoas com o número do cartão) é guardada, por isso o ecrã do cartão e o das tarefas abrem mesmo sem ligação, com um aviso "Sem ligação ao servidor — a mostrar a última lista". O cartão NFC continua a identificar a pessoa.
- Registos que o servidor recusa (ex.: a tarefa foi apagada) são postos de lado depois de 5 tentativas e a app avisa; ficam guardados no aparelho.
- Limite: a página tem de estar aberta quando o Wi-Fi cai (recarregá-la sem ligação não funciona).
- Sem alterações no servidor. Testes: fila, deteção de "sem ligação" (o PocketBase marca falhas de rede como "abort"), cache, estados com pendentes; teste de segurança do reenvio com id próprio. Verificado a sério no browser: servidor desligado → toque guardado → servidor ligado → enviado.

## 1.89.0 — 2026-10-06 — Quantos assar amanhã

"Quantos assar amanhã": a previsão, sabor a sabor, do que convém ter pronto.

- **Produção → Quantos assar** (nova secção): escolhes o dia (amanhã ou um dos 6 seguintes) e a app diz, por sabor, quantas unidades ter prontas, o total e as **fornadas** (pela média das tuas fornadas dos últimos 60 dias). O botão de copiar dá a lista em texto.
- **Como prevê**: olha para as últimas 12 semanas, só os dias **iguais** ao escolhido (as quintas-feiras, por exemplo) em que a loja vendeu — um dia fechado não conta como zero. Para cada sabor testa 4 modelos nos dias já passados (mais peso às últimas semanas, média, mediana, igual à semana passada), mede quanto cada um teria errado e **usa o que erra menos**. Quanto mais histórico, melhor acerta; com pouco histórico usa a média geral do sabor e avisa (ponto vermelho/laranja/verde = confiança).
- **Margem de segurança** = o erro do modelo (para não faltar), que **encolhe** nos sabores que vão para o lixo (5 % ou mais do que se faz, pelo Desperdício da Contagem) e **desaparece** a partir de 15 %.
- **Descontar o que já há em stock** (ligado por defeito): tira o que ainda tens nos locais, pela contagem de fecho de hoje ou a estimativa pelas contas.
- **Ajuste do dia**: −20 %, +20 % ou +50 % (evento) sobe ou desce tudo de uma vez — a app não sabe de feriados, chuva ou encomendas especiais.
- Só lê vendas e registos já existentes: sem alterações no servidor. Testes do cálculo (modelos, erro, escolha do modelo, margem, desperdício, dias fechados, histórico curto).

## 1.88.0 — 2026-10-06 — Tabela de preços para revendedores

Tabela de preços para revendedores, em PDF ou WhatsApp.

- **Contabilidade → Revendedores** (nova secção): a tabela com todos os produtos que têm preço de venda, por categoria — preço por unidade **sem IVA** e **com IVA** (o IVA das vendas das Configurações) e uma coluna por cada degrau de **desconto por quantidade**.
- Como se chega ao preço do revendedor: **desconto %** sobre o preço ao público (sem IVA), ou um **canal** (revendedor/plataforma da ficha técnica): o revendedor paga o que te chega com as taxas do canal tiradas — a mesma conta da Rentabilidade. Tudo arredondado a cêntimos.
- **Desconto por quantidade**: junta degraus ("a partir de 24 un −5 %"); aplicam-se por produto. Já vêm 24+ (−5 %) e 48+ (−10 %) para começar.
- **Copiar** (texto simples), **WhatsApp** (abre a conversa com a tabela; o texto fica também copiado) e **PDF** (impressão do navegador → "Guardar como PDF", com o nome da empresa e a data). Desmarca os produtos que não queres mostrar.
- O desconto, o canal, os degraus e os produtos escolhidos ficam guardados neste aparelho. Sem alterações no servidor.
- Testes do cálculo (desconto, IVA no fim, degraus, canal, ordem, texto, escape de HTML, sem IVA definido).

## 1.87.0 — 2026-10-06 — Rentabilidade por sabor e canal

Rentabilidade por sabor e canal: que produtos deixam mais lucro.

- **Contabilidade → Rentabilidade** (nova secção): ranking dos produtos com custo e preço de venda, com o lucro **por unidade**, a **margem %** e o **lucro por hora de forno**. Escolhes a **Loja física** ou um **canal** (plataforma/revendedor da ficha técnica) e a lista refaz-se com as taxas desse canal em cascata.
- O lucro é **sem IVA**, ao preço de venda que o produto já tem, depois das taxas do canal e das percentagens de custo das Configurações (salário, aluguel…). Ordena por lucro por unidade, por hora de forno ou por margem.
- **Lucro por hora de forno** = lucro por unidade × unidades por fornada × 60 ÷ tempo de assadura. As unidades por fornada vêm da média das fornadas dos últimos 60 dias; podes escrever outro valor (fica guardado neste aparelho).
- Barra verde (lucro) ou vermelha (prejuízo) em cada produto; os produtos sem custo ou sem preço de venda são contados à parte. Sem alterações no servidor.
- Testes do cálculo (loja, canal com taxas, ordem, prejuízo, sem tempo de forno, média das fornadas).

## 1.86.0 — 2026-10-06 — Rastreabilidade por lote com QR

Rastreabilidade por lote (Reg. (CE) 178/2002, art. 18.º): sabes de que lotes de ingredientes veio cada lote que produziste.

- **Produção → Lotes** (nova secção): lista dos lotes de produção e **"Novo lote"**: escolhes o produto, a data, as unidades (a validade vem
  do prazo da ficha) e, para **cada ingrediente da ficha**, o lote que usaste — os que vencem primeiro vêm à frente — ou **"＋ Novo
  lote…"** (código da embalagem do fornecedor, validade, fornecedor) ou "Sem lote". O lote ganha um código (`261006-ALB-1`: data,
  produto e nº do dia).
- **Página do lote** (`/lote/…`): produto, datas, quantidade, responsável e a lista de ingredientes com lote, fornecedor e validade;
  aviso nos ingredientes sem lote. A **lupa** de cada ingrediente mostra **todos os lotes de produção em que esse lote do fornecedor
  entrou** — a lista do que retirar se houver um alerta.
- **Etiqueta com QR**: o botão abre a etiqueta já com o lote, a data de fabrico do lote e um **QR** que abre a página do lote no
  telemóvel (precisa de sessão). **Ficha** imprime/guarda em PDF a folha de rastreabilidade.
- Servidor: coleções `lotes_ingrediente` e `lotes_producao` (migration `1791010000_lotes`; cópia dos ingredientes usados dentro do lote,
  só owner/admin apagam lotes de produção) e `GET /api/gc_turnkey/lotes/ingredientes?ficha=` (ingredientes da ficha, incluindo os das
  sub-receitas, com os lotes conhecidos). Nova dependência `qr` (gerador de QR).
- 16 testes de segurança novos (papéis, outra empresa, códigos únicos, sem sessão) e testes do código do lote, do QR, da etiqueta e do
  escape de texto (XSS) na ficha impressa.

## 1.85.0 — 2026-10-05 — Avisos e resumo diário por Telegram e email

Recebes todos os dias um resumo do que pede atenção, por **Telegram** e/ou **email**.

- **Configurações → Avisos e resumo diário** (administradores): ligar o envio diário, escolher a **hora** (Lisboa), o **que incluir**
  (HACCP por fazer, stock baixo, pagamentos nos próximos 7 dias, faturas por rever, preços que subiram nas últimas 24 h) e os canais.
- **Telegram** (grátis): crias um bot com o @BotFather, colas o token (guardado **cifrado**, nunca volta a aparecer), envias /start ao bot
  e tocas em **"Detetar o meu chat"** — escolhes o teu (ou o de um grupo). **Email**: vários endereços; precisa do email do servidor
  configurado no PocketBase (Definições → Mail) — se não estiver, a app explica.
- **"Enviar um teste"** manda já o resumo e mostra o resultado de cada canal (e o texto). Sem canais mostra só a pré-visualização.
- **WhatsApp**: o código está pronto mas **desligado** (a API da Meta é paga) — só se ativa no servidor com
  `GC_TURNKEY_WHATSAPP_TOKEN` e `GC_TURNKEY_WHATSAPP_PHONE_ID`; não há nada na app a ativá-lo.
- Servidor: tarefa que corre a cada minuto e envia à hora marcada (recupera até 3 h se o servidor esteve parado; 1 envio por dia),
  `POST /api/gc_turnkey/avisos/testar` e `…/telegram/detetar` (só owner/admin). Nova coleção `avisos_config` (migration
  `1791000000_avisos`); serviço `telegram` nas integrações. Os erros nunca revelam o token.
- 18 testes de segurança novos (com um Telegram falso) e testes da configuração.

## 1.84.0 — 2026-10-05 — Estado dos backups

Vês se os backups estão a correr, sem abrir o servidor.

- **Configurações → Estado dos backups** (administradores): o **último backup automático** (há quanto tempo e tamanho), quantos há
  guardados e o estado da **cópia para fora do servidor** (Google Drive/B2, cifrada): *ok*, *FALHOU* ou *sem informação* (o script
  nunca correu). Fica a vermelho com as frases do que está mal.
- **Início**: cartão **"Backup com problema"** quando o último backup tem mais de **30 h**, não há nenhum, ou a cópia externa
  falhou/está atrasada (só para administradores).
- Servidor: `GET /api/gc_turnkey/backups/estado` (só owner/admin; não devolve caminhos). Lê os `.zip` de `pb_data/backups`
  e o ficheiro `pb_data/backup_externo.json`, que o `deploy/backup/copia-externa.sh` passa a escrever (ok/falha + hora +
  mensagem) a cada execução. **O script só escreve o estado depois de o publicares no servidor** (`deploy/backup/` vai no pacote;
  copia-o para o sítio onde o agendamento o chama, se o tiveres fora da pasta do pacote).
- 8 testes de segurança novos (sem sessão, papéis, formato, sem caminhos) e 7 testes da lógica de "em dia / problema".
- Sem alterações à base de dados.

## 1.83.0 — 2026-10-05 — Aprovações de contas dentro da app

Aprovas contas novas dentro da app, sem abrir o painel `/_/` do PocketBase.

- **Configurações → Aprovações de contas** (só o *operador da plataforma*): lista quem se registou e espera, com **Aprovar** e
  **Recusar** (recusar apaga o pedido; com confirmação). Mostra a data do pedido.
- **Início**: cartão **"Contas por aprovar"** quando há alguém à espera.
- **Quem é o operador**: os emails de `GC_TURNKEY_OPERADORES` no `.env` do servidor (separados por vírgula) ou, se a variável não
  existir, o **proprietário aprovado mais antigo** (tu). Os outros utilizadores recebem "não és operador" e nenhum dado.
- Servidor: `GET /api/gc_turnkey/aprovacoes`, `POST …/{id}/aprovar` e `…/{id}/recusar` — exigem sessão e operador; recusar só funciona
  em contas ainda por aprovar. 21 testes de segurança novos (sem sessão, papéis, por aprovar, inexistente…).
- Sem alterações à base de dados.

## 1.82.0 — 2026-10-05 — Alerta de variação de preço

Quando o preço de um ingrediente sobe (por exemplo ao aplicar uma fatura), a app avisa e mostra o que fica afetado.

- **Servidor**: sempre que o preço de um ingrediente muda ≥ 1 %, regista a **variação** (preço por kg antes/depois, % ) e as
  **fichas técnicas cujo custo mudou** (custo antes/depois e preço de venda). Fica ~4 meses. Só o servidor escreve (coleção
  `variacoes_preco`, migration `1790990000`).
- **Inventário → Preços** (nova secção): lista as variações — filtros Subidas / Descidas / Todas — e, ao tocar numa, as **fichas
  afetadas com o custo e a margem antes → depois** (margem sobre o preço sem IVA). "Marcar como vistas" limpa o aviso neste aparelho.
- **Início**: cartão "Preços subiram" (com os ingredientes e %) quando há subidas acima do limiar por ver.
- **Ao aplicar uma fatura**: aviso "N preço(s) subiram: Farinha +20 % …" com o botão **Ver impacto**.
- **Limiar configurável** em Configurações → Percentuais de custo → "Avisar quando um preço sobe mais de" (5 % por omissão).
- Testes novos.

## 1.81.0 — 2026-10-05 — Temperatura do forno em cada produto

Cada produto passa a ter a **temperatura do forno** além do tempo de assadura.

- **Ficha técnica → Editar → "Temperatura do forno (°C)"** (50 a 400 °C), junto ao tempo de assadura.
- Aparece **junto com o tempo**: "Assar a 170 °C durante 11 min" na ficha, na **Mise en place / Produzir**, na **Agenda** (detalhe do
  plano) e nos botões de **assar da Contagem** ("170 °C · 11 min").
- **Aviso na Contagem**: se pões ao forno, ao mesmo tempo, sabores com temperaturas diferentes, aparece "Atenção: temperaturas
  diferentes no mesmo forno (165 °C, 180 °C)".
- Nova coluna `temperatura_forno_c` nas fichas (migration `1790980000_temperatura_forno`); fichas existentes ficam sem
  temperatura até a preencheres. Testes novos.

## 1.80.0 — 2026-10-06 — Segurança do servidor e carregamento mais rápido

Revisão de segurança e de agilidade (ver `docs/SEGURANCA.md`, secção "Revisão de 2026-10-06"):

- **Cabeçalhos de segurança** na app web (hook novo `pb/hooks/web_cabecalhos.pb.js`): *Content-Security-Policy* restritiva (a
  app só fala com ela própria — mesmo que alguém injetasse código, não o conseguia enviar para fora; sem iframes),
  *Strict-Transport-Security* (atrás de HTTPS, também na API), *Referrer-Policy*, *Permissions-Policy*, *nosniff*.
- **Atualizações apanhadas logo**: os ficheiros da app passam a ir com `Cache-Control: no-cache` + ETag. O navegador confirma
  com o servidor (resposta de 304, sem descarregar) e apanha uma versão nova na hora — acaba o "Atualizar não atualiza".
- **Carregamento ~3× mais leve**: o pacote cria versões comprimidas (`.gz`) dos ficheiros grandes e o servidor serve-as
  (`main.dart.js` 5,0 MB → 1,4 MB). Só afeta o primeiro carregamento/atualizações (depois fica em cache).
- **Contentor com menos privilégios** (`deploy/compose.yaml`): sem capacidades extra e sem escalada de permissões.
- Testes de segurança novos (cabeçalhos da app e da API, HSTS só atrás de HTTPS).
- Sem alterações à base de dados.

## 1.79.0 — 2026-10-06 — Sem "Impostos" nos percentuais; o CMV é teu e a margem é o que sobra

- **"Impostos" saiu** dos Percentuais de custo e da Quebra do preço: o IVA só aparece no fim (preço sem IVA → IVA → preço
  final). O aviso/botão "O IVA está a contar duas vezes" deixou de ser necessário e saiu.
- **O CMV passa a ser um campo teu** (Configurações → Percentuais de custo → "CMV — custo da matéria-prima"). O **preço
  sugerido = custo ÷ CMV**. Os custos (salário, aluguel, serviços, despesas fixas, taxas financeiras) são % do preço sem IVA e
  a **margem de lucro é o que sobra** (100 − CMV − custos), mostrada num cartão ao lado, a verde, ou a vermelho se os custos
  não couberem. Se reduzires custos a margem sobe; se os aumentares desce — o CMV mantém-se.
- **Empresas existentes**: o CMV fica igual ao que já era (a migration `1790970000_cmv_config` calcula-o), por isso os preços
  sugeridos não mudam; o antigo "Impostos" deixa de contar e a margem passa a ser o que sobra. Ajusta o CMV ao que quiseres.
- **Números mágicos** e as **dicas de IA** usavam o "Impostos" como imposto das vendas: passam a usar o **IVA das vendas** (a
  parte de IVA que vem nos totais de venda), e o CMV sobre o total com IVA.
- `CostConfig` deixa de ser gerado (freezed): classe simples com `copyWith`. Testes novos.

## 1.78.0 — 2026-10-06 — O botão "Atualizar" passa a atualizar mesmo

- **Problema**: depois de publicar uma versão nova, o aviso "Há uma versão nova da app" aparecia, mas **"Atualizar" não
  atualizava** no Chrome do computador — a app antiga continuava (só um Ctrl+Shift+R resolvia). O botão limpava a cache da
  app, mas o próprio Chrome guardava o ficheiro antigo na sua cache de rede.
- **Correção**: "Atualizar" limpa a cache da app **e obriga o Chrome a pedir ao servidor os ficheiros novos** (página,
  `main.dart.js`, scripts, versão…) antes de recarregar. Funciona a partir desta versão: na primeira vez que passares para
  a 1.78.0 ainda precisas de **Ctrl+Shift+R** (a app que está aberta é a antiga); a partir daí o botão chega.
- Sem alterações à base de dados.

## 1.77.0 — 2026-10-06 — Receita: barra de topo com espaço para o nome

- **Receita (detalhe)**: a barra tinha 6 ícones (Agendar, Procedimento, Nutrição, Histórico, Editar, Ajuda) e, em telemóvel, o
  nome da receita ficava cortado. Ficam à vista **Agendar produção**, **Editar** e **Ajuda**; **Procedimento e imagens,
  Informação nutricional e Histórico** passam para o menu **⋮**.
- Vistos sem problemas, com dados reais: Receitas (lista e detalhe), Informação do produto da ficha (declaração nutricional,
  ingredientes, alergénios) e Faturas (já com os meses por ordem).
- Sem alterações à base de dados.

## 1.76.0 — 2026-10-06 — Faturas: meses por ordem e com nome

Revisão no servidor (Chrome, dados reais):

- **Faturas**: os grupos de meses vinham pela ordem de criação (setembro, outubro, junho…). Passam a vir por ordem —
  **mais recente primeiro** (ao contrário se ordenas por data crescente) — e com o nome por extenso ("Setembro de 2026" em
  vez de "2026-09").
- Vistos sem problemas, com dados reais: HACCP, Equipa e cartões, Contagem, Vendas, Produção, Contabilidade (custos fixos,
  DRE, relatórios e IVA), Inventário (ingredientes e embalagens), Navegação e a ficha técnica.
- Sem alterações à base de dados.

## 1.75.0 — 2026-10-06 — Quebra do preço: embalagem à parte e IVA só no fim

- **Matéria-prima e Embalagem em linhas separadas**: na Quebra do preço, a *Embalagem* passa a ter a sua linha, logo
  abaixo da *Matéria-prima* e acima do *Salário* (valor e % no esperado e no real). Juntas continuam a dar o CMV.
- **IVA a contar duas vezes**: se os **"Impostos" dos percentuais forem iguais ao IVA das vendas** (ex.: 23 % e 23 %), a
  Quebra mostra um aviso a vermelho — o imposto aparecia dentro da quebra e outra vez no fim. O botão **"Tirar o imposto da
  quebra"** (administradores, com confirmação) põe "Impostos" a 0 %; o IVA fica só no fim. Em Configurações, a nota do
  *IVA das vendas* avisa o mesmo.
- Rubricas a 0 % (ex.: Impostos depois de tirado, Despesas fixas vazias) deixam de aparecer na tabela: menos linhas.
- Atenção: "Impostos" também é usado nos **Números mágicos** e na **Distribuição teórica**; ao pô-lo a 0 % deixam de
  contar esse imposto (se tens outro imposto real, como IRC, deixa só essa percentagem).
- Sem alterações à base de dados. Testes novos.

## 1.74.0 — 2026-10-06 — Preços por canal: plataformas e terceiros com taxas em cascata

Cada canal de venda tem as suas taxas, e na ficha técnica vês o preço a cobrar e o lucro de cada um.

- **Canais ilimitados**: na ficha técnica, **"Preços por canal (plataformas e terceiros)" → "Novo canal"**. Cada canal tem um
  nome e uma lista **ordenada de taxas**; cada taxa tem um nome, uma **% do preço** desse nível e/ou um **€ fixo por venda**
  (ex.: *Plataforma 30%* ; *Plataforma 30% → Revendedor 20% + 0,20 €*). Podes ter quantos canais e quantas taxas quiseres,
  cada canal com os seus valores. Os canais são da empresa: criam-se uma vez e aparecem em todas as fichas. Lápis para editar,
  apagar dentro do editor.
- **Cascata**: a ordem é a pela qual cada taxa tira a sua parte do que o cliente paga (a primeira é a de fora, ex. a
  plataforma; a última é a mais perto de nós, ex. o revendedor); cada % é sobre o valor do seu nível.
- Para cada canal (e para a **Loja física**, sem taxas): **preço sem IVA que mantém o lucro da loja** (preço limpo + taxas),
  **+ IVA no fim = valor a cobrar ao cliente**; cada taxa em €; o que **chega a nós**; o **lucro por unidade** e a margem; e
  uma **barra** com para onde vai o preço (taxas, custo, estrutura, lucro).
- **"E se vendo ao preço da loja?"**: o que chega a nós, o lucro (a vermelho se for prejuízo) e a **taxa máxima que o canal
  aguenta** antes de dar prejuízo — para saberes onde podes negociar taxas ou subir preços.
- Interruptor **"Usa a embalagem para plataformas"**: soma ao custo a *Embalagem para plataformas* da ficha (o preço
  recomendado já a cobre).
- Nova coleção `canais_venda` (migration `1790960000_canais_venda`): protegida por empresa e papel como as restantes.
- Testes novos das contas em cascata (taxas %, fixas, 100%, IVA por último).

## 1.73.0 — 2026-10-06 — IVA por último na ficha técnica + simulador de revenda

O IVA é cobrado em cima do preço limpo (sem IVA), por isso as contas da ficha passam a fazer-se **sobre o preço sem IVA**
e o IVA soma-se no fim. Antes, a quebra do preço, o CMV real e a margem usavam o preço de venda **com** IVA, e davam
margens demasiado optimistas.

- O **"Preço de venda"** da ficha é o preço ao público, **com IVA** (como já era). Na ficha vê-se por baixo o **preço sem
  IVA** e a **margem sobre o preço sem IVA**; o **CMV real** também é sobre o preço sem IVA.
- **Quebra do preço (sem IVA)**: todas as rubricas (matéria-prima, salário, aluguel, margem…) são sobre o preço sem IVA,
  e no fim aparecem **Preço sem IVA → IVA (x%) → Preço final (com IVA)**, no esperado e no real.
- **"Quanto posso cobrar? (revenda)"**, dentro da Quebra do preço: mostra o **preço de equilíbrio sem IVA** (abaixo dele há
  prejuízo) e o **desconto máximo**; escreves (ou tocas em 5/10/15/20 %) um **desconto para o revendedor**, dado no preço
  sem IVA, e vês o **preço sem IVA, o IVA, o valor a cobrar (preço + IVA), o lucro por unidade e a margem**. Avisa quando
  estás abaixo do equilíbrio.
- **Preço sugerido** no cartão da ficha, na lista de fichas e na venda: passa a mostrar-se **com IVA** (para comparar com
  o preço de venda); na quebra aparece sem IVA e com IVA.
- A taxa é a de **Configurações → Percentuais de custo → IVA das vendas** (a mesma do IVA a separar). Sem taxa definida,
  nada muda (as contas ficam como antes) e a Quebra avisa para a definir.
- Sem alterações à base de dados. Testes novos (IVA por último, equilíbrio, lucro).

## 1.72.0 — 2026-10-05 — Ecrãs largos: conteúdo numa coluna centrada

Revisão no Chrome do computador (ligado ao servidor): em ecrã largo as listas, botões e cartões esticavam por ~1500 px
(cartões do Início enormes e vazios, linhas muito afastadas do valor, rodapé com os ícones separados).

- Todo o conteúdo e o **rodapé** ficam agora numa **coluna centrada de, no máximo, 960 px** — como no telemóvel. Em
  telemóvel e tablet estreito nada muda.
- Sem alterações à base de dados.

## 1.71.0 — 2026-10-05 — Receitas: importar dentro do "+"

- Em **Receitas**, o botão **+** passa a oferecer **Nova receita** (à mão) e **Importar receitas (CSV / colar)**: tudo o
  que é criar receitas está no mesmo sítio. O ícone **Lixeira** volta a estar à vista (deixa de ser preciso o menu ⋮).
- Sem alterações à base de dados.

## 1.70.0 — 2026-10-05 — Revisão de interface (2): barras de topo

Continuação da revisão em largura de telemóvel — as barras de topo com ícones a mais escondiam ou cortavam o título:

- **Vendas** (sem título, com 6 ícones): fica só a ordenação; **Análise de vendas, Produtos não identificados,
  Sincronizar com o Vendus, Reimportar histórico e Importar CSV** passam para um menu **⋮**. O botão flutuante
  "Registar venda" já não tapa a última linha da lista.
- **Receitas** (título cortado "Receit…"): ficam Ordenar e **+**; **Importar** e **Lixeira** passam para o menu **⋮**.
- **Fichas Técnicas** (título cortado): o título da barra passa a "Fichas" (a página continua a chamar-se Fichas Técnicas).
- Vistos sem problemas: Compras, Encomendas, Faturas, Produção/Agenda, Quiosque, detalhe da Ficha.
- Sem alterações à base de dados.

## 1.69.0 — 2026-10-05 — Revisão final de interface (telemóvel)

Revisão de alinhamentos e textos nos ecrãs, em largura de telemóvel:

- **Rodapé**: "Contagem diária" partia-se em duas linhas e desalinhava os ícones e o realce. Passa a "Contagem"
  (nome curto só no rodapé; o resto da app mantém o nome completo). Outros nomes longos também têm versão curta se
  forem postos no rodapé: Quiosque, Contas (Contabilidade), Opções (Configurações).
- **Botões de escolha** (Claro / Automático / Escuro, períodos, etc.): margens menores e sem o visto, para o texto
  caber numa só linha ("Automático" partia-se em "Automáti-co"). Vale para toda a app.
- **Início**: o cartão "HACCP por fazer" mostra no máximo 2 linhas de texto (com reticências) em vez de uma lista
  comprida de controlos; o número continua ao lado.
- Sem alterações à base de dados.

## 1.68.0 — 2026-10-05 — Contabilidade: as finanças numa só página

Seis páginas soltas de finanças passam a **uma só**, **Contabilidade**, com secções (toque para mudar):

- **Resumo** (o antigo Painel financeiro: entradas, saídas, lucro), **DRE**, **Custos fixos**, **Equipamentos**,
  **Números mágicos** e **Relatórios e IVA**.
- **Relatórios e IVA** (novo): o período, o **IVA a separar** e, logo abaixo, todos os relatórios no mesmo sítio —
  Relatório geral (Excel/CSV, só administradores), faturas para a contabilista, "O que comprei", Análise de vendas e
  Relatórios HACCP.
- Menos ícones escondidos: os atalhos de Custos fixos para Equipamentos/Números mágicos e do Painel para a DRE
  deixaram de existir (são secções ao lado). O relatório geral saiu do ícone do Painel para "Relatórios e IVA".
- Nas Configurações → Navegação há uma só entrada **Contabilidade** (antes eram quatro: Painel financeiro, Custos
  fixos, Equipamentos, Números mágicos). Os endereços antigos continuam a funcionar e abrem a secção certa.
- O aviso "Pagamentos por vir" do Início segue a permissão de Contabilidade.
- Ajuda: novo tópico "Contabilidade"; textos de Custos fixos e do Painel atualizados.
- Sem alterações à base de dados.

## 1.67.0 — 2026-10-04 — Formatos de cookie e categorias de receita sem páginas próprias

Duas páginas de configuração que não precisavam de existir, porque o que fazem se faz melhor onde se usa:

- **Formato do cookie** (Mini, Recheado, Simples…) escolhe-se na **Ficha técnica → Editar**. Se o formato que
  queres não existe, **"＋ Novo formato…"** cria-o ali mesmo (nome, massa e recheio em gramas) e fica já escolhido.
  O lápis ao lado edita ou **apaga** o formato (recusa se alguma ficha o usa). A página "Formatos de cookie" saiu
  das Configurações.
- **Categoria da receita**: ao criar/editar uma receita, tocas numa categoria, ou **"Nova categoria"** para criar;
  **mantém premido** uma categoria para lhe **mudar o nome** (muda em todas as receitas que a usam). Uma categoria
  **desaparece sozinha quando nenhuma receita a usa**; Massa, Recheio, Cobertura e Outra ficam sempre como sugestão.
  A página "Categorias de receitas" saiu das Configurações.
- **Filtros mais ágeis**: na lista de Receitas e de Fichas, os botões de categoria mostram **quantas há** de cada
  ("Massa (12)"); na lista de Receitas, mantém premido para renomear. Na Ficha, a categoria tem sugestões de
  toque (as já usadas).
- Ficha técnica → Editar: espaçamento corrigido (as notas de ajuda sobrepunham-se à etiqueta do campo seguinte).
- Os endereços antigos (`/opcoes/formatos`, `/opcoes/categorias-receita`) redirecionam.
- Nada foi apagado da base de dados: a coleção `categorias_receita` deixa de ser usada (a categoria é o nome na
  própria receita, como já era).

## 1.66.0 — 2026-10-04 — Relatório HACCP formal, por período e por tipo

- **HACCP → Registos → "Gerar relatório"**: cria o relatório formal de um período — **hoje, 7 dias, este mês, mês
  passado, 90 dias ou ano** — e de um **tipo de controlo** (temperatura, limpeza, pragas, manutenção, outros) ou de
  **todos**. Na aba **Hoje** há o atalho **"Relatório de hoje"**. Abre pronto a imprimir ou guardar em **PDF (A4)**.
- Cada relatório tem **número sequencial por empresa e ano** (`HACCP-2026-0007`), que fica registado na emissão
  (quem, quando, período, tipo, nº de registos e de não conformidades).
- Conteúdo: identificação do **operador/estabelecimento** (a mesma das etiquetas), período, emitido por/quando;
  **resumo** (registos, conformes, não conformidades, por resolver, **cobertura**: feitos face aos esperados);
  **um quadro por controlo** agrupado por tipo (frequência, local, **limite crítico**, mínimo/máximo/média,
  data e hora, valor, conforme, quem registou, ação corretiva); **lista de não conformidades e ações corretivas**;
  **enquadramento legal** (Reg. (CE) n.º 852/2004, Reg. (CE) n.º 178/2002, DL n.º 113/2006); campos de **assinatura**
  (elaborado por / verificado pelo responsável HACCP); **código de integridade** que muda se qualquer registo mudar;
  número do documento e paginação em todas as páginas.
- O relatório é um **registo dos controlos**; a sua aceitação como prova depende do **plano HACCP do estabelecimento**
  (perigos, pontos críticos, limites), que o responsável deve validar. Convém confirmar o modelo com a vossa
  consultora/o vosso técnico de segurança alimentar.
- Equipa e cartões: o botão de juntar pessoas sem conta passa a dizer **"Adicionar pessoa"** (a Equipa continua a
  aparecer sozinha).
- Migration `1790950000_haccp_relatorios.js` (coleção `haccp_relatorios`: não se altera depois de emitida).

## 1.65.0 — 2026-10-04 — Produção numa só página: Produzir, Mise en place e Agenda

Três páginas mostravam o mesmo plano de produção. Passam a **uma só, "Produção"**, com duas secções:

- **Produzir** (antes "Produzir" + "Mise en place"): escolhes o produto e a quantidade e vês **tudo no mesmo
  sítio** — o mise en place (o que produzir primeiro, os ingredientes a pesar com caixas para marcar, o stock
  que há e o "Assar X min"), o **custo por receita** e o procedimento. Depois: **"Produção feita"** (regista agora,
  dá baixa no stock e pode juntar o que faltou à lista de compras) ou **"Agendar"** (para outro dia).
- **Agenda**: as produções planeadas por dia, com quantas estão **por fazer**. O detalhe de cada produção
  continua igual.
- *Todas as páginas* e o rodapé têm **uma só entrada, "Produção"** (saíram "Mise en place" e "Agenda"); o rodapé por
  omissão passa a ser Produção · Contagem diária · Compras · Inventário. No Início: "Produzir agora" e "Produções
  por fazer" levam à secção certa.
- Os endereços antigos (`/mise-en-place`, incluindo `?receita=…`) levam ao Produzir.
- Nada se perdeu: formato para receitas, procedimento e imagens, "Abrir" um intermédio, carrinho de agendar,
  prioridade e hora limite, custo, tempo de assadura.
- A ajuda do Mise en place passou para a do Produzir.

## 1.64.0 — 2026-10-04 — O quiosque mostra a Equipa

- **O quiosque de tarefas lista logo as pessoas da Equipa** (as contas da empresa): não é preciso criar cada
  uma outra vez. O nome vem da conta.
- A página passa a chamar-se **"Equipa e cartões"**: aí associas o cartão NFC de cada pessoa (menu ⋮ → "Associar
  cartão"). O cartão fica guardado na pessoa; quem ainda não tem cartão continua a escolher o nome no quiosque.
- **"Esconder do quiosque"** tira alguém da lista sem apagar nada (e "Mostrar no quiosque" volta a pô-la).
- **"Pessoa sem conta"** mantém-se para quem trabalha mas não tem conta na app.
- Migration `1790940000_colaboradores_equipa.js` (campo `user` em `colaboradores`, uma linha por conta).
- Os colaboradores já criados na 1.56.0–1.63.0 (sem conta) continuam a aparecer como "Sem conta".

## 1.63.0 — 2026-10-04 — Inventário numa só página: ingredientes, limpeza, material e embalagens

Quatro sítios que geriam coisas parecidas passam a **uma só página, "Inventário"**, com secções:

- **Ingredientes** (antes a página Ingredientes + o stock da "Cozinha"): cada linha mostra agora o **stock**
  ("Stock 2,5 kg"; vermelho "mín. …" quando está abaixo do mínimo). Toca no stock para dar entrada ou saída;
  toque longo para ver o histórico.
- **Limpeza e insumos** (antes uma página à parte e metade do "Material da loja"): produtos, fichas de segurança
  (FDS) e o stock em cada linha.
- **Material da loja**: equipamentos, mobiliário, ferramentas… (já sem os consumíveis, que ficam em Limpeza e insumos).
- **Embalagens**: peças e kits, como antes.
- Os botões do topo trocam de secção e mostram **"a acabar"** quando há itens abaixo do mínimo nessa secção.
- *Todas as páginas* e o rodapé têm **uma só entrada, "Inventário"** (saíram Ingredientes, Limpeza e insumos e
  Embalagens). Os endereços antigos (`/ingredientes`, `/consumiveis`, `/embalagens`) levam à secção certa.
- Cada secção mantém todas as suas funções (ordenar, juntar, INSA, importar, lixeira, kits, FDS…); só mudou o
  sítio. A barra do topo de cada secção fica reduzida às ações.

## 1.62.0 — 2026-10-04 — Mensagens de erro claras em todos os ecrãs

- Em **33 ecrãs** (receitas, vendas, compras, fichas, embalagens, formatos, agenda, definições…) um erro aparecia
  em bruto, por exemplo `ClientException: {url: http://…, statusCode: 400 …}`, com o endereço do servidor à vista.
  Passa tudo a **uma frase em português**: "Sem ligação ao servidor…", a mensagem do servidor quando é nossa
  (ex.: "Esta ficha não tem massa…") ou "Não foi possível concluir. Tenta de novo.".
- As listas que falham a carregar ("Tentar de novo") usam a mesma frase.
- Erros técnicos (com endereços, `Null`, `type '…'`) nunca se mostram.
- A função passou para `core/errors/mensagem_amigavel.dart`; o ficheiro antigo continua a apontar para ela.

## 1.61.0 — 2026-10-04 — "Produtos" passa para dentro da ficha técnica (uma só informação nutricional)

A página **Produtos** e a **declaração nutricional** da ficha técnica faziam o mesmo, e só a impressão feita nos
Produtos saía correta. Ficou **uma só** coisa:

- **Ficha técnica → ícone do prato = "Informação do produto"**: declaração nutricional, ingredientes (completa ou
  resumida), alergénios, peso, validade e conservação, com **copiar** e **imprimir a etiqueta** (a impressão
  correta, a mesma de antes). A seta de voltar regressa à ficha.
- **Lista de fichas**: um prato vermelho ao lado do nome quando a informação está por completar (diz o que
  falta) e o filtro **"Informação por completar (n)"** — é a antiga lista de Produtos.
- A página **Produtos saiu** de *Todas as páginas*; os links e favoritos antigos (`/produtos`, `/produtos/…`)
  redirecionam para a ficha.
- A folha antiga "Declaração nutricional" (com imprimir/copiar duplicados) passou a **"Completar a nutrição"**:
  só lista os ingredientes sem dados e leva a preenchê-los.
- Textos de ajuda atualizados.

## 1.60.0 — 2026-10-04 — Menos páginas soltas: Colaboradores passa para dentro do HACCP

- A página **"Colaboradores e cartões"** deixa de ocupar um lugar próprio em *Todas as páginas* (e no rodapé).
  Abre-se pelo **HACCP** (ícones do quiosque e do cartão no topo) — é lá que as tarefas e as pessoas se juntam.
- O **Quiosque de tarefas** mantém o seu lugar (é a página que fica aberta no telemóvel da loja/fábrica).
- Nada muda no que a página faz nem nas permissões (só proprietário/administrador gere cartões).
- Quem tinha "Colaboradores e cartões" no rodapé ou escondido: a escolha deixa de se aplicar (a página já não existe
  no catálogo); basta abri-la pelo HACCP.

## 1.59.0 — 2026-10-04 — Inventário só com o que se compra (os cookies prontos ficam na Contagem)

Limpeza de uma função duplicada: o stock de "Produto" (cookies prontos) existia no Inventário **e** na Contagem
diária, e o da Contagem é o que tem abertura, vendas do Vendus, perdas e fecho.

- **Inventário → Cozinha** mostra só os **ingredientes**; deixaram de aparecer os "Produtos" (cookies prontos).
  O aviso no topo leva à **Contagem diária**.
- O "Stock baixo" do Início deixa de contar produtos prontos.
- Textos de ajuda atualizados (ficha técnica, formatos de cookie, inventário).
- **Nada foi apagado**: os registos antigos de stock de produto continuam na base de dados; para os voltar a ver
  basta voltar à versão 1.58.0.

## 1.58.0 — 2026-10-04 — Mais rápido: vendas do período sem trazer o histórico todo

- **Contagem diária, Painel financeiro, DRE, IVA, Números mágicos e Relatório geral** carregavam as linhas de venda
  de **todas** as vendas desde o início, mesmo para ver um só dia. Passam a pedir só as linhas das vendas do
  período (em lotes, em paralelo). Os números são os mesmos; o tempo de carregamento deixa de crescer com os meses.
- Sem alterações de dados nem de ecrãs.

## 1.57.0 — 2026-10-04 — Contagem diária: um só sítio para registar

Limpeza sem perder funções — antes havia **dois caminhos** para registar o mesmo na Contagem diária.

- **"Rápido" passa a ser o único sítio onde se regista** (abertura, fornadas, perdas e consumo próprio, fecho).
- **"Detalhe" passa a ser só consulta**: as contas de cada sabor, os registos do dia e o apagar de um registo
  enganado. Saíram dali os botões "Assados", "Desperdício", "Contar abertura" e "Contar fecho" (faziam o mesmo que
  o Rápido) e o toque no cartão do sabor.
- "Enviar / devolver" fica no Rápido (passo "Dia"), numa folha mais simples (sabor, destino e quantidade com − / +).
- Removido código duplicado: as folhas antigas de movimento e de contagem rápida.
- Quem só pode ver (papel Leitura) continua a ver o Detalhe.

## 1.56.0 — 2026-10-04 — Quiosque de tarefas com cartão NFC e colaboradores

- **Novo "Quiosque de tarefas"** (em *Todas as páginas*): um ecrã inteiro, sem rodapé, para o telemóvel que fica na
  loja/fábrica com a app sempre aberta. Mostra só **um botão grande por tarefa** (as do HACCP: limpezas,
  temperaturas, pragas, extintor, lote…), a vermelho/laranja/verde conforme estejam em atraso, por fazer ou feitas.
  - **Cartão NFC**: cada pessoa encosta o seu cartão e a app sabe quem é ("Olá, Ana"). Sem cartão (ou sem NFC no
    aparelho) toca-se no próprio nome na lista.
  - **Um toque regista**: limpeza e manutenção ficam logo registadas com o nome e a hora. **Temperatura**: teclado
    numérico grande (fora dos limites pergunta o que foi feito, com opções rápidas). **Pragas**: "Tudo bem" ou "Vi
    sinais". **Lote/outros**: escreve-se o texto.
  - Volta sozinho ao ecrã do cartão **45 s** depois do último toque. Para sair do quiosque: mantém premido o cadeado.
  - Mostra também o que **está no forno**, com o tempo de cada sabor.
- **Nova página "Colaboradores e cartões"** (só proprietário/administrador): cria cada colaborador (não precisa de
  conta na app) e associa-lhe o cartão encostando-o ao telemóvel (ou escrevendo o número de série). Um cartão só
  pode ser de uma pessoa.
- HACCP: novo controlo habitual **"Registo de lote"** (escreve-se o lote no quiosque).
- **Requisito do NFC**: o leitor só funciona no **Chrome do Android** e com a app aberta por **HTTPS**; o
  navegador pede permissão na primeira vez. Sem isso o quiosque funciona na mesma, escolhendo o nome.
- Nova migration `1790930000_colaboradores.js` (coleção `colaboradores`).

## 1.55.0 — 2026-10-04 — Forno com um cronómetro por sabor (e no Início)

- **Sabores com tempos diferentes**: cada sabor da fornada tem o **seu cronómetro**, com o tempo de assadura da
  ficha técnica: **"faltam 05:12"**, **"passaram 06:48"** e uma barra de progresso. O que sai primeiro aparece
  primeiro.
- Quando um sabor chega ao fim do tempo, **só esse** avisa (vibra e toca) e fica a vermelho com o botão **"Tirei"**;
  os outros continuam a contar. "Tirei tudo" tira os que faltam; quando saem todos, a fornada fecha.
- Se vários sabores não têm tempo na ficha, pergunta os minutos uma vez (e diz quais são).
- **No Início** aparece o cartão **"No forno"** com uma linha por sabor e o tempo que falta (vermelho "Tirar do
  forno!" quando algum está pronto); toca para abrir a contagem. Só aparece quando há algo no forno.
- Fornadas feitas na 1.54.0 continuam a funcionar (usam o tempo da fornada para todos os sabores).

## 1.54.0 — 2026-10-04 — Contagem rápida com botões − / + e forno com cronómetro

- **Contagem diária → separador "Rápido"** (é o que abre por omissão; "Detalhe" tem todas as contas): cada sabor
  numa linha, com **botão de menos, o número (que também se escreve) e botão de mais**. Três passos: **Abrir**,
  **Dia** e **Fechar**.
  - **Abrir**: os sabores vêm preenchidos com o que ficou de ontem. Se ontem ninguém contou o fecho, a app calcula
    o que **devia ter ficado** (assados − vendas − perdas…) e avisa; podes corrigir e **registar as perdas de ontem**.
  - **Dia**: as **vendas vêm sozinhas do Vendus** (sabor a sabor), **perdas e consumo próprio** (queimado, quebrado,
    fora do prazo, **consumo próprio**, erro de produção…) com − / +, e **enviar/devolver** para outro local.
  - **Fechar**: o número pequeno é o que devia haver; ajusta o que realmente sobrou ("faltam 2 / sobram 1"), ou
    toca em **"Está tudo como devia haver"**. Se não fechares, no dia seguinte a abertura já vem com o que devia
    ter ficado.
  - **Duas opções de trabalho** (escolhe-se em cada aparelho): **1 · vendas** — contas só a abertura e o fecho e as
    vendas vêm do Vendus; **2 · fornadas** — como a 1 e ainda registas cada fornada.
- **Forno**: na opção 2, escolhes os sabores e as quantidades e carregas em **ASSAR**. Regista os assados, e
  arranca um **cronómetro** com o **tempo de assadura da ficha técnica** (o maior, se houver vários sabores; se
  nenhum tiver, pergunta os minutos). Quando acaba, o telemóvel vibra e toca, e o cartão fica a vermelho até
  carregares em **"Tirei do forno"**. O cronómetro vê-se em qualquer telemóvel. **"Foi engano — cancelar"** apaga
  os assados dessa fornada.
- A abertura herdada passa a olhar os **últimos 14 dias** (antes só o último fecho contado).
- Novas migrations: `1790920000_fornadas.js` (coleção `fornadas` e o motivo `consumo_proprio`).

## 1.53.0 — 2026-10-04 — Tempo de assadura na ficha técnica e na montagem

- **Ficha técnica → "Tempo de assadura (minutos)"**: define-se uma vez na ficha e aparece em **Assar X min** no
  detalhe da ficha, na **Mise en place / Produzir** (cartão em destaque junto ao plano do produto) e na
  **Agenda** (mise en place por receita de uma produção). É também o tempo que o cronómetro do forno vai usar
  na contagem diária (próxima versão).
- Nova migration `1790910000_tempo_assadura.js` (`fichas_tecnicas.tempo_assadura_min`).

## 1.52.0 — 2026-10-04 — Ficha técnica: embalagem separada e embalagem para plataformas

- **Ficha técnica → custo separado**: o detalhe mostra **Matéria-prima**, **Embalagem** e **Nas plataformas**
  lado a lado. O custo do produto na loja (e o preço sugerido / CMV) continua a ser matéria-prima + embalagem.
- **Novo bloco "Embalagem para plataformas"**: para o que só usas nas vendas por Uber Eats, Glovo, etc. (saco
  de entrega, selo, caixa extra). **Não entra no custo da loja**; "Nas plataformas" = custo da loja + este
  bloco. Aceita embalagens avulsas e kits, como o bloco Embalagem.
- **Correção**: duplicar uma ficha agora copia também as embalagens e os kits (antes ficavam de fora).
- **Correção**: o "Peso" da ficha deixou de somar as peças das embalagens.
- **Inventário → Cozinha**: aviso a apontar para a **Contagem diária** (é lá que se contam os cookies prontos,
  por local e por dia).
- Nova migration `1790900000_slot_embalagem_plataforma.js`.

## 1.51.0 — 2026-10-04 — HACCP (registos, pragas, frigorífico, limpezas) e categorias nos custos fixos

- **Nova página "HACCP"** (em *Todas as páginas*): três separadores.
  - **Hoje**: o que falta fazer — vermelho (atrasado/nunca registado), laranja (fazer hoje, "1 de 2"), verde
    (em dia) — e as **não conformidades por resolver**. Também aparece um aviso **"HACCP por fazer"** no Início.
  - **Registos**: histórico por período (7/30/90 dias ou 1 ano) e por controlo, com **imprimir / guardar em PDF**
    para auditorias.
  - **Controlos**: o que se controla — **temperatura** do frigorífico e da arca (com limites: fora deles fica
    logo como não conformidade e pede a ação corretiva), **limpezas**, **controlo de pragas** (registo de
    ocorrências), **manutenções/validades** (extintor, empresa de pragas, com a data da próxima revisão) e
    outros. Cada um com a sua frequência (diária — até várias vezes por dia —, semanal, mensal, anual ou
    ocasional). "Adicionar os controlos habituais" cria uma lista de partida.
  - Os registos nunca se apagam (só proprietário/administrador, pela base de dados): ficam como prova.
- **Custos fixos → "Categoria"** (texto livre com sugestões: Instalações, Pessoal, **Controlo operacional**,
  Marketing, Software, Impostos, Outros custos): filtra por categoria com o subtotal de cada uma. No relatório
  geral serve de pista quando o nome do custo não chega para o classificar.
- Nova migration `1790890000_haccp.js` (coleções `haccp_controlos`, `haccp_registos` e `custos_fixos.categoria`).

## 1.50.0 — 2026-10-04 — IVA a separar, vista diária e relatório do que foi comprado

- **Painel financeiro → "IVA a separar"**: o **IVA cobrado nas vendas** − o **IVA das faturas de compra
  confirmadas** = o que há a **entregar ao Estado** (ou crédito de IVA). Por dia, semana, mês ou ano, com a
  lista **"Dia a dia"** (vendido com IVA e IVA de cada dia). O IVA das vendas vem do Vendus quando existe;
  senão estima-se com a nova taxa **"IVA das vendas"** (Configurações → Percentuais de custo; não entra nos
  percentuais do preço). O cartão avisa quantas linhas foram estimadas ou ficaram sem IVA.
- **Novo período "Dia"** em todos os ecrãs financeiros (Painel, DRE, Análise de vendas, Números mágicos,
  Desperdício…): um único dia. Nos **Números mágicos**, a venda mínima do dia (mínimo mensal ÷ 26 dias) contra
  o que vendeste nesse dia; e, na semana e no mês, uma lista **"Dia a dia"** com o vendido de cada dia contra o
  mínimo diário (✓ quando o bateste).
- **Compras → ícone "O que comprei"**: relatório do que deu entrada no stock por compra (dar o visto na lista
  de compras ou aplicar faturas) por dia, semana, mês ou ano, agrupado por **dia / fornecedor / produto**,
  com custo estimado e **descarregar CSV**. O histórico não se perde ao limpar a lista de compras.
- **Relatório geral** (Excel/CSV): o "Resumo mensal" ganha `iva_cobrado_nas_vendas`, `iva_das_compras` e
  `iva_a_entregar`.
- Nova migration `1790880000_iva_vendas.js` (campo `iva_vendas` em `configuracoes_custo`).

## 1.49.0 — 2026-10-04 — Contagem diária por local (loja, Alvalade, plataformas) e desperdício

- **Nova página "Contagem diária"** (em *Todas as páginas*; pode ir para o rodapé): para cada **local**
  (Loja, Alvalade, Plataformas — e outros que criares), por dia e por sabor:
  **Abertura + Assados + Recebidos − Enviados − Vendidos − Desperdício = "Devia haver"**, e a **contagem de
  fecho** (o que sobrou de facto) com a diferença ("faltam 3").
  - **Assados**: regista o que saiu do forno.
  - **Enviar / devolver**: passa cookies de um local para outro (Loja → Alvalade; no dia seguinte, o que
    volta de Alvalade → Loja). O destino fica com os recebidos; assim sabes quantos foram e quantos voltaram.
  - **Desperdício** com motivo (queimado, fora do prazo, quebrado/caído, erro de produção, degustação,
    outro) e notas.
  - **Contar abertura / Contar fecho**: contagem rápida de todos os sabores de uma vez; a abertura mostra a
    diferença "de ontem para hoje".
  - Os **vendidos** vêm sozinhos das Vendas, pelo **canal** da venda (cada local tem os seus canais:
    "Parceria Alvalade" → Alvalade; "Uber Eats", "Glovo", "Bolt Food" → Plataformas; o resto → Loja).
- **Relatórios** (ícone do gráfico): **desperdício** por motivo, sabor e local, com o custo da
  matéria-prima e a % dos assados; e **balanço por local** (ex.: Alvalade — recebidos, devolvidos, vendidos,
  desperdício e saldo), por semana/mês/ano.
- **Relatório geral** (Painel financeiro): nova folha **"2 Contagem diaria"** (assados, recebidos, enviados,
  vendidos, desperdício e motivo, devia haver, sobra contada e diferença, por dia/local/sabor).
- Gestão de **locais** (ícone do local): nome, tipo e canais de venda. Novas coleções `locais` e
  `movimentos_produto` (migration `1790870000_contagem_locais.js`, que cria Loja / Alvalade / Plataformas).

## 1.48.3 — 2026-10-02 — Corrige "Failed to create record" ao criar embalagem sem formato

- **Corrigido**: ao aplicar uma fatura com uma embalagem **nova** (ex.: "Caixa para bolo") sem escolher
  nenhum formato de cookie, a linha falhava com "Failed to create record" e ficava por rever. A regra da
  coleção de embalagens recusava a lista de formatos vazia ("em branco serve para qualquer formato"); o
  mesmo acontecia ao criar/editar uma embalagem sem formatos. Nova migration
  `1790860000_embalagens_formatos_regra.js`. Um formato de outra empresa continua a ser recusado.
- Depois de atualizar, volta a aplicar a fatura: a linha "Caixa para bolo" fica por rever com o que já
  preenchiste — basta tocar em Aplicar outra vez.

## 1.48.2 — 2026-10-02 — Backup manual: verifica o espaço e limita o número de cópias

- **`gc_turnkey.sh backup-agora`** (servidor):
  - antes de parar o servidor, **verifica se há espaço em disco** para a cópia; se não houver, avisa e **não
    mexe em nada** (o servidor continua a funcionar);
  - depois de um backup bem sucedido, **guarda só os últimos 5** backups manuais (configurável com
    `GC_TURNKEY_BACKUPS_MANTER=N` no `.env`) — cada um tem o tamanho dos dados e enchiam o disco.
  - o espaço é medido no disco onde a cópia é escrita, por isso `backups-manuais` pode ser um atalho para
    outro disco maior (ver `docs/SERVIDOR_LINUX.md`).
- Sem alterações na app nem na base de dados.

## 1.48.1 — 2026-10-02 — Backup que falha já não deixa o servidor parado

- **Corrigido (servidor, `gc_turnkey.sh backup-agora`)**: o backup pára o servidor para copiar `data/`; se a
  cópia falhasse (disco cheio, permissões…), o script abortava **sem voltar a arrancar o servidor** — e a
  atualização (`publicar-producao.sh`) parava aí, com a app em baixo e ainda na versão antiga. Agora, se a
  cópia falha, o servidor **arranca sempre de novo**, o ficheiro parcial é apagado e o script diz que o
  backup falhou (com a dica de verificar espaço em disco e permissões). A atualização aborta sem mexer na app.
- Sem alterações na app nem na base de dados (mesmos conteúdos da 1.48.0).

## 1.48.0 — 2026-10-02 — Relatório geral no Painel financeiro (Excel / CSV)

- **Painel financeiro → ícone "Relatório geral"** (administradores): gera um ficheiro com **uma folha por
  relatório**, seguindo a especificação de relatórios da estratégia: Resumo mensal · 1 Vendas (por canal,
  sabor, com e sem IVA) · 1 Equivalência de nomes · 2 Produção · 3 Custo por sabor (+ componentes,
  ingredientes e histórico de preços de compra) · 4 Despesas por categoria · 7 Tesouraria · e modelos por
  preencher para 5 Plataformas, 6 Pessoal, 8 Eventos e 9 Origem dos clientes. A folha **Leia-me** diz, por
  relatório, o que está completo e o que falta.
- Formatos: **Excel (.xlsx)** ou **CSV (.zip)** (UTF-8, vírgula; datas AAAA-MM-DD; euros com ponto).
  Períodos: últimos 12 meses (por omissão), 6 meses, este ano ou o período do painel.
- **IVA**: margens sem IVA. O valor sem IVA vem do Vendus quando existe; senão podes escolher uma taxa
  (6/13/23 %) para estimar — fica sempre indicado na coluna `iva_origem` (registado / estimado /
  desconhecido).
- **Vendas ganham canal, hora e método de pagamento** (e por linha: valor sem IVA, taxa e desconto):
  - definir o **canal** (Loja física, Uber Eats, Glovo, Bolt Food, Parceria Alvalade, Revenda, Envio
    nacional, Eventos… ou outro) ao registar uma venda e, depois, no detalhe da venda;
  - o Vendus passa a trazer **hora, método de pagamento e valor sem IVA** por linha; as vendas novas ficam
    como "Loja física". "Reimportar histórico" **completa as vendas antigas** do Vendus (sem duplicar).
- Nova migration `1790850000_vendas_relatorio.js`.
- Ainda **não são registados** (vão em branco no relatório): comissão do canal, tipo de cliente,
  sobras/desperdício/horas de produção, extratos das plataformas, horas de pessoal, saldo bancário e
  dívidas, eventos e origem dos clientes — próximos passos se quiseres capturá-los na app.

## 1.47.0 — 2026-10-02 — IA nos custos fixos/variáveis e dicas no Painel financeiro

- **Custos fixos → ícone ✨ "Organizar com IA"**: a IA lê os custos ativos e sugere, para cada um, se é
  **fixo** ou **variável**, porquê, e (nos variáveis) o que fazer se o dinheiro apertar — *reduzir*, *pausar
  por um período* ou *cortar* — com uma dica. Escolhes quais sugestões aplicar; nada muda sem confirmares.
- **Ajuda dos Custos fixos** reescrita: o que é fixo (não se elimina sem fechar ou mudar o negócio) e o que
  deve ser variável (pode reduzir-se ou cortar-se, por um período ou para sempre), porquê separar, e o
  critério de desempate. O formulário de custo também explica o tipo escolhido.
- **Painel financeiro → "Dicas para melhorar"** (só administradores): botão "Gerar dicas com IA" que lê os
  números do período mostrado e do anterior (receita, lucro, custos fixos/variáveis, CMV, imposto, linhas
  sem produto) e devolve 4–6 dicas por prioridade. Pensado para usar no fim de cada semana/mês.
- Servidor: 2 endpoints novos (`/api/gc_turnkey/financeiro/classificar-custos` e `/dicas`), só
  owner/admin; usam o mesmo fornecedor de IA e chave das faturas (nada novo a configurar). A IA só
  sugere — não grava.

## 1.46.1 — 2026-10-02 — Números mágicos: lucro líquido, ano e comparação

- **Novo período "Ano"** (1 de janeiro a 31 de dezembro) nos Números mágicos, Painel financeiro, DRE e
  Análise de vendas, com histórico por ano. Nos custos mensais, um ano pesa 12 meses.
- **Comparação com o período anterior nos Números mágicos** (evolução ou quebra do vendido, em %). Se o
  período atual ainda decorre, compara com o **mesmo nº de dias** do anterior (ex.: 1–2 de outubro vs 1–2 de
  setembro), para a comparação ser justa.

- **Corrigido**: ao passar o mínimo, "Já passou o mínimo — lucro puro" mostrava todo o excedente
  (vendido − mínimo) como lucro. Mas cada produto vendido a mais continua a levar **imposto** e **CMV**.
- Agora mostra: *Vendido acima do mínimo* → *− Imposto* → *− CMV* → **Lucro líquido do período** (só o
  que sobra). Os custos reais (fixos, variáveis, depreciação) já ficaram pagos pelo mínimo.

## 1.46.0 — 2026-10-02 — Períodos claros nos números financeiros (semana dom–sáb, mês inteiro, histórico)

- **Números mágicos, Painel financeiro, DRE e Análise de vendas** passam a usar o mesmo seletor de período:
  - **Semana**: de **domingo a sábado**, ignora o mês (pode atravessar dois meses).
  - **Mês**: do **dia 1 ao último dia** do mês.
  - As **datas exatas** aparecem sempre (ex.: *01/10/2026 – 31/10/2026*), e quando o período ainda está a
    decorrer diz-se que é contado inteiro.
- O período é sempre **completo** (a semana toda, o mês todo), por isso o mínimo/custos do período **já não
  mudam de um dia para o outro** — só o "vendido" vai subindo. Antes a semana ia de segunda até hoje e o mês
  do dia 1 até hoje, e o mínimo era proporcional aos dias passados.
- **Histórico**: setas ‹ › para qualquer semana ou mês anterior (não só o mês passado), toque nas datas para
  saltar para um dia, e botão "voltar a hoje".
- A comparação com o "período anterior" usa agora a semana anterior, ou o **mês civil anterior** (antes era
  "o mesmo nº de dias antes").
- Uma semana pesa sempre 7/30,44 de um mês nos custos fixos (antes variava com o mês onde caía).
- Corrigido: contagem de dias de um período errada em semanas que incluem a mudança de hora.

## 1.45.0 — 2026-10-02 — Subnome nas fichas + etiquetas térmicas em tamanhos padrão

- **Ficha técnica → Editar**: novo campo **Subnome** (ex.: Carolina do Sul → *Red Velvet*). O campo
  "Descrição" passa a chamar-se **Característica** (ex.: "Brigadeiro de queijo creme e compota de frutos
  vermelhos").
- O subnome aparece na **página do produto** e, ao imprimir, há um interruptor **"Imprimir o subnome"**
  (por baixo do nome, em letra mais pequena que o nome e maior que a característica).
- **Etiquetas**: deixa de haver medidas livres. Escolhe-se um **tamanho padrão de etiqueta térmica**
  (50 × 80 — preferido, 50 × 100, 60 × 80, 60 × 100, 75 × 100). A **frente** (nome, subnome,
  característica e peso) tem **15 mm por omissão (mínimo) até 25 mm**; a parte de baixo, com a informação
  legal, fica com o resto.
- A app mede o texto e sugere: "Frente de X mm" se a frente não chega, e o **menor tamanho padrão** onde
  tudo cabe (tenta sempre 50 × 80 primeiro).
- Definições de etiqueta antigas (medidas livres) são convertidas para o tamanho padrão mais próximo.
- Nova migration `1790840000_fichas_subnome.js`.

## 1.44.1 — 2026-10-02 — Preço em falta visível na lista de Fichas Técnicas

- **Fichas Técnicas (lista)**: faixa **vermelha** no topo com as fichas cujo custo está incompleto
  (ex.: "Bali"), e em cada ficha afetada o custo fica a vermelho com ⚠ (toca para ver o que falta) — igual
  ao que já existia na lista de Receitas.
- O servidor passa a **preencher sozinho** os novos dados de custo das receitas/fichas existentes, 1 minuto
  depois de arrancar após a atualização — já não é preciso chamar `admin/recompute` à mão.

## 1.44.0 — 2026-10-02 — Aviso de preço em falta apanha linhas por ligar e massas/sub-receitas

- **Corrigido**: o aviso vermelho "Preço em falta" da Ficha Técnica não aparecia quando a massa tinha
  linhas **por ligar** ("vínculo pendente") nem quando o ingrediente sem preço estava dentro de uma
  massa/sub-receita (caso da ficha "Bali" / "Massa Bali").
- A deteção passou para o servidor: receitas e fichas guardam agora `custo_completo` + `custo_sem_dados`
  (linhas por ligar, ingredientes sem preço, através de sub-receitas e ingredientes de fabrico próprio).
  Recalculam sozinhos a cada alteração.
- Nova migration `1790830000_custo_completo.js`.
- **Depois de instalar**: chama **uma vez** `POST /api/gc_turnkey/admin/recompute` (superuser/dono) para
  preencher os dados já existentes; sem isso o aviso só aparece nas receitas/fichas que forem alteradas.

## 1.43.0 — 2026-10-01 — Avisos de preço/nutrição em falta na Ficha Técnica

- **Ficha Técnica → ecrã de edição** (Peso/Custo/Preço de venda) ganha dois avisos logo no topo, quando
  algum ingrediente usado — direto ou dentro de uma massa/sub-receita — ainda não está completo:
  - 🔴 **"Preço em falta"** (vermelho) — lista os ingredientes sem preço definido; o custo da ficha fica
    incompleto/errado enquanto isto não for corrigido.
  - 🟡 **"Nutrição em falta"** (amarelo) — lista os ingredientes sem tabela nutricional; toca para abrir a
    Declaração nutricional e corrigir em cascata (mesmo mecanismo que já existia, agora também visível sem
    teres de abrir essa folha para descobrir que falta algo).
- Corrigido: o ícone novo de "Produtos não identificados" (Vendas) usava o mesmo ícone do botão de Ajuda da
  página — trocado para um ícone próprio.

## 1.42.0 — 2026-10-01 — Ligar produtos não identificados nas vendas (retroativo + aprende sozinho)

- **Vendas → ícone "Produtos não identificados"** (novo): lista as descrições de vendas (Vendus/CSV) que
  não foram associadas a nenhum produto, agrupadas e ordenadas por valor total — com o nº de linhas e de
  unidades de cada uma.
- Toca numa descrição para **ligar a um produto já existente** (escolhe da lista) ou **criar um produto
  novo** (nome pré-preenchido com a descrição, revê antes de criar). A ligação:
  - corrige **de uma vez todas as vendas passadas** com essa descrição exata (não só a mais recente);
  - fica "aprendida" no produto — a próxima importação CSV ou sincronização Vendus com a mesma descrição
    liga-se sozinha, sem precisares de repetir a correção.
- Isto resolve de vez descrições com acentos/erros do POS (ex.: "Gookie Belèm do pàra.") que nunca batiam
  certo com o nome do produto — e melhora a precisão do Painel financeiro/DRE, que já avisava destas vendas
  sem conseguir calcular a margem.

## 1.41.1 — 2026-10-01 — Corrigido: "Adicionar" num kit de embalagens dizia "cria as peças primeiro"

- **Embalagens → Kits → editar um kit → "Adicionar"** podia mostrar "Cria primeiro as embalagens no
  separador 'Peças'", mesmo havendo peças criadas — acontecia se o editor do kit abrisse sem a lista de
  peças já ter sido carregada nessa sessão (o pedido não esperava a resposta do servidor, lia uma lista
  ainda vazia). Agora espera sempre a lista real antes de decidir se está vazia.

## 1.41.0 — 2026-09-30 — Declaração de aditivos na lista de ingredientes do produto

- **Ingredientes → Nutrição e alergénios** ganha um campo de texto livre **"Aditivos"**, para a declaração de
  aditivos que tem de constar na lista de ingredientes do produto final (ex.: `Corante: E122, E110 (pode ter
  efeitos negativos na atividade e atenção das crianças). Conservante: E211.`). É independente da nutrição —
  aparece mesmo que o ingrediente esteja marcado como "sem valor nutricional relevante" e seja usado em
  quantidade residual, porque a obrigação de declarar aditivos não depende da quantidade.
- Esse texto passa a aparecer automaticamente, entre parênteses retos a seguir ao nome do ingrediente, na
  **lista de ingredientes do produto** (ecrã do Produto, etiqueta impressa, texto para copiar) — nas versões
  Completa e Resumida.

## 1.40.0 — 2026-09-30 — Ingrediente "sem valor nutricional relevante" (corante, aroma…)

- **Ingredientes → Nutrição e alergénios** ganha um interruptor **"Sem valor nutricional relevante"**, para
  corantes, aromas e afins usados em quantidade residual. Antes, deixar tudo a zero fazia o sistema tratar o
  ingrediente como "dados em falta" para sempre (em Receitas e Fichas Técnicas); agora, com o interruptor
  ativo, conta como **zero confirmado** — desaparece da lista "por preencher" sem precisares de inventar um
  valor simbólico.
- Ao ativar o interruptor, os campos numéricos ficam desativados (já não fazem sentido).
- Na lista de Ingredientes, estes ficam com um ícone próprio (🚫) distinto de "sem nutrição".

## 1.39.0 — 2026-09-30 — Importar vários custos fixos/variáveis e equipamentos colando texto

- **Custos fixos e Equipamentos** ganham o mesmo tipo de importação em lote que já existia para
  Ingredientes/Receitas: o botão "Importar" abre agora uma folha para **colar texto direto da folha de
  cálculo** (Ctrl+V normal, sem clipboard especial) — uma linha por registo, colunas separadas por tab, `;`
  ou `,` (deteção automática) — ou continuar a escolher um ficheiro CSV como antes.
- **Custos fixos**: `nome, valor, dia de pagamento, notas` (as duas últimas opcionais) — ex.:
  `Energia\t€140,00\t31\tnotas`. Todos entram como "Fixo"; muda o tipo depois na app se algum for variável.
- **Equipamentos**: `nome, custo de compra, vida útil (anos), notas` (a última opcional) — ex.:
  `Computador\t€500,00\t3`.
- Em ambos, linhas em branco no meio do texto colado são ignoradas.

## 1.38.0 — 2026-09-30 — Nota no email à contabilidade + assunto automático

- **Faturas → "Enviar por email" (contabilidade)** ganha um campo opcional **"Nota para a contabilidade"**
  (ex.: "falta a fatura da EDP, chega depois") que aparece no corpo do email quando preenchido. Fica em branco
  depois de um envio bem-sucedido; se o envio falhar, o texto não se perde.
- O **assunto do email** passa a ser sempre gerado automaticamente pela app — identifica-se ("GC Turnkey") e
  diz a empresa a que pertencem as faturas — deixa de depender de configuração nenhuma.
- Corrigido: um envio falhado (ex.: SMTP não configurado no servidor) já não mostra o erro técnico bruto do
  servidor de email na interface — só a mensagem amigável, tal como o resto da app.
- **`pb/DEPLOY.md`/`pb/README.md`**: documentado (era um buraco) como configurar o remetente "noreply" e o SMTP
  — é tudo na **Admin UI do PocketBase → Settings → Mail settings**, não há variável de ambiente nossa para isto.

## 1.37.0 — 2026-09-30 — Importar uma receita por foto/print (IA) ou lista simples

- **Receitas → "Importar receitas"** ganha um novo modo **"Uma receita"** (ao lado do CSV avançado de sempre):
  escreves o nome, escolhes a categoria, e colas/escreves a lista de ingredientes num formato simples — só
  "ingrediente" + "quantidade em gramas" por linha, sem repetir nome/categoria em cada linha.
- **Preenchimento automático por IA**: no modo "Uma receita", "Escolher imagem" (ou colar com **Ctrl+V** um
  print da folha de cálculo/foto de uma lista) manda a imagem para o servidor, que usa a mesma IA já usada nas
  faturas e nos rótulos nutricionais para ler o nome da receita, a categoria e a lista de ingredientes —
  **pré-preenche o formulário para reveres e corrigires antes de importar** (nunca aplica sem confirmares,
  como em toda a app). Precisa da chave de IA configurada no servidor (`GEMINI_API_KEY`/`ANTHROPIC_API_KEY`,
  ver `pb/README.md`) — sem ela, mostra "IA não configurada".
- Ingredientes sem correspondência (nome novo) ficam pendentes, tal como no CSV — usa "Ligar automaticamente"
  (v1.36.0) para resolver depois os que baterem certo com um ingrediente existente.
- O modo "Várias (CSV avançado)" de sempre continua igual, para quem já tem várias receitas numa folha só.

## 1.36.0 — 2026-09-30 — Ligar automaticamente ingredientes por ligar, pelo nome

- **Receitas com linhas "por ligar"** (ex.: importadas antes de teres o ingrediente cadastrado) ganham um botão
  **"Ligar automaticamente"** — na lista de Receitas (ícone de varinha, só aparece quando há pendências) e
  dentro da receita (no aviso "Há linhas por ligar"). Compara o nome de cada linha pendente com os
  ingredientes existentes: nomes **exatamente iguais** (ignorando acentos/maiúsculas) ligam-se sozinhos, sem
  precisar de confirmar; para os restantes, abre uma lista para reveres a melhor sugestão (ou escolheres outro
  ingrediente/sub-receita) e confirmares antes de aplicar. Nada é ligado sem passares pela revisão, exceto os
  nomes idênticos.
- Pensado para depois de importar receitas em massa e teres de ligar dezenas de linhas repetidas uma a uma —
  agora as que já batem certo com um ingrediente existente ficam resolvidas com um clique.

## 1.35.0 — 2026-09-30 — Erro de nutrição do produto sempre visível

- **Ingrediente → "Produtos de compra" → editar um produto → "Nutrição própria do produto":** ao tentar
  guardar com "Usar estes valores" ligado mas todos os valores vazios (ou nome/embalagem/preço em falta), a
  mensagem de erro aparecia no fundo de um formulário longo — muitas vezes fora da vista, sem dar para ver
  scroll para baixo. Parecia que o "Guardar" não fazia nada. Agora, sempre que aparece um erro, o diálogo
  desce sozinho até à mensagem ficar visível.
- Não havia nenhuma falha real a gravar (confirmado com testes diretos ao servidor) — o valor já ficava bem
  guardado sempre que a validação passava. O problema era só a mensagem de erro ficar escondida.

## 1.34.0 — 2026-09-30 — Email configurável e ZIP para a contabilidade

- **Faturas → "Para a contabilidade"** (ícone de pasta) ganha: um **email configurável** na própria app (fica
  guardado, também serve para o envio mensal automático), um botão **"Enviar por email"** (todas as faturas
  confirmadas, ou só as de um mês — sob pedido, não só o dia 1 automático), e um botão **"Baixar ZIP"** com
  todos os ficheiros das faturas do período escolhido. Alternador "Um mês" / "Todas" no topo escolhe o período.
- Antes, o email do contabilista só dava para configurar por variável de ambiente no servidor
  (`GC_TURNKEY_CONTAB_EMAIL`) e o único envio era o cron automático do dia 1. Isso continua a funcionar (usa o
  email da app se estiver definido, senão a variável de ambiente).
- Corrigido de caminho: o ecrã "Para a contabilidade" tinha um erro que rebentava sempre que abria em modo de
  desenvolvimento (`setState` com uma `Future` por engano) — nunca dava para ver em testes, só sobrevivia por
  o modo de produção ignorar esse tipo de erro silenciosamente. Apanhado e corrigido ao testar esta função.

## 1.33.0 — 2026-09-29 — Preço a vermelho quando a receita tem linhas por ligar

- **Receitas com linhas por ligar a um ingrediente/sub-receita** agora mostram o preço a **vermelho, com um
  aviso (⚠)** — tanto na lista de Receitas como no "Custo (prev.)"/"Custo/kg" dentro da receita. Passar o rato
  por cima (ou tocar) no aviso explica porquê o valor não é definitivo. Antes só havia uma faixa a avisar
  dentro da receita — não dava para ver de relance, na lista, quais receitas tinham este problema.
- Corrigido de caminho: o diálogo do aviso fechava a página em vez de se fechar a ele próprio (erro de
  `context` do diálogo) — haveria de fazer a app "desaparecer" ao tocar em "Entendi".

## 1.32.0 — 2026-09-29 — Característica em todo o lado, stock para Bebida/Revenda/Limpeza, buscas sem acentos

- **Não dava para distinguir variantes ao rever uma fatura** (ex.: "Café em grão" Rioba gold vs. Rioba bio
  apareciam ambos só como "Rioba · 1 kg"). Os seletores de ingrediente e de embalagem, ao rever uma fatura,
  passam a mostrar a **característica** no nome, tal como já acontecia noutros sítios da app.
- **Limpeza/Insumo/Bebida/Revenda ganham "Característica"** (opcional, ex.: "lata 33cl", "sabor limão") — no
  ecrã Limpeza e insumos e ao criar um produto novo a partir de uma fatura. Aparece no nome nas listas e nos
  seletores, para nunca mais confundir variantes do mesmo produto.
- **Bebida/Revenda (e Limpeza/Insumo, se quiseres) passam a ter stock**, tal como Ingrediente: a linha da fatura
  ganha "Comprado" (quantidade em unidades) e a Ação "Stock"/"Ambos" fica disponível — a compra dá entrada no
  Inventário (aba "Material da loja") e o preço por unidade é calculado sozinho a partir do total pago e da
  quantidade comprada (tal como já acontecia com as peças de uma embalagem).
- **Preço de Limpeza/Insumo/Bebida/Revenda na fatura passa a ser "Preço da compra"** (o total pago), não o preço
  de 1 unidade — evita gravar um custo por unidade inflado quando se compra em quantidade.
- **Busca sem acentos e maiúsculas/minúsculas** também nos seletores de Embalagem e de Limpeza/Insumo/Bebida/
  Revenda ao rever uma fatura, e na pesquisa do ecrã Limpeza e insumos — antes só os ingredientes tinham isto.
- Testado de ponta a ponta num servidor descartável com cópia dos dados reais: criar uma Bebida nova por uma
  fatura com "Ambos" (preço + stock), confirmar característica gravada, preço por unidade correto (total ÷
  quantidade) e entrada no Inventário com a quantidade certa.

## 1.31.1 — 2026-09-29 — Logótipo largo sem cortar, botão "+ Item" já não tapa a última linha

- **Corrigido: logótipos não quadrados ficavam cortados** na barra superior (e na prévia nova). Um logótipo tipo
  "wordmark" (mais largo do que alto) era forçado a caber num quadrado e as pontas desapareciam. Agora mede-se
  pela altura escolhida e mantém-se a proporção da imagem (nunca corta, só reduz um bocadinho se for
  invulgarmente largo) — a app ajusta o enquadramento sozinha, não é preciso recortar a imagem antes de enviar.
- **Corrigido: o botão "+ Item" (receitas) tapava os botões da última linha** (trocar ingrediente/escolher
  produto), impossíveis de tocar. A lista agora reserva espaço no fundo para o botão.

## 1.31.0 — 2026-09-29 — Corrige falha ao aplicar faturas, trocar ingrediente na receita, prévia do logótipo

- **Corrigido: "Failed to create record." ao aplicar algumas faturas.** A descrição lida da fatura (nome, código,
  lote…) às vezes é mais comprida do que os 200 caracteres que o nome do ingrediente/embalagem aceita — o
  "Aplicar" falhava com um erro genérico e sem indicar qual linha nem porquê. Agora: avisa antes de aplicar se
  algum nome/característica for longo demais (para encurtar), e se mesmo assim uma linha falhar a criar, **as
  restantes linhas prontas aplicam-se na mesma** — a linha com problema fica por rever, com o que já escreveste
  intacto, e a app mostra exatamente qual campo falhou.
- **Trocar o ingrediente de uma receita**: cada linha ganha um botão "⇄" para ligar a outro ingrediente ou
  sub-receita (antes só dava para ajustar a quantidade, ou ligar quando a linha ainda estava pendente). Pede
  confirmação (mostra o nome antigo e o novo) e mantém a quantidade. Restrito a Proprietário/Administrador —
  Editores continuam a poder mudar a quantidade, mas não trocar o ingrediente.
- **Prévia do logótipo em tempo real**: em Configurações → Aparência, ajustar o tamanho (ou posição/visibilidade)
  do logótipo e do nome mostra logo uma barra de exemplo igual à app real, antes de guardar.

## 1.30.0 — 2026-09-29 — Bebidas/Revenda, tipos livres e peças compradas nas faturas

- **Novos tipos ao validar faturas**: além de Ingrediente, Limpeza/insumo e Embalagem, agora também **Bebida** e
  **Revenda** — para produtos comprados para vender ao cliente (não usados nas receitas). Gravam-se na mesma
  coleção de "Limpeza e insumos" (não pedem ficha de segurança) e ganham um **preço de venda** opcional, para
  dar para ver a margem — editável em Limpeza e insumos.
- **Tipo de embalagem e categoria de consumível deixam de ser listas fixas**: escreve um novo (ex.: "Frasco",
  "Bebida") sempre que o que precisas não estiver nas sugestões — tanto ao rever uma fatura como em
  Embalagens/Limpeza e insumos diretamente.
- **Peças compradas nas embalagens, direto na fatura**: uma linha de embalagem ganha o campo "Peças compradas"
  (pré-preenchido com a quantidade que a IA leu, ex. "rolo de 500 adesivos") — antes ficava sempre gravado como
  1 peça e tinhas de corrigir à mão depois em Embalagens. Corrigido também no servidor (o valor já não fica
  preso em 1 quando não se indica nada).
- **Criar formato de cookie sem sair da fatura**: ao ligar uma linha a uma embalagem nova, "+ Novo formato"
  cria um formato só com o nome (o peso completa-se depois em Configurações → Formatos de cookie) e liga-o logo.
- Testado manualmente de ponta a ponta: fatura com uma linha de embalagem (peças + tipo + formato novo) e uma
  de bebida (categoria + preço) — confirmado no servidor que a embalagem fica com `tipo`, `unidades_compra` e
  `formatos_cookie` corretos.

## 1.29.1 — 2026-09-29 — Procurar ingrediente ignora acentos e olha à característica

- A pesquisa de ingredientes (Ingredientes, escolher ingrediente numa receita/ficha/lista de compras/fatura,
  juntar ingredientes) passa a **ignorar acentuação** ("acucar" encontra "Açúcar") e a **procurar também na
  característica e na marca**, não só no nome — antes só a lista de Ingredientes fazia isto; os outros sítios
  só olhavam ao nome exato, sem acentos.

## 1.29.0 — 2026-09-29 — Selecionar vários ingredientes para juntar

- Em **Ingredientes**, o menu (⋮) ganha "Selecionar ingredientes para juntar": entra num modo de seleção
  (como o das Faturas) com uma caixa em cada ingrediente comprado — os de fabrico próprio não podem ser
  selecionados. Escolhe 2 ou mais e toca em "Juntar".
- Depois de escolher, a app pergunta **qual dos selecionados fica** — os outros passam a ser produtos de
  compra dele (receitas, fichas, stock e faturas seguem tudo) e vão para a lixeira, tal como já acontecia ao
  juntar um a um.
- Testado manualmente: 3 ingredientes selecionados → escolher qual fica → confirmar → só o escolhido fica na
  lista ativa, os outros dois aparecem na Lixeira.

## 1.28.0 — 2026-09-28 — Barra de topo redesenhada + comparação de fornecedores nas compras

- **Barra de topo mais limpa e consistente em toda a app**: o botão de ajuda (?), as notas da página e a
  sugestão/erro deixam de ser 3 ícones separados e passam a viver atrás de **um só botão** (o "?", com a
  bolinha de notas por resolver quando há alguma) — abre uma folha com a explicação da página e, lá dentro,
  "Notas desta página" e "Sugestão ou reportar erro". Nada foi removido, só reorganizado.
- O botão de ajuda (?) fica sempre na mesma posição — a última à direita — em **todas** as páginas da app
  (antes a ordem variava de página para página).
- Em **Ingredientes**, as ações menos usadas (Juntar marcas/fornecedores, Preencher nutrição pela INSA,
  Importar CSV) passam a viver atrás de um único menu (⋮), em vez de 3 ícones soltos — a barra de topo fica
  com metade dos ícones.
- **Conteúdo dos botões de ajuda atualizado**: todas as páginas que ganharam funcionalidades novas nas
  últimas versões (ordenar/filtrar, categorias de receitas, marcas/fornecedores, notas por página, faturas em
  lote, uso individual/múltiplo nas embalagens, etc.) agora explicam essas funcionalidades — a ajuda estava
  desatualizada em relação à app.
- **Lista de compras — comparação de fornecedores**: ao escolher, para adicionar, um ingrediente que já
  compras a mais do que um fornecedor, aparece um aviso a dizer **qual é o mais barato e quanto poupas** (ex.
  "Makro é o mais barato — €1,20/kg · poupas 27% vs Continente"). Um ícone de informação abre a comparação
  completa, do mais barato ao mais caro, por kg/L/unidade consoante o ingrediente.

## 1.27.0 — 2026-09-28 — Ordenar e filtrar nas listas

- Novo botão de **ordenação** (ícone de seta, junto à ajuda) nos ecrãs de lista: Faturas, Ingredientes,
  Receitas, Produtos, Fichas Técnicas, Vendas, Encomendas, Limpeza e insumos e Embalagens. Toca num critério
  para ordenar por ele (nome, preço/custo, valor, data, categoria, fornecedor…); toca outra vez para inverter
  a ordem (crescente/decrescente).
- **Filtros novos** onde ainda não havia: Faturas ganha chips por estado (nova/analisada/confirmada/erro/
  ignorada); Fichas Técnicas ganha chips por categoria; Vendas ganha chips por origem (manual/CSV/Vendus);
  Encomendas ganha um chip "Urgentes". Os filtros já existentes (pesquisa, categorias de receitas, fornecedor
  de ingredientes, etc.) mantêm-se tal como estavam.
- Nas Faturas, a ordenação aplica-se dentro de cada grupo de mês (os meses continuam do mais recente para o
  mais antigo).
- Novo widget reutilizável `SortMenuButton` (`lib/src/core/widgets/sort_menu_button.dart`) para não repetir
  esta lógica ecrã a ecrã.

## 1.26.0 — 2026-09-28 — Categorias de receitas editáveis

- **As categorias de receitas deixam de ser uma lista fixa** (Massa/Recheio/Cobertura/Outra, presa no código) e
  passam a ser geríveis por empresa — criar, renomear, desativar, apagar — tal como já acontece com os
  Formatos de cookie. Novo ecrã **Configurações → Categorias de receitas**.
- As 4 categorias que já existiam ficam automaticamente criadas (semeadas) em todas as empresas, com o mesmo
  nome (só com maiúscula inicial) — as receitas que já tinhas continuam exatamente com a categoria que tinham,
  nada muda visualmente.
- Uma categoria "inativa" continua nas receitas que já a têm, mas deixa de aparecer para escolher numa receita
  nova. Apagar uma categoria não apaga nem desliga as receitas que já a usavam (só deixam de a poder escolher
  de novo).
- O filtro de categorias no ecrã de Receitas passa a mostrar só as categorias que as tuas receitas realmente
  usam (antes eram sempre as mesmas 4, mesmo sem nenhuma receita nelas).
- Migration `1707955220_categorias_receita` (nova coleção + `receitas.categoria` passa de lista fixa para
  texto livre, com os valores antigos convertidos).
- Testes: `test/categoria_receita_test.dart`, `test/migration_test.dart`/`test/receita_csv_test.dart`/
  `test/recipe_detail_test.dart` atualizados; a suite de segurança cobre `categorias_receita` automaticamente
  (isolamento entre empresas, como já faz com todas as coleções por empresa).
- A migração foi testada a sério contra os teus dados reais (confirmado: "Massa Base" → categoria "Massa",
  "Bolo" → categoria "Outra", e as 4 categorias semeadas em cada uma das tuas empresas).

## 1.25.0 — 2026-09-28 — Notas por página

- **Notas de equipa em qualquer página.** Novo ícone (nota adesiva) ao lado do botão de sugestão/erro, em toda
  a app: qualquer pessoa da empresa (mesmo quem só lê) escreve uma nota para avisar a equipa de algo nessa
  página — um problema, uma decisão, o que falta — sem precisar de falar por fora da app. Fica visível a toda
  a gente da empresa (diferente do botão de sugestão/erro, que só a equipa de desenvolvimento vê). Marca-se
  como resolvida (fica registado quem e quando) e some do selo de contagem no ícone; o texto/página de uma
  nota não se alteram depois de criada.
- Nova coleção `notas_pagina` (migration `1707955219_notas_pagina`) e o hook `notas_pagina.pb.js` que carimba
  autor/data no servidor (nunca confia no que o cliente manda para esses campos).
- Testes: `test/nota_pagina_test.dart` e nova secção "8g. Notas de página" em `test/security/seguranca.py`
  (isolamento entre empresas, quem cria/resolve/apaga, texto imutável depois de criada).

## 1.24.0 — 2026-09-28 — Ignorar faturas em lote, corrigir linhas e administrador nas faturas

- **Bug corrigido: o botão "Enviar" da sugestão/erro ficava sempre desativado.** Escrever a nota não bastava —
  faltava o ecrã voltar a olhar para o texto escrito. Agora funciona: escreves e o botão liga-se.
- **Selecionar várias faturas e marcar como "Ignorada".** Para faturas antigas que só interessa ter o ficheiro
  digitalizado — ninguém vai decidir preço/stock com elas. Ícone "Selecionar" no topo de Faturas: marca as que
  quiseres e "Marcar como ignorada". Não apaga nada; reabrir uma e decidir qualquer linha tira-a sozinha desse
  estado.
- **Na revisão de uma fatura**: já dá para **remover uma linha** (duplicada, lida a mais pela IA) — desaparece
  da lista e nunca mexe em preço/stock — e para **acrescentar um item em falta** que a IA não leu, preenchido à
  mão como qualquer linha normal.
- **O administrador passa a poder corrigir e apagar faturas** (fornecedor, número, data, totais) — antes só o
  proprietário conseguia, o que obrigava a reportar o problema por fora da app quando quem estava a usá-la era
  um administrador. Continua tudo registado no histórico, com quem fez o quê.
- Migrations `1707955217_faturas_ignorar_lote` (`faturas.estado` ganha o valor `ignorada`) e
  `1707955218_faturas_editar_admin` (regras de `faturas` passam a aceitar `owner` ou `admin`).
- Novo endpoint `POST /api/gc_turnkey/faturas/ignorar-lote`.
- Testes: `test/invoice_ia_parse_test.dart` (estado "ignorada") e três secções novas em
  `test/security/seguranca.py` — "8e. Ignorar faturas em lote" (papéis, isolamento, apagadas, reversão ao
  decidir uma linha), "8f. Linha acrescentada à mão" (o total de linhas sobe com ela — não fica confirmada
  antes de tempo), e o administrador acrescentado a "8c. Editar e apagar faturas".

## 1.23.0 — 2026-09-28 — Juntar marcas/fornecedores repetidos

- **Corrigir nomes duplicados de marca/fornecedor.** A mesma marca/fornecedor real acaba às vezes com vários
  nomes ligeiramente diferentes — escritos à mão de formas diferentes, ou lidos por IA de faturas diferentes
  do mesmo fornecedor (ex.: "Recheio", "Recheio Cash & Carry, S.A.", "Recheio Cash & Carry, SA"). Novo ecrã
  **"Juntar marcas/fornecedores"** (ícone no topo de Ingredientes, e atalho junto ao filtro de fornecedor):
  escolhe os que são o mesmo, escreve o nome final, e todos os produtos de compra, consumíveis e embalagens
  que tinham esses nomes passam a ter o nome escolhido — de uma vez, em toda a empresa. Só proprietário e
  administrador (pode alterar muitos registos de uma vez).
- **Simplificar, para não voltar a acontecer**: espaços a mais (duplos, tabs) na marca/fornecedor — quer
  escritos à mão quer lidos pela IA de uma fatura — passam a ser normalizados para um só espaço antes de
  gravar, tanto ao aplicar faturas como ao corrigir. Nunca junta nomes diferentes sozinho — isso continua a
  ser sempre uma escolha da pessoa, na ferramenta de juntar.
- Novo endpoint `POST /api/gc_turnkey/marcas-fornecedores/juntar` (`pb/hooks/marcas_fornecedores.pb.js`).
- Testes: nova secção "9a. Juntar marcas/fornecedores repetidos" em `test/security/seguranca.py` — papéis
  (editor/viewer recusados), isolamento entre empresas, validação, junção a sério (produtos + embalagem +
  sincronização do ingrediente genérico), normalização de espaços e marca vs. fornecedor.

## 1.22.0 — 2026-09-28 — Marca/fornecedor sincronizados, sugestões e maiúscula inicial

- **Bug corrigido: a marca e o fornecedor não apareciam na lista de Ingredientes.** Ao aplicar uma fatura, a
  marca/fornecedor ficavam gravados no **produto de compra** (a marca específica), mas o ingrediente genérico
  — o que aparece na lista, na pesquisa e no filtro por fornecedor — nunca era atualizado. Agora, sempre que um
  produto de compra muda (aplicar fatura, editar em "Produtos de compra", ou corrigir a marca), o ingrediente
  genérico sincroniza a marca/fornecedor **do produto com a compra mais recente** — o mesmo produto que já
  manda no custo. Nunca apaga marca/fornecedor já preenchidos só porque o produto mais recente vem em branco.
- **Vários fornecedores por ingrediente**: já existia (ecrã "Produtos de compra", dentro de cada ingrediente) —
  lista todas as marcas/embalagens compradas, cada uma com o seu fornecedor e data, e assinala com "custo
  atual" a que manda no preço (a mais recente). Não havia bug aqui; ficou mais visível com a sincronização
  acima.
- **Fornecedor: um só por fatura.** Corrigir o fornecedor deixou de se pedir linha a linha — corrige-se **uma
  vez no cabeçalho da fatura** (lápis, proprietário) e propaga-se sozinho a todos os produtos/consumíveis/
  embalagens que essa fatura já tinha tocado. O endpoint `/corrigir-item` passa a corrigir só a **marca**
  (continua disponível a proprietário e administrador, mesmo com a linha já aplicada).
- **Marca e fornecedor com sugestões**: os campos de marca e de fornecedor (Ingredientes, Produtos de compra,
  Embalagens, Consumíveis, revisão de faturas, cabeçalho da fatura) mostram agora os valores já usados na
  empresa para escolher — sem nunca obrigar: continua a dar para escrever um valor novo à mão.
- **Maiúscula inicial sempre.** Nomes de ingredientes, produtos de compra, consumíveis, embalagens, kits,
  formatos de cookie, receitas, fichas técnicas, custos fixos e equipamento passam a começar sempre por
  maiúscula ao gravar (`capitalizarInicial`), sem mexer no resto do texto escrito.
- Testes: `test/capitalizar_test.dart` (regra da maiúscula inicial) e nova secção em
  `test/security/seguranca.py` que confirma a sincronização do genérico (na 1ª e na 2ª fatura, e ao corrigir a
  marca) e o novo comportamento do `/corrigir-item` (só marca) e da propagação do fornecedor pelo cabeçalho.

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
