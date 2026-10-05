import 'package:qr/qr.dart';

/// Um QR code como SVG (um só `<path>`, nítido em qualquer tamanho e na
/// impressão). Tem margem ("quiet zone") de 2 módulos.
String qrSvg(
  String dados, {
  QrErrorCorrectLevel nivel = QrErrorCorrectLevel.medium,
}) {
  final code = QrCode(
    payload: QrPayload.fromString(dados),
    errorCorrectLevel: nivel,
  );
  final img = QrImage(code);
  const margem = 2;
  final n = img.moduleCount;
  final total = n + margem * 2;
  final b = StringBuffer();
  for (var y = 0; y < n; y++) {
    var x = 0;
    while (x < n) {
      if (img.isDark(y, x)) {
        final ini = x;
        while (x < n && img.isDark(y, x)) {
          x++;
        }
        b.write('M${ini + margem} ${y + margem}h${x - ini}v1h-${x - ini}z');
      } else {
        x++;
      }
    }
  }
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $total $total" '
      'shape-rendering="crispEdges"><rect width="$total" height="$total" fill="#fff"/>'
      '<path d="$b" fill="#000"/></svg>';
}
