import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';

/// Idade máxima (horas) de um backup para ser considerado em dia: o
/// PocketBase faz um por noite, por isso 30 h dá folga.
const idadeMaxBackupHoras = 30;

/// O estado dos backups, como o servidor o vê (só leitura).
class EstadoBackups {
  const EstadoBackups({
    this.localTotal = 0,
    this.ultimoNome = '',
    this.ultimoTamanho = 0,
    this.ultimoQuando,
    this.externoEstado = 'desconhecido',
    this.externoQuando,
    this.externoFicheiro = '',
    this.externoMensagem = '',
  });

  final int localTotal;
  final String ultimoNome;
  final int ultimoTamanho;
  final DateTime? ultimoQuando;

  /// `ok`, `falha` ou `desconhecido` (o script da cópia externa nunca correu).
  final String externoEstado;
  final DateTime? externoQuando;
  final String externoFicheiro;
  final String externoMensagem;

  factory EstadoBackups.fromJson(Map<String, dynamic> j) {
    final local = j['local'] is Map
        ? Map<String, dynamic>.from(j['local'] as Map)
        : const <String, dynamic>{};
    final ultimo = local['ultimo'] is Map
        ? Map<String, dynamic>.from(local['ultimo'] as Map)
        : const <String, dynamic>{};
    final ext = j['externo'] is Map
        ? Map<String, dynamic>.from(j['externo'] as Map)
        : const <String, dynamic>{};
    return EstadoBackups(
      localTotal: (local['total'] as num?)?.toInt() ?? 0,
      ultimoNome: (ultimo['nome'] ?? '').toString(),
      ultimoTamanho: (ultimo['tamanho'] as num?)?.toInt() ?? 0,
      ultimoQuando: DateTime.tryParse((ultimo['quando'] ?? '').toString()),
      externoEstado: (ext['estado'] ?? 'desconhecido').toString(),
      externoQuando: DateTime.tryParse((ext['quando'] ?? '').toString()),
      externoFicheiro: (ext['ficheiro'] ?? '').toString(),
      externoMensagem: (ext['mensagem'] ?? '').toString(),
    );
  }

  Duration? idadeLocal(DateTime agora) =>
      ultimoQuando == null ? null : agora.difference(ultimoQuando!);

  Duration? idadeExterno(DateTime agora) =>
      externoQuando == null ? null : agora.difference(externoQuando!);

  bool localAtrasado(DateTime agora) {
    final i = idadeLocal(agora);
    return i == null || i.inHours > idadeMaxBackupHoras;
  }

  bool get externoFalhou => externoEstado == 'falha';

  bool externoAtrasado(DateTime agora) {
    if (externoEstado != 'ok') return false;
    final i = idadeExterno(agora);
    return i == null || i.inHours > idadeMaxBackupHoras;
  }

  /// Há algo a corrigir: backup local em falta/atrasado ou cópia externa a
  /// falhar/atrasada. ("Desconhecido" não é problema: pode nem estar instalada.)
  bool problema([DateTime? agora]) {
    final t = agora ?? DateTime.now().toUtc();
    return localAtrasado(t) || externoFalhou || externoAtrasado(t);
  }

  /// Frases curtas do que está mal.
  List<String> avisos([DateTime? agora]) {
    final t = agora ?? DateTime.now().toUtc();
    return [
      if (localTotal == 0)
        'Ainda não há nenhum backup automático guardado.'
      else if (localAtrasado(t))
        'O último backup automático tem ${idadeLocal(t)?.inHours ?? '?'} h — devia haver um por noite.',
      if (externoFalhou)
        'A cópia para fora do servidor falhou'
            '${externoMensagem.isEmpty ? '.' : ': $externoMensagem'}',
      if (externoAtrasado(t))
        'A última cópia para fora do servidor tem ${idadeExterno(t)?.inHours ?? '?'} h.',
    ];
  }
}

class BackupsRepository {
  BackupsRepository(this._pb);
  final PocketBase _pb;

  Future<EstadoBackups> estado() async {
    final res = await _pb.send('/api/gc_turnkey/backups/estado');
    return EstadoBackups.fromJson(
      res is Map ? Map<String, dynamic>.from(res) : const <String, dynamic>{},
    );
  }
}

final backupsRepositoryProvider = Provider<BackupsRepository>(
  (ref) => BackupsRepository(ref.watch(pbProvider)),
);

/// O estado dos backups (só para administradores; os outros não chamam).
final estadoBackupsProvider = FutureProvider.autoDispose<EstadoBackups?>((
  ref,
) async {
  if (!ref.watch(currentPapelProvider).canEditConfig) return null;
  return ref.watch(backupsRepositoryProvider).estado();
});
