/// <reference path="../pb_data/types.d.ts" />

// Tarefas da equipa (2.19.0; menções no Telegram: 2.20.0).
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

// Menções nos comentários → Telegram de cada pessoa mencionada (2.20.0), se a
// pessoa ligou o seu Telegram (telegram_pessoas.js). Ao editar um comentário,
// só avisa quem passou a estar mencionado.
onRecordAfterCreateSuccess((e) => {
  try {
    const ids = e.record.getStringSlice('mencoes');
    if (ids.length) require(`${__hooks}/telegram_pessoas.js`).avisarMencoes(e.app, e.record, ids);
  } catch (err) {
    console.log('[tarefas] aviso de menção: ' + String(err && err.message ? err.message : 'desconhecido').replace(/bot[0-9]+:[A-Za-z0-9_-]+/g, 'bot***'));
  }
  e.next();
}, 'tarefa_comentarios');

onRecordAfterUpdateSuccess((e) => {
  try {
    const antes = e.record.original().getStringSlice('mencoes');
    const novos = e.record.getStringSlice('mencoes').filter((id) => antes.indexOf(id) < 0);
    if (novos.length) require(`${__hooks}/telegram_pessoas.js`).avisarMencoes(e.app, e.record, novos);
  } catch (err) {
    console.log('[tarefas] aviso de menção: ' + String(err && err.message ? err.message : 'desconhecido').replace(/bot[0-9]+:[A-Za-z0-9_-]+/g, 'bot***'));
  }
  e.next();
}, 'tarefa_comentarios');
