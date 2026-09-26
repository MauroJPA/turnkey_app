/// Uma linha do resumo depois de analisar um ficheiro: o que ficou de cada documento.
class ItemResumo {
  const ItemResumo({
    required this.id,
    this.fornecedor = '',
    this.numero = '',
    this.data = '',
    this.estado = '',
    this.duplicada = false,
    this.erro = '',
    this.paginas = '',
    this.linhas = 0,
  });

  final String id;
  final String fornecedor;
  final String numero;
  final String data;
  final String estado;
  final bool duplicada;
  final String erro;

  /// Páginas do ficheiro original (ex.: "3-4").
  final String paginas;
  final int linhas;

  /// Lida sem problemas e com linhas para rever.
  bool get ok => !duplicada && estado != 'erro' && linhas > 0;

  factory ItemResumo.fromJson(Map<String, dynamic> j) => ItemResumo(
    id: (j['id'] ?? '').toString(),
    fornecedor: (j['fornecedor'] ?? '').toString(),
    numero: (j['numero'] ?? '').toString(),
    data: (j['data'] ?? '').toString(),
    estado: (j['estado'] ?? '').toString(),
    duplicada: j['duplicada'] == true,
    erro: (j['erro'] ?? '').toString(),
    paginas: (j['paginas'] ?? '').toString(),
    linhas: (j['linhas'] as num?)?.toInt() ?? 0,
  );
}

/// Resultado de analisar um ficheiro com várias faturas.
class ResumoAnalise {
  const ResumoAnalise({this.itens = const [], this.paginasSemFatura = ''});

  final List<ItemResumo> itens;

  /// Páginas em que a IA não reconheceu nenhuma fatura (ex.: "4-5, 40").
  final String paginasSemFatura;

  int get duplicadas => itens.where((i) => i.duplicada).length;
  int get comErro =>
      itens.where((i) => !i.duplicada && i.estado == 'erro').length;
  int get semLinhas => itens
      .where((i) => !i.duplicada && i.estado != 'erro' && i.linhas == 0)
      .length;
  int get novas => itens.where((i) => i.ok).length;

  bool get temAvisos =>
      duplicadas > 0 ||
      comErro > 0 ||
      semLinhas > 0 ||
      paginasSemFatura.isNotEmpty;

  factory ResumoAnalise.fromJson(Object? j) {
    if (j is! Map) return const ResumoAnalise();
    final itens = j['itens'];
    return ResumoAnalise(
      itens: [
        if (itens is List)
          for (final e in itens.whereType<Map>())
            ItemResumo.fromJson(Map<String, dynamic>.from(e)),
      ],
      paginasSemFatura: (j['paginasSemFatura'] ?? '').toString(),
    );
  }
}
