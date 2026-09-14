import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/formatting/money_provider.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/help_actions.dart';
import '../../import_csv/domain/import_result.dart';
import '../application/sales_import_service.dart';
import '../application/sales_providers.dart';
import '../domain/venda.dart';
import 'venda_form_sheet.dart';

class SalesScreen extends ConsumerWidget {
  const SalesScreen({super.key});

  bool _podeEditar(WidgetRef ref) =>
      ref.read(currentPapelProvider).canEditBusiness;

  Future<void> _importarCsv(BuildContext context, WidgetRef ref) async {
    try {
      final resultado =
          await ref.read(salesImportServiceProvider).pickAndImport();
      ref.invalidate(salesListProvider);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Importação de vendas'),
          content: Text(
            resultado.semErros
                ? resultado.resumo
                : '${resultado.resumo}\n\n'
                    '${resultado.erros.take(10).join('\n')}'
                    '${resultado.erros.length > 10 ? '\n…' : ''}',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Ok'),
            ),
          ],
        ),
      );
    } on ImportCancelled {
      // nada escolhido — ignora
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _sincronizarVendus(
    BuildContext context,
    WidgetRef ref, {
    DateTime? desde,
    DateTime? ate,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        duration: Duration(minutes: 5),
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'A sincronizar com o Vendus… pode demorar um pouco '
                'se houver muitas vendas por trazer.',
              ),
            ),
          ],
        ),
      ),
    );
    try {
      final r = await ref
          .read(salesActionsProvider)
          .sincronizarVendus(desde: desde, ate: ate);
      messenger.hideCurrentSnackBar();
      if (!context.mounted) return;
      final partes = [
        '${r.vendasCriadas} venda(s) nova(s)',
        if (r.duplicadasIgnoradas > 0)
          '${r.duplicadasIgnoradas} já importada(s) (ignoradas)',
        if (r.itensSemFicha > 0)
          '${r.itensSemFicha} linha(s) sem produto identificado',
        if (r.vendasCriadas == 0 &&
            r.duplicadasIgnoradas == 0 &&
            r.totalDocumentosRecebidos > 0)
          '(recebi ${r.totalDocumentosRecebidos} documento(s) do Vendus, '
              'mas nenhum era do tipo esperado — contacta-me com este número)',
      ];
      messenger.showSnackBar(SnackBar(content: Text(partes.join(' · '))));
    } on Object catch (e) {
      messenger.hideCurrentSnackBar();
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _reimportarHistorico(BuildContext context, WidgetRef ref) async {
    final hoje = DateTime.now();
    final intervalo = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: hoje.subtract(const Duration(days: 90)),
        end: hoje,
      ),
      firstDate: DateTime(hoje.year - 3),
      lastDate: hoje,
      helpText: 'Reimportar vendas do Vendus — desde / até',
    );
    if (intervalo == null || !context.mounted) return;
    await _sincronizarVendus(
      context,
      ref,
      desde: intervalo.start,
      ate: intervalo.end,
    );
  }

  Future<void> _novaVenda(BuildContext context, WidgetRef ref) async {
    final criada = await showVendaFormSheet(context);
    if (criada == true) ref.invalidate(salesListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final podeEditar = _podeEditar(ref);
    final async = ref.watch(salesListProvider(90));
    final fmt = ref.watch(moneyFormatProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
        title: const Text('Vendas'),
        actions: [
          IconButton(
            tooltip: 'Análise de vendas',
            icon: const Icon(Icons.bar_chart_outlined),
            onPressed: () => context.push(Routes.analiseVendas),
          ),
          const HelpActions(topic: HelpTopic.vendas),
          if (podeEditar) ...[
            PopupMenuButton<void>(
              tooltip: 'Sincronizar com o Vendus',
              icon: const Icon(Icons.cloud_sync_outlined),
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  onTap: () => _sincronizarVendus(context, ref),
                  child: const Text('Sincronizar (desde a última vez)'),
                ),
                PopupMenuItem(
                  onTap: () => _reimportarHistorico(context, ref),
                  child: const Text('Reimportar histórico (escolher data)'),
                ),
              ],
            ),
            IconButton(
              tooltip: 'Importar CSV',
              icon: const Icon(Icons.upload_file_outlined),
              onPressed: () => _importarCsv(context, ref),
            ),
          ],
        ],
      ),
      floatingActionButton: podeEditar
          ? FloatingActionButton.extended(
              onPressed: () => _novaVenda(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Registar venda'),
            )
          : null,
      body: AsyncValueView<List<Venda>>(
        value: async,
        onRetry: () => ref.invalidate(salesListProvider(90)),
        data: (vendas) {
          if (vendas.isEmpty) {
            return EmptyState(
              icon: Icons.point_of_sale_outlined,
              titulo: 'Ainda sem vendas registadas',
              mensagem: podeEditar
                  ? 'Regista manualmente ou importa um CSV de vendas.'
                  : 'Pede a um administrador para registar vendas.',
            );
          }
          final totalPeriodo = vendas.fold<double>(0, (s, v) => s + v.total);
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Últimos 90 dias: ${fmt(totalPeriodo)} em ${vendas.length} '
                  '${vendas.length == 1 ? 'venda' : 'vendas'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              for (final v in vendas)
                ListTile(
                  leading: Icon(_origemIcon(v.origem)),
                  title: Text(_diaLabel(v.data)),
                  subtitle: Text(
                    v.numeroDocumento.isNotEmpty
                        ? '${v.origem.label} · ${v.numeroDocumento}'
                        : v.origem.label,
                  ),
                  trailing: Text(
                    fmt(v.total),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () => context.go('${Routes.sales}/${v.id}'),
                ),
            ],
          );
        },
      ),
    );
  }

  IconData _origemIcon(OrigemVenda o) => switch (o) {
        OrigemVenda.manual => Icons.edit_outlined,
        OrigemVenda.csv => Icons.upload_file_outlined,
        OrigemVenda.vendus => Icons.sync_outlined,
      };

  String _diaLabel(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}
