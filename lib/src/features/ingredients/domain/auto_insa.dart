import '../../../core/nutrition/nutrition.dart';

/// Um candidato da tabela INSA para um ingrediente, com a pontuação de
/// semelhança calculada no servidor.
class InsaCandidato {
  const InsaCandidato({
    required this.id,
    required this.nome,
    this.grupo = '',
    this.score = 0,
    this.nutri = const Nutrientes(),
    this.alergenios = const [],
  });

  final String id;
  final String nome;
  final String grupo;
  final double score;
  final Nutrientes nutri;
  final List<String> alergenios;

  /// Percentagem aproximada de semelhança (para mostrar "≈ 87 %").
  int get percentagem => (score.clamp(0, 1) * 100).round();

  factory InsaCandidato.fromJson(Map<String, dynamic> j) {
    final n = j['nutri'];
    final al = j['alergenios'];
    return InsaCandidato(
      id: (j['id'] ?? '').toString(),
      nome: (j['nome'] ?? '').toString(),
      grupo: (j['grupo'] ?? '').toString(),
      score: (j['score'] as num?)?.toDouble() ?? 0,
      nutri: n is Map
          ? Nutrientes(
              kcal: _d(n['energia_kcal']),
              lipidos: _d(n['lipidos_g']),
              saturados: _d(n['saturados_g']),
              hidratos: _d(n['hidratos_g']),
              acucares: _d(n['acucares_g']),
              fibra: _d(n['fibra_g']),
              proteina: _d(n['proteina_g']),
              sal: _d(n['sal_g']),
            )
          : const Nutrientes(),
      alergenios: al is List ? al.map((e) => '$e').toList() : const [],
    );
  }

  static double _d(Object? v) =>
      v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);
}

enum EstadoAutoInsa { preenchido, revisao, semCandidato }

class ResultadoAutoInsa {
  const ResultadoAutoInsa({
    required this.ingredienteId,
    required this.nome,
    required this.estado,
    this.referenciaNome = '',
    this.candidatos = const [],
  });

  final String ingredienteId;
  final String nome;
  final EstadoAutoInsa estado;
  final String referenciaNome;
  final List<InsaCandidato> candidatos;

  factory ResultadoAutoInsa.fromJson(Map<String, dynamic> j) {
    final cs = j['candidatos'];
    final ref = j['referencia'];
    return ResultadoAutoInsa(
      ingredienteId: (j['ingredienteId'] ?? '').toString(),
      nome: (j['nome'] ?? '').toString(),
      estado: switch ((j['estado'] ?? '').toString()) {
        'preenchido' => EstadoAutoInsa.preenchido,
        'revisao' => EstadoAutoInsa.revisao,
        _ => EstadoAutoInsa.semCandidato,
      },
      referenciaNome: ref is Map ? (ref['nome'] ?? '').toString() : '',
      candidatos: cs is List
          ? cs
              .whereType<Map>()
              .map((e) => InsaCandidato.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}

class ResumoAutoInsa {
  const ResumoAutoInsa({
    this.aplicados = 0,
    this.total = 0,
    this.resultados = const [],
  });

  final int aplicados;
  final int total;
  final List<ResultadoAutoInsa> resultados;

  int get porRever => resultados
      .where((r) => r.estado == EstadoAutoInsa.revisao)
      .length;
  int get semCorrespondencia => resultados
      .where((r) => r.estado == EstadoAutoInsa.semCandidato)
      .length;

  factory ResumoAutoInsa.fromJson(Map<String, dynamic> j) {
    final rs = j['resultados'];
    return ResumoAutoInsa(
      aplicados: (j['aplicados'] as num?)?.toInt() ?? 0,
      total: (j['total'] as num?)?.toInt() ?? 0,
      resultados: rs is List
          ? rs
              .whereType<Map>()
              .map((e) =>
                  ResultadoAutoInsa.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}
