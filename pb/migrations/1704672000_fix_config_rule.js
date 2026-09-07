/// <reference path="../pb_data/types.d.ts" />

// Corrige a updateRule de `configuracoes_custo`: o operador `~` do PocketBase é
// LIKE (substring), não regex — `papel ~ 'owner|admin'` nunca dava verdade.

migrate(
  (app) => {
    const c = app.findCollectionByNameOrId('configuracoes_custo');
    c.updateRule =
      "@request.auth.id != '' && empresa = @request.auth.empresa && (@request.auth.papel = 'owner' || @request.auth.papel = 'admin')";
    app.save(c);
  },
  (app) => {
    const c = app.findCollectionByNameOrId('configuracoes_custo');
    c.updateRule =
      "@request.auth.id != '' && empresa = @request.auth.empresa && @request.auth.papel ~ 'owner|admin'";
    app.save(c);
  },
);
