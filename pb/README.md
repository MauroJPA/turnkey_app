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

## Estado

- **M0** — `migrations/1704067200_base_collections.js`: `empresas`, campos
  `empresa`+`papel` em `users`, `configuracoes_custo`. Escrito para a API JS da
  v0.35; **a validar contra o servidor real no M1**.
- **M2+** — `ingredientes`, `fornecedores`, `receitas`, `itens_receita`,
  `fichas_tecnicas`, `itens_ficha`, `historico` entram nos respetivos milestones.
- **M4** — `hooks/cost_cascade.pb.js` (recálculo recursivo + cascata).

## Regras de acesso (multi-empresa)

Todas as coleções de negócio:

| Regra | Expressão |
|---|---|
| list / view | `@request.auth.id != "" && empresa = @request.auth.empresa` |
| create | `@request.auth.id != "" && @request.body.empresa = @request.auth.empresa` |
| update / delete | `@request.auth.id != "" && empresa = @request.auth.empresa` + (M6) papel |
