import 'package:pocketbase/pocketbase.dart';

import '../../../core/formatting/capitalizar.dart';

/// Tipo de custo — para separar, no painel financeiro, o que é fixo
/// (aluguel, salários) do que varia com o volume vendido.
enum TipoCusto {
  fixo,
  variavel;

  static TipoCusto fromApi(String? v) =>
      v == 'variavel' ? TipoCusto.variavel : TipoCusto.fixo;

  String get api => name;

  String get label => switch (this) {
    TipoCusto.fixo => 'Fixo',
    TipoCusto.variavel => 'Variável',
  };
}

/// Um custo real e recorrente da empresa (aluguel, salários, seguros,
/// subscrições…), em valor mensal — diferente dos percentuais de
/// `CostConfig`, que só servem para sugerir o preço de venda.
class CustoFixo {
  const CustoFixo({
    required this.id,
    required this.nome,
    this.tipo = TipoCusto.fixo,
    this.valorMensal = 0,
    this.arquivado = false,
    this.notas = '',
    this.diaPagamento,
  });

  final String id;
  final String nome;
  final TipoCusto tipo;
  final double valorMensal;
  final bool arquivado;
  final String notas;

  /// Dia do mês (1-31) em que este custo é pago — só para o lembrete de
  /// pagamentos, não entra em nenhum cálculo.
  final int? diaPagamento;

  bool get ativo => !arquivado;

  factory CustoFixo.fromRecord(RecordModel r) => CustoFixo(
    id: r.id,
    nome: r.getStringValue('nome'),
    tipo: TipoCusto.fromApi(r.getStringValue('tipo')),
    valorMensal: r.getDoubleValue('valor_mensal'),
    arquivado: r.getBoolValue('arquivado'),
    notas: r.getStringValue('notas'),
    diaPagamento: r.getIntValue('dia_pagamento') > 0
        ? r.getIntValue('dia_pagamento')
        : null,
  );
}

/// Dados de um custo fixo a criar/editar (formulário).
class CustoFixoInput {
  CustoFixoInput({
    required this.nome,
    required this.tipo,
    required this.valorMensal,
    this.notas = '',
    this.diaPagamento,
  });

  final String nome;
  final TipoCusto tipo;
  final double valorMensal;
  final String notas;
  final int? diaPagamento;

  Map<String, dynamic> toBody() => {
    'nome': capitalizarInicial(nome.trim()),
    'tipo': tipo.api,
    'valor_mensal': valorMensal,
    'notas': notas.trim(),
    'dia_pagamento': diaPagamento,
  };
}
