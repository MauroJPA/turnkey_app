/// Os dias da semana em que a empresa trabalha: 1 = segunda … 7 = domingo
/// (os mesmos números de `DateTime.weekday`).
const todosOsDias = {1, 2, 3, 4, 5, 6, 7};

const nomesDiasCurtos = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
const nomesDiasLongos = [
  'segunda-feira',
  'terça-feira',
  'quarta-feira',
  'quinta-feira',
  'sexta-feira',
  'sábado',
  'domingo',
];

/// "1,2,3,4,5,6" → {1,…,6}. Vazio ou ilegível = trabalha todos os dias.
Set<int> lerDiasTrabalho(String? texto) {
  final dias = <int>{
    for (final p in (texto ?? '').split(','))
      if (int.tryParse(p.trim()) case final d? when d >= 1 && d <= 7) d,
  };
  return dias.isEmpty ? todosOsDias : dias;
}

/// {1,…,6} → "1,2,3,4,5,6". Todos os dias (ou nenhum) guarda-se vazio.
String escreverDiasTrabalho(Set<int> dias) {
  final validos = dias.where((d) => d >= 1 && d <= 7).toList()..sort();
  if (validos.isEmpty || validos.length == 7) return '';
  return validos.join(',');
}

/// Texto curto: "segunda a sábado", "todos os dias", "seg, qua, sex".
String resumoDiasTrabalho(Set<int> dias) {
  final d = dias.toList()..sort();
  if (d.length == 7) return 'todos os dias';
  final seguidos = d.length > 2 && d.last - d.first == d.length - 1;
  if (seguidos) {
    return '${nomesDiasLongos[d.first - 1].replaceAll('-feira', '')} a '
        '${nomesDiasLongos[d.last - 1].replaceAll('-feira', '')}';
  }
  return d.map((x) => nomesDiasCurtos[x - 1]).join(', ');
}

/// O primeiro dia de trabalho a partir de [desde] (inclusive), até uma
/// semana à frente; `null` se não houver nenhum.
DateTime? proximoDiaDeTrabalho(DateTime desde, Set<int> dias) {
  for (var i = 0; i < 7; i++) {
    final d = DateTime(desde.year, desde.month, desde.day + i);
    if (dias.contains(d.weekday)) return d;
  }
  return null;
}
