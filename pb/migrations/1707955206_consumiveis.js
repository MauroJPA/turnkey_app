/// <reference path="../pb_data/types.d.ts" />

// Consumíveis: produtos de limpeza/desinfeção e outros insumos que não entram
// nas receitas mas exigem documentação (ficha de dados de segurança — FDS —,
// ficha técnica, certificados). `consumivel_documentos` guarda os ficheiros
// (protegidos: só abrem com token de curta duração, como as faturas).
// `nomes_fatura` guarda as descrições de fatura já associadas a cada consumível,
// para as faturas seguintes ligarem sozinhas (e trazerem os documentos).

migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');

    const podeVer = "@request.auth.id != '' && empresa = @request.auth.empresa";
    const podeCriar =
      "@request.auth.id != '' && @request.body.empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";
    const podeEscrever =
      "@request.auth.id != '' && empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";

    const cons = new Collection({
      type: 'base',
      name: 'consumiveis',
      listRule: podeVer,
      viewRule: podeVer,
      createRule: podeCriar,
      updateRule: podeEscrever,
      deleteRule: podeEscrever,
      fields: [
        { type: 'relation', name: 'empresa', required: true, maxSelect: 1, collectionId: empresas.id, cascadeDelete: true },
        { type: 'text', name: 'nome', required: true, max: 250 },
        {
          type: 'select',
          name: 'categoria',
          required: false,
          maxSelect: 1,
          values: ['limpeza', 'desinfecao', 'higiene', 'insumo', 'outro'],
        },
        { type: 'text', name: 'marca', required: false, max: 200 },
        { type: 'text', name: 'fornecedor', required: false, max: 200 },
        // "5 L", "750 ml", "caixa de 100" — texto livre.
        { type: 'text', name: 'embalagem', required: false, max: 120 },
        { type: 'number', name: 'preco', required: false, min: 0 },
        { type: 'date', name: 'preco_atualizado_em', required: false },
        // Se a ASAE/HACCP exige ficha de dados de segurança para este item.
        { type: 'bool', name: 'exige_fds', required: false },
        { type: 'text', name: 'notas', required: false, max: 2000 },
        { type: 'json', name: 'nomes_fatura', required: false, maxSize: 20000 },
        { type: 'bool', name: 'deletado', required: false },
      ],
      indexes: [
        'CREATE INDEX `idx_consumiveis_empresa` ON `consumiveis` (`empresa`, `deletado`)',
      ],
    });
    cons.fields.add(new Field({ type: 'autodate', name: 'created', onCreate: true, onUpdate: false }));
    cons.fields.add(new Field({ type: 'autodate', name: 'updated', onCreate: true, onUpdate: true }));
    app.save(cons);

    const consumiveis = app.findCollectionByNameOrId('consumiveis');
    const pertenceAEmpresa =
      "(@request.body.consumivel:isset = false || @request.body.consumivel = '' || @request.body.consumivel.empresa = @request.auth.empresa)";

    const docs = new Collection({
      type: 'base',
      name: 'consumivel_documentos',
      listRule: podeVer,
      viewRule: podeVer,
      createRule: podeCriar + ' && ' + pertenceAEmpresa,
      updateRule: podeEscrever + ' && ' + pertenceAEmpresa,
      deleteRule: podeEscrever,
      fields: [
        { type: 'relation', name: 'empresa', required: true, maxSelect: 1, collectionId: empresas.id, cascadeDelete: true },
        { type: 'relation', name: 'consumivel', required: true, maxSelect: 1, collectionId: consumiveis.id, cascadeDelete: true },
        {
          type: 'select',
          name: 'tipo',
          required: true,
          maxSelect: 1,
          values: ['fds', 'ficha_tecnica', 'certificado', 'outro'],
        },
        { type: 'text', name: 'titulo', required: false, max: 250 },
        { type: 'text', name: 'versao', required: false, max: 80 },
        // Data do documento (revisão da FDS, emissão do certificado).
        { type: 'date', name: 'data_documento', required: false },
        {
          type: 'file',
          name: 'ficheiro',
          required: true,
          maxSelect: 1,
          maxSize: 20971520,
          protected: true,
          mimeTypes: ['application/pdf', 'image/jpeg', 'image/png', 'image/webp'],
        },
      ],
      indexes: [
        'CREATE INDEX `idx_cons_docs_consumivel` ON `consumivel_documentos` (`consumivel`)',
        'CREATE INDEX `idx_cons_docs_empresa` ON `consumivel_documentos` (`empresa`)',
      ],
    });
    docs.fields.add(new Field({ type: 'autodate', name: 'created', onCreate: true, onUpdate: false }));
    docs.fields.add(new Field({ type: 'autodate', name: 'updated', onCreate: true, onUpdate: true }));
    app.save(docs);

    // Linhas de fatura que correspondem a um consumível (em vez de um ingrediente).
    const itens = app.findCollectionByNameOrId('faturas_itens');
    itens.fields.add(
      new Field({ type: 'relation', name: 'consumivel', required: false, maxSelect: 1, collectionId: consumiveis.id, cascadeDelete: false }),
    );
    app.save(itens);
  },
  (app) => {
    const itens = app.findCollectionByNameOrId('faturas_itens');
    itens.fields.removeByName('consumivel');
    app.save(itens);
    app.delete(app.findCollectionByNameOrId('consumivel_documentos'));
    app.delete(app.findCollectionByNameOrId('consumiveis'));
  },
);
