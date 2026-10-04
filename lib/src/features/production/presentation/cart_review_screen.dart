import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/errors/mensagem_amigavel.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/help_actions.dart';
import '../../schedule/application/schedule_providers.dart';
import '../../schedule/data/schedule_repository.dart';
import '../../schedule/domain/production_plan.dart';
import '../application/agenda_cart.dart';

class CartReviewScreen extends ConsumerStatefulWidget {
  const CartReviewScreen({super.key});

  @override
  ConsumerState<CartReviewScreen> createState() => _CartReviewScreenState();
}

class _CartReviewScreenState extends ConsumerState<CartReviewScreen> {
  final _titulo = TextEditingController();
  DateTime _data = DateTime.now();
  bool _busy = false;

  @override
  void dispose() {
    _titulo.dispose();
    super.dispose();
  }

  String _dataLabel(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _criar(List<CartLinha> linhas) async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(scheduleRepositoryProvider);
      final plano = await repo.createPlan(
        data: _data,
        titulo: _titulo.text.trim(),
        nomesReceitas:
            linhas.map((l) => l.nome).toList(),
      );
      for (final l in linhas) {
        await repo.addItem(
          plano.id,
          receitaId: l.receitaId,
          quantidadeKg: l.kg,
          formatoId: l.formatoId,
          recheioId: l.recheioId,
          fichaId: l.fichaId,
          prioridade: l.prioridade.api,
          horaLimite: l.horaLimite,
          unidadesPrevistas: l.unidadesPrevistas,
        );
      }
      ref.read(agendaCartProvider.notifier).limpar();
      ref.invalidate(plansListProvider);
      if (mounted) context.go('${Routes.schedule}/${plano.id}');
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final linhas = ref.watch(agendaCartProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.production),
        ),
        title: const Text('Rever e agendar'),
        actions: const [HelpActions(topic: HelpTopic.agendar)],
      ),
      body: linhas.isEmpty
          ? const Center(child: Text('Carrinho vazio.'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: [
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.event_outlined),
                        title: Text(_dataLabel(_data)),
                        trailing: TextButton(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _data,
                              firstDate: DateTime(_data.year - 1),
                              lastDate: DateTime(_data.year + 3),
                            );
                            if (d != null) setState(() => _data = d);
                          },
                          child: const Text('Mudar'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: TextField(
                          controller: _titulo,
                          decoration: InputDecoration(
                            labelText: 'Título (opcional)',
                            helperText: 'Vazio → "${tituloPadraoProducao(
                              _data,
                              linhas.map((l) => l.nome).toList(),
                            )}"',
                            helperMaxLines: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                for (final l in linhas)
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    child: ListTile(
                      title: InkWell(
                        onTap: () => context.push(
                          l.fichaId.isNotEmpty
                              ? '${Routes.techSheets}/${l.fichaId}'
                              : '${Routes.recipes}/${l.receitaId}',
                        ),
                        child: Text(
                          l.nome,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      subtitle: Text(
                        [
                          if (l.formatoNome.isNotEmpty)
                            l.formatoNome
                          else if (l.fichaId.isNotEmpty)
                            'Produto final'
                          else
                            'Intermédio (a granel)',
                          if (l.recheioNome != null) 'recheio ${l.recheioNome}',
                          l.unidadesPrevistas > 0
                              ? '${l.kg.toStringAsFixed(2)} kg → ~${l.unidadesPrevistas} un'
                              : '${l.kg.toStringAsFixed(2)} kg',
                          l.prioridade.label,
                          if (l.horaLimite.isNotEmpty) 'até ${l.horaLimite}',
                        ].join(' · '),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => ref
                            .read(agendaCartProvider.notifier)
                            .remover(l.id),
                      ),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: linhas.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _criar(linhas),
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text('Criar produção (${linhas.length})'),
                ),
              ),
            ),
    );
  }
}
