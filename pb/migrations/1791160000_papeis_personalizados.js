/// <reference path="../pb_data/types.d.ts" />

// Papéis personalizados (2.21.0).
//
// `papeis_personalizados`: papéis com nome ("Balcão", "Cozinha",
// "Contabilista"…). Cada um parte de um papel BASE (admin, editor ou viewer),
// que é o que o servidor deixa fazer, e ajusta página a página o que se vê e
// edita (`acesso`: chave da página → 'oculto' | 'ver' | 'editar'); o que não
// muda herda do papel base. Só o proprietário cria, muda e apaga (como a
// matriz de acesso).
//
// `users.papel_personalizado`: o papel personalizado da pessoa (vazio = só o
// papel base). Só muda pelos endpoints da equipa (team.pb.js), que também põem
// `users.papel` = o papel base; o guards.pb.js recusa o resto. Apagar o papel
// limpa o campo nas pessoas (ficam com o papel base).
migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');

    const ehOwner = "@request.auth.papel = 'owner'";
    const membro = "@request.auth.id != '' && empresa = @request.auth.empresa";
    const naoMuda = (campo) => `(@request.body.${campo}:isset = false || @request.body.${campo} = ${campo})`;

    const papeis = new Collection({
      type: 'base',
      name: 'papeis_personalizados',
      listRule: membro,
      viewRule: membro,
      createRule: `@request.auth.id != '' && @request.body.empresa = @request.auth.empresa && ${ehOwner}`,
      updateRule: `${membro} && ${ehOwner} && ${naoMuda('empresa')}`,
      deleteRule: `${membro} && ${ehOwner}`,
      fields: [
        { type: 'relation', name: 'empresa', required: true, maxSelect: 1, collectionId: empresas.id, cascadeDelete: true },
        { type: 'text', name: 'nome', required: true, max: 40 },
        { type: 'select', name: 'base', required: true, maxSelect: 1, values: ['admin', 'editor', 'viewer'] },
        { type: 'json', name: 'acesso', required: false, maxSize: 20000 },
        { type: 'autodate', name: 'created', onCreate: true },
        { type: 'autodate', name: 'updated', onCreate: true, onUpdate: true },
      ],
      indexes: ['CREATE UNIQUE INDEX `idx_papeis_personalizados_nome` ON `papeis_personalizados` (`empresa`, `nome`)'],
    });
    app.save(papeis);

    const users = app.findCollectionByNameOrId('users');
    users.fields.add(
      new RelationField({ name: 'papel_personalizado', required: false, maxSelect: 1, collectionId: papeis.id, cascadeDelete: false }),
    );
    app.save(users);
  },
  (app) => {
    const users = app.findCollectionByNameOrId('users');
    users.fields.removeByName('papel_personalizado');
    app.save(users);
    try {
      app.delete(app.findCollectionByNameOrId('papeis_personalizados'));
    } catch (_) {}
  },
);
