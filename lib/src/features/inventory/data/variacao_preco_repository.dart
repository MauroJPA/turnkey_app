import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../../../core/storage/prefs_locais.dart';
import '../../pricing/data/cost_config_repository.dart';
import '../domain/variacao_preco.dart';

/// As variações de preço dos últimos 90 dias (só o servidor as escreve).
class VariacaoPrecoRepository {
  VariacaoPrecoRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  Future<List<VariacaoPreco>> recentes({int dias = 90}) async {
    final desde = DateTime.now()
        .toUtc()
        .subtract(Duration(days: dias))
        .toIso8601String()
        .replaceFirst('T', ' ');
    final recs = await _pb
        .collection('variacoes_preco')
        .getList(
          perPage: 200,
          filter: 'empresa = "$_empresaId" && created >= "$desde"',
          sort: '-created',
        );
    return recs.items.map(VariacaoPreco.fromRecord).toList();
  }
}

final variacaoPrecoRepositoryProvider = Provider<VariacaoPrecoRepository>((
  ref,
) {
  return VariacaoPrecoRepository(ref.watch(pbProvider), requireEmpresaId(ref));
});

/// As variações de preço recentes (mais novas primeiro).
final variacoesPrecoProvider = FutureProvider.autoDispose<List<VariacaoPreco>>((
  ref,
) {
  return ref.watch(variacaoPrecoRepositoryProvider).recentes();
});

const _chaveVistas = 'precos_vistos_ate';

/// Quando carregaste em "marcar como vistas" neste aparelho.
DateTime? precosVistosAte() {
  final v = lerPref(_chaveVistas);
  return v == null ? null : DateTime.tryParse(v);
}

void marcarPrecosVistos() =>
    guardarPref(_chaveVistas, DateTime.now().toUtc().toIso8601String());

/// Subidas acima do limiar ainda por ver (para o Início e o Inventário).
final subidasPorVerProvider = Provider.autoDispose<List<VariacaoPreco>>((ref) {
  final todas = ref.watch(variacoesPrecoProvider).valueOrNull ?? const [];
  final limiar = ref.watch(costConfigProvider).valueOrNull?.alertaPrecoPct ?? 5;
  final visto = precosVistosAte();
  return [
    for (final v in todas)
      if (v.subidaAcima(limiar) && (visto == null || v.criada.isAfter(visto)))
        v,
  ];
});
