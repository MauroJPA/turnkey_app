import 'package:pocketbase/pocketbase.dart';

import '../../../core/formatting/capitalizar.dart';

const kTiposEmbalagem = <String>[
  'Caixa',
  'Saco',
  'Saqueta',
  'Adesivo',
  'Fita',
  'Cartão',
  'Outro',
];

/// Para que serve uma embalagem: uma peça só (individual), várias peças
/// juntas (múltiplo, ex.: caixa de 6), a granel (sem contagem fixa) ou outro.
enum UsoEmbalagem {
  individual,
  multiplo,
  granel,
  outro;

  static UsoEmbalagem? fromApi(String? v) {
    for (final u in UsoEmbalagem.values) {
      if (u.name == v) return u;
    }
    return null;
  }

  String get api => name;
  String get label => switch (this) {
    UsoEmbalagem.individual => 'Individual',
    UsoEmbalagem.multiplo => 'Múltiplo',
    UsoEmbalagem.granel => 'A granel',
    UsoEmbalagem.outro => 'Outro',
  };
}

/// Uma embalagem/consumível de embalamento (caixa, saco, saqueta, adesivo…).
/// O custo por unidade de produto = (preço da compra ÷ peças que vêm) ÷
/// unidades de produto que uma peça embala.
class Embalagem {
  const Embalagem({
    required this.id,
    required this.nome,
    this.tipo = '',
    this.caracteristica = '',
    this.uso,
    this.formatosCookieIds = const [],
    this.precoCompra = 0,
    this.unidadesCompra = 1,
    this.rendeUnidades = 1,
    this.fornecedor = '',
    this.deletado = false,
    this.nomesFatura = const [],
  });

  final String id;
  final String nome;
  final String tipo;

  /// O que distingue esta variante (cor, tamanho, "com janela"…). Opcional.
  final String caracteristica;

  /// Para que serve (individual, múltiplo, a granel…). `null` = não definido.
  final UsoEmbalagem? uso;

  /// Formatos de cookie a que se destina; vazio = serve para qualquer formato.
  final List<String> formatosCookieIds;

  /// Descrições de fatura (normalizadas) já associadas a esta embalagem, para
  /// as faturas seguintes se ligarem sozinhas.
  final List<String> nomesFatura;

  /// € do que se compra (um rolo, um pacote, uma peça).
  final double precoCompra;

  /// Nº de peças nessa compra.
  final double unidadesCompra;

  /// Nº de unidades de produto que uma peça embala (caixa de 6 → 6).
  final double rendeUnidades;

  final String fornecedor;
  final bool deletado;

  double get _pecas => unidadesCompra > 0 ? unidadesCompra : 1;
  double get _rende => rendeUnidades > 0 ? rendeUnidades : 1;

  /// Custo por peça.
  double get custoPeca => precoCompra / _pecas;

  /// Custo por unidade de produto embalada.
  double get custoUnidade => custoPeca / _rende;

  factory Embalagem.fromRecord(RecordModel r) => Embalagem(
    id: r.id,
    nome: r.getStringValue('nome'),
    tipo: r.getStringValue('tipo'),
    caracteristica: r.getStringValue('caracteristica'),
    uso: UsoEmbalagem.fromApi(r.getStringValue('uso')),
    formatosCookieIds: switch (r.data['formatos_cookie']) {
      final List v => [for (final n in v) '$n'],
      final String s when s.isNotEmpty => [s],
      _ => const [],
    },
    precoCompra: r.getDoubleValue('preco_compra'),
    unidadesCompra: r.getDoubleValue('unidades_compra'),
    rendeUnidades: r.getDoubleValue('rende_unidades'),
    fornecedor: r.getStringValue('fornecedor'),
    deletado: r.getBoolValue('deletado'),
    nomesFatura: switch (r.data['nomes_fatura']) {
      final List v => [for (final n in v) '$n'],
      _ => const [],
    },
  );
}

class EmbalagemInput {
  EmbalagemInput({
    required this.nome,
    this.tipo = 'Caixa',
    this.caracteristica = '',
    this.uso,
    this.formatosCookieIds = const [],
    this.precoCompra = 0,
    this.unidadesCompra = 1,
    this.rendeUnidades = 1,
    this.fornecedor = '',
  });

  final String nome;
  final String tipo;
  final String caracteristica;
  final UsoEmbalagem? uso;
  final List<String> formatosCookieIds;
  final double precoCompra;
  final double unidadesCompra;
  final double rendeUnidades;
  final String fornecedor;

  factory EmbalagemInput.fromModel(Embalagem e) => EmbalagemInput(
    nome: e.nome,
    tipo: e.tipo.isEmpty ? 'Caixa' : e.tipo,
    caracteristica: e.caracteristica,
    uso: e.uso,
    formatosCookieIds: e.formatosCookieIds,
    precoCompra: e.precoCompra,
    unidadesCompra: e.unidadesCompra,
    rendeUnidades: e.rendeUnidades,
    fornecedor: e.fornecedor,
  );

  Map<String, dynamic> toBody() => {
    'nome': capitalizarInicial(nome.trim()),
    'tipo': tipo,
    'caracteristica': caracteristica.trim(),
    'uso': uso?.api ?? '',
    'formatos_cookie': formatosCookieIds,
    'preco_compra': precoCompra,
    'unidades_compra': unidadesCompra <= 0 ? 1 : unidadesCompra,
    'rende_unidades': rendeUnidades <= 0 ? 1 : rendeUnidades,
    'fornecedor': fornecedor.trim(),
    'deletado': false,
  };
}
