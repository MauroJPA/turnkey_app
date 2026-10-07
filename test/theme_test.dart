import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/app/theme/app_theme.dart';
import 'package:gc_turnkey/src/features/settings/domain/empresa.dart';

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

  test('presets: várias cores, todas distintas e com nome', () {
    expect(AppTheme.presets.length, greaterThanOrEqualTo(8));
    final rgb = AppTheme.presets
        .map((p) => p.cor.toARGB32() & 0xFFFFFF)
        .toSet();
    expect(rgb.length, AppTheme.presets.length);
    expect(AppTheme.presets.every((p) => p.nome.isNotEmpty), isTrue);
    // a cor de marca por omissão continua entre as opções
    expect(
      AppTheme.presets.any(
        (p) => (p.cor.toARGB32() & 0xFFFFFF) == (AppTheme.seed.toARGB32() & 0xFFFFFF),
      ),
      isTrue,
    );
  });

  test('paletas Gookie: cores do manual e texto legível nos dois modos', () {
    expect(AppTheme.gookieVerde.toARGB32() & 0xFFFFFF, 0x192621);
    expect(AppTheme.gookieCaramelo.toARGB32() & 0xFFFFFF, 0xB58054);
    expect(AppTheme.gookieCreme.toARGB32() & 0xFFFFFF, 0xFFFBF0);
    expect(AppTheme.paletaMarcaDe(AppTheme.gookieVerde), isNotNull);
    expect(AppTheme.paletaMarcaDe(AppTheme.seed), isNull);
    expect(AppTheme.paletaMarcaDe(null), isNull);

    double contraste(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    for (final p in AppTheme.paletasMarca) {
      expect(AppTheme.presets.any((x) => x.cor == p.cor), isTrue);
      for (final m in [p.claro, p.escuro]) {
        expect(contraste(m.texto, m.fundo), greaterThanOrEqualTo(4.5));
        expect(contraste(m.texto, m.superficie), greaterThanOrEqualTo(4.5));
        expect(contraste(m.sobrePrimaria, m.primaria), greaterThanOrEqualTo(4.5));
        expect(
          contraste(m.sobreSecundaria, m.secundaria),
          greaterThanOrEqualTo(4.5),
        );
      }
    }
  });

  test('tema com paleta Gookie usa o fundo creme/verde da marca', () {
    final claro = AppTheme.light(AppTheme.gookieCaramelo);
    final escuro = AppTheme.dark(AppTheme.gookieCaramelo);
    expect(claro.scaffoldBackgroundColor, AppTheme.gookieCreme);
    expect(escuro.scaffoldBackgroundColor, AppTheme.gookieVerde);
    // fundo personalizado continua a mandar por cima da paleta
    final custom = AppTheme.light(
      AppTheme.gookieCaramelo,
      fundo: const Color(0xFF123456),
    );
    expect(custom.scaffoldBackgroundColor, const Color(0xFF123456));
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
