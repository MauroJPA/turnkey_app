// Testes do script web/gc_colar.js (Ctrl+V de imagens nas tarefas), com um "navegador" falso.
// Correr:  node test/seguranca/test_colar.js
const assert = require('assert');
const fs = require('fs');
const path = require('path');
const vm = require('vm');

let n = 0;
function teste(nome, f) {
  Promise.resolve()
    .then(f)
    .then(() => {
      n++;
    })
    .catch((e) => {
      console.error('FALHA: ' + nome + '\n  ' + e.message);
      process.exitCode = 1;
    });
}

const codigo = fs.readFileSync(path.join(__dirname, '..', '..', 'web', 'gc_colar.js'), 'utf8');

function navegador() {
  let ouvinte = null;
  const document = { addEventListener: (nome, f) => nome === 'paste' && (ouvinte = f) };
  const window = {};
  vm.runInNewContext(codigo, { window, document, Date, Uint8Array, Array, String });
  return { window, colar: (e) => ouvinte(e) };
}

function evento({ texto = '', ficheiros = [] } = {}) {
  let impedido = false;
  return {
    clipboardData: { getData: (t) => (t === 'text/plain' ? texto : ''), files: ficheiros },
    preventDefault: () => (impedido = true),
    get impedido() {
      return impedido;
    },
  };
}

const imagem = (tipo, bytes = [1, 2, 3]) => ({
  type: tipo,
  arrayBuffer: () => Promise.resolve(new Uint8Array(bytes).buffer),
});
const espera = () => new Promise((r) => setTimeout(r, 10));

teste('sem ouvinte registado, nada acontece (a colagem segue normal)', async () => {
  const { colar } = navegador();
  const e = evento({ ficheiros: [imagem('image/png')] });
  colar(e);
  assert.strictEqual(e.impedido, false);
});

teste('uma imagem colada chega ao ouvinte com nome e bytes', async () => {
  const { window, colar } = navegador();
  const recebidas = [];
  window.gcColarRegistar((nome, bytes) => recebidas.push({ nome, bytes }));
  const e = evento({ ficheiros: [imagem('image/png', [9, 8, 7])] });
  colar(e);
  await espera();
  assert.strictEqual(e.impedido, true);
  assert.strictEqual(recebidas.length, 1);
  assert.match(recebidas[0].nome, /^colada-\d+-1\.png$/);
  assert.deepStrictEqual(Array.from(recebidas[0].bytes), [9, 8, 7]);
});

teste('jpeg e webp ficam com a extensão certa; várias imagens chegam todas', async () => {
  const { window, colar } = navegador();
  const nomes = [];
  window.gcColarRegistar((nome) => nomes.push(nome));
  colar(evento({ ficheiros: [imagem('image/jpeg'), imagem('image/webp'), imagem('image/gif')] }));
  await espera();
  assert.strictEqual(nomes.length, 3);
  assert.match(nomes[0], /-1\.jpg$/);
  assert.match(nomes[1], /-2\.webp$/);
  assert.match(nomes[2], /-3\.png$/);
});

teste('com texto na área de transferência cola-se o texto, não a imagem', async () => {
  const { window, colar } = navegador();
  let chamadas = 0;
  window.gcColarRegistar(() => chamadas++);
  const e = evento({ texto: 'célula A1', ficheiros: [imagem('image/png')] });
  colar(e);
  await espera();
  assert.strictEqual(e.impedido, false);
  assert.strictEqual(chamadas, 0);
});

teste('ficheiros que não são imagens são ignorados', async () => {
  const { window, colar } = navegador();
  let chamadas = 0;
  window.gcColarRegistar(() => chamadas++);
  const e = evento({ ficheiros: [{ type: 'application/pdf', arrayBuffer: () => Promise.resolve(new ArrayBuffer(1)) }] });
  colar(e);
  await espera();
  assert.strictEqual(e.impedido, false);
  assert.strictEqual(chamadas, 0);
});

teste('depois de limpar, deixa de ouvir', async () => {
  const { window, colar } = navegador();
  let chamadas = 0;
  window.gcColarRegistar(() => chamadas++);
  window.gcColarLimpar();
  const e = evento({ ficheiros: [imagem('image/png')] });
  colar(e);
  await espera();
  assert.strictEqual(e.impedido, false);
  assert.strictEqual(chamadas, 0);
});

teste('um evento sem clipboardData não dá erro', () => {
  const { window, colar } = navegador();
  window.gcColarRegistar(() => {});
  colar({ preventDefault() {} });
});

process.on('exit', () => {
  if (!process.exitCode) console.log(n + ' testes de gc_colar.js OK');
});
