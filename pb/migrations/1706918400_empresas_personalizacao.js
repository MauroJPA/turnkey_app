/// <reference path="../pb_data/types.d.ts" />

// Personalização avançada da empresa: cores por papel (secundária, fundo,
// texto), posição/tamanho/visibilidade do logótipo e do nome, e fonte de
// letra (nome + ficheiro para tipos de letra personalizados).

migrate(
  (app) => {
    const c = app.findCollectionByNameOrId('empresas');

    const addText = (name) => {
      if (!c.fields.getByName(name)) {
        c.fields.add(new Field({ type: 'text', name, required: false, max: 32 }));
      }
    };
    const addBool = (name) => {
      if (!c.fields.getByName(name)) {
        c.fields.add(new Field({ type: 'bool', name, required: false }));
      }
    };
    const addNumber = (name) => {
      if (!c.fields.getByName(name)) {
        c.fields.add(new Field({ type: 'number', name, required: false }));
      }
    };
    const addAlinhamento = (name) => {
      if (!c.fields.getByName(name)) {
        c.fields.add(
          new Field({
            type: 'select',
            name,
            required: false,
            maxSelect: 1,
            values: ['esquerda', 'centro', 'direita'],
          }),
        );
      }
    };

    // Cores adicionais (hex opcional; vazio = derivado automaticamente da
    // cor de marca, como hoje).
    addText('cor_secundaria');
    addText('cor_fundo');
    addText('cor_texto');

    // Logótipo: alinhamento, tamanho (px) e se está oculto (o valor por
    // omissão do campo bool é `false` = visível, por isso guarda-se o
    // "oculto" e não o "visível").
    addBool('logo_oculto');
    addAlinhamento('logo_alinhamento');
    addNumber('logo_tamanho');

    // Nome da marca: alinhamento, tamanho (px) e se está oculto.
    addBool('nome_oculto');
    addAlinhamento('nome_alinhamento');
    addNumber('nome_tamanho');

    // Tipo de letra personalizado.
    addText('fonte_familia');
    if (!c.fields.getByName('fonte_ficheiro')) {
      c.fields.add(
        new Field({
          type: 'file',
          name: 'fonte_ficheiro',
          required: false,
          maxSelect: 1,
          maxSize: 5242880,
          mimeTypes: [
            'font/ttf',
            'font/otf',
            'application/font-sfnt',
            'application/octet-stream',
          ],
        }),
      );
    }

    app.save(c);
  },
  (app) => {
    const c = app.findCollectionByNameOrId('empresas');
    for (const name of [
      'cor_secundaria',
      'cor_fundo',
      'cor_texto',
      'logo_oculto',
      'logo_alinhamento',
      'logo_tamanho',
      'nome_oculto',
      'nome_alinhamento',
      'nome_tamanho',
      'fonte_familia',
      'fonte_ficheiro',
    ]) {
      if (c.fields.getByName(name)) c.fields.removeByName(name);
    }
    app.save(c);
  },
);
