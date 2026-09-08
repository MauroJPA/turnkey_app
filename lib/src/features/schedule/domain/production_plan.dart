import 'package:pocketbase/pocketbase.dart';

/// Título por omissão de uma produção: "Produção de hoje" ou
/// "Produção DD/MM/AAAA", com os nomes das receitas se houver.
String tituloPadraoProducao(DateTime data, List<String> nomesReceitas) {
  final hoje = DateTime.now();
  final ehHoje = data.year == hoje.year &&
      data.month == hoje.month &&
      data.day == hoje.day;
  final dd = data.day.toString().padLeft(2, '0');
  final mm = data.month.toString().padLeft(2, '0');
  final base = ehHoje ? 'Produção de hoje' : 'Produção $dd/$mm/${data.year}';
  final nomes = nomesReceitas.where((n) => n.trim().isNotEmpty).toList();
  if (nomes.isEmpty) return base;
  final lista = nomes.take(3).join(', ') + (nomes.length > 3 ? '…' : '');
  return '$base - $lista';
}

/// Prioridade de uma linha da agenda.
enum Prioridade {
  alta,
  media,
  baixa;

  static Prioridade fromApi(String? v) => Prioridade.values.firstWhere(
        (p) => p.name == v,
        orElse: () => Prioridade.media,
      );

  String get api => name;

  String get label => switch (this) {
        Prioridade.alta => 'Alta',
        Prioridade.media => 'Média',
        Prioridade.baixa => 'Baixa',
      };

  /// Peso para ordenar (0 = mais urgente).
  int get peso => switch (this) {
        Prioridade.alta => 0,
        Prioridade.media => 1,
        Prioridade.baixa => 2,
      };
}

/// Estado de um plano de produção.
enum EstadoProducao {
  planeada,
  concluida,
  cancelada;

  static EstadoProducao fromApi(String? v) => EstadoProducao.values.firstWhere(
        (e) => e.name == v,
        orElse: () => EstadoProducao.planeada,
      );

  String get api => name;

  String get label => switch (this) {
        EstadoProducao.planeada => 'Planeada',
        EstadoProducao.concluida => 'Concluída',
        EstadoProducao.cancelada => 'Cancelada',
      };
}

/// Um plano de produção para um dia: cabeçalho (data, título, estado).
class ProducaoPlan {
  const ProducaoPlan({
    required this.id,
    required this.data,
    required this.titulo,
    required this.estado,
    this.notas = '',
    this.concluidaEm,
    this.custoSnapshot = 0,
  });

  final String id;
  final DateTime data;
  final String titulo;
  final EstadoProducao estado;
  final String notas;
  final DateTime? concluidaEm;
  final double custoSnapshot;

  bool get concluida => estado == EstadoProducao.concluida;

  factory ProducaoPlan.fromRecord(RecordModel r) {
    DateTime? parseDate(String f) {
      final s = r.getStringValue(f);
      if (s.isEmpty) return null;
      return DateTime.tryParse(s);
    }

    return ProducaoPlan(
      id: r.id,
      data: parseDate('data') ?? DateTime.now(),
      titulo: r.getStringValue('titulo'),
      estado: EstadoProducao.fromApi(r.getStringValue('estado')),
      notas: r.getStringValue('notas'),
      concluidaEm: parseDate('concluida_em'),
      custoSnapshot: r.getDoubleValue('custo_snapshot'),
    );
  }
}

/// Uma linha do plano: uma receita e a quantidade a produzir (em kg),
/// com formato de cookie, recheio, prioridade e hora limite.
class ProducaoItem {
  const ProducaoItem({
    required this.id,
    required this.receitaId,
    required this.nome,
    required this.quantidadeKg,
    this.formatoNome = '',
    this.recheioNome = '',
    this.prioridade = Prioridade.media,
    this.horaLimite = '',
    this.unidadesPrevistas = 0,
  });

  final String id;
  final String receitaId;
  final String nome;
  final double quantidadeKg;
  final String formatoNome;
  final String recheioNome;
  final Prioridade prioridade;
  final String horaLimite;
  final int unidadesPrevistas;

  factory ProducaoItem.fromRecord(RecordModel r) {
    String expNome(String rel) {
      final e = r.get<List<RecordModel>>('expand.$rel', const []);
      return e.isNotEmpty ? e.first.getStringValue('nome') : '';
    }

    return ProducaoItem(
      id: r.id,
      receitaId: r.getStringValue('receita'),
      nome: expNome('receita'),
      quantidadeKg: r.getDoubleValue('quantidade_kg'),
      formatoNome: expNome('formato'),
      recheioNome: expNome('recheio'),
      prioridade: Prioridade.fromApi(r.getStringValue('prioridade')),
      horaLimite: r.getStringValue('hora_limite'),
      unidadesPrevistas: r.getIntValue('unidades_previstas'),
    );
  }
}

/// Um ingrediente necessário para o plano (resultado da explosão server-side).
class PlanoNecessario {
  const PlanoNecessario({
    required this.ingredienteId,
    required this.nome,
    required this.fornecedor,
    required this.gramas,
    required this.custo,
    required this.emStock,
    required this.aComprar,
    this.embalagemG = 0,
    this.aComprarSacos = 0,
  });

  final String ingredienteId;
  final String nome;
  final String fornecedor;
  final double gramas;
  final double custo;
  final double emStock;
  final double aComprar;
  final double embalagemG;
  final int aComprarSacos;

  factory PlanoNecessario.fromJson(Map<String, dynamic> j) => PlanoNecessario(
        ingredienteId: j['ingredienteId'] as String? ?? '',
        nome: j['nome'] as String? ?? '',
        fornecedor: j['fornecedor'] as String? ?? '',
        gramas: (j['gramas'] as num?)?.toDouble() ?? 0,
        custo: (j['custo'] as num?)?.toDouble() ?? 0,
        emStock: (j['emStock'] as num?)?.toDouble() ?? 0,
        aComprar: (j['aComprar'] as num?)?.toDouble() ?? 0,
        embalagemG: (j['embalagemG'] as num?)?.toDouble() ?? 0,
        aComprarSacos: (j['aComprarSacos'] as num?)?.toInt() ?? 0,
      );
}

/// Uma receita a produzir (linha de `produzir` no plano).
class PlanoProduzir {
  const PlanoProduzir({
    required this.receitaId,
    required this.nome,
    required this.kg,
    this.unidades = 0,
    this.formato = '',
    this.recheio = '',
    this.prioridade = Prioridade.media,
    this.horaLimite = '',
  });

  final String receitaId;
  final String nome;
  final double kg;
  final int unidades;
  final String formato;
  final String recheio;
  final Prioridade prioridade;
  final String horaLimite;

  factory PlanoProduzir.fromJson(Map<String, dynamic> j) => PlanoProduzir(
        receitaId: j['receitaId'] as String? ?? '',
        nome: j['nome'] as String? ?? '',
        kg: (j['kg'] as num?)?.toDouble() ?? 0,
        unidades: (j['unidades'] as num?)?.toInt() ?? 0,
        formato: j['formato'] as String? ?? '',
        recheio: j['recheio'] as String? ?? '',
        prioridade: Prioridade.fromApi(j['prioridade'] as String?),
        horaLimite: j['horaLimite'] as String? ?? '',
      );
}

/// Uma quantidade de um item (ingrediente ou intermédio) numa receita.
class PlanoQtd {
  const PlanoQtd({required this.nome, required this.gramas});
  final String nome;
  final double gramas;

  factory PlanoQtd.fromJson(Map<String, dynamic> j) => PlanoQtd(
        nome: j['nome'] as String? ?? '',
        gramas: (j['gramas'] as num?)?.toDouble() ?? 0,
      );
}

/// Detalhe de UMA receita do plano — para o "mise en place".
class PlanoPorReceita {
  const PlanoPorReceita({
    required this.receitaId,
    required this.nome,
    required this.kg,
    this.unidades = 0,
    this.formato = '',
    this.recheio = '',
    this.comprar = const [],
    this.intermedios = const [],
  });

  final String receitaId;
  final String nome;
  final double kg;
  final int unidades;
  final String formato;
  final String recheio;
  final List<PlanoQtd> comprar;
  final List<PlanoQtd> intermedios;

  factory PlanoPorReceita.fromJson(Map<String, dynamic> j) => PlanoPorReceita(
        receitaId: j['receitaId'] as String? ?? '',
        nome: j['nome'] as String? ?? '',
        kg: (j['kg'] as num?)?.toDouble() ?? 0,
        unidades: (j['unidades'] as num?)?.toInt() ?? 0,
        formato: j['formato'] as String? ?? '',
        recheio: j['recheio'] as String? ?? '',
        comprar: ((j['comprar'] as List?) ?? const [])
            .map((e) => PlanoQtd.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        intermedios: ((j['intermedios'] as List?) ?? const [])
            .map((e) => PlanoQtd.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// Resposta agregada de `GET /api/turnkey/producoes/{id}/plano`.
class PlanoResposta {
  const PlanoResposta({
    required this.necessarios,
    required this.produzir,
    required this.custoTotal,
    this.porReceita = const [],
  });

  final List<PlanoNecessario> necessarios;
  final List<PlanoProduzir> produzir;
  final List<PlanoPorReceita> porReceita;
  final double custoTotal;

  double get totalAComprar =>
      necessarios.fold(0, (s, n) => s + n.aComprar);

  factory PlanoResposta.fromJson(Map<String, dynamic> j) => PlanoResposta(
        necessarios: ((j['necessarios'] as List?) ?? const [])
            .map((e) => PlanoNecessario.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ))
            .toList(),
        produzir: ((j['produzir'] as List?) ?? const [])
            .map((e) => PlanoProduzir.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ))
            .toList(),
        porReceita: ((j['porReceita'] as List?) ?? const [])
            .map((e) => PlanoPorReceita.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ))
            .toList(),
        custoTotal: (j['custoTotal'] as num?)?.toDouble() ?? 0,
      );
}

/// Movimento (consumo ou saída) devolvido por `.../concluir`.
class MovimentoResumo {
  const MovimentoResumo({required this.nome, required this.gramas});

  final String nome;
  final double gramas;

  factory MovimentoResumo.fromJson(Map<String, dynamic> j) => MovimentoResumo(
        nome: j['nome'] as String? ?? '',
        gramas: (j['gramas'] as num?)?.toDouble() ?? 0,
      );
}

/// Um componente da ficha (recheio, cobertura, extra) com a quantidade por
/// unidade produzida.
class FichaComponente {
  const FichaComponente({
    required this.slot,
    required this.nome,
    required this.gPorUnidade,
  });

  final String slot;
  final String nome;
  final double gPorUnidade;

  String get slotLabel => switch (slot) {
        'recheio_base' => 'Recheio',
        'recheio_top' => 'Recheio (topo)',
        'cobertura_base' => 'Cobertura',
        'cobertura_top' => 'Cobertura (topo)',
        _ => 'Extra',
      };

  factory FichaComponente.fromJson(Map<String, dynamic> j) => FichaComponente(
        slot: j['slot'] as String? ?? 'extra',
        nome: j['nome'] as String? ?? '',
        gPorUnidade: (j['gPorUnidade'] as num?)?.toDouble() ?? 0,
      );
}

/// Resposta de `GET /api/turnkey/fichas/resolver`.
class FichaResolvida {
  const FichaResolvida({
    required this.fichaId,
    this.nome = '',
    this.componentes = const [],
  });

  final String fichaId;
  final String nome;
  final List<FichaComponente> componentes;

  bool get existe => fichaId.isNotEmpty;

  factory FichaResolvida.fromJson(Map<String, dynamic> j) => FichaResolvida(
        fichaId: j['fichaId'] as String? ?? '',
        nome: j['nome'] as String? ?? '',
        componentes: ((j['componentes'] as List?) ?? const [])
            .map((e) => FichaComponente.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ))
            .toList(),
      );
}

/// Resposta de `POST /api/turnkey/producoes/{id}/concluir`.
class ConclusaoResumo {
  const ConclusaoResumo({
    required this.consumos,
    required this.saidas,
    required this.faltas,
    required this.custoTotal,
  });

  final List<MovimentoResumo> consumos;
  final List<MovimentoResumo> saidas;
  final List<String> faltas;
  final double custoTotal;

  factory ConclusaoResumo.fromJson(Map<String, dynamic> j) => ConclusaoResumo(
        consumos: ((j['consumos'] as List?) ?? const [])
            .map((e) => MovimentoResumo.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ))
            .toList(),
        saidas: ((j['saidas'] as List?) ?? const [])
            .map((e) => MovimentoResumo.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ))
            .toList(),
        faltas: ((j['faltas'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        custoTotal: (j['custoTotal'] as num?)?.toDouble() ?? 0,
      );
}
