/// <reference path="../pb_data/types.d.ts" />

// Tarefas da equipa (quadros ao estilo Trello) — 2.19.0.
//
// `quadros`         um quadro por assunto ("Loja", "Eventos"…).
// `quadro_colunas`  as fases de cada quadro ("A fazer", "Em curso", "Feito");
//                   `concluida` marca a(s) coluna(s) de trabalho terminado.
// `tarefas`         cartões: título, descrição, responsáveis, prazo, etiquetas,
//                   lista de verificação (checklist) e a fase onde estão.
// `tarefa_comentarios` conversa de cada tarefa, com menções (@pessoa);
//                   `lida_por` = quem já viu a menção.
//
// Toda a empresa vê (a Leitura também, só a ver); quem não é de leitura cria,
// move e comenta. Apagar: o autor ou a administração. Um quadro/tarefa nunca
// muda de empresa nem de quadro, e os responsáveis/mencionados são da empresa.
migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');
    const users = app.findCollectionByNameOrId('users');

    const ehAdmin = "(@request.auth.papel = 'owner' || @request.auth.papel = 'admin')";
    const membro = "@request.auth.id != '' && empresa = @request.auth.empresa";
    const escreve = `${membro} && @request.auth.papel != 'viewer'`;
    const criaEscreve =
      "@request.auth.id != '' && @request.body.empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";
    const naoMuda = (campo) => `(@request.body.${campo}:isset = false || @request.body.${campo} = ${campo})`;
    const pessoasDaEmpresa = (campo) =>
      `(@request.body.${campo}:isset = false || @request.body.${campo}:length = 0 || @request.body.${campo}.empresa = @request.auth.empresa)`;

    // ---- quadros
    const quadros = new Collection({
      type: 'base',
      name: 'quadros',
      listRule: membro,
      viewRule: membro,
      createRule: `${criaEscreve} && @request.body.autor = @request.auth.id`,
      updateRule: `${escreve} && ${naoMuda('empresa')} && ${naoMuda('autor')}`,
      deleteRule: `${escreve} && (${ehAdmin} || autor = @request.auth.id)`,
      fields: [
        { type: 'relation', name: 'empresa', required: true, maxSelect: 1, collectionId: empresas.id, cascadeDelete: true },
        { type: 'text', name: 'nome', required: true, max: 80 },
        { type: 'number', name: 'ordem', required: false },
        { type: 'bool', name: 'arquivado', required: false },
        { type: 'relation', name: 'autor', required: false, maxSelect: 1, collectionId: users.id, cascadeDelete: false },
        { type: 'autodate', name: 'created', onCreate: true },
        { type: 'autodate', name: 'updated', onCreate: true, onUpdate: true },
      ],
      indexes: ['CREATE INDEX `idx_quadros_empresa` ON `quadros` (`empresa`, `arquivado`)'],
    });
    app.save(quadros);

    // ---- colunas (fases)
    const colunas = new Collection({
      type: 'base',
      name: 'quadro_colunas',
      listRule: membro,
      viewRule: membro,
      createRule: `${criaEscreve} && @request.body.quadro.empresa = @request.auth.empresa`,
      updateRule: `${escreve} && ${naoMuda('empresa')} && ${naoMuda('quadro')}`,
      deleteRule: escreve,
      fields: [
        { type: 'relation', name: 'empresa', required: true, maxSelect: 1, collectionId: empresas.id, cascadeDelete: true },
        { type: 'relation', name: 'quadro', required: true, maxSelect: 1, collectionId: quadros.id, cascadeDelete: true },
        { type: 'text', name: 'nome', required: true, max: 60 },
        { type: 'number', name: 'ordem', required: false },
        // as tarefas aqui contam como feitas (não aparecem como atrasadas)
        { type: 'bool', name: 'concluida', required: false },
        { type: 'autodate', name: 'created', onCreate: true },
        { type: 'autodate', name: 'updated', onCreate: true, onUpdate: true },
      ],
      indexes: ['CREATE INDEX `idx_quadro_colunas_quadro` ON `quadro_colunas` (`quadro`, `ordem`)'],
    });
    app.save(colunas);

    // ---- tarefas (cartões)
    const tarefas = new Collection({
      type: 'base',
      name: 'tarefas',
      listRule: membro,
      viewRule: membro,
      createRule:
        `${criaEscreve} && @request.body.quadro.empresa = @request.auth.empresa` +
        ` && @request.body.coluna.quadro = @request.body.quadro && @request.body.autor = @request.auth.id` +
        ` && ${pessoasDaEmpresa('responsaveis')}`,
      updateRule:
        `${escreve} && ${naoMuda('empresa')} && ${naoMuda('quadro')} && ${naoMuda('autor')}` +
        ` && (@request.body.coluna:isset = false || @request.body.coluna.quadro = quadro)` +
        ` && ${pessoasDaEmpresa('responsaveis')}`,
      deleteRule: `${escreve} && (${ehAdmin} || autor = @request.auth.id)`,
      fields: [
        { type: 'relation', name: 'empresa', required: true, maxSelect: 1, collectionId: empresas.id, cascadeDelete: true },
        { type: 'relation', name: 'quadro', required: true, maxSelect: 1, collectionId: quadros.id, cascadeDelete: true },
        // sem cascata: uma fase com tarefas não se apaga por engano
        { type: 'relation', name: 'coluna', required: true, maxSelect: 1, collectionId: colunas.id, cascadeDelete: false },
        { type: 'text', name: 'titulo', required: true, max: 200 },
        { type: 'text', name: 'descricao', required: false, max: 5000 },
        { type: 'number', name: 'ordem', required: false },
        { type: 'relation', name: 'responsaveis', required: false, maxSelect: 20, collectionId: users.id, cascadeDelete: false },
        { type: 'date', name: 'prazo', required: false },
        // ["Urgente", "Loja"]
        { type: 'json', name: 'etiquetas', required: false, maxSize: 2000 },
        // [{"t": "Comprar farinha", "f": false}]
        { type: 'json', name: 'checklist', required: false, maxSize: 20000 },
        { type: 'bool', name: 'arquivada', required: false },
        { type: 'relation', name: 'autor', required: false, maxSelect: 1, collectionId: users.id, cascadeDelete: false },
        { type: 'text', name: 'autor_nome', required: false, max: 80 },
        { type: 'autodate', name: 'created', onCreate: true },
        { type: 'autodate', name: 'updated', onCreate: true, onUpdate: true },
      ],
      indexes: [
        'CREATE INDEX `idx_tarefas_quadro` ON `tarefas` (`quadro`, `arquivada`, `coluna`)',
        'CREATE INDEX `idx_tarefas_empresa` ON `tarefas` (`empresa`, `arquivada`)',
      ],
    });
    app.save(tarefas);

    // ---- comentários (com menções)
    // Editar: o autor (texto/menções). Marcar como lida: qualquer membro, só o
    // campo `lida_por`.
    const soLida =
      "(@request.body.texto:isset = false && @request.body.mencoes:isset = false && @request.body.autor:isset = false" +
      " && @request.body.autor_nome:isset = false && @request.body.tarefa:isset = false && @request.body.empresa:isset = false)";
    const comentarios = new Collection({
      type: 'base',
      name: 'tarefa_comentarios',
      listRule: membro,
      viewRule: membro,
      createRule:
        `${criaEscreve} && @request.body.tarefa.empresa = @request.auth.empresa && @request.body.autor = @request.auth.id` +
        ` && ${pessoasDaEmpresa('mencoes')} && ${pessoasDaEmpresa('lida_por')}`,
      updateRule:
        `${membro} && ${naoMuda('empresa')} && ${naoMuda('tarefa')} && ${naoMuda('autor')}` +
        ` && ${pessoasDaEmpresa('mencoes')} && ${pessoasDaEmpresa('lida_por')}` +
        ` && ((@request.auth.papel != 'viewer' && autor = @request.auth.id) || ${soLida})`,
      deleteRule: `${escreve} && (${ehAdmin} || autor = @request.auth.id)`,
      fields: [
        { type: 'relation', name: 'empresa', required: true, maxSelect: 1, collectionId: empresas.id, cascadeDelete: true },
        { type: 'relation', name: 'tarefa', required: true, maxSelect: 1, collectionId: tarefas.id, cascadeDelete: true },
        { type: 'relation', name: 'autor', required: false, maxSelect: 1, collectionId: users.id, cascadeDelete: false },
        { type: 'text', name: 'autor_nome', required: false, max: 80 },
        { type: 'text', name: 'texto', required: true, max: 2000 },
        { type: 'relation', name: 'mencoes', required: false, maxSelect: 20, collectionId: users.id, cascadeDelete: false },
        { type: 'relation', name: 'lida_por', required: false, maxSelect: 50, collectionId: users.id, cascadeDelete: false },
        { type: 'autodate', name: 'created', onCreate: true },
        { type: 'autodate', name: 'updated', onCreate: true, onUpdate: true },
      ],
      indexes: ['CREATE INDEX `idx_tarefa_comentarios_tarefa` ON `tarefa_comentarios` (`tarefa`, `created`)'],
    });
    app.save(comentarios);
  },
  (app) => {
    for (const nome of ['tarefa_comentarios', 'tarefas', 'quadro_colunas', 'quadros']) {
      try {
        app.delete(app.findCollectionByNameOrId(nome));
      } catch (_) {}
    }
  },
);
