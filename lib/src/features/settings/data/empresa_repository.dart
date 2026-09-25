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

  Future<Empresa> updateAparencia(
    String id, {
    required String corMarca,
    required TemaApp tema,
    required String corSecundaria,
    required String corFundo,
    required String corTexto,
    required bool logoVisivel,
    required Alinhamento logoAlinhamento,
    required double logoTamanho,
    required bool nomeVisivel,
    required Alinhamento nomeAlinhamento,
    required double nomeTamanho,
    required String fonteFamilia,
  }) async {
    final r = await _pb.collection('empresas').update(
      id,
      body: {
        'cor_marca': corMarca.trim(),
        'tema': tema.api,
        'cor_secundaria': corSecundaria.trim(),
        'cor_fundo': corFundo.trim(),
        'cor_texto': corTexto.trim(),
        'logo_oculto': !logoVisivel,
        'logo_alinhamento': logoAlinhamento.name,
        'logo_tamanho': logoTamanho,
        'nome_oculto': !nomeVisivel,
        'nome_alinhamento': nomeAlinhamento.name,
        'nome_tamanho': nomeTamanho,
        'fonte_familia': fonteFamilia.trim(),
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

  Future<Empresa> definirFonte(
    String id, {
    required String nome,
    required List<int> bytes,
  }) async {
    final r = await _pb.collection('empresas').update(
      id,
      body: {'fonte_familia': _familiaFromNome(nome)},
      files: [http.MultipartFile.fromBytes('fonte_ficheiro', bytes, filename: nome)],
    );
    return Empresa.fromRecord(r);
  }

  Future<Empresa> removerFonte(String id) async {
    final r = await _pb.collection('empresas').update(
      id,
      body: {'fonte_ficheiro': null, 'fonte_familia': ''},
    );
    return Empresa.fromRecord(r);
  }

  static String _familiaFromNome(String nome) {
    final semExtensao = nome.contains('.')
        ? nome.substring(0, nome.lastIndexOf('.'))
        : nome;
    return semExtensao.replaceAll(RegExp(r'[^A-Za-z0-9]+'), ' ').trim();
  }

  /// URL público do logótipo da empresa (`''` se não houver).
  String logoUrl(Empresa e) {
    if (!e.temLogo) return '';
    return _fileUrl('empresas', e.id, e.logo);
  }

  /// URL público do ficheiro de fonte personalizado (`''` se não houver).
  String fonteUrl(Empresa e) {
    if (!e.temFontePersonalizada) return '';
    return _fileUrl('empresas', e.id, e.fonteFicheiro);
  }

  String _fileUrl(String colecao, String id, String ficheiro) {
    final base = _pb.baseURL.endsWith('/')
        ? _pb.baseURL.substring(0, _pb.baseURL.length - 1)
        : _pb.baseURL;
    return '$base/api/files/$colecao/$id/$ficheiro';
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
      '/api/gc_turnkey/onboarding',
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
