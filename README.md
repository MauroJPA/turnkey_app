# turnkey_app

ERP modular para uma loja de cookies (e, no futuro, para outras empresas):
gestão de **ingredientes**, **receitas** (massas, recheios, coberturas, outras) e
**fichas técnicas** de produtos, com **precificação** baseada em percentuais de
custo. Regra central: qualquer alteração de preço de um ingrediente propaga-se
automaticamente a todas as receitas, sub-receitas e fichas que o usam.

- **Flutter** (Material 3) + **Riverpod** (estado/DI) + **go_router**
- Backend **PocketBase v0.35** partilhado, com isolamento por empresa
- Modelos com **freezed** / **json_serializable** (código gerado)

Substitui duas tentativas anteriores (`app_receitas2`, `meu_app_ia`); a lógica de
custo/cascata e de import de CSV é portada do `meu_app_ia`.

## Arquitetura

```
lib/src/
  app/        MaterialApp.router, tema, rotas
  core/       env, cliente PocketBase, auth, formatação, widgets partilhados
  features/   auth · dashboard · ingredients · recipes · tech_sheets · pricing
              · import_csv · settings
              cada feature: data/ (repos) · domain/ (modelos) ·
              application/ (controllers) · presentation/ (ecrãs)
pb/           migrations (schema), hooks (cascata), seed
```

Regras: os widgets nunca falam com o PocketBase diretamente — só via repositórios
expostos por providers Riverpod. Cada repositório injeta/filtra por `empresa`.

## Correr

Pré-requisitos: Flutter 3.32.x (Dart 3.8), um servidor PocketBase v0.35
(ver [`pb/README.md`](pb/README.md)).

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run --dart-define=PB_URL=http://127.0.0.1:8090
```

`--dart-define` disponíveis: `PB_URL`, `DEFAULT_LOCALE`, `DEBUG_TOOLS`
(ver [`.env.example`](.env.example)).

## Código gerado

`*.g.dart` e `*.freezed.dart` são versionados. Depois de mexer num modelo:

```bash
dart run build_runner build --delete-conflicting-outputs
# ou, durante o desenvolvimento:
dart run build_runner watch --delete-conflicting-outputs
```

## Verificar

```bash
flutter analyze
flutter test
```

## Roadmap

- **Fase 1** (atual): Login, Opções/Configurações, Ingredientes, Receitas,
  Fichas Técnicas + motor de cascata de custos.
- **Fase 2**: inventário, produção, lista de compras.
- **Fase 3**: IA para faturas de compra → contabilidade.

Plano detalhado e milestones: `C:\Users\mauro\.claude\plans\jiggly-drifting-forest.md`.
