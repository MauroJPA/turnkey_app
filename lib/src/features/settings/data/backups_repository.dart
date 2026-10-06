import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';

/// Idade máxima (horas) de um backup para ser considerado em dia: o
/// PocketBase faz um por noite, por isso 30 h dá folga.
const idadeMaxBackupHoras = 30;

/// Espaço livre mínimo (em %) e absoluto (KB, ~2 GB) antes de avisar.
const discoLivreMinPct = 15;
const discoLivreMinKb = 2 * 1024 * 1024;

/// Resultado de um teste ao backup (integridade ou restauro completo).
class TesteBackup {
  const TesteBackup({
    this.ok,
    this.quando,
    this.ficheiro = '',
    this.segundos,
    this.mensagem = '',
  });

  final bool? ok;
  final DateTime? quando;
  final String ficheiro;
  final int? segundos;
  final String mensagem;

  static TesteBackup? tentar(Object? v) {
    if (v is! Map) return null;
    final j = Map<String, dynamic>.from(v);
    return TesteBackup(
      ok: j['ok'] is bool ? j['ok'] as bool : null,
      quando: DateTime.tryParse((j['quando'] ?? '').toString()),
      ficheiro: (j['ficheiro'] ?? '').toString(),
      segundos: (j['segundos'] as num?)?.toInt(),
      mensagem: (j['mensagem'] ?? '').toString(),
    );
  }
}

/// Espaço num disco do servidor.
class EspacoDisco {
  const EspacoDisco({required this.livreKb, required this.totalKb});

  final int livreKb;
  final int totalKb;

  double get livrePct => totalKb <= 0 ? 100 : livreKb * 100 / totalKb;

  bool get baixo => livrePct < discoLivreMinPct || livreKb < discoLivreMinKb;

  String get livreTexto {
    final gb = livreKb / 1024 / 1024;
    return gb >= 10
        ? '${gb.toStringAsFixed(0)} GB'
        : '${gb.toStringAsFixed(1)} GB';
  }

  static EspacoDisco? tentar(Object? v) {
    if (v is! Map) return null;
    final l = (v['livreKb'] as num?)?.toInt();
    final t = (v['totalKb'] as num?)?.toInt();
    if (l == null || t == null || t <= 0) return null;
    return EspacoDisco(livreKb: l, totalKb: t);
  }
}

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
    this.discoDados,
    this.discoBackups,
    this.integridade,
    this.restauro,
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

  /// Disco dos dados e (se for outro disco) o dos backups.
  final EspacoDisco? discoDados;
  final EspacoDisco? discoBackups;

  /// Último teste de integridade (semanal) e de restauro (mensal).
  final TesteBackup? integridade;
  final TesteBackup? restauro;

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
      discoDados: EspacoDisco.tentar(
        j['disco'] is Map ? (j['disco'] as Map)['dados'] : null,
      ),
      discoBackups: EspacoDisco.tentar(
        j['disco'] is Map ? (j['disco'] as Map)['backups'] : null,
      ),
      integridade: TesteBackup.tentar(j['integridade']),
      restauro: TesteBackup.tentar(j['restauro']),
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

  /// O disco onde estão os backups (ou os dados, se for o mesmo) está a acabar.
  bool get discoBaixo =>
      (discoBackups ?? discoDados)?.baixo == true || discoDados?.baixo == true;

  bool get integridadeFalhou => integridade?.ok == false;
  bool get restauroFalhou => restauro?.ok == false;

  bool externoAtrasado(DateTime agora) {
    if (externoEstado != 'ok') return false;
    final i = idadeExterno(agora);
    return i == null || i.inHours > idadeMaxBackupHoras;
  }

  /// Há algo a corrigir: backup local em falta/atrasado ou cópia externa a
  /// falhar/atrasada. ("Desconhecido" não é problema: pode nem estar instalada.)
  bool problema([DateTime? agora]) {
    final t = agora ?? DateTime.now().toUtc();
    return localAtrasado(t) ||
        externoFalhou ||
        externoAtrasado(t) ||
        discoBaixo ||
        integridadeFalhou ||
        restauroFalhou;
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
      if (discoBaixo)
        'O servidor está com pouco espaço livre '
            '(${(discoBackups ?? discoDados)!.livreTexto}): os backups podem deixar de caber.',
      if (integridadeFalhou)
        'O teste ao último backup falhou'
            '${integridade!.mensagem.isEmpty ? '.' : ': ${integridade!.mensagem}'}',
      if (restauroFalhou)
        'O teste de restauro falhou'
            '${restauro!.mensagem.isEmpty ? '.' : ': ${restauro!.mensagem}'}',
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

  /// Testa já a integridade do último backup (só administradores).
  Future<TesteBackup?> testarAgora() async {
    final res = await _pb.send(
      '/api/gc_turnkey/backups/testar',
      method: 'POST',
    );
    return TesteBackup.tentar(res);
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
