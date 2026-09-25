/// <reference path="../pb_data/types.d.ts" />

// Ingredientes genéricos + produtos de compra.
//
// `ingredientes` passa a ser o ingrediente GENÉRICO ("Açúcar branco", "Cravinho
// em pó"), o que as receitas usam. `ingrediente_produtos` são as variantes que
// se compram (marca, fornecedor, embalagem, preço) e o que as faturas trazem
// ("Açúcar Sidul BCO granulado KG"). O custo do genérico vem do produto com a
// compra mais recente (hook produtos.pb.js). `nomes_fatura` guarda as
// descrições de fatura já associadas a este produto, para emparelhar sozinho
// nas faturas seguintes.
//
// Os ingredientes já existentes ficam como genéricos com um produto cada
// (mesmos preços e embalagens: nenhum custo muda).

migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');
    const ingredientes = app.findCollectionByNameOrId('ingredientes');
    const pertenceAEmpresa =
      "(@request.body.ingrediente:isset = false || @request.body.ingrediente = '' || @request.body.ingrediente.empresa = @request.auth.empresa)";

    const c = new Collection({
      type: 'base',
      name: 'ingrediente_produtos',
      listRule: "@request.auth.id != '' && empresa = @request.auth.empresa",
      viewRule: "@request.auth.id != '' && empresa = @request.auth.empresa",
      createRule:
        "@request.auth.id != '' && @request.body.empresa = @request.auth.empresa && @request.auth.papel != 'viewer' && " +
        pertenceAEmpresa,
      updateRule:
        "@request.auth.id != '' && empresa = @request.auth.empresa && @request.auth.papel != 'viewer' && " +
        pertenceAEmpresa,
      deleteRule:
        "@request.auth.id != '' && empresa = @request.auth.empresa && @request.auth.papel != 'viewer'",
      fields: [
        { type: 'relation', name: 'empresa', required: true, maxSelect: 1, collectionId: empresas.id, cascadeDelete: true },
        { type: 'relation', name: 'ingrediente', required: true, maxSelect: 1, collectionId: ingredientes.id, cascadeDelete: true },
        { type: 'text', name: 'nome', required: true, max: 250 },
        { type: 'text', name: 'marca', required: false, max: 200 },
        { type: 'text', name: 'fornecedor', required: false, max: 200 },
        { type: 'number', name: 'embalagem_g', required: false, min: 0 },
        { type: 'number', name: 'preco', required: false, min: 0 },
        { type: 'date', name: 'preco_atualizado_em', required: false },
        { type: 'json', name: 'nomes_fatura', required: false, maxSize: 20000 },
      ],
      indexes: [
        'CREATE INDEX `idx_ing_produtos_ingrediente` ON `ingrediente_produtos` (`ingrediente`)',
        'CREATE INDEX `idx_ing_produtos_empresa` ON `ingrediente_produtos` (`empresa`)',
      ],
    });
    c.fields.add(new Field({ type: 'autodate', name: 'created', onCreate: true, onUpdate: false }));
    c.fields.add(new Field({ type: 'autodate', name: 'updated', onCreate: true, onUpdate: true }));
    app.save(c);

    // Cada ingrediente comprado já existente passa a ter um produto (mesmos valores).
    const existentes = app.findRecordsByFilter(
      'ingredientes',
      "origem != 'fabrico_proprio' && preco > 0 && gramas_embalagem > 0",
      '',
      0,
      0,
    );
    const col = app.findCollectionByNameOrId('ingrediente_produtos');
    for (const ing of existentes) {
      const p = new Record(col);
      p.set('empresa', ing.getString('empresa'));
      p.set('ingrediente', ing.id);
      p.set('nome', ing.getString('nome'));
      p.set('marca', ing.getString('marca'));
      p.set('fornecedor', ing.getString('fornecedor'));
      p.set('embalagem_g', ing.getFloat('gramas_embalagem'));
      p.set('preco', ing.getFloat('preco'));
      const data = ing.getString('preco_atualizado_em');
      if (data) p.set('preco_atualizado_em', data);
      p.set('nomes_fatura', []);
      app.save(p);
    }
  },
  (app) => {
    app.delete(app.findCollectionByNameOrId('ingrediente_produtos'));
  },
);
