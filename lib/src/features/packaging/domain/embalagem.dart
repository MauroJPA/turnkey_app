import 'package:pocketbase/pocketbase.dart';

const kTiposEmbalagem = <String>[
  'Caixa',
  'Saco',
  'Saqueta',
  'Adesivo',
  'Fita',
  'Cartão',
  'Outro',
];

/// Uma embalagem/consumível de embalamento (caixa, saco, saqueta, adesivo…).
/// O custo por unidade de produto = (preço da compra ÷ peças que vêm) ÷
/// unidades de produto que uma peça embala.
class Embalagem {
  const Embalagem({
    required this.id,
    required this.nome,
    this.tipo = '',
    this.precoCompra = 0,
    this.unidadesCompra = 1,
    this.rendeUnidades = 1,
    this.fornecedor = '',
    this.deletado = false,
  });

  final String id;
  final String nome;
  final String tipo;

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
        precoCompra: r.getDoubleValue('preco_compra'),
        unidadesCompra: r.getDoubleValue('unidades_compra'),
        rendeUnidades: r.getDoubleValue('rende_unidades'),
        fornecedor: r.getStringValue('fornecedor'),
        deletado: r.getBoolValue('deletado'),
      );
}

class EmbalagemInput {
  EmbalagemInput({
    required this.nome,
    this.tipo = 'Caixa',
    this.precoCompra = 0,
    this.unidadesCompra = 1,
    this.rendeUnidades = 1,
    this.fornecedor = '',
  });

  final String nome;
  final String tipo;
  final double precoCompra;
  final double unidadesCompra;
  final double rendeUnidades;
  final String fornecedor;

  factory EmbalagemInput.fromModel(Embalagem e) => EmbalagemInput(
        nome: e.nome,
        tipo: e.tipo.isEmpty ? 'Caixa' : e.tipo,
        precoCompra: e.precoCompra,
        unidadesCompra: e.unidadesCompra,
        rendeUnidades: e.rendeUnidades,
        fornecedor: e.fornecedor,
      );

  Map<String, dynamic> toBody() => {
        'nome': nome.trim(),
        'tipo': tipo,
        'preco_compra': precoCompra,
        'unidades_compra': unidadesCompra <= 0 ? 1 : unidadesCompra,
        'rende_unidades': rendeUnidades <= 0 ? 1 : rendeUnidades,
        'fornecedor': fornecedor.trim(),
        'deletado': false,
      };
}
