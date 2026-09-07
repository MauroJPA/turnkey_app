/// Formatação e arredondamento de valores monetários.
///
/// Portado de `meu_app_ia/lib/utils/ui_helper.dart` (`formatPrice`), que
/// arredondava sempre **para cima** a 2 casas decimais.
library;

enum RoundingRule {
  /// Arredonda sempre para cima (comportamento histórico da Gookie).
  up,

  /// Arredondamento normal (metade para cima).
  nearest,
}

/// Arredonda [value] a [decimals] casas segundo [rule].
double roundMoney(
  double value, {
  RoundingRule rule = RoundingRule.up,
  int decimals = 2,
}) {
  if (value.isNaN || value.isInfinite) return 0;
  final factor = _pow10(decimals);
  final scaled = value * factor;
  final rounded = switch (rule) {
    RoundingRule.up => scaled.ceil(),
    RoundingRule.nearest => scaled.round(),
  };
  return rounded / factor;
}

/// Formata [value] como preço com símbolo de moeda (ex.: `€1,23`).
String formatMoney(
  double value, {
  String symbol = '€',
  RoundingRule rule = RoundingRule.up,
  int decimals = 2,
}) {
  final rounded = roundMoney(value, rule: rule, decimals: decimals);
  return '$symbol${rounded.toStringAsFixed(decimals).replaceAll('.', ',')}';
}

int _pow10(int n) {
  var r = 1;
  for (var i = 0; i < n; i++) {
    r *= 10;
  }
  return r;
}
