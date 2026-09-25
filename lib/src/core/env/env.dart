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
  /// Local por omissão. Em produção a app web é servida pelo próprio
  /// PocketBase (pasta `web`), por isso compila-se com
  /// `--dart-define=PB_URL=origin` e usa o endereço de onde foi aberta
  /// (funciona igual em `http://mini-pc:8090` e em `https://dominio`).
  /// Também aceita um endereço fixo: `--dart-define=PB_URL=https://...`.
  static const String _pbUrlDefine = String.fromEnvironment(
    'PB_URL',
    defaultValue: 'http://127.0.0.1:8090',
  );

  static String get pbUrl =>
      _pbUrlDefine == 'origin' ? Uri.base.origin : _pbUrlDefine;

  /// Locale por omissão para formatação de números e datas.
  static const String defaultLocale = String.fromEnvironment(
    'DEFAULT_LOCALE',
    defaultValue: 'pt_PT',
  );

  /// Ativa ecrãs e logs de diagnóstico.
  static const bool debugTools = bool.fromEnvironment('DEBUG_TOOLS');
}
