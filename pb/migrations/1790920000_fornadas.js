/// <reference path="../pb_data/types.d.ts" />

// Forno da contagem diária:
// - `fornadas`: cada vez que se põe cookies no forno (local, sabores e
//   quantidades, quando começou, quantos minutos). O cronómetro vê-se em
//   qualquer telemóvel; os assados já ficam registados em `movimentos_produto`
//   (os ids estão em `movimentos`, para se poderem desfazer ao cancelar).
// - `movimentos_produto.motivo`: novo motivo "consumo_proprio" (cookies
//   comidos pelos colaboradores).

migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');
    const locais = app.findCollectionByNameOrId('locais');
    const users = app.findCollectionByNameOrId('users');

    // --- motivo "consumo próprio" --------------------------------------------
    const mov = app.findCollectionByNameOrId('movimentos_produto');
    const motivo = mov.fields.getByName('motivo');
    if (motivo && motivo.values.indexOf('consumo_proprio') < 0) {
      motivo.values = motivo.values.concat(['consumo_proprio']);
      app.save(mov);
    }

    // --- fornadas ----------------------------------------------------------------
    const podeVer = "@request.auth.id != '' && empresa = @request.auth.empresa";
    const podeEscrever =
      "@request.auth.id != '' && empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";
    const podeCriar =
      "@request.auth.id != '' && @request.body.empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";
    const mesmaEmpresa = (campo) =>
      `(@request.body.${campo}:isset = false || @request.body.${campo} = '' || @request.body.${campo}.empresa = @request.auth.empresa)`;

    const fornadas = new Collection({
      type: 'base',
      name: 'fornadas',
      listRule: podeVer,
      viewRule: podeVer,
      createRule: `(${podeCriar}) && ${mesmaEmpresa('local')}`,
      updateRule: `(${podeEscrever}) && ${mesmaEmpresa('local')}`,
      deleteRule: podeEscrever,
      fields: [
        {
          type: 'relation',
          name: 'empresa',
          required: true,
          maxSelect: 1,
          collectionId: empresas.id,
          cascadeDelete: true,
        },
        {
          type: 'relation',
          name: 'local',
          required: true,
          maxSelect: 1,
          collectionId: locais.id,
          cascadeDelete: true,
        },
        { type: 'date', name: 'inicio', required: true },
        { type: 'number', name: 'duracao_min', required: true, min: 1, max: 600 },
        // [{ "ficha": "<id>", "quantidade": 6 }, ...]
        { type: 'json', name: 'itens', required: false, maxSize: 20000 },
        // ids dos movimentos "producao" criados com a fornada
        { type: 'json', name: 'movimentos', required: false, maxSize: 20000 },
        {
          type: 'select',
          name: 'estado',
          required: true,
          maxSelect: 1,
          values: ['no_forno', 'tirada', 'cancelada'],
        },
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
        'CREATE INDEX `idx_fornadas_local_estado` ON `fornadas` (`empresa`, `local`, `estado`)',
      ],
    });
    app.save(fornadas);
  },
  (app) => {
    app.delete(app.findCollectionByNameOrId('fornadas'));
    const mov = app.findCollectionByNameOrId('movimentos_produto');
    const motivo = mov.fields.getByName('motivo');
    if (motivo) {
      motivo.values = motivo.values.filter((v) => v !== 'consumo_proprio');
      app.save(mov);
    }
  },
);
