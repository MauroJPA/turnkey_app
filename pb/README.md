# PocketBase — schema e hooks do `turnkey_app`

Servidor alvo: **PocketBase v0.35.0** (Mini PC da Gookie, acedido via Tailscale).

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

Hooks: `onboarding.pb.js`, `guards.pb.js`, `cost_cascade.pb.js` (+ `cascade.js`).
Falta (M5): `fichas_tecnicas`, `itens_ficha` e `__recomputeFichaImpl`.

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
