/// Tipo de período "de calendário": a semana (domingo a sábado, ignora o mês)
/// ou o mês civil (dia 1 ao último dia).
enum TipoPeriodo { semana, mes }

/// Um intervalo de datas (inclusive nas duas pontas) para o painel
/// financeiro, com o período anterior para comparação.
///
/// Os períodos de calendário ([semanaDe], [mesDe]) são sempre **completos**
/// (a semana inteira, o mês inteiro), mesmo que ainda estejam a decorrer —
/// assim os mínimos/custos do período não mudam de um dia para o outro, só as
/// vendas vão somando.
class Periodo {
  const Periodo({
    required this.desde,
    required this.ate,
    required this.label,
    this.tipo,
  });

  final DateTime desde;
  final DateTime ate;
  final String label;

  /// `null` = intervalo livre (não é uma semana nem um mês de calendário).
  final TipoPeriodo? tipo;

  // Usado como argumento de provider `.family` — precisa de igualdade por
  // valor (não identidade), já que cada build pode criar uma instância nova.
  @override
  bool operator ==(Object other) =>
      other is Periodo && other.desde == desde && other.ate == ate;

  @override
  int get hashCode => Object.hash(desde, ate);

  /// Nº de dias (inclusive). Conta em UTC para não ser afetado pela mudança
  /// de hora.
  int get dias =>
      DateTime.utc(ate.year, ate.month, ate.day)
          .difference(DateTime.utc(desde.year, desde.month, desde.day))
          .inDays +
      1;

  bool contem(DateTime d) {
    final x = _diaZero(d);
    return !x.isBefore(desde) && !x.isAfter(ate);
  }

  /// Período imediatamente anterior — para comparar "este período vs. o
  /// anterior". Um mês compara com o mês civil anterior; uma semana com a
  /// semana anterior; um intervalo livre, com outro da mesma duração.
  Periodo get anterior {
    switch (tipo) {
      case TipoPeriodo.mes:
        return mesDe(DateTime(desde.year, desde.month - 1, 1));
      case TipoPeriodo.semana:
        return semanaDe(DateTime(desde.year, desde.month, desde.day - 1));
      case null:
        return Periodo(
          desde: DateTime(desde.year, desde.month, desde.day - dias),
          ate: DateTime(desde.year, desde.month, desde.day - 1),
          label: 'Período anterior',
        );
    }
  }

  /// O período de calendário a seguir (só faz sentido para semana/mês).
  Periodo get seguinte {
    switch (tipo) {
      case TipoPeriodo.mes:
        return mesDe(DateTime(ate.year, ate.month + 1, 1));
      case TipoPeriodo.semana:
        return semanaDe(DateTime(ate.year, ate.month, ate.day + 1));
      case null:
        return Periodo(
          desde: DateTime(ate.year, ate.month, ate.day + 1),
          ate: DateTime(ate.year, ate.month, ate.day + dias),
          label: 'Período seguinte',
        );
    }
  }

  /// Fração de um mês "médio" que este período representa — para prorratear
  /// custos fixos (que são sempre um valor *mensal*). Um mês completo dá 1.0;
  /// uma semana dá sempre 7/30,44, esteja onde estiver no calendário.
  double get fatorProrateioMensal {
    if (tipo == TipoPeriodo.semana) return dias / 30.44;
    final diasMes = desde.month == ate.month
        ? DateTime(desde.year, desde.month + 1, 0).day
        : 30.44;
    return dias / diasMes;
  }

  /// "01/10/2026 – 31/10/2026" (ou "05/10/2026" se for um só dia).
  String get intervaloTexto =>
      desde == ate ? _dmy(desde) : '${_dmy(desde)} – ${_dmy(ate)}';

  static DateTime _diaZero(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool _dentro(DateTime d, DateTime desde, DateTime ate) =>
      !d.isBefore(desde) && !d.isAfter(ate);

  static String _dmy(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static const _meses = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];

  /// A semana (domingo a sábado) que contém [d] — ignora o mês.
  static Periodo semanaDe(DateTime d, {DateTime? hoje}) {
    final dia = _diaZero(d);
    final inicio = DateTime(dia.year, dia.month, dia.day - (dia.weekday % 7));
    final fim = DateTime(inicio.year, inicio.month, inicio.day + 6);
    final h = _diaZero(hoje ?? DateTime.now());
    final String label;
    if (_dentro(h, inicio, fim)) {
      label = 'Esta semana';
    } else if (_dentro(DateTime(h.year, h.month, h.day - 7), inicio, fim)) {
      label = 'Semana passada';
    } else {
      label = 'Semana de ${_dmy(inicio).substring(0, 5)}';
    }
    return Periodo(
      desde: inicio,
      ate: fim,
      label: label,
      tipo: TipoPeriodo.semana,
    );
  }

  /// O mês civil completo (dia 1 ao último dia) que contém [d].
  static Periodo mesDe(DateTime d, {DateTime? hoje}) {
    final inicio = DateTime(d.year, d.month, 1);
    final fim = DateTime(d.year, d.month + 1, 0);
    final h = _diaZero(hoje ?? DateTime.now());
    final String label;
    if (h.year == inicio.year && h.month == inicio.month) {
      label = 'Este mês';
    } else if (DateTime(h.year, h.month - 1, 1) == inicio) {
      label = 'Mês passado';
    } else {
      label = '${_meses[inicio.month - 1]} de ${inicio.year}';
    }
    return Periodo(desde: inicio, ate: fim, label: label, tipo: TipoPeriodo.mes);
  }

  static Periodo semanaAtual() => semanaDe(DateTime.now());

  static Periodo mesAtual() => mesDe(DateTime.now());

  static Periodo mesPassado() {
    final h = DateTime.now();
    return mesDe(DateTime(h.year, h.month - 1, 1));
  }

  static List<Periodo> presets() => [semanaAtual(), mesAtual(), mesPassado()];
}
