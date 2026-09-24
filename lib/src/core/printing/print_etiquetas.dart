// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Abre [paginaHtml] (página completa, com o seu próprio botão de imprimir)
/// num novo separador.
void abrirPaginaEtiquetas(String paginaHtml) {
  final blob = html.Blob([paginaHtml], 'text/html');
  html.window.open(html.Url.createObjectUrlFromBlob(blob), '_blank');
}
