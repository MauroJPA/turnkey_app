/// O estado da sincronização automática com o Vendus.
class EstadoVendus {
  const EstadoVendus({
    required this.configurado,
    this.tentativaEm,
    this.okEm,
    this.resultado = '',
  });

  /// Há um token do Vendus guardado.
  final bool configurado;

  /// A última vez que o servidor tentou sincronizar.
  final DateTime? tentativaEm;

  /// A última vez que correu bem.
  final DateTime? okEm;

  /// "Tudo em dia", "3 venda(s) nova(s)" ou o motivo do erro.
  final String resultado;

  factory EstadoVendus.fromJson(Map<String, dynamic> j) {
    DateTime? d(Object? v) {
      final s = '${v ?? ''}';
      return s.isEmpty ? null : DateTime.tryParse(s)?.toLocal();
    }

    return EstadoVendus(
      configurado: j['configurado'] == true,
      tentativaEm: d(j['tentativaEm']),
      okEm: d(j['okEm']),
      resultado: '${j['resultado'] ?? ''}',
    );
  }

  /// Ligado ao Vendus mas sem uma sincronização boa há mais de [horas].
  bool desatualizado(DateTime agora, {int horas = 26}) =>
      configurado &&
      (okEm == null || agora.difference(okEm!) > Duration(hours: horas));

  /// Convém sincronizar já (antes de fazer a previsão): há mais de [horas].
  bool pedeSincronizar(DateTime agora, {int horas = 3}) =>
      configurado &&
      (okEm == null || agora.difference(okEm!) > Duration(hours: horas));

  /// "14:05" ou "ontem 14:05" ou "3/10 14:05".
  String quando(DateTime agora) {
    final d = okEm;
    if (d == null) return 'nunca';
    String hm(DateTime x) =>
        '${x.hour.toString().padLeft(2, '0')}:${x.minute.toString().padLeft(2, '0')}';
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final dia = DateTime(d.year, d.month, d.day);
    final dif = hoje.difference(dia).inDays;
    if (dif == 0) return hm(d);
    if (dif == 1) return 'ontem ${hm(d)}';
    return '${d.day}/${d.month} ${hm(d)}';
  }
}
