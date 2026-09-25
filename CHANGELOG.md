# Changelog — turnkey_app

Versões da app (Flutter) + schema/hooks do PocketBase. Datas em AAAA-MM-DD.

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
