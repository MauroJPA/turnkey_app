import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/finance/domain/custo_fixo.dart';
import 'package:gc_turnkey/src/features/finance/domain/ia_financeira.dart';

void main() {
  group('sugestoesDeJson', () {
    test('lê as sugestões e deteta quando o tipo muda', () {
      final s = sugestoesDeJson({
        'provider': 'gemini',
        'sugestoes': [
          {
            'id': 'a',
            'nome': 'Marketing',
            'valorMensal': 80,
            'tipoAtual': 'fixo',
            'tipoSugerido': 'variavel',
            'motivo': 'Pode reduzir-se',
            'acao': 'pausar',
            'dica': 'Pausa os anúncios',
          },
          {
            'id': 'b',
            'nome': 'Renda',
            'valorMensal': 600,
            'tipoAtual': 'fixo',
            'tipoSugerido': 'fixo',
            'acao': 'manter',
          },
        ],
      });
      expect(s, hasLength(2));
      expect(s[0].muda, isTrue);
      expect(s[0].tipoSugerido, TipoCusto.variavel);
      expect(s[0].acao, AcaoCusto.pausar);
      expect(s[0].dica, 'Pausa os anúncios');
      expect(s[1].muda, isFalse);
      expect(s[1].motivo, '');
    });

    test('tolera lixo: sem lista, sem id, ação desconhecida', () {
      expect(sugestoesDeJson(null), isEmpty);
      expect(sugestoesDeJson({'sugestoes': 5}), isEmpty);
      final s = sugestoesDeJson({
        'sugestoes': [
          {'nome': 'sem id'},
          {'id': 'x', 'tipoAtual': 'fixo', 'tipoSugerido': 'xpto', 'acao': 'yy'},
        ],
      });
      expect(s, hasLength(1));
      expect(s.single.tipoSugerido, TipoCusto.fixo);
      expect(s.single.acao, AcaoCusto.manter);
    });
  });

  group('DicasFinanceiras.fromJson', () {
    test('lê resumo e dicas, ignora as incompletas', () {
      final d = DicasFinanceiras.fromJson({
        'resumo': 'Mês fraco',
        'dicas': [
          {'titulo': 'A', 'texto': 'x', 'prioridade': 'alta', 'area': 'custos'},
          {'titulo': 'sem texto'},
          {'titulo': 'B', 'texto': 'y', 'prioridade': 'zzz'},
        ],
      });
      expect(d.resumo, 'Mês fraco');
      expect(d.dicas, hasLength(2));
      expect(d.dicas[0].prioridade, PrioridadeDica.alta);
      expect(d.dicas[1].prioridade, PrioridadeDica.media);
    });

    test('resposta inválida dá vazio', () {
      expect(DicasFinanceiras.fromJson('x').dicas, isEmpty);
    });
  });
}
