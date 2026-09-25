import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../domain/produto_ingrediente.dart';

final ingredientProductRepositoryProvider =
    Provider<IngredientProductRepository>((ref) {
      return IngredientProductRepository(
        ref.watch(pbProvider),
        requireEmpresaId(ref),
      );
    });

/// Todos os produtos de compra da empresa (agrupam-se por ingrediente).
final produtosIngredienteProvider =
    FutureProvider.autoDispose<List<ProdutoIngrediente>>((ref) {
      return ref.watch(ingredientProductRepositoryProvider).list();
    });

/// Os produtos de um ingrediente genérico.
final produtosDoIngredienteProvider = Provider.autoDispose
    .family<List<ProdutoIngrediente>, String>((ref, ingredienteId) {
      final todos =
          ref.watch(produtosIngredienteProvider).valueOrNull ?? const [];
      return [
        for (final p in todos)
          if (p.ingredienteId == ingredienteId) p,
      ];
    });

class IngredientProductRepository {
  IngredientProductRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  RecordService get _c => _pb.collection('ingrediente_produtos');

  Future<List<ProdutoIngrediente>> list() async {
    final recs = await _c.getFullList(
      filter: 'empresa = "$_empresaId"',
      sort: '-preco_atualizado_em',
    );
    return recs.map(ProdutoIngrediente.fromRecord).toList();
  }

  Future<List<ProdutoIngrediente>> doIngrediente(String ingredienteId) async {
    final recs = await _c.getFullList(
      filter: 'empresa = "$_empresaId" && ingrediente = "$ingredienteId"',
      sort: '-preco_atualizado_em',
    );
    return recs.map(ProdutoIngrediente.fromRecord).toList();
  }

  Map<String, dynamic> _corpo({
    required String nome,
    required String marca,
    required String fornecedor,
    required double embalagemG,
    required double preco,
    DateTime? data,
    List<String>? alergenios,
    List<String>? alergeniosTracos,
    NutriProduto? nutri,
  }) => {
    'nome': nome.trim(),
    'marca': marca.trim(),
    'fornecedor': fornecedor.trim(),
    'embalagem_g': embalagemG,
    'preco': preco,
    if (data != null) 'preco_atualizado_em': _dia(data),
    if (alergenios != null) 'alergenios': alergenios,
    if (alergeniosTracos != null) 'alergenios_tracos': alergeniosTracos,
    if (nutri != null) ...nutri.toCampos(),
  };

  static String _dia(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} 00:00:00.000Z';

  Future<ProdutoIngrediente> criar({
    required String ingredienteId,
    required String nome,
    String marca = '',
    String fornecedor = '',
    required double embalagemG,
    required double preco,
    DateTime? data,
    List<String> alergenios = const [],
    List<String> alergeniosTracos = const [],
    NutriProduto? nutri,
  }) async {
    final rec = await _c.create(
      body: {
        ..._corpo(
          nome: nome,
          marca: marca,
          fornecedor: fornecedor,
          embalagemG: embalagemG,
          preco: preco,
          data: data ?? DateTime.now(),
          alergenios: alergenios,
          alergeniosTracos: alergeniosTracos,
          nutri: nutri,
        ),
        'empresa': _empresaId,
        'ingrediente': ingredienteId,
      },
    );
    return ProdutoIngrediente.fromRecord(rec);
  }

  Future<ProdutoIngrediente> atualizar(
    String id, {
    required String nome,
    String marca = '',
    String fornecedor = '',
    required double embalagemG,
    required double preco,
    DateTime? data,
    List<String>? alergenios,
    List<String>? alergeniosTracos,
    NutriProduto? nutri,
  }) async {
    final rec = await _c.update(
      id,
      body: _corpo(
        nome: nome,
        marca: marca,
        fornecedor: fornecedor,
        embalagemG: embalagemG,
        preco: preco,
        data: data,
        alergenios: alergenios,
        alergeniosTracos: alergeniosTracos,
        nutri: nutri,
      ),
    );
    return ProdutoIngrediente.fromRecord(rec);
  }

  Future<void> apagar(String id) => _c.delete(id);
}
