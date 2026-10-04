import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/application/settings_providers.dart';
import '../data/colaboradores_repository.dart';
import '../domain/colaborador.dart';

/// Todas as pessoas do quiosque: a **Equipa** (as contas da empresa) mais
/// quem não tem conta, com os cartões — também as escondidas (para a gestão).
final todosColaboradoresProvider =
    FutureProvider.autoDispose<List<Colaborador>>((ref) async {
      final linhas = await ref.watch(colaboradoresRepositoryProvider).linhas();
      final equipa = await ref.watch(teamMembersProvider.future);
      return juntarEquipa(
        linhas: linhas,
        equipa: [for (final m in equipa) (id: m.id, nome: m.nome)],
      );
    });

/// As pessoas que aparecem no quiosque (as não escondidas).
final colaboradoresProvider = FutureProvider.autoDispose<List<Colaborador>>(
  (ref) async => [
    for (final c in await ref.watch(todosColaboradoresProvider.future))
      if (c.ativo) c,
  ],
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

  Future<void> renomear(Colaborador c, String nome) async {
    await _repo.renomear(c.id, nome);
    _refresh();
  }

  Future<void> definirCartao(Colaborador c, String uid) async {
    await _repo.definirCartao(c, uid);
    _refresh();
  }

  Future<void> arquivar(Colaborador c, {required bool arquivado}) async {
    await _repo.arquivar(c, arquivado: arquivado);
    _refresh();
  }
}
