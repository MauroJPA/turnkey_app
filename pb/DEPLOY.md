# Aplicar o schema no servidor (Mini PC)

O schema e a lógica de servidor vivem neste repo:

```
pb/migrations/*.js   -> schema (coleções, campos, regras)
pb/hooks/*           -> lógica (cascata de custos, onboarding, equipa, admin)
```

**Para instalar no servidor (Debian + Docker + Tailscale) segue `docs/SERVIDOR_LINUX.md`**
(pacote pronto, arranque automático, HTTPS, backups). Este ficheiro descreve o detalhe do PocketBase
(algumas instruções abaixo são de Windows/systemd e servem só de referência).

As 50 migrations aplicam-se limpas a uma base de dados vazia (verificado). A
`1706227200_seed_insa.js` insere 1376 alimentos na `ingredientes_referencia`
(demora alguns segundos no 1.º arranque; é idempotente).

---

## Pré-requisito

O Mini PC corre **PocketBase v0.40.4** (mínimo seguro: 0.39.7). Confirma:

```bash
./pocketbase --version
```

## Passos

1. **Backup** da base de dados atual do servidor:
   ```bash
   cp -r pb_data pb_data.bak-$(date +%F)
   ```

2. **Copiar as migrations e os hooks** para as pastas que o PocketBase lê
   (por omissão `pb_migrations/` e `pb_hooks/` ao lado do binário):
   ```bash
   cp gc_turnkey/pb/migrations/*.js  <pasta-do-pocketbase>/pb_migrations/
   cp -r gc_turnkey/pb/hooks/*       <pasta-do-pocketbase>/pb_hooks/
   ```
   (inclui `pb_hooks/cascade.js` — é um módulo `require()`d pelos hooks, não um
   hook autónomo, mas tem de estar na mesma pasta.)

3. **Aplicar as migrations** (correm no arranque; ou explicitamente):
   ```bash
   ./pocketbase migrate up
   ./pocketbase serve   # reinicia o serviço (systemd: systemctl restart pocketbase)
   ```

   **Análise de faturas por IA** (`faturas.pb.js` → `ai.js`): o fornecedor de IA
   escolhe-se por `GC_TURNKEY_AI_PROVIDER` — **`gemini`** (por omissão, tem plano
   gratuito) ou `anthropic`. Só é preciso a chave do provider ativo.
   - **Gemini** (agora): chave em <https://aistudio.google.com/app/apikey>
     (começa por `AIza`). Variáveis: `GC_TURNKEY_AI_PROVIDER=gemini`,
     `GEMINI_API_KEY=AIza...`. Saída de internet para
     `generativelanguage.googleapis.com`.
   - **Anthropic** (futuro): chave em <https://console.anthropic.com/> →
     Settings → API keys (`sk-ant-...`). Variáveis: `GC_TURNKEY_AI_PROVIDER=anthropic`,
     `ANTHROPIC_API_KEY=sk-ant-...`. Saída para `api.anthropic.com`. Custo
     ~€0,01–0,03 por fatura.
   - Opcional `GC_TURNKEY_AI_MODEL` (por omissão `gemini-3.6-flash` /
     `claude-sonnet-5`; se a Google descontinuar o modelo, o `/analisar` dá
     `502 "no longer available"` e basta pôr aqui o novo, ex.: `gemini-3.8-flash`).
   - **Dev (Windows, `serve.ps1`)**: copia `pb/.env.example` para `pb/.env`
     (fora do git) e preenche. O `serve.ps1` carrega o `.env` para o ambiente
     antes de arrancar e escreve `provider=… chave definida`.
   - **Mini PC — Windows service (NSSM)**:
     `nssm set pocketbase AppEnvironmentExtra GC_TURNKEY_AI_PROVIDER=gemini GEMINI_API_KEY=AIza...`
     e reiniciar o serviço. Ou correr o PocketBase pelo mesmo `serve.ps1` com um
     `pb\.env` ao lado.
   - **Mini PC — Linux systemd**: `Environment=GC_TURNKEY_AI_PROVIDER=gemini` e
     `Environment=GEMINI_API_KEY=AIza...` na unit (ou
     `EnvironmentFile=/etc/pocketbase.env`), depois
     `systemctl daemon-reload && systemctl restart pocketbase`.
   - Sem a chave do provider ativo, tudo o resto funciona; só
     `/api/gc_turnkey/faturas/{id}/analisar` devolve `503` e a app mostra
     "IA não configurada".
   - Confirmar depois de arrancar:
     `curl -X POST http://127.0.0.1:8090/api/gc_turnkey/faturas/x/analisar` →
     deve dar `401` (falta auth), **não** `503`. Um `503` = chave não carregada.

   **Email para a contabilidade (SMTP):** o botão "Enviar por email" (Faturas →
   ícone de pasta) e o cron mensal (dia 1) usam o **Mailer do próprio
   PocketBase** — não há nenhuma variável de ambiente nossa para isto, é
   tudo na **Admin UI**:
   - Abre `http://<servidor>:8090/_/` → **Settings → Mail settings**.
   - **Sender name** / **Sender address**: o nome/email que aparece como
     remetente — é aqui que se configura o "noreply" (ex.: nome
     `Gookie Cookies`, endereço `noreply@teudominio.pt`). Se o "Sender name"
     ficar vazio, a app usa o nome da empresa.
   - **SMTP**: liga "Use SMTP" e preenche host/porta/utilizador/password do
     teu servidor de email (Gmail com password de aplicação, SendGrid,
     Mailgun, o SMTP do teu domínio, etc.). Testa com o botão "Send test
     email" da própria Admin UI.
   - Sem SMTP configurado, o botão "Enviar por email" e o cron mensal falham
     com uma mensagem clara ("Não foi possível enviar o email — SMTP
     configurado no servidor?"); o resto da app (incluindo "Baixar ZIP")
     continua a funcionar na mesma.
   - O **assunto** do email é sempre gerado pela app (nunca escrito à mão):
     identifica-se ("GC Turnkey") e diz a empresa a que pertencem as
     faturas — não depende de nenhuma configuração.

   **Segredos por empresa (token do Vendus):** exigem `GC_TURNKEY_ENC_KEY` (32 caracteres,
   `pb\gerar-chave-cifra.ps1 -Gravar`) — ver `docs/SEGURANCA.md`. O token de cada empresa
   guarda-se na app (Configurações → Integrações), cifrado; `VENDUS_API_KEY` só serve de recurso
   para a empresa de `VENDUS_SYNC_EMPRESA`.

   **Sincronização com o Vendus** (`vendus.pb.js`): opcional — sem estas
   variáveis, o botão "Sincronizar com o Vendus" na app dá `503` e o cron
   horário não faz nada.
   - `VENDUS_API_KEY`: gerada em Apps → API na conta Vendus.
   - `VENDUS_SYNC_EMPRESA`: id da empresa (`empresas.id`), só necessário para
     o **cron horário** (`0 * * * *`) — o botão manual usa a empresa de quem
     está autenticado. Sem esta variável, o cron não faz nada mas o botão
     continua a funcionar normalmente.
   - Mesmo mecanismo de variáveis de ambiente da IA de faturas acima (dev:
     `pb/.env`; NSSM: `AppEnvironmentExtra`; systemd: `Environment=`).
   - Saída de internet para `www.vendus.pt`.

4. **Verificar** no Admin UI (`/_/`) que existem as coleções:
   `empresas, configuracoes_custo, ingredientes, receitas, itens_receita,
   fichas_tecnicas, itens_ficha, historico, inventario, movimentos_inventario,
   producoes, producao_itens, lista_compras, formatos_cookie, sugestoes,
   faturas, faturas_itens, ingredientes_referencia, embalagens,
   embalagem_kits, embalagem_kit_itens, vendas, vendas_itens, custos_fixos,
   equipamentos, encomendas, encomendas_itens, configuracoes_encomendas,
   configuracoes_navegacao, preferencias_utilizador`
   e que `users` tem os campos `nome`, `empresa`, `papel`. A migração
   `1705104000_formatos_cookie.js` **semeia** Mini/Recheado/Simples em cada
   empresa existente (e o onboarding fá-lo para novas).
   Endpoints (`pb_hooks/inventario.pb.js`): `POST
   /api/gc_turnkey/inventario/ajustar`, `GET /api/gc_turnkey/producoes/{id}/plano`,
   `POST /api/gc_turnkey/producoes/{id}/lista-compras`, `POST
   /api/gc_turnkey/producoes/{id}/concluir` — ver [`README.md`](README.md).

5. **Primeiro utilizador**: cria uma conta na app (ecrã de registo) e faz o
   onboarding — fica `owner` da nova empresa.

## Migrar os dados do `meu_app_ia`

Depois do schema aplicado, do lado de uma máquina que veja os dois servidores:

```bash
dart run pb/seed/migrate_from_meu_app_ia.dart \
  --src-url=http://<meu_app_ia>:8090 \
  --dst-url=http://<mini-pc>:8090 --dst-email=<superuser> --dst-pass=<...> \
  --empresa="Nome da empresa" --attach-user=<o-teu-email> --recompute
```

`--recompute` liga os ingredientes-espelho (os "ingredientes de fabrico próprio" que na
verdade são receitas), recalcula tudo em cascata e imprime as diferenças vs. os
valores antigos. `--dry-run` conta sem escrever.

> As diferenças mostradas são **esperadas** onde o `meu_app_ia` tinha o custo
> em cache desatualizado (ex.: preços de ingredientes corrigidos depois, cópias
> de receitas sem linhas). O valor recalculado é o correto.

## Notas

- **Nunca** commitar `pb_data/` nem credenciais.
- As migrations são idempotentes no que toca a campos (`if (!getByName(...))`),
  mas cada uma só corre **uma vez** por base de dados — não editar uma migration
  já aplicada; criar uma nova.
- Regras de acesso e o gotcha dos hooks isolados: ver [`README.md`](README.md).
