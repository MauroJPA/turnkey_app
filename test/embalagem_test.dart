import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/packaging/domain/embalagem.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  group('UsoEmbalagem', () {
    test('fromApi reconhece os valores válidos e ignora o resto', () {
      expect(UsoEmbalagem.fromApi('individual'), UsoEmbalagem.individual);
      expect(UsoEmbalagem.fromApi('multiplo'), UsoEmbalagem.multiplo);
      expect(UsoEmbalagem.fromApi('granel'), UsoEmbalagem.granel);
      expect(UsoEmbalagem.fromApi('outro'), UsoEmbalagem.outro);
      expect(UsoEmbalagem.fromApi(''), isNull);
      expect(UsoEmbalagem.fromApi(null), isNull);
      expect(UsoEmbalagem.fromApi('disparate'), isNull);
    });

    test('api devolve o nome e label o texto em português', () {
      expect(UsoEmbalagem.individual.api, 'individual');
      expect(UsoEmbalagem.multiplo.label, 'Múltiplo');
      expect(UsoEmbalagem.granel.label, 'A granel');
      expect(UsoEmbalagem.outro.label, 'Outro');
    });
  });

  group('Embalagem.fromRecord: característica, uso e formatos_cookie', () {
    test('lê característica, uso e uma lista de formatos', () {
      final e = Embalagem.fromRecord(
        RecordModel.fromJson({
          'id': 'e1',
          'collectionName': 'embalagens',
          'nome': 'Saco kraft',
          'caracteristica': 'com janela',
          'uso': 'multiplo',
          'formatos_cookie': ['f1', 'f2'],
        }),
      );
      expect(e.caracteristica, 'com janela');
      expect(e.uso, UsoEmbalagem.multiplo);
      expect(e.formatosCookieIds, ['f1', 'f2']);
    });

    test('formatos_cookie como string única (seleção simples) vira lista', () {
      final e = Embalagem.fromRecord(
        RecordModel.fromJson({
          'id': 'e2',
          'collectionName': 'embalagens',
          'nome': 'Caixa',
          'formatos_cookie': 'f1',
        }),
      );
      expect(e.formatosCookieIds, ['f1']);
    });

    test('sem característica/uso/formatos assume vazio/null', () {
      final e = Embalagem.fromRecord(
        RecordModel.fromJson({
          'id': 'e3',
          'collectionName': 'embalagens',
          'nome': 'Adesivo',
        }),
      );
      expect(e.caracteristica, '');
      expect(e.uso, isNull);
      expect(e.formatosCookieIds, isEmpty);
    });
  });

  group('EmbalagemInput.toBody: característica, uso e formatos_cookie', () {
    test('inclui os três campos novos', () {
      final b = EmbalagemInput(
        nome: 'Saco',
        caracteristica: ' com janela ',
        uso: UsoEmbalagem.individual,
        formatosCookieIds: const ['f1', 'f2'],
      ).toBody();
      expect(b['caracteristica'], 'com janela');
      expect(b['uso'], 'individual');
      expect(b['formatos_cookie'], ['f1', 'f2']);
    });

    test('sem uso definido envia string vazia (não null)', () {
      final b = EmbalagemInput(nome: 'Saco').toBody();
      expect(b['uso'], '');
      expect(b['formatos_cookie'], isEmpty);
    });
  });

  test(
    'custoPeca = preço da compra ÷ peças; custoUnidade divide pelo rende',
    () {
      const caixa = Embalagem(
        id: 'e1',
        nome: 'Caixa 6 un',
        tipo: 'Caixa',
        precoCompra: 120, // pacote de 100 caixas
        unidadesCompra: 100,
        rendeUnidades: 6,
      );
      expect(caixa.custoPeca, closeTo(1.2, 1e-9)); // €1,20 por caixa
      expect(caixa.custoUnidade, closeTo(0.2, 1e-9)); // €0,20 por cookie
    },
  );

  test('valores em falta assumem 1 (não dividir por zero)', () {
    const adesivo = Embalagem(
      id: 'e2',
      nome: 'Adesivo',
      precoCompra: 5,
      unidadesCompra: 0,
      rendeUnidades: 0,
    );
    expect(adesivo.custoPeca, 5);
    expect(adesivo.custoUnidade, 5);
  });

  test('toBody normaliza peças/rende <= 0 para 1', () {
    final b = EmbalagemInput(
      nome: ' Saco ',
      unidadesCompra: 0,
      rendeUnidades: -3,
    ).toBody();
    expect(b['nome'], 'Saco');
    expect(b['unidades_compra'], 1);
    expect(b['rende_unidades'], 1);
  });
}
