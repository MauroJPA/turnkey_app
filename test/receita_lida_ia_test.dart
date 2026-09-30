import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/recipes/domain/receita_lida_ia.dart';

void main() {
  test('lê nome, categoria e ingredientes válidos', () {
    final r = ReceitaLidaIa.fromJson({
      'nome': 'Chocolate quente',
      'categoria': 'Recheio',
      'ingredientes': [
        {'nome': 'Açucar Branco', 'quantidade_g': 30},
        {'nome': 'Nata 35%', 'quantidade_g': 200},
      ],
    });
    expect(r.nome, 'Chocolate quente');
    expect(r.categoria, 'Recheio');
    expect(r.ingredientes.length, 2);
    expect(r.ingredientes.first.nome, 'Açucar Branco');
    expect(r.ingredientes.first.quantidadeG, 30);
  });

  test('ingredientes sem nome ou com quantidade <= 0 são descartados', () {
    final r = ReceitaLidaIa.fromJson({
      'ingredientes': [
        {'nome': '', 'quantidade_g': 30},
        {'nome': 'Sal', 'quantidade_g': 0},
        {'nome': 'Ovo', 'quantidade_g': 50},
      ],
    });
    expect(r.ingredientes.length, 1);
    expect(r.ingredientes.single.nome, 'Ovo');
  });

  test('campos em falta (nome/categoria/ingredientes null) não rebentam', () {
    final r = ReceitaLidaIa.fromJson({});
    expect(r.nome, isEmpty);
    expect(r.categoria, isEmpty);
    expect(r.ingredientes, isEmpty);
  });
}
