/// <reference path="../pb_data/types.d.ts" />

// Aprovação de registos: qualquer pessoa pode criar conta, mas só entra na
// app (criar empresa) depois de o operador da plataforma a aprovar. Aprovação
// = pôr `users.aprovado` a verdadeiro, no painel de administração do
// PocketBase (/_/ → users) ou na base de dados. Só superutilizadores o fazem:
// a regra de criação recusa `aprovado` e o hook guards.pb.js recusa alterações.
//
// Contas já existentes ficam aprovadas (ninguém fica de fora).

migrate(
  (app) => {
    const users = app.findCollectionByNameOrId('users');
    if (!users.fields.getByName('aprovado')) {
      users.fields.add(new Field({ type: 'bool', name: 'aprovado' }));
    }
    users.createRule =
      '@request.body.empresa:isset = false && @request.body.papel:isset = false && @request.body.aprovado:isset = false';
    app.save(users);
    app.db().newQuery('UPDATE users SET aprovado = TRUE').execute();
  },
  (app) => {
    const users = app.findCollectionByNameOrId('users');
    users.createRule =
      '@request.body.empresa:isset = false && @request.body.papel:isset = false';
    users.fields.removeByName('aprovado');
    app.save(users);
  },
);
