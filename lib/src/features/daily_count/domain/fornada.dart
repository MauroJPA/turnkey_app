import 'package:pocketbase/pocketbase.dart';

enum EstadoFornada {
  noForno('no_forno'),
  tirada('tirada'),
  cancelada('cancelada');

  const EstadoFornada(this.api);
  final String api;

  static EstadoFornada fromApi(String? v) => EstadoFornada.values.firstWhere(
    (e) => e.api == v,
    orElse: () => EstadoFornada.noForno,
  );
}

/// Um sabor dentro de uma fornada, com o seu próprio tempo de forno.
class ItemFornada {
  const ItemFornada({
    required this.fichaId,
    required this.quantidade,
    required this.duracaoMin,
    this.tirado = false,
  });

  final String fichaId;
  final double quantidade;

  /// Minutos de forno deste sabor (cada um pode ter o seu).
  final int duracaoMin;

  /// `true` quando já saiu do forno.
  final bool tirado;

  ItemFornada comoTirado() => ItemFornada(
    fichaId: fichaId,
    quantidade: quantidade,
    duracaoMin: duracaoMin,
    tirado: true,
  );

  Map<String, dynamic> toJson() => {
    'ficha': fichaId,
    'quantidade': quantidade,
    'duracao_min': duracaoMin,
    'tirado': tirado,
  };
}

/// Cookies no forno: o que entrou, quando e quantos minutos leva cada sabor.
class Fornada {
  const Fornada({
    required this.id,
    required this.localId,
    required this.inicio,
    required this.duracaoMin,
    this.itens = const [],
    this.movimentoIds = const [],
    this.estado = EstadoFornada.noForno,
  });

  final String id;
  final String localId;

  /// Hora local a que entrou no forno.
  final DateTime inicio;

  /// O maior tempo entre os sabores (quando a fornada inteira fica pronta).
  final int duracaoMin;
  final List<ItemFornada> itens;

  /// Os registos de "assados" criados com a fornada (para desfazer).
  final List<String> movimentoIds;
  final EstadoFornada estado;

  DateTime get fim => inicio.add(Duration(minutes: duracaoMin));

  /// Quanto falta para a fornada inteira (negativo = já devia ter saído).
  Duration restante(DateTime agora) => fim.difference(agora);

  /// `true` quando o último sabor já cumpriu o tempo.
  bool pronta(DateTime agora) => restante(agora).inSeconds <= 0;

  /// Há sabores com tempos diferentes?
  bool get temTemposDiferentes =>
      itens.map((i) => i.duracaoMin).toSet().length > 1;

  DateTime fimDe(ItemFornada i) => inicio.add(Duration(minutes: i.duracaoMin));

  /// Quanto falta para este sabor (negativo = passou do tempo).
  Duration restanteDe(ItemFornada i, DateTime agora) =>
      fimDe(i).difference(agora);

  /// Há quanto tempo está no forno (nunca mais que o tempo dele + atraso).
  Duration decorrido(DateTime agora) => agora.difference(inicio);

  bool prontoItem(ItemFornada i, DateTime agora) =>
      restanteDe(i, agora).inSeconds <= 0;

  /// Os sabores que ainda estão no forno, o que sai primeiro à frente.
  List<ItemFornada> noForno(DateTime agora) =>
      [
        for (final i in itens)
          if (!i.tirado) i,
      ]..sort(
        (a, b) => restanteDe(a, agora).compareTo(restanteDe(b, agora)),
      );

  bool get todosTirados => itens.isNotEmpty && itens.every((i) => i.tirado);

  double get totalUnidades => itens.fold(0, (s, i) => s + i.quantidade);

  Fornada comItemTirado(String fichaId) => Fornada(
    id: id,
    localId: localId,
    inicio: inicio,
    duracaoMin: duracaoMin,
    itens: [
      for (final i in itens) i.fichaId == fichaId ? i.comoTirado() : i,
    ],
    movimentoIds: movimentoIds,
    estado: estado,
  );

  factory Fornada.fromRecord(RecordModel r) {
    final duracaoGeral = r.getIntValue('duracao_min');
    final itens = <ItemFornada>[];
    final bruto = r.data['itens'];
    if (bruto is List) {
      for (final e in bruto) {
        if (e is! Map) continue;
        final f = '${e['ficha'] ?? ''}';
        final q = (e['quantidade'] as num?)?.toDouble() ?? 0;
        final d = (e['duracao_min'] as num?)?.toInt() ?? duracaoGeral;
        if (f.isNotEmpty && q > 0) {
          itens.add(
            ItemFornada(
              fichaId: f,
              quantidade: q,
              duracaoMin: d > 0 ? d : duracaoGeral,
              tirado: e['tirado'] == true,
            ),
          );
        }
      }
    }
    final movs = <String>[];
    final brutoMovs = r.data['movimentos'];
    if (brutoMovs is List) {
      for (final e in brutoMovs) {
        if (e != null && '$e'.isNotEmpty) movs.add('$e');
      }
    }
    return Fornada(
      id: r.id,
      localId: r.getStringValue('local'),
      inicio: (DateTime.tryParse(r.getStringValue('inicio')) ?? DateTime.now())
          .toLocal(),
      duracaoMin: duracaoGeral,
      itens: itens,
      movimentoIds: movs,
      estado: EstadoFornada.fromApi(r.getStringValue('estado')),
    );
  }
}

/// O maior tempo de uma lista de sabores (quando a fornada inteira fica
/// pronta); `null` se nenhum o tem definido.
int? duracaoDaFornada(
  Iterable<String> fichaIds,
  Map<String, int> tempoPorFicha,
) {
  var maior = 0;
  for (final f in fichaIds) {
    final t = tempoPorFicha[f] ?? 0;
    if (t > maior) maior = t;
  }
  return maior > 0 ? maior : null;
}

/// "07:32" / "1:02:10" para um cronómetro.
String cronometro(Duration d) {
  final t = d.isNegative ? -d : d;
  String d2(int n) => n.toString().padLeft(2, '0');
  final h = t.inHours;
  final m = t.inMinutes.remainder(60);
  final s = t.inSeconds.remainder(60);
  return h > 0 ? '$h:${d2(m)}:${d2(s)}' : '${d2(m)}:${d2(s)}';
}

/// Um sabor no forno, com a fornada de onde vem (para resumos que juntam
/// várias fornadas).
typedef SaborNoForno = ({Fornada fornada, ItemFornada item});

/// Todos os sabores ainda no forno, o que sai primeiro à frente.
List<SaborNoForno> saboresNoForno(List<Fornada> fornadas, DateTime agora) {
  final out = <SaborNoForno>[
    for (final f in fornadas)
      if (f.estado == EstadoFornada.noForno)
        for (final i in f.itens)
          if (!i.tirado) (fornada: f, item: i),
  ];
  out.sort(
    (a, b) => a.fornada
        .restanteDe(a.item, agora)
        .compareTo(b.fornada.restanteDe(b.item, agora)),
  );
  return out;
}
