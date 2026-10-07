import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../domain/vigia.dart';

class VigiaRepository {
  VigiaRepository(this._pb);
  final PocketBase _pb;

  /// O estado do vigia; `null` se esta conta não é o dono do servidor.
  Future<EstadoVigia?> estado() async {
    final res = await _pb.send('/api/gc_turnkey/seguranca/vigia');
    final m = res is Map
        ? Map<String, dynamic>.from(res)
        : const <String, dynamic>{};
    if (m['operador'] != true) return null;
    return EstadoVigia.fromJson(m);
  }

  /// "Já verifiquei": o vigia passa a ver isto como normal.
  Future<void> aceitar(String id) => _pb.send(
    '/api/gc_turnkey/seguranca/vigia/aceitar',
    method: 'POST',
    body: {'id': id},
  );
}

final vigiaRepositoryProvider = Provider<VigiaRepository>(
  (ref) => VigiaRepository(ref.watch(pbProvider)),
);

/// O vigia (só para o proprietário/administrador; `null` se não é o dono do
/// servidor). Falhas de rede dão `null` — o Início nunca parte por isto.
final vigiaProvider = FutureProvider.autoDispose<EstadoVigia?>((ref) async {
  if (!ref.watch(currentPapelProvider).canEditConfig) return null;
  try {
    return await ref.watch(vigiaRepositoryProvider).estado();
  } on Object {
    return null;
  }
});
