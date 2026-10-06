/// Em que ponto está a lista de compras de uma produção acabada de agendar.
enum EstadoCompras {
  /// Ficou desligada ("Preparar também a lista de compras").
  naoPreparadas,

  /// Tentou-se preparar e falhou.
  erro,

  /// Há ingredientes por comprar.
  faltam,

  /// O stock chega: nada a comprar.
  chega,

  /// A produção não leva ingredientes que se comprem (nada a avaliar).
  vazia,
}

/// O que se mostra depois de agendar a produção do dia: o que ficou
/// agendado e o que falta comprar, num só sítio.
class ResumoPlanoPronto {
  const ResumoPlanoPronto({
    required this.rotulo,
    required this.produtos,
    this.semReceita = 0,
    this.compras = EstadoCompras.naoPreparadas,
    this.aComprar = 0,
    this.custo = 0,
    this.nomes = const [],
  });

  /// "amanhã", "Hoje", "Qui 9/10"…
  final String rotulo;

  /// Produtos que entraram na produção.
  final int produtos;

  /// Produtos que ficaram de fora por não terem receita de massa ligada.
  final int semReceita;

  final EstadoCompras compras;

  /// Quantos ingredientes faltam comprar.
  final int aComprar;

  /// Custo estimado do que falta comprar (0 = não se sabe).
  final double custo;

  /// Nomes dos ingredientes por comprar.
  final List<String> nomes;

  ResumoPlanoPronto comCompras({
    required EstadoCompras compras,
    int aComprar = 0,
    double custo = 0,
    List<String> nomes = const [],
  }) => ResumoPlanoPronto(
    rotulo: rotulo,
    produtos: produtos,
    semReceita: semReceita,
    compras: compras,
    aComprar: aComprar,
    custo: custo,
    nomes: nomes,
  );

  /// "3 produtos para amanhã".
  String get linhaProducao {
    final base = '$produtos produto${produtos == 1 ? '' : 's'} para $rotulo';
    return semReceita > 0
        ? '$base · $semReceita sem receita ligada ficou de fora'
        : base;
  }

  /// A frase das compras ("Faltam 4 ingredientes (≈ €23,40)").
  String linhaCompras(String Function(double) dinheiro) => switch (compras) {
    EstadoCompras.naoPreparadas => 'A lista de compras não foi preparada.',
    EstadoCompras.erro => 'Não consegui preparar a lista de compras.',
    EstadoCompras.chega => 'O stock chega: não falta comprar nada.',
    EstadoCompras.vazia => 'Sem ingredientes para comprar.',
    EstadoCompras.faltam =>
      'Falta${aComprar == 1 ? '' : 'm'} $aComprar '
          'ingrediente${aComprar == 1 ? '' : 's'}'
          '${custo > 0 ? ' (≈ ${dinheiro(custo)})' : ''}',
  };

  /// "Manteiga · Farinha · Açúcar e mais 2" (no máximo [max] nomes).
  String nomesResumidos({int max = 4}) {
    if (nomes.isEmpty) return '';
    final vistos = nomes.take(max).join(' · ');
    final resto = nomes.length - max;
    return resto > 0 ? '$vistos e mais $resto' : vistos;
  }

  /// A parte das compras está resolvida (nada a fazer).
  bool get comprasEmDia =>
      compras == EstadoCompras.chega || compras == EstadoCompras.vazia;
}
