/// <reference path="../pb_data/types.d.ts" />

// Cabeçalhos de segurança, cache e compressão para a app web.
//
// 1. Segurança (em tudo o que não é a API nem o painel /_/ do PocketBase, que
//    já trazem os seus):
//      - Strict-Transport-Security (só quando o pedido chegou por HTTPS),
//      - Referrer-Policy, Permissions-Policy,
//      - Content-Security-Policy: a app só fala com ela própria (connect-src
//        'self'), por isso, mesmo que alguém consiga injetar código, não o
//        consegue enviar para fora; não pode ser posta numa <iframe>.
// 2. Cache: os ficheiros da app não têm versão no nome, por isso `no-cache` +
//    ETag: o navegador confirma com o servidor (resposta curta) e apanha logo
//    uma versão nova. Resolve o "Atualizar não atualiza".
// 3. Compressão: se existir `<ficheiro>.gz` ao lado (o pacote de produção
//    cria-os), serve-o comprimido — o primeiro carregamento no telemóvel passa
//    de ~12 MB para ~3 MB.
//
// A pasta pública é GC_TURNKEY_PUBLICO (por omissão /pb/pb_public, a do contentor).

// (as constantes ficam DENTRO do handler: o PocketBase corre cada handler numa VM
// própria e não vê variáveis do ficheiro.)
routerUse((e) => {
  const CSP = [
    "default-src 'self'",
    // 'unsafe-inline': as páginas de impressão usam onload; o CanvasKit precisa de wasm
    "script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval' https://www.gstatic.com",
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' data: blob:",
    "font-src 'self' data: https://fonts.gstatic.com",
    "connect-src 'self' https://www.gstatic.com https://fonts.gstatic.com data: blob:",
    "worker-src 'self' blob:",
    "frame-src 'self' blob:",
    "object-src 'none'",
    "base-uri 'self'",
    "form-action 'self'",
    "frame-ancestors 'none'",
  ].join('; ');

  const TIPOS = {
    js: 'application/javascript; charset=utf-8',
    wasm: 'application/wasm',
    json: 'application/json; charset=utf-8',
    css: 'text/css; charset=utf-8',
    svg: 'image/svg+xml',
    otf: 'font/otf',
    ttf: 'font/ttf',
    html: 'text/html; charset=utf-8',
    frag: 'text/plain; charset=utf-8',
  };


  const caminho = e.request.url.path || '/';

  const h = e.response.header();
  const https = (e.request.header.get('X-Forwarded-Proto') || '') === 'https' || !!e.request.tls;

  // a API e o painel de administração têm os seus próprios cabeçalhos
  // (só juntamos HSTS e Referrer-Policy)
  if (caminho.indexOf('/api/') === 0 || caminho.indexOf('/_/') === 0 || caminho === '/_') {
    h.set('Referrer-Policy', 'no-referrer');
    if (https) h.set('Strict-Transport-Security', 'max-age=31536000');
    return e.next();
  }

  h.set('X-Content-Type-Options', 'nosniff');
  h.set('Referrer-Policy', 'no-referrer');
  h.set('Permissions-Policy', 'camera=(self), microphone=(), geolocation=(), payment=()');
  h.set('Content-Security-Policy', CSP);
  h.set('Cache-Control', 'no-cache');
  if (https) h.set('Strict-Transport-Security', 'max-age=31536000');

  // compressão pré-calculada (GET/HEAD, pedido aceita gzip)
  const metodo = e.request.method;
  const aceita = e.request.header.get('Accept-Encoding') || '';
  const ext = (caminho.split('.').pop() || '').toLowerCase();
  if ((metodo === 'GET' || metodo === 'HEAD') && aceita.indexOf('gzip') !== -1 && TIPOS[ext] && caminho.indexOf('..') === -1) {
    const pasta = $os.getenv('GC_TURNKEY_PUBLICO') || '/pb/pb_public';
    const ficheiro = pasta + caminho + '.gz';
    try {
      const info = $os.stat(ficheiro);
      const etag = '"gz-' + info.size() + '-' + info.modTime().unix() + '"';
      h.set('ETag', etag);
      h.set('Vary', 'Accept-Encoding');
      if ((e.request.header.get('If-None-Match') || '') === etag) {
        return e.noContent(304);
      }
      h.set('Content-Encoding', 'gzip');
      if (metodo === 'HEAD') {
        h.set('Content-Type', TIPOS[ext]);
        return e.noContent(200);
      }
      return e.blob(200, TIPOS[ext], $os.readFile(ficheiro));
    } catch (_) {
      // sem versão comprimida: segue o ficheiro normal
      h.del('Content-Encoding');
      h.del('ETag');
    }
  }

  return e.next();
});
