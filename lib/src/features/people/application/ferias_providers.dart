import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ferias_repository.dart';
import '../domain/ferias.dart';

/// As ausências (férias, baixas…) que tocam um ano.
final feriasAnoProvider = FutureProvider.autoDispose
    .family<List<Ausencia>, int>(
      (ref, ano) => ref.watch(feriasRepositoryProvider).doAno(ano),
    );

/// O direito a férias de cada pessoa num ano (chave da pessoa → dias úteis).
final feriasDireitosProvider = FutureProvider.autoDispose
    .family<Map<String, int>, int>(
      (ref, ano) => ref.watch(feriasRepositoryProvider).direitos(ano),
    );
