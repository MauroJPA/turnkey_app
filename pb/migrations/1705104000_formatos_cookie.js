/// <reference path="../pb_data/types.d.ts" />

// Fase 3 — `formatos_cookie` (tamanhos de cookie por empresa).
// Semeia os 3 formatos atuais da Gookie em todas as empresas existentes;
// o onboarding faz o mesmo para novas empresas.

migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');

    const podeVer = "@request.auth.id != '' && empresa = @request.auth.empresa";
    const podeCriar =
      "@request.auth.id != '' && @request.body.empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";
    const podeEscrever =
      "@request.auth.id != '' && empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";

    const c = new Collection({
      type: 'base',
      name: 'formatos_cookie',
      listRule: podeVer,
      viewRule: podeVer,
      createRule: podeCriar,
      updateRule: podeEscrever,
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
        { type: 'text', name: 'nome', required: true, max: 80 },
        { type: 'number', name: 'massa_g', required: true, min: 1 },
        { type: 'number', name: 'recheio_g', required: false, min: 0 },
        { type: 'number', name: 'ordem', required: false, min: 0 },
        { type: 'bool', name: 'ativo', required: false },
      ],
      indexes: [
        'CREATE UNIQUE INDEX `idx_formatos_nome` ON `formatos_cookie` (`empresa`, `nome`)',
      ],
    });
    c.fields.add(
      new Field({ type: 'autodate', name: 'created', onCreate: true }),
    );
    c.fields.add(
      new Field({
        type: 'autodate',
        name: 'updated',
        onCreate: true,
        onUpdate: true,
      }),
    );
    app.save(c);

    // Semear os formatos atuais em todas as empresas.
    const seed = [
      { nome: 'Mini', massa_g: 20, recheio_g: 0, ordem: 1 },
      { nome: 'Recheado', massa_g: 120, recheio_g: 30, ordem: 2 },
      { nome: 'Simples', massa_g: 150, recheio_g: 0, ordem: 3 },
    ];
    const todas = app.findAllRecords('empresas');
    for (const emp of todas) {
      for (const f of seed) {
        const r = new Record(c);
        r.set('empresa', emp.id);
        r.set('nome', f.nome);
        r.set('massa_g', f.massa_g);
        r.set('recheio_g', f.recheio_g);
        r.set('ordem', f.ordem);
        r.set('ativo', true);
        app.save(r);
      }
    }
  },
  (app) => {
    app.delete(app.findCollectionByNameOrId('formatos_cookie'));
  },
);
