import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import '../../../core/pocketbase/pb_client.dart';
import '../domain/empresa.dart';

final empresaRepositoryProvider = Provider<EmpresaRepository>(
  (ref) => EmpresaRepository(ref.watch(pbProvider)),
);

class EmpresaRepository {
  EmpresaRepository(this._pb);

  final PocketBase _pb;

  Future<Empresa> getById(String id) async {
    final r = await _pb.collection('empresas').getOne(id);
    return Empresa.fromRecord(r);
  }

  Future<Empresa> updatePerfil(
    String id, {
    required String nome,
    required Moeda moeda,
    required RegraArredondamento regra,
    required String corMarca,
    required TemaApp tema,
  }) async {
    final r = await _pb.collection('empresas').update(
      id,
      body: {
        'nome': nome.trim(),
        'moeda': moeda.code,
        'regra_arredondamento': regra.name,
        'cor_marca': corMarca.trim(),
        'tema': tema.api,
      },
    );
    return Empresa.fromRecord(r);
  }

  Future<Empresa> definirLogo(
    String id, {
    required String nome,
    required List<int> bytes,
  }) async {
    final r = await _pb.collection('empresas').update(
      id,
      body: {},
      files: [http.MultipartFile.fromBytes('logo', bytes, filename: nome)],
    );
    return Empresa.fromRecord(r);
  }

  Future<Empresa> removerLogo(String id) async {
    final r = await _pb.collection('empresas').update(
      id,
      body: {'logo': null},
    );
    return Empresa.fromRecord(r);
  }

  /// URL público do logótipo da empresa (`''` se não houver).
  String logoUrl(Empresa e) {
    if (!e.temLogo) return '';
    final base = _pb.baseURL.endsWith('/')
        ? _pb.baseURL.substring(0, _pb.baseURL.length - 1)
        : _pb.baseURL;
    return '$base/api/files/empresas/${e.id}/${e.logo}';
  }

  /// Onboarding: cria a empresa, promove o utilizador a `owner` e cria a linha
  /// de `configuracoes_custo` — tudo atomicamente no servidor.
  ///
  /// Ver `pb/hooks/onboarding.pb.js`. As regras de API não deixam o cliente
  /// fazer estes passos diretamente (de propósito), por isso passa por aqui.
  Future<String> onboard({
    required String nome,
    required Moeda moeda,
    required RegraArredondamento regra,
  }) async {
    final res = await _pb.send(
      '/api/turnkey/onboarding',
      method: 'POST',
      body: {
        'nome': nome,
        'moeda': moeda.code,
        'regra': regra.name,
      },
    );
    return (res as Map<String, dynamic>)['empresaId'] as String;
  }
}
