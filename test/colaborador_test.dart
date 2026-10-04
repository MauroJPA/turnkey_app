import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/quiosque/domain/colaborador.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  test('normalizarUid deixa só hexadecimal em maiúsculas', () {
    expect(normalizarUid('04:a1:b2:c3:d4:e5:f6'), '04A1B2C3D4E5F6');
    expect(normalizarUid(' 04 a1-b2 '), '04A1B2');
    expect(normalizarUid(''), '');
    expect(normalizarUid('xyz'), '');
  });

  test('o cartão encontra a pessoa certa (e ignora arquivados)', () {
    const ana = Colaborador(id: 'a', nome: 'Ana', nfcUid: '04A1B2C3');
    const rui = Colaborador(id: 'r', nome: 'Rui', nfcUid: '0511223344');
    const velho = Colaborador(
      id: 'v',
      nome: 'Velho',
      nfcUid: 'AABBCCDD',
      arquivado: true,
    );
    const semCartao = Colaborador(id: 's', nome: 'Sem cartão');
    final todos = [ana, rui, velho, semCartao];
    expect(colaboradorDoCartao('04:a1:b2:c3', todos)?.nome, 'Ana');
    expect(colaboradorDoCartao('05-11-22-33-44', todos)?.nome, 'Rui');
    expect(colaboradorDoCartao('AA:BB:CC:DD', todos), isNull); // arquivado
    expect(colaboradorDoCartao('99:99', todos), isNull);
    expect(colaboradorDoCartao('', todos), isNull); // vazio não casa com "sem cartão"
  });

  test('a Equipa aparece toda, com o cartão de quem já tem linha', () {
    const linhas = [
      Colaborador(id: 'L1', nome: 'Ana (antigo)', nfcUid: '04A1', userId: 'u1'),
      Colaborador(id: 'L2', nome: 'Visitante', nfcUid: '0511'),
      Colaborador(id: 'L3', nome: 'Rui', userId: 'u2', arquivado: true),
    ];
    final r = juntarEquipa(
      linhas: linhas,
      equipa: [
        (id: 'u1', nome: 'Ana Silva'),
        (id: 'u2', nome: 'Rui'),
        (id: 'u3', nome: 'Carla'),
      ],
    );
    expect(r.map((c) => c.nome), ['Ana Silva', 'Carla', 'Rui', 'Visitante']);
    final ana = r.firstWhere((c) => c.userId == 'u1');
    expect(ana.id, 'L1'); // linha existente
    expect(ana.nfcUid, '04A1');
    expect(ana.nome, 'Ana Silva'); // o nome vem da conta
    final carla = r.firstWhere((c) => c.userId == 'u3');
    expect(carla.virtual, isTrue); // ainda sem linha
    expect(carla.id, '${prefixoEquipa}u3');
    expect(carla.temCartao, isFalse);
    expect(r.firstWhere((c) => c.userId == 'u2').arquivado, isTrue);
    expect(r.firstWhere((c) => c.nome == 'Visitante').daEquipa, isFalse);
  });

  test('uma conta que saiu da Equipa deixa de aparecer', () {
    final r = juntarEquipa(
      linhas: const [Colaborador(id: 'L1', nome: 'Velho', userId: 'uX')],
      equipa: [(id: 'u1', nome: 'Ana')],
    );
    expect(r.map((c) => c.nome), ['Ana']);
  });

  test('lê o colaborador do registo', () {
    final c = Colaborador.fromRecord(
      RecordModel({
        'id': 'c1',
        'nome': 'Ana',
        'nfc_uid': '04:a1:b2',
        'ordem': 2,
        'arquivado': false,
      }),
    );
    expect(c.nfcUid, '04A1B2');
    expect(c.temCartao, isTrue);
    expect(c.ativo, isTrue);
    final sem = Colaborador.fromRecord(RecordModel({'id': 'c2', 'nome': 'Rui'}));
    expect(sem.temCartao, isFalse);
  });
}
