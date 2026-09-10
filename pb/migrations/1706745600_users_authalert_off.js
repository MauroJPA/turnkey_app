/// <reference path="../pb_data/types.d.ts" />

// Desliga o email "Login from a new location" da coleção `users`. É um ERP
// interno de equipa e o SMTP muitas vezes não está configurado — o alerta
// só gerava ruído/erros. (O login nunca dependeu de `verified`; o authRule
// da coleção continua vazio.)

migrate(
  (app) => {
    const c = app.findCollectionByNameOrId('users');
    unmarshal({ authAlert: { enabled: false } }, c);
    return app.save(c);
  },
  (app) => {
    const c = app.findCollectionByNameOrId('users');
    unmarshal({ authAlert: { enabled: true } }, c);
    return app.save(c);
  },
);
