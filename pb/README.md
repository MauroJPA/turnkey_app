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
| `1705104000_formatos_cookie.js` | `formatos_cookie` + seed Mini/Recheado/Simples por empresa |
| `1705190400_producao_itens_agenda.js` | `producao_itens`: `formato`, `recheio`, `prioridade`, `hora_limite`, `unidades_previstas` |
| `1705276800_fichas_formato.js` | `fichas_tecnicas.formato` |
| `1705363200_receitas_imagens.js` | `receitas.imagens` (file, ≤8, image/*) |
| `1705449600_lista_compras_embalagem.js` | `lista_compras.embalagem_g` |
| `1705536000_lista_compras_custo.js` | `lista_compras.custo_estimado` |
| `1705622400_empresas_tema.js` | `empresas.tema` (sistema/claro/escuro) |
| `1705708800_lista_compras_extra.js` | `lista_compras`: `notas`, `unidade` (itens manuais) |
| `1705795200_inventario_itens_livres.js` | `inventario`/`movimentos_inventario`: `descricao`, `unidade` (itens livres) + índice `(empresa, descricao)` |

Aparência (tema, cor de marca `cor_marca`, logótipo `logo`) é **por empresa** —
editada em Configurações → Aparência, aplica-se a toda a equipa.

Hooks: `onboarding.pb.js` (semeia `configuracoes_custo` + `formatos_cookie`),
`guards.pb.js`, `cost_cascade.pb.js`, `team.pb.js`, `inventario.pb.js`,
`admin.pb.js` (+ `cascade.js`, que exporta `runCascade`, `explodeCompras`,
`aplicarMovimento`, `carregarProducao`, `resolverFicha`).

### Endpoints (Fase 2 — `inventario.pb.js`)

Todos exigem `requireAuth('users', '_superusers')`; um `users` não-viewer só age
sobre a sua empresa.

| Método | Rota | Efeito |
|---|---|---|
| `POST` | `/api/turnkey/inventario/ajustar` | `{ ingrediente?\|ficha?\|descricao?(item livre) + unidade?, delta, motivo, notas?, producao?, minimo?, localizacao? }` → upsert da linha `inventario` (`quantidade = max(0, q+delta)`) + `movimentos_inventario`. `delta` 0 é aceite se vier `minimo`/`localizacao`/`unidade`. |
| `GET` | `/api/turnkey/fichas/resolver` | `?massa=&formato=&recheio=` → ficha técnica correspondente + `componentes:[{slot,nome,gPorUnidade}]` (recheios/coberturas/extra) ou `{fichaId:''}`. |
| `GET` | `/api/turnkey/producoes/{id}/plano` | explosão agregada (sub-receitas + espelhos de fabrico próprio + **recheio do formato**: `N = round(kg·1000/massa_g)`, `N·recheio_g` do recheio) → `{ necessarios:[{ingredienteId,nome,fornecedor,gramas,custo,emStock,aComprar,embalagemG,aComprarSacos}], produzir:[{receitaId,nome,kg,unidades,formato,recheio,prioridade,horaLimite}], custoTotal }`. |
| `POST` | `/api/turnkey/producoes/{id}/lista-compras` | mesma agregação → upsert em `lista_compras`; `quantidade_necessaria_g` = necessidade exata, `quantidade_comprar_g` = `ceil(falta/embalagem)·embalagem` (sacos inteiros), grava `embalagem_g` → `{ linhas }`. |
| `POST` | `/api/turnkey/producoes/{id}/concluir` | por `producao_item`: consome a massa (`kg`, escalada por %) e — se `resolverFicha` encontrar a ficha do (massa+formato) — todos os slots não-massa da ficha (recheio_base/top, cobertura_base/top, extra) a `N·quantidade_g`, creditando `+N` unidades no `inventario` da ficha. Sem ficha: usa o `recheio` indicado à mão (se houver) e entra em `faltas`. Itens sem `formato` mantêm o crédito do ingrediente-espelho. Grava `unidades_previstas`, `estado=concluida`, `concluida_em`, `custo_snapshot` → `{ consumos, saidas, faltas, custoTotal }`. |

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
