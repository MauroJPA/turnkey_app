import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/categoria_receita_repository.dart';
import '../domain/categoria_receita.dart';

/// Todas as categorias da empresa (ativas e inativas), ordenadas.
final categoriasReceitaProvider =
    FutureProvider.autoDispose<List<CategoriaReceita>>((ref) {
      return ref.watch(categoriaReceitaRepositoryProvider).list();
    });

/// Só as ativas — para o seletor ao criar/editar uma receita.
final categoriasReceitaAtivasProvider =
    FutureProvider.autoDispose<List<CategoriaReceita>>((ref) {
      return ref
          .watch(categoriaReceitaRepositoryProvider)
          .list(apenasAtivas: true);
    });

final categoriaReceitaActionsProvider = Provider<CategoriaReceitaActions>(
  CategoriaReceitaActions.new,
);

class CategoriaReceitaActions {
  CategoriaReceitaActions(this._ref);
  final Ref _ref;

  CategoriaReceitaRepository get _repo =>
      _ref.read(categoriaReceitaRepositoryProvider);

  void _refresh() {
    _ref.invalidate(categoriasReceitaProvider);
    _ref.invalidate(categoriasReceitaAtivasProvider);
  }

  Future<void> criar(CategoriaReceitaInput input) async {
    await _repo.create(input);
    _refresh();
  }

  Future<void> editar(String id, CategoriaReceitaInput input) async {
    await _repo.update(id, input);
    _refresh();
  }

  Future<void> apagar(String id) async {
    await _repo.delete(id);
    _refresh();
  }
}
