import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pricing/data/cost_config_repository.dart';
import '../../sales/data/sales_repository.dart';
import '../data/custos_fixos_repository.dart';
import '../data/equipamentos_repository.dart';
import '../domain/custo_fixo.dart';
import '../domain/numeros_magicos.dart';
import '../domain/periodo.dart';

final numerosMagicosProvider =
    FutureProvider.autoDispose.family<NumerosMagicos, Periodo>(
  (ref, periodo) async {
    final custosFixosRepo = ref.watch(custosFixosRepositoryProvider);
    final equipamentosRepo = ref.watch(equipamentosRepositoryProvider);
    final sales = ref.watch(salesRepositoryProvider);
    final costConfig = await ref.watch(costConfigProvider.future);

    final custosFixosMensal =
        await custosFixosRepo.totalMensal(tipo: TipoCusto.fixo);
    final custosVariaveisMensal =
        await custosFixosRepo.totalMensal(tipo: TipoCusto.variavel);
    final depreciacaoMensal = await equipamentosRepo.totalMensal();

    final resultado =
        await sales.periodo(desde: periodo.desde, ate: periodo.ate);
    final receitaPeriodo =
        resultado.vendas.fold<double>(0, (s, v) => s + v.total);

    return NumerosMagicos(
      periodo: periodo,
      custosFixosMensal: custosFixosMensal,
      custosVariaveisMensal: custosVariaveisMensal,
      depreciacaoMensal: depreciacaoMensal,
      impostoPercent: costConfig.impostos,
      cmvPercent: costConfig.cmvPercent,
      receitaPeriodo: receitaPeriodo,
    );
  },
);
