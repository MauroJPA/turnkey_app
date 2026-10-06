/// <reference path="../pb_data/types.d.ts" />

// Anotações da equipa — 1.94.0.
//
// `anotacoes`: recados, ocorrências e lembretes partilhados pela equipa (quem
// não é de leitura). Cada um edita e apaga as suas; a administração, todas.
// Qualquer pessoa pode fixar/arquivar (marcar como tratada) uma nota dos outros,
// mas não mudar o texto.
migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');
    const users = app.findCollectionByNameOrId('users');

    const ehAdmin = "(@request.auth.papel = 'owner' || @request.auth.papel = 'admin')";
    const podeVer = "@request.auth.id != '' && empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";
    const podeCriar =
      "@request.auth.id != '' && @request.body.empresa = @request.auth.empresa && @request.auth.papel != 'viewer' && @request.body.autor = @request.auth.id";
    const soEstado =
      "(@request.body.titulo:isset = false && @request.body.texto:isset = false && @request.body.categoria:isset = false && @request.body.lembrar_em:isset = false && @request.body.autor:isset = false && @request.body.autor_nome:isset = false && @request.body.empresa:isset = false)";
    const podeEditar = `${podeVer} && (${ehAdmin} || autor = @request.auth.id || ${soEstado})`;
    const podeApagar = `${podeVer} && (${ehAdmin} || autor = @request.auth.id)`;

    const c = new Collection({
      type: 'base',
      name: 'anotacoes',
      listRule: podeVer,
      viewRule: podeVer,
      createRule: podeCriar,
      updateRule: podeEditar,
      deleteRule: podeApagar,
      fields: [
        { type: 'relation', name: 'empresa', required: true, maxSelect: 1, collectionId: empresas.id, cascadeDelete: true },
        { type: 'text', name: 'titulo', required: false, max: 120 },
        { type: 'text', name: 'texto', required: true, max: 2000 },
        { type: 'select', name: 'categoria', required: true, maxSelect: 1, values: ['recado', 'ocorrencia', 'lembrete'] },
        { type: 'bool', name: 'fixada', required: false },
        { type: 'bool', name: 'arquivada', required: false },
        // lembretes: a partir deste dia a nota aparece no Início
        { type: 'date', name: 'lembrar_em', required: false },
        { type: 'relation', name: 'autor', required: false, maxSelect: 1, collectionId: users.id, cascadeDelete: false },
        { type: 'text', name: 'autor_nome', required: false, max: 80 },
        { type: 'autodate', name: 'created', onCreate: true },
        { type: 'autodate', name: 'updated', onCreate: true, onUpdate: true },
      ],
      indexes: [
        'CREATE INDEX `idx_anotacoes_empresa` ON `anotacoes` (`empresa`, `arquivada`, `created`)',
      ],
    });
    app.save(c);
  },
  (app) => {
    app.delete(app.findCollectionByNameOrId('anotacoes'));
  },
);
