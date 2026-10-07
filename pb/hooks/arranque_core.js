// Checklist de arranque (módulo partilhado via require()).
//
// `contar` lê da base só números (nunca conteúdo) e `passos` transforma-os na
// lista "o que falta configurar" que o Início mostra. A app dá o texto e a rota
// de cada `chave`; aqui só se decide o que está FEITO.

// `sql` é SQL a sério (não a sintaxe de filtros do PocketBase): AND, COALESCE…
function contagem(app, colecao, sql, params) {
  try {
    return app.countRecords(colecao, $dbx.exp(sql, params));
  } catch (_) {
    return 0;
  }
}

// Só números: { ingredientes, comPreco, receitas, fichas, equipa, horarios, ... }
function contar(app, empresaId) {
  const p = { e: empresaId };
  const c = {
    ingredientes: contagem(app, 'ingredientes', 'empresa = {:e} AND COALESCE(deletado, 0) = 0', p),
    comPreco: contagem(app, 'ingredientes', 'empresa = {:e} AND COALESCE(deletado, 0) = 0 AND COALESCE(preco, 0) > 0', p),
    receitas: contagem(app, 'receitas', 'empresa = {:e} AND COALESCE(deletado, 0) = 0', p),
    fichas: contagem(app, 'fichas_tecnicas', 'empresa = {:e} AND COALESCE(deletado, 0) = 0', p),
    equipa: contagem(app, 'colaboradores', 'empresa = {:e} AND COALESCE(arquivado, 0) = 0', p),
    horarios: contagem(app, 'escala_modelo', 'empresa = {:e}', p) + contagem(app, 'escala_regras', 'empresa = {:e}', p),
    logo: false,
    diasTrabalho: false,
    avisos: false,
  };
  try {
    const emp = app.findRecordById('empresas', empresaId);
    c.logo = !!emp.getString('logo');
  } catch (_) {}
  try {
    const cfg = app.findFirstRecordByFilter('configuracoes_custo', 'empresa = {:e}', p);
    c.diasTrabalho = String(cfg.getString('dias_trabalho') || '').trim() !== '';
  } catch (_) {}
  try {
    const a = app.findFirstRecordByFilter('avisos_config', 'empresa = {:e}', p);
    const email = a.getBool('email_ativo') && String(a.getString('email_para') || '').trim() !== '';
    const tele = a.getBool('telegram_ativo') && String(a.getString('telegram_chat') || '').trim() !== '';
    c.avisos = email || tele;
  } catch (_) {}
  return c;
}

// extra = { backupExterno: true|false|null, vigia: true|false|null (null = não é o dono), ia: bool }
// Devolve [{ chave, feito, detalhe }] pela ordem em que faz sentido fazer.
function passos(c, extra) {
  extra = extra || {};
  const out = [];
  const add = (chave, feito, detalhe) => out.push({ chave: chave, feito: !!feito, detalhe: detalhe || '' });
  add('empresa', c.logo, c.logo ? 'Logótipo definido' : 'Falta o logótipo');
  add('dias', c.diasTrabalho, c.diasTrabalho ? '' : 'Diz em que dias a empresa trabalha');
  add('ingredientes', c.ingredientes >= 3, c.ingredientes + (c.ingredientes === 1 ? ' ingrediente' : ' ingredientes'));
  const pc = c.ingredientes > 0 ? c.comPreco / c.ingredientes : 0;
  add('precos', c.ingredientes >= 3 && pc >= 0.8, c.comPreco + ' de ' + c.ingredientes + ' com preço');
  add('receitas', c.receitas >= 1, c.receitas + (c.receitas === 1 ? ' receita' : ' receitas'));
  add('fichas', c.fichas >= 1, c.fichas + (c.fichas === 1 ? ' produto' : ' produtos'));
  add('equipa', c.equipa >= 1, c.equipa + (c.equipa === 1 ? ' pessoa' : ' pessoas'));
  add('horarios', c.horarios >= 1, c.horarios >= 1 ? '' : 'Ainda sem horários na Escala');
  add('avisos', c.avisos, c.avisos ? 'Avisos ligados' : 'Liga o Telegram ou o email');
  if (extra.ia !== undefined && extra.ia !== null) add('ia', extra.ia, extra.ia ? '' : 'Falta a chave da IA no servidor');
  if (extra.backupExterno !== undefined && extra.backupExterno !== null) {
    add('backups', extra.backupExterno, extra.backupExterno ? 'Cópia externa a funcionar' : 'Falta a cópia externa');
  }
  if (extra.vigia !== undefined && extra.vigia !== null) add('vigia', extra.vigia, extra.vigia ? '' : 'Falta instalar o vigia no servidor');
  return out;
}

module.exports = { contar, passos };
