import 'package:pocketbase/pocketbase.dart';

/// Os 14 alergénios de declaração obrigatória na UE (Reg. (UE) 1169/2011,
/// Anexo II). A ordem e o texto têm de bater com os `values` do campo
/// `select` na migração `1706140800_nutricao.js`.
const kAlergenios = <String>[
  'Glúten',
  'Crustáceos',
  'Ovos',
  'Peixe',
  'Amendoins',
  'Soja',
  'Leite',
  'Frutos de casca rija',
  'Aipo',
  'Mostarda',
  'Sésamo',
  'Sulfitos',
  'Tremoço',
  'Moluscos',
];

double _d(Object? v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);

/// Declaração nutricional: os 8 valores obrigatórios da UE.
///
/// Num ingrediente/referência representa valores **por 100 g** (ou 100 ml).
/// Numa receita/ficha em cache representa valores **por 100 g de produto**.
class Nutrientes {
  const Nutrientes({
    this.kcal = 0,
    this.lipidos = 0,
    this.saturados = 0,
    this.hidratos = 0,
    this.acucares = 0,
    this.fibra = 0,
    this.proteina = 0,
    this.sal = 0,
  });

  final double kcal;
  final double lipidos;
  final double saturados;
  final double hidratos;
  final double acucares;
  final double fibra;
  final double proteina;
  final double sal;

  /// Energia em kJ (derivada: 1 kcal = 4,184 kJ).
  double get kj => kcal * 4.184;

  bool get vazio =>
      kcal == 0 &&
      lipidos == 0 &&
      saturados == 0 &&
      hidratos == 0 &&
      acucares == 0 &&
      fibra == 0 &&
      proteina == 0 &&
      sal == 0;

  Nutrientes operator +(Nutrientes o) => Nutrientes(
        kcal: kcal + o.kcal,
        lipidos: lipidos + o.lipidos,
        saturados: saturados + o.saturados,
        hidratos: hidratos + o.hidratos,
        acucares: acucares + o.acucares,
        fibra: fibra + o.fibra,
        proteina: proteina + o.proteina,
        sal: sal + o.sal,
      );

  Nutrientes escala(double f) => Nutrientes(
        kcal: kcal * f,
        lipidos: lipidos * f,
        saturados: saturados * f,
        hidratos: hidratos * f,
        acucares: acucares * f,
        fibra: fibra * f,
        proteina: proteina * f,
        sal: sal * f,
      );

  /// Contribuição absoluta de `gramas` deste alimento (valores são por 100 g).
  Nutrientes paraGramas(double gramas) => escala(gramas / 100);

  /// Converte totais absolutos (com peso `gramas`) para "por 100 g".
  Nutrientes por100(double gramas) =>
      gramas > 0 ? escala(100 / gramas) : const Nutrientes();

  Map<String, dynamic> toJson() => {
        'kcal': kcal,
        'kj': kj,
        'lipidos': lipidos,
        'saturados': saturados,
        'hidratos': hidratos,
        'acucares': acucares,
        'fibra': fibra,
        'proteina': proteina,
        'sal': sal,
      };

  factory Nutrientes.fromJson(Map<String, dynamic> j) => Nutrientes(
        kcal: _d(j['kcal']),
        lipidos: _d(j['lipidos']),
        saturados: _d(j['saturados']),
        hidratos: _d(j['hidratos']),
        acucares: _d(j['acucares']),
        fibra: _d(j['fibra']),
        proteina: _d(j['proteina']),
        sal: _d(j['sal']),
      );

  /// Lê os campos `nutri_*` de um `ingredientes` ou `ingredientes_referencia`.
  factory Nutrientes.fromRecord(RecordModel r) => Nutrientes(
        kcal: r.getDoubleValue('nutri_energia_kcal'),
        lipidos: r.getDoubleValue('nutri_lipidos_g'),
        saturados: r.getDoubleValue('nutri_saturados_g'),
        hidratos: r.getDoubleValue('nutri_hidratos_g'),
        acucares: r.getDoubleValue('nutri_acucares_g'),
        fibra: r.getDoubleValue('nutri_fibra_g'),
        proteina: r.getDoubleValue('nutri_proteina_g'),
        sal: r.getDoubleValue('nutri_sal_g'),
      );

  /// Corpo para gravar nos campos `nutri_*` de um ingrediente.
  Map<String, dynamic> toCampos() => {
        'nutri_energia_kcal': kcal,
        'nutri_lipidos_g': lipidos,
        'nutri_saturados_g': saturados,
        'nutri_hidratos_g': hidratos,
        'nutri_acucares_g': acucares,
        'nutri_fibra_g': fibra,
        'nutri_proteina_g': proteina,
        'nutri_sal_g': sal,
      };

  @override
  bool operator ==(Object other) =>
      other is Nutrientes &&
      other.kcal == kcal &&
      other.lipidos == lipidos &&
      other.saturados == saturados &&
      other.hidratos == hidratos &&
      other.acucares == acucares &&
      other.fibra == fibra &&
      other.proteina == proteina &&
      other.sal == sal;

  @override
  int get hashCode => Object.hash(
      kcal, lipidos, saturados, hidratos, acucares, fibra, proteina, sal);
}

/// Nutrição de uma receita/ficha em cache: os valores por 100 g de produto
/// acabado + a lista de alergénios agregada. Guardado no campo JSON `nutri`.
class NutriCache {
  const NutriCache({
    this.por100g = const Nutrientes(),
    this.por100gCozido,
    this.porUnidade,
    this.alergenios = const [],
    this.alergeniosTracos = const [],
    this.completo = true,
    this.semDados = const [],
    this.pesoBaseG = 0,
    this.pesoUnidadeG = 0,
    this.perdaPct = 0,
  });

  /// Receita: valores por 100 g de mistura crua. Ficha: por 100 g de produto
  /// acabado (já com a perda de cozedura).
  final Nutrientes por100g;

  /// Receita: por 100 g já cozido (só preenchido quando há perda). Ficha: null.
  final Nutrientes? por100gCozido;

  /// Ficha: totais de uma unidade (a água que sai a cozer não tem calorias).
  final Nutrientes? porUnidade;

  final List<String> alergenios;
  final List<String> alergeniosTracos;

  /// `false` se algum ingrediente da árvore não tem valores nutricionais.
  final bool completo;

  /// Nomes dos ingredientes sem dados (para avisar o utilizador).
  final List<String> semDados;
  final double pesoBaseG;

  /// Ficha: peso de uma unidade já cozida (g).
  final double pesoUnidadeG;
  final double perdaPct;

  bool get vazio => por100g.vazio && alergenios.isEmpty;

  factory NutriCache.fromJson(Map<String, dynamic>? j) {
    if (j == null || j.isEmpty) return const NutriCache(completo: false);
    List<String> ls(Object? v) =>
        v is List ? v.map((e) => '$e').toList() : const [];
    Nutrientes? n(Object? v) => v is Map
        ? Nutrientes.fromJson(Map<String, dynamic>.from(v))
        : null;
    return NutriCache(
      por100g: n(j['por100g']) ?? const Nutrientes(),
      por100gCozido: n(j['por100g_cozido']),
      porUnidade: n(j['por_unidade']),
      alergenios: ls(j['alergenios']),
      alergeniosTracos: ls(j['alergenios_tracos']),
      completo: j['completo'] as bool? ?? false,
      semDados: ls(j['sem_dados']),
      pesoBaseG: _d(j['peso_base_g']),
      pesoUnidadeG: _d(j['peso_unidade_g']),
      perdaPct: _d(j['perda_pct'] ?? j['perda_media_pct']),
    );
  }
}
