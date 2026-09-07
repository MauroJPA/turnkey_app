import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  }) async {
    final r = await _pb.collection('empresas').update(
      id,
      body: {
        'nome': nome.trim(),
        'moeda': moeda.code,
        'regra_arredondamento': regra.name,
        'cor_marca': corMarca.trim(),
      },
    );
    return Empresa.fromRecord(r);
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
