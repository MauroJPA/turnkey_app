// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;

/// Abre [paginaHtml] (página completa, com o seu próprio botão de imprimir)
/// num novo separador.
void abrirPaginaEtiquetas(String paginaHtml) {
  final blob = html.Blob([paginaHtml], 'text/html');
  html.window.open(html.Url.createObjectUrlFromBlob(blob), '_blank');
}

/// Altura, em mm, que a frente e a parte de baixo da etiqueta ocupam de facto
/// (medida ao desenhar a página, sem limite de altura).
typedef MedidasEtiqueta = ({double frenteMm, double corpoMm});

/// Desenha a página (gerada por [gerar] com um token de medição) num iframe
/// escondido e devolve as alturas medidas, ou `null` se não foi possível.
Future<MedidasEtiqueta?> medirEtiqueta(
  String Function(String token) gerar,
) async {
  final token = DateTime.now().microsecondsSinceEpoch.toString();
  final resposta = Completer<MedidasEtiqueta?>();
  final sub = html.window.onMessage.listen((e) {
    final d = e.data;
    if (d is! String || !d.startsWith('etq:$token:')) return;
    final p = d.split(':');
    final f = double.tryParse(p.length > 2 ? p[2] : '');
    final c = double.tryParse(p.length > 3 ? p[3] : '');
    if (!resposta.isCompleted) {
      resposta.complete(
        f == null || c == null ? null : (frenteMm: f, corpoMm: c),
      );
    }
  });
  final frame = html.IFrameElement()
    ..style.position = 'fixed'
    ..style.left = '-10000px'
    ..style.top = '0'
    ..style.width = '800px'
    ..style.height = '600px'
    ..style.visibility = 'hidden'
    ..srcdoc = gerar(token);
  html.document.body!.append(frame);
  try {
    return await resposta.future.timeout(const Duration(seconds: 5));
  } on Object {
    return null;
  } finally {
    await sub.cancel();
    frame.remove();
  }
}
