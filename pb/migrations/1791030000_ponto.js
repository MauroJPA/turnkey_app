/// <reference path="../pb_data/types.d.ts" />

// Registo de ponto (entrada, pausa, saída) — 1.92.0.
//
// `ponto_registos`: uma marcação de uma pessoa (da Equipa ou sem conta). Quem
// regista é qualquer pessoa da empresa que não seja de leitura (o quiosque marca
// o ponto de toda a gente), mas só o proprietário/administrador lê todas as
// marcações; cada pessoa lê as suas (campo `user`). Só o proprietário/administrador
// corrige ou apaga; uma correção fica assinalada (`corrigido` + hora original).
// `GET /api/gc_turnkey/ponto/estado` (hooks/ponto.pb.js) diz ao quiosque qual foi
// a última marcação de cada pessoa, sem expor o resto.
migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');
    const users = app.findCollectionByNameOrId('users');

    const ehAdmin = "(@request.auth.papel = 'owner' || @request.auth.papel = 'admin')";
    const podeVer = `@request.auth.id != '' && empresa = @request.auth.empresa && (${ehAdmin} || user = @request.auth.id)`;
    const podeCriar =
      "@request.auth.id != '' && @request.body.empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";
    const admin = `@request.auth.id != '' && empresa = @request.auth.empresa && ${ehAdmin}`;
    const mesma = (campo) =>
      `(@request.body.${campo}:isset = false || @request.body.${campo} = '' || @request.body.${campo}.empresa = @request.auth.empresa)`;

    const c = new Collection({
      type: 'base',
      name: 'ponto_registos',
      listRule: podeVer,
      viewRule: podeVer,
      createRule: `(${podeCriar}) && ${mesma('user')}`,
      updateRule: `(${admin}) && ${mesma('user')}`,
      deleteRule: admin,
      fields: [
        { type: 'relation', name: 'empresa', required: true, maxSelect: 1, collectionId: empresas.id, cascadeDelete: true },
        // chave da pessoa: "u:<id da conta>" ou "c:<id do colaborador>"
        { type: 'text', name: 'pessoa', required: true, max: 60 },
        { type: 'text', name: 'nome', required: false, max: 80 },
        // a conta, se a pessoa tem uma (é o que deixa cada um ver as suas marcações)
        { type: 'relation', name: 'user', required: false, maxSelect: 1, collectionId: users.id, cascadeDelete: false },
        { type: 'select', name: 'tipo', required: true, maxSelect: 1, values: ['entrada', 'saida', 'pausa_inicio', 'pausa_fim'] },
        { type: 'date', name: 'data_hora', required: true },
        { type: 'select', name: 'origem', required: false, maxSelect: 1, values: ['quiosque', 'app', 'manual'] },
        { type: 'text', name: 'notas', required: false, max: 300 },
        { type: 'bool', name: 'corrigido', required: false },
        { type: 'date', name: 'data_hora_original', required: false },
        { type: 'relation', name: 'autor', required: false, maxSelect: 1, collectionId: users.id, cascadeDelete: false },
        { type: 'autodate', name: 'created', onCreate: true },
        { type: 'autodate', name: 'updated', onCreate: true, onUpdate: true },
      ],
      indexes: [
        'CREATE INDEX `idx_ponto_empresa_data` ON `ponto_registos` (`empresa`, `data_hora`)',
        'CREATE INDEX `idx_ponto_pessoa_data` ON `ponto_registos` (`empresa`, `pessoa`, `data_hora`)',
      ],
    });
    app.save(c);
  },
  (app) => {
    app.delete(app.findCollectionByNameOrId('ponto_registos'));
  },
);
