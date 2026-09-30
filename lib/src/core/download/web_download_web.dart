// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Dispara o "Guardar como" do browser para os [bytes] dados, com o nome
/// [nome] (ex.: "faturas-2026-09.zip").
void baixarFicheiro(String nome, List<int> bytes) {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', nome)
    ..click();
  html.Url.revokeObjectUrl(url);
}
