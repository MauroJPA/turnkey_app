import 'dart:js_interop';

@JS('gcAvisarForno')
external void _gcAvisarForno();

/// Avisa que acabou o tempo: vibração e três bipes curtos (ver
/// `web/gc_dispositivo.js`). Nunca lança erro — o navegador pode bloquear o
/// som se a página ainda não teve toques.
void avisarForno() {
  try {
    _gcAvisarForno();
  } on Object {
    // sem som nem vibração neste aparelho
  }
}
