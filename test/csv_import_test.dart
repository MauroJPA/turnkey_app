import 'package:flutter_test/flutter_test.dart';
import 'package:turnkey_app/src/features/import_csv/application/ingredient_import_service.dart';
import 'package:turnkey_app/src/features/ingredients/data/ingredient_repository.dart';
import 'package:turnkey_app/src/features/ingredients/domain/ingredient.dart';

class _FakeRepo implements IngredientWriter {
  final Map<String, Ingrediente> byName = {};
  int creates = 0;
  int updates = 0;

  @override
  Future<Ingrediente?> findByName(String nome) async => byName[nome];

  @override
  Future<Ingrediente> create(IngredienteInput input) async {
    creates++;
    final i = Ingrediente(
      id: 'id${byName.length}',
      nome: input.nome,
      preco: input.preco,
      gramasEmbalagem: input.gramasEmbalagem,
    );
    byName[i.nome] = i;
    return i;
  }

  @override
  Future<Ingrediente> update(String id, IngredienteInput input) async {
    updates++;
    final i = Ingrediente(
      id: id,
      nome: input.nome,
      preco: input.preco,
      gramasEmbalagem: input.gramasEmbalagem,
    );
    byName[i.nome] = i;
    return i;
  }
}

void main() {
  test('importa, ignora cabeçalho e tolera € e vírgula decimal', () async {
    final repo = _FakeRepo();
    final svc = IngredientImportService(repo);

    const csv = '''
nome,caracteristica,marca,fornecedor,preco,gramas
Farinha T65,Farinha,Nacional,Makro,"€12,50",25000
Açúcar,Branco,Sidul,Makro,0.99,1000
''';

    final res = await svc.importCsv(csv);

    expect(res.criados, 2);
    expect(res.atualizados, 0);
    expect(res.semErros, isTrue);
    expect(repo.byName['Farinha T65']!.preco, 12.5);
    expect(repo.byName['Farinha T65']!.custoPorGrama, closeTo(0.0005, 1e-9));
  });

  test('atualiza quando o nome já existe e reporta linhas inválidas', () async {
    final repo = _FakeRepo();
    repo.byName['Sal'] = const Ingrediente(id: 'x', nome: 'Sal');
    final svc = IngredientImportService(repo);

    const csv = 'Sal,,,,1.20,500\n'
        'Pimenta,,,,abc,50\n'
        ',,,,1,1\n';

    final res = await svc.importCsv(csv);

    expect(res.atualizados, 1);
    expect(res.criados, 0);
    expect(res.erros.length, 1);
    expect(res.erros.single, contains('Pimenta'));
  });
}
