import 'package:pocketbase/pocketbase.dart';

enum FaturaTipo {
  fatura,
  listaPrecos;

  static FaturaTipo fromApi(String? v) =>
      v == 'lista_precos' ? FaturaTipo.listaPrecos : FaturaTipo.fatura;
  String get api => this == FaturaTipo.listaPrecos ? 'lista_precos' : 'fatura';
  String get label =>
      this == FaturaTipo.listaPrecos ? 'Lista de preços' : 'Fatura';
}

enum FaturaEstado {
  nova,
  analisada,
  confirmada,
  erro;

  static FaturaEstado fromApi(String? v) => FaturaEstado.values.firstWhere(
    (e) => e.name == v,
    orElse: () => FaturaEstado.nova,
  );
  String get label => switch (this) {
    FaturaEstado.nova => 'Nova',
    FaturaEstado.analisada => 'Analisada',
    FaturaEstado.confirmada => 'Confirmada',
    FaturaEstado.erro => 'Erro',
  };
}

/// Uma linha extraída pela IA (dentro de `faturas.dados_ia.linhas`).
class FaturaLinhaIa {
  const FaturaLinhaIa({
    required this.descricao,
    this.quantidade,
    this.unidade = '',
    this.precoUnitario,
    this.total,
    this.embalagemG,
    this.nomeGenerico = '',
    this.marca = '',
    this.consumivel = false,
    this.categoriaConsumivel = '',
  });

  final String descricao;

  /// Ingrediente em termos genéricos, sem marca nem embalagem (sugestão da IA).
  final String nomeGenerico;

  /// Marca comercial lida da linha (vazio se não houver).
  final String marca;

  /// A IA acha que é limpeza/insumo (não um ingrediente).
  final bool consumivel;

  /// `limpeza`, `desinfecao`, `higiene`, `insumo` ou `outro` (só se [consumivel]).
  final String categoriaConsumivel;
  final double? quantidade;
  final String unidade;
  final double? precoUnitario;
  final double? total;
  final double? embalagemG;

  /// Quantidade convertida para gramas (kg/L -> g/ml aproximado).
  double get quantidadeG {
    final q = quantidade ?? 0;
    final u = unidade.toLowerCase().trim();
    if (u == 'kg' || u == 'l') return q * 1000;
    return q;
  }

  factory FaturaLinhaIa.fromJson(Map<String, dynamic> j) => FaturaLinhaIa(
    descricao: (j['descricao'] ?? j['nome'] ?? '').toString(),
    quantidade: (j['quantidade'] as num?)?.toDouble(),
    unidade: (j['unidade'] ?? '').toString(),
    precoUnitario: (j['preco_unitario'] as num?)?.toDouble(),
    total: (j['total'] as num?)?.toDouble(),
    embalagemG: (j['embalagem_g'] as num?)?.toDouble(),
    nomeGenerico: (j['nome_generico'] ?? '').toString().trim(),
    marca: (j['marca'] ?? '').toString().trim(),
    consumivel: j['tipo_item'] == 'consumivel',
    categoriaConsumivel: (j['categoria_consumivel'] ?? '').toString().trim(),
  );
}

class Fatura {
  const Fatura({
    required this.id,
    required this.tipo,
    required this.estado,
    this.fornecedor = '',
    this.numero = '',
    this.dataFatura = '',
    this.total = 0,
    this.iva = 0,
    this.ficheiro = '',
    this.dadosIa = const {},
    this.created = '',
  });

  final String id;
  final FaturaTipo tipo;
  final FaturaEstado estado;
  final String fornecedor;
  final String numero;
  final String dataFatura;
  final double total;
  final double iva;
  final String ficheiro;
  final Map<String, dynamic> dadosIa;
  final String created;

  bool get temFicheiro => ficheiro.isNotEmpty;

  bool get ficheiroEhPdf => ficheiro.toLowerCase().endsWith('.pdf');

  String get erroIa => (dadosIa['erro'] ?? '').toString();

  /// Se esta fatura foi marcada como duplicada, o id da original.
  String get duplicadaDe => (dadosIa['duplicada_de'] ?? '').toString();

  List<FaturaLinhaIa> get linhasIa {
    final l = dadosIa['linhas'];
    if (l is! List) return const [];
    return l
        .whereType<Map>()
        .map((e) => FaturaLinhaIa.fromJson(Map<String, dynamic>.from(e)))
        .where((x) => x.descricao.trim().isNotEmpty)
        .toList();
  }

  factory Fatura.fromRecord(RecordModel r) {
    // Um campo json vazio volta como "" (não {}) neste SDK — ler defensivamente.
    final rawDi = r.data['dados_ia'];
    final di = rawDi is Map
        ? Map<String, dynamic>.from(rawDi)
        : <String, dynamic>{};
    return Fatura(
      id: r.id,
      tipo: FaturaTipo.fromApi(r.getStringValue('tipo')),
      estado: FaturaEstado.fromApi(r.getStringValue('estado')),
      fornecedor: r.getStringValue('fornecedor'),
      numero: r.getStringValue('numero'),
      dataFatura: r.getStringValue('data_fatura'),
      total: r.getDoubleValue('total'),
      iva: r.getDoubleValue('iva'),
      ficheiro: r.getStringValue('ficheiro'),
      dadosIa: di,
      created: r.getStringValue('created'),
    );
  }
}

/// Ação a aplicar a uma linha de fatura ao confirmar.
enum AcaoFatura {
  preco,
  stock,
  ambos,
  ignorar;

  String get api => name;
  String get label => switch (this) {
    AcaoFatura.preco => 'Preço',
    AcaoFatura.stock => 'Stock',
    AcaoFatura.ambos => 'Preço + Stock',
    AcaoFatura.ignorar => 'Ignorar',
  };
}
