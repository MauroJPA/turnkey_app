/// <reference path="../pb_data/types.d.ts" />

// Palavra-passe provisória: quando o proprietário/administrador repõe a senha
// de alguém da equipa (esqueceu-se), a conta fica com `senha_provisoria` = true
// e, ao entrar, a pessoa é obrigada a escolher uma palavra-passe nova.
// O campo só muda pelos endpoints do servidor (ver guards.pb.js e
// team_acesso.pb.js).

migrate(
  (app) => {
    const users = app.findCollectionByNameOrId('users');
    if (!users.fields.getByName('senha_provisoria')) {
      users.fields.add(new Field({ type: 'bool', name: 'senha_provisoria' }));
      app.save(users);
    }
  },
  (app) => {
    const users = app.findCollectionByNameOrId('users');
    users.fields.removeByName('senha_provisoria');
    app.save(users);
  },
);
