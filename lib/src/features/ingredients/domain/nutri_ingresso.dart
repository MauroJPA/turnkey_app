import '../../../core/nutrition/nutrition.dart';
import 'ingredient.dart';

/// Nutrição e alergénios preenchidos no formulário de "Novo ingrediente"
/// (por 100 g ou 100 ml). Tudo opcional.
class NutriIngresso {
  const NutriIngresso({
    this.nutri = const Nutrientes(),
    this.base = '100g',
    this.densidade = 1,
    this.alergenios = const [],
    this.tracos = const [],
    this.origem = 'manual',
    this.foto,
  });

  final Nutrientes nutri;
  final String base;
  final double densidade;
  final List<String> alergenios;
  final List<String> tracos;

  /// 'manual', 'insa' (escolhido da tabela) ou 'rotulo' (lido por IA).
  final String origem;

  /// Foto da tabela nutricional a anexar depois de criar o ingrediente.
  final ({String nome, List<int> bytes})? foto;

  bool get temDados =>
      !nutri.vazio || alergenios.isNotEmpty || tracos.isNotEmpty;
}

/// Resultado da leitura de um rótulo por IA (ainda sem ingrediente gravado).
class RotuloLido {
  const RotuloLido({
    required this.nutri,
    this.base = '100g',
    this.densidade = 1,
    this.alergenios = const [],
    this.tracos = const [],
  });

  final Nutrientes nutri;
  final String base;
  final double densidade;
  final List<String> alergenios;
  final List<String> tracos;

  factory RotuloLido.fromJson(Map<String, dynamic> j) {
    final n = Map<String, dynamic>.from((j['nutri'] as Map?) ?? const {});
    double v(String k) => (n[k] as num?)?.toDouble() ?? 0;
    List<String> lista(String k) =>
        ((j[k] as List?) ?? const []).map((e) => '$e').toList();
    return RotuloLido(
      nutri: Nutrientes(
        kcal: v('energia_kcal'),
        lipidos: v('lipidos_g'),
        saturados: v('saturados_g'),
        hidratos: v('hidratos_g'),
        acucares: v('acucares_g'),
        fibra: v('fibra_g'),
        proteina: v('proteina_g'),
        sal: v('sal_g'),
      ),
      base: j['base'] == '100ml' ? '100ml' : '100g',
      densidade: (j['densidade'] as num?)?.toDouble() ?? 1,
      alergenios: lista('alergenios'),
      tracos: lista('alergenios_tracos'),
    );
  }
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
