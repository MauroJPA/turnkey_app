// Service worker da gc_turnkey: deixa a app abrir sem ligação (ex.: o quiosque
// da loja depois de o Wi-Fi cair e a página ser recarregada).
//
// Regra: "rede primeiro, cache se a rede falhar". Com ligação a app é sempre a
// versão do servidor (os ficheiros são pedidos e validados como antes); a cópia
// guardada só serve quando o servidor não responde. Nunca guarda nem responde a
// pedidos à API (`/api/`) nem ao painel (`/_/`), nem ao `version.json` (para o
// aviso de versão nova ser sempre verdadeiro).
'use strict';

const CACHE = 'gc-shell-v1';
const ESPERA_REDE_MS = 6000;

// o mínimo para a app arrancar; o resto (CanvasKit, tipos de letra…) é
// guardado à medida que a app o pede ou pela mensagem "cachear" da página
const ESSENCIAIS = [
  './',
  'index.html',
  'flutter_bootstrap.js',
  'flutter.js',
  'main.dart.js',
  'gc_dispositivo.js',
  'gc_instalar.js',
  'manifest.json',
  'favicon.png',
];

function ignorar(url) {
  const p = url.pathname;
  return p.includes('/api/') || p.includes('/_/') || p.endsWith('/version.json') || p.endsWith('/gc_sw.js');
}

self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE).then((c) =>
      Promise.all(
        ESSENCIAIS.map((u) =>
          c.add(new Request(u, { cache: 'reload' })).catch(() => {}),
        ),
      ),
    ),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      for (const k of await caches.keys()) {
        if (k !== CACHE) await caches.delete(k);
      }
      await self.clients.claim();
    })(),
  );
});

// A página diz que ficheiros usou (a primeira vez, antes de o service worker
// controlar a página): guarda os que ainda faltam.
self.addEventListener('message', (event) => {
  const d = event.data || {};
  if (d.tipo !== 'cachear' || !Array.isArray(d.urls)) return;
  event.waitUntil(
    (async () => {
      const c = await caches.open(CACHE);
      for (const u of d.urls.slice(0, 200)) {
        try {
          const url = new URL(u, self.location.href);
          if (url.origin !== self.location.origin || ignorar(url)) continue;
          if (await c.match(url.href, { ignoreSearch: true, ignoreVary: true })) continue;
          const r = await fetch(url.href, { cache: 'no-cache' });
          if (r.ok) await c.put(url.href, r);
        } catch (_) {}
      }
    })(),
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET' || req.headers.has('range')) return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin || ignorar(url)) return;
  event.respondWith(redePrimeiro(req));
});

async function guardada(c, req) {
  return (
    // ignoreVary: o servidor responde com "Vary: Origin" e pedidos de módulos
    // (cors) levam esse cabeçalho; sem isto a cópia guardada não "casava"
    (await c.match(req, { ignoreSearch: true, ignoreVary: true })) ||
    (req.mode === 'navigate'
      ? (await c.match('./', { ignoreVary: true })) ||
        (await c.match('index.html', { ignoreVary: true }))
      : undefined)
  );
}

async function redePrimeiro(req) {
  const c = await caches.open(CACHE);
  const rede = fetch(req);
  try {
    const TEMPO = Symbol('tempo');
    const primeiro = await Promise.race([
      rede,
      new Promise((resolve) => setTimeout(() => resolve(TEMPO), ESPERA_REDE_MS)),
    ]);
    if (primeiro === TEMPO) {
      // servidor lento ou Wi-Fi sem internet: usa a cópia, se a houver
      const copia = await guardada(c, req);
      if (copia) {
        rede.catch(() => {});
        return copia;
      }
      return await rede;
    }
    // servidor com problemas (ex.: a reiniciar numa atualização): cópia, se houver
    if (primeiro.status >= 500) {
      const copia = await guardada(c, req);
      if (copia) return copia;
    }
    if (primeiro.ok && primeiro.type === 'basic') {
      c.put(req, primeiro.clone()).catch(() => {});
    }
    return primeiro;
  } catch (_) {
    const copia = await guardada(c, req);
    if (copia) return copia;
    return new Response('Sem ligação ao servidor.', {
      status: 503,
      headers: { 'Content-Type': 'text/plain; charset=utf-8' },
    });
  }
}
