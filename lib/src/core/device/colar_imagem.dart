// Colar imagens (Ctrl+V) no navegador. A versão web usa `web/gc_colar.js`;
// nas outras plataformas (e nos testes) não faz nada.
export 'colar_imagem_stub.dart'
    if (dart.library.js_interop) 'colar_imagem_web.dart';
