import '../../invoices/domain/fatura.dart';
import '../../sales/domain/venda.dart';
import 'periodo.dart';

/// Como se chegou ao IVA de uma linha de venda.
enum OrigemIva {
  /// O Vendus indicou o valor sem IVA.
  registado,

  /// Estimado com a taxa de IVA definida em Configurações.
  estimado,

  /// Sem valor sem IVA e sem taxa definida: o IVA desta linha não se sabe.
  desconhecido,
}

/// O IVA de uma linha de venda.
class LinhaIva {
  const LinhaIva({
    required this.dia,
    required this.bruto,
    required this.iva,
    required this.origem,
  });

  final DateTime dia;

  /// Valor da linha com IVA.
  final double bruto;

  /// IVA contido no [bruto]; 0 se [origem] for desconhecido.
  final double iva;
  final OrigemIva origem;
}

DateTime _dia(DateTime d) => DateTime(d.year, d.month, d.day);

/// O IVA de cada linha de venda. [taxaPadraoPercent] (0 = não definida) só
/// se usa nas linhas sem o valor sem IVA registado; [taxaPorFicha] é a taxa
/// própria de cada produto (ex.: bebidas), que ganha à da empresa.
List<LinhaIva> linhasDeIva({
  required List<Venda> vendas,
  required List<VendaItem> itens,
  required double taxaPadraoPercent,
  Map<String, double> taxaPorFicha = const {},
}) {
  final porVenda = {for (final v in vendas) v.id: v};
  final out = <LinhaIva>[];
  for (final it in itens) {
    final v = porVenda[it.vendaId];
    if (v == null || it.totalLinha <= 0) continue;
    final bruto = it.totalLinha;
    if (it.valorSemIva != null && it.valorSemIva! <= bruto) {
      out.add(
        LinhaIva(
          dia: _dia(v.data),
          bruto: bruto,
          iva: bruto - it.valorSemIva!,
          origem: OrigemIva.registado,
        ),
      );
    } else if ((taxaPorFicha[it.fichaId] ?? taxaPadraoPercent) > 0) {
      final taxa = taxaPorFicha[it.fichaId] ?? taxaPadraoPercent;
      out.add(
        LinhaIva(
          dia: _dia(v.data),
          bruto: bruto,
          iva: bruto - bruto / (1 + taxa / 100),
          origem: OrigemIva.estimado,
        ),
      );
    } else {
      out.add(
        LinhaIva(
          dia: _dia(v.data),
          bruto: bruto,
          iva: 0,
          origem: OrigemIva.desconhecido,
        ),
      );
    }
  }
  return out;
}

/// IVA cobrado num dia.
class DiaIva {
  const DiaIva({required this.dia, required this.bruto, required this.iva});
  final DateTime dia;
  final double bruto;
  final double iva;
}

/// O IVA de um período: o que se cobrou nas vendas, o que se pagou nas compras
/// (dedutível) e, por diferença, o que há a entregar.
class ResumoIva {
  const ResumoIva({
    required this.ivaLiquidado,
    required this.ivaDedutivel,
    required this.vendidoComIva,
    required this.linhasRegistadas,
    required this.linhasEstimadas,
    required this.linhasDesconhecidas,
    required this.dias,
  });

  /// IVA cobrado aos clientes.
  final double ivaLiquidado;

  /// IVA das faturas de compra confirmadas.
  final double ivaDedutivel;
  final double vendidoComIva;
  final int linhasRegistadas;
  final int linhasEstimadas;
  final int linhasDesconhecidas;

  /// Por dia, do mais antigo para o mais recente (só dias com vendas).
  final List<DiaIva> dias;

  /// Positivo = a entregar ao Estado; negativo = crédito de IVA.
  double get aEntregar => ivaLiquidado - ivaDedutivel;

  /// Há linhas cujo IVA não se conseguiu calcular.
  bool get incompleto => linhasDesconhecidas > 0;

  bool get temEstimativas => linhasEstimadas > 0;
}

ResumoIva resumoDeIva({
  required List<LinhaIva> linhas,
  required double ivaDedutivel,
}) {
  var liquidado = 0.0;
  var bruto = 0.0;
  var reg = 0;
  var est = 0;
  var desc = 0;
  final porDia = <DateTime, (double, double)>{};
  for (final l in linhas) {
    liquidado += l.iva;
    bruto += l.bruto;
    switch (l.origem) {
      case OrigemIva.registado:
        reg++;
      case OrigemIva.estimado:
        est++;
      case OrigemIva.desconhecido:
        desc++;
    }
    final a = porDia[l.dia] ?? (0.0, 0.0);
    porDia[l.dia] = (a.$1 + l.bruto, a.$2 + l.iva);
  }
  final dias = [
    for (final e in porDia.entries)
      DiaIva(dia: e.key, bruto: e.value.$1, iva: e.value.$2),
  ]..sort((a, b) => a.dia.compareTo(b.dia));
  return ResumoIva(
    ivaLiquidado: liquidado,
    ivaDedutivel: ivaDedutivel,
    vendidoComIva: bruto,
    linhasRegistadas: reg,
    linhasEstimadas: est,
    linhasDesconhecidas: desc,
    dias: dias,
  );
}

DateTime? _dataFatura(Fatura f) {
  final s = f.dataFatura.length >= 10 ? f.dataFatura.substring(0, 10) : '';
  final d = DateTime.tryParse(s);
  if (d != null) return d;
  final c = f.created.length >= 10 ? f.created.substring(0, 10) : '';
  return DateTime.tryParse(c);
}

/// IVA das faturas de compra confirmadas (não apagadas) com data no período.
double ivaDedutivelDasFaturas(List<Fatura> faturas, Periodo periodo) {
  var total = 0.0;
  for (final f in faturas) {
    if (f.apagada ||
        f.tipo != FaturaTipo.fatura ||
        f.estado != FaturaEstado.confirmada) {
      continue;
    }
    final d = _dataFatura(f);
    if (d == null || !periodo.contem(d)) continue;
    if (f.iva > 0) total += f.iva;
  }
  return total;
}
