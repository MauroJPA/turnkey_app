/// <reference path="../pb_data/types.d.ts" />

// Avisos e resumo diário por email e Telegram (uma configuração por empresa).
// O token do bot do Telegram guarda-se cifrado em `segredos_empresa`
// (serviço "telegram"); aqui ficam só o chat, os emails, a hora e o que incluir.
// Só owner/admin da empresa criam/alteram. `ultimo_envio` / `ultimo_resultado`
// são escritos pelo servidor.
migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');
    const podeVer = "@request.auth.id != '' && empresa = @request.auth.empresa";
    const admin = "(@request.auth.papel = 'owner' || @request.auth.papel = 'admin')";
    const podeCriar = `@request.auth.id != '' && @request.body.empresa = @request.auth.empresa && ${admin}`;
    const podeEscrever = `@request.auth.id != '' && empresa = @request.auth.empresa && ${admin}`;

    const c = new Collection({
      type: 'base',
      name: 'avisos_config',
      listRule: podeVer,
      viewRule: podeVer,
      createRule: podeCriar,
      updateRule: podeEscrever,
      deleteRule: podeEscrever,
      fields: [
        { type: 'relation', name: 'empresa', required: true, maxSelect: 1, collectionId: empresas.id, cascadeDelete: true },
        { type: 'bool', name: 'ativo', required: false },
        // hora local do envio, "HH:MM"
        { type: 'text', name: 'hora', required: false, max: 5 },
        { type: 'bool', name: 'email_ativo', required: false },
        { type: 'text', name: 'email_para', required: false, max: 300 },
        { type: 'bool', name: 'telegram_ativo', required: false },
        { type: 'text', name: 'telegram_chat', required: false, max: 60 },
        { type: 'bool', name: 'inc_haccp', required: false },
        { type: 'bool', name: 'inc_stock', required: false },
        { type: 'bool', name: 'inc_pagamentos', required: false },
        { type: 'bool', name: 'inc_faturas', required: false },
        { type: 'bool', name: 'inc_precos', required: false },
        { type: 'text', name: 'ultimo_envio', required: false, max: 10 },
        { type: 'text', name: 'ultimo_resultado', required: false, max: 400 },
        { type: 'autodate', name: 'created', onCreate: true },
        { type: 'autodate', name: 'updated', onCreate: true, onUpdate: true },
      ],
      indexes: [
        'CREATE UNIQUE INDEX `idx_avisos_config_empresa` ON `avisos_config` (`empresa`)',
      ],
    });
    app.save(c);
  },
  (app) => {
    try {
      app.delete(app.findCollectionByNameOrId('avisos_config'));
    } catch (_) {}
  },
);
