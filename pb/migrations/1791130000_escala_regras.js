/// <reference path="../pb_data/types.d.ts" />

// Regras de horário em lote (2.10.0).
//
// `escala_regras`: uma mudança ao horário habitual que se REPETE — por dias da
// semana, a partir de uma data, para sempre ou até uma data (e, se quiseres, só
// de 2 em 2 semanas). Cria-se de uma vez para várias pessoas: cada pessoa tem o
// seu registo e todos partilham o mesmo `lote` (para apagar/terminar juntos).
// Ordem de prioridade (da mais forte): ausência aprovada > alteração de um dia
// (`escala_excecoes`) > empresa fechada > regra mais recente > horário habitual.
migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');
    const users = app.findCollectionByNameOrId('users');

    const ehAdmin = "(@request.auth.papel = 'owner' || @request.auth.papel = 'admin')";
    const podeVer = "@request.auth.id != '' && empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";
    const doAdmin = `@request.auth.id != '' && empresa = @request.auth.empresa && ${ehAdmin}`;
    const criarAdmin = `@request.auth.id != '' && @request.body.empresa = @request.auth.empresa && ${ehAdmin}`;
    const mesma = (campo) =>
      `(@request.body.${campo}:isset = false || @request.body.${campo} = '' || @request.body.${campo}.empresa = @request.auth.empresa)`;

    const hora = (nome) => ({ type: 'text', name: nome, required: false, max: 5, pattern: '^([01][0-9]|2[0-3]):[0-5][0-9]$' });

    const regras = new Collection({
      type: 'base',
      name: 'escala_regras',
      listRule: podeVer,
      viewRule: podeVer,
      createRule: `(${criarAdmin}) && ${mesma('user')}`,
      updateRule: `(${doAdmin}) && ${mesma('user')}`,
      deleteRule: doAdmin,
      fields: [
        { type: 'relation', name: 'empresa', required: true, maxSelect: 1, collectionId: empresas.id, cascadeDelete: true },
        { type: 'text', name: 'lote', required: true, max: 40 },
        { type: 'text', name: 'pessoa', required: true, max: 60 },
        { type: 'text', name: 'nome', required: false, max: 80 },
        { type: 'relation', name: 'user', required: false, maxSelect: 1, collectionId: users.id, cascadeDelete: false },
        // "1,2,3,4,5" (1 = segunda … 7 = domingo)
        { type: 'text', name: 'dias', required: true, max: 20, pattern: '^[1-7](,[1-7])*$' },
        // folga = não trabalha nesses dias (as horas ficam vazias)
        { type: 'bool', name: 'folga', required: false },
        hora('inicio'),
        hora('fim'),
        { type: 'number', name: 'pausa_min', required: false, min: 0, max: 240 },
        { type: 'date', name: 'de', required: true },
        // vazio = para sempre
        { type: 'date', name: 'ate', required: false },
        // 1 = todas as semanas, 2 = semanas alternadas (a contar da semana de `de`)…
        { type: 'number', name: 'cada_semanas', required: false, min: 1, max: 8 },
        { type: 'bool', name: 'saltar_feriados', required: false },
        { type: 'text', name: 'notas', required: false, max: 200 },
        { type: 'autodate', name: 'created', onCreate: true },
        { type: 'autodate', name: 'updated', onCreate: true, onUpdate: true },
      ],
      indexes: ['CREATE INDEX `idx_escala_regras_empresa` ON `escala_regras` (`empresa`, `lote`)'],
    });
    app.save(regras);
  },
  (app) => {
    try {
      app.delete(app.findCollectionByNameOrId('escala_regras'));
    } catch (_) {}
  },
);
