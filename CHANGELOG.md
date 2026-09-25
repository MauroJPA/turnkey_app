# Changelog — turnkey_app

Versões da app (Flutter) + schema/hooks do PocketBase. Datas em AAAA-MM-DD.

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
