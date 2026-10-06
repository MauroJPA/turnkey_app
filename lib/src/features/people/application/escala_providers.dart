import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/escala_repository.dart';
import '../domain/escala.dart';

typedef IntervaloEscala = ({DateTime de, DateTime ate});

/// O horário habitual de toda a equipa.
final escalaModeloProvider = FutureProvider.autoDispose<List<TurnoModelo>>(
  (ref) => ref.watch(escalaRepositoryProvider).modelo(),
);

/// As alterações de dias concretos entre duas datas (`ate` exclusive).
final escalaExcecoesProvider = FutureProvider.autoDispose
    .family<List<ExcecaoEscala>, IntervaloEscala>(
      (ref, i) =>
          ref.watch(escalaRepositoryProvider).excecoes(de: i.de, ate: i.ate),
    );
