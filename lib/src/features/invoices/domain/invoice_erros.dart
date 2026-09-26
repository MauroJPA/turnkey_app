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
    final msg = e.response['message'];
    if (code < 500 || code == 502 || code == 503) {
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
