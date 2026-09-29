import 'package:pocketbase/pocketbase.dart';

import '../../../core/formatting/busca.dart';
import '../../../core/formatting/capitalizar.dart';

/// Categorias sugeridas ao escrever — não é uma lista fechada: qualquer
/// texto novo fica disponível para a empresa a partir daí (como marca/
/// fornecedor). "Bebida"/"Revenda" são para produtos comprados para vender
/// ao cliente (não entram nas receitas nem exigem ficha de segurança).
const kCategoriasConsumivelPadrao = <String>[
  'Limpeza',
  'Desinfeção',
  'Higiene',
  'Insumo',
  'Bebida',
  'Revenda',
  'Outro',
];

/// Limpeza e desinfeção levam ficha de dados de segurança por omissão; o
/// resto (incluindo Bebida/Revenda) não.
bool exigeFdsPorOmissaoPara(String categoria) {
  final c = normalizarBusca(categoria);
  return c == 'limpeza' || c == 'desinfecao';
}

enum TipoDocumento {
  fds('fds', 'Ficha de dados de segurança'),
  fichaTecnica('ficha_tecnica', 'Ficha técnica'),
  certificado('certificado', 'Certificado / declaração'),
  outro('outro', 'Outro');

  const TipoDocumento(this.api, this.label);
  final String api;
  final String label;

  static TipoDocumento fromApi(String s) =>
      values.firstWhere((t) => t.api == s, orElse: () => TipoDocumento.outro);
}

/// Produto de limpeza/desinfeção ou insumo que exige documentação.
class Consumivel {
  const Consumivel({
    required this.id,
    required this.nome,
    this.categoria = 'Limpeza',
    this.caracteristica = '',
    this.marca = '',
    this.fornecedor = '',
    this.embalagem = '',
    this.preco = 0,
    this.precoVenda = 0,
    this.precoAtualizadoEm,
    this.exigeFds = true,
    this.notas = '',
    this.nomesFatura = const [],
  });

  final String id;
  final String nome;
  final String categoria;

  /// O que distingue esta variante (tamanho, sabor, aroma…). Opcional.
  final String caracteristica;
  final String marca;
  final String fornecedor;
  final String embalagem;
  final double preco;

  /// Preço a que se vende ao cliente (Bebidas/Revenda) — 0 se não se aplica.
  final double precoVenda;
  final DateTime? precoAtualizadoEm;
  final bool exigeFds;
  final String notas;

  /// Descrições de fatura (normalizadas) já associadas a este item.
  final List<String> nomesFatura;

  bool get temPrecoVenda => precoVenda > 0;

  String get nomeComCaracteristica =>
      caracteristica.trim().isEmpty ? nome : '$nome ${caracteristica.trim()}';

  factory Consumivel.fromRecord(RecordModel r) {
    final nomes = r.data['nomes_fatura'];
    return Consumivel(
      id: r.id,
      nome: r.getStringValue('nome'),
      categoria: r.getStringValue('categoria'),
      caracteristica: r.getStringValue('caracteristica'),
      marca: r.getStringValue('marca'),
      fornecedor: r.getStringValue('fornecedor'),
      embalagem: r.getStringValue('embalagem'),
      preco: r.getDoubleValue('preco'),
      precoVenda: r.getDoubleValue('preco_venda'),
      precoAtualizadoEm: DateTime.tryParse(
        r.getStringValue('preco_atualizado_em'),
      ),
      exigeFds: r.getBoolValue('exige_fds'),
      notas: r.getStringValue('notas'),
      nomesFatura: nomes is List
          ? [for (final n in nomes) n.toString()]
          : const [],
    );
  }
}

class ConsumivelInput {
  const ConsumivelInput({
    required this.nome,
    this.categoria = 'Limpeza',
    this.caracteristica = '',
    this.marca = '',
    this.fornecedor = '',
    this.embalagem = '',
    this.preco = 0,
    this.precoVenda = 0,
    this.exigeFds = true,
    this.notas = '',
  });

  final String nome;
  final String categoria;
  final String caracteristica;
  final String marca;
  final String fornecedor;
  final String embalagem;
  final double preco;
  final double precoVenda;
  final bool exigeFds;
  final String notas;

  factory ConsumivelInput.fromModel(Consumivel c) => ConsumivelInput(
    nome: c.nome,
    categoria: c.categoria,
    caracteristica: c.caracteristica,
    marca: c.marca,
    fornecedor: c.fornecedor,
    embalagem: c.embalagem,
    preco: c.preco,
    precoVenda: c.precoVenda,
    exigeFds: c.exigeFds,
    notas: c.notas,
  );

  Map<String, dynamic> toBody() => {
    'nome': capitalizarInicial(nome.trim()),
    'categoria': categoria.trim().isEmpty
        ? 'Outro'
        : capitalizarInicial(categoria.trim()),
    'caracteristica': caracteristica.trim(),
    'marca': marca.trim(),
    'fornecedor': fornecedor.trim(),
    'embalagem': embalagem.trim(),
    'preco': preco,
    'preco_venda': precoVenda,
    'exige_fds': exigeFds,
    'notas': notas.trim(),
    'deletado': false,
  };
}

/// Um ficheiro anexado a um consumível (FDS, ficha técnica, certificado…).
class DocumentoConsumivel {
  const DocumentoConsumivel({
    required this.id,
    required this.consumivelId,
    required this.tipo,
    required this.ficheiro,
    this.titulo = '',
    this.versao = '',
    this.dataDocumento,
    this.criadoEm,
  });

  final String id;
  final String consumivelId;
  final TipoDocumento tipo;
  final String ficheiro;
  final String titulo;
  final String versao;
  final DateTime? dataDocumento;
  final DateTime? criadoEm;

  /// Data que conta para saber se o documento está atualizado.
  DateTime? get dataEfetiva => dataDocumento ?? criadoEm;

  String get nomeVisivel => titulo.isNotEmpty ? titulo : tipo.label;

  factory DocumentoConsumivel.fromRecord(RecordModel r) => DocumentoConsumivel(
    id: r.id,
    consumivelId: r.getStringValue('consumivel'),
    tipo: TipoDocumento.fromApi(r.getStringValue('tipo')),
    ficheiro: r.getStringValue('ficheiro'),
    titulo: r.getStringValue('titulo'),
    versao: r.getStringValue('versao'),
    dataDocumento: DateTime.tryParse(r.getStringValue('data_documento')),
    criadoEm: DateTime.tryParse(r.getStringValue('created')),
  );
}

/// Situação da documentação de um consumível.
enum EstadoFds {
  /// Não exige ficha de segurança.
  naoExige,

  /// Tem FDS recente.
  ok,

  /// Tem FDS mas com mais de [idadeMaximaFds] — confirmar se há revisão nova.
  antiga,

  /// Exige e não tem.
  falta,
}

/// Idade a partir da qual se sugere confirmar se existe uma FDS mais recente
/// (o fornecedor tem de a rever quando há alterações; 3 anos é só um aviso).
const idadeMaximaFds = Duration(days: 365 * 3);

EstadoFds estadoFds(
  Consumivel c,
  Iterable<DocumentoConsumivel> docs, {
  DateTime? agora,
}) {
  if (!c.exigeFds) return EstadoFds.naoExige;
  final fds = docs.where((d) => d.tipo == TipoDocumento.fds).toList();
  if (fds.isEmpty) return EstadoFds.falta;
  DateTime? maisRecente;
  for (final d in fds) {
    final dt = d.dataEfetiva;
    if (dt == null) continue;
    if (maisRecente == null || dt.isAfter(maisRecente)) maisRecente = dt;
  }
  if (maisRecente == null) return EstadoFds.ok;
  return (agora ?? DateTime.now()).difference(maisRecente) > idadeMaximaFds
      ? EstadoFds.antiga
      : EstadoFds.ok;
}
