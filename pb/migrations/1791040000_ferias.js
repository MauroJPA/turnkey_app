/// <reference path="../pb_data/types.d.ts" />

// Mapa de férias e ausências — 1.93.0.
//
// `ferias`: um período de férias (ou baixa, falta…) de uma pessoa. Quem não é
// administrador só consegue pedir (estado "pedido") para si; o proprietário/
// administrador aprova ou recusa e pode registar qualquer ausência. O mapa é
// partilhado: todos veem as férias aprovadas dos colegas; baixas, faltas e
// pedidos só os vê o próprio e a administração (dados de saúde/pessoais).
// `ferias_direito`: os dias de férias a que cada pessoa tem direito em cada ano
// (só a administração escreve; cada um lê o seu).
migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');
    const users = app.findCollectionByNameOrId('users');

    const ehAdmin = "(@request.auth.papel = 'owner' || @request.auth.papel = 'admin')";
    const doAdmin = `@request.auth.id != '' && empresa = @request.auth.empresa && ${ehAdmin}`;
    const mesma = (campo) =>
      `(@request.body.${campo}:isset = false || @request.body.${campo} = '' || @request.body.${campo}.empresa = @request.auth.empresa)`;

    const campoEmpresa = () => ({
      type: 'relation',
      name: 'empresa',
      required: true,
      maxSelect: 1,
      collectionId: empresas.id,
      cascadeDelete: true,
    });

    const verFerias = `@request.auth.id != '' && empresa = @request.auth.empresa && (${ehAdmin} || user = @request.auth.id || (tipo = 'ferias' && estado = 'aprovado'))`;
    const criarFerias = `@request.auth.id != '' && @request.body.empresa = @request.auth.empresa && @request.auth.papel != 'viewer' && (${ehAdmin} || (@request.body.estado = 'pedido' && @request.body.user = @request.auth.id)) && ${mesma('user')}`;
    const apagarFerias = `@request.auth.id != '' && empresa = @request.auth.empresa && (${ehAdmin} || (user = @request.auth.id && estado = 'pedido'))`;

    const ferias = new Collection({
      type: 'base',
      name: 'ferias',
      listRule: verFerias,
      viewRule: verFerias,
      createRule: criarFerias,
      updateRule: `(${doAdmin}) && ${mesma('user')}`,
      deleteRule: apagarFerias,
      fields: [
        campoEmpresa(),
        // chave da pessoa: "u:<id da conta>" ou "c:<id do colaborador>"
        { type: 'text', name: 'pessoa', required: true, max: 60 },
        { type: 'text', name: 'nome', required: false, max: 80 },
        { type: 'relation', name: 'user', required: false, maxSelect: 1, collectionId: users.id, cascadeDelete: false },
        { type: 'select', name: 'tipo', required: true, maxSelect: 1, values: ['ferias', 'baixa', 'falta', 'outro'] },
        { type: 'date', name: 'data_inicio', required: true },
        { type: 'date', name: 'data_fim', required: true },
        // dias úteis (segunda a sexta, sem feriados) calculados pela app
        { type: 'number', name: 'dias_uteis', required: false, min: 0, max: 400 },
        { type: 'select', name: 'estado', required: true, maxSelect: 1, values: ['pedido', 'aprovado', 'recusado'] },
        { type: 'text', name: 'notas', required: false, max: 300 },
        { type: 'relation', name: 'decidido_por', required: false, maxSelect: 1, collectionId: users.id, cascadeDelete: false },
        { type: 'date', name: 'decidido_em', required: false },
        { type: 'autodate', name: 'created', onCreate: true },
        { type: 'autodate', name: 'updated', onCreate: true, onUpdate: true },
      ],
      indexes: [
        'CREATE INDEX `idx_ferias_empresa_inicio` ON `ferias` (`empresa`, `data_inicio`)',
        'CREATE INDEX `idx_ferias_pessoa` ON `ferias` (`empresa`, `pessoa`)',
      ],
    });
    app.save(ferias);

    const verDireito = `@request.auth.id != '' && empresa = @request.auth.empresa && (${ehAdmin} || user = @request.auth.id)`;
    const direito = new Collection({
      type: 'base',
      name: 'ferias_direito',
      listRule: verDireito,
      viewRule: verDireito,
      createRule: `@request.auth.id != '' && @request.body.empresa = @request.auth.empresa && ${ehAdmin} && ${mesma('user')}`,
      updateRule: `(${doAdmin}) && ${mesma('user')}`,
      deleteRule: doAdmin,
      fields: [
        campoEmpresa(),
        { type: 'text', name: 'pessoa', required: true, max: 60 },
        { type: 'relation', name: 'user', required: false, maxSelect: 1, collectionId: users.id, cascadeDelete: false },
        { type: 'number', name: 'ano', required: true, min: 2000, max: 2200 },
        { type: 'number', name: 'dias', required: true, min: 0, max: 100 },
        { type: 'autodate', name: 'created', onCreate: true },
        { type: 'autodate', name: 'updated', onCreate: true, onUpdate: true },
      ],
      indexes: [
        'CREATE UNIQUE INDEX `idx_ferias_direito_unico` ON `ferias_direito` (`empresa`, `pessoa`, `ano`)',
      ],
    });
    app.save(direito);
  },
  (app) => {
    for (const nome of ['ferias_direito', 'ferias']) {
      try {
        app.delete(app.findCollectionByNameOrId(nome));
      } catch (_) {}
    }
  },
);
