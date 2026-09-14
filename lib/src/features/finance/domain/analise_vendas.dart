import '../../sales/domain/venda.dart';
import 'periodo.dart';
import 'resumo_financeiro.dart';

/// Vendas agregadas por ficha técnica (ou sem produto identificado) num
/// período — base do ranking de sabores mais vendidos e da margem real.
class VendaPorFicha {
  const VendaPorFicha({
    required this.fichaId,
    required this.nome,
    required this.quantidade,
    required this.receita,
    required this.custo,
  });

  /// Vazio quando as linhas de venda não têm ficha associada.
  final String fichaId;
  final String nome;
  final double quantidade;
  final double receita;
  final double custo;

  bool get temFicha => fichaId.isNotEmpty;
  double get margemValor => receita - custo;
  double get margemPercent => receita > 0 ? (margemValor / receita) * 100 : 0;
}

/// Análise de vendas de um [periodo]: ranking por ficha técnica (sabor) e a
/// tendência de cada uma face ao período anterior de igual duração.
class AnaliseVendas {
  const AnaliseVendas({
    required this.periodo,
    required this.porFicha,
    required this.quantidadeAnterior,
  });

  final Periodo periodo;

  /// Ordenado por receita, decrescente.
  final List<VendaPorFicha> porFicha;

  /// Quantidade vendida no período anterior, por `fichaId` (chave vazia =
  /// sem ficha) — base da seta de tendência de cada linha.
  final Map<String, double> quantidadeAnterior;

  /// Variação da quantidade vendida de [v] face ao período anterior — `null`
  /// se não houve vendas dessa ficha no período anterior (sem comparação).
  double? tendenciaPercent(VendaPorFicha v) =>
      variacaoPercent(quantidadeAnterior[v.fichaId] ?? 0, v.quantidade);
}

class _Acumulado {
  double quantidade = 0;
  double receita = 0;
  double custo = 0;
}

/// Quantidade total vendida por `fichaId` (chave vazia = sem ficha) — usado
/// para comparar com o período anterior.
Map<String, double> quantidadePorFicha(List<VendaItem> itens) {
  final m = <String, double>{};
  for (final it in itens) {
    final chave = it.fichaId ?? '';
    m[chave] = (m[chave] ?? 0) + it.quantidade;
  }
  return m;
}

/// Agrupa as linhas de venda por ficha técnica (ou sem produto identificado)
/// e devolve o ranking ordenado por receita, decrescente. [nomes] resolve
/// `fichaId` → nome (ficha apagada entretanto fica "Ficha removida").
List<VendaPorFicha> agruparPorFicha(
  List<VendaItem> itens,
  Map<String, String> nomes,
) {
  final porId = <String, _Acumulado>{};
  for (final it in itens) {
    final chave = it.fichaId ?? '';
    final acc = porId.putIfAbsent(chave, _Acumulado.new);
    acc.quantidade += it.quantidade;
    acc.receita += it.totalLinha;
    if (it.temFicha) acc.custo += it.custoUnitarioSnapshot * it.quantidade;
  }
  final lista = porId.entries
      .map((e) => VendaPorFicha(
            fichaId: e.key,
            nome: e.key.isEmpty
                ? 'Sem produto identificado'
                : (nomes[e.key] ?? 'Ficha removida'),
            quantidade: e.value.quantidade,
            receita: e.value.receita,
            custo: e.value.custo,
          ))
      .toList();
  lista.sort((a, b) => b.receita.compareTo(a.receita));
  return lista;
}
