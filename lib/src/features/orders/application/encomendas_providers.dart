import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/encomendas_repository.dart';
import '../domain/encomenda.dart';

final encomendasListProvider =
    FutureProvider.autoDispose.family<List<Encomenda>, bool>(
  (ref, incluirConcluidas) => ref
      .watch(encomendasRepositoryProvider)
      .list(incluirConcluidas: incluirConcluidas),
);

final encomendaByIdProvider =
    FutureProvider.autoDispose.family<Encomenda, String>(
  (ref, id) => ref.watch(encomendasRepositoryProvider).getById(id),
);

final encomendaItensProvider =
    FutureProvider.autoDispose.family<List<EncomendaItem>, String>(
  (ref, id) => ref.watch(encomendasRepositoryProvider).itensDe(id),
);

final encomendasActionsProvider =
    Provider<EncomendasActions>(EncomendasActions.new);

class EncomendasActions {
  EncomendasActions(this._ref);
  final Ref _ref;

  void _refresh() => _ref.invalidate(encomendasListProvider);

  Future<Encomenda> criar(EncomendaInput input) async {
    final e = await _ref.read(encomendasRepositoryProvider).criar(input);
    _refresh();
    return e;
  }

  Future<void> atualizar(String id, EncomendaInput input) async {
    await _ref.read(encomendasRepositoryProvider).atualizar(id, input);
    _refresh();
    _ref.invalidate(encomendaByIdProvider(id));
    _ref.invalidate(encomendaItensProvider(id));
  }

  Future<void> atualizarEstado(String id, EstadoEncomenda estado) async {
    await _ref.read(encomendasRepositoryProvider).atualizarEstado(id, estado);
    _refresh();
    _ref.invalidate(encomendaByIdProvider(id));
  }

  Future<void> remover(String id) async {
    await _ref.read(encomendasRepositoryProvider).remover(id);
    _refresh();
  }
}
