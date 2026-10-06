import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../domain/formacao.dart';

final formacoesRepositoryProvider = Provider<FormacoesRepository>((ref) {
  return FormacoesRepository(ref.watch(pbProvider), requireEmpresaId(ref));
});

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// A data (sem horas) de um campo `date` do PocketBase.
DateTime? _dia(String s) {
  final p = s.length >= 10 ? s.substring(0, 10).split('-') : const <String>[];
  if (p.length != 3) return null;
  final a = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  final d = int.tryParse(p[2]);
  if (a == null || m == null || d == null) return null;
  return DateTime(a, m, d);
}

/// Formações e certificados (`formacoes`).
class FormacoesRepository {
  FormacoesRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  RecordService get _c => _pb.collection('formacoes');

  String? get utilizadorId => _pb.authStore.record?.id;

  static Formacao desdeRecord(RecordModel r) => Formacao(
    id: r.id,
    pessoa: r.getStringValue('pessoa'),
    nome: r.getStringValue('nome'),
    userId: r.getStringValue('user'),
    titulo: r.getStringValue('titulo'),
    tipo: TipoFormacao.fromApi(r.getStringValue('tipo')),
    realizada: _dia(r.getStringValue('data_realizada')),
    validade: _dia(r.getStringValue('validade')),
    entidade: r.getStringValue('entidade'),
    notas: r.getStringValue('notas'),
    ficheiro: r.getStringValue('ficheiro'),
  );

  /// Tudo o que o servidor deixa ver a quem está ligado (a administração vê
  /// todos; os outros só os seus).
  Future<List<Formacao>> listar() async {
    final recs = await _c.getFullList(
      filter: 'empresa = "$_empresaId"',
      sort: 'validade,titulo',
    );
    return recs.map(desdeRecord).toList();
  }

  Map<String, dynamic> _corpo({
    required String titulo,
    required TipoFormacao tipo,
    DateTime? realizada,
    DateTime? validade,
    String entidade = '',
    String notas = '',
  }) => {
    'titulo': titulo.trim(),
    'tipo': tipo.api,
    'data_realizada': realizada == null
        ? ''
        : '${_ymd(realizada)} 00:00:00.000Z',
    'validade': validade == null ? '' : '${_ymd(validade)} 00:00:00.000Z',
    'entidade': entidade.trim(),
    'notas': notas.trim(),
  };

  Future<void> criar({
    required String pessoa,
    required String nome,
    String userId = '',
    required String titulo,
    required TipoFormacao tipo,
    DateTime? realizada,
    DateTime? validade,
    String entidade = '',
    String notas = '',
    List<int>? bytes,
    String nomeFicheiro = '',
  }) => _c.create(
    body: {
      'empresa': _empresaId,
      'pessoa': pessoa,
      'nome': nome.trim(),
      if (userId.isNotEmpty) 'user': userId,
      ..._corpo(
        titulo: titulo,
        tipo: tipo,
        realizada: realizada,
        validade: validade,
        entidade: entidade,
        notas: notas,
      ),
    },
    files: [
      if (bytes != null)
        http.MultipartFile.fromBytes(
          'ficheiro',
          bytes,
          filename: nomeFicheiro.isEmpty ? 'certificado' : nomeFicheiro,
        ),
    ],
  );

  Future<void> editar(
    String id, {
    required String titulo,
    required TipoFormacao tipo,
    DateTime? realizada,
    DateTime? validade,
    String entidade = '',
    String notas = '',
    List<int>? bytes,
    String nomeFicheiro = '',
  }) => _c.update(
    id,
    body: _corpo(
      titulo: titulo,
      tipo: tipo,
      realizada: realizada,
      validade: validade,
      entidade: entidade,
      notas: notas,
    ),
    files: [
      if (bytes != null)
        http.MultipartFile.fromBytes(
          'ficheiro',
          bytes,
          filename: nomeFicheiro.isEmpty ? 'certificado' : nomeFicheiro,
        ),
    ],
  );

  Future<void> apagar(String id) => _c.delete(id);

  /// URL do ficheiro com um token novo (é protegido; o token dura ~2 minutos).
  Future<String> urlFicheiro(Formacao f) async {
    final base = _pb.baseURL.endsWith('/')
        ? _pb.baseURL.substring(0, _pb.baseURL.length - 1)
        : _pb.baseURL;
    final token = await _pb.files.getToken();
    return '$base/api/files/formacoes/${f.id}/${f.ficheiro}?token=$token';
  }
}
