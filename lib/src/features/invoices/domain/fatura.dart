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
  erro,
  ignorada;

  static FaturaEstado fromApi(String? v) => FaturaEstado.values.firstWhere(
    (e) => e.name == v,
    orElse: () => FaturaEstado.nova,
  );
  String get label => switch (this) {
    FaturaEstado.nova => 'Nova',
    FaturaEstado.analisada => 'Analisada',
    FaturaEstado.confirmada => 'Confirmada',
    FaturaEstado.erro => 'Erro',
    // faturas antigas que ninguém vai validar (preço/stock) — os ficheiros
    // ficam guardados, só não pedem revisão (ver Faturas → Selecionar).
    FaturaEstado.ignorada => 'Ignorada',
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
    this.embalagemUnidade = 'g',
    this.caracteristica = '',
    this.nomeGenerico = '',
    this.marca = '',
    this.consumivel = false,
    this.categoriaConsumivel = '',
    this.embalagem = false,
    this.tipoEmbalagem = '',
  });

  final String descricao;

  /// Unidade da embalagem (`embalagem_g` está nela): `g` (por omissão), `ml` ou `un`.
  final String embalagemUnidade;

  /// Característica que distingue variedades do mesmo ingrediente (T55, T65,
  /// integral, 70% cacau…). Vazio se não houver.
  final String caracteristica;

  /// Ingrediente em termos genéricos, sem marca nem embalagem (sugestão da IA).
  final String nomeGenerico;

  /// Marca comercial lida da linha (vazio se não houver).
  final String marca;

  /// A IA acha que é limpeza/insumo (não um ingrediente).
  final bool consumivel;

  /// `limpeza`, `desinfecao`, `higiene`, `insumo` ou `outro` (só se [consumivel]).
  final String categoriaConsumivel;

  /// A IA acha que é material de embalar (caixa, saco, adesivo…), não um
  /// ingrediente nem um consumível de limpeza.
  final bool embalagem;

  /// `Caixa`, `Saco`, `Saqueta`, `Adesivo`, `Fita`, `Cartão` ou `Outro` (só se
  /// [embalagem]) — ver `kTiposEmbalagem`.
  final String tipoEmbalagem;
  final double? quantidade;
  final String unidade;
  final double? precoUnitario;
  final double? total;
  final double? embalagemG;

  String get _u => unidade.toLowerCase().trim().replaceAll('.', '');

  /// A quantidade vem em peso/volume (g, kg, l, ml…)? Caso contrário conta
  /// embalagens/unidades ("2 un" de 15 g são 30 g).
  bool get unidadeEPeso =>
      const {'g', 'gr', 'grs', 'kg', 'l', 'lt', 'ml', 'cl', 'dl'}.contains(_u);

  /// A quantidade vem em volume (l, ml, cl, dl)?
  bool get unidadeEVolume => const {'l', 'lt', 'ml', 'cl', 'dl'}.contains(_u);

  /// A quantidade lida conta embalagens e sabe-se o peso de cada uma.
  bool get contaEmbalagens => !unidadeEPeso && (embalagemG ?? 0) > 0;

  /// Quantidade convertida para gramas (kg/L -> g/ml aproximado). Em unidades
  /// ("2 un") multiplica pelo peso da embalagem, se se conhecer.
  double get quantidadeG {
    final q = quantidade ?? 0;
    switch (_u) {
      case 'kg' || 'l' || 'lt':
        return q * 1000;
      case 'dl':
        return q * 100;
      case 'cl':
        return q * 10;
      case 'g' || 'gr' || 'grs' || 'ml':
        return q;
    }
    return contaEmbalagens ? q * embalagemG! : q;
  }

  factory FaturaLinhaIa.fromJson(Map<String, dynamic> j) => FaturaLinhaIa(
    descricao: (j['descricao'] ?? j['nome'] ?? '').toString(),
    quantidade: (j['quantidade'] as num?)?.toDouble(),
    unidade: (j['unidade'] ?? '').toString(),
    precoUnitario: (j['preco_unitario'] as num?)?.toDouble(),
    total: (j['total'] as num?)?.toDouble(),
    embalagemG: (j['embalagem_g'] as num?)?.toDouble(),
    embalagemUnidade: switch ((j['embalagem_unidade'] ?? '')
        .toString()
        .trim()
        .toLowerCase()) {
      'ml' => 'ml',
      'un' => 'un',
      _ => 'g',
    },
    caracteristica: (j['caracteristica'] ?? '').toString().trim(),
    nomeGenerico: (j['nome_generico'] ?? '').toString().trim(),
    marca: (j['marca'] ?? '').toString().trim(),
    consumivel: j['tipo_item'] == 'consumivel',
    categoriaConsumivel: (j['categoria_consumivel'] ?? '').toString().trim(),
    embalagem: j['tipo_item'] == 'embalagem',
    tipoEmbalagem: (j['tipo_embalagem'] ?? '').toString().trim(),
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
    this.apagada = false,
    this.apagadaEm = '',
    this.apagadaPor = '',
    this.pendentesLinhas = 0,
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

  /// Apagada pelo proprietário: fica escondida (e na base de dados) e pode ser restaurada.
  final bool apagada;
  final String apagadaEm;
  final String apagadaPor;

  /// Linhas já vistas mas ainda sem decisão ("por rever depois") — não
  /// bloqueiam aplicar as restantes; ficam à espera de mais informação.
  final int pendentesLinhas;

  bool get temPendentes => pendentesLinhas > 0;

  bool get temFicheiro => ficheiro.isNotEmpty;

  bool get ficheiroEhPdf => ficheiro.toLowerCase().endsWith('.pdf');

  String get erroIa => (dadosIa['erro'] ?? '').toString();

  Map<String, dynamic>? get _lote {
    final l = dadosIa['lote'];
    return l is Map ? Map<String, dynamic>.from(l) : null;
  }

  /// Análise por janelas de páginas (ficheiros grandes) já começada.
  bool get temLote => _lote != null;

  /// Páginas do ficheiro (se a análise por janelas foi preparada).
  int get lotePaginas => (_lote?['paginas'] as num?)?.toInt() ?? 0;

  /// Páginas já lidas pela IA.
  int get loteFeitas {
    final p = (_lote?['proxima'] as num?)?.toInt() ?? 1;
    return (p - 1).clamp(0, lotePaginas);
  }

  /// Carregada mas a análise não chegou ao fim (a app fechou ou houve um erro).
  bool get analiseAMeio => estado == FaturaEstado.nova;

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
      apagada: r.getBoolValue('apagada'),
      apagadaEm: r.getStringValue('apagada_em'),
      apagadaPor: r.getStringValue('apagada_por'),
      pendentesLinhas: r.getDoubleValue('pendentes_linhas').round(),
    );
  }
}

/// Ação a aplicar a uma linha de fatura ao confirmar.
enum AcaoFatura {
  preco,
  stock,
  ambos,
  pendente,
  ignorar;

  String get api => name;
  String get label => switch (this) {
    AcaoFatura.preco => 'Preço',
    AcaoFatura.stock => 'Stock',
    AcaoFatura.ambos => 'Preço + Stock',
    AcaoFatura.pendente => 'Por rever depois',
    AcaoFatura.ignorar => 'Ignorar',
  };

  /// Vai mesmo atualizar preço/stock agora (ao contrário de "pendente" ou
  /// "ignorar", que não têm efeito nenhum nesta ronda).
  bool get aplicaAgora => this == preco || this == stock || this == ambos;
}

String? _naoVazio(String v) => v.isEmpty ? null : v;

/// A linha de índice [index] desta fatura já foi gravada numa ronda anterior
/// de "Aplicar" — para reabrir a revisão sem repetir o que já está decidido.
class ItemFaturaAnterior {
  const ItemFaturaAnterior({
    required this.index,
    required this.aplicado,
    required this.acao,
    this.ingredienteId,
    this.consumivelId,
    this.embalagemId,
    this.produtoId,
    this.descricaoFatura = '',
    this.marca = '',
    this.fornecedor = '',
  });

  final int index;

  /// Preço/stock já atualizados com esta linha — não se toca mais nela.
  final bool aplicado;
  final AcaoFatura acao;
  final String? ingredienteId;
  final String? consumivelId;
  final String? embalagemId;

  /// Produto de compra (marca) tocado por esta linha — só existe quando o
  /// preço já foi aplicado a um ingrediente. `null` = ainda não há nada para
  /// corrigir (ex.: linha "só stock" ou por rever).
  final String? produtoId;

  final String descricaoFatura;

  /// Marca/fornecedor que ficaram gravados ao aplicar — para mostrar e dar
  /// para o proprietário/administrador corrigir, mesmo com a linha já
  /// aplicada (ver `InvoiceRepository.corrigirItem`).
  final String marca;
  final String fornecedor;

  /// Há um registo (produto/consumível/embalagem) ligado a esta linha para
  /// corrigir marca/fornecedor.
  bool get temAlvoParaCorrigir =>
      produtoId != null || consumivelId != null || embalagemId != null;

  factory ItemFaturaAnterior.fromRecord(RecordModel r) => ItemFaturaAnterior(
    index: r.getDoubleValue('linha_index').round(),
    aplicado: r.getBoolValue('aplicado'),
    acao: AcaoFatura.values.firstWhere(
      (a) => a.api == r.getStringValue('acao'),
      orElse: () => AcaoFatura.pendente,
    ),
    ingredienteId: _naoVazio(r.getStringValue('ingrediente')),
    consumivelId: _naoVazio(r.getStringValue('consumivel')),
    embalagemId: _naoVazio(r.getStringValue('embalagem')),
    produtoId: _naoVazio(r.getStringValue('produto')),
    descricaoFatura: r.getStringValue('descricao_fatura'),
    marca: r.getStringValue('marca'),
    fornecedor: r.getStringValue('fornecedor'),
  );
}
