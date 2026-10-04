import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/finance/domain/custo_fixo.dart';

void main() {
  group('TipoCusto', () {
    test('fromApi tolerante, cai em fixo', () {
      expect(TipoCusto.fromApi('variavel'), TipoCusto.variavel);
      expect(TipoCusto.fromApi('fixo'), TipoCusto.fixo);
      expect(TipoCusto.fromApi('lixo'), TipoCusto.fixo);
      expect(TipoCusto.fromApi(null), TipoCusto.fixo);
    });
  });

  group('CustoFixo.ativo', () {
    test('por omissão (arquivado=false) fica ativo', () {
      const c = CustoFixo(id: '1', nome: 'Aluguel', valorMensal: 500);
      expect(c.ativo, isTrue);
    });

    test('arquivado=true fica inativo', () {
      const c = CustoFixo(
          id: '1', nome: 'Aluguel', valorMensal: 500, arquivado: true);
      expect(c.ativo, isFalse);
    });
  });

  group('CustoFixoInput.toBody', () {
    test('normaliza nome/notas e envia o tipo pela api', () {
      final input = CustoFixoInput(
        nome: '  Aluguel  ',
        tipo: TipoCusto.variavel,
        valorMensal: 500,
        notas: '  nota  ',
      );
      expect(input.toBody(), {
        'nome': 'Aluguel',
        'tipo': 'variavel',
        'valor_mensal': 500,
        'notas': 'nota',
        'dia_pagamento': null,
        'categoria': '',
      });
    });

    test('envia a categoria com a primeira letra maiúscula', () {
      final input = CustoFixoInput(
        nome: 'Extintores',
        tipo: TipoCusto.fixo,
        valorMensal: 5,
        categoria: '  controlo operacional ',
      );
      expect(input.toBody()['categoria'], 'Controlo operacional');
    });

    test('inclui o dia de pagamento quando definido', () {
      final input = CustoFixoInput(
        nome: 'Energia',
        tipo: TipoCusto.fixo,
        valorMensal: 140,
        diaPagamento: 8,
      );
      expect(input.toBody()['dia_pagamento'], 8);
    });
  });
}
