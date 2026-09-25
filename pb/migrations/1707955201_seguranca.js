/// <reference path="../pb_data/types.d.ts" />

// Endurecimento de segurança (testes em test/security/seguranca.py):
//  1. Registo público: já não deixa escolher `empresa` nem `papel` (antes,
//     qualquer pessoa podia registar-se como proprietária de outra empresa).
//  2. Ficheiros das faturas passam a ser protegidos (só com sessão + token
//     de ficheiro de curta duração).
//  3. Logótipo da empresa: só imagens, máx. 3 MB.
//  4. Limite de pedidos (contra força bruta no login) ligado.
//     Atrás de um proxy é preciso configurar "trusted proxy headers" nas
//     definições, senão todos os utilizadores partilham o mesmo IP (docs/SEGURANCA.md).

migrate(
  (app) => {
    const users = app.findCollectionByNameOrId('users');
    users.createRule = '@request.body.empresa:isset = false && @request.body.papel:isset = false';
    app.save(users);

    const faturas = app.findCollectionByNameOrId('faturas');
    const ficheiro = faturas.fields.getByName('ficheiro');
    ficheiro.protected = true;
    app.save(faturas);

    const empresas = app.findCollectionByNameOrId('empresas');
    const logo = empresas.fields.getByName('logo');
    logo.mimeTypes = ['image/jpeg', 'image/png', 'image/webp'];
    logo.maxSize = 3 * 1024 * 1024;
    app.save(empresas);

    const settings = app.settings();
    settings.rateLimits.enabled = true;
    settings.rateLimits.rules = [
      { label: '*:auth', duration: 60, maxRequests: 15 },
      { label: '*:create', duration: 10, maxRequests: 120 },
      { label: '/api/', duration: 10, maxRequests: 600 },
    ];
    app.save(settings);
  },
  (app) => {
    const users = app.findCollectionByNameOrId('users');
    users.createRule = '';
    app.save(users);

    const faturas = app.findCollectionByNameOrId('faturas');
    faturas.fields.getByName('ficheiro').protected = false;
    app.save(faturas);

    const empresas = app.findCollectionByNameOrId('empresas');
    const logo = empresas.fields.getByName('logo');
    logo.mimeTypes = [];
    logo.maxSize = 0;
    app.save(empresas);

    const settings = app.settings();
    settings.rateLimits.enabled = false;
    app.save(settings);
  },
);
