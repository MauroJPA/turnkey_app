/// <reference path="../pb_data/types.d.ts" />

// Contagem diária de produto acabado por LOCAL (loja, Alvalade, plataformas):
// assados, enviados/devolvidos entre locais, desperdício (com motivo) e
// contagens de abertura/fecho.
//
// `locais` — onde há cookies: tipo (loja | parceiro | plataforma) e os canais
// de venda que lhe pertencem (para saber o "vendido" de cada local a partir
// das vendas, sem registar duas vezes).
// `movimentos_produto` — registo do dia a dia, por local e por sabor (ficha):
//   producao      +quantidade no local
//   transferencia -quantidade no local, +quantidade no `destino`
//   desperdicio   -quantidade (com `motivo`)
//   contagem_abertura / contagem_fecho  — o que foi contado (uma por
//                 local+sabor+dia; repetir a contagem substitui a anterior)

migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');
    const fichas = app.findCollectionByNameOrId('fichas_tecnicas');
    const users = app.findCollectionByNameOrId('users');

    const podeVer = "@request.auth.id != '' && empresa = @request.auth.empresa";
    const podeEscrever =
      "@request.auth.id != '' && empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";
    const podeCriar =
      "@request.auth.id != '' && @request.body.empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";
    // relações têm de ser da mesma empresa (mesmo padrão da migration 1707955202)
    const mesmaEmpresa = (campo) =>
      `(@request.body.${campo}:isset = false || @request.body.${campo} = '' || @request.body.${campo}.empresa = @request.auth.empresa)`;

    const campoEmpresa = () => ({
      type: 'relation',
      name: 'empresa',
      required: true,
      maxSelect: 1,
      collectionId: empresas.id,
      cascadeDelete: true,
    });

    // --- locais -----------------------------------------------------------
    const locais = new Collection({
      type: 'base',
      name: 'locais',
      listRule: podeVer,
      viewRule: podeVer,
      createRule: podeCriar,
      updateRule: podeEscrever,
      deleteRule: podeEscrever,
      fields: [
        campoEmpresa(),
        { type: 'text', name: 'nome', required: true, max: 60 },
        {
          type: 'select',
          name: 'tipo',
          required: true,
          maxSelect: 1,
          values: ['loja', 'parceiro', 'plataforma'],
        },
        // nomes dos canais de venda deste local (ex.: ["Uber Eats","Glovo"])
        { type: 'json', name: 'canais', required: false, maxSize: 4000 },
        { type: 'number', name: 'ordem', required: false },
        { type: 'bool', name: 'arquivado', required: false },
        { type: 'autodate', name: 'created', onCreate: true },
        { type: 'autodate', name: 'updated', onCreate: true, onUpdate: true },
      ],
      indexes: [
        'CREATE UNIQUE INDEX `idx_locais_empresa_nome` ON `locais` (`empresa`, `nome`)',
      ],
    });
    app.save(locais);

    // --- movimentos_produto ---------------------------------------------------
    const mov = new Collection({
      type: 'base',
      name: 'movimentos_produto',
      listRule: podeVer,
      viewRule: podeVer,
      createRule: `(${podeCriar}) && ${mesmaEmpresa('local')} && ${mesmaEmpresa('destino')} && ${mesmaEmpresa('ficha')}`,
      updateRule: `(${podeEscrever}) && ${mesmaEmpresa('local')} && ${mesmaEmpresa('destino')} && ${mesmaEmpresa('ficha')}`,
      deleteRule: podeEscrever,
      fields: [
        campoEmpresa(),
        { type: 'date', name: 'data', required: true },
        {
          type: 'relation',
          name: 'local',
          required: true,
          maxSelect: 1,
          collectionId: locais.id,
          cascadeDelete: true,
        },
        {
          type: 'relation',
          name: 'ficha',
          required: true,
          maxSelect: 1,
          collectionId: fichas.id,
          cascadeDelete: true,
        },
        {
          type: 'select',
          name: 'tipo',
          required: true,
          maxSelect: 1,
          values: [
            'producao',
            'transferencia',
            'desperdicio',
            'contagem_abertura',
            'contagem_fecho',
          ],
        },
        { type: 'number', name: 'quantidade', required: true, min: 0 },
        // só nas transferências: para onde vão os cookies
        {
          type: 'relation',
          name: 'destino',
          required: false,
          maxSelect: 1,
          collectionId: locais.id,
          cascadeDelete: true,
        },
        // só no desperdício
        {
          type: 'select',
          name: 'motivo',
          required: false,
          maxSelect: 1,
          values: [
            'queimado',
            'fora_prazo',
            'quebrado',
            'erro_producao',
            'degustacao',
            'outro',
          ],
        },
        { type: 'text', name: 'notas', required: false, max: 200 },
        {
          type: 'relation',
          name: 'autor',
          required: false,
          maxSelect: 1,
          collectionId: users.id,
          cascadeDelete: false,
        },
        { type: 'autodate', name: 'created', onCreate: true },
        { type: 'autodate', name: 'updated', onCreate: true, onUpdate: true },
      ],
      indexes: [
        'CREATE INDEX `idx_movprod_empresa_data` ON `movimentos_produto` (`empresa`, `data`)',
        'CREATE INDEX `idx_movprod_local_data` ON `movimentos_produto` (`empresa`, `local`, `data`)',
        // uma contagem de abertura/fecho por local+sabor+dia
        "CREATE UNIQUE INDEX `idx_movprod_contagem` ON `movimentos_produto` (`empresa`, `local`, `ficha`, `data`, `tipo`) WHERE `tipo` IN ('contagem_abertura','contagem_fecho')",
      ],
    });
    app.save(mov);

    // --- locais por omissão nas empresas que já existem ------------------------
    const padrao = [
      { nome: 'Loja', tipo: 'loja', canais: ['Loja física'], ordem: 1 },
      { nome: 'Alvalade', tipo: 'parceiro', canais: ['Parceria Alvalade'], ordem: 2 },
      {
        nome: 'Plataformas',
        tipo: 'plataforma',
        canais: ['Uber Eats', 'Glovo', 'Bolt Food'],
        ordem: 3,
      },
    ];
    const todas = app.findAllRecords('empresas');
    for (const emp of todas) {
      for (const p of padrao) {
        const r = new Record(locais);
        r.set('empresa', emp.id);
        r.set('nome', p.nome);
        r.set('tipo', p.tipo);
        r.set('canais', JSON.stringify(p.canais));
        r.set('ordem', p.ordem);
        r.set('arquivado', false);
        app.save(r);
      }
    }
  },
  (app) => {
    app.delete(app.findCollectionByNameOrId('movimentos_produto'));
    app.delete(app.findCollectionByNameOrId('locais'));
  },
);
