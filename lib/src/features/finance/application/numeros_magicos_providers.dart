import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pricing/data/cost_config_repository.dart';
import '../../sales/data/sales_repository.dart';
import '../data/custos_fixos_repository.dart';
import '../data/equipamentos_repository.dart';
import '../domain/custo_fixo.dart';
import '../domain/numeros_magicos.dart';
import '../domain/periodo.dart';

final numerosMagicosProvider = FutureProvider.autoDispose
    .family<NumerosMagicos, Periodo>((ref, periodo) async {
      final custosFixosRepo = ref.watch(custosFixosRepositoryProvider);
      final equipamentosRepo = ref.watch(equipamentosRepositoryProvider);
      final sales = ref.watch(salesRepositoryProvider);
      final costConfig = await ref.watch(costConfigProvider.future);

      final custosFixosMensal = await custosFixosRepo.totalMensal(
        tipo: TipoCusto.fixo,
      );
      final custosVariaveisMensal = await custosFixosRepo.totalMensal(
        tipo: TipoCusto.variavel,
      );
      final depreciacaoMensal = await equipamentosRepo.totalMensal();

      final resultado = await sales.periodo(
        desde: periodo.desde,
        ate: periodo.ate,
      );
      final receitaPeriodo = resultado.vendas.fold<double>(
        0,
        (s, v) => s + v.total,
      );

      // Comparação: o período anterior; se o atual ainda decorre, só o mesmo
      // nº de dias desde o início (para comparar o mesmo ponto, não um período
      // completo com um parcial).
      final anterior = periodo.anterior;
      final hoje = DateTime.now();
      final hojeZero = DateTime(hoje.year, hoje.month, hoje.day);
      final decorridos =
          periodo.contem(hojeZero) && periodo.ate.isAfter(hojeZero)
          ? hojeZero.difference(periodo.desde).inDays + 1
          : periodo.dias;
      final fimComparado = decorridos >= anterior.dias
          ? anterior.ate
          : DateTime(
              anterior.desde.year,
              anterior.desde.month,
              anterior.desde.day + decorridos - 1,
            );
      final comparado = Periodo(
        desde: anterior.desde,
        ate: fimComparado,
        label: anterior.label,
      );
      final resAnterior = await sales.periodo(
        desde: comparado.desde,
        ate: comparado.ate,
      );
      final receitaComparada = resAnterior.vendas.fold<double>(
        0,
        (s, v) => s + v.total,
      );

      return NumerosMagicos(
        periodo: periodo,
        periodoComparado: comparado,
        receitaComparada: receitaComparada,
        custosFixosMensal: custosFixosMensal,
        custosVariaveisMensal: custosVariaveisMensal,
        depreciacaoMensal: depreciacaoMensal,
        impostoPercent: costConfig.impostos,
        cmvPercent: costConfig.cmvPercent,
        receitaPeriodo: receitaPeriodo,
      );
    });
