import 'package:pocketbase/pocketbase.dart';

/// Mensagem em português para mostrar à pessoa. Nunca devolve o erro de rede em
/// bruto (pode conter o endereço do servidor).
String mensagemAmigavel(Object e) {
  if (e is ClientException) {
    final code = e.statusCode;
    if (code == 413) {
      return 'O ficheiro é grande demais para o servidor. Divide o PDF em '
          'partes mais pequenas e tenta de novo.';
    }
    if (code == 0) {
      return 'Sem ligação ao servidor. Verifica a internet e tenta de novo '
          '(o que já foi lido fica guardado).';
    }
    if (code < 500 || code == 502 || code == 503) {
      final campos = _erroPorCampo(e.response['data']);
      if (campos.isNotEmpty) return campos;
      final msg = e.response['message'];
      if (msg is String && msg.trim().isNotEmpty) return msg.trim();
    }
    if (code == 401 || code == 403) {
      return 'Sem permissão ou sessão terminada. Entra de novo.';
    }
    return 'O servidor não conseguiu concluir. Tenta de novo daqui a uns '
        'minutos (o que já foi lido fica guardado).';
  }
  return 'Não foi possível concluir. Tenta de novo.';
}

/// PocketBase devolve os erros de validação por campo em `data`
/// (ex.: `{"nome": {"message": "Must be no more than 200 character(s)."}}`).
/// Em vez do genérico "Failed to create record.", mostra qual campo falhou.
String _erroPorCampo(Object? data) {
  if (data is! Map || data.isEmpty) return '';
  final partes = <String>[];
  for (final entry in data.entries) {
    final info = entry.value;
    if (info is! Map) continue;
    final msg = info['message'];
    if (msg is! String || msg.trim().isEmpty) continue;
    partes.add('"${entry.key}": ${msg.trim()}');
  }
  return partes.join('; ');
}
