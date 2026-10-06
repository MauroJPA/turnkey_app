import 'package:pocketbase/pocketbase.dart';

/// O servidor não se alcançou (sem Wi-Fi, servidor a reiniciar…): vale a
/// pena guardar e tentar mais tarde. Um erro de validação não é isto.
bool eErroDeLigacao(Object e) {
  if (e is ClientException) {
    // o cliente do PocketBase marca como "abort" qualquer falha de rede
    // (ligação recusada, Wi-Fi caído…); só o cliente fechado não conta
    if (e.originalError is StateError) return false;
    return e.statusCode == 0 ||
        e.statusCode == 502 ||
        e.statusCode == 503 ||
        e.statusCode == 504;
  }
  return false;
}

/// A sessão caducou ou não tem permissão: não se deve perder o registo, mas
/// também não adianta repetir até alguém entrar de novo.
bool eErroDeSessao(Object e) =>
    e is ClientException && (e.statusCode == 401 || e.statusCode == 403);

/// O envio falhou por o id já existir: o registo já chegou antes.
bool eIdJaExiste(Object e) {
  if (e is! ClientException || e.statusCode != 400) return false;
  final data = e.response['data'];
  return data is Map && data.containsKey('id');
}
