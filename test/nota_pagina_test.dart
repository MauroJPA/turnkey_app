import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/feedback/domain/nota_pagina.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  group('NotaPagina.fromRecord', () {
    test('lê todos os campos', () {
      final n = NotaPagina.fromRecord(
        RecordModel.fromJson({
          'id': 'n1',
          'collectionName': 'notas_pagina',
          'pagina': 'faturas',
          'texto': 'Falta a foto do rótulo desta fatura.',
          'autor_nome': 'Mauro',
          'resolvida': false,
        }),
      );
      expect(n.pagina, 'faturas');
      expect(n.texto, 'Falta a foto do rótulo desta fatura.');
      expect(n.autorNome, 'Mauro');
      expect(n.resolvida, isFalse);
      expect(n.resolvidaPor, '');
    });

    test('nota resolvida lê quem e quando', () {
      final n = NotaPagina.fromRecord(
        RecordModel.fromJson({
          'id': 'n2',
          'collectionName': 'notas_pagina',
          'pagina': 'ingredientes',
          'texto': 'Já corrigido.',
          'resolvida': true,
          'resolvida_por': 'Ana',
          'resolvida_em': '2026-09-28 10:00:00.000Z',
        }),
      );
      expect(n.resolvida, isTrue);
      expect(n.resolvidaPor, 'Ana');
      expect(n.resolvidaEm, isNotEmpty);
    });
  });
}
