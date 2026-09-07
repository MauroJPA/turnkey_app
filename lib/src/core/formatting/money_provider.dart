import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/application/empresa_providers.dart';
import '../../features/settings/domain/empresa.dart';
import 'money.dart';

typedef MoneyFmt = String Function(double value);

/// Formatador de dinheiro configurado pela empresa ativa (moeda + regra de
/// arredondamento). Cai em `€` / arredondar para cima se ainda não houver
/// empresa carregada.
final moneyFormatProvider = Provider<MoneyFmt>((ref) {
  final empresa = ref.watch(currentEmpresaProvider).valueOrNull;
  final symbol = empresa?.moeda.symbol ?? '€';
  final rule = empresa?.regraArredondamento == RegraArredondamento.normal
      ? RoundingRule.nearest
      : RoundingRule.up;
  return (value) => formatMoney(value, symbol: symbol, rule: rule);
});
