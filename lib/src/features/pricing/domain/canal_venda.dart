import 'dart:convert';

import 'package:pocketbase/pocketbase.dart';

/// Uma taxa de um canal: uma percentagem do que o cliente paga nesse nível
/// e/ou um valor fixo por venda (€).
class TaxaCanal {
  const TaxaCanal({required this.nome, this.percent = 0, this.fixo = 0});

  final String nome;

  /// % do preço desse nível (0–99,9).
  final double percent;

  /// Valor fixo por venda (€).
  final double fixo;

  Map<String, dynamic> toJson() => {
    'nome': nome,
    'percent': percent,
    'fixo': fixo,
  };

  static TaxaCanal fromJson(Map<String, dynamic> j) => TaxaCanal(
    nome: (j['nome'] ?? '').toString(),
    percent: _num(j['percent']),
    fixo: _num(j['fixo']),
  );

  static double _num(Object? v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
}

/// O resultado de uma conta num canal (tudo **sem IVA**).
class PrecoCanal {
  const PrecoCanal({
    required this.precoCliente,
    required this.receita,
    required this.taxas,
  });

  /// O que o cliente paga, sem IVA.
  final double precoCliente;

  /// O que chega a nós depois de todas as taxas, sem IVA.
  final double receita;

  /// Cada taxa em €, pela ordem do canal.
  final List<({String nome, double valor})> taxas;

  double get totalTaxas => precoCliente - receita;
  double get totalTaxasPercent =>
      precoCliente > 0 ? totalTaxas / precoCliente * 100 : 0;
}

/// Um canal de venda com taxas em cascata (plataforma de entrega,
/// revendedor, terceiro…). A **ordem** das [taxas] é a ordem em que cada uma
/// tira a sua parte do que o cliente paga: a primeira é a de fora (ex.: a
/// plataforma), a última é a mais perto de nós (ex.: o revendedor). Cada
/// percentagem é sobre o valor do seu nível (cascata).
class CanalVenda {
  const CanalVenda({
    required this.id,
    required this.nome,
    this.taxas = const [],
    this.embalagemPlataforma = false,
    this.ordem = 0,
  });

  final String id;
  final String nome;
  final List<TaxaCanal> taxas;

  /// Usa a embalagem para plataformas da ficha (custo extra).
  final bool embalagemPlataforma;
  final int ordem;

  factory CanalVenda.fromRecord(RecordModel r) => CanalVenda(
    id: r.id,
    nome: r.getStringValue('nome'),
    taxas: lerTaxas(r.data['taxas']),
    embalagemPlataforma: r.getBoolValue('embalagem_plataforma'),
    ordem: r.getIntValue('ordem'),
  );

  /// Resumo curto, ex.: "Plataforma 30% → Revendedor 20%".
  String get resumo => taxas.isEmpty
      ? 'sem taxas'
      : taxas
            .map((t) {
              final partes = [
                if (t.percent > 0) '${_n(t.percent)}%',
                if (t.fixo > 0) '${_n(t.fixo)} €',
              ].join(' + ');
              return '${t.nome.isEmpty ? 'Taxa' : t.nome} $partes'.trim();
            })
            .join(' → ');

  static String _n(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v
            .toStringAsFixed(2)
            .replaceAll(RegExp(r'0+$'), '')
            .replaceAll('.', ',');

  /// O que chega a nós se o cliente paga [precoCliente] (sem IVA): as taxas
  /// tiram-se uma a uma, pela ordem do canal.
  PrecoCanal aoPreco(double precoCliente) {
    var r = precoCliente;
    final out = <({String nome, double valor})>[];
    for (final t in taxas) {
      final valor = r * t.percent / 100 + t.fixo;
      out.add((nome: t.nome.isEmpty ? 'Taxa' : t.nome, valor: valor));
      r -= valor;
    }
    return PrecoCanal(precoCliente: precoCliente, receita: r, taxas: out);
  }

  /// O preço (sem IVA) que o cliente tem de pagar para **nós recebermos**
  /// [receita]: faz-se o caminho inverso, da taxa mais perto de nós para a
  /// de fora — cada uma soma-se ao seu nível. `null` se alguma taxa é ≥ 100%.
  PrecoCanal? paraReceber(double receita) {
    var p = receita;
    for (final t in taxas.reversed) {
      if (t.percent >= 100) return null;
      p = (p + t.fixo) / (1 - t.percent / 100);
    }
    return aoPreco(p);
  }
}

/// Lê o JSON das taxas (lista, ou texto com a lista).
List<TaxaCanal> lerTaxas(Object? raw) {
  Object? v = raw;
  if (v is String && v.trim().isNotEmpty) {
    try {
      v = jsonDecode(v);
    } on FormatException {
      return const [];
    }
  }
  if (v is! List) return const [];
  return [
    for (final e in v)
      if (e is Map) TaxaCanal.fromJson(Map<String, dynamic>.from(e)),
  ];
}
