/// <reference path="../pb_data/types.d.ts" />

// Canais de venda com taxas em cascata (plataformas de entrega, revendedores,
// terceiros): cada canal tem uma lista ORDENADA de taxas — `taxas` é um array
// JSON [{ nome, percent, fixo }] — na ordem em que cada uma tira a sua parte do
// que o cliente paga (a primeira é a de fora, ex.: a plataforma; a última é a
// mais perto de nós, ex.: o revendedor). `embalagem_plataforma`: o canal usa a
// embalagem para plataformas da ficha (custo extra).
// Serve para calcular, em cada ficha técnica, o preço a cobrar (preço limpo +
// taxas + IVA no fim) e o lucro de cada canal.
migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');

    const podeVer = "@request.auth.id != '' && empresa = @request.auth.empresa";
    const podeEscrever =
      "@request.auth.id != '' && empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";
    const podeCriar =
      "@request.auth.id != '' && @request.body.empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";

    const canais = new Collection({
      type: 'base',
      name: 'canais_venda',
      listRule: podeVer,
      viewRule: podeVer,
      createRule: podeCriar,
      updateRule: podeEscrever,
      deleteRule: podeEscrever,
      fields: [
        {
          type: 'relation',
          name: 'empresa',
          required: true,
          maxSelect: 1,
          collectionId: empresas.id,
          cascadeDelete: true,
        },
        { type: 'text', name: 'nome', required: true, max: 60 },
        { type: 'json', name: 'taxas', required: false, maxSize: 8000 },
        { type: 'bool', name: 'embalagem_plataforma', required: false },
        { type: 'number', name: 'ordem', required: false },
        { type: 'autodate', name: 'created', onCreate: true },
        { type: 'autodate', name: 'updated', onCreate: true, onUpdate: true },
      ],
      indexes: [
        'CREATE UNIQUE INDEX `idx_canais_venda_empresa_nome` ON `canais_venda` (`empresa`, `nome`)',
      ],
    });
    app.save(canais);
  },
  (app) => {
    try {
      app.delete(app.findCollectionByNameOrId('canais_venda'));
    } catch (_) {
      // já não existe
    }
  },
);
