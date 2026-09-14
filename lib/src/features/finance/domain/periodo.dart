/// Um intervalo de datas (inclusive nas duas pontas) para o painel
/// financeiro, com o período anterior de igual duração para comparação.
class Periodo {
  const Periodo({required this.desde, required this.ate, required this.label});

  final DateTime desde;
  final DateTime ate;
  final String label;

  // Usado como argumento de provider `.family` — precisa de igualdade por
  // valor (não identidade), já que cada build pode criar uma instância nova.
  @override
  bool operator ==(Object other) =>
      other is Periodo && other.desde == desde && other.ate == ate;

  @override
  int get hashCode => Object.hash(desde, ate);

  int get dias => ate.difference(desde).inDays + 1;

  /// Período imediatamente anterior, com a mesma duração — para comparar
  /// "este período vs. o anterior".
  Periodo get anterior => Periodo(
        desde: desde.subtract(Duration(days: dias)),
        ate: desde.subtract(const Duration(days: 1)),
        label: 'Período anterior',
      );

  /// Fração de um mês "médio" que este período representa — para prorratear
  /// custos fixos (que são sempre um valor *mensal*). Um mês completo dá 1.0.
  double get fatorProrateioMensal {
    final diasMes = desde.month == ate.month
        ? DateTime(desde.year, desde.month + 1, 0).day
        : 30.44;
    return dias / diasMes;
  }

  static DateTime _diaZero(DateTime d) => DateTime(d.year, d.month, d.day);

  static Periodo semanaAtual() {
    final hoje = _diaZero(DateTime.now());
    final inicio = hoje.subtract(Duration(days: hoje.weekday - 1));
    return Periodo(desde: inicio, ate: hoje, label: 'Esta semana');
  }

  static Periodo mesAtual() {
    final hoje = _diaZero(DateTime.now());
    return Periodo(
      desde: DateTime(hoje.year, hoje.month, 1),
      ate: hoje,
      label: 'Este mês',
    );
  }

  static Periodo mesPassado() {
    final hoje = _diaZero(DateTime.now());
    final ultimoDiaMesPassado = DateTime(hoje.year, hoje.month, 0);
    return Periodo(
      desde: DateTime(ultimoDiaMesPassado.year, ultimoDiaMesPassado.month, 1),
      ate: ultimoDiaMesPassado,
      label: 'Mês passado',
    );
  }

  static List<Periodo> presets() =>
      [semanaAtual(), mesAtual(), mesPassado()];
}
