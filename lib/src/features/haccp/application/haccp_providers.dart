import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pricing/data/cost_config_repository.dart';
import '../../pricing/domain/dias_trabalho.dart';
import '../data/haccp_repository.dart';
import '../domain/haccp.dart';

/// Os controlos ativos.
final haccpControlosProvider = FutureProvider.autoDispose<List<ControloHaccp>>(
  (ref) => ref.watch(haccpRepositoryProvider).listControlos(),
);

/// Todos os controlos, também os arquivados (para a gestão).
final haccpTodosControlosProvider =
    FutureProvider.autoDispose<List<ControloHaccp>>(
      (ref) => ref
          .watch(haccpRepositoryProvider)
          .listControlos(incluirArquivados: true),
    );

typedef IntervaloHaccp = ({DateTime desde, DateTime ate});

final haccpRegistosProvider = FutureProvider.autoDispose
    .family<List<RegistoHaccp>, IntervaloHaccp>(
      (ref, i) => ref
          .watch(haccpRepositoryProvider)
          .registos(desde: i.desde, ate: i.ate),
    );

/// Quantos dias para trás se procura o último registo de cada controlo
/// (cobre os anuais, como o extintor, com folga de um mês).
const diasHistoricoHaccp = 400;

/// O estado de cada controlo ativo (em dia, por fazer hoje, atrasado…).
final haccpEstadoProvider = FutureProvider.autoDispose<List<StatusControlo>>((
  ref,
) async {
  final controlos = await ref.watch(haccpControlosProvider.future);
  final agora = DateTime.now();
  final registos = await ref
      .watch(haccpRepositoryProvider)
      .registos(
        desde: agora.subtract(const Duration(days: diasHistoricoHaccp)),
        ate: agora,
      );
  // os dias de folga não contam (se a configuração não carregar, todos contam)
  var dias = todosOsDias;
  try {
    dias = (await ref.watch(costConfigProvider.future)).diasDeTrabalho;
  } on Object {
    // sem configuração: trabalha-se todos os dias
  }
  return estadoDosControlos(controlos, registos, agora, diasTrabalho: dias);
});

/// Não conformidades por resolver (último ano).
final haccpNaoConformidadesProvider =
    FutureProvider.autoDispose<List<RegistoHaccp>>((ref) async {
      final agora = DateTime.now();
      final registos = await ref
          .watch(haccpRepositoryProvider)
          .registos(
            desde: agora.subtract(const Duration(days: 365)),
            ate: agora,
          );
      return naoConformidadesAbertas(registos);
    });

final haccpActionsProvider = Provider<HaccpActions>(HaccpActions.new);

class HaccpActions {
  HaccpActions(this._ref);
  final Ref _ref;

  HaccpRepository get _repo => _ref.read(haccpRepositoryProvider);

  void refrescar() => _refresh();

  void _refresh() {
    _ref.invalidate(haccpEstadoProvider);
    _ref.invalidate(haccpRegistosProvider);
    _ref.invalidate(haccpNaoConformidadesProvider);
  }

  void _refreshControlos() {
    _ref.invalidate(haccpControlosProvider);
    _ref.invalidate(haccpTodosControlosProvider);
    _refresh();
  }

  Future<void> registar({
    required String controloId,
    required DateTime dataHora,
    double? valor,
    required bool conforme,
    String responsavel = '',
    String notas = '',
    String acaoCorretiva = '',
    DateTime? proximoVencimento,
    String? id,
  }) async {
    await _repo.registar(
      id: id,
      controloId: controloId,
      dataHora: dataHora,
      valor: valor,
      conforme: conforme,
      responsavel: responsavel,
      notas: notas,
      acaoCorretiva: acaoCorretiva,
      proximoVencimento: proximoVencimento,
    );
    _refresh();
  }

  Future<void> resolver(String registoId, {String acaoCorretiva = ''}) async {
    await _repo.resolver(registoId, acaoCorretiva: acaoCorretiva);
    _refresh();
  }

  Future<void> criarControlo(ControloInput input) async {
    await _repo.criarControlo(input);
    _refreshControlos();
  }

  Future<void> atualizarControlo(String id, ControloInput input) async {
    await _repo.atualizarControlo(id, input);
    _refreshControlos();
  }

  Future<void> arquivarControlo(String id, {required bool arquivado}) async {
    await _repo.arquivarControlo(id, arquivado: arquivado);
    _refreshControlos();
  }

  Future<void> criarHabituais() async {
    await _repo.criarHabituais();
    _refreshControlos();
  }
}
