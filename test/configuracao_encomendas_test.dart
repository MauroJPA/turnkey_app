import 'package:flutter_test/flutter_test.dart';
import 'package:turnkey_app/src/features/orders/domain/configuracao_encomendas.dart';

void main() {
  group('TalaoTamanho', () {
    test('fromApi tolerante, cai em termico80', () {
      expect(TalaoTamanho.fromApi('a4'), TalaoTamanho.a4);
      expect(TalaoTamanho.fromApi('termico80'), TalaoTamanho.termico80);
      expect(TalaoTamanho.fromApi('lixo'), TalaoTamanho.termico80);
      expect(TalaoTamanho.fromApi(null), TalaoTamanho.termico80);
    });
  });

  group('ConfiguracaoEncomendas.vazia', () {
    test('tem valores por omissão sensatos sem precisar de registo criado', () {
      const c = ConfiguracaoEncomendas.vazia;
      expect(c.id, isEmpty);
      expect(c.talaoTamanho, TalaoTamanho.termico80);
      expect(c.imprimirAuto, isFalse);
      expect(c.lembreteHoras, 4);
    });
  });

  group('ConfiguracaoEncomendasInput.toBody', () {
    test('envia os 3 campos configuráveis', () {
      final input = ConfiguracaoEncomendasInput(
        talaoTamanho: TalaoTamanho.a4,
        imprimirAuto: true,
        lembreteHoras: 6,
      );
      expect(input.toBody(), {
        'talao_tamanho': 'a4',
        'imprimir_auto': true,
        'lembrete_horas': 6,
      });
    });
  });
}
