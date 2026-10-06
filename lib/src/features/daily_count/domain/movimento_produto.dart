import 'package:pocketbase/pocketbase.dart';

/// O que se registou sobre os cookies de um local.
enum TipoMovimento {
  producao('producao', 'Assados'),
  transferencia('transferencia', 'Enviados'),
  desperdicio('desperdicio', 'Desperdício'),
  contagemAbertura('contagem_abertura', 'Contagem de abertura'),
  contagemFecho('contagem_fecho', 'Contagem de fecho');

  const TipoMovimento(this.api, this.label);
  final String api;
  final String label;

  static TipoMovimento fromApi(String? v) => TipoMovimento.values.firstWhere(
    (t) => t.api == v,
    orElse: () => TipoMovimento.producao,
  );

  bool get eContagem =>
      this == TipoMovimento.contagemAbertura ||
      this == TipoMovimento.contagemFecho;
}

/// Porque é que um cookie foi para o lixo.
enum MotivoDesperdicio {
  queimado('queimado', 'Queimado'),
  foraPrazo('fora_prazo', 'Fora do prazo'),
  quebrado('quebrado', 'Quebrado / caído'),
  erroProducao('erro_producao', 'Erro de produção'),
  degustacao('degustacao', 'Degustação / oferta'),
  consumoProprio('consumo_proprio', 'Consumo próprio'),
  outro('outro', 'Outro');

  const MotivoDesperdicio(this.api, this.label);
  final String api;
  final String label;

  /// Perda que se pode evitar mexendo no dia a dia (forno, prazos, manuseio,
  /// receita). Degustação e consumo próprio são escolhas; "outro" fica de fora.
  bool get evitavel =>
      this == queimado ||
      this == foraPrazo ||
      this == quebrado ||
      this == erroProducao;

  /// Pista do que fazer para reduzir este desperdício.
  String? get dica => switch (this) {
    queimado => 'Confirma a temperatura e o tempo do forno nas fichas.',
    foraPrazo => 'Assa menos: usa o "Quantos assar" e agenda só o que vendes.',
    quebrado => 'Revê a embalagem e o transporte dos cookies.',
    erroProducao => 'Revê a receita/ficha e o procedimento com a equipa.',
    _ => null,
  };

  static MotivoDesperdicio? fromApi(String? v) {
    for (final m in MotivoDesperdicio.values) {
      if (m.api == v) return m;
    }
    return null;
  }
}

/// Uma linha do registo do dia a dia, por local e por sabor (ficha).
class MovimentoProduto {
  const MovimentoProduto({
    required this.id,
    required this.data,
    required this.localId,
    required this.fichaId,
    required this.tipo,
    required this.quantidade,
    this.destinoId = '',
    this.motivo,
    this.notas = '',
  });

  final String id;
  final DateTime data;
  final String localId;
  final String fichaId;
  final TipoMovimento tipo;
  final double quantidade;

  /// Só nas transferências: para onde foram os cookies.
  final String destinoId;

  /// Só no desperdício.
  final MotivoDesperdicio? motivo;
  final String notas;

  factory MovimentoProduto.fromRecord(RecordModel r) {
    final d = DateTime.tryParse(r.getStringValue('data')) ?? DateTime.now();
    return MovimentoProduto(
      id: r.id,
      // só o dia interessa (a data vem em UTC à meia-noite)
      data: DateTime(d.year, d.month, d.day),
      localId: r.getStringValue('local'),
      fichaId: r.getStringValue('ficha'),
      tipo: TipoMovimento.fromApi(r.getStringValue('tipo')),
      quantidade: r.getDoubleValue('quantidade'),
      destinoId: r.getStringValue('destino'),
      motivo: MotivoDesperdicio.fromApi(r.getStringValue('motivo')),
      notas: r.getStringValue('notas'),
    );
  }
}
