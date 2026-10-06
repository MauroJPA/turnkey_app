import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/invoices/domain/fatura.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  group('linha de fatura: equipamento', () {
    test('tipo_item equipamento marca a linha', () {
      final l = FaturaLinhaIa.fromJson({
        'descricao': 'Forno convecção 5 tabuleiros',
        'tipo_item': 'equipamento',
        'quantidade': 1,
        'total': 1800.0,
      });
      expect(l.equipamento, isTrue);
      expect(l.consumivel, isFalse);
      expect(l.embalagem, isFalse);
      expect(l.total, 1800);
    });

    test('os outros tipos não são equipamento', () {
      for (final t in ['ingrediente', 'consumivel', 'embalagem', null]) {
        final l = FaturaLinhaIa.fromJson({'descricao': 'x', 'tipo_item': t});
        expect(l.equipamento, isFalse, reason: '$t');
      }
    });
  });

  group('item anterior com equipamento', () {
    RecordModel rec(Map<String, dynamic> extra) => RecordModel.fromJson({
      'id': 'i1',
      'linha_index': 0,
      'aplicado': true,
      'acao': 'preco',
      ...extra,
    });

    test('lê o equipamento criado', () {
      final a = ItemFaturaAnterior.fromRecord(rec({'equipamento': 'eq1'}));
      expect(a.equipamentoId, 'eq1');
      expect(a.aplicado, isTrue);
      // equipamentos não têm marca para corrigir
      expect(a.temAlvoParaCorrigir, isFalse);
    });

    test('sem equipamento fica nulo', () {
      final a = ItemFaturaAnterior.fromRecord(rec({'equipamento': ''}));
      expect(a.equipamentoId, isNull);
    });
  });
}
