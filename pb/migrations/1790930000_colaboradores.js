/// <reference path="../pb_data/types.d.ts" />

// Colaboradores e cartões NFC para o quiosque de tarefas diárias: o telemóvel
// fica na loja/fábrica com a app aberta e cada pessoa encosta o seu cartão
// para registar limpezas, temperaturas, etc. — o registo fica com o nome dela.
//
// `colaboradores` — quem pode registar (não precisa de conta na app) e o
// número de série do seu cartão. Qualquer pessoa da empresa vê a lista (o
// quiosque precisa dela); só o proprietário/administrador cria, altera e
// apaga (um cartão identifica quem fez o registo).

migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');

    const ehOwnerOuAdmin =
      "(@request.auth.papel = 'owner' || @request.auth.papel = 'admin')";
    const podeVer = "@request.auth.id != '' && empresa = @request.auth.empresa";
    const podeGerir = `@request.auth.id != '' && empresa = @request.auth.empresa && ${ehOwnerOuAdmin}`;
    const podeCriar = `@request.auth.id != '' && @request.body.empresa = @request.auth.empresa && ${ehOwnerOuAdmin}`;

    const colaboradores = new Collection({
      type: 'base',
      name: 'colaboradores',
      listRule: podeVer,
      viewRule: podeVer,
      createRule: podeCriar,
      updateRule: podeGerir,
      deleteRule: podeGerir,
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
        // número de série do cartão NFC (só hexadecimal, em maiúsculas)
        { type: 'text', name: 'nfc_uid', required: false, max: 60 },
        { type: 'number', name: 'ordem', required: false },
        { type: 'bool', name: 'arquivado', required: false },
        { type: 'autodate', name: 'created', onCreate: true },
        { type: 'autodate', name: 'updated', onCreate: true, onUpdate: true },
      ],
      indexes: [
        'CREATE INDEX `idx_colaboradores_empresa` ON `colaboradores` (`empresa`)',
        // um cartão pertence a uma só pessoa
        "CREATE UNIQUE INDEX `idx_colaboradores_cartao` ON `colaboradores` (`empresa`, `nfc_uid`) WHERE `nfc_uid` != ''",
      ],
    });
    app.save(colaboradores);
  },
  (app) => {
    app.delete(app.findCollectionByNameOrId('colaboradores'));
  },
);
