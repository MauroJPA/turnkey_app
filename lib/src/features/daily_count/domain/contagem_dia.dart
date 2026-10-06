import '../../sales/domain/venda.dart';
import 'local.dart';
import 'movimento_produto.dart';

DateTime _dia(DateTime d) => DateTime(d.year, d.month, d.day);

/// Unidades vendidas de um sabor num local e dia (vem das vendas).
class VendaDoLocal {
  const VendaDoLocal({
    required this.localId,
    required this.data,
    required this.fichaId,
    required this.quantidade,
  });

  final String localId;
  final DateTime data;
  final String fichaId;
  final double quantidade;
}

/// Reparte as linhas de venda pelos locais, pelo canal da venda.
List<VendaDoLocal> vendasPorLocal({
  required List<Venda> vendas,
  required List<VendaItem> itens,
  required List<Local> locais,
}) {
  final porVenda = {for (final v in vendas) v.id: v};
  final out = <VendaDoLocal>[];
  for (final it in itens) {
    final f = it.fichaId;
    final v = porVenda[it.vendaId];
    if (f == null || v == null || it.quantidade <= 0) continue;
    final local = localDoCanal(v.canal, locais);
    if (local == null) continue;
    out.add(
      VendaDoLocal(
        localId: local.id,
        data: _dia(v.data),
        fichaId: f,
        quantidade: it.quantidade,
      ),
    );
  }
  return out;
}

/// A conta do dia de UM sabor em UM local.
class LinhaContagem {
  const LinhaContagem({
    required this.fichaId,
    required this.abertura,
    required this.aberturaContada,
    required this.fechoAnterior,
    required this.diferencaAbertura,
    required this.assados,
    required this.recebido,
    required this.enviado,
    required this.vendido,
    required this.desperdicio,
    required this.fecho,
    this.fechoAnteriorEstimado = false,
  });

  final String fichaId;

  /// Cookies no início do dia: a contagem de abertura, ou — se não houve — o
  /// que ficou do dia anterior (contado ou estimado pelas contas).
  final double abertura;

  /// `true` se [abertura] foi contada nesse dia (e não herdada do dia anterior).
  final bool aberturaContada;

  /// O que ficou do dia anterior: a contagem de fecho, ou — se ninguém
  /// contou — o que devia ter ficado pelas contas (assados − vendas − perdas…).
  /// `null` se não há dias anteriores com registos.
  final double? fechoAnterior;

  /// `true` quando [fechoAnterior] não foi contado: é a estimativa da app.
  final bool fechoAnteriorEstimado;

  /// Contagem de abertura − [fechoAnterior] (o que "desapareceu" de uma noite
  /// para a manhã); `null` se não se pode comparar.
  final double? diferencaAbertura;

  final double assados;
  final double recebido;
  final double enviado;
  final double vendido;
  final double desperdicio;

  /// O que foi contado no fim do dia; `null` = ainda não contado.
  final double? fecho;

  /// O que devia haver no fim do dia pelas contas.
  double get esperado =>
      abertura + assados + recebido - enviado - vendido - desperdicio;

  /// Contado − esperado: negativo = faltam cookies sem explicação (quebra);
  /// positivo = há mais do que as contas dizem. `null` se não foi contado.
  double? get diferenca => fecho == null ? null : fecho! - esperado;

  bool get temMovimento =>
      assados != 0 ||
      recebido != 0 ||
      enviado != 0 ||
      vendido != 0 ||
      desperdicio != 0 ||
      abertura != 0 ||
      fecho != null;
}

/// Totais de UM sabor num dia (para as contas do dia a dia).
class _Dia {
  double? abertura;
  double? fecho;
  double assados = 0;
  double recebido = 0;
  double enviado = 0;
  double vendido = 0;
  double desperdicio = 0;

  double get saldo => assados + recebido - enviado - vendido - desperdicio;
}

/// Calcula a contagem de um [dia] num [localId], para cada ficha em
/// [fichaIds]. [movimentos] e [vendas] devem incluir o histórico recente: é
/// dele que se sabe o que ficou do dia anterior. Se ninguém contou o fecho
/// de um dia, a app estima-o pelas contas desse dia (abertura + assados +
/// recebidos − enviados − vendidos − perdas), para a abertura do dia seguinte
/// já vir preenchida.
List<LinhaContagem> calcularContagemDia({
  required String localId,
  required DateTime dia,
  required Iterable<String> fichaIds,
  required List<MovimentoProduto> movimentos,
  required List<VendaDoLocal> vendas,
}) {
  final d = _dia(dia);

  // totais por sabor e por dia
  final porFicha = <String, Map<DateTime, _Dia>>{};
  _Dia acc(String ficha, DateTime data) =>
      (porFicha[ficha] ??= {})[_dia(data)] ??= _Dia();

  for (final m in movimentos) {
    if (m.localId != localId && m.destinoId != localId) continue;
    final a = acc(m.fichaId, m.data);
    switch (m.tipo) {
      case TipoMovimento.producao:
        if (m.localId == localId) a.assados += m.quantidade;
      case TipoMovimento.transferencia:
        if (m.destinoId == localId) a.recebido += m.quantidade;
        if (m.localId == localId) a.enviado += m.quantidade;
      case TipoMovimento.desperdicio:
        if (m.localId == localId) a.desperdicio += m.quantidade;
      case TipoMovimento.contagemAbertura:
        if (m.localId == localId) a.abertura = m.quantidade;
      case TipoMovimento.contagemFecho:
        if (m.localId == localId) a.fecho = m.quantidade;
    }
  }
  for (final v in vendas) {
    if (v.localId == localId) acc(v.fichaId, v.data).vendido += v.quantidade;
  }

  final out = <LinhaContagem>[];
  for (final f in fichaIds) {
    final dias = porFicha[f] ?? const <DateTime, _Dia>{};

    // o que ficou dos dias anteriores, dia a dia, por ordem
    double? carry;
    var estimado = false;
    final anteriores = dias.keys.where((x) => x.isBefore(d)).toList()..sort();
    for (final x in anteriores) {
      final a = dias[x]!;
      // sem contagens nem produção, ainda não há de onde partir
      if (carry == null &&
          a.abertura == null &&
          a.fecho == null &&
          a.assados == 0 &&
          a.recebido == 0) {
        continue;
      }
      final ab = a.abertura ?? carry ?? 0;
      if (a.fecho != null) {
        carry = a.fecho;
        estimado = false;
      } else {
        final fim = ab + a.saldo;
        carry = fim < 0 ? 0 : fim;
        estimado = true;
      }
    }

    final hoje = dias[d];
    final aberturaContada = hoje?.abertura != null;
    final abertura = hoje?.abertura ?? carry ?? 0;
    out.add(
      LinhaContagem(
        fichaId: f,
        abertura: abertura,
        aberturaContada: aberturaContada,
        fechoAnterior: carry,
        fechoAnteriorEstimado: carry != null && estimado,
        diferencaAbertura: aberturaContada && carry != null
            ? hoje!.abertura! - carry
            : null,
        assados: hoje?.assados ?? 0,
        recebido: hoje?.recebido ?? 0,
        enviado: hoje?.enviado ?? 0,
        vendido: hoje?.vendido ?? 0,
        desperdicio: hoje?.desperdicio ?? 0,
        fecho: hoje?.fecho,
      ),
    );
  }
  return out;
}

// ---------------------------------------------------------------------------
// relatórios por período
// ---------------------------------------------------------------------------

/// Desperdício num período: totais, por motivo, por sabor e por local.
class ResumoDesperdicio {
  const ResumoDesperdicio({
    required this.unidades,
    required this.custo,
    required this.assados,
    required this.porMotivo,
    required this.porSabor,
    required this.porLocal,
    this.custoPorMotivo = const {},
    this.custoPorSabor = const {},
    this.custoPorLocal = const {},
  });

  final double unidades;

  /// Custo da matéria-prima do que se deitou fora (unidades × custo atual).
  final double custo;
  final double assados;

  /// Chave: [MotivoDesperdicio] (ou `null` = sem motivo).
  final Map<MotivoDesperdicio?, double> porMotivo;
  final Map<String, double> porSabor;
  final Map<String, double> porLocal;

  /// O mesmo, mas em custo (unidades × custo da ficha).
  final Map<MotivoDesperdicio?, double> custoPorMotivo;
  final Map<String, double> custoPorSabor;
  final Map<String, double> custoPorLocal;

  /// Desperdício como % dos cookies assados (0 se não há assados).
  double get percentDosAssados => assados > 0 ? unidades / assados * 100 : 0;

  /// Custo do que se podia ter evitado (queimado, fora de prazo, quebrado, erro).
  double get custoEvitavel => custoPorMotivo.entries
      .where((e) => e.key?.evitavel ?? false)
      .fold<double>(0, (s, e) => s + e.value);

  /// Custo do que foi escolha (degustação, consumo próprio).
  double get custoOferta => custoPorMotivo.entries
      .where(
        (e) =>
            e.key == MotivoDesperdicio.degustacao ||
            e.key == MotivoDesperdicio.consumoProprio,
      )
      .fold<double>(0, (s, e) => s + e.value);

  /// O motivo evitável que mais custou (null se não há nenhum).
  MotivoDesperdicio? get maiorPerdaEvitavel {
    MotivoDesperdicio? melhor;
    var max = 0.0;
    for (final e in custoPorMotivo.entries) {
      final k = e.key;
      if (k == null || !k.evitavel) continue;
      if (e.value > max) {
        max = e.value;
        melhor = k;
      }
    }
    return melhor;
  }
}

ResumoDesperdicio resumoDesperdicio({
  required List<MovimentoProduto> movimentos,
  required Map<String, double> custoPorFicha,
}) {
  var unidades = 0.0;
  var custo = 0.0;
  var assados = 0.0;
  final motivos = <MotivoDesperdicio?, double>{};
  final sabores = <String, double>{};
  final locais = <String, double>{};
  final custoMotivos = <MotivoDesperdicio?, double>{};
  final custoSabores = <String, double>{};
  final custoLocais = <String, double>{};
  for (final m in movimentos) {
    if (m.tipo == TipoMovimento.producao) assados += m.quantidade;
    if (m.tipo != TipoMovimento.desperdicio) continue;
    unidades += m.quantidade;
    final c = m.quantidade * (custoPorFicha[m.fichaId] ?? 0);
    custo += c;
    custoMotivos[m.motivo] = (custoMotivos[m.motivo] ?? 0) + c;
    custoSabores[m.fichaId] = (custoSabores[m.fichaId] ?? 0) + c;
    custoLocais[m.localId] = (custoLocais[m.localId] ?? 0) + c;
    motivos[m.motivo] = (motivos[m.motivo] ?? 0) + m.quantidade;
    sabores[m.fichaId] = (sabores[m.fichaId] ?? 0) + m.quantidade;
    locais[m.localId] = (locais[m.localId] ?? 0) + m.quantidade;
  }
  return ResumoDesperdicio(
    unidades: unidades,
    custo: custo,
    assados: assados,
    porMotivo: motivos,
    porSabor: sabores,
    porLocal: locais,
    custoPorMotivo: custoMotivos,
    custoPorSabor: custoSabores,
    custoPorLocal: custoLocais,
  );
}

/// Balanço de um local num período, por sabor: o que chegou, o que saiu de
/// volta, o que se vendeu e deitou fora — para saber, por exemplo, quantos
/// cookies foram para Alvalade e quantos voltaram.
class BalancoSabor {
  const BalancoSabor({
    required this.fichaId,
    required this.assados,
    required this.recebido,
    required this.enviado,
    required this.vendido,
    required this.desperdicio,
  });

  final String fichaId;
  final double assados;
  final double recebido;
  final double enviado;
  final double vendido;
  final double desperdicio;

  /// Entradas − saídas (teórico): o que devia ter ficado no local.
  double get saldo => assados + recebido - enviado - vendido - desperdicio;
}

List<BalancoSabor> balancoDoLocal({
  required String localId,
  required List<MovimentoProduto> movimentos,
  required List<VendaDoLocal> vendas,
}) {
  final fichas = <String>{
    for (final m in movimentos)
      if (m.localId == localId || m.destinoId == localId) m.fichaId,
    for (final v in vendas)
      if (v.localId == localId) v.fichaId,
  };
  double soma(String f, bool Function(MovimentoProduto) t) => movimentos
      .where((m) => m.fichaId == f && t(m))
      .fold<double>(0, (s, m) => s + m.quantidade);
  final out = [
    for (final f in fichas)
      BalancoSabor(
        fichaId: f,
        assados: soma(
          f,
          (m) => m.localId == localId && m.tipo == TipoMovimento.producao,
        ),
        recebido: soma(
          f,
          (m) =>
              m.tipo == TipoMovimento.transferencia && m.destinoId == localId,
        ),
        enviado: soma(
          f,
          (m) => m.tipo == TipoMovimento.transferencia && m.localId == localId,
        ),
        vendido: vendas
            .where((v) => v.localId == localId && v.fichaId == f)
            .fold<double>(0, (s, v) => s + v.quantidade),
        desperdicio: soma(
          f,
          (m) => m.localId == localId && m.tipo == TipoMovimento.desperdicio,
        ),
      ),
  ];
  out.sort((a, b) => b.recebido.compareTo(a.recebido));
  return out;
}
