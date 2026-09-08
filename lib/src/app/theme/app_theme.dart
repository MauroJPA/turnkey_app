import 'package:flutter/material.dart';

/// Tema Material 3 da app.
///
/// A cor de destaque pode, mais tarde, ser sobreposta por empresa
/// (campo `cor_marca` em `empresas`).
class AppTheme {
  const AppTheme._();

  /// Castanho "cookie" — cor de marca por omissão.
  static const Color seed = Color(0xFF8D5B34);

  /// Cores predefinidas para escolher em Configurações → Aparência.
  static const List<({String nome, Color cor})> presets = [
    (nome: 'Castanho cookie', cor: Color(0xFF8D5B34)),
    (nome: 'Azul', cor: Color(0xFF2E6FB7)),
    (nome: 'Verde', cor: Color(0xFF2E7D4F)),
    (nome: 'Ameixa', cor: Color(0xFF7A4988)),
    (nome: 'Framboesa', cor: Color(0xFFB23A5C)),
  ];

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

  /// `#RRGGBB` de uma cor (para gravar em `empresas.cor_marca`).
  static String toHex(Color c) {
    final rgb = c.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
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
