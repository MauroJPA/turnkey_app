/// <reference path="../pb_data/types.d.ts" />

// Personalização da navegação.
// `configuracoes_navegacao` — 1 linha por empresa: `rodape` (lista ordenada de
// chaves de páginas na barra inferior) e `acesso` (matriz papel → página →
// 'oculto' | 'ver' | 'editar'). Só o proprietário mexe em `acesso`; o
// administrador só no `rodape`. Sem linha, a app usa os valores por omissão.
// `preferencias_utilizador` — 1 linha por pessoa: páginas que oculta na grelha
// do Início (`oculto`) e a cor de cada botão (`cores`, chave → #RRGGBB).

migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');
    const users = app.findCollectionByNameOrId('users');

    const ehOwner = "@request.auth.papel = 'owner'";
    const ehOwnerOuAdmin =
      "(@request.auth.papel = 'owner' || @request.auth.papel = 'admin')";
    const podeVer = "@request.auth.id != '' && empresa = @request.auth.empresa";
    // Administrador escreve tudo menos a matriz `acesso`.
    const semAcesso = '@request.body.acesso:isset = false';
    const podeEscreverConfig =
      `@request.auth.id != '' && empresa = @request.auth.empresa && (${ehOwner} || (${ehOwnerOuAdmin} && ${semAcesso}))`;
    const podeCriarConfig =
      `@request.auth.id != '' && @request.body.empresa = @request.auth.empresa && (${ehOwner} || (${ehOwnerOuAdmin} && ${semAcesso}))`;
    const apagarConfig =
      `@request.auth.id != '' && empresa = @request.auth.empresa && ${ehOwner}`;

    const campoEmpresa = () => ({
      type: 'relation',
      name: 'empresa',
      required: true,
      maxSelect: 1,
      collectionId: empresas.id,
      cascadeDelete: true,
    });

    const configNavegacao = new Collection({
      type: 'base',
      name: 'configuracoes_navegacao',
      listRule: podeVer,
      viewRule: podeVer,
      createRule: podeCriarConfig,
      updateRule: podeEscreverConfig,
      deleteRule: apagarConfig,
      fields: [
        campoEmpresa(),
        { type: 'json', name: 'rodape', required: false, maxSize: 20000 },
        { type: 'json', name: 'acesso', required: false, maxSize: 200000 },
      ],
      indexes: [
        'CREATE UNIQUE INDEX `idx_config_navegacao_empresa` ON `configuracoes_navegacao` (`empresa`)',
      ],
    });
    app.save(configNavegacao);

    const minha = "@request.auth.id != '' && utilizador = @request.auth.id";
    const preferencias = new Collection({
      type: 'base',
      name: 'preferencias_utilizador',
      listRule: minha,
      viewRule: minha,
      createRule:
        "@request.auth.id != '' && @request.body.utilizador = @request.auth.id && @request.body.empresa = @request.auth.empresa",
      updateRule: minha,
      deleteRule: minha,
      fields: [
        campoEmpresa(),
        {
          type: 'relation',
          name: 'utilizador',
          required: true,
          maxSelect: 1,
          collectionId: users.id,
          cascadeDelete: true,
        },
        { type: 'json', name: 'oculto', required: false, maxSize: 20000 },
        { type: 'json', name: 'cores', required: false, maxSize: 20000 },
      ],
      indexes: [
        'CREATE UNIQUE INDEX `idx_pref_utilizador` ON `preferencias_utilizador` (`empresa`, `utilizador`)',
      ],
    });
    app.save(preferencias);
  },
  (app) => {
    app.delete(app.findCollectionByNameOrId('preferencias_utilizador'));
    app.delete(app.findCollectionByNameOrId('configuracoes_navegacao'));
  },
);
