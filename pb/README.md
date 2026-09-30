# PocketBase — schema e hooks do `gc_turnkey`

Servidor alvo: **PocketBase v0.35.0** (Mini PC Linux, acedido via Tailscale).

```
pb/
  migrations/   # schema como código (JS). Aplica-se com `pocketbase migrate`
  hooks/        # lógica server-side (cascata de custos + histórico) — copiar para pb_hooks/
  seed/         # dados de exemplo p/ dev + script de migração do meu_app_ia
```

## Desenvolvimento local

1. Descarregar o binário do PocketBase **v0.35.0** para `pb/bin/` (ignorado pelo git).
2. Ligar as migrations e hooks deste repo à pasta de dados local:
   ```
   cd pb
   ./bin/pocketbase serve --dir=./pb_data --migrationsDir=./migrations --hooksDir=./hooks
   ```
   (no Windows: `bin\pocketbase.exe serve --dir=.\pb_data --migrationsDir=.\migrations --hooksDir=.\hooks`)
3. Criar o primeiro superuser quando pedido; o Admin UI fica em `http://127.0.0.1:8090/_/`.
4. Correr a app apontada a este servidor:
   ```
   flutter run --dart-define=PB_URL=http://127.0.0.1:8090
   ```

## Servidor de produção (Mini PC)

- Copiar `pb/migrations/*` para o `pb_migrations/` do servidor e reiniciar — as
  migrations por aplicar correm no arranque.
- Copiar `pb/hooks/*` para o `pb_hooks/` do servidor e reiniciar.
- **Nunca** commitar credenciais de admin nem `pb_data/`.

## Estado (validado contra PocketBase 0.35 local)

| Migration | Conteúdo |
|---|---|
| `1704067200_base_collections.js` | `empresas`, `users.empresa/papel/nome`, `configuracoes_custo` |
| `1704153600_ingredientes.js` | `ingredientes` |
| `1704240000_receitas.js` | `receitas`, `itens_receita`, `ingredientes.receita_espelho` |
| `1704326400_historico.js` | `historico` (só o servidor escreve) |
| `1704412800_timestamps.js` | campos `autodate` `created`/`updated` nas coleções de negócio |
| `1704499200_fichas_tecnicas.js` | `fichas_tecnicas`, `itens_ficha` |
| `1704585600_equipa_regras.js` | regras de equipa/papéis |
| `1704672000_fix_config_rule.js` | correção de regra em `configuracoes_custo` |
| `1704758400_receita_procedimento.js` | `receitas.procedimento` |
| `1704844800_inventario.js` | `inventario`, `movimentos_inventario` (só o servidor escreve) |
| `1704931200_producoes.js` | `producoes`, `producao_itens`, `movimentos_inventario.producao` |
| `1705017600_lista_compras.js` | `lista_compras` |
| `1705104000_formatos_cookie.js` | `formatos_cookie` + seed Mini/Recheado/Simples por empresa |
| `1705190400_producao_itens_agenda.js` | `producao_itens`: `formato`, `recheio`, `prioridade`, `hora_limite`, `unidades_previstas` |
| `1705276800_fichas_formato.js` | `fichas_tecnicas.formato` |
| `1705363200_receitas_imagens.js` | `receitas.imagens` (file, ≤8, image/*) |
| `1705449600_lista_compras_embalagem.js` | `lista_compras.embalagem_g` |
| `1705536000_lista_compras_custo.js` | `lista_compras.custo_estimado` |
| `1705622400_empresas_tema.js` | `empresas.tema` (sistema/claro/escuro) |
| `1705708800_lista_compras_extra.js` | `lista_compras`: `notas`, `unidade` (itens manuais) |
| `1705795200_inventario_itens_livres.js` | `inventario`/`movimentos_inventario`: `descricao`, `unidade` (itens livres) + índice `(empresa, descricao)` |
| `1705881600_sugestoes.js` | `sugestoes` (qualquer utilizador cria; só a Admin UI lê) |
| `1705968000_faturas.js` | `faturas` (foto + `dados_ia` + `estado`), `faturas_itens` (linhas emparelhadas com ingredientes) — ambas só escritas por endpoint |
| `1706054400_material_loja.js` | `categoria` em `lista_compras` / `inventario` / `movimentos_inventario` (material da loja: equipamentos, consumíveis, mobiliário…) |
| `1706140800_nutricao.js` | `ingredientes`: 8 valores nutricionais (por 100 g/ml) + `nutri_base`/`nutri_densidade`/`nutri_origem`/`nutri_atualizado_em` + `alergenios`/`alergenios_tracos` (os 14 da UE). `receitas`: `perda_cozedura_pct` + cache JSON `nutri`. `fichas_tecnicas`: cache JSON `nutri`. Nova coleção partilhada `ingredientes_referencia` (só-leitura). |
| `1706227200_seed_insa.js` | semeia `ingredientes_referencia` com 1376 alimentos da **INSA BDCA v7.1 (2026)** (idempotente; nome normalizado sem acentos em `sinonimos`). |
| `1706313600_embalagens.js` | coleção `embalagens` (caixas, sacos, saquetas, adesivos… com `preco_compra`/`unidades_compra`/`rende_unidades` → `custo_unitario` cache) + relação opcional `itens_ficha.embalagem` + valor `embalagem` no `slot`. |
| `1706400000_historico_faturas.js` | adiciona `faturas_apagadas` aos valores de `historico.entidade_tipo` (rasto das faturas apagadas, `entidade_id = <empresaId>`). |
| `1706486400_embalagem_kits.js` | coleções `embalagem_kits` (nome, descrição, `custo_unitario` cache) + `embalagem_kit_itens` (`kit`, `embalagem`, `quantidade`) + relação opcional `itens_ficha.kit`. Um kit junta várias embalagens numa combinação com nome; na ficha técnica escolhe-se o kit para precificar de uma vez. |
| `1706572800_ref_alergenios.js` | campo `alergenios` em `ingredientes_referencia`, preenchido por inferência de palavras-chave sobre nome/grupo (match por token com plurais; expressões multi-palavra por substring; guardas p/ "chocolate"≠"choco", "compota"≠"pota", farinha de milho/arroz sem glúten). Sugestão, não oficial. |
| `1706659200_inventario_uso.js` | `inventario`: `favorito` (bool), `usos` (number), `ultimo_uso` (date). `usos`+`ultimo_uso` são incrementados por `cascade.js aplicarMovimento` (motivos `consumo_producao`/`saida_producao`) e por `inventario_uso.pb.js` (`onRecordAfterCreateSuccess` em `lista_compras`). `favorito` grava-se via `/api/gc_turnkey/inventario/ajustar`. Vistas "Favoritos" e "Mais usados" no ecrã de Inventário. |
| `1706745600_users_authalert_off.js` | desliga o email "Login from a new location" da coleção `users` (ERP interno; SMTP muitas vezes ausente). |
| `1706832000_ingrediente_nutri_foto.js` | campo `nutri_foto` (file, thumb 0x240) em `ingredientes` — foto da tabela nutricional do rótulo. A lista de ingredientes distingue visualmente `Ingrediente.fonteNutri`: vazia / por rever (INSA) / INSA / à mão / à mão+foto. |
| `1706918400_empresas_personalizacao.js` | `empresas`: `cor_secundaria`/`cor_fundo`/`cor_texto` (hex, opcionais — vazio = derivado automaticamente da cor de marca); `logo_oculto`/`logo_alinhamento`/`logo_tamanho` e `nome_oculto`/`nome_alinhamento`/`nome_tamanho` (posição/tamanho/visibilidade do logótipo e do nome na barra superior — bool guarda o "oculto", não o "visível", porque o valor por omissão de um campo bool é `false`); `fonte_familia` (text) + `fonte_ficheiro` (file, .ttf/.otf) para tipo de letra personalizado. |
| `1707004800_vendas.js` | `fichas_tecnicas.preco_venda` (number — preço real definido pelo utilizador; até aqui só existia o preço *sugerido*, calculado ao vivo a partir de `configuracoes_custo`, nunca persistido). Coleções `vendas` (`data`, `origem`: manual/csv/vendus, `total` cache, `numero_documento`, `notas`) e `vendas_itens` (`venda`, `ficha` opcional, `descricao`, `quantidade`, `preco_unitario`, `total_linha` cache, `custo_unitario_snapshot`) — base do painel financeiro/DRE e da análise de sabores mais vendidos (Financeiro, F-FIN-1). `historico.entidade_tipo` ganha o valor `venda`. |
| `1707091200_custos_fixos.js` | Coleção `custos_fixos` (Financeiro, F-FIN-2) — custos reais e recorrentes (aluguel, salários…) em valor mensal, `tipo` fixo/variável, `arquivado` (guarda o "arquivado", não o "ativo", pelo mesmo motivo do `logo_oculto`). Diferente dos percentuais de `configuracoes_custo`, que só sugerem o preço de venda. |
| `1707177600_vendus.js` | `vendas.vendus_id` (Financeiro, F-FIN-6) — identifica o documento de origem no Vendus; índice único por empresa **só quando não vazio** (`WHERE vendus_id != ''`), para não afetar vendas manuais/CSV. `empresas.vendus_ultima_sincronizacao` guarda a data do documento mais recente já importado (base do `since` da sincronização seguinte). |
| `1707264000_equipamentos.js` | Coleção `equipamentos` (Financeiro, F-FIN-7) — equipamento da loja (`nome`, `custo`, `vida_util_anos`, `arquivado`); a depreciação mensal (`custo / (vida_util_anos * 12)`) é calculada no cliente, não guardada, para nunca ficar desatualizada. `custos_fixos.dia_pagamento` (number, opcional, 1-31) — só para o lembrete "Pagamentos por vir" no Início, não entra em nenhum cálculo. |
| `1707350400_encomendas.js` | Coleções `encomendas` (cliente, `data_hora`, `estado` nova/em_producao/pronta/entregue/cancelada, `valor_total`/`valor_pago` — 0 = sem valor informado, o estado do pagamento é derivado no cliente, nunca guardado) e `encomendas_itens` (ficha técnica + quantidade). `configuracoes_encomendas` (1 linha por empresa, opcional): tamanho do talão (térmico 80mm/A4), impressão automática ao criar, horas de antecedência do lembrete "Encomendas por vir" no Início. `historico.entidade_tipo` ganha o valor `encomenda`. Talão impresso reutiliza `core/printing/print_html.dart` (Blob + `window.open`) e mostra também o estado do pagamento, pois segue a encomenda até ao cliente. |
| `1707436800_navegacao.js` | `configuracoes_navegacao` (1 linha por empresa, opcional): `rodape` (chaves das páginas da barra inferior, por ordem) e `acesso` (matriz papel → página → `oculto`/`ver`/`editar`); todos leem, owner/admin escrevem o `rodape`, **só o owner** escreve `acesso` (regra `@request.body.acesso:isset = false` para o admin). `preferencias_utilizador` (1 linha por pessoa): `oculto` (atalhos escondidos na grelha do Início) e `cores` (cor de cada botão) — cada pessoa só vê/edita a sua. As permissões por página são aplicadas na app (esconder/bloquear); o PocketBase continua a aplicar as regras por papel. |
| `1707523200_producao_item_ficha.js` | `producao_itens.ficha` (relação para `fichas_tecnicas`): o produto final escolhido em Produzir / Mise en place. Quando preenchida manda sobre a resolução automática massa + recheio + formato e as unidades vêm da massa por unidade da própria ficha (`cascade.infoFicha`). Endpoint novo `GET /api/gc_turnkey/fichas/{id}/plano?unidades=N` (massa + recheios + coberturas a produzir primeiro e ingredientes). `/producoes/{id}/plano`, `/lista-compras` e `/concluir` respeitam a ficha explícita. |

Aparência (tema, distribuição de cores, logótipo, nome da marca — posição/
tamanho/visibilidade — e tipo de letra) é **por empresa** — editada em
Configurações → Aparência, aplica-se a toda a equipa. O tipo de letra
personalizado carrega-se em runtime no cliente via `dart:ui`'s
`loadFontFromList` (sem pacote `google_fonts`, para não depender de internet
no Mini PC); sem ficheiro enviado, usa-se a fonte do sistema.

**Vendas** — registo manual (`vendas`/`vendas_itens`), importação de CSV
(`data,produto,quantidade,preco_unitario`; cada linha liga-se à ficha técnica
de nome mais parecido — `melhorMatchFicha`, mesma lógica Jaccard usada para
as faturas — ou fica só com a descrição, sem travar a importação), ou
sincronização com o **Vendus** (`vendus.pb.js`/`vendus_core.js`, F-FIN-6):
botão "Sincronizar com o Vendus" no ecrã de Vendas + cron horário
(`vendus_sync`), ambos chamam `sincronizarEmpresa()` — busca documentos de
venda (`FT`/`FS`/`FR`/`FG`, `status=N`) desde `empresas.vendus_ultima_sincronizacao`,
emparelha cada linha à ficha técnica pelo nome (mesmo `melhorMatchFicha`, agora
portado para JS em `vendus_core.js` — tem de ficar igual à versão Dart em
`match_ficha.dart`, qualquer ajuste ao algoritmo faz-se nos dois sítios), e
regista `vendas`/`vendas_itens` (`origem='vendus'`). Documentos já importados
(por `vendus_id`) são ignorados — idempotente, seguro correr o cron ou o
botão manual quantas vezes for preciso. Sem `VENDUS_API_KEY`: `503` no botão,
o cron só regista no log e tenta de novo na hora seguinte. Ecrã Início →
Vendas.

⚠️ **Filtro de datas do PocketBase compara literais pelo formato completo**
(`yyyy-MM-dd HH:mm:ss.SSSZ`), não semanticamente — uma data "nua" como
`data <= "2026-09-14"` falha silenciosamente contra um valor guardado
`"2026-09-14 00:00:00.000Z"` (comparação de string: a string mais curta fica
sempre "menor"). Qualquer filtro `>=`/`<=` sobre um campo `date`/`datetime`
tem de incluir a hora completa (`00:00:00.000Z` no início do intervalo,
`23:59:59.999Z` no fim) — ver `SalesRepository.list()`.

Hooks: `onboarding.pb.js` (semeia `configuracoes_custo` + `formatos_cookie`),
`guards.pb.js`, `cost_cascade.pb.js`, `team.pb.js`, `inventario.pb.js`,
`faturas.pb.js`, `nutricao.pb.js`, `receitas_ia.pb.js`, `admin.pb.js` (+
`cascade.js`, que exporta `runCascade` — agora também calcula/cacheia `nutri`
de receitas/fichas e a união de alergénios —, `explodeCompras`,
`explodeProducao`, `explodeComprasDe`, `aplicarMovimento`, `carregarProducao`,
`resolverFicha`; + `ai.js`, que exporta
`analisarImagemIA({ tarefa: 'fatura' | 'rotulo' | 'receita' })`).

`dev_autoverify.pb.js`: **só em dev** — com `GC_TURNKEY_DEV=1` no ambiente, as
contas `users` novas ficam logo `verified` (não é preciso email/SMTP para
entrar). O `pb/serve.ps1` local já põe `GC_TURNKEY_DEV=1`; em produção não
defina esta variável. (O login em si nunca depende de `verified` — o
`authRule` da coleção `users` é vazio — mas isto evita o estado
"não verificado" enquanto se desenvolve.)

### Variáveis de ambiente do servidor — IA de faturas

A análise de faturas (`faturas.pb.js` → `ai.js`) tem o **fornecedor de IA
selecionável por variável de ambiente**, sem tocar no código.

| Variável | Para quê |
|---|---|
| `GC_TURNKEY_AI_PROVIDER` | `gemini` (por omissão) ou `anthropic`. |
| `GEMINI_API_KEY` (ou `GOOGLE_API_KEY`) | chave do Google AI Studio — usada quando o provider é `gemini`. De <https://aistudio.google.com/app/apikey>. Tem plano **gratuito**. |
| `ANTHROPIC_API_KEY` | chave da Anthropic — usada quando o provider é `anthropic`. De <https://console.anthropic.com/>. |
| `GC_TURNKEY_AI_MODEL` | opcional; modelo a usar. Por omissão `gemini-3.6-flash` (gemini) ou `claude-sonnet-5` (anthropic). A Google descontinua modelos periodicamente — se `/analisar` devolver `502 "model ... is no longer available"`, põe aqui o modelo novo (ex.: `gemini-3.8-flash`). |

Sem a chave do provider ativo, `/analisar` devolve `503` com mensagem clara e a
app mostra "IA não configurada". As chaves vivem **só no servidor** — a app
Flutter nunca as vê. **Adicionar um fornecedor novo**: uma função `pedir<Nome>()`
em `ai.js` + um ramo no `switch` (instruções no topo do ficheiro).

Em dev, o `pb/serve.ps1` carrega estas variáveis de um ficheiro `pb/.env`
(fora do git — ver `pb/.env.example`). Em produção, definir no serviço
(NSSM `AppEnvironmentExtra` no Windows, `Environment=`/`EnvironmentFile=` no
systemd). Detalhe em [`DEPLOY.md`](DEPLOY.md).

**Scanner de faturas** (`faturas_scan.pb.js`): com `GC_TURNKEY_SCAN_DIR` (pasta
que o scanner alimenta por *scan-to-folder*) + `GC_TURNKEY_SCAN_EMPRESA` (id da
empresa), um cron a cada 5 min cria uma `faturas` (`estado='nova'`,
`notas='Scanner: <ficheiro>'`) por cada JPG/PNG/WebP/PDF, chama
`faturas_core.js analisarFatura` e move o original para `<pasta>/processadas/`.
Sem chave de IA a fatura fica em `nova` para revisão manual. O painel inicial
mostra "Faturas por rever" quando há faturas `nova`/`analisada`.

**Envio ao contabilista** — a app tem, em Faturas → ícone de pasta, um email
configurável (`empresas.email_contabilidade`) e um botão "Enviar por email"
(todas as faturas confirmadas, ou só um período), além de "Baixar ZIP"
(zipado no browser, a partir dos ficheiros individuais). Lógica partilhada em
`faturas_export.js`. Também há um **cron mensal** (`faturas_contab.pb.js`,
`0 8 1 * *`) que faz o mesmo envio sozinho, do mês anterior — usa
`empresas.email_contabilidade` se estiver definido, senão a variável de
ambiente `GC_TURNKEY_CONTAB_EMAIL` (mantida por compatibilidade). Requer SMTP
configurado no Admin UI em qualquer dos casos.

**Sincronização com o Vendus** (`vendus.pb.js`/`vendus_core.js`, F-FIN-6):

| Variável | Para quê |
|---|---|
| `VENDUS_API_KEY` | API KEY gerada em Apps → API na conta Vendus. Sem ela, `/sincronizar` devolve `503` e o cron horário não faz nada (só regista no log). |
| `VENDUS_SYNC_EMPRESA` | id da empresa para o **cron horário** (`vendus_sync`, `0 * * * *`) — o cron não tem sessão de utilizador, por isso precisa de saber a que empresa pertence (mesmo papel de `GC_TURNKEY_SCAN_EMPRESA` no scan de faturas). O botão manual "Sincronizar com o Vendus" na app usa a empresa de quem está autenticado, não precisa desta variável. |

A chave nunca chega à app — só o servidor fala com `https://www.vendus.pt/ws/v1.1/`.
Documentos já importados (`vendus_id`) nunca se repetem; correr o botão manual
com o cron ativo ao mesmo tempo é seguro.

### Endpoints (Fase 2 — `inventario.pb.js`)

Todos exigem `requireAuth('users', '_superusers')`; um `users` não-viewer só age
sobre a sua empresa.

| Método | Rota | Efeito |
|---|---|---|
| `POST` | `/api/gc_turnkey/inventario/ajustar` | `{ ingrediente?\|ficha?\|descricao?(item livre) + unidade? + categoria?, delta, motivo, notas?, producao?, minimo?, localizacao? }` → upsert da linha `inventario` (`quantidade = max(0, q+delta)`) + `movimentos_inventario`. `categoria` é o "material da loja" (ver `kCategoriasMaterial`). `delta` 0 é aceite se vier `minimo`/`localizacao`/`unidade`/`categoria`. |
| `GET` | `/api/gc_turnkey/fichas/resolver` | `?massa=&formato=&recheio=` → ficha técnica correspondente + `componentes:[{slot,nome,gPorUnidade}]` (recheios/coberturas/extra) ou `{fichaId:''}`. |
| `GET` | `/api/gc_turnkey/producoes/{id}/plano` | explosão agregada (sub-receitas + espelhos de fabrico próprio + **recheio do formato**: `N = round(kg·1000/massa_g)`, `N·recheio_g` do recheio) → `{ necessarios:[{ingredienteId,nome,fornecedor,gramas,custo,emStock,aComprar,embalagemG,aComprarSacos}], produzir:[{receitaId,nome,kg,unidades,formato,recheio,prioridade,horaLimite}], custoTotal }`. |
| `POST` | `/api/gc_turnkey/producoes/{id}/lista-compras` | mesma agregação → upsert em `lista_compras`; `quantidade_necessaria_g` = necessidade exata, `quantidade_comprar_g` = `ceil(falta/embalagem)·embalagem` (sacos inteiros), grava `embalagem_g` → `{ linhas }`. |
| `POST` | `/api/gc_turnkey/producoes/{id}/concluir` | por `producao_item`: consome a massa (`kg`, escalada por %) e — se `resolverFicha` encontrar a ficha do (massa+formato) — todos os slots não-massa da ficha (recheio_base/top, cobertura_base/top, extra) a `N·quantidade_g`, creditando `+N` unidades no `inventario` da ficha. Sem ficha: usa o `recheio` indicado à mão (se houver) e entra em `faltas`. Itens sem `formato` mantêm o crédito do ingrediente-espelho. Grava `unidades_previstas`, `estado=concluida`, `concluida_em`, `custo_snapshot` → `{ consumos, saidas, faltas, custoTotal }`. |

### Endpoints (Fase 5 — `faturas.pb.js`)

Auth `users` não-viewer (ou superuser); só agem sobre a empresa do autor.

| Método | Rota | Efeito |
|---|---|---|
| `POST` | `/api/gc_turnkey/faturas/{id}/analisar` | body `{ imagem: <base64>, mime }`. Via `ai.js` (`GC_TURNKEY_AI_PROVIDER`: `gemini` por omissão, ou `anthropic`) envia a imagem/PDF ao modelo de visão com um prompt que extrai `{ fornecedor, data, numero, total, iva, moeda, linhas:[{descricao, quantidade, unidade, preco_unitario, total, embalagem_g}] }`. Grava em `faturas.dados_ia`, `estado='analisada'`, pré-preenche `fornecedor/numero/total/iva/data_fatura` se vazios. Devolve `{ estado, provider, dados }`. Sem a chave do provider ativo → `503` (não mexe na fatura). Erro de rede/IA/JSON → `estado='erro'`, `dados_ia.erro`, `502`. **Dedup**: se já existir outra `faturas` (`tipo='fatura'`, `estado!='erro'`) da mesma empresa com o mesmo fornecedor + número (ou, sem número, mesmo fornecedor + data + total), marca `estado='erro'`, `dados_ia.duplicada_de=<id>` e devolve `409`. |
| `POST` | `/api/gc_turnkey/faturas/{id}/aplicar` | body `{ linhas:[{ ingredienteId?, descricaoFatura, quantidadeG, precoUnitario, totalLinha, embalagemG, acao }] }` (`acao` ∈ `preco\|stock\|ambos\|ignorar`). Numa transação: apaga `faturas_itens` anteriores; por linha com ingrediente e `acao≠ignorar` — `preco/ambos` → **só** atualiza `ingredientes.preco` (+`gramas_embalagem`) quando `data_fatura` (ou `created`) ≥ `ingredientes.preco_atualizado_em` (uma fatura antiga não estraga um preço mais recente); ao atualizar, carimba `preco_atualizado_em` com a **data da fatura**; dispara a cascata de custos. `stock/ambos` → `cascade.aplicarMovimento(+quantidadeG, 'compra', notas:'Fatura <nº>')` (sempre, mesmo com fatura antiga). Recria `faturas_itens`, `faturas.estado='confirmada'` → `{ precos, precosIgnorados, movimentos }`. |
| `GET` | `/api/gc_turnkey/faturas/export?de=&ate=` | faturas `confirmada` no intervalo (em falta = todas) → `{ faturas:[{ id, fornecedor, dataFatura, numero, total, iva, nomeFicheiro, ficheiroUrl, linhas:[...] }] }`. `nomeFicheiro` = `FT-NOMEFORNECEDOR-DDMMAAAA.ext` (nome canónico p/ contabilidade). A app usa isto para montar o ZIP no browser (baixa cada `ficheiroUrl` e junta). |
| `POST` | `/api/gc_turnkey/faturas/enviar-contabilidade` | body `{ de?, ate?, email? }` (`de`/`ate` em falta = todas as faturas confirmadas). Envia por email (SMTP do Admin UI) com os ficheiros em anexo + `resumo.csv`. Se vier `email`, grava-o em `empresas.email_contabilidade` para a próxima vez (e para o cron mensal). `400` sem faturas no período ou sem email configurado. → `{ quantidade, total }`. |

O ficheiro carregado é guardado com um nome no formato **`FT-NOMEFORNECEDOR-DDMMAAAA`** (data da fatura). O PocketBase normaliza (minúsculas, `_`, sufixo aleatório) ao gravar; o nome canónico exacto para a contabilidade vem no campo `nomeFicheiro` do `/export`.

### Endpoint (Financeiro — `vendus.pb.js`)

| Método | Rota | Efeito |
|---|---|---|
| `POST` | `/api/gc_turnkey/vendus/sincronizar` | Auth `users` não-viewer. Busca documentos de venda novos no Vendus (desde `empresas.vendus_ultima_sincronizacao`), emparelha cada linha à ficha técnica pelo nome e grava `vendas`/`vendas_itens` (`origem='vendus'`). Devolve `{ vendasCriadas, duplicadasIgnoradas, itensCriados, itensSemFicha }`. `503` sem `VENDUS_API_KEY`. |

### Endpoint (Nutrição — `nutricao.pb.js`)

| Método | Rota | Efeito |
|---|---|---|
| `POST` | `/api/gc_turnkey/ingredientes/{id}/rotulo` | body `{ imagem: <base64>, mime }`. Via `ai.js` lê o rótulo (foto/PDF) → preenche `nutri_*` + `nutri_base`/`nutri_densidade` + `nutri_origem='rotulo'` + os 14 alergénios (canonizados) no ingrediente e grava (a cascata nutricional dispara sozinha). `503` sem chave, `400` sem imagem, `502` erro da IA. |
| `POST` | `/api/gc_turnkey/receitas/ler-imagem` | body `{ imagem: <base64>, mime }`. Via `ai.js` (`tarefa:'receita'`) lê um print/foto de uma lista de ingredientes → `{ provider, nome, categoria, ingredientes:[{nome,quantidade_g}] }`. **Só leitura, não grava nada** — a app (`receitas_import_sheet.dart`, modo "Uma receita") usa o resultado para pré-preencher o formulário, a pessoa revê/corrige e confirma com "Importar" como sempre. `503` sem chave, `400` sem imagem, `502` erro da IA. |
| `POST` | `/api/gc_turnkey/ingredientes/auto-insa` | body `{ ids?: string[], dryRun?: bool }`. Emparelha cada ingrediente (sem `ids`: os da empresa **sem** nutrição) com `ingredientes_referencia` por semelhança de nome (recall+precision de tokens + bónus de palavra-cabeça/prefixo/nome exato). Vencedor destacado (`best≥0.8` e margem `≥0.2`) → grava `nutri_*` + `alergenios` + `nutri_origem='insa'`. Caso contrário → `nutri_origem='insa_revisao'` (não estraga `manual`/`rotulo`/`insa`) e devolve os 6 candidatos mais próximos. `dryRun` não escreve. Resposta `{ aplicados, total, resultados:[{ ingredienteId, nome, estado:'preenchido'|'revisao'|'sem_candidato', referencia?, candidatos:[{id,nome,grupo,score,nutri,alergenios}] }] }`. |

A **nutrição de receitas e fichas é calculada em cascata** (`cascade.js`), como o custo: `receitas.nutri` = valores por 100 g de mistura crua (+ `por100g_cozido` com a perda); `fichas_tecnicas.nutri` = por 100 g de **produto acabado** (a água que sai a cozer não tem calorias — muda o peso) + `por_unidade`, e a **união dos alergénios** de toda a árvore.

**Embalagens**: uma linha `itens_ficha` com `embalagem` (e `slot='embalagem'`) soma `preco_compra / unidades_compra / rende_unidades × quantidade` ao custo da ficha, **sem** contar para o peso nem para a nutrição. O `cost_cascade.pb.js` re-corre as fichas quando o custo da embalagem muda; `custo_unitario` é a cache mantida pelo `runCascade('embalagem', id)`.

**Kits de embalagens**: uma linha `itens_ficha` com `kit` (também `slot='embalagem'`) soma `Σ (custo/un de cada embalagem do kit × quantidade da linha do kit) × quantidade da linha da ficha`, igualmente sem peso nem nutrição. `runCascade('kit', id)` recalcula `embalagem_kits.custo_unitario` (cache) e as fichas que usam o kit; os hooks em `embalagem_kit_itens` disparam-no ao mudar as linhas, e `runCascade('embalagem', id)` também recalcula os kits que contêm a embalagem alterada.

## ⚠️ Regras de escrita de hooks (PocketBase 0.35)

O corpo de cada handler (`onRecord*`) corre **isolado**: NÃO enxerga funções nem
constantes definidas ao nível de topo do próprio ficheiro `.pb.js`. Consequências:

- Cada handler tem de ser **autocontido** (define os seus helpers lá dentro) ou
  carregar lógica com `require(`${__hooks}/<ficheiro>.js`)` **dentro** do handler.
- No módulo carregado por `require`, a visibilidade entre funções de topo também
  se mostrou pouco fiável — por isso `cascade.js` expõe **uma** função
  (`runCascade`) com todos os auxiliares como closures internas.
- `findRecordsByFilter(coll, filter, sort, limit, offset, params)`: passar `''`
  como `sort` (um nome de campo "cru" como `'created'` dá `GoError: invalid sort
  field` a menos que exista mesmo um campo com esse nome).
- Coleções `base` **não** trazem `created`/`updated` — adicionar `autodate`.

## Regras de acesso (multi-empresa)

Todas as coleções de negócio:

| Regra | Expressão |
|---|---|
| list / view | `@request.auth.id != "" && empresa = @request.auth.empresa` |
| create | `@request.auth.id != "" && @request.body.empresa = @request.auth.empresa` |
| update / delete | `@request.auth.id != "" && empresa = @request.auth.empresa` + (M6) papel |

⚠️ **`~`/`!~` são LIKE (substring), não regex.** `papel ~ 'owner|admin'`
**nunca** dá verdade (o pipe é procurado literalmente). Para "papel é X ou Y",
usar sempre o OR explícito: `(@request.auth.papel = 'owner' || @request.auth.papel = 'admin')`.
Já apanhado duas vezes — `1704672000_fix_config_rule.js` (`configuracoes_custo`)
e `1707091200_custos_fixos.js` (`custos_fixos`, corrigido antes de aplicar).
