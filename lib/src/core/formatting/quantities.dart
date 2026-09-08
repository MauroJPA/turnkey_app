/// Formatação de quantidades em gramas.
library;

/// Converte gramas para texto com a unidade adequada:
/// abaixo de 1000 g mostra gramas inteiras (`"800 g"`); a partir de 1000 g
/// mostra kg com vírgula decimal e sem zeros supérfluos (`"1 kg"`, `"1,2 kg"`,
/// `"1,594 kg"`).
String gramasParaTexto(double g) {
  final abs = g.abs();
  if (abs < 1000) {
    return '${g.round()} g';
  }
  var s = (g / 1000).toStringAsFixed(3);
  if (s.contains('.')) {
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  return '${s.replaceAll('.', ',')} kg';
}
