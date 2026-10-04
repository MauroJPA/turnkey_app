/// <reference path="../pb_data/types.d.ts" />

// Registo dos relatórios HACCP emitidos (para auditoria): cada relatório tem
// um número sequencial por empresa e ano (HACCP-2026-0007), o período e o
// tipo, quantos registos continha e uma "impressão digital" dos dados
// (integridade). Assim, mais tarde, um relatório impresso pode ser confirmado
// contra o que foi emitido. Não se apagam nem se alteram (só owner/admin
// apagam, pela base de dados).

migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');
    const users = app.findCollectionByNameOrId('users');

    const ehOwnerOuAdmin =
      "(@request.auth.papel = 'owner' || @request.auth.papel = 'admin')";
    const podeVer = "@request.auth.id != '' && empresa = @request.auth.empresa";
    const podeCriar =
      "@request.auth.id != '' && @request.body.empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";

    const c = new Collection({
      type: 'base',
      name: 'haccp_relatorios',
      listRule: podeVer,
      viewRule: podeVer,
      createRule: podeCriar,
      // um relatório emitido não se altera
      updateRule: null,
      deleteRule: `@request.auth.id != '' && empresa = @request.auth.empresa && ${ehOwnerOuAdmin}`,
      fields: [
        {
          type: 'relation',
          name: 'empresa',
          required: true,
          maxSelect: 1,
          collectionId: empresas.id,
          cascadeDelete: true,
        },
        { type: 'text', name: 'codigo', required: true, max: 40 },
        { type: 'number', name: 'ano', required: true },
        { type: 'number', name: 'sequencia', required: true },
        // 'todos' ou o tipo do controlo (temperatura, limpeza, praga, ...)
        { type: 'text', name: 'tipo', required: true, max: 20 },
        { type: 'date', name: 'desde', required: true },
        { type: 'date', name: 'ate', required: true },
        { type: 'number', name: 'registos', required: false },
        { type: 'number', name: 'nao_conformidades', required: false },
        { type: 'text', name: 'integridade', required: true, max: 40 },
        {
          type: 'relation',
          name: 'autor',
          required: false,
          maxSelect: 1,
          collectionId: users.id,
          cascadeDelete: false,
        },
        { type: 'autodate', name: 'created', onCreate: true },
        { type: 'autodate', name: 'updated', onCreate: true, onUpdate: true },
      ],
      indexes: [
        'CREATE UNIQUE INDEX `idx_haccp_relatorios_codigo` ON `haccp_relatorios` (`empresa`, `codigo`)',
        'CREATE INDEX `idx_haccp_relatorios_empresa_ano` ON `haccp_relatorios` (`empresa`, `ano`)',
      ],
    });
    app.save(c);
  },
  (app) => {
    app.delete(app.findCollectionByNameOrId('haccp_relatorios'));
  },
);
