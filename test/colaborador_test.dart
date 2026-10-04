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
