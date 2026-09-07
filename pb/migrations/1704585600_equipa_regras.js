/// <reference path="../pb_data/types.d.ts" />

// M6 — regras de acesso para gestão de equipa e configurações.
//  - membros da mesma empresa podem ver-se uns aos outros (ecrã Equipa)
//  - owner/admin podem editar o perfil da empresa

migrate(
  (app) => {
    const users = app.findCollectionByNameOrId('users');
    users.listRule =
      "@request.auth.id != '' && (id = @request.auth.id || (empresa != '' && empresa = @request.auth.empresa))";
    users.viewRule = users.listRule;
    app.save(users);

    const empresas = app.findCollectionByNameOrId('empresas');
    empresas.updateRule =
      "@request.auth.id != '' && id = @request.auth.empresa && (@request.auth.papel = 'owner' || @request.auth.papel = 'admin')";
    app.save(empresas);
  },
  (app) => {
    const users = app.findCollectionByNameOrId('users');
    users.listRule = 'id = @request.auth.id';
    users.viewRule = 'id = @request.auth.id';
    app.save(users);

    const empresas = app.findCollectionByNameOrId('empresas');
    empresas.updateRule =
      "@request.auth.id != '' && id = @request.auth.empresa && @request.auth.papel ~ 'owner'";
    app.save(empresas);
  },
);
