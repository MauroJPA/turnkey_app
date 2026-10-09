import 'dart:js_interop';

import 'instalacao.dart';

@JS('gcInstalarEstado')
external String _gcInstalarEstado();

@JS('gcInstalar')
external JSPromise<JSString> _gcInstalar();

/// O que o navegador permite agora (ver `web/gc_instalar.js`). Nunca lança
/// erro: sem o script, nada se oferece.
EstadoInstalacao estadoInstalacao() {
  try {
    return EstadoInstalacao.fromJson(_gcInstalarEstado());
  } on Object {
    return const EstadoInstalacao();
  }
}

/// Mostra o pedido "Instalar" do navegador. Devolve `true` se a pessoa aceitou.
Future<bool> instalarApp() async {
  try {
    final r = await _gcInstalar().toDart;
    return r.toDart == 'accepted';
  } on Object {
    return false;
  }
}
