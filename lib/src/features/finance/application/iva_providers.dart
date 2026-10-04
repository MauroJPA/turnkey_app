import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../invoices/data/invoice_repository.dart';
import '../../pricing/data/cost_config_repository.dart';
import '../../sales/data/sales_repository.dart';
import '../domain/iva.dart';
import '../domain/periodo.dart';

/// O IVA de um período + a taxa por omissão usada nas estimativas.
class IvaDoPeriodo {
  const IvaDoPeriodo({required this.resumo, required this.taxaPadrao});
  final ResumoIva resumo;

  /// Taxa de IVA das vendas definida em Configurações (0 = não definida).
  final double taxaPadrao;
}

final ivaPeriodoProvider = FutureProvider.autoDispose
    .family<IvaDoPeriodo, Periodo>((ref, periodo) async {
      final config = await ref.watch(costConfigProvider.future);
      final res = await ref
          .watch(salesRepositoryProvider)
          .periodo(desde: periodo.desde, ate: periodo.ate);
      final faturas = await ref.watch(invoiceRepositoryProvider).list();
      final linhas = linhasDeIva(
        vendas: res.vendas,
        itens: res.itens,
        taxaPadraoPercent: config.ivaVendas,
      );
      return IvaDoPeriodo(
        resumo: resumoDeIva(
          linhas: linhas,
          ivaDedutivel: ivaDedutivelDasFaturas(faturas, periodo),
        ),
        taxaPadrao: config.ivaVendas,
      );
    });
