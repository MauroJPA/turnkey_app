import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../inventory/application/inventory_providers.dart';
import '../data/schedule_repository.dart';
import '../domain/production_plan.dart';

final plansListProvider =
    FutureProvider.autoDispose<List<ProducaoPlan>>((ref) {
  return ref.watch(scheduleRepositoryProvider).listPlans();
});

final planProvider =
    FutureProvider.autoDispose.family<ProducaoPlan, String>((ref, id) {
  return ref.watch(scheduleRepositoryProvider).getPlan(id);
});

final planItensProvider =
    FutureProvider.autoDispose.family<List<ProducaoItem>, String>((ref, id) {
  return ref.watch(scheduleRepositoryProvider).listItens(id);
});

/// Explosão agregada de ingredientes necessários (server-side).
final planoProvider =
    FutureProvider.autoDispose.family<PlanoResposta, String>((ref, id) {
  return ref.watch(scheduleRepositoryProvider).plano(id);
});

/// Formato mais usado historicamente para uma receita (`''` se não há).
final formatoSugeridoProvider =
    FutureProvider.autoDispose.family<String, String>((ref, receitaId) {
  return ref.watch(scheduleRepositoryProvider).formatoMaisUsado(receitaId);
});

final scheduleActionsProvider =
    Provider<ScheduleActions>(ScheduleActions.new);

class ScheduleActions {
  ScheduleActions(this._ref);
  final Ref _ref;

  ScheduleRepository get _repo => _ref.read(scheduleRepositoryProvider);

  void _refreshPlan(String id) {
    _ref.invalidate(plansListProvider);
    _ref.invalidate(planProvider(id));
    _ref.invalidate(planItensProvider(id));
    _ref.invalidate(planoProvider(id));
  }

  Future<ProducaoPlan> criar({required DateTime data, String titulo = ''}) async {
    final p = await _repo.createPlan(data: data, titulo: titulo);
    _ref.invalidate(plansListProvider);
    return p;
  }

  Future<void> editarCabecalho(
    String id, {
    DateTime? data,
    String? titulo,
    String? notas,
  }) async {
    await _repo.updatePlan(id, data: data, titulo: titulo, notas: notas);
    _refreshPlan(id);
  }

  Future<void> apagar(String id) async {
    await _repo.deletePlan(id);
    _ref.invalidate(plansListProvider);
  }

  Future<void> adicionarReceita(
    String id, {
    required String receitaId,
    required double quantidadeKg,
  }) async {
    await _repo.addItem(id, receitaId: receitaId, quantidadeKg: quantidadeKg);
    _refreshPlan(id);
  }

  Future<void> editarItem(
    String planId,
    String itemId, {
    required double quantidadeKg,
  }) async {
    await _repo.updateItem(itemId, quantidadeKg: quantidadeKg);
    _refreshPlan(planId);
  }

  Future<void> removerItem(String planId, String itemId) async {
    await _repo.removeItem(itemId);
    _refreshPlan(planId);
  }

  Future<int> gerarListaCompras(String id) => _repo.gerarListaCompras(id);

  Future<ConclusaoResumo> concluir(String id) async {
    final r = await _repo.concluir(id);
    _refreshPlan(id);
    _ref.invalidate(stockListProvider);
    return r;
  }
}
