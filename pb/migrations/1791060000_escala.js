/// <reference path="../pb_data/types.d.ts" />

// Escala semanal da equipa (mapa de horário de trabalho) — 1.95.0.
//
// `escala_modelo`: o horário habitual de cada pessoa, por dia da semana
//   (1 = segunda … 7 = domingo). Um dia sem linha é folga.
// `escala_excecoes`: o que muda num dia concreto (um turno diferente, ou folga).
// Toda a equipa (menos a Leitura) vê o horário, como um mapa afixado; só o
// proprietário/administrador o altera.
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

    const campoEmpresa = () => ({
      type: 'relation',
      name: 'empresa',
      required: true,
      maxSelect: 1,
      collectionId: empresas.id,
      cascadeDelete: true,
    });
    const campoUser = () => ({
      type: 'relation',
      name: 'user',
      required: false,
      maxSelect: 1,
      collectionId: users.id,
      cascadeDelete: false,
    });
    // "HH:MM"
    const hora = (nome) => ({ type: 'text', name: nome, required: false, max: 5, pattern: '^([01][0-9]|2[0-3]):[0-5][0-9]$' });

    const modelo = new Collection({
      type: 'base',
      name: 'escala_modelo',
      listRule: podeVer,
      viewRule: podeVer,
      createRule: `(${criarAdmin}) && ${mesma('user')}`,
      updateRule: `(${doAdmin}) && ${mesma('user')}`,
      deleteRule: doAdmin,
      fields: [
        campoEmpresa(),
        { type: 'text', name: 'pessoa', required: true, max: 60 },
        { type: 'text', name: 'nome', required: false, max: 80 },
        campoUser(),
        { type: 'number', name: 'dia_semana', required: true, min: 1, max: 7 },
        { ...hora('inicio'), required: true },
        { ...hora('fim'), required: true },
        { type: 'number', name: 'pausa_min', required: false, min: 0, max: 240 },
        { type: 'autodate', name: 'created', onCreate: true },
        { type: 'autodate', name: 'updated', onCreate: true, onUpdate: true },
      ],
      indexes: [
        'CREATE UNIQUE INDEX `idx_escala_modelo_unico` ON `escala_modelo` (`empresa`, `pessoa`, `dia_semana`)',
      ],
    });
    app.save(modelo);

    const excecoes = new Collection({
      type: 'base',
      name: 'escala_excecoes',
      listRule: podeVer,
      viewRule: podeVer,
      createRule: `(${criarAdmin}) && ${mesma('user')}`,
      updateRule: `(${doAdmin}) && ${mesma('user')}`,
      deleteRule: doAdmin,
      fields: [
        campoEmpresa(),
        { type: 'text', name: 'pessoa', required: true, max: 60 },
        { type: 'text', name: 'nome', required: false, max: 80 },
        campoUser(),
        { type: 'date', name: 'data', required: true },
        // folga = não trabalha nesse dia (as horas ficam vazias)
        { type: 'bool', name: 'folga', required: false },
        hora('inicio'),
        hora('fim'),
        { type: 'number', name: 'pausa_min', required: false, min: 0, max: 240 },
        { type: 'text', name: 'notas', required: false, max: 200 },
        { type: 'autodate', name: 'created', onCreate: true },
        { type: 'autodate', name: 'updated', onCreate: true, onUpdate: true },
      ],
      indexes: [
        'CREATE UNIQUE INDEX `idx_escala_excecoes_unico` ON `escala_excecoes` (`empresa`, `pessoa`, `data`)',
      ],
    });
    app.save(excecoes);
  },
  (app) => {
    for (const nome of ['escala_excecoes', 'escala_modelo']) {
      try {
        app.delete(app.findCollectionByNameOrId(nome));
      } catch (_) {}
    }
  },
);
