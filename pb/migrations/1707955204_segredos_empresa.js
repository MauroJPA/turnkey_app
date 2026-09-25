/// <reference path="../pb_data/types.d.ts" />

// `segredos_empresa`: chaves/tokens de serviços externos de cada empresa (ex.:
// o token do Vendus), guardados CIFRADOS (AES-256-GCM) com a chave-mestra
// `GC_TURNKEY_ENC_KEY` que só existe no ambiente do servidor (pb\.env), nunca na
// base de dados nem nos backups. Sem regras de API (null): ninguém lê nem
// escreve por REST; só os hooks do servidor (pb/hooks/segredos.js).

migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');
    const users = app.findCollectionByNameOrId('users');
    const c = new Collection({
      type: 'base',
      name: 'segredos_empresa',
      listRule: null,
      viewRule: null,
      createRule: null,
      updateRule: null,
      deleteRule: null,
      fields: [
        { type: 'relation', name: 'empresa', required: true, maxSelect: 1, collectionId: empresas.id, cascadeDelete: true },
        { type: 'text', name: 'servico', required: true, max: 40 },
        { type: 'text', name: 'valor_cifrado', required: true, max: 4000 },
        { type: 'text', name: 'sufixo', required: false, max: 8 },
        { type: 'relation', name: 'atualizado_por', required: false, maxSelect: 1, collectionId: users.id, cascadeDelete: false },
      ],
      indexes: [
        'CREATE UNIQUE INDEX `idx_segredos_empresa_servico` ON `segredos_empresa` (`empresa`, `servico`)',
      ],
    });
    c.fields.add(new Field({ type: 'autodate', name: 'created', onCreate: true, onUpdate: false }));
    c.fields.add(new Field({ type: 'autodate', name: 'updated', onCreate: true, onUpdate: true }));
    app.save(c);
  },
  (app) => {
    app.delete(app.findCollectionByNameOrId('segredos_empresa'));
  },
);
