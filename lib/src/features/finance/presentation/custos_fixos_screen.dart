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
import '../application/custos_fixos_providers.dart';
import '../domain/custo_fixo.dart';
import 'custo_fixo_form_sheet.dart';
import 'custos_fixos_import_sheet.dart';
import 'organizar_custos_ia_sheet.dart';

class CustosFixosScreen extends ConsumerStatefulWidget {
  const CustosFixosScreen({super.key});

  @override
  ConsumerState<CustosFixosScreen> createState() => _CustosFixosScreenState();
}

class _CustosFixosScreenState extends ConsumerState<CustosFixosScreen> {
  bool _arquivados = false;

  /// Filtro por categoria ('' = sem categoria; null = todas).
  String? _categoria;

  bool get _podeEditar => ref.read(currentPapelProvider).canEditConfig;

  Future<void> _novo() async {
    final input = await showCustoFixoFormSheet(context);
    if (input == null) return;
    await ref.read(custosFixosActionsProvider).create(input);
  }

  Future<void> _editar(CustoFixo c) async {
    final input = await showCustoFixoFormSheet(context, existente: c);
    if (input == null) return;
    await ref.read(custosFixosActionsProvider).update(c.id, input);
  }

  Future<void> _arquivarOuRestaurar(CustoFixo c) async {
    if (c.ativo) {
      await ref.read(custosFixosActionsProvider).arquivar(c.id);
    } else {
      await ref.read(custosFixosActionsProvider).restaurar(c.id);
    }
  }

  Future<void> _apagar(CustoFixo c) async {
    final ok = await confirmDialog(
      context,
      titulo: 'Apagar "${c.nome}"',
      mensagem: 'Não é reversível.',
      destrutivo: true,
      confirmar: 'Apagar',
    );
    if (!ok) return;
    await ref.read(custosFixosActionsProvider).apagar(c.id);
  }

  @override
  Widget build(BuildContext context) {
    final podeEditar = _podeEditar;
    final async = ref.watch(custosFixosListProvider(_arquivados));
    final fmt = ref.watch(moneyFormatProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
        title: const Text('Custos fixos'),
        actions: [
          IconButton(
            tooltip: 'Equipamentos (depreciação)',
            icon: const Icon(Icons.kitchen_outlined),
            onPressed: () => context.push(Routes.equipamentos),
          ),
          IconButton(
            tooltip: 'Números mágicos',
            icon: const Icon(Icons.calculate_outlined),
            onPressed: () => context.push(Routes.numerosMagicos),
          ),
          if (podeEditar)
            IconButton(
              tooltip: 'Organizar com IA (fixo / variável)',
              icon: const Icon(Icons.auto_awesome),
              onPressed: () => showOrganizarCustosIaSheet(context),
            ),
          if (podeEditar)
            IconButton(
              tooltip: 'Importar',
              icon: const Icon(Icons.upload_file_outlined),
              onPressed: () => showImportarCustosFixosSheet(context),
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
          const HelpActions(topic: HelpTopic.custosFixos),
        ],
      ),
      floatingActionButton: podeEditar
          ? FloatingActionButton.extended(
              onPressed: _novo,
              icon: const Icon(Icons.add),
              label: const Text('Novo custo'),
            )
          : null,
      body: AsyncValueView<List<CustoFixo>>(
        value: async,
        onRetry: () => ref.invalidate(custosFixosListProvider(_arquivados)),
        data: (custos) {
          if (custos.isEmpty) {
            return EmptyState(
              icon: Icons.receipt_long_outlined,
              titulo: _arquivados
                  ? 'Sem custos arquivados'
                  : 'Ainda sem custos registados',
              mensagem: podeEditar
                  ? 'Regista aqui os custos reais que saem todos os meses: aluguel, salários, seguros…'
                  : 'Pede a um administrador para registar os custos.',
            );
          }
          // categorias em uso, com o subtotal mensal
          final porCategoria = <String, double>{};
          for (final c in custos) {
            porCategoria.update(
              c.categoria,
              (v) => v + c.valorMensal,
              ifAbsent: () => c.valorMensal,
            );
          }
          final temCategorias = porCategoria.keys.any((k) => k.isNotEmpty);
          // se a categoria filtrada já não existe, mostra tudo
          final filtro = porCategoria.containsKey(_categoria) ? _categoria : null;
          if (filtro == null && _categoria != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _categoria = null);
            });
          }
          custos = [
            for (final c in custos)
              if (filtro == null || c.categoria == filtro) c,
          ];
          final totalFixo = custos
              .where((c) => c.tipo == TipoCusto.fixo)
              .fold<double>(0, (s, c) => s + c.valorMensal);
          final totalVariavel = custos
              .where((c) => c.tipo == TipoCusto.variavel)
              .fold<double>(0, (s, c) => s + c.valorMensal);
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
                        'Fixos: ${fmt(totalFixo)}   ·   Variáveis: ${fmt(totalVariavel)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        'Total: ${fmt(totalFixo + totalVariavel)}/mês',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                ),
              if (temCategorias)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: const Text('Todas'),
                          selected: filtro == null,
                          onSelected: (_) => setState(() => _categoria = null),
                        ),
                      ),
                      for (final e in (porCategoria.entries.toList()
                        ..sort((a, b) => a.key.compareTo(b.key))))
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              '${e.key.isEmpty ? 'Sem categoria' : e.key} · ${fmt(e.value)}',
                            ),
                            selected: filtro == e.key,
                            onSelected: (_) =>
                                setState(() => _categoria = e.key),
                          ),
                        ),
                    ],
                  ),
                ),
              for (final c in custos)
                ListTile(
                  leading: CircleAvatar(
                    child: Icon(
                      c.tipo == TipoCusto.fixo
                          ? Icons.lock_clock_outlined
                          : Icons.trending_up,
                    ),
                  ),
                  title: Text(c.nome),
                  subtitle: Text(
                    '${c.tipo.label}'
                    '${c.categoria.isNotEmpty ? ' · ${c.categoria}' : ''}'
                    '${c.diaPagamento != null ? ' · paga dia ${c.diaPagamento}' : ''}'
                    '${c.notas.isNotEmpty ? ' · ${c.notas}' : ''}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${fmt(c.valorMensal)}/mês',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (podeEditar)
                        PopupMenuButton<String>(
                          onSelected: (v) {
                            switch (v) {
                              case 'editar':
                                _editar(c);
                              case 'arquivar':
                                _arquivarOuRestaurar(c);
                              case 'apagar':
                                _apagar(c);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'editar',
                              child: Text('Editar'),
                            ),
                            PopupMenuItem(
                              value: 'arquivar',
                              child: Text(c.ativo ? 'Arquivar' : 'Reativar'),
                            ),
                            const PopupMenuItem(
                              value: 'apagar',
                              child: Text('Apagar'),
                            ),
                          ],
                        ),
                    ],
                  ),
                  onTap: podeEditar ? () => _editar(c) : null,
                ),
            ],
          );
        },
      ),
    );
  }
}
