/// O preço de venda que devolve a uma ficha técnica a margem que tinha antes
/// de o custo da matéria-prima subir.
class SugestaoPreco {
  const SugestaoPreco({
    required this.precoAtual,
    required this.precoSugerido,
    required this.margemAtual,
    required this.margemAlvo,
  });

  /// Preço de venda em vigor, com IVA.
  final double precoAtual;

  /// Preço sugerido, com IVA, arredondado para cima ao [passo] (ex.: 5 cêntimos).
  final double precoSugerido;

  /// Margem de hoje (% do preço sem IVA), com o custo novo.
  final double margemAtual;

  /// A margem que se quer recuperar (a que o preço atual dava com o custo antigo).
  final double margemAlvo;

  double get aumento => precoSugerido - precoAtual;
  double get aumentoPct => precoAtual > 0 ? aumento / precoAtual * 100 : 0;
}

/// Sugere um novo preço de venda quando o custo de uma ficha subiu de
/// [custoAntes] para [custoAtual] (matéria-prima por unidade).
///
/// A ideia é simples: o preço atual dava uma margem com o custo antigo; para
/// manter essa mesma margem com o custo novo, o preço sem IVA passa a
/// `custoAtual / (1 − margem)`. Depois soma-se o IVA e arredonda-se para cima
/// ao [passo] (por omissão 5 cêntimos), que é o que se pratica nas lojas.
///
/// A margem de antes é a que o preço [precoAntesComIva] (o de quando a fatura
/// mudou o custo; se for 0, usa-se o atual) dava com [custoAntes]. Assim, se o
/// preço já foi subido depois, a sugestão ajusta-se ou desaparece.
///
/// Devolve `null` quando não há nada a sugerir: o custo não subiu, não há preço
/// de venda, a margem de antes já não existia, ou a margem de hoje já está
/// recuperada (ex.: o preço já foi mexido) ou a diferença é só de arredondamento.
SugestaoPreco? sugerirPreco({
  required double custoAntes,
  required double custoAtual,
  required double precoAtualComIva,
  double precoAntesComIva = 0,
  required double ivaPct,
  double passo = 0.05,
}) {
  if (precoAtualComIva <= 0 || custoAntes <= 0 || custoAtual <= custoAntes) {
    return null;
  }
  final fator = 1 + (ivaPct < 0 ? 0 : ivaPct) / 100;
  final semIvaAntes =
      (precoAntesComIva > 0 ? precoAntesComIva : precoAtualComIva) / fator;
  final semIva = precoAtualComIva / fator;
  final margemAlvo = (1 - custoAntes / semIvaAntes) * 100;
  if (margemAlvo <= 0 || margemAlvo >= 100) return null;
  final margemAtual = (1 - custoAtual / semIva) * 100;
  // já recuperada (ou quase): não incomodar
  if (margemAtual >= margemAlvo - 0.5) return null;
  final novoSemIva = custoAtual / (1 - margemAlvo / 100);
  final bruto = novoSemIva * fator;
  // arredonda para cima ao passo, com uma folga para erros de vírgula flutuante
  final sugerido = (bruto / passo - 1e-9).ceil() * passo;
  final arred = double.parse(sugerido.toStringAsFixed(2));
  if (arred <= precoAtualComIva + 0.004) return null;
  return SugestaoPreco(
    precoAtual: precoAtualComIva,
    precoSugerido: arred,
    margemAtual: margemAtual,
    margemAlvo: margemAlvo,
  );
}
