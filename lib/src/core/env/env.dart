/// Configuração de ambiente lida em tempo de compilação via `--dart-define`.
///
/// Exemplo:
/// ```
/// flutter run --dart-define=PB_URL=http://127.0.0.1:8090
/// ```
library;

class Env {
  const Env._();

  /// URL base do servidor PocketBase.
  ///
  /// Local por omissão; em produção passa-se o endereço do Mini PC
  /// (ex.: via Tailscale) por `--dart-define=PB_URL=...`.
  static const String pbUrl = String.fromEnvironment(
    'PB_URL',
    defaultValue: 'http://127.0.0.1:8090',
  );

  /// Locale por omissão para formatação de números e datas.
  static const String defaultLocale = String.fromEnvironment(
    'DEFAULT_LOCALE',
    defaultValue: 'pt_PT',
  );

  /// Ativa ecrãs e logs de diagnóstico.
  static const bool debugTools = bool.fromEnvironment('DEBUG_TOOLS');
}
