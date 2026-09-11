// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
//
// A app só é construída para web (`flutter build web`); `dart:html` continua
// a funcionar e evita adicionar os pacotes `printing`/`pdf` só para isto.
import 'dart:html' as html;

/// Abre uma nova janela/separador com [corpoHtml] e chama logo o diálogo de
/// impressão do navegador — usado para imprimir a tabela nutricional de um
/// produto Gookie sem depender de pacotes extra (`printing`/`pdf`).
///
/// O visual é propositadamente simples por agora; será substituído por um
/// template a fornecer.
void abrirImpressao(String tituloPagina, String corpoHtml) {
  final pagina = '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>$tituloPagina</title>
<style>
  body { font-family: Arial, Helvetica, sans-serif; padding: 24px; color: #111; }
  h1 { font-size: 18px; margin: 0 0 4px; }
  p.sub { margin: 0 0 16px; color: #555; font-size: 13px; }
  table { border-collapse: collapse; width: 100%; max-width: 480px; }
  th, td { border: 1px solid #999; padding: 6px 10px; font-size: 13px; text-align: left; }
  th { background: #eee; text-align: right; }
  td.valor { text-align: right; }
  td.indent { padding-left: 22px; font-style: italic; }
  p.alergenios { margin-top: 16px; font-size: 13px; }
  p.aviso { margin-top: 16px; font-size: 11px; color: #777; }
  @media print { body { padding: 0; } }
</style>
</head>
<body onload="window.print()">
$corpoHtml
</body>
</html>
''';
  final blob = html.Blob([pagina], 'text/html');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
}
