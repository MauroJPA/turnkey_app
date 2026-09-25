import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../domain/consumivel.dart';

final consumivelRepositoryProvider = Provider<ConsumivelRepository>((ref) {
  return ConsumivelRepository(ref.watch(pbProvider), requireEmpresaId(ref));
});

class ConsumivelRepository {
  ConsumivelRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  RecordService get _c => _pb.collection('consumiveis');
  RecordService get _docs => _pb.collection('consumivel_documentos');

  Future<List<Consumivel>> list() async {
    final recs = await _c.getFullList(
      filter: 'empresa = "$_empresaId" && deletado = false',
      sort: 'nome',
    );
    return recs.map(Consumivel.fromRecord).toList();
  }

  Future<Consumivel> create(ConsumivelInput input) async {
    final rec = await _c.create(
      body: {
        ...input.toBody(),
        'empresa': _empresaId,
        if (input.preco > 0) 'preco_atualizado_em': _dia(DateTime.now()),
      },
    );
    return Consumivel.fromRecord(rec);
  }

  Future<Consumivel> update(
    String id,
    ConsumivelInput input, {
    bool precoMudou = false,
  }) async => Consumivel.fromRecord(
    await _c.update(
      id,
      body: {
        ...input.toBody(),
        if (precoMudou) 'preco_atualizado_em': _dia(DateTime.now()),
      },
    ),
  );

  Future<void> setDeleted(String id, {required bool deletado}) =>
      _c.update(id, body: {'deletado': deletado});

  static String _dia(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} 00:00:00.000Z';

  // --- documentos -----------------------------------------------------------

  Future<List<DocumentoConsumivel>> listDocumentos() async {
    final recs = await _docs.getFullList(
      filter: 'empresa = "$_empresaId"',
      sort: '-created',
    );
    return recs.map(DocumentoConsumivel.fromRecord).toList();
  }

  Future<DocumentoConsumivel> anexar({
    required String consumivelId,
    required TipoDocumento tipo,
    required List<int> bytes,
    required String nomeFicheiro,
    String titulo = '',
    String versao = '',
    DateTime? dataDocumento,
  }) async {
    final rec = await _docs.create(
      body: {
        'empresa': _empresaId,
        'consumivel': consumivelId,
        'tipo': tipo.api,
        'titulo': titulo.trim(),
        'versao': versao.trim(),
        if (dataDocumento != null) 'data_documento': _dia(dataDocumento),
      },
      files: [
        http.MultipartFile.fromBytes('ficheiro', bytes, filename: nomeFicheiro),
      ],
    );
    return DocumentoConsumivel.fromRecord(rec);
  }

  Future<void> apagarDocumento(String id) => _docs.delete(id);

  /// URL do ficheiro com um token novo (o ficheiro é protegido; o token
  /// vale cerca de 2 minutos).
  Future<String> urlDocumento(DocumentoConsumivel d) async {
    final base = _pb.baseURL.endsWith('/')
        ? _pb.baseURL.substring(0, _pb.baseURL.length - 1)
        : _pb.baseURL;
    final token = await _pb.files.getToken();
    return '$base/api/files/consumivel_documentos/${d.id}/${d.ficheiro}'
        '?token=$token';
  }
}
