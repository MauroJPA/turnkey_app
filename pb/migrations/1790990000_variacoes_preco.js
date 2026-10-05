/// <reference path="../pb_data/types.d.ts" />

// Alerta de variação de preço: cada vez que o preço de um ingrediente muda
// (ex.: ao aplicar uma fatura) o servidor regista a variação e as fichas
// técnicas afetadas (custo antes/depois). Só o servidor escreve (create/update/
// delete sem regra = só superutilizador/hook). `configuracoes_custo.alerta_preco_pct`
// é o limiar (%) a partir do qual a app avisa.
migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');
    const ingredientes = app.findCollectionByNameOrId('ingredientes');
    const podeVer = "@request.auth.id != '' && empresa = @request.auth.empresa";

    const c = new Collection({
      type: 'base',
      name: 'variacoes_preco',
      listRule: podeVer,
      viewRule: podeVer,
      createRule: null,
      updateRule: null,
      deleteRule: null,
      fields: [
        { type: 'relation', name: 'empresa', required: true, maxSelect: 1, collectionId: empresas.id, cascadeDelete: true },
        { type: 'relation', name: 'ingrediente', required: false, maxSelect: 1, collectionId: ingredientes.id, cascadeDelete: true },
        { type: 'text', name: 'ingrediente_nome', required: false, max: 250 },
        // preço por kg (ou por unidade se não houver gramas) antes e depois
        { type: 'number', name: 'antes', required: false },
        { type: 'number', name: 'depois', required: false },
        { type: 'number', name: 'pct', required: false },
        // [{ id, nome, custo_antes, custo_depois, preco_venda }]
        { type: 'json', name: 'afetadas', required: false, maxSize: 200000 },
        { type: 'autodate', name: 'created', onCreate: true },
      ],
      indexes: [
        'CREATE INDEX `idx_variacoes_preco_empresa` ON `variacoes_preco` (`empresa`, `created`)',
      ],
    });
    app.save(c);

    const cfg = app.findCollectionByNameOrId('configuracoes_custo');
    if (!cfg.fields.getByName('alerta_preco_pct')) {
      cfg.fields.add(
        new Field({ type: 'number', name: 'alerta_preco_pct', required: false, min: 1, max: 100 }),
      );
      app.save(cfg);
    }
  },
  (app) => {
    try {
      app.delete(app.findCollectionByNameOrId('variacoes_preco'));
    } catch (_) {}
    const cfg = app.findCollectionByNameOrId('configuracoes_custo');
    if (cfg.fields.getByName('alerta_preco_pct')) {
      cfg.fields.removeByName('alerta_preco_pct');
      app.save(cfg);
    }
  },
);
