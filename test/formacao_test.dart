import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/people/domain/formacao.dart';

void main() {
  final hoje = DateTime(2026, 10, 6);

  Formacao f(
    String id, {
    String pessoa = 'c:ana',
    String nome = 'Ana',
    String titulo = 'HACCP',
    DateTime? validade,
    DateTime? realizada,
  }) => Formacao(
    id: id,
    pessoa: pessoa,
    nome: nome,
    titulo: titulo,
    tipo: TipoFormacao.certificado,
    validade: validade,
    realizada: realizada,
  );

  test('estado e dias até caducar', () {
    expect(f('1').estado(hoje), EstadoValidade.semValidade);
    expect(f('1').diasParaCaducar(hoje), isNull);
    expect(f('1').quando(hoje), 'não caduca');

    final a = f('2', validade: DateTime(2026, 10, 16));
    expect(a.diasParaCaducar(hoje), 10);
    expect(a.estado(hoje), EstadoValidade.aCaducar);
    expect(a.quando(hoje), 'caduca em 10 dias');

    expect(f('3', validade: DateTime(2026, 10, 6)).quando(hoje), 'caduca hoje');
    expect(
      f('3', validade: DateTime(2026, 10, 6)).estado(hoje),
      EstadoValidade.aCaducar,
    );
    expect(
      f('4', validade: DateTime(2026, 10, 7)).quando(hoje),
      'caduca amanhã',
    );
    expect(
      f('5', validade: DateTime(2026, 10, 5)).estado(hoje),
      EstadoValidade.caducada,
    );
    expect(
      f('5', validade: DateTime(2026, 10, 5)).quando(hoje),
      'caducou ontem',
    );
    expect(
      f('6', validade: DateTime(2026, 9, 26)).quando(hoje),
      'caducou há 10 dias',
    );
    // 30 dias ainda é "a caducar"; 31 já é válida
    expect(
      f('7', validade: DateTime(2026, 11, 5)).estado(hoje),
      EstadoValidade.aCaducar,
    );
    expect(
      f('8', validade: DateTime(2026, 11, 6)).estado(hoje),
      EstadoValidade.valida,
    );
  });

  test('a hora do dia não muda a conta dos dias', () {
    final tarde = DateTime(2026, 10, 6, 23, 59);
    expect(f('1', validade: DateTime(2026, 10, 7)).diasParaCaducar(tarde), 1);
  });

  test('uma renovação substitui o certificado antigo', () {
    final antigo = f('antigo', validade: DateTime(2026, 9, 1));
    final novo = f('novo', validade: DateTime(2029, 9, 1));
    final v = vigentes([antigo, novo]);
    expect(v.map((x) => x.id), ['novo']);
    expect(formacoesEmAlerta([antigo, novo], hoje), isEmpty);
  });

  test('o título compara-se sem maiúsculas e a pessoa conta', () {
    final a = f('a', titulo: 'HACCP', validade: DateTime(2026, 9, 1));
    final b = f('b', titulo: ' haccp ', validade: DateTime(2028, 1, 1));
    final outra = f(
      'c',
      pessoa: 'c:rui',
      nome: 'Rui',
      titulo: 'HACCP',
      validade: DateTime(2026, 9, 1),
    );
    final v = vigentes([a, b, outra]).map((x) => x.id).toSet();
    expect(v, {'b', 'c'});
  });

  test('o que não caduca ganha ao que tem validade', () {
    final comValidade = f('v', validade: DateTime(2026, 9, 1));
    final semValidade = f('s');
    expect(vigentes([comValidade, semValidade]).single.id, 's');
    expect(vigentes([semValidade, comValidade]).single.id, 's');
  });

  test('sem validade, fica a mais recente', () {
    final a = f('a', realizada: DateTime(2020, 1, 1));
    final b = f('b', realizada: DateTime(2024, 1, 1));
    expect(vigentes([a, b]).single.id, 'b');
    expect(vigentes([b, a]).single.id, 'b');
  });

  test('alertas: caducadas e a caducar, as mais urgentes primeiro', () {
    final r = formacoesEmAlerta([
      f('longe', titulo: 'A', validade: DateTime(2027, 1, 1)),
      f('em10', titulo: 'B', validade: DateTime(2026, 10, 16)),
      f('caducada', titulo: 'C', validade: DateTime(2026, 9, 20)),
      f('sem', titulo: 'D'),
      f('em3', titulo: 'E', validade: DateTime(2026, 10, 9)),
    ], hoje);
    expect(r.map((x) => x.id), ['caducada', 'em3', 'em10']);
  });
}
