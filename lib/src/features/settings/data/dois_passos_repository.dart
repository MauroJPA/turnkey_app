import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';

/// Estado da verificação em 2 passos (palavra-passe + código por email) dos
/// administradores.
class EstadoDoisPassos {
  const EstadoDoisPassos({
    this.ativo = false,
    this.smtp = false,
    this.podeAlterar = false,
  });

  /// Está ligada: owner e admin precisam do código por email para entrar.
  final bool ativo;

  /// O servidor consegue enviar emails (sem isto os códigos não chegam).
  final bool smtp;

  /// Só o proprietário liga/desliga.
  final bool podeAlterar;

  factory EstadoDoisPassos.fromJson(Map<String, dynamic> j) => EstadoDoisPassos(
    ativo: j['ativo'] == true,
    smtp: j['smtp'] == true,
    podeAlterar: j['podeAlterar'] == true,
  );
}

class DoisPassosRepository {
  DoisPassosRepository(this._pb);
  final PocketBase _pb;

  Future<EstadoDoisPassos> estado() async {
    final res = await _pb.send('/api/gc_turnkey/seguranca/2fa');
    return EstadoDoisPassos.fromJson(
      res is Map ? Map<String, dynamic>.from(res) : const <String, dynamic>{},
    );
  }

  Future<EstadoDoisPassos> definir(bool ativo) async {
    final res = await _pb.send(
      '/api/gc_turnkey/seguranca/2fa',
      method: 'POST',
      body: {'ativo': ativo},
    );
    return EstadoDoisPassos.fromJson(
      res is Map ? Map<String, dynamic>.from(res) : const <String, dynamic>{},
    );
  }
}

final doisPassosRepositoryProvider = Provider<DoisPassosRepository>(
  (ref) => DoisPassosRepository(ref.watch(pbProvider)),
);

/// O estado do 2FA (só para administradores).
final estadoDoisPassosProvider = FutureProvider.autoDispose<EstadoDoisPassos?>((
  ref,
) async {
  if (!ref.watch(currentPapelProvider).canEditConfig) return null;
  return ref.watch(doisPassosRepositoryProvider).estado();
});
