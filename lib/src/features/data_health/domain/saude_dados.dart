import '../../ingredients/domain/ingredient.dart';
import '../../tech_sheets/domain/tech_sheet.dart';

/// O que pode faltar nos dados.
enum TipoProblema {
  fichaSemPreco(
    'Produtos sem preço de venda',
    'Não entram na Rentabilidade nem na tabela de revendedores.',
    true,
  ),
  fichaSemCusto(
    'Produtos sem custo calculado',
    'A ficha não tem ingredientes (ou eles não têm preço): o lucro e a margem não se calculam.',
    true,
  ),
  fichaSemTempo(
    'Produtos sem tempo de assadura',
    'Sem lucro por hora de forno nem cronómetro ao assar.',
    false,
  ),
  fichaSemTemperatura(
    'Produtos sem temperatura do forno',
    'Não aparece "Assar a 170 °C durante 11 min".',
    false,
  ),
  ingredienteSemPreco(
    'Ingredientes sem preço',
    'O custo das fichas que os usam fica incompleto.',
    true,
  ),
  ingredienteSemNutricao(
    'Ingredientes sem informação nutricional',
    'A declaração nutricional dos produtos fica incompleta nas etiquetas.',
    false,
  );

  const TipoProblema(this.titulo, this.consequencia, this.essencial);

  final String titulo;

  /// O que se perde enquanto falta.
  final String consequencia;

  /// Afeta o dinheiro (preços e custos), por isso conta mais.
  final bool essencial;

  bool get eFicha => index <= TipoProblema.fichaSemTemperatura.index;
}

/// Uma coisa que falta preencher.
class ProblemaDados {
  const ProblemaDados({
    required this.tipo,
    required this.id,
    required this.nome,
  });

  final TipoProblema tipo;

  /// O id da ficha ou do ingrediente.
  final String id;
  final String nome;
}

/// O resultado da análise.
class RelatorioSaude {
  const RelatorioSaude({
    required this.problemas,
    required this.fichas,
    required this.ingredientes,
  });

  final List<ProblemaDados> problemas;
  final int fichas;
  final int ingredientes;

  /// Quantas verificações se fizeram (4 por ficha, 2 por ingrediente).
  int get verificacoes => fichas * 4 + ingredientes * 2;

  /// % do que está preenchido.
  double get completoPct => verificacoes == 0
      ? 100
      : (1 - problemas.length / verificacoes).clamp(0, 1) * 100;

  List<ProblemaDados> de(TipoProblema t) => [
    for (final p in problemas)
      if (p.tipo == t) p,
  ];

  /// Problemas que mexem com preços e custos.
  int get essenciais => problemas.where((p) => p.tipo.essencial).length;
}

/// Vê o que falta nas fichas e nos ingredientes (ignora o que está na lixeira).
RelatorioSaude analisarDados({
  required Iterable<FichaTecnica> fichas,
  required Iterable<Ingrediente> ingredientes,
}) {
  final out = <ProblemaDados>[];
  var nf = 0;
  for (final f in fichas) {
    if (f.deletado) continue;
    nf++;
    void falta(TipoProblema t) =>
        out.add(ProblemaDados(tipo: t, id: f.id, nome: _nomeFicha(f)));
    if (!f.temPrecoVenda) falta(TipoProblema.fichaSemPreco);
    if (f.custoProduto <= 0) falta(TipoProblema.fichaSemCusto);
    if (f.tempoAssaduraMin <= 0) falta(TipoProblema.fichaSemTempo);
    if (f.temperaturaFornoC <= 0) falta(TipoProblema.fichaSemTemperatura);
  }
  var ni = 0;
  for (final i in ingredientes) {
    if (i.deletado) continue;
    ni++;
    // os de fabrico próprio têm o custo da receita, não um preço de compra
    if (i.origem == OrigemIngrediente.comprado && i.preco <= 0) {
      out.add(
        ProblemaDados(
          tipo: TipoProblema.ingredienteSemPreco,
          id: i.id,
          nome: i.nome,
        ),
      );
    }
    if (!i.temNutri) {
      out.add(
        ProblemaDados(
          tipo: TipoProblema.ingredienteSemNutricao,
          id: i.id,
          nome: i.nome,
        ),
      );
    }
  }
  out.sort((a, b) {
    final c = a.tipo.index.compareTo(b.tipo.index);
    return c != 0 ? c : a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
  });
  return RelatorioSaude(problemas: out, fichas: nf, ingredientes: ni);
}

String _nomeFicha(FichaTecnica f) =>
    f.subnome.isEmpty ? f.nome : '${f.nome} · ${f.subnome}';
