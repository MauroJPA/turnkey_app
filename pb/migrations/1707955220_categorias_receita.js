/// <reference path="../pb_data/types.d.ts" />

// Categorias de receitas deixam de ser uma lista fixa (Massa/Recheio/
// Cobertura/Outra, presa no código) e passam a ser geríveis por empresa —
// criar, renomear, desativar, apagar — tal como já acontece com os Formatos
// de cookie (ver 1705104000_formatos_cookie.js, mesmo padrão).
//
// `receitas.categoria` passa de `select` fixo para `text` livre: guarda o
// NOME da categoria escolhida (não um id), tal como `tech_sheets.categoria`
// já funciona. Os valores antigos ('massa'/'recheio'/'cobertura'/'outra')
// são convertidos para o rótulo capitalizado ('Massa'/'Recheio'/
// 'Cobertura'/'Outra'), que passa a ser também o nome semeado em
// `categorias_receita` — por isso nada muda visualmente para quem já tinha
// receitas.

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
      name: 'categorias_receita',
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
        { type: 'number', name: 'ordem', required: false, min: 0 },
        { type: 'bool', name: 'ativo', required: false },
      ],
      indexes: [
        'CREATE UNIQUE INDEX `idx_categorias_receita_nome` ON `categorias_receita` (`empresa`, `nome`)',
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

    // Semear as 4 categorias atuais em todas as empresas — mesmos nomes que
    // já apareciam (só com maiúscula inicial, como o resto da app).
    const seed = [
      { nome: 'Massa', ordem: 1 },
      { nome: 'Recheio', ordem: 2 },
      { nome: 'Cobertura', ordem: 3 },
      { nome: 'Outra', ordem: 4 },
    ];
    const todasEmpresas = app.findAllRecords('empresas');
    for (const emp of todasEmpresas) {
      for (const cat of seed) {
        const r = new Record(c);
        r.set('empresa', emp.id);
        r.set('nome', cat.nome);
        r.set('ordem', cat.ordem);
        r.set('ativo', true);
        app.save(r);
      }
    }

    // receitas.categoria: de select fixo para texto livre (guarda o nome).
    const rotulos = {
      massa: 'Massa',
      recheio: 'Recheio',
      cobertura: 'Cobertura',
      outra: 'Outra',
    };
    const receitas = app.findCollectionByNameOrId('receitas');
    const campoCategoria = receitas.fields.getByName('categoria');
    if (campoCategoria && campoCategoria.type() === 'select') {
      // guarda o valor antigo de cada receita ANTES de mudar o esquema — os
      // Record já lidos ficam presos ao tipo antigo (select) e recusam
      // gravar um texto que não seja um dos 4 valores fixos.
      const antigos = {};
      for (const r of app.findAllRecords('receitas')) {
        antigos[r.id] = r.getString('categoria');
      }
      receitas.fields.removeByName('categoria');
      receitas.fields.add(
        new Field({ type: 'text', name: 'categoria', required: true, max: 80 }),
      );
      app.save(receitas);
      for (const r of app.findAllRecords('receitas')) {
        r.set('categoria', rotulos[antigos[r.id]] || 'Outra');
        app.save(r);
      }
    }
  },
  (app) => {
    const receitas = app.findCollectionByNameOrId('receitas');
    const campoCategoria = receitas.fields.getByName('categoria');
    if (campoCategoria && campoCategoria.type() === 'text') {
      const paraApi = {
        massa: 'massa',
        recheio: 'recheio',
        cobertura: 'cobertura',
        outra: 'outra',
      };
      const valores = {};
      for (const r of app.findAllRecords('receitas')) {
        valores[r.id] = paraApi[r.getString('categoria').toLowerCase()] || 'outra';
      }
      receitas.fields.removeByName('categoria');
      receitas.fields.add(
        new Field({
          type: 'select',
          name: 'categoria',
          required: true,
          maxSelect: 1,
          values: ['massa', 'recheio', 'cobertura', 'outra'],
        }),
      );
      app.save(receitas);
      for (const r of app.findAllRecords('receitas')) {
        r.set('categoria', valores[r.id] || 'outra');
        app.save(r);
      }
    }
    app.delete(app.findCollectionByNameOrId('categorias_receita'));
  },
);
