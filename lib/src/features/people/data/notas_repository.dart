import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../domain/nota.dart';

final notasRepositoryProvider = Provider<NotasRepository>((ref) {
  return NotasRepository(ref.watch(pbProvider), requireEmpresaId(ref));
});

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Anotações da equipa (`anotacoes`).
class NotasRepository {
  NotasRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  RecordService get _c => _pb.collection('anotacoes');

  String? get utilizadorId => _pb.authStore.record?.id;

  static Nota desdeRecord(RecordModel r) {
    final l = r.getStringValue('lembrar_em');
    DateTime? lembrar;
    if (l.length >= 10) {
      final p = l.substring(0, 10).split('-');
      if (p.length == 3) {
        lembrar = DateTime(
          int.tryParse(p[0]) ?? 2000,
          int.tryParse(p[1]) ?? 1,
          int.tryParse(p[2]) ?? 1,
        );
      }
    }
    return Nota(
      id: r.id,
      titulo: r.getStringValue('titulo'),
      texto: r.getStringValue('texto'),
      categoria: CategoriaNota.fromApi(r.getStringValue('categoria')),
      fixada: r.getBoolValue('fixada'),
      arquivada: r.getBoolValue('arquivada'),
      lembrarEm: lembrar,
      autorId: r.getStringValue('autor'),
      autorNome: r.getStringValue('autor_nome'),
      criada:
          DateTime.tryParse(r.getStringValue('created'))?.toLocal() ??
          DateTime.now(),
    );
  }

  Future<List<Nota>> listar({required bool arquivadas}) async {
    final recs = await _c.getFullList(
      filter:
          'empresa = "$_empresaId" && arquivada = ${arquivadas ? 'true' : 'false'}',
      sort: '-created',
    );
    return recs.map(desdeRecord).toList();
  }

  Future<void> criar({
    String titulo = '',
    required String texto,
    required CategoriaNota categoria,
    required String autorNome,
    bool fixada = false,
    DateTime? lembrarEm,
  }) => _c.create(
    body: {
      'empresa': _empresaId,
      'titulo': titulo.trim(),
      'texto': texto.trim(),
      'categoria': categoria.api,
      'fixada': fixada,
      'arquivada': false,
      if (lembrarEm != null) 'lembrar_em': '${_ymd(lembrarEm)} 00:00:00.000Z',
      'autor': utilizadorId,
      'autor_nome': autorNome,
    },
  );

  Future<void> editar(
    String id, {
    String titulo = '',
    required String texto,
    required CategoriaNota categoria,
    DateTime? lembrarEm,
  }) => _c.update(
    id,
    body: {
      'titulo': titulo.trim(),
      'texto': texto.trim(),
      'categoria': categoria.api,
      'lembrar_em': lembrarEm == null ? '' : '${_ymd(lembrarEm)} 00:00:00.000Z',
    },
  );

  Future<void> fixar(String id, {required bool fixada}) =>
      _c.update(id, body: {'fixada': fixada});

  Future<void> arquivar(String id, {required bool arquivada}) =>
      _c.update(id, body: {'arquivada': arquivada});

  Future<void> apagar(String id) => _c.delete(id);
}
