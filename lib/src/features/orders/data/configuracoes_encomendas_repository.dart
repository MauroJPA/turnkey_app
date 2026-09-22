import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../domain/configuracao_encomendas.dart';

final configuracoesEncomendasRepositoryProvider =
    Provider<ConfiguracoesEncomendasRepository>((ref) {
  return ConfiguracoesEncomendasRepository(
    ref.watch(pbProvider),
    requireEmpresaId(ref),
  );
});

class ConfiguracoesEncomendasRepository {
  ConfiguracoesEncomendasRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  RecordService get _c => _pb.collection('configuracoes_encomendas');

  /// Sem linha ainda (empresa nova), devolve [ConfiguracaoEncomendas.vazia]
  /// em vez de dar erro — não é preciso nada no onboarding.
  Future<ConfiguracaoEncomendas> get() async {
    try {
      final rec = await _c.getFirstListItem('empresa = "$_empresaId"');
      return ConfiguracaoEncomendas.fromRecord(rec);
    } on ClientException {
      return ConfiguracaoEncomendas.vazia;
    }
  }

  /// Cria a linha na 1ª vez que a empresa grava, atualiza nas seguintes.
  Future<ConfiguracaoEncomendas> salvar(
    String existingId,
    ConfiguracaoEncomendasInput input,
  ) async {
    final rec = existingId.isEmpty
        ? await _c.create(body: {...input.toBody(), 'empresa': _empresaId})
        : await _c.update(existingId, body: input.toBody());
    return ConfiguracaoEncomendas.fromRecord(rec);
  }
}

final configuracaoEncomendasProvider =
    FutureProvider<ConfiguracaoEncomendas>((ref) {
  return ref.watch(configuracoesEncomendasRepositoryProvider).get();
});
