/// <reference path="../pb_data/types.d.ts" />

// Formações e certificados das pessoas — 1.106.0.
//
// `formacoes`: um certificado ou formação de uma pessoa (ex.: "Manipulador de
// alimentos", validade 3 anos), com o ficheiro (PDF/foto) guardado. A validade
// serve para a app avisar antes de caducar. É um dado pessoal: só a pessoa e a
// administração o veem; o ficheiro é protegido (precisa de token curto).
migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');
    const users = app.findCollectionByNameOrId('users');

    const ehAdmin = "(@request.auth.papel = 'owner' || @request.auth.papel = 'admin')";
    const mesma = (campo) =>
      `(@request.body.${campo}:isset = false || @request.body.${campo} = '' || @request.body.${campo}.empresa = @request.auth.empresa)`;

    const ver = `@request.auth.id != '' && empresa = @request.auth.empresa && (${ehAdmin} || user = @request.auth.id)`;
    // a administração regista para quem quiser; cada pessoa só para si
    const criar = `@request.auth.id != '' && @request.body.empresa = @request.auth.empresa && @request.auth.papel != 'viewer' && (${ehAdmin} || @request.body.user = @request.auth.id) && ${mesma('user')}`;
    // quem não é administração não passa o registo para outra pessoa
    const alterar = `@request.auth.id != '' && empresa = @request.auth.empresa && @request.auth.papel != 'viewer' && (${ehAdmin} || (user = @request.auth.id && (@request.body.user:isset = false || @request.body.user = @request.auth.id))) && ${mesma('user')}`;
    const apagar = `@request.auth.id != '' && empresa = @request.auth.empresa && @request.auth.papel != 'viewer' && (${ehAdmin} || user = @request.auth.id)`;

    const c = new Collection({
      type: 'base',
      name: 'formacoes',
      listRule: ver,
      viewRule: ver,
      createRule: criar,
      updateRule: alterar,
      deleteRule: apagar,
      fields: [
        { type: 'relation', name: 'empresa', required: true, maxSelect: 1, collectionId: empresas.id, cascadeDelete: true },
        // chave da pessoa: "u:<id da conta>" ou "c:<id do colaborador>"
        { type: 'text', name: 'pessoa', required: true, max: 60 },
        { type: 'text', name: 'nome', required: false, max: 80 },
        { type: 'relation', name: 'user', required: false, maxSelect: 1, collectionId: users.id, cascadeDelete: false },
        { type: 'text', name: 'titulo', required: true, max: 120 },
        { type: 'select', name: 'tipo', required: true, maxSelect: 1, values: ['formacao', 'certificado', 'aptidao'] },
        { type: 'date', name: 'data_realizada', required: false },
        // sem validade = não caduca
        { type: 'date', name: 'validade', required: false },
        { type: 'text', name: 'entidade', required: false, max: 120 },
        { type: 'text', name: 'notas', required: false, max: 300 },
        {
          type: 'file',
          name: 'ficheiro',
          required: false,
          maxSelect: 1,
          maxSize: 10485760,
          protected: true,
          mimeTypes: ['application/pdf', 'image/jpeg', 'image/png', 'image/webp'],
        },
        { type: 'autodate', name: 'created', onCreate: true },
        { type: 'autodate', name: 'updated', onCreate: true, onUpdate: true },
      ],
      indexes: [
        'CREATE INDEX `idx_formacoes_empresa_validade` ON `formacoes` (`empresa`, `validade`)',
        'CREATE INDEX `idx_formacoes_pessoa` ON `formacoes` (`empresa`, `pessoa`)',
      ],
    });
    app.save(c);
  },
  (app) => {
    try {
      app.delete(app.findCollectionByNameOrId('formacoes'));
    } catch (_) {}
  },
);
