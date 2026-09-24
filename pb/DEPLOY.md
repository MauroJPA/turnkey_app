# Aplicar o schema no servidor (Mini PC)

O schema e a lógica de servidor vivem neste repo:

```
pb/migrations/*.js   -> schema (coleções, campos, regras)
pb/hooks/*           -> lógica (cascata de custos, onboarding, equipa, admin)
```

As 40 migrations aplicam-se limpas a uma base de dados vazia (verificado). A
`1706227200_seed_insa.js` insere 1376 alimentos na `ingredientes_referencia`
(demora alguns segundos no 1.º arranque; é idempotente).

---

## Pré-requisito

O Mini PC corre **PocketBase v0.35.0**. Confirma:

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
   cp turnkey_app/pb/migrations/*.js  <pasta-do-pocketbase>/pb_migrations/
   cp -r turnkey_app/pb/hooks/*       <pasta-do-pocketbase>/pb_hooks/
   ```
   (inclui `pb_hooks/cascade.js` — é um módulo `require()`d pelos hooks, não um
   hook autónomo, mas tem de estar na mesma pasta.)

3. **Aplicar as migrations** (correm no arranque; ou explicitamente):
   ```bash
   ./pocketbase migrate up
   ./pocketbase serve   # reinicia o serviço (systemd: systemctl restart pocketbase)
   ```

   **Análise de faturas por IA** (`faturas.pb.js` → `ai.js`): o fornecedor de IA
   escolhe-se por `TURNKEY_AI_PROVIDER` — **`gemini`** (por omissão, tem plano
   gratuito) ou `anthropic`. Só é preciso a chave do provider ativo.
   - **Gemini** (agora): chave em <https://aistudio.google.com/app/apikey>
     (começa por `AIza`). Variáveis: `TURNKEY_AI_PROVIDER=gemini`,
     `GEMINI_API_KEY=AIza...`. Saída de internet para
     `generativelanguage.googleapis.com`.
   - **Anthropic** (futuro): chave em <https://console.anthropic.com/> →
     Settings → API keys (`sk-ant-...`). Variáveis: `TURNKEY_AI_PROVIDER=anthropic`,
     `ANTHROPIC_API_KEY=sk-ant-...`. Saída para `api.anthropic.com`. Custo
     ~€0,01–0,03 por fatura.
   - Opcional `TURNKEY_AI_MODEL` (por omissão `gemini-3.6-flash` /
     `claude-sonnet-5`; se a Google descontinuar o modelo, o `/analisar` dá
     `502 "no longer available"` e basta pôr aqui o novo, ex.: `gemini-3.8-flash`).
   - **Dev (Windows, `serve.ps1`)**: copia `pb/.env.example` para `pb/.env`
     (fora do git) e preenche. O `serve.ps1` carrega o `.env` para o ambiente
     antes de arrancar e escreve `provider=… chave definida`.
   - **Mini PC — Windows service (NSSM)**:
     `nssm set pocketbase AppEnvironmentExtra TURNKEY_AI_PROVIDER=gemini GEMINI_API_KEY=AIza...`
     e reiniciar o serviço. Ou correr o PocketBase pelo mesmo `serve.ps1` com um
     `pb\.env` ao lado.
   - **Mini PC — Linux systemd**: `Environment=TURNKEY_AI_PROVIDER=gemini` e
     `Environment=GEMINI_API_KEY=AIza...` na unit (ou
     `EnvironmentFile=/etc/pocketbase.env`), depois
     `systemctl daemon-reload && systemctl restart pocketbase`.
   - Sem a chave do provider ativo, tudo o resto funciona; só
     `/api/turnkey/faturas/{id}/analisar` devolve `503` e a app mostra
     "IA não configurada".
   - Confirmar depois de arrancar:
     `curl -X POST http://127.0.0.1:8090/api/turnkey/faturas/x/analisar` →
     deve dar `401` (falta auth), **não** `503`. Um `503` = chave não carregada.

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
   /api/turnkey/inventario/ajustar`, `GET /api/turnkey/producoes/{id}/plano`,
   `POST /api/turnkey/producoes/{id}/lista-compras`, `POST
   /api/turnkey/producoes/{id}/concluir` — ver [`README.md`](README.md).

5. **Primeiro utilizador**: cria uma conta na app (ecrã de registo) e faz o
   onboarding — fica `owner` da nova empresa.

## Migrar os dados do `meu_app_ia`

Depois do schema aplicado, do lado de uma máquina que veja os dois servidores:

```bash
dart run pb/seed/migrate_from_meu_app_ia.dart \
  --src-url=http://<meu_app_ia>:8090 \
  --dst-url=http://<mini-pc>:8090 --dst-email=<superuser> --dst-pass=<...> \
  --empresa="Gookie" --attach-user=<o-teu-email> --recompute
```

`--recompute` liga os ingredientes-espelho (os "ingredientes Gookie" que na
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
