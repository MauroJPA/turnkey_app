import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/formatting/money_provider.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/help_actions.dart';
import '../application/equipamentos_providers.dart';
import '../domain/equipamento.dart';
import 'equipamento_form_sheet.dart';
import 'equipamentos_import_sheet.dart';

class EquipamentosScreen extends ConsumerStatefulWidget {
  const EquipamentosScreen({super.key, this.embedded = false});

  /// Dentro da página Inventário: sem seta de voltar, título nem ajuda.
  final bool embedded;

  @override
  ConsumerState<EquipamentosScreen> createState() => _EquipamentosScreenState();
}

class _EquipamentosScreenState extends ConsumerState<EquipamentosScreen> {
  bool _arquivados = false;

  bool get _podeEditar => ref.read(currentPapelProvider).canEditConfig;

  Future<void> _novo() async {
    final input = await showEquipamentoFormSheet(context);
    if (input == null) return;
    await ref.read(equipamentosActionsProvider).create(input);
  }

  Future<void> _editar(Equipamento e) async {
    final input = await showEquipamentoFormSheet(context, existente: e);
    if (input == null) return;
    await ref.read(equipamentosActionsProvider).update(e.id, input);
  }

  Future<void> _arquivarOuRestaurar(Equipamento e) async {
    if (e.ativo) {
      await ref.read(equipamentosActionsProvider).arquivar(e.id);
    } else {
      await ref.read(equipamentosActionsProvider).restaurar(e.id);
    }
  }

  Future<void> _apagar(Equipamento e) async {
    final ok = await confirmDialog(
      context,
      titulo: 'Apagar "${e.nome}"',
      mensagem: 'Não é reversível.',
      destrutivo: true,
      confirmar: 'Apagar',
    );
    if (!ok) return;
    await ref.read(equipamentosActionsProvider).apagar(e.id);
  }

  @override
  Widget build(BuildContext context) {
    final podeEditar = _podeEditar;
    final async = ref.watch(equipamentosListProvider(_arquivados));
    final fmt = ref.watch(moneyFormatProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: widget.embedded ? 48 : null,
        leading: widget.embedded
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go(Routes.custosFixos),
              ),
        title: widget.embedded ? null : const Text('Equipamentos'),
        actions: [
          if (podeEditar)
            IconButton(
              tooltip: 'Importar',
              icon: const Icon(Icons.upload_file_outlined),
              onPressed: () => showImportarEquipamentosSheet(context),
            ),
          IconButton(
            tooltip: _arquivados ? 'Ocultar arquivados' : 'Ver arquivados',
            icon: Icon(
              _arquivados
                  ? Icons.visibility_off_outlined
                  : Icons.archive_outlined,
            ),
            onPressed: () => setState(() => _arquivados = !_arquivados),
          ),
          if (!widget.embedded)
            const HelpActions(topic: HelpTopic.equipamentos),
        ],
      ),
      floatingActionButton: podeEditar
          ? FloatingActionButton.extended(
              onPressed: _novo,
              icon: const Icon(Icons.add),
              label: const Text('Novo equipamento'),
            )
          : null,
      body: AsyncValueView<List<Equipamento>>(
        value: async,
        onRetry: () => ref.invalidate(equipamentosListProvider(_arquivados)),
        data: (equipamentos) {
          if (equipamentos.isEmpty) {
            return EmptyState(
              icon: Icons.kitchen_outlined,
              titulo: _arquivados
                  ? 'Sem equipamentos arquivados'
                  : 'Ainda sem equipamentos registados',
              mensagem: podeEditar
                  ? 'Regista aqui o equipamento da loja (forno, balcão, computador…) para calcular a depreciação mensal real.'
                  : 'Pede a um administrador para registar o equipamento.',
            );
          }
          final totalCusto = equipamentos.fold<double>(
            0,
            (s, e) => s + e.custo,
          );
          final totalMensal = equipamentos.fold<double>(
            0,
            (s, e) => s + e.custoMensal,
          );
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              if (!_arquivados)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Investido: ${fmt(totalCusto)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        'Depreciação: ${fmt(totalMensal)}/mês',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                ),
              for (final e in equipamentos)
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.kitchen_outlined),
                  ),
                  title: Text(e.nome),
                  subtitle: Text(
                    '${fmt(e.custo)} · ${e.vidaUtilAnos.toStringAsFixed(0)} ano(s)'
                    '${e.notas.isNotEmpty ? ' · ${e.notas}' : ''}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${fmt(e.custoMensal)}/mês',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (podeEditar)
                        PopupMenuButton<String>(
                          onSelected: (v) {
                            switch (v) {
                              case 'editar':
                                _editar(e);
                              case 'arquivar':
                                _arquivarOuRestaurar(e);
                              case 'apagar':
                                _apagar(e);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'editar',
                              child: Text('Editar'),
                            ),
                            PopupMenuItem(
                              value: 'arquivar',
                              child: Text(e.ativo ? 'Arquivar' : 'Reativar'),
                            ),
                            const PopupMenuItem(
                              value: 'apagar',
                              child: Text('Apagar'),
                            ),
                          ],
                        ),
                    ],
                  ),
                  onTap: podeEditar ? () => _editar(e) : null,
                ),
            ],
          );
        },
      ),
    );
  }
}
