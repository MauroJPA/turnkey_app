import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/colaboradores_repository.dart';
import '../domain/colaborador.dart';

/// Os colaboradores ativos (o quiosque escolhe daqui).
final colaboradoresProvider = FutureProvider.autoDispose<List<Colaborador>>(
  (ref) => ref.watch(colaboradoresRepositoryProvider).list(),
);

/// Todos, também os arquivados (para a gestão).
final todosColaboradoresProvider =
    FutureProvider.autoDispose<List<Colaborador>>(
      (ref) => ref
          .watch(colaboradoresRepositoryProvider)
          .list(incluirArquivados: true),
    );

final colaboradoresActionsProvider = Provider<ColaboradoresActions>(
  ColaboradoresActions.new,
);

class ColaboradoresActions {
  ColaboradoresActions(this._ref);
  final Ref _ref;

  ColaboradoresRepository get _repo =>
      _ref.read(colaboradoresRepositoryProvider);

  void _refresh() {
    _ref.invalidate(colaboradoresProvider);
    _ref.invalidate(todosColaboradoresProvider);
  }

  Future<void> criar(String nome) async {
    await _repo.criar(nome);
    _refresh();
  }

  Future<void> renomear(String id, String nome) async {
    await _repo.renomear(id, nome);
    _refresh();
  }

  Future<void> definirCartao(String id, String uid) async {
    await _repo.definirCartao(id, uid);
    _refresh();
  }

  Future<void> arquivar(String id, {required bool arquivado}) async {
    await _repo.arquivar(id, arquivado: arquivado);
    _refresh();
  }
}
