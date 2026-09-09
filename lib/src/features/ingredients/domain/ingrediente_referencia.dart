import 'package:pocketbase/pocketbase.dart';

import '../../../core/nutrition/nutrition.dart';

/// Uma entrada da tabela partilhada de referência (ex.: INSA TCA) — valores
/// nutricionais por 100 g de um alimento genérico, para pré-preencher um
/// ingrediente.
class IngredienteReferencia {
  const IngredienteReferencia({
    required this.id,
    required this.nome,
    this.codigo = '',
    this.grupo = '',
    this.fonte = '',
    this.sinonimos = '',
    this.nutri = const Nutrientes(),
  });

  final String id;
  final String nome;
  final String codigo;
  final String grupo;
  final String fonte;
  final String sinonimos;
  final Nutrientes nutri;

  factory IngredienteReferencia.fromRecord(RecordModel r) =>
      IngredienteReferencia(
        id: r.id,
        nome: r.getStringValue('nome'),
        codigo: r.getStringValue('codigo'),
        grupo: r.getStringValue('grupo'),
        fonte: r.getStringValue('fonte'),
        sinonimos: r.getStringValue('sinonimos'),
        nutri: Nutrientes.fromRecord(r),
      );
}
