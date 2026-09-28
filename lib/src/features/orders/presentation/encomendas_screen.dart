import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/help_actions.dart';
import '../../../core/widgets/sort_menu_button.dart';
import '../application/encomendas_providers.dart';
import '../data/configuracoes_encomendas_repository.dart';
import '../domain/encomenda.dart';
import 'encomenda_form_sheet.dart';
import 'encomendas_config_sheet.dart';

class EncomendasScreen extends ConsumerStatefulWidget {
  const EncomendasScreen({super.key});

  @override
  ConsumerState<EncomendasScreen> createState() => _EncomendasScreenState();
}

class _EncomendasScreenState extends ConsumerState<EncomendasScreen> {
  bool _concluidas = false;
  bool _soUrgentes = false;

  static final List<SortOption<Encomenda>> _sortOptions = [
    SortOption<Encomenda>(
      'Data/hora',
      (a, b) => a.dataHora.compareTo(b.dataHora),
    ),
    SortOption<Encomenda>(
      'Cliente',
      (a, b) =>
          a.clienteNome.toLowerCase().compareTo(b.clienteNome.toLowerCase()),
    ),
  ];
  int _sortIndex = 0;
  bool _sortAsc = true;

  bool get _podeEditar => ref.read(currentPapelProvider).canEditBusiness;

  Future<void> _nova() async {
    await showEncomendaFormSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final podeEditar = _podeEditar;
    final async = ref.watch(encomendasListProvider(_concluidas));
    final lembreteHoras =
        ref.watch(configuracaoEncomendasProvider).valueOrNull?.lembreteHoras ??
        4;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
        title: const Text('Encomendas'),
        actions: [
          if (podeEditar)
            IconButton(
              tooltip: 'Configurar talão e avisos',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => showEncomendasConfigSheet(context),
            ),
          SortMenuButton<Encomenda>(
            options: _sortOptions,
            selectedIndex: _sortIndex,
            ascending: _sortAsc,
            onChanged: (i, asc) => setState(() {
              _sortIndex = i;
              _sortAsc = asc;
            }),
          ),
          IconButton(
            tooltip: _concluidas
                ? 'Ver só as ativas'
                : 'Ver entregues/canceladas',
            icon: Icon(
              _concluidas ? Icons.visibility_off_outlined : Icons.history,
            ),
            onPressed: () => setState(() => _concluidas = !_concluidas),
          ),
          const HelpActions(topic: HelpTopic.encomendas),
        ],
      ),
      floatingActionButton: podeEditar
          ? FloatingActionButton.extended(
              onPressed: _nova,
              icon: const Icon(Icons.add),
              label: const Text('Nova encomenda'),
            )
          : null,
      body: AsyncValueView<List<Encomenda>>(
        value: async,
        onRetry: () => ref.invalidate(encomendasListProvider(_concluidas)),
        data: (encomendas) {
          if (encomendas.isEmpty) {
            return EmptyState(
              icon: Icons.event_note_outlined,
              titulo: _concluidas
                  ? 'Sem encomendas entregues/canceladas'
                  : 'Ainda sem encomendas',
              mensagem: podeEditar
                  ? 'Regista aqui os pedidos dos clientes para uma data/hora específica.'
                  : 'Pede a um colega para registar a encomenda.',
            );
          }
          final agora = DateTime.now();
          final nUrgentes = encomendas
              .where(
                (e) => e.estado.ativa && e.horasAte(agora) <= lembreteHoras,
              )
              .length;
          if (_soUrgentes && nUrgentes == 0) _soUrgentes = false;
          final filtradas = _soUrgentes
              ? encomendas
                    .where(
                      (e) =>
                          e.estado.ativa && e.horasAte(agora) <= lembreteHoras,
                    )
                    .toList()
              : encomendas;
          final ordenadas = ordenarPor(
            filtradas,
            _sortOptions[_sortIndex],
            _sortAsc,
          );
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount:
                ordenadas.length + (nUrgentes > 0 && !_concluidas ? 1 : 0),
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, idx) {
              if (nUrgentes > 0 && !_concluidas) {
                if (idx == 0) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: FilterChip(
                      avatar: const Icon(Icons.priority_high, size: 18),
                      label: Text('Urgentes ($nUrgentes)'),
                      selected: _soUrgentes,
                      onSelected: (v) => setState(() => _soUrgentes = v),
                    ),
                  );
                }
                idx -= 1;
              }
              final i = idx;
              final e = ordenadas[i];
              final horas = e.horasAte(agora);
              final urgente = e.estado.ativa && horas <= lembreteHoras;
              final atrasada = e.estado.ativa && horas < 0;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: atrasada
                      ? Theme.of(context).colorScheme.error
                      : urgente
                      ? Theme.of(context).colorScheme.errorContainer
                      : null,
                  child: Icon(_iconeEstado(e.estado)),
                ),
                title: Text(e.clienteNome),
                subtitle: Text(
                  '${_dataHoraLabel(e.dataHora)} · ${e.estado.label}'
                  '${e.clienteTelefone.isNotEmpty ? ' · ${e.clienteTelefone}' : ''}',
                ),
                trailing: (urgente || atrasada) && podeEditar
                    ? Icon(
                        Icons.priority_high,
                        color: Theme.of(context).colorScheme.error,
                      )
                    : const Icon(Icons.chevron_right),
                onTap: () => context.push('${Routes.encomendas}/${e.id}'),
              );
            },
          );
        },
      ),
    );
  }
}

IconData _iconeEstado(EstadoEncomenda estado) => switch (estado) {
  EstadoEncomenda.nova => Icons.fiber_new_outlined,
  EstadoEncomenda.emProducao => Icons.bakery_dining_outlined,
  EstadoEncomenda.pronta => Icons.inventory_2_outlined,
  EstadoEncomenda.entregue => Icons.check_circle_outline,
  EstadoEncomenda.cancelada => Icons.cancel_outlined,
};

String _dataHoraLabel(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
