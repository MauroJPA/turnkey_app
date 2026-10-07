import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../domain/arranque.dart';

/// O que falta configurar (só a administração). Falhas de rede dão `null`: o
/// Início nunca parte por causa disto.
final arranqueProvider = FutureProvider.autoDispose<Arranque?>((ref) async {
  if (!ref.watch(currentPapelProvider).canEditConfig) return null;
  try {
    final res = await ref.watch(pbProvider).send('/api/gc_turnkey/arranque');
    if (res is! Map) return null;
    return Arranque.fromJson(Map<String, dynamic>.from(res));
  } on Object {
    return null;
  }
});
