# Aplicar o schema no servidor (Mini PC)

O schema e a lógica de servidor vivem neste repo:

```
pb/migrations/*.js   -> schema (coleções, campos, regras)
pb/hooks/*           -> lógica (cascata de custos, onboarding, equipa, admin)
```

As 22 migrations aplicam-se limpas a uma base de dados vazia (verificado).

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

4. **Verificar** no Admin UI (`/_/`) que existem as coleções:
   `empresas, configuracoes_custo, ingredientes, receitas, itens_receita,
   fichas_tecnicas, itens_ficha, historico, inventario, movimentos_inventario,
   producoes, producao_itens, lista_compras, formatos_cookie`
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
