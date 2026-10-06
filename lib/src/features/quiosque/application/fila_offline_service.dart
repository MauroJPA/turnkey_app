import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/prefs_locais.dart';
import '../../haccp/application/haccp_providers.dart';
import '../../haccp/data/haccp_repository.dart';
import '../../haccp/domain/haccp.dart';
import '../../people/application/ponto_providers.dart';
import '../../people/data/ponto_repository.dart';
import '../../people/domain/ponto.dart';
import '../domain/colaborador.dart';
import '../domain/fila_offline.dart';
import 'colaboradores_providers.dart';

const _chaveFila = 'quiosque_fila';
const _chaveRejeitados = 'quiosque_rejeitados';
const _chaveEstados = 'quiosque_estados';
const _chavePessoas = 'quiosque_pessoas';
const _chavePonto = 'quiosque_ponto';

/// Depois de quantos envios falhados (por razões que não são a ligação) um
/// registo é posto de lado.
const tentativasMaximas = 5;

/// O que o quiosque tem por enviar.
class EstadoFila {
  const EstadoFila({
    this.pendentes = const [],
    this.semLigacao = false,
    this.rejeitados = 0,
    this.aEnviar = false,
  });

  final List<RegistoPendente> pendentes;

  /// A última tentativa de falar com o servidor falhou por falta de ligação.
  final bool semLigacao;

  /// Registos que o servidor não aceitou (ficam guardados para ajuda).
  final int rejeitados;
  final bool aEnviar;

  EstadoFila copiar({
    List<RegistoPendente>? pendentes,
    bool? semLigacao,
    int? rejeitados,
    bool? aEnviar,
  }) => EstadoFila(
    pendentes: pendentes ?? this.pendentes,
    semLigacao: semLigacao ?? this.semLigacao,
    rejeitados: rejeitados ?? this.rejeitados,
    aEnviar: aEnviar ?? this.aEnviar,
  );
}

/// Os registos do quiosque que esperam por ligação. Cada toque tenta enviar
/// logo; se o servidor não responde, guarda-o neste aparelho e volta a tentar
/// de vez em quando (e quando se pede).
class FilaOffline extends Notifier<EstadoFila> {
  @override
  EstadoFila build() => EstadoFila(pendentes: lerFila(lerPref(_chaveFila)));

  HaccpRepository get _repo => ref.read(haccpRepositoryProvider);

  void _guardar(List<RegistoPendente> fila) {
    guardarPref(_chaveFila, codificarFila(fila));
    state = state.copiar(pendentes: fila);
  }

  /// Regista uma tarefa. Devolve `true` se chegou ao servidor e `false` se
  /// ficou guardada no aparelho à espera de ligação. Outros erros (permissão,
  /// dados inválidos) sobem para quem chamou.
  Future<bool> registar({
    required String controloId,
    required DateTime dataHora,
    double? valor,
    required bool conforme,
    String responsavel = '',
    String notas = '',
    String acaoCorretiva = '',
  }) async {
    final id = novoIdPb();
    try {
      await ref
          .read(haccpActionsProvider)
          .registar(
            id: id,
            controloId: controloId,
            dataHora: dataHora,
            valor: valor,
            conforme: conforme,
            responsavel: responsavel,
            notas: notas,
            acaoCorretiva: acaoCorretiva,
          );
      state = state.copiar(semLigacao: false);
      return true;
    } on Object catch (e) {
      if (!eErroDeLigacao(e)) rethrow;
      _guardar([
        ...state.pendentes,
        RegistoPendente(
          id: id,
          controloId: controloId,
          dataHora: dataHora,
          conforme: conforme,
          valor: valor,
          responsavel: responsavel,
          notas: notas,
          acaoCorretiva: acaoCorretiva,
        ),
      ]);
      state = state.copiar(semLigacao: true);
      return false;
    }
  }

  /// Guarda no aparelho a última marcação da pessoa (é daí que o quiosque
  /// sabe o que oferecer a seguir, mesmo sem ligação).
  void _lembrarPonto(String pessoa, TipoPonto tipo, DateTime quando) {
    final atual = lerEstadoPonto(lerPref(_chavePonto));
    guardarPref(
      _chavePonto,
      codificarEstadoPonto(
        juntarEstadoPonto(atual, {pessoa: UltimoPonto(tipo, quando)}),
      ),
    );
    ref.invalidate(estadoPontoQuiosqueProvider);
  }

  /// Marca o ponto de uma pessoa (quiosque). Devolve `true` se chegou ao
  /// servidor e `false` se ficou guardada à espera de ligação.
  Future<bool> registarPonto({
    required String pessoa,
    required String nome,
    String userId = '',
    required TipoPonto tipo,
    required DateTime dataHora,
  }) async {
    final id = novoIdPb();
    try {
      await ref
          .read(pontoRepositoryProvider)
          .registar(
            id: id,
            pessoa: pessoa,
            nome: nome,
            userId: userId,
            tipo: tipo,
            dataHora: dataHora,
            origem: OrigemPonto.quiosque,
          );
      state = state.copiar(semLigacao: false);
      _lembrarPonto(pessoa, tipo, dataHora);
      return true;
    } on Object catch (e) {
      if (!eErroDeLigacao(e)) rethrow;
      _guardar([
        ...state.pendentes,
        RegistoPendente(
          id: id,
          controloId: '',
          dataHora: dataHora,
          conforme: true,
          ponto: PontoPendente(
            pessoa: pessoa,
            nome: nome,
            userId: userId,
            tipo: tipo.api,
          ),
        ),
      ]);
      state = state.copiar(semLigacao: true);
      _lembrarPonto(pessoa, tipo, dataHora);
      return false;
    }
  }

  /// Tenta enviar tudo o que está guardado, por ordem. Devolve quantos
  /// chegaram ao servidor.
  Future<int> sincronizar() async {
    if (state.aEnviar || state.pendentes.isEmpty) return 0;
    state = state.copiar(aEnviar: true);
    var enviados = 0;
    final restantes = <RegistoPendente>[];
    var parar = false;
    var rejeitados = state.rejeitados;
    try {
      for (final r in state.pendentes) {
        if (parar) {
          restantes.add(r);
          continue;
        }
        try {
          final p = r.ponto;
          if (p != null) {
            await ref
                .read(pontoRepositoryProvider)
                .registar(
                  id: r.id,
                  pessoa: p.pessoa,
                  nome: p.nome,
                  userId: p.userId,
                  tipo: TipoPonto.fromApi(p.tipo) ?? TipoPonto.entrada,
                  dataHora: r.dataHora,
                  origem: OrigemPonto.quiosque,
                );
          } else {
            await _repo.registar(
              id: r.id,
              controloId: r.controloId,
              dataHora: r.dataHora,
              valor: r.valor,
              conforme: r.conforme,
              responsavel: r.responsavel,
              notas: r.notas,
              acaoCorretiva: r.acaoCorretiva,
            );
          }
          enviados++;
        } on Object catch (e) {
          if (eIdJaExiste(e)) {
            enviados++; // já tinha chegado antes
          } else if (eErroDeLigacao(e)) {
            parar = true;
            restantes.add(r);
            state = state.copiar(semLigacao: true);
          } else if (eErroDeSessao(e)) {
            parar = true; // volta a tentar quando alguém entrar de novo
            restantes.add(r);
          } else if (r.tentativas + 1 >= tentativasMaximas) {
            rejeitados++;
            _guardarRejeitado(r);
          } else {
            restantes.add(r.maisUmaTentativa());
          }
        }
      }
    } finally {
      _guardar(restantes);
      state = state.copiar(
        aEnviar: false,
        rejeitados: rejeitados,
        semLigacao: parar ? state.semLigacao : false,
      );
    }
    if (enviados > 0) {
      ref.read(haccpActionsProvider).refrescar();
      ref.invalidate(estadoPontoQuiosqueProvider);
    }
    return enviados;
  }

  void _guardarRejeitado(RegistoPendente r) {
    try {
      final antigos = jsonDecode(lerPref(_chaveRejeitados) ?? '[]');
      final lista = antigos is List ? antigos : <Object?>[];
      guardarPref(_chaveRejeitados, jsonEncode([...lista, r.toJson()]));
    } on FormatException {
      guardarPref(_chaveRejeitados, jsonEncode([r.toJson()]));
    }
  }
}

final filaOfflineProvider = NotifierProvider<FilaOffline, EstadoFila>(
  FilaOffline.new,
);

/// As tarefas do quiosque: as do servidor e, se ele não responde, a última
/// lista que se viu (`daCache`).
typedef EstadosQuiosque = ({List<StatusControlo> lista, bool daCache});

final estadosQuiosqueProvider = FutureProvider.autoDispose<EstadosQuiosque>((
  ref,
) async {
  try {
    final l = await ref.watch(haccpEstadoProvider.future);
    guardarPref(_chaveEstados, codificarEstados(l));
    return (lista: l, daCache: false);
  } on Object {
    final c = lerEstados(lerPref(_chaveEstados));
    if (c.isEmpty) rethrow;
    return (lista: c, daCache: true);
  }
});

/// As pessoas do quiosque, também sem ligação (com os cartões).
final pessoasQuiosqueProvider = FutureProvider.autoDispose<List<Colaborador>>((
  ref,
) async {
  try {
    final l = await ref.watch(colaboradoresProvider.future);
    guardarPref(_chavePessoas, codificarPessoas(l));
    return l;
  } on Object {
    final c = lerPessoas(lerPref(_chavePessoas));
    if (c.isEmpty) rethrow;
    return c;
  }
});

/// O que cada pessoa marcou por último (servidor + o que ficou guardado neste
/// aparelho; fica a marcação mais recente).
final estadoPontoQuiosqueProvider =
    FutureProvider.autoDispose<Map<String, UltimoPonto>>((ref) async {
      final local = lerEstadoPonto(lerPref(_chavePonto));
      var servidor = const <String, UltimoPonto>{};
      try {
        servidor = await ref.watch(pontoEstadoProvider.future);
      } on Object {
        // sem ligação: vale o que se sabe deste aparelho
      }
      final juntos = juntarEstadoPonto(local, servidor);
      if (juntos.isNotEmpty) {
        guardarPref(_chavePonto, codificarEstadoPonto(juntos));
      }
      return juntos;
    });
