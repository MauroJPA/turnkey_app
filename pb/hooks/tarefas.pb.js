/// <reference path="../pb_data/types.d.ts" />

// Tarefas da equipa (2.19.0).
//
// Apagar um quadro apaga tudo o que tem. As tarefas prendem a sua fase
// (`tarefas.coluna` sem cascata, para uma fase com tarefas não se apagar por
// engano), por isso as tarefas do quadro vão primeiro; os comentários vão com
// elas (cascata) e as fases com o quadro. Corre dentro da mesma transação: se
// algo falhar, nada se apaga.
//
// NOTA: cada handler é autocontido (os handlers correm isolados).

onRecordDelete((e) => {
  const tarefas = e.app.findRecordsByFilter('tarefas', 'quadro = {:q}', '', 0, 0, { q: e.record.id });
  for (const t of tarefas) {
    e.app.delete(t);
  }
  e.next();
}, 'quadros');
