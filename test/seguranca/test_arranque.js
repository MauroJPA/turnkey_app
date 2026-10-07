// Testes da checklist de arranque (pb/hooks/arranque_core.js — a parte pura).
// Correr:  node test/seguranca/test_arranque.js
const assert = require('assert');
const path = require('path');
const a = require(path.join(__dirname, '..', '..', 'pb', 'hooks', 'arranque_core.js'));

let n = 0;
function teste(nome, f) {
  try {
    f();
    n++;
  } catch (e) {
    console.error('FALHA: ' + nome + '\n  ' + e.message);
    process.exitCode = 1;
  }
}

const vazio = { ingredientes: 0, comPreco: 0, receitas: 0, fichas: 0, equipa: 0, horarios: 0, logo: false, diasTrabalho: false, avisos: false };
const tudo = { ingredientes: 10, comPreco: 10, receitas: 3, fichas: 2, equipa: 4, horarios: 6, logo: true, diasTrabalho: true, avisos: true };
const por = (ps, k) => ps.find((p) => p.chave === k);

teste('uma empresa nova tem tudo por fazer', () => {
  const ps = a.passos(vazio, {});
  assert.strictEqual(ps.length, 9);
  assert(ps.every((p) => p.feito === false));
  assert.deepStrictEqual(ps.map((p) => p.chave), ['empresa', 'dias', 'ingredientes', 'precos', 'receitas', 'fichas', 'equipa', 'horarios', 'avisos']);
});

teste('uma empresa completa tem tudo feito', () => {
  const ps = a.passos(tudo, { ia: true, backupExterno: true, vigia: true });
  assert.strictEqual(ps.length, 12);
  assert(ps.every((p) => p.feito === true), JSON.stringify(ps.filter((p) => !p.feito)));
});

teste('ingredientes: precisam de pelo menos 3; preços de 80 % com preço', () => {
  assert.strictEqual(por(a.passos({ ...tudo, ingredientes: 2, comPreco: 2 }), 'ingredientes').feito, false);
  assert.strictEqual(por(a.passos({ ...tudo, ingredientes: 3, comPreco: 3 }), 'ingredientes').feito, true);
  assert.strictEqual(por(a.passos({ ...tudo, ingredientes: 10, comPreco: 7 }), 'precos').feito, false);
  assert.strictEqual(por(a.passos({ ...tudo, ingredientes: 10, comPreco: 8 }), 'precos').feito, true);
  assert.strictEqual(por(a.passos({ ...tudo, ingredientes: 2, comPreco: 2 }), 'precos').feito, false);
  assert.strictEqual(por(a.passos(tudo), 'precos').detalhe, '10 de 10 com preço');
});

teste('os passos do servidor só aparecem quando se sabem', () => {
  const sem = a.passos(tudo, {});
  assert(!por(sem, 'backups') && !por(sem, 'vigia') && !por(sem, 'ia'));
  const so = a.passos(tudo, { backupExterno: false, vigia: false, ia: false });
  assert.strictEqual(por(so, 'backups').feito, false);
  assert.strictEqual(por(so, 'vigia').feito, false);
  assert.strictEqual(por(so, 'ia').feito, false);
  // quem não é o dono do servidor (vigia === null) não vê esse passo
  assert(!por(a.passos(tudo, { vigia: null, backupExterno: true }), 'vigia'));
});

teste('os detalhes são texto curto e sem dados sensíveis', () => {
  for (const p of a.passos(tudo, { ia: false, backupExterno: false, vigia: false })) {
    assert(typeof p.detalhe === 'string' && p.detalhe.length < 80, p.chave);
  }
});

console.log(n + ' testes OK');
