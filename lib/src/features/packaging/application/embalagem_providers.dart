import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/embalagem_repository.dart';
import '../domain/embalagem.dart';

final embalagensListProvider =
    FutureProvider.autoDispose<List<Embalagem>>((ref) {
  return ref.watch(embalagemRepositoryProvider).list();
});

final embalagemActionsProvider =
    Provider<EmbalagemActions>(EmbalagemActions.new);

class EmbalagemActions {
  EmbalagemActions(this._ref);
  final Ref _ref;

  EmbalagemRepository get _repo => _ref.read(embalagemRepositoryProvider);

  void _refresh() => _ref.invalidate(embalagensListProvider);

  Future<Embalagem> criar(EmbalagemInput input) async {
    final e = await _repo.create(input);
    _refresh();
    return e;
  }

  Future<void> atualizar(String id, EmbalagemInput input) async {
    await _repo.update(id, input);
    _refresh();
  }

  Future<void> apagar(String id) async {
    await _repo.setDeleted(id, deletado: true);
    _refresh();
  }
}
