import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sales_repository.dart';
import '../domain/venda.dart';

/// Vendas dos últimos [dias] (por omissão, 90 — histórico recente para a
/// lista principal; o painel financeiro usa períodos próprios).
final salesListProvider =
    FutureProvider.autoDispose.family<List<Venda>, int>((ref, dias) {
  final ate = DateTime.now();
  final desde = ate.subtract(Duration(days: dias));
  return ref.watch(salesRepositoryProvider).list(desde: desde, ate: ate);
});

final vendaItensProvider =
    FutureProvider.autoDispose.family<List<VendaItem>, String>((ref, id) {
  return ref.watch(salesRepositoryProvider).itensDe(id);
});

final vendaByIdProvider =
    FutureProvider.autoDispose.family<Venda, String>((ref, id) {
  return ref.watch(salesRepositoryProvider).getById(id);
});

final salesActionsProvider = Provider<SalesActions>(SalesActions.new);

class SalesActions {
  SalesActions(this._ref);
  final Ref _ref;

  void _refresh() => _ref.invalidate(salesListProvider);

  Future<Venda> criar({
    required DateTime data,
    required OrigemVenda origem,
    String numeroDocumento = '',
    String notas = '',
    required List<VendaItemInput> linhas,
  }) async {
    final v = await _ref.read(salesRepositoryProvider).criar(
          data: data,
          origem: origem,
          numeroDocumento: numeroDocumento,
          notas: notas,
          linhas: linhas,
        );
    _refresh();
    return v;
  }

  Future<void> remover(String id) async {
    await _ref.read(salesRepositoryProvider).remover(id);
    _refresh();
  }

  Future<
      ({
        int vendasCriadas,
        int duplicadasIgnoradas,
        int itensCriados,
        int itensSemFicha,
      })> sincronizarVendus() async {
    final r = await _ref.read(salesRepositoryProvider).sincronizarVendus();
    _refresh();
    return r;
  }
}
