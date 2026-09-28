/// <reference path="../pb_data/types.d.ts" />

// `notas_pagina` — nota de equipa numa página da app (diferente de
// `sugestoes`, que só os programadores leem): qualquer pessoa da empresa vê
// e escreve, para avisar colegas de um problema ou decisão sem precisar de
// falar por fora da app ("esta fatura tem o total errado", "falta a foto do
// rótulo"…). Marca-se como resolvida quando já não faz falta.
//
// `pagina` usa a mesma chave dos tópicos de ajuda (HelpTopic.name), por isso
// cobre todas as páginas que já têm o botão de ajuda/sugestão, sem precisar
// de ligar caso a caso.

migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');
    const users = app.findCollectionByNameOrId('users');

    const podeVer = "@request.auth.id != '' && empresa = @request.auth.empresa";
    const podeCriar =
      "@request.auth.id != '' && @request.body.empresa = @request.auth.empresa";
    const podeResolver =
      "@request.auth.id != '' && empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";
    const podeApagar =
      "@request.auth.id != '' && empresa = @request.auth.empresa && (@request.auth.papel = 'owner' || @request.auth.papel = 'admin')";

    const c = new Collection({
      type: 'base',
      name: 'notas_pagina',
      listRule: podeVer,
      viewRule: podeVer,
      createRule: podeCriar,
      updateRule: podeResolver,
      deleteRule: podeApagar,
      fields: [
        {
          type: 'relation',
          name: 'empresa',
          required: true,
          maxSelect: 1,
          collectionId: empresas.id,
          cascadeDelete: true,
        },
        {
          type: 'relation',
          name: 'autor',
          required: false,
          maxSelect: 1,
          collectionId: users.id,
          cascadeDelete: false,
        },
        // instantâneo do nome de quem escreveu/resolveu — continua legível
        // mesmo que a pessoa saia da equipa depois.
        { type: 'text', name: 'autor_nome', required: false, max: 200 },
        { type: 'text', name: 'pagina', required: true, max: 60 },
        { type: 'text', name: 'texto', required: true, max: 2000 },
        { type: 'bool', name: 'resolvida', required: false },
        { type: 'date', name: 'resolvida_em', required: false },
        { type: 'text', name: 'resolvida_por', required: false, max: 200 },
      ],
      indexes: [
        'CREATE INDEX `idx_notas_pagina_empresa_pagina` ON `notas_pagina` (`empresa`, `pagina`)',
      ],
    });
    c.fields.add(
      new Field({ type: 'autodate', name: 'created', onCreate: true }),
    );
    app.save(c);
  },
  (app) => {
    app.delete(app.findCollectionByNameOrId('notas_pagina'));
  },
);
