import 'package:flutter_test/flutter_test.dart';
import 'package:turnkey_app/src/core/help/help_content.dart';

void main() {
  test('todos os HelpTopic têm conteúdo com título e parágrafos', () {
    for (final t in HelpTopic.values) {
      final e = helpContent[t];
      expect(e, isNotNull, reason: 'sem conteúdo para $t');
      expect(e!.titulo.trim(), isNotEmpty, reason: 'título vazio em $t');
      expect(e.paragrafos, isNotEmpty, reason: 'sem parágrafos em $t');
      for (final p in e.paragrafos) {
        expect(p.trim(), isNotEmpty, reason: 'parágrafo vazio em $t');
      }
    }
  });
}
