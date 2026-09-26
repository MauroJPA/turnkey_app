import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/invoices/application/analise_faturas_controller.dart';
import 'package:gc_turnkey/src/features/invoices/domain/fatura.dart';
import 'package:gc_turnkey/src/features/invoices/domain/invoice_erros.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  group('mensagemAmigavel', () {
    test('413: ficheiro grande demais, sem endereço do servidor', () {
      final m = mensagemAmigavel(
        ClientException(
          url: Uri.parse(
            'https://exemplo.ts.net:8444/api/collections/faturas/records',
          ),
          statusCode: 413,
          response: const {'message': 'Request entity too large.'},
        ),
      );
      expect(m, contains('grande demais'));
      expect(m, isNot(contains('ts.net')));
      expect(m, isNot(contains('413')));
    });

    test('sem ligação: aviso de rede', () {
      final m = mensagemAmigavel(ClientException(statusCode: 0));
      expect(m, contains('Sem ligação'));
    });

    test('mensagem do servidor (503 da IA) passa em português', () {
      final m = mensagemAmigavel(
        ClientException(
          statusCode: 503,
          response: const {
            'message': 'A IA está sobrecarregada. Tenta daqui a uns minutos.',
          },
        ),
      );
      expect(m, contains('sobrecarregada'));
    });

    test('erro desconhecido: mensagem genérica', () {
      expect(
        mensagemAmigavel(Exception('http://segredo?key=abc')),
        isNot(contains('segredo')),
      );
    });
  });

  group('Fatura: análise a meio', () {
    Fatura f(
      Map<String, dynamic> dados, {
      FaturaEstado estado = FaturaEstado.nova,
    }) => Fatura(
      id: 'x',
      tipo: FaturaTipo.fatura,
      estado: estado,
      dadosIa: dados,
    );

    test('lote com progresso', () {
      final fat = f({
        'lote': {'paginas': 93, 'proxima': 13},
      });
      expect(fat.temLote, isTrue);
      expect(fat.lotePaginas, 93);
      expect(fat.loteFeitas, 12);
      expect(fat.analiseAMeio, isTrue);
    });

    test('sem lote e já analisada', () {
      final fat = f(const {}, estado: FaturaEstado.analisada);
      expect(fat.temLote, isFalse);
      expect(fat.analiseAMeio, isFalse);
      expect(fat.loteFeitas, 0);
    });
  });

  test('TrabalhoAnalise: texto e progresso', () {
    const t = TrabalhoAnalise(
      chave: 'a',
      titulo: 'faturas.pdf',
      fase: FaseAnalise.aLer,
      paginas: 93,
      feitas: 12,
    );
    expect(t.ativo, isTrue);
    expect(t.progresso, closeTo(12 / 93, 1e-9));
    expect(t.texto, contains('12 de 93'));
    const e = TrabalhoAnalise(
      chave: 'a',
      titulo: 'x',
      fase: FaseAnalise.aEnviar,
      tamanhoBytes: 83600000,
    );
    expect(e.texto, contains('79,7 MB'));
    expect(e.progresso, isNull);
  });
}
