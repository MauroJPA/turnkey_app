import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../daily_count/application/contagem_providers.dart';
import '../../daily_count/data/contagem_repository.dart';
import '../../daily_count/domain/movimento_produto.dart';
import '../../sales/data/sales_repository.dart';
import '../domain/previsao_assar.dart';

/// Vendas e desperdício por dia e sabor nas últimas semanas — o que alimenta
/// a previsão de quantos assar.
final consumoRecenteProvider = FutureProvider.autoDispose<List<ConsumoDia>>((
  ref,
) async {
  final agora = DateTime.now();
  final hoje = DateTime(agora.year, agora.month, agora.day);
  final desde = hoje.subtract(const Duration(days: diasDeHistoricoPrevisao));
  final ontem = hoje.subtract(const Duration(days: 1));
  final vendas = await ref
      .watch(salesRepositoryProvider)
      .periodo(desde: desde, ate: ontem);
  final movs = await ref
      .watch(contagemRepositoryProvider)
      .movimentos(desde: desde, ate: ontem);

  final porVenda = {for (final v in vendas.vendas) v.id: v};
  final out = <ConsumoDia>[];
  for (final it in vendas.itens) {
    final v = porVenda[it.vendaId];
    final f = it.fichaId;
    if (v == null || f == null || it.quantidade <= 0) continue;
    out.add(
      ConsumoDia(
        dia: DateTime(v.data.year, v.data.month, v.data.day),
        fichaId: f,
        vendido: it.quantidade,
      ),
    );
  }
  for (final m in movs) {
    if (m.tipo != TipoMovimento.desperdicio || m.quantidade <= 0) continue;
    out.add(
      ConsumoDia(dia: m.data, fichaId: m.fichaId, desperdicio: m.quantidade),
    );
  }
  return out;
});

/// Cookies por sabor que há agora em todos os locais: o fecho contado de hoje
/// ou, se ainda não foi contado, o que devia haver pelas contas.
final stockAgoraProvider = FutureProvider.autoDispose<Map<String, double>>((
  ref,
) async {
  final agora = DateTime.now();
  final hoje = DateTime(agora.year, agora.month, agora.day);
  final locais = await ref.watch(locaisProvider.future);
  final out = <String, double>{};
  for (final l in locais) {
    final c = await ref.watch(
      contagemDoDiaProvider((localId: l.id, dia: hoje)).future,
    );
    for (final linha in c.linhas) {
      final q = linha.fecho ?? linha.esperado;
      if (q > 0) out[linha.fichaId] = (out[linha.fichaId] ?? 0) + q;
    }
  }
  return out;
});
