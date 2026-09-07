import 'package:flutter/material.dart';

/// Tema Material 3 da app.
///
/// A cor de destaque pode, mais tarde, ser sobreposta por empresa
/// (campo `cor_marca` em `empresas`).
class AppTheme {
  const AppTheme._();

  /// Castanho "cookie" — cor de marca por omissão.
  static const Color seed = Color(0xFF8D5B34);

  static ThemeData light([Color? brand]) =>
      _base(Brightness.light, brand ?? seed);
  static ThemeData dark([Color? brand]) =>
      _base(Brightness.dark, brand ?? seed);

  /// Interpreta uma cor hex (`#RRGGBB` ou `RRGGBB`); `null` se inválida.
  static Color? parseHex(String value) {
    var v = value.trim().replaceFirst('#', '');
    if (v.length == 6) v = 'FF$v';
    if (v.length != 8) return null;
    final n = int.tryParse(v, radix: 16);
    return n == null ? null : Color(n);
  }

  static ThemeData _base(Brightness brightness, Color seedColor) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: scheme.surfaceTint,
        centerTitle: false,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
        ),
      ),
    );
  }
}
