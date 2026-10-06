import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notas_repository.dart';
import '../domain/nota.dart';

/// As anotações da equipa (`true` = as arquivadas/tratadas).
final notasProvider = FutureProvider.autoDispose.family<List<Nota>, bool>(
  (ref, arquivadas) =>
      ref.watch(notasRepositoryProvider).listar(arquivadas: arquivadas),
);

/// Os lembretes que já chegaram e ainda não foram tratados (cartão no Início).
final notasParaHojeProvider = Provider.autoDispose<List<Nota>>((ref) {
  final notas = ref.watch(notasProvider(false)).valueOrNull ?? const [];
  final hoje = DateTime.now();
  return ordenarNotas(notas.where((n) => n.paraHoje(hoje)));
});
