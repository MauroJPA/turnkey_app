import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_user.dart';
import '../data/formacoes_repository.dart';
import '../domain/formacao.dart';

/// As formações e certificados que o utilizador pode ver.
final formacoesProvider = FutureProvider.autoDispose<List<Formacao>>(
  (ref) => ref.watch(formacoesRepositoryProvider).listar(),
);

/// Caducadas ou a caducar (para o cartão do Início): só a administração, que
/// vê a equipa toda.
final formacoesEmAlertaProvider = Provider.autoDispose<List<Formacao>>((ref) {
  if (!ref.watch(currentPapelProvider).canEditConfig) return const [];
  final todas = ref.watch(formacoesProvider).valueOrNull ?? const [];
  return formacoesEmAlerta(todas, DateTime.now());
});
