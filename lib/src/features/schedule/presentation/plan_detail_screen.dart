import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/formatting/money_provider.dart';
import '../../../core/formatting/quantities.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/help_actions.dart';
import '../../recipes/domain/recipe.dart';
import '../../recipes/presentation/recipe_picker_sheet.dart';
import '../application/schedule_providers.dart';
import '../data/schedule_repository.dart';
import '../domain/production_plan.dart';

String _qLabel(double v, String unidade) =>
    unidade == 'g' ? _gLabel(v) : quantidadeParaTexto(v, unidade);

String _gLabel(double g) => g >= 1000
    ? '${(g / 1000).toStringAsFixed(3)} kg'
    : '${g.toStringAsFixed(0)} g';

String _dataCurta(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$day/$m/${d.year}';
}

class PlanDetailScreen extends ConsumerWidget {
  const PlanDetailScreen({super.key, required this.planId});

  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planoAsync = ref.watch(planProvider(planId));
    final podeEditar = ref.watch(currentPapelProvider).canEditBusiness;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.schedule),
        ),
        title: const Text('Produção'),
        actions: [
          if (podeEditar)
            AsyncValueView<ProducaoPlan>(
              value: planoAsync,
              data: (p) => p.concluida
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: 'Apagar plano',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final ok = await confirmDialog(
                          context,
                          titulo: 'Apagar plano?',
                          mensagem:
                              'Remove o plano e as suas linhas. Não mexe no stock.',
                          confirmar: 'Apagar',
                          destrutivo: true,
                        );
                        if (!ok) return;
                        await ref.read(scheduleActionsProvider).apagar(planId);
                        if (context.mounted) context.go(Routes.schedule);
                      },
                    ),
            ),
          const HelpActions(topic: HelpTopic.planoDetalhe),
        ],
      ),
      body: AsyncValueView<ProducaoPlan>(
        value: planoAsync,
        onRetry: () => ref.invalidate(planProvider(planId)),
        data: (plano) =>
            _Body(plano: plano, podeEditar: podeEditar && !plano.concluida),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.plano, required this.podeEditar});

  final ProducaoPlan plano;
  final bool podeEditar;

  Future<void> _editarData(BuildContext context, WidgetRef ref) async {
    final d = await showDatePicker(
      context: context,
      initialDate: plano.data,
      firstDate: DateTime(plano.data.year - 2),
      lastDate: DateTime(plano.data.year + 3),
    );
    if (d == null) return;
    await ref.read(scheduleActionsProvider).editarCabecalho(plano.id, data: d);
  }

  Future<void> _editarTitulo(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(text: plano.titulo);
    final novo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Título'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ex.: Fornada de sábado'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (novo == null) return;
    await ref
        .read(scheduleActionsProvider)
        .editarCabecalho(plano.id, titulo: novo);
  }

  Future<void> _adicionarReceita(BuildContext context, WidgetRef ref) async {
    final Receita? r = await showRecipePickerSheet(context);
    if (r == null || !context.mounted) return;
    final kg = await _pedirKg(context, titulo: r.nome);
    if (kg == null || kg <= 0) return;
    try {
      await ref
          .read(scheduleActionsProvider)
          .adicionarReceita(plano.id, receitaId: r.id, quantidadeKg: kg);
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(moneyFormatProvider);
    final itensAsync = ref.watch(planItensProvider(plano.id));
    final planoAsync = ref.watch(planoProvider(plano.id));

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: [
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.event_outlined),
                title: Text(_dataCurta(plano.data)),
                subtitle: Text(plano.estado.label),
                trailing: podeEditar
                    ? TextButton(
                        onPressed: () => _editarData(context, ref),
                        child: const Text('Mudar'),
                      )
                    : null,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.title),
                title: Text(plano.titulo.isEmpty ? 'Sem título' : plano.titulo),
                trailing: podeEditar
                    ? TextButton(
                        onPressed: () => _editarTitulo(context, ref),
                        child: const Text('Editar'),
                      )
                    : null,
              ),
              if (plano.concluida && plano.concluidaEm != null) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text('Concluída em ${_dataCurta(plano.concluidaEm!)}'),
                  subtitle: plano.custoSnapshot > 0
                      ? Text('Custo real: ${fmt(plano.custoSnapshot)}')
                      : null,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        _SectionTitle(
          'Receitas a produzir',
          trailing: podeEditar
              ? TextButton.icon(
                  onPressed: () => _adicionarReceita(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar'),
                )
              : null,
        ),
        AsyncValueView<List<ProducaoItem>>(
          value: itensAsync,
          data: (itens) {
            if (itens.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Ainda sem receitas. Adiciona uma acima.'),
              );
            }
            return Column(
              children: [
                for (final it in itens)
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    child: ListTile(
                      title: InkWell(
                        onTap: it.fichaId.isNotEmpty
                            ? () => context.push(
                                '${Routes.techSheets}/${it.fichaId}',
                              )
                            : it.receitaId.isEmpty
                            ? null
                            : () => context.push(
                                '${Routes.recipes}/${it.receitaId}',
                              ),
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                it.titulo.isEmpty ? '(receita)' : it.titulo,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            _PrioridadeChip(prioridade: it.prioridade),
                          ],
                        ),
                      ),
                      subtitle: Text(
                        [
                          if (it.formatoNome.isNotEmpty)
                            it.formatoNome
                          else if (it.fichaId.isNotEmpty)
                            'Produto final'
                          else
                            'Intermédio',
                          if (it.recheioNome.isNotEmpty)
                            'recheio ${it.recheioNome}',
                          '${it.quantidadeKg.toStringAsFixed(2)} kg',
                          if (it.unidadesPrevistas > 0)
                            '~${it.unidadesPrevistas} un',
                          if (it.horaLimite.isNotEmpty) 'até ${it.horaLimite}',
                        ].join(' · '),
                      ),
                      trailing: podeEditar
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () async {
                                    final kg = await _pedirKg(
                                      context,
                                      titulo: it.titulo,
                                      inicial: it.quantidadeKg,
                                    );
                                    if (kg == null || kg <= 0) return;
                                    await ref
                                        .read(scheduleActionsProvider)
                                        .editarItem(
                                          plano.id,
                                          it.id,
                                          quantidadeKg: kg,
                                        );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => ref
                                      .read(scheduleActionsProvider)
                                      .removerItem(plano.id, it.id),
                                ),
                              ],
                            )
                          : null,
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        _SectionTitle('Mise en place — por receita'),
        AsyncValueView<PlanoResposta>(
          value: planoAsync,
          data: (resp) {
            if (resp.porReceita.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Sem receitas no plano.'),
              );
            }
            return Column(
              children: [
                for (final pr in resp.porReceita)
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pr.nome.isEmpty ? '(receita)' : pr.nome,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            [
                              if (pr.formato.isNotEmpty) pr.formato,
                              if (pr.recheio.isNotEmpty)
                                'recheio ${pr.recheio}',
                              '${pr.kg.toStringAsFixed(2)} kg',
                              if (pr.unidades > 0) '~${pr.unidades} un',
                              if (pr.tempoAssaduraMin > 0)
                                'assar ${pr.tempoAssaduraMin} min',
                            ].join(' · '),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 6),
                          if (pr.intermedios.isNotEmpty) ...[
                            const Text(
                              'Produzir primeiro:',
                              style: TextStyle(fontSize: 12),
                            ),
                            for (final i in pr.intermedios)
                              Text('  • ${i.nome}: ${_gLabel(i.gramas)}'),
                            const SizedBox(height: 4),
                          ],
                          const Text(
                            'Ingredientes:',
                            style: TextStyle(fontSize: 12),
                          ),
                          if (pr.comprar.isEmpty)
                            const Text('  • —')
                          else
                            for (final c in pr.comprar)
                              Text(
                                '  • ${c.nome}: ${_qLabel(c.gramas, c.unidade)}',
                              ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        _SectionTitle(
          'Ingredientes necessários (total)',
          trailing: IconButton(
            tooltip: 'Recalcular',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(planoProvider(plano.id)),
          ),
        ),
        AsyncValueView<PlanoResposta>(
          value: planoAsync,
          onRetry: () => ref.invalidate(planoProvider(plano.id)),
          data: (resp) {
            if (resp.necessarios.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Nada a comprar (ou sem receitas no plano).'),
              );
            }
            return Column(
              children: [
                for (final n in resp.necessarios)
                  ListTile(
                    dense: true,
                    title: Text(n.nome),
                    subtitle: Text(
                      'Preciso ${_qLabel(n.gramas, n.unidade)} · '
                      'stock ${_qLabel(n.emStock, n.unidade)}'
                      '${n.fornecedor.isNotEmpty ? ' · ${n.fornecedor}' : ''}',
                    ),
                    trailing: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          n.aComprar <= 0
                              ? 'ok'
                              : n.aComprarSacos > 0
                              ? '${n.aComprarSacos} '
                                    '${n.aComprarSacos == 1 ? 'saco' : 'sacos'}'
                              : 'comprar ${_qLabel(n.aComprar, n.unidade)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: n.aComprar > 0
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        Text(
                          fmt(n.custo),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Custo estimado',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        fmt(resp.custoTotal),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _copiarRelatorio(context, resp),
                      icon: const Icon(Icons.copy_all_outlined),
                      label: const Text('Copiar relatório'),
                    ),
                    if (podeEditar)
                      FilledButton.tonalIcon(
                        onPressed: () => _gerarCompras(context, ref),
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text('Adicionar à lista de compras'),
                      ),
                    if (podeEditar)
                      FilledButton.icon(
                        onPressed: () => _concluir(context, ref, resp),
                        icon: const Icon(Icons.task_alt),
                        label: const Text('Concluir produção'),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  String _relatorio(PlanoResposta resp) {
    final b = StringBuffer();
    final titulo = plano.titulo.isEmpty ? 'Produção' : plano.titulo;
    b.writeln('$titulo — ${_dataCurta(plano.data)}');
    b.writeln();
    b.writeln('A produzir:');
    for (final p in resp.produzir) {
      final extras = [
        if (p.formato.isNotEmpty) p.formato,
        if (p.recheio.isNotEmpty) 'recheio ${p.recheio}',
        if (p.unidades > 0) '~${p.unidades} un',
        if (p.horaLimite.isNotEmpty) 'até ${p.horaLimite}',
      ];
      b.writeln(
        '- ${p.nome}: ${p.kg.toStringAsFixed(2)} kg'
        '${extras.isEmpty ? '' : ' (${extras.join(', ')})'}',
      );
    }
    b.writeln();
    b.writeln('=== MISE EN PLACE (por receita) ===');
    for (final pr in resp.porReceita) {
      b.writeln();
      final cab = [
        if (pr.formato.isNotEmpty) pr.formato,
        if (pr.recheio.isNotEmpty) 'recheio ${pr.recheio}',
        '${pr.kg.toStringAsFixed(2)} kg',
        if (pr.unidades > 0) '~${pr.unidades} un',
      ].join(' · ');
      b.writeln('# ${pr.nome}  ($cab)');
      if (pr.intermedios.isNotEmpty) {
        b.writeln('  Produzir primeiro:');
        for (final i in pr.intermedios) {
          b.writeln('    - ${i.nome}: ${_gLabel(i.gramas)}');
        }
      }
      b.writeln('  Ingredientes:');
      for (final c in pr.comprar) {
        b.writeln('    - ${c.nome}: ${_qLabel(c.gramas, c.unidade)}');
      }
    }
    b.writeln();
    b.writeln('=== INGREDIENTES NO TOTAL (para comprar) ===');
    for (final n in resp.necessarios) {
      final compra = n.aComprar > 0
          ? ' (comprar ${_qLabel(n.aComprar, n.unidade)})'
          : ' (em stock)';
      b.writeln('- ${n.nome}: ${_qLabel(n.gramas, n.unidade)}$compra');
    }
    b.writeln();
    b.writeln('Custo estimado: ${resp.custoTotal.toStringAsFixed(2)}');
    return b.toString();
  }

  Future<void> _copiarRelatorio(
    BuildContext context,
    PlanoResposta resp,
  ) async {
    await Clipboard.setData(ClipboardData(text: _relatorio(resp)));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Relatório copiado.')));
    }
  }

  Future<void> _gerarCompras(BuildContext context, WidgetRef ref) async {
    try {
      final jaTem = await ref
          .read(scheduleRepositoryProvider)
          .contarLinhasCompra(plano.id);
      if (!context.mounted) return;
      if (jaTem > 0) {
        final ok = await confirmDialog(
          context,
          titulo: 'Já foi adicionado',
          mensagem:
              'Esta produção já tem $jaTem linha(s) na lista de compras. '
              'Queres mesmo adicionar de novo? (as quantidades são '
              'recalculadas, não somadas)',
          confirmar: 'Adicionar de novo',
        );
        if (!ok) return;
      }
      final n = await ref
          .read(scheduleActionsProvider)
          .gerarListaCompras(plano.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$n item(s) na lista de compras.')),
      );
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _concluir(
    BuildContext context,
    WidgetRef ref,
    PlanoResposta resp,
  ) async {
    final produz = resp.produzir
        .map(
          (p) =>
              '• ${p.nome}: ${p.kg.toStringAsFixed(2)} kg'
              '${p.unidades > 0 ? ' → ~${p.unidades} un'
                        '${p.formato.isNotEmpty ? ' (${p.formato})' : ''}' : ''}',
        )
        .join('\n');
    final consome = resp.necessarios
        .take(12)
        .map((n) => '• ${n.nome}: ${_qLabel(n.gramas, n.unidade)}')
        .join('\n');
    final maisLinhas = resp.necessarios.length > 12
        ? '\n… e mais ${resp.necessarios.length - 12}'
        : '';

    final ok = await confirmDialog(
      context,
      titulo: 'Concluir produção?',
      mensagem:
          'Vai movimentar o stock:\n\n'
          'PRODUZIR (entra em stock):\n$produz\n\n'
          'CONSUMIR (sai do stock):\n$consome$maisLinhas\n\n'
          'Se faltar stock de um componente, a quantidade fica em 0 e '
          'o resumo avisa.',
      confirmar: 'Concluir',
    );
    if (!ok) return;

    try {
      final resumo = await ref.read(scheduleActionsProvider).concluir(plano.id);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Produção concluída'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Consumos: ${resumo.consumos.length}'),
                Text('Saídas p/ stock: ${resumo.saidas.length}'),
                Text('Custo: ${resumo.custoTotal.toStringAsFixed(2)}'),
                if (resumo.faltas.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Avisos:',
                    style: TextStyle(
                      color: Theme.of(ctx).colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  for (final f in resumo.faltas) Text('• $f'),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

Future<double?> _pedirKg(
  BuildContext context, {
  required String titulo,
  double? inicial,
}) {
  final ctrl = TextEditingController(
    text: inicial != null ? inicial.toString() : '',
  );
  return showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Quantidade',
          suffixText: 'kg',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final v =
                double.tryParse(ctrl.text.replaceAll(',', '.').trim()) ?? 0;
            Navigator.pop(ctx, v);
          },
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

class _PrioridadeChip extends StatelessWidget {
  const _PrioridadeChip({required this.prioridade});
  final Prioridade prioridade;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (Color bg, Color fg) = switch (prioridade) {
      Prioridade.alta => (cs.errorContainer, cs.onErrorContainer),
      Prioridade.media => (cs.secondaryContainer, cs.onSecondaryContainer),
      Prioridade.baixa => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
    };
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(prioridade.label, style: TextStyle(color: fg, fontSize: 11)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.texto, {this.trailing});

  final String texto;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 4, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(texto, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
