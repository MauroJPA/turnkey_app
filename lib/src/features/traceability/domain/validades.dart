/// Ingredientes: avisa quando faltam estes dias ou menos para a validade.
const diasAvisoIngrediente = 5;

/// Produtos acabados: avisa quando vencem hoje ou amanhã.
const diasAvisoProduto = 1;

/// Um lote vencido há mais do que isto deixa de dar aviso (já ninguém o usa;
/// evita avisos para sempre sobre lotes antigos que ninguém marcou).
const diasVencidoAteEsquecer = 14;

enum TipoValidade { ingrediente, produto }

/// Um lote cuja validade está a acabar (ou já acabou).
class AlertaValidade {
  const AlertaValidade({
    required this.id,
    required this.tipo,
    required this.nome,
    required this.lote,
    required this.validade,
    required this.dias,
    this.quantidade = 0,
  });

  /// O id do registo do lote (para o marcar como esgotado).
  final String id;
  final TipoValidade tipo;

  /// O ingrediente ou o produto.
  final String nome;
  final String lote;
  final DateTime validade;

  /// Dias até à validade: 0 = hoje, negativo = já passou.
  final int dias;

  /// Unidades do lote (produtos), 0 se não se sabe.
  final double quantidade;

  bool get vencido => dias < 0;

  /// "vence hoje", "vence amanhã", "vence em 3 dias", "vencido há 2 dias".
  String get quando => switch (dias) {
    0 => 'vence hoje',
    1 => 'vence amanhã',
    < 0 => 'vencido há ${-dias} ${-dias == 1 ? 'dia' : 'dias'}',
    _ => 'vence em $dias dias',
  };

  String get texto {
    final q = quantidade > 0
        ? ' (${quantidade == quantidade.roundToDouble() ? quantidade.toStringAsFixed(0) : quantidade} un)'
        : '';
    return '$nome · lote $lote$q — $quando';
  }
}

/// Um lote de ingrediente, na forma que interessa aos avisos.
typedef LoteIngredienteAviso = ({
  String id,
  String nome,
  String lote,
  DateTime? validade,
  bool esgotado,
});

/// Um lote de produto acabado.
typedef LoteProdutoAviso = ({
  String id,
  String nome,
  String lote,
  DateTime? validade,
  double quantidade,
  bool esgotado,
});

int _diasAte(DateTime validade, DateTime hoje) {
  final v = DateTime.utc(validade.year, validade.month, validade.day);
  final h = DateTime.utc(hoje.year, hoje.month, hoje.day);
  return v.difference(h).inDays;
}

/// Os lotes a precisar de atenção: os que vencem dentro da janela de aviso (ou
/// venceram há pouco) e ainda não foram marcados como esgotados. Os que vencem
/// primeiro vêm à frente.
List<AlertaValidade> alertasDeValidade({
  required DateTime hoje,
  Iterable<LoteIngredienteAviso> ingredientes = const [],
  Iterable<LoteProdutoAviso> produtos = const [],
  int diasIngrediente = diasAvisoIngrediente,
  int diasProduto = diasAvisoProduto,
}) {
  final out = <AlertaValidade>[];
  for (final l in ingredientes) {
    final v = l.validade;
    if (v == null || l.esgotado) continue;
    final d = _diasAte(v, hoje);
    if (d > diasIngrediente || d < -diasVencidoAteEsquecer) continue;
    out.add(
      AlertaValidade(
        id: l.id,
        tipo: TipoValidade.ingrediente,
        nome: l.nome,
        lote: l.lote,
        validade: v,
        dias: d,
      ),
    );
  }
  for (final l in produtos) {
    final v = l.validade;
    if (v == null || l.esgotado || l.quantidade <= 0) continue;
    final d = _diasAte(v, hoje);
    if (d > diasProduto || d < -diasVencidoAteEsquecer) continue;
    out.add(
      AlertaValidade(
        id: l.id,
        tipo: TipoValidade.produto,
        nome: l.nome,
        lote: l.lote,
        validade: v,
        dias: d,
        quantidade: l.quantidade,
      ),
    );
  }
  out.sort((a, b) {
    final c = a.dias.compareTo(b.dias);
    return c != 0 ? c : a.nome.compareTo(b.nome);
  });
  return out;
}
