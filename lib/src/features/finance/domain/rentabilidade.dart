import '../../pricing/domain/canal_venda.dart';
import '../../pricing/domain/cost_config.dart';
import '../../tech_sheets/domain/tech_sheet.dart';

/// Como ordenar o ranking.
enum OrdemRentabilidade {
  lucroUnidade('Lucro por unidade'),
  lucroHoraForno('Lucro por hora de forno'),
  margem('Margem %');

  const OrdemRentabilidade(this.label);
  final String label;
}

/// O que um produto rende num canal, ao preço de venda que já tem.
class LinhaRentabilidade {
  const LinhaRentabilidade({
    required this.ficha,
    required this.precoSemIva,
    required this.receita,
    required this.lucroUn,
    required this.margemPct,
    this.lucroHora,
  });

  final FichaTecnica ficha;

  /// Preço pago pelo cliente, sem IVA.
  final double precoSemIva;

  /// O que chega a nós depois das taxas do canal, sem IVA.
  final double receita;
  final double lucroUn;

  /// Lucro sobre o que chega a nós (%).
  final double margemPct;

  /// Lucro por hora de forno se o forno só levasse este produto; `null` sem
  /// tempo de assadura ou sem capacidade do forno.
  final double? lucroHora;

  bool get prejuizo => lucroUn < 0;
}

/// O ranking de rentabilidade de [fichas] num [canal] (`null` = loja física,
/// sem taxas). Só entram produtos com preço de venda e custo. [capacidadeForno]
/// são as unidades que cabem numa fornada.
List<LinhaRentabilidade> calcularRentabilidade({
  required List<FichaTecnica> fichas,
  required CostConfig config,
  CanalVenda? canal,
  double capacidadeForno = 0,
  OrdemRentabilidade ordem = OrdemRentabilidade.lucroUnidade,
}) {
  final out = <LinhaRentabilidade>[];
  for (final f in fichas) {
    if (f.deletado || !f.temPrecoVenda || f.custoProduto <= 0) continue;
    final precoSemIva = config.semIva(f.precoVenda);
    final receita = canal == null
        ? precoSemIva
        : canal.aoPreco(precoSemIva).receita;
    final lucro = config.lucroSemIva(f.custoProduto, receita);
    final hora = f.tempoAssaduraMin > 0 && capacidadeForno > 0
        ? lucro * capacidadeForno * 60 / f.tempoAssaduraMin
        : null;
    out.add(
      LinhaRentabilidade(
        ficha: f,
        precoSemIva: precoSemIva,
        receita: receita,
        lucroUn: lucro,
        margemPct: receita > 0 ? lucro / receita * 100 : 0,
        lucroHora: hora,
      ),
    );
  }
  out.sort((a, b) {
    final c = switch (ordem) {
      OrdemRentabilidade.lucroUnidade => b.lucroUn.compareTo(a.lucroUn),
      OrdemRentabilidade.lucroHoraForno =>
        (b.lucroHora ?? double.negativeInfinity).compareTo(
          a.lucroHora ?? double.negativeInfinity,
        ),
      OrdemRentabilidade.margem => b.margemPct.compareTo(a.margemPct),
    };
    return c != 0 ? c : a.ficha.nome.compareTo(b.ficha.nome);
  });
  return out;
}

/// Unidades por fornada a partir do histórico: a média do total de cada
/// fornada (ignora canceladas e vazias). 0 se não há dados.
double capacidadeMediaFornadas(Iterable<double> totaisPorFornada) {
  final v = [
    for (final t in totaisPorFornada)
      if (t > 0) t,
  ];
  if (v.isEmpty) return 0;
  return v.reduce((a, b) => a + b) / v.length;
}
