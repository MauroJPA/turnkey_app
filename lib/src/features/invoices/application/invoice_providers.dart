import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../consumables/application/consumivel_providers.dart';
import '../../ingredients/application/ingredients_providers.dart';
import '../../packaging/application/embalagem_providers.dart';
import '../data/invoice_repository.dart';
import '../domain/fatura.dart';

final faturasListProvider = FutureProvider.autoDispose<List<Fatura>>((ref) {
  return ref.watch(invoiceRepositoryProvider).list();
});

final faturaProvider = FutureProvider.autoDispose.family<Fatura, String>((
  ref,
  id,
) {
  return ref.watch(invoiceRepositoryProvider).getById(id);
});

/// Faturas apagadas (só o proprietário as vê e restaura).
final faturasApagadasProvider = FutureProvider.autoDispose<List<Fatura>>((ref) {
  return ref.watch(invoiceRepositoryProvider).listApagadas();
});

/// O que já foi decidido nesta fatura (rondas anteriores de "Aplicar"), por
/// índice de linha — para a revisão não repetir o que já está feito.
final itensFaturaProvider = FutureProvider.autoDispose
    .family<List<ItemFaturaAnterior>, String>((ref, faturaId) {
      return ref.watch(invoiceRepositoryProvider).itensAnteriores(faturaId);
    });

final invoiceActionsProvider = Provider<InvoiceActions>(InvoiceActions.new);

class InvoiceActions {
  InvoiceActions(this._ref);
  final Ref _ref;

  InvoiceRepository get _repo => _ref.read(invoiceRepositoryProvider);

  Future<ResultadoAplicar> aplicar(
    String id,
    List<LinhaAAplicar> linhas,
  ) async {
    final r = await _repo.aplicar(id, linhas);
    _ref.invalidate(faturaProvider(id));
    _ref.invalidate(faturasListProvider);
    _ref.invalidate(ingredientsListProvider);
    _ref.invalidate(itensFaturaProvider(id));
    return r;
  }

  Future<void> apagar(String id) async {
    await _repo.apagar(id);
    _ref.invalidate(faturasListProvider);
    _ref.invalidate(faturasApagadasProvider);
  }

  Future<void> restaurar(String id) async {
    await _repo.restaurar(id);
    _ref.invalidate(faturasListProvider);
    _ref.invalidate(faturasApagadasProvider);
  }

  Future<void> editar(
    String id, {
    required String fornecedor,
    required String numero,
    DateTime? data,
    double? total,
  }) async {
    await _repo.editar(
      id,
      fornecedor: fornecedor,
      numero: numero,
      data: data,
      total: total,
    );
    _ref.invalidate(faturaProvider(id));
    _ref.invalidate(faturasListProvider);
  }

  Future<int> limparInvalidas() async {
    final n = await _repo.limparInvalidas();
    _ref.invalidate(faturasListProvider);
    _ref.invalidate(faturasApagadasProvider);
    return n;
  }

  /// Corrige marca/fornecedor de uma linha já aplicada (proprietário/admin).
  Future<({String marca, String fornecedor})> corrigirItem(
    String faturaId,
    int index, {
    String? marca,
    String? fornecedor,
  }) async {
    final r = await _repo.corrigirItem(
      faturaId,
      index,
      marca: marca,
      fornecedor: fornecedor,
    );
    _ref.invalidate(itensFaturaProvider(faturaId));
    _ref.invalidate(ingredientsListProvider);
    _ref.invalidate(consumiveisListProvider);
    _ref.invalidate(embalagensListProvider);
    return r;
  }
}
