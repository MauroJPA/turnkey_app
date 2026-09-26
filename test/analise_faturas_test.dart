import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/invoices/application/analise_faturas_controller.dart';
import 'package:gc_turnkey/src/features/invoices/domain/analise_resumo.dart';
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

  resumoTests();
}

void resumoTests() {
  group('ResumoAnalise', () {
    test('lê itens, duplicadas e páginas sem fatura', () {
      final r = ResumoAnalise.fromJson({
        'itens': [
          {
            'id': 'a',
            'fornecedor': 'Makro',
            'numero': '1',
            'estado': 'analisada',
            'linhas': 12,
            'paginas': '1-2',
          },
          {
            'id': 'b',
            'fornecedor': 'Makro',
            'numero': '1',
            'estado': 'erro',
            'duplicada': true,
            'paginas': '3',
          },
          {
            'id': 'c',
            'fornecedor': 'Icopa',
            'estado': 'analisada',
            'linhas': 0,
            'paginas': '4',
          },
        ],
        'paginasSemFatura': '5-6',
      });
      expect(r.itens.length, 3);
      expect(r.novas, 1);
      expect(r.duplicadas, 1);
      expect(r.semLinhas, 1);
      expect(r.comErro, 0);
      expect(r.temAvisos, isTrue);
      expect(r.paginasSemFatura, '5-6');
    });

    test('sem resumo: vazio e sem avisos', () {
      final r = ResumoAnalise.fromJson(null);
      expect(r.itens, isEmpty);
      expect(r.temAvisos, isFalse);
    });
  });

  test('TrabalhoAnalise feita: texto com o resumo', () {
    final t = TrabalhoAnalise(
      chave: 'a',
      titulo: 'x.pdf',
      fase: FaseAnalise.feita,
      resumo: ResumoAnalise.fromJson({
        'itens': [
          {'id': 'a', 'estado': 'analisada', 'linhas': 3},
          {'id': 'b', 'estado': 'erro', 'duplicada': true},
        ],
        'paginasSemFatura': '7',
      }),
    );
    expect(t.texto, contains('1 nova'));
    expect(t.texto, contains('1 duplicada'));
    expect(t.texto, contains('págs. sem fatura: 7'));
  });

  test('TrabalhoAnalise a ler com aviso de nova tentativa', () {
    const t = TrabalhoAnalise(
      chave: 'a',
      titulo: 'x.pdf',
      fase: FaseAnalise.aLer,
      paginas: 93,
      feitas: 24,
      mensagem:
          'Páginas 25–30: IA sobrecarregada.\nNova tentativa em 10s (2 de 6)…',
    );
    expect(t.texto, contains('24 de 93'));
    expect(t.texto, contains('Nova tentativa em 10s'));
  });
}
