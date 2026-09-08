import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnkey_app/src/app/theme/app_theme.dart';
import 'package:turnkey_app/src/features/settings/domain/empresa.dart';

void main() {
  test('parseHex aceita #RRGGBB e RRGGBB, rejeita o resto', () {
    expect(AppTheme.parseHex('#8D5B34'), isNotNull);
    expect(AppTheme.parseHex('8D5B34'), isNotNull);
    expect(AppTheme.parseHex('  #2E6FB7 '), isNotNull);
    expect(AppTheme.parseHex('xyz'), isNull);
    expect(AppTheme.parseHex('#12'), isNull);
    expect(AppTheme.parseHex(''), isNull);
  });

  test('toHex é o inverso de parseHex', () {
    for (final p in AppTheme.presets) {
      final hex = AppTheme.toHex(p.cor);
      final back = AppTheme.parseHex(hex)!;
      expect(back.toARGB32() & 0xFFFFFF, p.cor.toARGB32() & 0xFFFFFF);
    }
  });

  test('presets: 5 cores, todas distintas', () {
    expect(AppTheme.presets.length, 5);
    final rgb = AppTheme.presets
        .map((p) => p.cor.toARGB32() & 0xFFFFFF)
        .toSet();
    expect(rgb.length, AppTheme.presets.length);
  });

  test('TemaApp.fromApi tolerante e .modo correto', () {
    expect(TemaApp.fromApi('claro'), TemaApp.claro);
    expect(TemaApp.fromApi('escuro'), TemaApp.escuro);
    expect(TemaApp.fromApi(null), TemaApp.sistema);
    expect(TemaApp.fromApi('lixo'), TemaApp.sistema);
    expect(TemaApp.claro.modo, ThemeMode.light);
    expect(TemaApp.escuro.modo, ThemeMode.dark);
    expect(TemaApp.sistema.modo, ThemeMode.system);
  });
}
