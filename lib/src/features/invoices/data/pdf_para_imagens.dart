import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

/// O PDF já convertido: as páginas (PNG) e o total de páginas do ficheiro.
class PdfConvertido {
  const PdfConvertido({required this.paginas, required this.imagens});

  /// Páginas que tem o PDF (pode ser mais do que as imagens devolvidas).
  final int paginas;
  final List<Uint8List> imagens;
}

/// Converte um PDF em imagens, no próprio aparelho, com o PDF.js que vai
/// dentro da app (web/pdfjs, chamado por web/gc_pdf.js). Nada sai do aparelho.
/// Lança se o PDF não abre (protegido, estragado) ou se o leitor não carregou.
Future<PdfConvertido> converterPdfEmImagens(
  String url, {
  double escala = 2.5,
  int maxPaginas = 10,
}) async {
  final f = globalContext['gcPdfParaImagens'];
  if (!f.isA<JSFunction>()) {
    throw StateError('O leitor de PDF não está disponível.');
  }
  final res = await globalContext
      .callMethod<JSPromise<JSObject>>(
        'gcPdfParaImagens'.toJS,
        url.toJS,
        escala.toJS,
        maxPaginas.toJS,
      )
      .toDart;
  final total = (res['paginas'] as JSNumber).toDartInt;
  final lista = (res['imagens'] as JSArray<JSUint8Array>).toDart;
  return PdfConvertido(
    paginas: total,
    imagens: [for (final i in lista) i.toDart],
  );
}
