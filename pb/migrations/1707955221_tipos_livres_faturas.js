/// <reference path="../pb_data/types.d.ts" />

// Ao validar faturas, os "tipos" de embalagem (Caixa/Saco/Saqueta…) e de
// consumível (Limpeza/Desinfeção/Higiene/Insumo…) deixam de ser listas fixas
// — passam a texto livre, tal como marca/fornecedor já funcionam (sugestões
// dos valores já usados na empresa, mas dá para escrever um novo a qualquer
// momento). Isto também acrescenta "Bebida" e "Revenda" como categorias de
// consumível (sem exigirem ficha de dados de segurança) e um `preco_venda`
// opcional em `consumiveis`, para dar para ver a margem de itens revendidos
// tal como já acontece com as fichas técnicas.

migrate(
  (app) => {
    // embalagens.tipo: select fixo -> texto livre (os valores já eram os
    // rótulos certos: 'Caixa', 'Saco'… — não é preciso converter nada).
    const embalagens = app.findCollectionByNameOrId('embalagens');
    const campoTipo = embalagens.fields.getByName('tipo');
    if (campoTipo && campoTipo.type() === 'select') {
      embalagens.fields.removeByName('tipo');
      embalagens.fields.add(
        new Field({ type: 'text', name: 'tipo', required: false, max: 80 }),
      );
      app.save(embalagens);
    }

    // consumiveis.categoria: select fixo -> texto livre. Os valores antigos
    // ('limpeza', 'desinfecao'…) eram as chaves internas — convertem-se para
    // o rótulo com maiúscula inicial (o que já aparecia na app).
    const rotulos = {
      limpeza: 'Limpeza',
      desinfecao: 'Desinfeção',
      higiene: 'Higiene',
      insumo: 'Insumo',
      outro: 'Outro',
    };
    const consumiveis = app.findCollectionByNameOrId('consumiveis');
    const campoCategoria = consumiveis.fields.getByName('categoria');
    if (campoCategoria && campoCategoria.type() === 'select') {
      // guarda o valor antigo de cada registo ANTES de mudar o esquema — os
      // Record já lidos ficam presos ao tipo antigo (select) e recusam
      // gravar um texto que não seja um dos valores fixos.
      const antigos = {};
      for (const r of app.findAllRecords('consumiveis')) {
        antigos[r.id] = r.getString('categoria');
      }
      consumiveis.fields.removeByName('categoria');
      consumiveis.fields.add(
        new Field({ type: 'text', name: 'categoria', required: false, max: 80 }),
      );
      app.save(consumiveis);
      for (const r of app.findAllRecords('consumiveis')) {
        r.set('categoria', rotulos[antigos[r.id]] || 'Outro');
        app.save(r);
      }
    }

    // preco_venda: para Bebidas/Revenda vendidas ao cliente — opcional, os
    // produtos de limpeza/insumo continuam sem preço de venda preenchido.
    if (!consumiveis.fields.getByName('preco_venda')) {
      consumiveis.fields.add(
        new Field({ type: 'number', name: 'preco_venda', required: false, min: 0 }),
      );
      app.save(consumiveis);
    }
  },
  (app) => {
    const consumiveis = app.findCollectionByNameOrId('consumiveis');
    if (consumiveis.fields.getByName('preco_venda')) {
      consumiveis.fields.removeByName('preco_venda');
      app.save(consumiveis);
    }

    const paraApi = {
      limpeza: 'limpeza',
      desinfeção: 'desinfecao',
      desinfecao: 'desinfecao',
      higiene: 'higiene',
      insumo: 'insumo',
    };
    const campoCategoria = consumiveis.fields.getByName('categoria');
    if (campoCategoria && campoCategoria.type() === 'text') {
      const valores = {};
      for (const r of app.findAllRecords('consumiveis')) {
        const chave = r.getString('categoria').toLowerCase();
        valores[r.id] = paraApi[chave] || 'outro';
      }
      consumiveis.fields.removeByName('categoria');
      consumiveis.fields.add(
        new Field({
          type: 'select',
          name: 'categoria',
          required: false,
          maxSelect: 1,
          values: ['limpeza', 'desinfecao', 'higiene', 'insumo', 'outro'],
        }),
      );
      app.save(consumiveis);
      for (const r of app.findAllRecords('consumiveis')) {
        r.set('categoria', valores[r.id] || 'outro');
        app.save(r);
      }
    }

    const embalagens = app.findCollectionByNameOrId('embalagens');
    const campoTipo = embalagens.fields.getByName('tipo');
    if (campoTipo && campoTipo.type() === 'text') {
      const validos = new Set([
        'Caixa',
        'Saco',
        'Saqueta',
        'Adesivo',
        'Fita',
        'Cartão',
        'Outro',
      ]);
      const valores = {};
      for (const r of app.findAllRecords('embalagens')) {
        const v = r.getString('tipo');
        valores[r.id] = validos.has(v) ? v : 'Outro';
      }
      embalagens.fields.removeByName('tipo');
      embalagens.fields.add(
        new Field({
          type: 'select',
          name: 'tipo',
          required: false,
          maxSelect: 1,
          values: ['Caixa', 'Saco', 'Saqueta', 'Adesivo', 'Fita', 'Cartão', 'Outro'],
        }),
      );
      app.save(embalagens);
      for (const r of app.findAllRecords('embalagens')) {
        r.set('tipo', valores[r.id] || 'Outro');
        app.save(r);
      }
    }
  },
);
