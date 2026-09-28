import 'package:pocketbase/pocketbase.dart';

import '../../../core/formatting/capitalizar.dart';

/// Um formato/tamanho de cookie da empresa (ex.: Mini 20 g, Recheado
/// 120 g de massa + 30 g de recheio, Simples 150 g).
class FormatoCookie {
  const FormatoCookie({
    required this.id,
    required this.nome,
    required this.massaG,
    this.recheioG = 0,
    this.ordem = 0,
    this.ativo = true,
  });

  final String id;
  final String nome;
  final double massaG;
  final double recheioG;
  final double ordem;
  final bool ativo;

  double get totalG => massaG + recheioG;
  bool get temRecheio => recheioG > 0;

  /// Unidades produzidas com [kg] de massa neste formato.
  int unidades(double kg) => massaG > 0 ? (kg * 1000 / massaG).round() : 0;

  String get rotulo => temRecheio
      ? '$nome (${totalG.toStringAsFixed(0)} g · massa ${massaG.toStringAsFixed(0)} + recheio ${recheioG.toStringAsFixed(0)})'
      : '$nome (${massaG.toStringAsFixed(0)} g)';

  factory FormatoCookie.fromRecord(RecordModel r) => FormatoCookie(
    id: r.id,
    nome: r.getStringValue('nome'),
    massaG: r.getDoubleValue('massa_g'),
    recheioG: r.getDoubleValue('recheio_g'),
    ordem: r.getDoubleValue('ordem'),
    ativo: r.getBoolValue('ativo'),
  );
}

class FormatoInput {
  FormatoInput({
    required this.nome,
    required this.massaG,
    this.recheioG = 0,
    this.ordem = 0,
    this.ativo = true,
  });

  final String nome;
  final double massaG;
  final double recheioG;
  final double ordem;
  final bool ativo;

  Map<String, dynamic> toBody() => {
    'nome': capitalizarInicial(nome.trim()),
    'massa_g': massaG,
    'recheio_g': recheioG,
    'ordem': ordem,
    'ativo': ativo,
  };
}
