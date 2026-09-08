import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mep_repository.dart';
import '../domain/mep_plano.dart';

typedef MepArgs = ({
  String receitaId,
  double kg,
  String? formatoId,
  String? recheioId,
});

final mepPlanoProvider =
    FutureProvider.autoDispose.family<MepPlano, MepArgs>((ref, args) {
  return ref.watch(mepRepositoryProvider).plano(
        args.receitaId,
        args.kg,
        formatoId: args.formatoId,
        recheioId: args.recheioId,
      );
});
