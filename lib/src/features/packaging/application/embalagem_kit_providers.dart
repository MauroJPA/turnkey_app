import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/embalagem_kit_repository.dart';
import '../domain/embalagem_kit.dart';
import 'embalagem_providers.dart';

final embalagemKitsListProvider =
    FutureProvider.autoDispose<List<EmbalagemKit>>((ref) {
  return ref.watch(embalagemKitRepositoryProvider).list();
});

class KitDetalhe {
  KitDetalhe({required this.kit, required this.itens});
  final EmbalagemKit kit;
  final List<EmbalagemKitItem> itens;

  double get custoSoma => itens.fold(0, (s, i) => s + i.custoLinha);
}

final embalagemKitDetailProvider =
    FutureProvider.autoDispose.family<KitDetalhe, String>((ref, id) async {
  final repo = ref.watch(embalagemKitRepositoryProvider);
  final kits = await repo.list();
  final kit = kits.firstWhere(
    (k) => k.id == id,
    orElse: () => EmbalagemKit(id: id, nome: '—'),
  );
  final itens = await repo.itens(id);
  return KitDetalhe(kit: kit, itens: itens);
});

final embalagemKitActionsProvider =
    Provider<EmbalagemKitActions>(EmbalagemKitActions.new);

class EmbalagemKitActions {
  EmbalagemKitActions(this._ref);
  final Ref _ref;

  EmbalagemKitRepository get _repo =>
      _ref.read(embalagemKitRepositoryProvider);

  void _refresh([String? id]) {
    _ref.invalidate(embalagemKitsListProvider);
    if (id != null) _ref.invalidate(embalagemKitDetailProvider(id));
    // o custo do kit muda o custo das fichas -> deixa a UI de embalagens
    // coerente também.
    _ref.invalidate(embalagensListProvider);
  }

  Future<EmbalagemKit> criar(EmbalagemKitInput input) async {
    final k = await _repo.create(input);
    _refresh();
    return k;
  }

  Future<void> atualizar(String id, EmbalagemKitInput input) async {
    await _repo.update(id, input);
    _refresh(id);
  }

  Future<void> apagar(String id) async {
    await _repo.setDeleted(id, deletado: true);
    _refresh();
  }

  Future<void> adicionarItem(
    String kitId,
    String embalagemId,
    double quantidade,
  ) async {
    await _repo.addItem(kitId, embalagemId, quantidade);
    _refresh(kitId);
  }

  Future<void> definirQuantidade(
    String kitId,
    String itemId,
    double quantidade,
  ) async {
    await _repo.setItemQuantidade(itemId, quantidade);
    _refresh(kitId);
  }

  Future<void> removerItem(String kitId, String itemId) async {
    await _repo.removeItem(itemId);
    _refresh(kitId);
  }
}
