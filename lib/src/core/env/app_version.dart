/// Versão desta compilação (`--dart-define=APP_VERSION=1.17.2`, posta pelo script
/// de empacotamento). Vazia em desenvolvimento.
const versaoApp = String.fromEnvironment('APP_VERSION');

/// "v1.17.2", ou "desenvolvimento" quando a compilação não traz versão.
String get versaoAppTexto => versaoApp.isEmpty ? 'desenvolvimento' : 'v$versaoApp';
