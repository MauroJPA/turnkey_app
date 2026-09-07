import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../domain/ingredient.dart';

final ingredientRepositoryProvider = Provider<IngredientRepository>((ref) {
  return IngredientRepository(
    ref.watch(pbProvider),
    requireEmpresaId(ref),
  );
});

/// Subconjunto de escrita usado pelo import de CSV (facilita testar).
abstract interface class IngredientWriter {
  Future<Ingrediente?> findByName(String nome);
  Future<Ingrediente> create(IngredienteInput input);
  Future<Ingrediente> update(String id, IngredienteInput input);
}

class IngredientRepository implements IngredientWriter {
  IngredientRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  RecordService get _c => _pb.collection('ingredientes');

  Future<List<Ingrediente>> list({bool trash = false}) async {
    final recs = await _c.getFullList(
      filter: 'empresa = "$_empresaId" && deletado = $trash',
      sort: 'nome',
    );
    return recs.map(Ingrediente.fromRecord).toList();
  }

  Future<Ingrediente> getById(String id) async =>
      Ingrediente.fromRecord(await _c.getOne(id));

  @override
  Future<Ingrediente> create(IngredienteInput input) async {
    final rec = await _c.create(
      body: {...input.toBody(), 'empresa': _empresaId, 'deletado': false},
    );
    return Ingrediente.fromRecord(rec);
  }

  @override
  Future<Ingrediente> update(String id, IngredienteInput input) async {
    final rec = await _c.update(id, body: input.toBody());
    return Ingrediente.fromRecord(rec);
  }

  Future<Ingrediente> duplicate(Ingrediente src) =>
      create(IngredienteInput.fromModel(src, nome: '${src.nome} (cópia)'));

  Future<void> setDeleted(String id, {required bool deletado}) =>
      _c.update(id, body: {'deletado': deletado});

  Future<void> hardDelete(String id) => _c.delete(id);

  /// Procura pelo nome exato (para o import de CSV decidir criar vs. atualizar).
  @override
  Future<Ingrediente?> findByName(String nome) async {
    final safe = nome.replaceAll('"', '');
    final res = await _c.getList(
      page: 1,
      perPage: 1,
      filter: 'empresa = "$_empresaId" && nome = "$safe"',
    );
    return res.items.isEmpty
        ? null
        : Ingrediente.fromRecord(res.items.first);
  }
}
