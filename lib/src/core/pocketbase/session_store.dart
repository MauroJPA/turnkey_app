import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pocketbase/pocketbase.dart';

/// Persiste o token de autenticação do PocketBase no armazenamento seguro
/// do dispositivo, para a sessão sobreviver a reinícios da app.
class SessionStore {
  SessionStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _key = 'pb_auth';

  Future<String?> readInitial() => _storage.read(key: _key);

  /// Cria um [AsyncAuthStore] ligado a este armazenamento.
  /// [initial] deve vir de [readInitial] (lido antes do arranque da app).
  AsyncAuthStore build(String? initial) {
    return AsyncAuthStore(
      initial: initial,
      save: (data) => _storage.write(key: _key, value: data),
      clear: () => _storage.delete(key: _key),
    );
  }
}
