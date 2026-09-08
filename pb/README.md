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
| `1704499200_fichas_tecnicas.js` | `fichas_tecnicas`, `itens_ficha` |
| `1704585600_equipa_regras.js` | regras de equipa/papéis |
| `1704672000_fix_config_rule.js` | correção de regra em `configuracoes_custo` |
| `1704758400_receita_procedimento.js` | `receitas.procedimento` |
| `1704844800_inventario.js` | `inventario`, `movimentos_inventario` (só o servidor escreve) |
| `1704931200_producoes.js` | `producoes`, `producao_itens`, `movimentos_inventario.producao` |
| `1705017600_lista_compras.js` | `lista_compras` |

Hooks: `onboarding.pb.js`, `guards.pb.js`, `cost_cascade.pb.js`, `team.pb.js`,
`inventario.pb.js`, `admin.pb.js` (+ `cascade.js`, que exporta `runCascade`,
`explodeCompras`, `aplicarMovimento`, `carregarProducao`).

### Endpoints (Fase 2 — `inventario.pb.js`)

Todos exigem `requireAuth('users', '_superusers')`; um `users` não-viewer só age
sobre a sua empresa.

| Método | Rota | Efeito |
|---|---|---|
| `POST` | `/api/turnkey/inventario/ajustar` | `{ ingrediente?\|ficha?, delta, motivo, notas?, producao?, minimo?, localizacao? }` → upsert da linha `inventario` (`quantidade = max(0, q+delta)`) + `movimentos_inventario`. `delta` 0 é aceite se vier `minimo`/`localizacao`. |
| `GET` | `/api/turnkey/producoes/{id}/plano` | explosão agregada (desce sub-receitas e espelhos de fabrico próprio até ingredientes comprados) → `{ necessarios:[{ingredienteId,nome,fornecedor,gramas,custo,emStock,aComprar}], produzir:[{receitaId,nome,kg}], custoTotal }`. |
| `POST` | `/api/turnkey/producoes/{id}/lista-compras` | mesma agregação → upsert em `lista_compras` (funde na linha não-comprada do mesmo ingrediente+produção), `comprar = max(0, necessário − stock)` → `{ linhas }`. |
| `POST` | `/api/turnkey/producoes/{id}/concluir` | por cada `producao_item` consome as linhas diretas escaladas (`consumo_producao`) e credita o espelho da receita (`saida_producao`); marca `estado=concluida`, `concluida_em`, `custo_snapshot` → `{ consumos, saidas, faltas, custoTotal }`. |

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
