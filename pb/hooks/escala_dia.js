// A pausa prevista pela escala num dia (módulo partilhado via require()).
//
// Usada para preencher AUTOMATICAMENTE a pausa na saída quando a pessoa não a
// marcou (a app faz o mesmo em `calcularJornadas`, em Dart). Mesma ordem de
// prioridade da escala: alteração de um dia > empresa fechada (sem pausa) >
// regra de horário mais recente > horário habitual.
//
// Funções PURAS (recebem os dados já carregados) + `carregar` (lê da base).

function dois(n) {
  return n < 10 ? '0' + n : '' + n;
}

// "2026-10-07" para uma data local.
function isoLocal(d) {
  return d.getFullYear() + '-' + dois(d.getMonth() + 1) + '-' + dois(d.getDate());
}

function diaSemana(d) {
  return d.getDay() === 0 ? 7 : d.getDay(); // 1 = segunda ... 7 = domingo
}

function pascoa(ano) {
  const a = ano % 19;
  const b = Math.floor(ano / 100);
  const c = ano % 100;
  const d = Math.floor(b / 4);
  const e = b % 4;
  const f = Math.floor((b + 8) / 25);
  const g = Math.floor((b - f + 1) / 3);
  const h = (19 * a + b - d - g + 15) % 30;
  const i = Math.floor(c / 4);
  const k = c % 4;
  const l = (32 + 2 * e + 2 * i - h - k) % 7;
  const m = Math.floor((a + 11 * h + 22 * l) / 451);
  const mes = Math.floor((h + l - 7 * m + 114) / 31);
  const dia = ((h + l - 7 * m + 114) % 31) + 1;
  return new Date(ano, mes - 1, dia);
}

// Os feriados nacionais de Portugal como "AAAA-MM-DD".
function feriados(ano) {
  const p = pascoa(ano);
  const mais = (n) => isoLocal(new Date(p.getFullYear(), p.getMonth(), p.getDate() + n));
  const fixos = ['01-01', '04-25', '05-01', '06-10', '08-15', '10-05', '11-01', '12-01', '12-08', '12-25'];
  const out = {};
  fixos.forEach((x) => (out[ano + '-' + x] = true));
  [-2, 0, 60].forEach((n) => (out[mais(n)] = true));
  return out;
}

function segundaMs(txt) {
  const x = new Date(String(txt).substring(0, 10) + 'T00:00:00Z');
  return x.getTime() - (diaSemana2(x) - 1) * 86400000;
}

function diaSemana2(x) {
  return x.getUTCDay() === 0 ? 7 : x.getUTCDay();
}

function regraCobre(r, iso, dow) {
  const de = String(r.de || '').substring(0, 10);
  const ate = String(r.ate || '').substring(0, 10);
  if (de && iso < de) return false;
  if (ate && iso > ate) return false;
  if (String(r.dias || '').split(',').indexOf(String(dow)) < 0) return false;
  const cada = r.cada_semanas || 1;
  if (cada > 1) {
    const semanas = Math.round((segundaMs(iso) - segundaMs(de)) / (7 * 86400000));
    if (semanas % cada !== 0) return false;
  }
  if (r.saltar_feriados && feriados(Number(iso.substring(0, 4)))[iso]) return false;
  return true;
}

// dados = { modelo: [{pessoa, dia_semana, inicio, fim, pausa_min}],
//           regras: [{pessoa, dias, de, ate, folga, inicio, fim, pausa_min, cada_semanas, saltar_feriados}] (da mais antiga à mais recente),
//           excecoes: [{pessoa, data, folga, inicio, fim, pausa_min}],
//           diasTrab: [1..7] (vazio = todos) }
// Devolve os minutos de pausa previstos (0 se não há turno nesse dia).
function pausaPrevistaMin(dados, pessoa, dia) {
  const iso = isoLocal(dia);
  const dow = diaSemana(dia);
  const temHoras = (x) => !!x.inicio && !!x.fim;

  for (const e of dados.excecoes || []) {
    if (e.pessoa === pessoa && String(e.data).substring(0, 10) === iso) {
      return e.folga || !temHoras(e) ? 0 : e.pausa_min || 0;
    }
  }
  const trab = dados.diasTrab || [];
  if (trab.length && trab.indexOf(dow) < 0) return 0;
  let regra = null;
  for (const r of dados.regras || []) {
    if (r.pessoa === pessoa && regraCobre(r, iso, dow)) regra = r;
  }
  if (regra) return regra.folga || !temHoras(regra) ? 0 : regra.pausa_min || 0;
  for (const m of dados.modelo || []) {
    if (m.pessoa === pessoa && m.dia_semana === dow) return temHoras(m) ? m.pausa_min || 0 : 0;
  }
  return 0;
}

// Lê da base tudo o que `pausaPrevistaMin` precisa (a escala da empresa).
function carregar(app, empresaId, de, ate) {
  const filtro = { e: empresaId };
  const modelo = app.findRecordsByFilter('escala_modelo', 'empresa = {:e}', '', 2000, 0, filtro).map((r) => ({
    pessoa: r.getString('pessoa'),
    dia_semana: r.getInt('dia_semana'),
    inicio: r.getString('inicio'),
    fim: r.getString('fim'),
    pausa_min: r.getInt('pausa_min'),
  }));
  const regras = app.findRecordsByFilter('escala_regras', 'empresa = {:e}', 'created', 2000, 0, filtro).map((r) => ({
    pessoa: r.getString('pessoa'),
    dias: r.getString('dias'),
    de: r.getString('de'),
    ate: r.getString('ate'),
    folga: r.getBool('folga'),
    inicio: r.getString('inicio'),
    fim: r.getString('fim'),
    pausa_min: r.getInt('pausa_min'),
    cada_semanas: r.getInt('cada_semanas') || 1,
    saltar_feriados: r.getBool('saltar_feriados'),
  }));
  const excecoes = app
    .findRecordsByFilter('escala_excecoes', 'empresa = {:e} && data >= {:d} && data <= {:a}', '', 5000, 0, {
      e: empresaId,
      d: isoLocal(de) + ' 00:00:00.000Z',
      a: isoLocal(ate) + ' 23:59:59.999Z',
    })
    .map((r) => ({
      pessoa: r.getString('pessoa'),
      data: r.getString('data'),
      folga: r.getBool('folga'),
      inicio: r.getString('inicio'),
      fim: r.getString('fim'),
      pausa_min: r.getInt('pausa_min'),
    }));
  let diasTrab = [];
  try {
    const cfg = app.findFirstRecordByFilter('configuracoes_custo', 'empresa = {:e}', filtro);
    diasTrab = String(cfg.getString('dias_trabalho') || '')
      .split(',')
      .map((x) => parseInt(x, 10))
      .filter((x) => x >= 1 && x <= 7);
  } catch (_) {}
  return { modelo, regras, excecoes, diasTrab };
}

module.exports = { pausaPrevistaMin, carregar, isoLocal };
