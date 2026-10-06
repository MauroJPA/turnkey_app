/// O tipo de anotação.
enum CategoriaNota {
  recado('recado', 'Recado'),
  ocorrencia('ocorrencia', 'Ocorrência'),
  lembrete('lembrete', 'Lembrete');

  const CategoriaNota(this.api, this.label);
  final String api;
  final String label;

  static CategoriaNota fromApi(String? v) => CategoriaNota.values.firstWhere(
    (c) => c.api == v,
    orElse: () => CategoriaNota.recado,
  );
}

/// Uma anotação da equipa.
class Nota {
  const Nota({
    required this.id,
    required this.texto,
    required this.categoria,
    required this.criada,
    this.titulo = '',
    this.fixada = false,
    this.arquivada = false,
    this.lembrarEm,
    this.autorId = '',
    this.autorNome = '',
  });

  final String id;
  final String titulo;
  final String texto;
  final CategoriaNota categoria;
  final bool fixada;
  final bool arquivada;

  /// Lembretes: a partir deste dia aparece no Início.
  final DateTime? lembrarEm;
  final String autorId;
  final String autorNome;
  final DateTime criada;

  /// É um lembrete que já chegou (ou passou) e ainda não foi tratado.
  bool paraHoje(DateTime hoje) {
    final d = lembrarEm;
    if (d == null || arquivada) return false;
    final h = DateTime(hoje.year, hoje.month, hoje.day);
    return !DateTime(d.year, d.month, d.day).isAfter(h);
  }
}

/// Fixadas primeiro; depois as mais recentes.
List<Nota> ordenarNotas(Iterable<Nota> notas) => [...notas]
  ..sort((a, b) {
    if (a.fixada != b.fixada) return a.fixada ? -1 : 1;
    return b.criada.compareTo(a.criada);
  });

/// Filtra por categoria (`null` = todas) e por texto (título, texto ou autor).
List<Nota> filtrarNotas(
  Iterable<Nota> notas, {
  CategoriaNota? categoria,
  String busca = '',
}) {
  final q = busca.trim().toLowerCase();
  return ordenarNotas([
    for (final n in notas)
      if ((categoria == null || n.categoria == categoria) &&
          (q.isEmpty ||
              n.titulo.toLowerCase().contains(q) ||
              n.texto.toLowerCase().contains(q) ||
              n.autorNome.toLowerCase().contains(q)))
        n,
  ]);
}

/// "há 2 h", "ontem", "3/10": para a lista.
String quandoTexto(DateTime d, DateTime agora) {
  final dif = agora.difference(d);
  if (dif.inMinutes < 1) return 'agora';
  if (dif.inMinutes < 60) return 'há ${dif.inMinutes} min';
  if (dif.inHours < 24 && d.day == agora.day) return 'há ${dif.inHours} h';
  final ontem = DateTime(agora.year, agora.month, agora.day - 1);
  if (d.year == ontem.year && d.month == ontem.month && d.day == ontem.day) {
    return 'ontem';
  }
  return '${d.day}/${d.month}${d.year == agora.year ? '' : '/${d.year}'}';
}
