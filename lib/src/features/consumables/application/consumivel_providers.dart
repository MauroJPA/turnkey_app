import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/consumivel_repository.dart';
import '../domain/consumivel.dart';

final consumiveisListProvider = FutureProvider.autoDispose<List<Consumivel>>((
  ref,
) {
  return ref.watch(consumivelRepositoryProvider).list();
});

/// Todos os documentos da empresa (agrupam-se por consumível).
final consumivelDocumentosProvider =
    FutureProvider.autoDispose<List<DocumentoConsumivel>>((ref) {
      return ref.watch(consumivelRepositoryProvider).listDocumentos();
    });

final documentosDoConsumivelProvider = Provider.autoDispose
    .family<List<DocumentoConsumivel>, String>((ref, consumivelId) {
      final todos =
          ref.watch(consumivelDocumentosProvider).valueOrNull ?? const [];
      return [
        for (final d in todos)
          if (d.consumivelId == consumivelId) d,
      ];
    });

final consumivelActionsProvider = Provider<ConsumivelActions>(
  ConsumivelActions.new,
);

class ConsumivelActions {
  ConsumivelActions(this._ref);
  final Ref _ref;

  ConsumivelRepository get _repo => _ref.read(consumivelRepositoryProvider);

  void _refresh() {
    _ref.invalidate(consumiveisListProvider);
    _ref.invalidate(consumivelDocumentosProvider);
  }

  Future<Consumivel> criar(ConsumivelInput input) async {
    final c = await _repo.create(input);
    _refresh();
    return c;
  }

  Future<void> atualizar(
    String id,
    ConsumivelInput input, {
    bool precoMudou = false,
  }) async {
    await _repo.update(id, input, precoMudou: precoMudou);
    _refresh();
  }

  Future<void> apagar(String id) async {
    await _repo.setDeleted(id, deletado: true);
    _refresh();
  }

  Future<void> anexar({
    required String consumivelId,
    required TipoDocumento tipo,
    required List<int> bytes,
    required String nomeFicheiro,
    String titulo = '',
    String versao = '',
    DateTime? dataDocumento,
  }) async {
    await _repo.anexar(
      consumivelId: consumivelId,
      tipo: tipo,
      bytes: bytes,
      nomeFicheiro: nomeFicheiro,
      titulo: titulo,
      versao: versao,
      dataDocumento: dataDocumento,
    );
    _refresh();
  }

  Future<void> apagarDocumento(String id) async {
    await _repo.apagarDocumento(id);
    _refresh();
  }

  Future<String> urlDocumento(DocumentoConsumivel d) => _repo.urlDocumento(d);
}
