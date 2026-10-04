/// <reference path="../pb_data/types.d.ts" />

// O quiosque de tarefas passa a mostrar a Equipa (os utilizadores da empresa)
// sem ser preciso criá-los outra vez. `colaboradores.user` liga uma linha a
// uma conta da equipa — é onde fica o cartão NFC dessa pessoa (e se foi
// escondida do quiosque). Linhas sem `user` continuam a servir para quem não
// tem conta na app.

migrate(
  (app) => {
    const users = app.findCollectionByNameOrId('users');
    const colab = app.findCollectionByNameOrId('colaboradores');

    if (!colab.fields.getByName('user')) {
      colab.fields.add(
        new Field({
          type: 'relation',
          name: 'user',
          required: false,
          maxSelect: 1,
          collectionId: users.id,
          cascadeDelete: true,
        }),
      );
    }

    // a conta ligada tem de ser da mesma empresa
    const mesmaEmpresa =
      "(@request.body.user:isset = false || @request.body.user = '' || @request.body.user.empresa = @request.auth.empresa)";
    colab.createRule = `(${colab.createRule}) && ${mesmaEmpresa}`;
    colab.updateRule = `(${colab.updateRule}) && ${mesmaEmpresa}`;

    colab.indexes = (colab.indexes || []).concat([
      // uma linha por conta
      "CREATE UNIQUE INDEX `idx_colaboradores_user` ON `colaboradores` (`empresa`, `user`) WHERE `user` != ''",
    ]);
    app.save(colab);
  },
  (app) => {
    const colab = app.findCollectionByNameOrId('colaboradores');
    colab.indexes = (colab.indexes || []).filter(
      (i) => i.indexOf('idx_colaboradores_user') < 0,
    );
    if (colab.fields.getByName('user')) {
      colab.fields.removeByName('user');
    }
    app.save(colab);
  },
);
