import 'dart:js_interop';
import 'dart:typed_data';

@JS('gcColarRegistar')
external void _gcColarRegistar(JSFunction fn);

@JS('gcColarLimpar')
external void _gcColarLimpar();

/// Fica à escuta de imagens coladas (Ctrl+V) no navegador (ver
/// `web/gc_colar.js`): cada imagem chega a [aoColar] com um nome e os bytes.
/// Só uma pessoa escuta de cada vez (a tarefa aberta). Nunca lança erro: sem o
/// script, simplesmente não há colagem.
void ouvirImagensColadas(void Function(String nome, Uint8List bytes) aoColar) {
  try {
    _gcColarRegistar(
      ((JSString nome, JSUint8Array bytes) {
        aoColar(nome.toDart, bytes.toDart);
      }).toJS,
    );
  } on Object {
    // sem suporte: nada a fazer
  }
}

/// Deixa de escutar.
void deixarDeOuvirImagensColadas() {
  try {
    _gcColarLimpar();
  } on Object {
    // sem suporte
  }
}
