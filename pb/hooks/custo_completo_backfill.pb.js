/// <reference path="../pb_data/types.d.ts" />

// Preenche `custo_completo` / `custo_sem_dados` nas receitas e fichas já
// existentes (campos novos da v1.44.0), uma única vez, logo depois de o
// servidor arrancar (as migrations já correram). Evita ter de chamar
// `POST /api/gc_turnkey/admin/recompute` à mão depois de atualizar.
// A marca fica em pb_data (`.custo_completo_v1`): se for apagada, o recálculo
// repete-se (é idempotente). Depois da primeira execução bem sucedida, a
// tarefa limita-se a ver que a marca existe.

cronAdd('custo_completo_backfill', '* * * * *', () => {
  try {
    const marca = $app.dataDir() + '/.custo_completo_v1';
    try {
      $os.stat(marca);
      return; // já feito
    } catch (_) {
      // sem marca: fazer agora
    }

    const cascade = require(`${__hooks}/cascade.js`);
    let receitas = 0;
    let fichas = 0;
    $app.runInTransaction((tx) => {
      const rs = tx.findRecordsByFilter('receitas', '1=1', '', 0, 0);
      for (const r of rs) {
        cascade.runCascade(tx, 'receita', r.id);
        receitas++;
      }
      const fs = tx.findRecordsByFilter('fichas_tecnicas', '1=1', '', 0, 0);
      for (const f of fs) {
        cascade.runCascade(tx, 'ficha', f.id);
        fichas++;
      }
    });
    $os.writeFile(marca, 'ok', 0o644);
    console.log(
      '[custo_completo] recalculadas ' + receitas + ' receitas e ' + fichas + ' fichas.',
    );
  } catch (err) {
    console.log('[custo_completo] backfill falhou: ' + err);
  }
});
