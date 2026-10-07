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

  /// O texto EXATO que seria enviado à IA (anonimizado pelo servidor) — não
  /// envia nada. Traz também a explicação guardada, se já houver.
  Future<PreviaIa> previaExplicacao(String id) async {
    final res = await _pb.send(
      '/api/gc_turnkey/seguranca/vigia/explicar',
      method: 'POST',
      body: {'id': id, 'previa': true},
    );
    return PreviaIa.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// Pede a explicação à IA (envia o texto da pré-visualização). Com
  /// [refazer] ignora a que está guardada.
  Future<ExplicacaoIa> explicar(String id, {bool refazer = false}) async {
    final res = await _pb.send(
      '/api/gc_turnkey/seguranca/vigia/explicar',
      method: 'POST',
      body: {'id': id, if (refazer) 'refazer': true},
    );
    final m = Map<String, dynamic>.from(res as Map);
    return ExplicacaoIa.fromJson(
      Map<String, dynamic>.from(m['explicacao'] as Map),
      provider: '${m['provider'] ?? ''}',
      doCache: m['doCache'] == true,
    );
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
