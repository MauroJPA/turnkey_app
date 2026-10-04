import 'package:pocketbase/pocketbase.dart';

import '../../../core/formatting/quantities.dart';

/// Uma compra que deu entrada no stock (dar o visto na lista de compras ou
/// aplicar uma fatura) — o histórico do que foi comprado.
class CompraRegistada {
  const CompraRegistada({
    required this.data,
    required this.nome,
    required this.quantidade,
    required this.unidade,
    this.origem = '',
    this.fornecedor = '',
    this.custoEstimado,
  });

  /// Dia da compra (hora local).
  final DateTime data;
  final String nome;
  final double quantidade;

  /// `g`, `ml`, `un` ou a unidade de um item livre.
  final String unidade;

  /// "Lista de compras", "Fatura…" ou o que estiver nas notas.
  final String origem;
  final String fornecedor;

  /// Quantidade × preço atual do ingrediente (`null` se não se sabe).
  final double? custoEstimado;

  /// "1,5 kg", "800 g", "12 un"…
  String get quantidadeTexto => switch (unidade) {
    'g' => gramasParaTexto(quantidade),
    'ml' =>
      quantidade >= 1000
          ? '${(quantidade / 1000).toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '').replaceAll('.', ',')} L'
          : '${quantidade.toStringAsFixed(quantidade == quantidade.roundToDouble() ? 0 : 1)} ml',
    final u =>
      '${quantidade.toStringAsFixed(quantidade == quantidade.roundToDouble() ? 0 : 1).replaceAll('.', ',')} $u',
  };

  factory CompraRegistada.fromRecord(RecordModel r) {
    final ing = r.get<List<RecordModel>>('expand.ingrediente', const []);
    final cons = r.get<List<RecordModel>>('expand.consumivel', const []);
    final delta = r.getDoubleValue('delta');
    var nome = r.getStringValue('descricao');
    var unidade = r.getStringValue('unidade');
    var fornecedor = '';
    double? custo;
    if (ing.isNotEmpty) {
      final i = ing.first;
      nome = i.getStringValue('nome');
      unidade = unidadeNormalizada(i.getStringValue('unidade'));
      fornecedor = i.getStringValue('fornecedor');
      final preco = i.getDoubleValue('preco');
      final emb = i.getDoubleValue('gramas_embalagem');
      if (preco > 0 && emb > 0) custo = delta * preco / emb;
    } else if (cons.isNotEmpty) {
      final c = cons.first;
      nome = c.getStringValue('nome');
      fornecedor = c.getStringValue('fornecedor');
      if (unidade.isEmpty) unidade = 'un';
    }
    if (unidade.isEmpty) unidade = 'un';
    final notas = r.getStringValue('notas');
    final criada = DateTime.tryParse(r.getStringValue('created'))?.toLocal();
    final d = criada ?? DateTime.now();
    return CompraRegistada(
      data: DateTime(d.year, d.month, d.day),
      nome: nome.isEmpty ? '(sem nome)' : nome,
      quantidade: delta,
      unidade: unidade,
      origem: notas,
      fornecedor: fornecedor,
      custoEstimado: custo,
    );
  }
}

enum AgruparCompras { dia, fornecedor, produto }

/// Um grupo de compras (um dia, um fornecedor ou um produto) e o seu total.
class GrupoCompras {
  const GrupoCompras({
    required this.titulo,
    required this.itens,
    required this.custoEstimado,
    this.data,
  });

  final String titulo;
  final List<CompraRegistada> itens;

  /// Soma dos custos estimados dos itens que o têm.
  final double custoEstimado;

  /// Só nos grupos por dia.
  final DateTime? data;
}

String _dmy(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Reparte as compras por dia (do mais recente), por fornecedor ou por
/// produto (do que mais se comprou, pelo custo).
List<GrupoCompras> agruparCompras(
  List<CompraRegistada> compras,
  AgruparCompras como,
) {
  final mapa = <String, List<CompraRegistada>>{};
  for (final c in compras) {
    final chave = switch (como) {
      AgruparCompras.dia => _dmy(c.data),
      AgruparCompras.fornecedor =>
        c.fornecedor.isEmpty ? '(sem fornecedor)' : c.fornecedor,
      AgruparCompras.produto => c.nome,
    };
    mapa.putIfAbsent(chave, () => []).add(c);
  }
  final grupos = [
    for (final e in mapa.entries)
      GrupoCompras(
        titulo: e.key,
        itens: e.value,
        custoEstimado: e.value.fold<double>(
          0,
          (s, c) => s + (c.custoEstimado ?? 0),
        ),
        data: como == AgruparCompras.dia ? e.value.first.data : null,
      ),
  ];
  switch (como) {
    case AgruparCompras.dia:
      grupos.sort((a, b) => b.data!.compareTo(a.data!));
    case AgruparCompras.fornecedor || AgruparCompras.produto:
      grupos.sort((a, b) {
        final c = b.custoEstimado.compareTo(a.custoEstimado);
        return c != 0 ? c : a.titulo.compareTo(b.titulo);
      });
  }
  return grupos;
}
