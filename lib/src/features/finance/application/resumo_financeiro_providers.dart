import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pricing/data/cost_config_repository.dart';
import '../../sales/data/sales_repository.dart';
import '../data/custos_fixos_repository.dart';
import '../domain/custo_fixo.dart';
import '../domain/periodo.dart';
import '../domain/resumo_financeiro.dart';

Future<ResumoFinanceiro> _calcular(Ref ref, Periodo periodo) async {
  final sales = ref.watch(salesRepositoryProvider);
  final custosFixosRepo = ref.watch(custosFixosRepositoryProvider);
  final costConfig = await ref.watch(costConfigProvider.future);

  final resultado = await sales.periodo(desde: periodo.desde, ate: periodo.ate);
  final receita = resultado.vendas.fold<double>(0, (s, v) => s + v.total);

  var custoProdutos = 0.0;
  var semFicha = 0;
  final quebra = <String, double>{};
  for (final it in resultado.itens) {
    if (!it.temFicha || it.custoUnitarioSnapshot <= 0) {
      semFicha++;
      continue;
    }
    custoProdutos += it.custoUnitarioSnapshot * it.quantidade;
    final quebraUnidade = costConfig.quebra(it.custoUnitarioSnapshot);
    for (final e in quebraUnidade.entries) {
      quebra[e.key] = (quebra[e.key] ?? 0) + e.value * it.quantidade;
    }
  }

  final fator = periodo.fatorProrateioMensal;
  final custosFixos =
      await custosFixosRepo.totalMensal(tipo: TipoCusto.fixo) * fator;
  final custosVariaveis =
      await custosFixosRepo.totalMensal(tipo: TipoCusto.variavel) * fator;

  return ResumoFinanceiro(
    periodo: periodo,
    receita: receita,
    custoProdutos: custoProdutos,
    custosFixos: custosFixos,
    custosVariaveis: custosVariaveis,
    numVendas: resultado.vendas.length,
    numLinhasSemFicha: semFicha,
    quebra: quebra,
  );
}

final resumoFinanceiroProvider =
    FutureProvider.autoDispose.family<ResumoFinanceiro, Periodo>(
  (ref, periodo) => _calcular(ref, periodo),
);

/// [periodo] e o período imediatamente anterior de igual duração, para os
/// cartões de tendência do painel.
final comparacaoFinanceiraProvider =
    FutureProvider.autoDispose.family<ComparacaoFinanceira, Periodo>(
  (ref, periodo) async {
    final atual = await ref.watch(resumoFinanceiroProvider(periodo).future);
    final anterior =
        await ref.watch(resumoFinanceiroProvider(periodo.anterior).future);
    return ComparacaoFinanceira(atual: atual, anterior: anterior);
  },
);
