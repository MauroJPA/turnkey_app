import '../../../core/nutrition/nutrition.dart';
import 'ingredient.dart';

/// Nutrição e alergénios preenchidos no formulário de "Novo ingrediente"
/// (por 100 g ou 100 ml). Tudo opcional.
class NutriIngresso {
  const NutriIngresso({
    this.nutri = const Nutrientes(),
    this.base = '100g',
    this.alergenios = const [],
  });

  final Nutrientes nutri;
  final String base;
  final List<String> alergenios;

  bool get temDados => !nutri.vazio || alergenios.isNotEmpty;
}

/// O que o formulário de ingrediente devolve.
class IngredienteFormResultado {
  const IngredienteFormResultado({
    required this.input,
    this.nutri,
    this.abrirNutricao = false,
  });

  final IngredienteInput input;

  /// Só ao criar; `null` se não foi preenchida nenhuma nutrição.
  final NutriIngresso? nutri;

  /// Abrir a folha completa (INSA / foto do rótulo) depois de criar.
  final bool abrirNutricao;
}
