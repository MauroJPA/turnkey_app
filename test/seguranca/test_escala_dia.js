// Testes da pausa prevista pela escala (pb/hooks/escala_dia.js), usada para
// preencher a pausa na saída (resumo semanal). Correr:
//   node test/seguranca/test_escala_dia.js
const assert = require('assert');
const path = require('path');
const e = require(path.join(__dirname, '..', '..', 'pb', 'hooks', 'escala_dia.js'));

let n = 0;
function teste(nome, f) {
  try {
    f();
    n++;
  } catch (err) {
    console.error('FALHA: ' + nome + '\n  ' + err.message);
    process.exitCode = 1;
  }
}

const modelo = [1, 2, 3, 4, 5].map((d) => ({ pessoa: 'u:1', dia_semana: d, inicio: '08:00', fim: '16:30', pausa_min: 30 }));
// quarta 7 out 2026
const qua = new Date(2026, 9, 7, 8, 0);
const sab = new Date(2026, 9, 10, 8, 0);
const dom = new Date(2026, 9, 11, 8, 0);

teste('o horário habitual dá a pausa do dia; sem turno, zero', () => {
  const d = { modelo };
  assert.strictEqual(e.pausaPrevistaMin(d, 'u:1', qua), 30);
  assert.strictEqual(e.pausaPrevistaMin(d, 'u:1', sab), 0);
  assert.strictEqual(e.pausaPrevistaMin(d, 'u:2', qua), 0);
});

teste('uma alteração de um dia manda (turno com outra pausa, ou folga)', () => {
  const turno = { modelo, excecoes: [{ pessoa: 'u:1', data: '2026-10-07 00:00:00.000Z', folga: false, inicio: '09:00', fim: '17:00', pausa_min: 60 }] };
  assert.strictEqual(e.pausaPrevistaMin(turno, 'u:1', qua), 60);
  const folga = { modelo, excecoes: [{ pessoa: 'u:1', data: '2026-10-07 00:00:00.000Z', folga: true }] };
  assert.strictEqual(e.pausaPrevistaMin(folga, 'u:1', qua), 0);
});

teste('a regra mais recente ganha ao horário habitual e às anteriores', () => {
  const regra = (extra) => ({ pessoa: 'u:1', dias: '1,2,3,4,5', de: '2026-10-01 00:00:00.000Z', ate: '', folga: false, inicio: '07:00', fim: '15:00', pausa_min: 15, cada_semanas: 1, ...extra });
  assert.strictEqual(e.pausaPrevistaMin({ modelo, regras: [regra()] }, 'u:1', qua), 15);
  assert.strictEqual(e.pausaPrevistaMin({ modelo, regras: [regra(), regra({ pausa_min: 45 })] }, 'u:1', qua), 45);
  // a regra de folga tira a pausa
  assert.strictEqual(e.pausaPrevistaMin({ modelo, regras: [regra({ folga: true, inicio: '', fim: '' })] }, 'u:1', qua), 0);
});

teste('a regra respeita as datas, as semanas alternadas e os dias', () => {
  const base = { pessoa: 'u:1', dias: '6', de: '2026-10-03 00:00:00.000Z', ate: '', folga: false, inicio: '07:00', fim: '15:00', pausa_min: 20, cada_semanas: 2 };
  const d = { modelo: [], regras: [base], diasTrab: [] };
  assert.strictEqual(e.pausaPrevistaMin(d, 'u:1', new Date(2026, 9, 3, 8)), 20); // semana 0
  assert.strictEqual(e.pausaPrevistaMin(d, 'u:1', new Date(2026, 9, 10, 8)), 0); // semana 1
  assert.strictEqual(e.pausaPrevistaMin(d, 'u:1', new Date(2026, 9, 17, 8)), 20); // semana 2
  assert.strictEqual(e.pausaPrevistaMin({ ...d, regras: [{ ...base, cada_semanas: 1, ate: '2026-10-09 00:00:00.000Z' }] }, 'u:1', sab), 0); // acabou
  assert.strictEqual(e.pausaPrevistaMin({ ...d, regras: [{ ...base, cada_semanas: 1, de: '2026-10-12 00:00:00.000Z' }] }, 'u:1', sab), 0); // ainda não começou
});

teste('dias fechados não têm pausa; feriados saltados também', () => {
  const d = { modelo: [...modelo, { pessoa: 'u:1', dia_semana: 7, inicio: '08:00', fim: '12:00', pausa_min: 10 }], diasTrab: [1, 2, 3, 4, 5, 6] };
  assert.strictEqual(e.pausaPrevistaMin(d, 'u:1', dom), 0);
  assert.strictEqual(e.pausaPrevistaMin(d, 'u:1', qua), 30);
  // 1/12/2026 (terça) é feriado: a regra "saltar feriados" não se aplica
  const regra = { pessoa: 'u:1', dias: '2', de: '2026-11-30 00:00:00.000Z', ate: '', folga: false, inicio: '07:00', fim: '15:00', pausa_min: 15, cada_semanas: 1, saltar_feriados: true };
  const f = { modelo: [], regras: [regra] };
  assert.strictEqual(e.pausaPrevistaMin(f, 'u:1', new Date(2026, 11, 1, 8)), 0);
  assert.strictEqual(e.pausaPrevistaMin(f, 'u:1', new Date(2026, 11, 15, 8)), 15);
});

console.log(n + ' testes OK');
