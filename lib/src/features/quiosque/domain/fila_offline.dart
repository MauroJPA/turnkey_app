import 'dart:convert';
import 'dart:math' as math;

import 'package:pocketbase/pocketbase.dart';

import '../../haccp/domain/haccp.dart';
import '../../people/domain/ponto.dart';
import 'colaborador.dart';

/// Os dados de uma marcação de ponto à espera de ligação.
class PontoPendente {
  const PontoPendente({
    required this.pessoa,
    required this.nome,
    required this.tipo,
    this.userId = '',
  });

  final String pessoa;
  final String nome;
  final String userId;

  /// O valor guardado no servidor (`entrada`, `saida`, `pausa_inicio`, `pausa_fim`).
  final String tipo;

  Map<String, dynamic> toJson() => {
    'pessoa': pessoa,
    'nome': nome,
    'user': userId,
    'tipo': tipo,
  };

  static PontoPendente? fromJson(Object? j) {
    if (j is! Map ||
        '${j['pessoa'] ?? ''}'.isEmpty ||
        '${j['tipo'] ?? ''}'.isEmpty) {
      return null;
    }
    return PontoPendente(
      pessoa: '${j['pessoa']}',
      nome: '${j['nome'] ?? ''}',
      userId: '${j['user'] ?? ''}',
      tipo: '${j['tipo']}',
    );
  }
}

/// Um registo do quiosque que ainda não chegou ao servidor (a ligação caiu):
/// uma tarefa HACCP ou, se [ponto] existe, uma marcação de ponto.
///
/// Leva o seu próprio [id] (15 letras/números, o formato do PocketBase): se o
/// envio chegou ao servidor mas a resposta se perdeu, reenviar não duplica —
/// o servidor diz que o id já existe e dá-se o registo por enviado.
class RegistoPendente {
  const RegistoPendente({
    required this.id,
    required this.controloId,
    required this.dataHora,
    required this.conforme,
    this.valor,
    this.responsavel = '',
    this.notas = '',
    this.acaoCorretiva = '',
    this.tentativas = 0,
    this.ponto,
  });

  final String id;
  final String controloId;

  /// Só nas marcações de ponto.
  final PontoPendente? ponto;

  /// Quando a pessoa tocou (não quando chegou ao servidor).
  final DateTime dataHora;
  final bool conforme;
  final double? valor;
  final String responsavel;
  final String notas;
  final String acaoCorretiva;
  final int tentativas;

  RegistoPendente maisUmaTentativa() => RegistoPendente(
    id: id,
    controloId: controloId,
    dataHora: dataHora,
    conforme: conforme,
    valor: valor,
    responsavel: responsavel,
    notas: notas,
    acaoCorretiva: acaoCorretiva,
    tentativas: tentativas + 1,
    ponto: ponto,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'controlo': controloId,
    'dataHora': dataHora.toUtc().toIso8601String(),
    'conforme': conforme,
    if (valor != null) 'valor': valor,
    'responsavel': responsavel,
    'notas': notas,
    'acao': acaoCorretiva,
    'tentativas': tentativas,
    if (ponto != null) 'ponto': ponto!.toJson(),
  };

  static RegistoPendente? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = '${j['id'] ?? ''}';
    final controlo = '${j['controlo'] ?? ''}';
    final quando = DateTime.tryParse('${j['dataHora'] ?? ''}');
    final ponto = PontoPendente.fromJson(j['ponto']);
    if (!idPbValido(id) ||
        (controlo.isEmpty && ponto == null) ||
        quando == null) {
      return null;
    }
    final v = j['valor'];
    return RegistoPendente(
      id: id,
      controloId: controlo,
      dataHora: quando.toLocal(),
      conforme: j['conforme'] != false,
      valor: v is num ? v.toDouble() : null,
      responsavel: '${j['responsavel'] ?? ''}',
      notas: '${j['notas'] ?? ''}',
      acaoCorretiva: '${j['acao'] ?? ''}',
      tentativas: j['tentativas'] is int ? j['tentativas'] as int : 0,
      ponto: ponto,
    );
  }
}

/// Os ids do PocketBase têm 15 caracteres `a-z` e `0-9`.
bool idPbValido(String id) => RegExp(r'^[a-z0-9]{15}$').hasMatch(id);

/// Um id novo para um registo (15 caracteres).
String novoIdPb([math.Random? r]) {
  const letras = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rnd = r ?? math.Random.secure();
  return List.generate(15, (_) => letras[rnd.nextInt(letras.length)]).join();
}

String codificarFila(List<RegistoPendente> fila) =>
    jsonEncode([for (final r in fila) r.toJson()]);

/// Lê a fila guardada; ignora entradas estragadas.
List<RegistoPendente> lerFila(String? texto) {
  if (texto == null || texto.trim().isEmpty) return const [];
  try {
    final j = jsonDecode(texto);
    if (j is! List) return const [];
    return [
      for (final e in j)
        if (RegistoPendente.fromJson(e) case final r?) r,
    ];
  } on FormatException {
    return const [];
  }
}

/// O servidor não se alcançou (sem Wi-Fi, servidor a reiniciar…): vale a
/// pena guardar e tentar mais tarde. Um erro de validação não é isto.
bool eErroDeLigacao(Object e) {
  if (e is ClientException) {
    // o cliente do PocketBase marca como "abort" qualquer falha de rede
    // (ligação recusada, Wi-Fi caído…); só o cliente fechado não conta
    if (e.originalError is StateError) return false;
    return e.statusCode == 0 ||
        e.statusCode == 502 ||
        e.statusCode == 503 ||
        e.statusCode == 504;
  }
  return false;
}

/// A sessão caducou ou não tem permissão: não se deve perder o registo, mas
/// também não adianta repetir até alguém entrar de novo.
bool eErroDeSessao(Object e) =>
    e is ClientException && (e.statusCode == 401 || e.statusCode == 403);

/// O envio falhou por o id já existir: o registo já chegou antes.
bool eIdJaExiste(Object e) {
  if (e is! ClientException || e.statusCode != 400) return false;
  final data = e.response['data'];
  return data is Map && data.containsKey('id');
}

// --- cache do que o quiosque mostra -------------------------------------------

Map<String, dynamic> controloParaJson(ControloHaccp c) => {
  'id': c.id,
  'nome': c.nome,
  'tipo': c.tipo.api,
  'periodicidade': c.periodicidadeDias,
  'vezes': c.vezesPorDia,
  if (c.limiteMin != null) 'min': c.limiteMin,
  if (c.limiteMax != null) 'max': c.limiteMax,
  'unidade': c.unidade,
  'local': c.local,
  'instrucoes': c.instrucoes,
  'ordem': c.ordem,
};

ControloHaccp? controloDeJson(Object? j) {
  if (j is! Map || '${j['id'] ?? ''}'.isEmpty) return null;
  double? d(Object? v) => v is num ? v.toDouble() : null;
  return ControloHaccp(
    id: '${j['id']}',
    nome: '${j['nome'] ?? ''}',
    tipo: TipoControlo.fromApi('${j['tipo'] ?? ''}'),
    periodicidadeDias: j['periodicidade'] is int
        ? j['periodicidade'] as int
        : 1,
    vezesPorDia: j['vezes'] is int ? j['vezes'] as int : 1,
    limiteMin: d(j['min']),
    limiteMax: d(j['max']),
    unidade: '${j['unidade'] ?? ''}',
    local: '${j['local'] ?? ''}',
    instrucoes: '${j['instrucoes'] ?? ''}',
    ordem: j['ordem'] is int ? j['ordem'] as int : 0,
  );
}

/// As tarefas do quiosque, para mostrar quando não há ligação.
String codificarEstados(List<StatusControlo> estados) => jsonEncode([
  for (final s in estados)
    {
      'c': controloParaJson(s.controlo),
      'e': s.estado.name,
      'f': s.feitosHoje,
      'x': s.esperadosHoje,
      'a': s.diasAtraso,
    },
]);

List<StatusControlo> lerEstados(String? texto) {
  if (texto == null || texto.trim().isEmpty) return const [];
  try {
    final j = jsonDecode(texto);
    if (j is! List) return const [];
    final out = <StatusControlo>[];
    for (final e in j) {
      if (e is! Map) continue;
      final c = controloDeJson(e['c']);
      if (c == null) continue;
      out.add(
        StatusControlo(
          controlo: c,
          estado: EstadoControlo.values.firstWhere(
            (x) => x.name == e['e'],
            orElse: () => EstadoControlo.pendenteHoje,
          ),
          feitosHoje: e['f'] is int ? e['f'] as int : 0,
          esperadosHoje: e['x'] is int ? e['x'] as int : 1,
          diasAtraso: e['a'] is int ? e['a'] as int : 0,
        ),
      );
    }
    return out;
  } on FormatException {
    return const [];
  }
}

/// As pessoas do quiosque (e o cartão de cada uma) para escolher sem ligação.
String codificarPessoas(List<Colaborador> pessoas) => jsonEncode([
  for (final p in pessoas)
    {'id': p.id, 'nome': p.nome, 'nfc': p.nfcUid, 'user': p.userId},
]);

List<Colaborador> lerPessoas(String? texto) {
  if (texto == null || texto.trim().isEmpty) return const [];
  try {
    final j = jsonDecode(texto);
    if (j is! List) return const [];
    return [
      for (final e in j)
        if (e is Map && '${e['id'] ?? ''}'.isNotEmpty)
          Colaborador(
            id: '${e['id']}',
            nome: '${e['nome'] ?? ''}',
            nfcUid: '${e['nfc'] ?? ''}',
            userId: '${e['user'] ?? ''}',
          ),
    ];
  } on FormatException {
    return const [];
  }
}

/// Passa para as tarefas o que já foi tocado sem ligação (e ainda não chegou
/// ao servidor): sobe os "feitos hoje" e, quando chega ao esperado, a tarefa
/// passa a "em dia". [pendentes] de outros dias não contam.
List<StatusControlo> comPendentes(
  List<StatusControlo> base,
  List<RegistoPendente> pendentes,
  DateTime agora,
) {
  if (pendentes.isEmpty) return base;
  bool hoje(DateTime d) =>
      d.year == agora.year && d.month == agora.month && d.day == agora.day;
  final porControlo = <String, int>{};
  for (final p in pendentes) {
    if (p.ponto == null && hoje(p.dataHora)) {
      porControlo[p.controloId] = (porControlo[p.controloId] ?? 0) + 1;
    }
  }
  return [
    for (final s in base)
      if ((porControlo[s.controlo.id] ?? 0) == 0)
        s
      else
        StatusControlo(
          controlo: s.controlo,
          ultimo: s.ultimo,
          proximo: s.proximo,
          diasAtraso: 0,
          feitosHoje: s.feitosHoje + porControlo[s.controlo.id]!,
          esperadosHoje: s.esperadosHoje,
          estado: s.estado == EstadoControlo.ocasional
              ? s.estado
              : (s.feitosHoje + porControlo[s.controlo.id]! >= s.esperadosHoje
                    ? EstadoControlo.emDia
                    : EstadoControlo.pendenteHoje),
        ),
  ];
}

// --- ponto: última marcação de cada pessoa, guardada no aparelho ----------------

String codificarEstadoPonto(Map<String, UltimoPonto> m) => jsonEncode({
  for (final e in m.entries)
    e.key: {
      't': e.value.tipo.api,
      'h': e.value.dataHora.toUtc().toIso8601String(),
    },
});

Map<String, UltimoPonto> lerEstadoPonto(String? texto) {
  if (texto == null || texto.trim().isEmpty) return const {};
  try {
    final j = jsonDecode(texto);
    if (j is! Map) return const {};
    final out = <String, UltimoPonto>{};
    for (final e in j.entries) {
      final v = e.value;
      if (v is! Map) continue;
      final t = TipoPonto.fromApi('${v['t']}');
      final h = DateTime.tryParse('${v['h']}')?.toLocal();
      if (t != null && h != null) out['${e.key}'] = UltimoPonto(t, h);
    }
    return out;
  } on FormatException {
    return const {};
  }
}

/// Junta duas listas de "última marcação": para cada pessoa fica a mais recente.
Map<String, UltimoPonto> juntarEstadoPonto(
  Map<String, UltimoPonto> a,
  Map<String, UltimoPonto> b,
) {
  final out = {...a};
  for (final e in b.entries) {
    final atual = out[e.key];
    if (atual == null || e.value.dataHora.isAfter(atual.dataHora)) {
      out[e.key] = e.value;
    }
  }
  return out;
}
