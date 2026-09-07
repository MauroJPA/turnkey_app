import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../domain/cost_config.dart';

final costConfigRepositoryProvider = Provider<CostConfigRepository>((ref) {
  return CostConfigRepository(ref.watch(pbProvider), requireEmpresaId(ref));
});

class CostConfigRepository {
  CostConfigRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  RecordService get _c => _pb.collection('configuracoes_custo');

  Future<CostConfig> get() async {
    final rec = await _c.getFirstListItem('empresa = "$_empresaId"');
    return CostConfig.fromRecord(rec);
  }

  Future<CostConfig> update(String id, CostConfig config) async {
    final rec = await _c.update(id, body: config.toBody());
    return CostConfig.fromRecord(rec);
  }
}

/// Percentuais de custo da empresa ativa.
final costConfigProvider = FutureProvider<CostConfig>((ref) {
  return ref.watch(costConfigRepositoryProvider).get();
});
