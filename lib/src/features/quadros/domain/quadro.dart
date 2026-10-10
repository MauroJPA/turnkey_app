/// Tarefas da equipa em quadros (ao estilo Trello): quadros → fases (colunas)
/// → tarefas (cartões), com responsáveis, prazo, etiquetas, lista de
/// verificação e comentários com menções. Só lógica pura (sem PocketBase nem
/// Flutter), para se testar à parte.
library;

/// Um quadro ("Loja", "Eventos", "Obras"…).
class Quadro {
  const Quadro({
    required this.id,
    required this.nome,
    this.ordem = 0,
    this.arquivado = false,
    this.autorId = '',
  });

  final String id;
  final String nome;
  final double ordem;
  final bool arquivado;
  final String autorId;
}

/// Uma fase do quadro ("A fazer", "Em curso", "Feito").
class ColunaQuadro {
  const ColunaQuadro({
    required this.id,
    required this.quadroId,
    required this.nome,
    this.ordem = 0,
    this.concluida = false,
  });

  final String id;
  final String quadroId;
  final String nome;
  final double ordem;

  /// As tarefas desta fase contam como feitas (nunca ficam "atrasadas").
  final bool concluida;
}

/// Um passo da lista de verificação de uma tarefa.
class ItemChecklist {
  const ItemChecklist(this.texto, {this.feito = false});

  final String texto;
  final bool feito;

  ItemChecklist copyWith({String? texto, bool? feito}) =>
      ItemChecklist(texto ?? this.texto, feito: feito ?? this.feito);

  Map<String, dynamic> toJson() => {'t': texto, 'f': feito};

  /// Tolerante: ignora o que não for um item válido.
  static List<ItemChecklist> listaDeJson(Object? v) => [
    if (v is List)
      for (final e in v)
        if (e is Map &&
            e['t'] is String &&
            (e['t'] as String).trim().isNotEmpty)
          ItemChecklist(e['t'] as String, feito: e['f'] == true),
  ];
}

/// Um cartão do quadro.
class Tarefa {
  const Tarefa({
    required this.id,
    required this.quadroId,
    required this.colunaId,
    required this.titulo,
    required this.criada,
    this.descricao = '',
    this.ordem = 0,
    this.responsaveis = const [],
    this.prazo,
    this.etiquetas = const [],
    this.checklist = const [],
    this.arquivada = false,
    this.autorId = '',
    this.autorNome = '',
  });

  final String id;
  final String quadroId;
  final String colunaId;
  final String titulo;
  final String descricao;
  final double ordem;

  /// Ids dos utilizadores responsáveis.
  final List<String> responsaveis;

  /// Só a data (o dia).
  final DateTime? prazo;
  final List<String> etiquetas;
  final List<ItemChecklist> checklist;
  final bool arquivada;
  final String autorId;
  final String autorNome;
  final DateTime criada;

  int get checklistFeitos => checklist.where((i) => i.feito).length;

  bool get temChecklist => checklist.isNotEmpty;

  /// O prazo já passou (ontem ou antes) e a tarefa não está numa fase feita.
  bool atrasada(DateTime hoje, {required bool feita}) {
    final p = prazo;
    if (p == null || feita) return false;
    return _dia(p).isBefore(_dia(hoje));
  }

  /// O prazo é hoje e a tarefa não está numa fase feita.
  bool paraHoje(DateTime hoje, {required bool feita}) {
    final p = prazo;
    if (p == null || feita) return false;
    return _dia(p) == _dia(hoje);
  }

  Tarefa copyWith({
    String? colunaId,
    String? titulo,
    String? descricao,
    double? ordem,
    List<String>? responsaveis,
    DateTime? prazo,
    bool limparPrazo = false,
    List<String>? etiquetas,
    List<ItemChecklist>? checklist,
    bool? arquivada,
  }) => Tarefa(
    id: id,
    quadroId: quadroId,
    colunaId: colunaId ?? this.colunaId,
    titulo: titulo ?? this.titulo,
    descricao: descricao ?? this.descricao,
    ordem: ordem ?? this.ordem,
    responsaveis: responsaveis ?? this.responsaveis,
    prazo: limparPrazo ? null : (prazo ?? this.prazo),
    etiquetas: etiquetas ?? this.etiquetas,
    checklist: checklist ?? this.checklist,
    arquivada: arquivada ?? this.arquivada,
    autorId: autorId,
    autorNome: autorNome,
    criada: criada,
  );
}

/// Um comentário numa tarefa.
class ComentarioTarefa {
  const ComentarioTarefa({
    required this.id,
    required this.tarefaId,
    required this.texto,
    required this.criado,
    this.autorId = '',
    this.autorNome = '',
    this.mencoes = const [],
    this.lidaPor = const [],
  });

  final String id;
  final String tarefaId;
  final String texto;
  final DateTime criado;
  final String autorId;
  final String autorNome;
  final List<String> mencoes;
  final List<String> lidaPor;

  /// Menciona [uid] e essa pessoa ainda não o viu.
  bool mencaoPorLer(String uid) =>
      uid.isNotEmpty && mencoes.contains(uid) && !lidaPor.contains(uid);
}

/// Uma pessoa que se pode mencionar ou pôr como responsável.
class PessoaEquipa {
  const PessoaEquipa(this.id, this.nome);

  final String id;
  final String nome;

  /// "Ana Silva" → "AS"; "ana" → "A".
  String get iniciais {
    final partes = nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (partes.isEmpty) return '?';
    final l = partes.toList();
    final a = l.first.substring(0, 1);
    final b = l.length > 1 ? l.last.substring(0, 1) : '';
    return (a + b).toUpperCase();
  }

  String get primeiroNome {
    final n = nome.trim();
    final i = n.indexOf(' ');
    return i < 0 ? n : n.substring(0, i);
  }
}

DateTime _dia(DateTime d) => DateTime(d.year, d.month, d.day);

/// Fases com que nasce um quadro novo (a última conta como feita).
const fasesPorOmissao = ['A fazer', 'Em curso', 'Feito'];

/// As tarefas de uma fase, pela ordem do quadro (ordem; depois as mais antigas).
List<Tarefa> tarefasDaColuna(Iterable<Tarefa> tarefas, String colunaId) =>
    [
      for (final t in tarefas)
        if (t.colunaId == colunaId) t,
    ]..sort((a, b) {
      final c = a.ordem.compareTo(b.ordem);
      return c != 0 ? c : a.criada.compareTo(b.criada);
    });

/// A ordem para pôr um cartão na posição [indice] de [coluna] (já ordenada).
/// O próprio cartão ([movido]) é ignorado se lá estiver, para se poder mover
/// dentro da mesma fase.
double ordemNaPosicao(List<Tarefa> coluna, int indice, {String movido = ''}) {
  final outras = [
    for (final t in coluna)
      if (t.id != movido) t,
  ];
  final i = indice.clamp(0, outras.length);
  if (outras.isEmpty) return 1000;
  if (i == 0) return outras.first.ordem - 1000;
  if (i == outras.length) return outras.last.ordem + 1000;
  return (outras[i - 1].ordem + outras[i].ordem) / 2;
}

/// A ordem para largar [movido] antes do cartão que está na posição
/// [antesDe] de [coluna] (a lista tal como se vê, com o próprio cartão se ele
/// já estiver nesta fase). `antesDe == coluna.length` = no fim.
double ordemAoLargar(List<Tarefa> coluna, int antesDe, String movido) {
  final atual = coluna.indexWhere((t) => t.id == movido);
  // a descer na mesma fase, o próprio cartão sai de cima: o índice encolhe
  final i = atual >= 0 && atual < antesDe ? antesDe - 1 : antesDe;
  return ordemNaPosicao(coluna, i, movido: movido);
}

/// A ordem para uma fase/quadro novo, no fim.
double ordemNoFim(Iterable<double> ordens) =>
    ordens.isEmpty ? 1000 : ordens.reduce((a, b) => a > b ? a : b) + 1000;

/// Os filtros rápidos do quadro.
enum FiltroTarefas {
  todas('Todas'),
  minhas('Minhas'),
  mencoes('Menções'),
  atrasadas('Atrasadas');

  const FiltroTarefas(this.label);
  final String label;
}

/// Aplica o filtro rápido e a pesquisa (título, descrição, etiquetas e o nome
/// de quem é responsável).
List<Tarefa> filtrarTarefas(
  Iterable<Tarefa> tarefas, {
  required FiltroTarefas filtro,
  required String uid,
  required Set<String> colunasFeitas,
  Set<String> comMencaoPorLer = const {},
  Map<String, String> nomes = const {},
  String busca = '',
  DateTime? hoje,
}) {
  final h = hoje ?? DateTime.now();
  final q = semAcentos(busca.trim().toLowerCase());
  bool bate(Tarefa t) {
    if (q.isEmpty) return true;
    final campos = [
      t.titulo,
      t.descricao,
      ...t.etiquetas,
      for (final r in t.responsaveis) nomes[r] ?? '',
    ];
    return campos.any((c) => semAcentos(c.toLowerCase()).contains(q));
  }

  return [
    for (final t in tarefas)
      if (!t.arquivada &&
          bate(t) &&
          switch (filtro) {
            FiltroTarefas.todas => true,
            FiltroTarefas.minhas => t.responsaveis.contains(uid),
            FiltroTarefas.mencoes => comMencaoPorLer.contains(t.id),
            FiltroTarefas.atrasadas => t.atrasada(
              h,
              feita: colunasFeitas.contains(t.colunaId),
            ),
          })
        t,
  ];
}

const _acentos = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', //
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', //
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', //
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ç': 'c',
};

/// "Ação" → "acao" (já em minúsculas) — para pesquisar sem acentos.
String semAcentos(String s) {
  final b = StringBuffer();
  for (final ch in s.split('')) {
    b.write(_acentos[ch] ?? ch);
  }
  return b.toString();
}

/// As pessoas mencionadas num texto com "@Nome" (nome completo ou só o
/// primeiro nome, sem ligar a maiúsculas nem acentos). Os nomes mais compridos
/// ganham ("@Ana Silva" é a Ana Silva, não outra Ana).
List<String> mencoesNoTexto(String texto, Iterable<PessoaEquipa> pessoas) {
  final t = semAcentos(texto.toLowerCase());
  final candidatos = <({String chave, String id})>[
    for (final p in pessoas)
      if (p.nome.trim().isNotEmpty) ...[
        (chave: semAcentos(p.nome.trim().toLowerCase()), id: p.id),
        (chave: semAcentos(p.primeiroNome.toLowerCase()), id: p.id),
      ],
  ]..sort((a, b) => b.chave.length.compareTo(a.chave.length));

  final achados = <String>[];
  var i = t.indexOf('@');
  while (i >= 0) {
    // "ana@loja.pt" é um email, não uma menção
    if (i > 0 && _letra(t[i - 1])) {
      i = t.indexOf('@', i + 1);
      continue;
    }
    final resto = t.substring(i + 1);
    for (final c in candidatos) {
      if (c.chave.isEmpty || !resto.startsWith(c.chave)) continue;
      final fim = c.chave.length;
      final limite = fim >= resto.length || !_letra(resto[fim]);
      if (!limite) continue;
      if (!achados.contains(c.id)) achados.add(c.id);
      break;
    }
    i = t.indexOf('@', i + 1);
  }
  return achados;
}

bool _letra(String c) => RegExp(r'[a-z0-9_]').hasMatch(c);

/// A palavra começada por "@" que está a ser escrita no fim de [texto] (sem o
/// "@"), ou `null`. Serve para sugerir nomes enquanto se escreve.
String? mencaoAEscrever(String texto, int cursor) {
  final ate = texto.substring(0, cursor.clamp(0, texto.length));
  final i = ate.lastIndexOf('@');
  if (i < 0) return null;
  if (i > 0 && !RegExp(r'\s').hasMatch(ate[i - 1])) return null;
  final parcial = ate.substring(i + 1);
  if (parcial.contains('\n') || parcial.length > 30) return null;
  // depois de duas palavras já não é um nome a meio
  if (parcial.split(' ').length > 2) return null;
  return parcial;
}

/// As pessoas cujo nome começa (em qualquer palavra) por [parcial].
List<PessoaEquipa> sugerirPessoas(
  Iterable<PessoaEquipa> pessoas,
  String parcial, {
  int maximo = 5,
}) {
  final q = semAcentos(parcial.trim().toLowerCase());
  return [
    for (final p in pessoas)
      if (q.isEmpty ||
          semAcentos(p.nome.toLowerCase()).startsWith(q) ||
          semAcentos(
            p.nome.toLowerCase(),
          ).split(RegExp(r'\s+')).any((w) => w.startsWith(q)))
        p,
  ].take(maximo).toList();
}

/// Substitui o "@parcial" antes do cursor por "@Nome " e devolve o texto novo e
/// a posição do cursor.
({String texto, int cursor}) inserirMencao(
  String texto,
  int cursor,
  PessoaEquipa p,
) {
  final c = cursor.clamp(0, texto.length);
  final i = texto.substring(0, c).lastIndexOf('@');
  if (i < 0) return (texto: texto, cursor: c);
  final novo =
      '${texto.substring(0, i)}@${p.nome.trim()} ${texto.substring(c)}';
  return (texto: novo, cursor: i + p.nome.trim().length + 2);
}

/// "hoje", "amanhã", "ontem", "em 3 dias", "há 3 dias", "12/10" — para o
/// cartão.
String prazoTexto(DateTime prazo, DateTime hoje) {
  final d = _dia(prazo).difference(_dia(hoje)).inDays;
  if (d == 0) return 'hoje';
  if (d == 1) return 'amanhã';
  if (d == -1) return 'ontem';
  if (d > 1 && d <= 6) return 'em $d dias';
  if (d < 0 && d >= -6) return 'há ${-d} dias';
  return '${prazo.day}/${prazo.month}${prazo.year == hoje.year ? '' : '/${prazo.year}'}';
}

/// Índice (0–7) de cor de uma etiqueta: sempre a mesma cor para o mesmo nome.
int corEtiqueta(String nome) {
  var h = 0;
  for (final c in semAcentos(nome.trim().toLowerCase()).codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h % 8;
}

/// Todas as etiquetas já usadas no quadro (para sugerir), por ordem alfabética.
List<String> etiquetasUsadas(Iterable<Tarefa> tarefas) {
  final vistas = <String, String>{};
  for (final t in tarefas) {
    for (final e in t.etiquetas) {
      vistas.putIfAbsent(semAcentos(e.trim().toLowerCase()), () => e.trim());
    }
  }
  return vistas.values.toList()..sort();
}
