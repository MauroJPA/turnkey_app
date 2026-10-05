import 'dart:convert';

import 'package:pocketbase/pocketbase.dart';

/// Uma ficha técnica cujo custo mudou por causa da variação de um preço.
class FichaAfetada {
  const FichaAfetada({
    required this.id,
    required this.nome,
    required this.custoAntes,
    required this.custoDepois,
    this.precoVenda = 0,
  });

  final String id;
  final String nome;
  final double custoAntes;
  final double custoDepois;

  /// Preço de venda ao público (com IVA) no momento; 0 = não definido.
  final double precoVenda;

  double get variacaoCusto => custoDepois - custoAntes;

  /// Margem (% do preço sem IVA) com um dado [custo]; `null` sem preço.
  double? margem(double custo, double ivaPct) {
    if (precoVenda <= 0) return null;
    final semIva = precoVenda / (1 + (ivaPct < 0 ? 0 : ivaPct) / 100);
    return (1 - custo / semIva) * 100;
  }

  static FichaAfetada fromJson(Map<String, dynamic> j) => FichaAfetada(
    id: (j['id'] ?? '').toString(),
    nome: (j['nome'] ?? '').toString(),
    custoAntes: _num(j['custo_antes']),
    custoDepois: _num(j['custo_depois']),
    precoVenda: _num(j['preco_venda']),
  );
}

double _num(Object? v) =>
    v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

/// A variação do preço de um ingrediente (ex.: ao aplicar uma fatura) e as
/// fichas técnicas que ficaram mais caras/baratas por causa dela.
class VariacaoPreco {
  const VariacaoPreco({
    required this.id,
    required this.ingredienteId,
    required this.ingredienteNome,
    required this.antes,
    required this.depois,
    required this.pct,
    required this.criada,
    this.afetadas = const [],
  });

  final String id;
  final String ingredienteId;
  final String ingredienteNome;

  /// Preço por kg (ou por unidade) antes e depois.
  final double antes;
  final double depois;

  /// Variação em % (positivo = subiu).
  final double pct;
  final DateTime criada;
  final List<FichaAfetada> afetadas;

  bool get subiu => pct > 0;

  /// Subida igual ou acima do limiar de aviso ([limiarPct], em %).
  bool subidaAcima(double limiarPct) => pct >= limiarPct;

  factory VariacaoPreco.fromRecord(RecordModel r) {
    Object? raw = r.data['afetadas'];
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        raw = jsonDecode(raw);
      } on FormatException {
        raw = null;
      }
    }
    return VariacaoPreco(
      id: r.id,
      ingredienteId: r.getStringValue('ingrediente'),
      ingredienteNome: r.getStringValue('ingrediente_nome'),
      antes: r.getDoubleValue('antes'),
      depois: r.getDoubleValue('depois'),
      pct: r.getDoubleValue('pct'),
      criada:
          DateTime.tryParse(
            r.getStringValue('created').replaceFirst(' ', 'T'),
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      afetadas: [
        if (raw is List)
          for (final e in raw)
            if (e is Map) FichaAfetada.fromJson(Map<String, dynamic>.from(e)),
      ],
    );
  }
}
