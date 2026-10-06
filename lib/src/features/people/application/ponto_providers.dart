import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ponto_repository.dart';
import '../domain/ponto.dart';

/// As marcações de um mês (o dia 1 do mês identifica-o). O administrador vê
/// todas; os outros só as suas.
final pontoMesProvider = FutureProvider.autoDispose
    .family<List<RegistoPonto>, DateTime>((ref, mes) {
      final desde = DateTime(mes.year, mes.month);
      final ate = DateTime(mes.year, mes.month + 1);
      return ref.watch(pontoRepositoryProvider).listar(desde: desde, ate: ate);
    });

/// A última marcação de cada pessoa (últimas 36 horas), pelo servidor.
final pontoEstadoProvider =
    FutureProvider.autoDispose<Map<String, UltimoPonto>>(
      (ref) => ref.watch(pontoRepositoryProvider).estado(),
    );

/// Marcações de hoje e de ontem (para "quem está a trabalhar").
final pontoRecenteProvider = FutureProvider.autoDispose<List<RegistoPonto>>((
  ref,
) {
  final agora = DateTime.now();
  final desde = DateTime(agora.year, agora.month, agora.day - 1);
  final ate = DateTime(agora.year, agora.month, agora.day + 1);
  return ref.watch(pontoRepositoryProvider).listar(desde: desde, ate: ate);
});
