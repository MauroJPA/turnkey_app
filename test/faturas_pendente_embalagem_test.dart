import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/invoices/domain/fatura.dart';
import 'package:gc_turnkey/src/features/invoices/domain/match_ingrediente.dart';
import 'package:gc_turnkey/src/features/packaging/domain/embalagem.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  group('AcaoFatura.pendente', () {
    test('label e aplicaAgora', () {
      expect(AcaoFatura.pendente.label, 'Por rever depois');
      expect(AcaoFatura.pendente.aplicaAgora, isFalse);
      expect(AcaoFatura.ignorar.aplicaAgora, isFalse);
      expect(AcaoFatura.preco.aplicaAgora, isTrue);
      expect(AcaoFatura.stock.aplicaAgora, isTrue);
      expect(AcaoFatura.ambos.aplicaAgora, isTrue);
    });
  });

  group('FaturaLinhaIa: embalagem', () {
    test('tipo_item embalagem e tipo_embalagem', () {
      final l = FaturaLinhaIa.fromJson(const {
        'descricao': 'Caixa take-away 20x20',
        'nome_generico': 'Caixa take-away',
        'tipo_item': 'embalagem',
        'tipo_embalagem': 'Caixa',
        'quantidade': 100,
        'unidade': 'un',
        'preco_unitario': 0.35,
      });
      expect(l.embalagem, isTrue);
      expect(l.consumivel, isFalse);
      expect(l.tipoEmbalagem, 'Caixa');
    });

    test('sem tipo_item: nem consumível nem embalagem', () {
      final l = FaturaLinhaIa.fromJson(const {'descricao': 'Farinha'});
      expect(l.embalagem, isFalse);
      expect(l.consumivel, isFalse);
      expect(l.tipoEmbalagem, '');
    });
  });

  group('Fatura: pendentesLinhas', () {
    Fatura f(double? pendentes) => Fatura.fromRecord(
      RecordModel.fromJson({
        'id': 'f1',
        'collectionName': 'faturas',
        'tipo': 'fatura',
        'estado': 'analisada',
        if (pendentes != null) 'pendentes_linhas': pendentes,
      }),
    );

    test('sem pendentes: temPendentes falso', () {
      expect(f(0).temPendentes, isFalse);
      expect(f(null).temPendentes, isFalse);
    });

    test('com pendentes: temPendentes verdadeiro', () {
      final fat = f(3);
      expect(fat.pendentesLinhas, 3);
      expect(fat.temPendentes, isTrue);
    });
  });

  group('ItemFaturaAnterior.fromRecord', () {
    test('lê índice, aplicado, ação e os alvos', () {
      final item = ItemFaturaAnterior.fromRecord(
        RecordModel.fromJson({
          'id': 'i1',
          'collectionName': 'faturas_itens',
          'linha_index': 2,
          'aplicado': true,
          'acao': 'preco',
          'ingrediente': 'ing1',
          'consumivel': '',
          'embalagem': '',
        }),
      );
      expect(item.index, 2);
      expect(item.aplicado, isTrue);
      expect(item.acao, AcaoFatura.preco);
      expect(item.ingredienteId, 'ing1');
      expect(item.consumivelId, isNull);
      expect(item.embalagemId, isNull);
    });

    test('ação desconhecida cai em pendente', () {
      final item = ItemFaturaAnterior.fromRecord(
        RecordModel.fromJson({
          'id': 'i1',
          'collectionName': 'faturas_itens',
          'linha_index': 0,
          'acao': '',
        }),
      );
      expect(item.acao, AcaoFatura.pendente);
      expect(item.aplicado, isFalse);
    });

    test('lê produto, marca, fornecedor e descrição da fatura', () {
      final item = ItemFaturaAnterior.fromRecord(
        RecordModel.fromJson({
          'id': 'i1',
          'collectionName': 'faturas_itens',
          'linha_index': 1,
          'aplicado': true,
          'acao': 'preco',
          'ingrediente': 'ing1',
          'produto': 'prod1',
          'marca': 'Sidul',
          'fornecedor': 'Makro',
          'descricao_fatura': 'Açúcar branco Sidul 1kg',
        }),
      );
      expect(item.produtoId, 'prod1');
      expect(item.marca, 'Sidul');
      expect(item.fornecedor, 'Makro');
      expect(item.descricaoFatura, 'Açúcar branco Sidul 1kg');
      expect(item.temAlvoParaCorrigir, isTrue);
    });

    test('sem produto/consumível/embalagem: nada para corrigir', () {
      final item = ItemFaturaAnterior.fromRecord(
        RecordModel.fromJson({
          'id': 'i1',
          'collectionName': 'faturas_itens',
          'linha_index': 0,
          'acao': 'pendente',
        }),
      );
      expect(item.produtoId, isNull);
      expect(item.temAlvoParaCorrigir, isFalse);
      expect(item.marca, '');
      expect(item.fornecedor, '');
    });
  });

  group('emparelharEmbalagem', () {
    const caixa = Embalagem(
      id: 'e1',
      nome: 'Caixa take-away média',
      tipo: 'Caixa',
      nomesFatura: ['caixa take away 20x20x8'],
    );
    const saco = Embalagem(id: 'e2', nome: 'Saco kraft pequeno', tipo: 'Saco');
    final lista = [caixa, saco];

    test('nome de fatura já aprendido', () {
      final e = emparelharEmbalagem(
        descricao: 'Caixa Take Away 20x20x8',
        embalagens: lista,
      );
      expect(e?.id, 'e1');
    });

    test('semelhança com o nome genérico da IA', () {
      final e = emparelharEmbalagem(
        descricao: 'CX TAKEAWAY MEDIA C/TAMPA',
        nomeGenerico: 'Caixa take-away média',
        embalagens: lista,
      );
      expect(e?.id, 'e1');
    });

    test('sem correspondência devolve null', () {
      expect(
        emparelharEmbalagem(
          descricao: 'Fita adesiva transparente',
          embalagens: lista,
        ),
        isNull,
      );
    });
  });
}
