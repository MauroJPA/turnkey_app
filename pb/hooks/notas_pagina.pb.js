/// <reference path="../pb_data/types.d.ts" />

// Carimba autor/data nas notas de página no servidor (nunca confia no que o
// cliente manda para estes campos) — ver a migration 1707955219_notas_pagina.
//
// NOTA: cada handler é autocontido (os handlers correm isolados) — por isso
// cada um resolve o próprio "nome de quem" em vez de chamar uma função
// partilhada no topo do ficheiro (nesse caso dava "ReferenceError").

onRecordCreateRequest((e) => {
  const auth = e.auth;
  if (auth && auth.collection().name === 'users') {
    e.record.set('autor', auth.id);
    e.record.set('autor_nome', auth.getString('nome') || auth.getString('email') || '');
  }
  // uma nota nova nunca começa já resolvida.
  e.record.set('resolvida', false);
  e.record.set('resolvida_em', '');
  e.record.set('resolvida_por', '');
  e.next();
}, 'notas_pagina');

onRecordUpdateRequest((e) => {
  const auth = e.auth;
  let antes = null;
  try {
    antes = e.record.original();
  } catch (_) {}
  const eraResolvida = antes ? antes.getBool('resolvida') : false;
  const ficaResolvida = e.record.getBool('resolvida');
  if (ficaResolvida && !eraResolvida) {
    const quem = auth ? (auth.getString('nome') || auth.getString('email') || '') : '';
    e.record.set('resolvida_em', new Date().toISOString());
    e.record.set('resolvida_por', quem);
  } else if (!ficaResolvida && eraResolvida) {
    e.record.set('resolvida_em', '');
    e.record.set('resolvida_por', '');
  }
  // só o campo "resolvida" (e o que fica marcado com ela) se edita depois de
  // criada — o texto e a página da nota não se alteram pela API.
  if (antes) {
    e.record.set('texto', antes.getString('texto'));
    e.record.set('pagina', antes.getString('pagina'));
    e.record.set('empresa', antes.getString('empresa'));
    e.record.set('autor', antes.getString('autor'));
    e.record.set('autor_nome', antes.getString('autor_nome'));
  }
  e.next();
}, 'notas_pagina');
