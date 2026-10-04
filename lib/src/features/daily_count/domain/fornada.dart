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

/// Um sabor e quantidade dentro de uma fornada.
class ItemFornada {
  const ItemFornada({required this.fichaId, required this.quantidade});
  final String fichaId;
  final double quantidade;

  Map<String, dynamic> toJson() => {'ficha': fichaId, 'quantidade': quantidade};
}

/// Cookies no forno: o que entrou, quando e quantos minutos leva.
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
  final int duracaoMin;
  final List<ItemFornada> itens;

  /// Os registos de "assados" criados com a fornada (para desfazer).
  final List<String> movimentoIds;
  final EstadoFornada estado;

  DateTime get fim => inicio.add(Duration(minutes: duracaoMin));

  /// Quanto falta (negativo = já devia ter saído).
  Duration restante(DateTime agora) => fim.difference(agora);

  /// `true` quando o tempo já acabou.
  bool pronta(DateTime agora) => restante(agora).inSeconds <= 0;

  double get totalUnidades => itens.fold(0, (s, i) => s + i.quantidade);

  factory Fornada.fromRecord(RecordModel r) {
    final itens = <ItemFornada>[];
    final bruto = r.data['itens'];
    if (bruto is List) {
      for (final e in bruto) {
        if (e is! Map) continue;
        final f = '${e['ficha'] ?? ''}';
        final q = (e['quantidade'] as num?)?.toDouble() ?? 0;
        if (f.isNotEmpty && q > 0) {
          itens.add(ItemFornada(fichaId: f, quantidade: q));
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
      duracaoMin: r.getIntValue('duracao_min'),
      itens: itens,
      movimentoIds: movs,
      estado: EstadoFornada.fromApi(r.getStringValue('estado')),
    );
  }
}

/// Os minutos de forno de uma fornada: o maior tempo de assadura entre os
/// sabores (que têm o tempo definido na ficha). `null` se nenhum o tem.
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
