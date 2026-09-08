import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/formatting/money_provider.dart';
import '../../../core/widgets/async_value_view.dart';
import '../application/schedule_providers.dart';
import '../domain/production_plan.dart';

String _dataLabel(DateTime d) {
  const dias = [
    'segunda',
    'terça',
    'quarta',
    'quinta',
    'sexta',
    'sábado',
    'domingo',
  ];
  const meses = [
    'jan',
    'fev',
    'mar',
    'abr',
    'mai',
    'jun',
    'jul',
    'ago',
    'set',
    'out',
    'nov',
    'dez',
  ];
  return '${dias[d.weekday - 1]}, ${d.day} ${meses[d.month - 1]} ${d.year}';
}

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  Future<void> _nova(BuildContext context, WidgetRef ref) async {
    final agora = DateTime.now();
    final data = await showDatePicker(
      context: context,
      initialDate: agora,
      firstDate: DateTime(agora.year - 1),
      lastDate: DateTime(agora.year + 3),
      helpText: 'Data da produção',
    );
    if (data == null) return;
    try {
      final plano = await ref.read(scheduleActionsProvider).criar(data: data);
      if (context.mounted) context.go('${Routes.schedule}/${plano.id}');
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(plansListProvider);
    final fmt = ref.watch(moneyFormatProvider);
    final podeEditar = ref.watch(currentPapelProvider).canEditBusiness;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
        title: const Text('Agenda de produção'),
      ),
      floatingActionButton: podeEditar
          ? FloatingActionButton.extended(
              onPressed: () => _nova(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Nova produção'),
            )
          : null,
      body: AsyncValueView<List<ProducaoPlan>>(
        value: async,
        onRetry: () => ref.invalidate(plansListProvider),
        data: (planos) {
          if (planos.isEmpty) {
            return const Center(
              child: Text('Sem produções planeadas.'),
            );
          }
          // agrupar por dia (a lista já vem ordenada por -data)
          final grupos = <String, List<ProducaoPlan>>{};
          for (final p in planos) {
            final chave = _dataLabel(p.data);
            grupos.putIfAbsent(chave, () => []).add(p);
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              for (final entry in grupos.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    entry.key,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ),
                for (final p in entry.value)
                  _PlanoTile(plano: p, fmt: fmt),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PlanoTile extends ConsumerWidget {
  const _PlanoTile({required this.plano, required this.fmt});

  final ProducaoPlan plano;
  final MoneyFmt fmt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final itens = ref.watch(planItensProvider(plano.id)).valueOrNull;
    final (Color chipBg, Color chipFg) = switch (plano.estado) {
      EstadoProducao.planeada => (cs.secondaryContainer, cs.onSecondaryContainer),
      EstadoProducao.concluida => (cs.primaryContainer, cs.onPrimaryContainer),
      EstadoProducao.cancelada => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
    };

    String? resumo;
    Prioridade? prioridadeMax;
    if (itens != null && itens.isNotEmpty) {
      prioridadeMax = itens
          .map((i) => i.prioridade)
          .reduce((a, b) => a.peso <= b.peso ? a : b);
      final horas = itens
          .map((i) => i.horaLimite)
          .where((h) => h.isNotEmpty)
          .toList()
        ..sort();
      resumo = [
        '${itens.length} ${itens.length == 1 ? 'receita' : 'receitas'}',
        if (horas.isNotEmpty) 'até ${horas.first}',
        if (plano.custoSnapshot > 0) 'custo ${fmt(plano.custoSnapshot)}',
      ].join(' · ');
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        title: Row(
          children: [
            Flexible(
              child: Text(plano.titulo.isEmpty ? 'Produção' : plano.titulo),
            ),
            if (prioridadeMax == Prioridade.alta)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.priority_high,
                  size: 18,
                  color: cs.error,
                ),
              ),
          ],
        ),
        subtitle: resumo != null
            ? Text(resumo)
            : (plano.custoSnapshot > 0
                ? Text('Custo: ${fmt(plano.custoSnapshot)}')
                : null),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: chipBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            plano.estado.label,
            style: TextStyle(color: chipFg, fontSize: 12),
          ),
        ),
        onTap: () => context.go('${Routes.schedule}/${plano.id}'),
      ),
    );
  }
}
