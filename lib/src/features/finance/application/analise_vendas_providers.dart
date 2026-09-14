import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sales/data/sales_repository.dart';
import '../../tech_sheets/data/tech_sheet_repository.dart';
import '../domain/analise_vendas.dart';
import '../domain/periodo.dart';

Future<AnaliseVendas> _calcular(Ref ref, Periodo periodo) async {
  final sales = ref.watch(salesRepositoryProvider);
  final fichas = await ref.watch(techSheetRepositoryProvider).list();
  final nomes = {for (final f in fichas) f.id: f.nome};

  final atual = await sales.periodo(desde: periodo.desde, ate: periodo.ate);
  final anteriorP = periodo.anterior;
  final anterior =
      await sales.periodo(desde: anteriorP.desde, ate: anteriorP.ate);

  return AnaliseVendas(
    periodo: periodo,
    porFicha: agruparPorFicha(atual.itens, nomes),
    quantidadeAnterior: quantidadePorFicha(anterior.itens),
  );
}

final analiseVendasProvider =
    FutureProvider.autoDispose.family<AnaliseVendas, Periodo>(
  (ref, periodo) => _calcular(ref, periodo),
);
