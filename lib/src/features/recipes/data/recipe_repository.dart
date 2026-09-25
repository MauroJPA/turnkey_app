import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../domain/recipe.dart';

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return RecipeRepository(ref.watch(pbProvider), requireEmpresaId(ref));
});

class RecipeRepository {
  RecipeRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  RecordService get _c => _pb.collection('receitas');
  RecordService get _itens => _pb.collection('itens_receita');

  Future<List<Receita>> list({bool trash = false}) async {
    final recs = await _c.getFullList(
      filter: 'empresa = "$_empresaId" && deletado = $trash',
      sort: 'nome',
    );
    return recs.map(Receita.fromRecord).toList();
  }

  Future<Receita> getById(String id) async =>
      Receita.fromRecord(await _c.getOne(id));

  Future<Receita> create(RecipeInput input) async {
    final rec = await _c.create(
      body: {...input.toBody(), 'empresa': _empresaId, 'deletado': false},
    );
    return Receita.fromRecord(rec);
  }

  Future<Receita> update(String id, RecipeInput input) async =>
      Receita.fromRecord(await _c.update(id, body: input.toBody()));

  /// Anexa ficheiros ao campo `imagens` (multi-ficheiro, mantém os já lá).
  Future<Receita> adicionarImagens(
    String id,
    List<({String nome, List<int> bytes})> novas,
  ) async {
    final files = [
      for (final img in novas)
        http.MultipartFile.fromBytes('imagens', img.bytes, filename: img.nome),
    ];
    return Receita.fromRecord(await _c.update(id, body: {}, files: files));
  }

  /// Remove um ficheiro do campo `imagens` (pelo nome guardado).
  Future<Receita> removerImagem(String id, String nomeFicheiro) async =>
      Receita.fromRecord(
        await _c.update(id, body: {
          'imagens-': [nomeFicheiro],
        }),
      );

  /// URL público de uma imagem da receita (opcionalmente a miniatura 0x160).
  String imagemUrl(String recipeId, String nomeFicheiro, {bool thumb = false}) {
    final base = _pb.baseURL.endsWith('/')
        ? _pb.baseURL.substring(0, _pb.baseURL.length - 1)
        : _pb.baseURL;
    final u = '$base/api/files/receitas/$recipeId/$nomeFicheiro';
    return thumb ? '$u?thumb=0x160' : u;
  }

  Future<void> setPublicar(String id, {required bool valor}) =>
      _c.update(id, body: {'publicar_como_ingrediente': valor});

  Future<void> setProcedimento(String id, String procedimento) =>
      _c.update(id, body: {'procedimento': procedimento.trim()});

  /// % de peso perdido na cozedura (concentra os valores por 100 g de produto).
  Future<void> setPerdaCozedura(String id, double pct) =>
      _c.update(id, body: {'perda_cozedura_pct': pct.clamp(0, 95)});

  Future<void> setDeleted(String id, {required bool deletado}) =>
      _c.update(id, body: {'deletado': deletado});

  Future<void> hardDelete(String id) => _c.delete(id);

  /// Duplica a receita e as suas linhas.
  Future<Receita> duplicate(String id) async {
    final src = await _c.getOne(id);
    final nova = await _c.create(
      body: {
        'empresa': _empresaId,
        'nome': '${src.getStringValue('nome')} (cópia)',
        'categoria': src.getStringValue('categoria'),
        'rendimento_manual': src.getBoolValue('rendimento_manual'),
        'rendimento_esperado': src.getDoubleValue('rendimento_esperado'),
        'publicar_como_ingrediente': false,
        'deletado': false,
      },
    );
    final itens = await _itens.getFullList(filter: 'receita = "$id"');
    for (final it in itens) {
      await _itens.create(
        body: {
          'empresa': _empresaId,
          'receita': nova.id,
          'ingrediente': it.getStringValue('ingrediente'),
          'sub_receita': it.getStringValue('sub_receita'),
          if (it.getStringValue('produto').isNotEmpty)
            'produto': it.getStringValue('produto'),
          'quantidade_g': it.getDoubleValue('quantidade_g'),
          'nome_provisorio': it.getStringValue('nome_provisorio'),
        },
      );
    }
    return Receita.fromRecord(nova);
  }
}
