import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ingredients/application/ingredients_providers.dart';
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

final invoiceActionsProvider = Provider<InvoiceActions>(InvoiceActions.new);

class InvoiceActions {
  InvoiceActions(this._ref);
  final Ref _ref;

  InvoiceRepository get _repo => _ref.read(invoiceRepositoryProvider);

  Future<({int precos, int precosIgnorados, int movimentos})> aplicar(
    String id,
    List<LinhaAAplicar> linhas,
  ) async {
    final r = await _repo.aplicar(id, linhas);
    _ref.invalidate(faturaProvider(id));
    _ref.invalidate(faturasListProvider);
    _ref.invalidate(ingredientsListProvider);
    return r;
  }

  Future<void> apagar(String id) async {
    await _repo.apagar(id);
    _ref.invalidate(faturasListProvider);
  }

  Future<int> limparInvalidas() async {
    final n = await _repo.limparInvalidas();
    _ref.invalidate(faturasListProvider);
    return n;
  }
}
