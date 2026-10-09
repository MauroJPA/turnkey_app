// Testes do script web/gc_instalar.js (instalar a app), com um "navegador" falso.
// Correr:  node test/seguranca/test_instalar.js
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

const codigo = fs.readFileSync(path.join(__dirname, '..', '..', 'web', 'gc_instalar.js'), 'utf8');

function navegador({ standalone = false, ua = 'Mozilla/5.0 (Linux; Android 14) Chrome/130', plataforma = 'Linux', toques = 5 } = {}) {
  const ouvintes = {};
  const window = {
    addEventListener: (nome, f) => (ouvintes[nome] = f),
    matchMedia: () => ({ matches: standalone }),
  };
  const navigator = { userAgent: ua, platform: plataforma, maxTouchPoints: toques };
  vm.runInNewContext(codigo, { window, navigator });
  return { window, ouvintes };
}

const estado = (w) => JSON.parse(w.gcInstalarEstado());

teste('sem aviso do navegador não há o que instalar', () => {
  const { window } = navegador();
  assert.deepStrictEqual(estado(window), { instalada: false, podeInstalar: false, ios: false });
});

teste('com o aviso do Chrome pode instalar e o pedido corre uma vez', async () => {
  const { window, ouvintes } = navegador();
  let pedidos = 0;
  ouvintes.beforeinstallprompt({ preventDefault() {}, prompt: () => pedidos++, userChoice: Promise.resolve({ outcome: 'accepted' }) });
  assert.strictEqual(estado(window).podeInstalar, true);
  assert.strictEqual(await window.gcInstalar(), 'accepted');
  assert.strictEqual(pedidos, 1);
  assert.strictEqual(estado(window).podeInstalar, false); // o evento só serve uma vez
  assert.strictEqual(await window.gcInstalar(), 'indisponivel');
});

teste('já instalada (modo standalone) ou acabada de instalar', () => {
  assert.strictEqual(estado(navegador({ standalone: true }).window).instalada, true);
  const { window, ouvintes } = navegador();
  ouvintes.appinstalled();
  assert.strictEqual(estado(window).instalada, true);
});

teste('iPhone e iPad são reconhecidos (iPadOS diz que é Mac com ecrã tátil)', () => {
  assert.strictEqual(estado(navegador({ ua: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)' }).window).ios, true);
  assert.strictEqual(estado(navegador({ ua: 'Mozilla/5.0 (Macintosh)', plataforma: 'MacIntel', toques: 5 }).window).ios, true);
  assert.strictEqual(estado(navegador({ ua: 'Mozilla/5.0 (Macintosh)', plataforma: 'MacIntel', toques: 0 }).window).ios, false);
});

teste('um erro no pedido não rebenta', async () => {
  const { window, ouvintes } = navegador();
  ouvintes.beforeinstallprompt({ preventDefault() {}, prompt: () => { throw new Error('x'); }, userChoice: Promise.resolve({}) });
  assert.strictEqual(await window.gcInstalar(), 'indisponivel');
});

setTimeout(() => console.log(n + ' testes OK'), 50);
