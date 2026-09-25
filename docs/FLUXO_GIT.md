# Fluxo de trabalho com Git

## Branches

| Branch | Para quê | Regras |
|---|---|---|
| `main` | **Produção.** Só código testado e pronto a instalar. | Nunca se trabalha diretamente aqui. Só recebe merges de `develop` (ou de `hotfix/*`), sempre com uma etiqueta de versão. |
| `develop` | **Integração.** Onde as funcionalidades se juntam e se testam. | Base de todas as `feature/*`. Tem de passar `scripts/verificar.sh` antes de juntar coisas novas. |
| `feature/<nome>` | Uma funcionalidade ou ajuste (ex. `feature/produtos`, `feature/etiqueta-termica`). | Sai de `develop`, volta a `develop` quando estiver pronta e verificada. |
| `hotfix/<nome>` | Correção urgente de algo que já está em produção. | Sai de `main`; volta a `main` **e** a `develop`. |

Estado inicial (2026-09-24): `master` foi renomeado para `main` (ficou igual ao estado
atual, etiqueta `v1.5.0` mantida) e `develop` criado a partir dele. **Trabalha-se em
`develop` ou nas `feature/*`.**

## No dia a dia

```bash
# começar uma funcionalidade
git switch develop
git switch -c feature/produtos

# ... trabalhar, ir fazendo commits pequenos ...

# antes de juntar
bash scripts/verificar.sh          # analyze + testes + hooks + migrations

# juntar a develop
git switch develop
git merge --no-ff feature/produtos
git branch -d feature/produtos
```

## Lançar uma versão para produção

```bash
git switch develop
bash scripts/verificar.sh          # tem de dar "TUDO OK"
# atualizar CHANGELOG.md e a versão em pubspec.yaml, fazer commit

git switch main
git merge --no-ff develop
git tag -a v1.0.0 -m "Primeira versão em produção"
git switch develop                 # e continuar a trabalhar aqui
```

Depois do merge em `main`: fazer backup da BD, instalar a nova versão e
correr o ensaio rápido (login, uma produção, uma venda).

## Correção urgente em produção (hotfix)

```bash
git switch main
git switch -c hotfix/corrige-x
# ... corrigir, bash scripts/verificar.sh ...
git switch main && git merge --no-ff hotfix/corrige-x
git tag -a v1.0.1 -m "Corrige x"
git switch develop && git merge --no-ff hotfix/corrige-x   # para não perder a correção
git branch -d hotfix/corrige-x
```

## Mensagens de commit

Uma linha que diz **o quê e porquê**, no imperativo ou descritivo, em português
(ex. "Ficha técnica: CMV esperado e real"). Corpo opcional com detalhes.

## Versões

`vMAIOR.MENOR.CORREÇÃO` — CORREÇÃO para hotfixes, MENOR para funcionalidades novas,
MAIOR para mudanças que exigem migração cuidadosa. A migration do PocketBase
(`pb/migrations`) é sempre commitada com o código que a usa.

## Falta (precisa de um remoto)

Hoje o repositório só existe neste computador. Antes da produção convém criar um
repositório **privado** (GitHub/GitLab) como cópia de segurança do código e, aí sim:

- [ ] `git remote add origin <url>` e enviar `main`, `develop` e as etiquetas;
- [ ] proteger `main` e `develop` (só merge por pull request);
- [ ] correr `scripts/verificar.sh` automaticamente em cada pull request (CI).
