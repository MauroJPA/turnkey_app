/// <reference path="../pb_data/types.d.ts" />

// Telegram com botões (ver telegram_botoes.js):
//   - cron de minuto a minuto: trata o que foi carregado nos botões;
//   - cron de 10 em 10 minutos: avisa das saídas por marcar ("Saída às 16:30");
//   - pedido de férias novo -> mensagem com "Aprovar" / "Recusar";
//   - POST /api/gc_turnkey/telegram/sondar  (owner/admin): trata já o que
//     foi carregado (em vez de esperar pelo minuto seguinte).
// NOTA: cada handler corre isolado — usa require() para o resto.

cronAdd('telegram_botoes', '* * * * *', () => {
  try {
    require(`${__hooks}/telegram_botoes.js`).sondar($app);
  } catch (err) {
    console.log('[telegram] erro nos botões: ' + String(err && err.message ? err.message : 'desconhecido').replace(/bot[0-9]+:[A-Za-z0-9_-]+/g, 'bot***'));
  }
});

cronAdd('telegram_saidas', '*/10 * * * *', () => {
  try {
    require(`${__hooks}/telegram_botoes.js`).avisarSaidas($app);
  } catch (err) {
    console.log('[telegram] erro nas saídas por marcar: ' + String(err && err.message ? err.message : 'desconhecido').replace(/bot[0-9]+:[A-Za-z0-9_-]+/g, 'bot***'));
  }
});

onRecordAfterCreateSuccess((e) => {
  try {
    const r = e.record;
    if (r.getString('estado') === 'pedido') {
      const nome = r.getString('nome') || 'Alguém';
      const tipo = { ferias: 'férias', baixa: 'baixa', falta: 'falta', outro: 'ausência' }[r.getString('tipo')] || 'ausência';
      const dmy = (t) => {
        const p = String(t).substring(0, 10).split('-');
        return p.length === 3 ? parseInt(p[2], 10) + '/' + parseInt(p[1], 10) : String(t);
      };
      const dias = r.getInt('dias_uteis');
      const texto = '🏖️ ' + nome + ' pediu ' + tipo + ': ' + dmy(r.getString('data_inicio')) + ' a ' + dmy(r.getString('data_fim')) + (dias > 0 ? ' (' + dias + ' dias úteis)' : '');
      require(`${__hooks}/telegram_botoes.js`).enviarComBotoes(e.app, r.getString('empresa'), texto, [
        { texto: '✅ Aprovar', tipo: 'fa', id: r.id },
        { texto: '❌ Recusar', tipo: 'fr', id: r.id },
      ]);
    }
  } catch (err) {
    console.log('[telegram] erro ao avisar do pedido: ' + String(err && err.message ? err.message : 'desconhecido').replace(/bot[0-9]+:[A-Za-z0-9_-]+/g, 'bot***'));
  }
  e.next();
}, 'ferias');

routerAdd(
  'POST',
  '/api/gc_turnkey/telegram/sondar',
  (e) => {
    const auth = e.auth;
    if (!auth || auth.collection().name !== 'users' || !auth.getString('empresa')) {
      throw new ForbiddenError('Autenticação necessária.');
    }
    const papel = auth.getString('papel');
    if (papel !== 'owner' && papel !== 'admin') throw new ForbiddenError('Precisas de ser administrador.');
    const r = require(`${__hooks}/telegram_botoes.js`).sondar(e.app, auth.getString('empresa'));
    return e.json(200, { tratados: r.tratados });
  },
  $apis.requireAuth('users'),
);
