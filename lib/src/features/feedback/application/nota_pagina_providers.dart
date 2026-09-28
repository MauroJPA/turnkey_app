import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/nota_pagina_repository.dart';
import '../domain/nota_pagina.dart';

/// Notas de equipa de uma página (chave = `HelpTopic.name`).
final notasPaginaProvider = FutureProvider.autoDispose
    .family<List<NotaPagina>, String>((ref, pagina) {
      return ref.watch(notaPaginaRepositoryProvider).listarPorPagina(pagina);
    });

/// Quantas notas por resolver tem uma página — para o selo no ícone.
final notasPorResolverProvider = FutureProvider.autoDispose.family<int, String>(
  (ref, pagina) async {
    final notas = await ref.watch(notasPaginaProvider(pagina).future);
    return notas.where((n) => !n.resolvida).length;
  },
);

final notaPaginaActionsProvider = Provider<NotaPaginaActions>(
  NotaPaginaActions.new,
);

class NotaPaginaActions {
  NotaPaginaActions(this._ref);
  final Ref _ref;

  Future<void> criar({required String pagina, required String texto}) async {
    await _ref
        .read(notaPaginaRepositoryProvider)
        .criar(pagina: pagina, texto: texto);
    _ref.invalidate(notasPaginaProvider(pagina));
    _ref.invalidate(notasPorResolverProvider(pagina));
  }

  Future<void> marcarResolvida(String pagina, String id, bool resolvida) async {
    await _ref
        .read(notaPaginaRepositoryProvider)
        .marcarResolvida(id, resolvida);
    _ref.invalidate(notasPaginaProvider(pagina));
    _ref.invalidate(notasPorResolverProvider(pagina));
  }

  Future<void> apagar(String pagina, String id) async {
    await _ref.read(notaPaginaRepositoryProvider).apagar(id);
    _ref.invalidate(notasPaginaProvider(pagina));
    _ref.invalidate(notasPorResolverProvider(pagina));
  }
}
