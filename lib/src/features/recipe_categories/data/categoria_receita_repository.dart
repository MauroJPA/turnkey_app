import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../domain/categoria_receita.dart';

final categoriaReceitaRepositoryProvider = Provider<CategoriaReceitaRepository>(
  (ref) {
    return CategoriaReceitaRepository(
      ref.watch(pbProvider),
      requireEmpresaId(ref),
    );
  },
);

class CategoriaReceitaRepository {
  CategoriaReceitaRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  RecordService get _c => _pb.collection('categorias_receita');

  Future<List<CategoriaReceita>> list({bool apenasAtivas = false}) async {
    final recs = await _c.getFullList(
      filter: apenasAtivas
          ? 'empresa = "$_empresaId" && ativo = true'
          : 'empresa = "$_empresaId"',
      sort: 'ordem,nome',
    );
    return recs.map(CategoriaReceita.fromRecord).toList();
  }

  Future<CategoriaReceita> create(CategoriaReceitaInput input) async {
    final r = await _c.create(body: {...input.toBody(), 'empresa': _empresaId});
    return CategoriaReceita.fromRecord(r);
  }

  Future<CategoriaReceita> update(
    String id,
    CategoriaReceitaInput input,
  ) async =>
      CategoriaReceita.fromRecord(await _c.update(id, body: input.toBody()));

  Future<void> delete(String id) => _c.delete(id);
}
