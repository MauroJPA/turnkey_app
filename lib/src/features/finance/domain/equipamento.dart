import 'package:pocketbase/pocketbase.dart';

import '../../../core/formatting/capitalizar.dart';

/// Uma peça de equipamento da loja (computador, forno, balcão…), para
/// calcular a depreciação mensal real — diferente dos custos fixos, que
/// são um valor recorrente já certo, não um custo de compra a diluir.
class Equipamento {
  const Equipamento({
    required this.id,
    required this.nome,
    this.custo = 0,
    this.vidaUtilAnos = 0,
    this.arquivado = false,
    this.notas = '',
  });

  final String id;
  final String nome;
  final double custo;
  final double vidaUtilAnos;
  final bool arquivado;
  final String notas;

  bool get ativo => !arquivado;

  /// Depreciação mensal: custo diluído pela vida útil em meses.
  double get custoMensal => vidaUtilAnos > 0 ? custo / (vidaUtilAnos * 12) : 0;

  factory Equipamento.fromRecord(RecordModel r) => Equipamento(
    id: r.id,
    nome: r.getStringValue('nome'),
    custo: r.getDoubleValue('custo'),
    vidaUtilAnos: r.getDoubleValue('vida_util_anos'),
    arquivado: r.getBoolValue('arquivado'),
    notas: r.getStringValue('notas'),
  );
}

/// Dados de um equipamento a criar/editar (formulário).
class EquipamentoInput {
  EquipamentoInput({
    required this.nome,
    required this.custo,
    required this.vidaUtilAnos,
    this.notas = '',
  });

  final String nome;
  final double custo;
  final double vidaUtilAnos;
  final String notas;

  double get custoMensal => vidaUtilAnos > 0 ? custo / (vidaUtilAnos * 12) : 0;

  Map<String, dynamic> toBody() => {
    'nome': capitalizarInicial(nome.trim()),
    'custo': custo,
    'vida_util_anos': vidaUtilAnos,
    'notas': notas.trim(),
  };
}
