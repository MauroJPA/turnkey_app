import 'dart:js_interop';

@JS('gcNfcSuporta')
external JSBoolean _gcNfcSuporta();

@JS('gcNfcIniciar')
external void _gcNfcIniciar(JSFunction aoLer, JSFunction aoErro);

@JS('gcNfcParar')
external void _gcNfcParar();

/// Leitor de cartões NFC do aparelho (Web NFC, ver `web/gc_dispositivo.js`).
/// Só funciona no Chrome do Android e em páginas HTTPS.
abstract final class NfcLeitor {
  /// `true` se este navegador pode ler cartões NFC.
  static bool get suporta {
    try {
      return _gcNfcSuporta().toDart;
    } on Object {
      return false;
    }
  }

  /// Começa a ler. [aoLer] recebe o número de série de cada cartão
  /// encostado; [aoErro] os problemas (sem permissão, sem NFC…).
  static void iniciar({
    required void Function(String serie) aoLer,
    required void Function(String mensagem) aoErro,
  }) {
    try {
      _gcNfcIniciar(
        ((JSString s) => aoLer(s.toDart)).toJS,
        ((JSString m) => aoErro(m.toDart)).toJS,
      );
    } on Object {
      aoErro('Este navegador não lê cartões NFC.');
    }
  }

  static void parar() {
    try {
      _gcNfcParar();
    } on Object {
      // nada a parar
    }
  }
}
