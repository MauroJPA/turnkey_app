import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cookie_format_repository.dart';
import '../domain/cookie_format.dart';

/// Todos os formatos da empresa (ativos e inativos), ordenados.
final formatosProvider =
    FutureProvider.autoDispose<List<FormatoCookie>>((ref) {
  return ref.watch(cookieFormatRepositoryProvider).list();
});

/// Só os formatos ativos — para os seletores da agenda/produção.
final formatosAtivosProvider =
    FutureProvider.autoDispose<List<FormatoCookie>>((ref) {
  return ref.watch(cookieFormatRepositoryProvider).list(apenasAtivos: true);
});

final cookieFormatActionsProvider =
    Provider<CookieFormatActions>(CookieFormatActions.new);

class CookieFormatActions {
  CookieFormatActions(this._ref);
  final Ref _ref;

  CookieFormatRepository get _repo =>
      _ref.read(cookieFormatRepositoryProvider);

  void _refresh() {
    _ref.invalidate(formatosProvider);
    _ref.invalidate(formatosAtivosProvider);
  }

  Future<void> criar(FormatoInput input) async {
    await _repo.create(input);
    _refresh();
  }

  Future<void> editar(String id, FormatoInput input) async {
    await _repo.update(id, input);
    _refresh();
  }

  Future<void> apagar(String id) async {
    await _repo.delete(id);
    _refresh();
  }
}
