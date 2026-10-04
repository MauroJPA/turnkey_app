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
  });

  final String fichaId;

  /// Cookies no início do dia: a contagem de abertura, ou — se não houve — a
  /// última contagem de fecho.
  final double abertura;

  /// `true` se [abertura] foi contada nesse dia (e não herdada do fecho).
  final bool aberturaContada;

  /// A última contagem de fecho antes deste dia (`null` se nunca houve).
  final double? fechoAnterior;

  /// Contagem de abertura − último fecho (o que "desapareceu" de uma noite
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

/// Calcula a contagem de um [dia] num [localId], para cada ficha em
/// [fichaIds]. [movimentos] deve incluir o histórico recente (para achar o
/// último fecho) e as [vendas] do local nesse dia.
List<LinhaContagem> calcularContagemDia({
  required String localId,
  required DateTime dia,
  required Iterable<String> fichaIds,
  required List<MovimentoProduto> movimentos,
  required List<VendaDoLocal> vendas,
}) {
  final d = _dia(dia);
  final doLocal = [
    for (final m in movimentos)
      if (m.localId == localId || m.destinoId == localId) m,
  ];

  double soma(String ficha, bool Function(MovimentoProduto) f) => doLocal
      .where((m) => m.fichaId == ficha && _dia(m.data) == d && f(m))
      .fold<double>(0, (s, m) => s + m.quantidade);

  final out = <LinhaContagem>[];
  for (final f in fichaIds) {
    // último fecho ANTES deste dia
    MovimentoProduto? fechoAnterior;
    for (final m in doLocal) {
      if (m.localId != localId ||
          m.fichaId != f ||
          m.tipo != TipoMovimento.contagemFecho ||
          !_dia(m.data).isBefore(d)) {
        continue;
      }
      if (fechoAnterior == null || m.data.isAfter(fechoAnterior.data)) {
        fechoAnterior = m;
      }
    }
    final aberturaMov = doLocal.cast<MovimentoProduto?>().firstWhere(
      (m) =>
          m!.localId == localId &&
          m.fichaId == f &&
          m.tipo == TipoMovimento.contagemAbertura &&
          _dia(m.data) == d,
      orElse: () => null,
    );
    final fechoMov = doLocal.cast<MovimentoProduto?>().firstWhere(
      (m) =>
          m!.localId == localId &&
          m.fichaId == f &&
          m.tipo == TipoMovimento.contagemFecho &&
          _dia(m.data) == d,
      orElse: () => null,
    );

    final abertura = aberturaMov?.quantidade ?? fechoAnterior?.quantidade ?? 0;
    out.add(
      LinhaContagem(
        fichaId: f,
        abertura: abertura,
        aberturaContada: aberturaMov != null,
        fechoAnterior: fechoAnterior?.quantidade,
        diferencaAbertura: aberturaMov != null && fechoAnterior != null
            ? aberturaMov.quantidade - fechoAnterior.quantidade
            : null,
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
            .where(
              (v) =>
                  v.localId == localId && v.fichaId == f && _dia(v.data) == d,
            )
            .fold<double>(0, (s, v) => s + v.quantidade),
        desperdicio: soma(
          f,
          (m) => m.localId == localId && m.tipo == TipoMovimento.desperdicio,
        ),
        fecho: fechoMov?.quantidade,
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
  });

  final double unidades;

  /// Custo da matéria-prima do que se deitou fora (unidades × custo atual).
  final double custo;
  final double assados;

  /// Chave: [MotivoDesperdicio] (ou `null` = sem motivo).
  final Map<MotivoDesperdicio?, double> porMotivo;
  final Map<String, double> porSabor;
  final Map<String, double> porLocal;

  /// Desperdício como % dos cookies assados (0 se não há assados).
  double get percentDosAssados => assados > 0 ? unidades / assados * 100 : 0;
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
  for (final m in movimentos) {
    if (m.tipo == TipoMovimento.producao) assados += m.quantidade;
    if (m.tipo != TipoMovimento.desperdicio) continue;
    unidades += m.quantidade;
    custo += m.quantidade * (custoPorFicha[m.fichaId] ?? 0);
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
