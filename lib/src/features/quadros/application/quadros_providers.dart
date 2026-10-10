import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/application/settings_providers.dart';
import '../data/quadros_repository.dart';
import '../domain/quadro.dart';

/// Os quadros ativos da empresa.
final quadrosProvider = FutureProvider.autoDispose<List<Quadro>>(
  (ref) => ref.watch(quadrosRepositoryProvider).listarQuadros(),
);

/// Os quadros arquivados (para os recuperar).
final quadrosArquivadosProvider = FutureProvider.autoDispose<List<Quadro>>(
  (ref) => ref.watch(quadrosRepositoryProvider).listarQuadros(arquivados: true),
);

/// O quadro aberto agora (`null` = o primeiro da lista).
final quadroEscolhidoProvider = StateProvider<String?>((_) => null);

/// Tudo o que o ecrã de um quadro precisa, de uma vez.
class DadosQuadro {
  const DadosQuadro({
    required this.colunas,
    required this.tarefas,
    required this.comentarios,
  });

  final List<ColunaQuadro> colunas;
  final List<Tarefa> tarefas;

  /// Só os campos leves (para contar e ver menções por ler).
  final List<ComentarioTarefa> comentarios;

  Set<String> get colunasFeitas => {
    for (final c in colunas)
      if (c.concluida) c.id,
  };

  Map<String, int> get nComentarios {
    final m = <String, int>{};
    for (final c in comentarios) {
      m[c.tarefaId] = (m[c.tarefaId] ?? 0) + 1;
    }
    return m;
  }

  Set<String> tarefasComMencaoPorLer(String uid) => {
    for (final c in comentarios)
      if (c.mencaoPorLer(uid)) c.tarefaId,
  };
}

/// Fases, tarefas abertas e comentários de um quadro. Fica à escuta: quando
/// alguém da equipa mexe no quadro, recarrega sozinho (sem piscar).
final dadosQuadroProvider = FutureProvider.autoDispose
    .family<DadosQuadro, String>((ref, quadroId) async {
      final repo = ref.watch(quadrosRepositoryProvider);

      Timer? espera;
      var vivo = true;
      final desligar = repo.ouvirQuadro(quadroId, () {
        // várias mudanças seguidas (mover = 1 a 2 eventos) → um só recarregar
        espera?.cancel();
        espera = Timer(const Duration(milliseconds: 400), () {
          if (vivo) ref.invalidateSelf();
        });
      });
      ref.onDispose(() {
        vivo = false;
        espera?.cancel();
        unawaited(desligar.then((f) => f()));
      });

      final r = await Future.wait([
        repo.listarColunas(quadroId),
        repo.listarTarefas(quadroId),
        repo.comentariosDoQuadro(quadroId),
      ]);
      return DadosQuadro(
        colunas: r[0] as List<ColunaQuadro>,
        tarefas: r[1] as List<Tarefa>,
        comentarios: r[2] as List<ComentarioTarefa>,
      );
    });

/// Tarefas arquivadas de um quadro (para as recuperar).
final tarefasArquivadasProvider = FutureProvider.autoDispose
    .family<List<Tarefa>, String>(
      (ref, quadroId) => ref
          .watch(quadrosRepositoryProvider)
          .listarTarefas(quadroId, arquivadas: true),
    );

/// Os comentários completos de uma tarefa (a conversa).
final comentariosTarefaProvider = FutureProvider.autoDispose
    .family<List<ComentarioTarefa>, String>(
      (ref, tarefaId) =>
          ref.watch(quadrosRepositoryProvider).listarComentarios(tarefaId),
    );

/// As pessoas da empresa (responsáveis e menções), por nome.
final pessoasEquipaProvider = Provider.autoDispose<List<PessoaEquipa>>((ref) {
  final membros = ref.watch(teamMembersProvider).valueOrNull ?? const [];
  return [
    for (final m in membros)
      PessoaEquipa(m.id, m.nome.trim().isEmpty ? m.email : m.nome.trim()),
  ];
});

/// Movimentos feitos agora e ainda não confirmados pelo servidor: o cartão já
/// aparece no sítio novo (sem esperar pela rede). id → (fase, ordem).
final movimentosPendentesProvider =
    StateProvider<Map<String, ({String coluna, double ordem})>>(
      (_) => const {},
    );

/// Aplica os movimentos pendentes às tarefas vindas do servidor.
List<Tarefa> comMovimentos(
  List<Tarefa> tarefas,
  Map<String, ({String coluna, double ordem})> pendentes,
) => [
  for (final t in tarefas)
    if (pendentes[t.id] case final m?)
      t.copyWith(colunaId: m.coluna, ordem: m.ordem)
    else
      t,
];

/// As minhas tarefas com prazo até hoje (atrasadas ou para hoje), em todos os
/// quadros — para o Início.
final minhasTarefasHojeProvider = FutureProvider.autoDispose<List<Tarefa>>(
  (ref) =>
      ref.watch(quadrosRepositoryProvider).minhasComPrazoAte(DateTime.now()),
);

/// Os comentários em que me mencionaram e que ainda não vi — para o Início.
final minhasMencoesProvider =
    FutureProvider.autoDispose<List<ComentarioTarefa>>(
      (ref) => ref.watch(quadrosRepositoryProvider).mencoesPorLer(),
    );
