import 'custo_fixo.dart';

/// O que fazer a um custo se o dinheiro apertar (sugestão da IA).
enum AcaoCusto {
  manter('Manter'),
  reduzir('Reduzir'),
  pausar('Pausar por um período'),
  cortar('Cortar');

  const AcaoCusto(this.label);
  final String label;

  static AcaoCusto fromApi(Object? v) => AcaoCusto.values.firstWhere(
    (a) => a.name == v,
    orElse: () => AcaoCusto.manter,
  );
}

/// Sugestão da IA para um custo: se é fixo ou variável, porquê, e o que fazer.
class SugestaoCusto {
  const SugestaoCusto({
    required this.id,
    required this.nome,
    required this.valorMensal,
    required this.tipoAtual,
    required this.tipoSugerido,
    this.motivo = '',
    this.acao = AcaoCusto.manter,
    this.dica = '',
  });

  final String id;
  final String nome;
  final double valorMensal;
  final TipoCusto tipoAtual;
  final TipoCusto tipoSugerido;
  final String motivo;
  final AcaoCusto acao;
  final String dica;

  /// A IA sugere um tipo diferente do atual.
  bool get muda => tipoAtual != tipoSugerido;

  factory SugestaoCusto.fromJson(Map<String, dynamic> j) => SugestaoCusto(
    id: '${j['id'] ?? ''}',
    nome: '${j['nome'] ?? ''}',
    valorMensal: (j['valorMensal'] as num?)?.toDouble() ?? 0,
    tipoAtual: TipoCusto.fromApi(j['tipoAtual'] as String?),
    tipoSugerido: TipoCusto.fromApi(j['tipoSugerido'] as String?),
    motivo: '${j['motivo'] ?? ''}',
    acao: AcaoCusto.fromApi(j['acao']),
    dica: '${j['dica'] ?? ''}',
  );
}

/// Lê a lista de sugestões da resposta do servidor (ignora entradas sem id).
List<SugestaoCusto> sugestoesDeJson(Object? raw) {
  final lista = raw is Map ? raw['sugestoes'] : null;
  if (lista is! List) return const [];
  return [
    for (final e in lista)
      if (e is Map && '${e['id'] ?? ''}'.isNotEmpty)
        SugestaoCusto.fromJson(Map<String, dynamic>.from(e)),
  ];
}

enum PrioridadeDica {
  alta,
  media,
  baixa;

  static PrioridadeDica fromApi(Object? v) => PrioridadeDica.values.firstWhere(
    (p) => p.name == v,
    orElse: () => PrioridadeDica.media,
  );

  String get label => switch (this) {
    PrioridadeDica.alta => 'Prioridade alta',
    PrioridadeDica.media => 'Prioridade média',
    PrioridadeDica.baixa => 'Prioridade baixa',
  };
}

/// Uma dica de melhoria gerada pela IA a partir dos números do painel.
class DicaFinanceira {
  const DicaFinanceira({
    required this.titulo,
    required this.texto,
    this.prioridade = PrioridadeDica.media,
    this.area = '',
  });

  final String titulo;
  final String texto;
  final PrioridadeDica prioridade;
  final String area;
}

class DicasFinanceiras {
  const DicasFinanceiras({this.resumo = '', this.dicas = const []});

  final String resumo;
  final List<DicaFinanceira> dicas;

  factory DicasFinanceiras.fromJson(Object? raw) {
    if (raw is! Map) return const DicasFinanceiras();
    final lista = raw['dicas'];
    return DicasFinanceiras(
      resumo: '${raw['resumo'] ?? ''}',
      dicas: [
        if (lista is List)
          for (final e in lista)
            if (e is Map &&
                '${e['titulo'] ?? ''}'.isNotEmpty &&
                '${e['texto'] ?? ''}'.isNotEmpty)
              DicaFinanceira(
                titulo: '${e['titulo']}',
                texto: '${e['texto']}',
                prioridade: PrioridadeDica.fromApi(e['prioridade']),
                area: '${e['area'] ?? ''}',
              ),
      ],
    );
  }
}
