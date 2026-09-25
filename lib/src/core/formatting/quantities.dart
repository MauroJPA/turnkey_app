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

/// Unidade normalizada de um ingrediente: `g` (por omissão), `ml` ou `un`.
String unidadeNormalizada(String? u) => (u == 'ml' || u == 'un') ? u! : 'g';

/// Nome curto da unidade para etiquetas de campos ("g", "ml", "un").
String unidadeSufixo(String? u) => unidadeNormalizada(u);

/// Quantidade com a unidade certa: gramas -> "800 g"/"1,2 kg"; ml -> "250 ml"/"1,5 L";
/// unidades -> "12 un".
String quantidadeParaTexto(double v, String? unidade) {
  switch (unidadeNormalizada(unidade)) {
    case 'ml':
      if (v.abs() < 1000) return '${v.round()} ml';
      var s = (v / 1000).toStringAsFixed(3);
      s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
      return '${s.replaceAll('.', ',')} L';
    case 'un':
      final n = v == v.roundToDouble()
          ? v.toStringAsFixed(0)
          : v.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll('.', ',');
      return '$n un';
    default:
      return gramasParaTexto(v);
  }
}
