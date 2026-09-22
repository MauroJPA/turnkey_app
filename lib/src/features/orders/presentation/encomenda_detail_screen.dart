import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/formatting/money_provider.dart';
import '../../../core/printing/print_html.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../settings/application/empresa_providers.dart';
import '../../tech_sheets/application/tech_sheets_providers.dart';
import '../../tech_sheets/domain/tech_sheet.dart';
import '../application/encomendas_providers.dart';
import '../data/configuracoes_encomendas_repository.dart';
import '../domain/configuracao_encomendas.dart';
import '../domain/encomenda.dart';
import 'encomenda_form_sheet.dart';
import 'encomenda_talao.dart';

class EncomendaDetailScreen extends ConsumerWidget {
  const EncomendaDetailScreen({super.key, required this.encomendaId});
  final String encomendaId;

  Future<void> _mudarEstado(
    BuildContext context,
    WidgetRef ref,
    EstadoEncomenda novo,
  ) async {
    await ref
        .read(encomendasActionsProvider)
        .atualizarEstado(encomendaId, novo);
  }

  Future<void> _cancelar(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      titulo: 'Cancelar encomenda',
      mensagem: 'O cliente deixa de aparecer na lista de encomendas ativas.',
      destrutivo: true,
      confirmar: 'Cancelar encomenda',
    );
    if (!ok) return;
    await ref
        .read(encomendasActionsProvider)
        .atualizarEstado(encomendaId, EstadoEncomenda.cancelada);
  }

  Future<void> _apagar(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      titulo: 'Apagar encomenda',
      mensagem: 'Não é reversível.',
      destrutivo: true,
      confirmar: 'Apagar',
    );
    if (!ok) return;
    await ref.read(encomendasActionsProvider).remover(encomendaId);
    if (context.mounted) context.go(Routes.encomendas);
  }

  Future<void> _editar(
    BuildContext context,
    WidgetRef ref,
    Encomenda e,
  ) async {
    final itens = await ref.read(encomendaItensProvider(encomendaId).future);
    final fichas = await ref.read(fichasListProvider(false).future);
    if (!context.mounted) return;
    await showEncomendaFormSheet(
      context,
      existente: e,
      itensExistentes: itens,
      fichasDosItens: fichas,
    );
  }

  Future<void> _registarPagamento(
    BuildContext context,
    WidgetRef ref,
    Encomenda e,
  ) async {
    final controller = TextEditingController(
      text: e.valorPago > 0 ? e.valorPago.toStringAsFixed(2) : '',
    );
    final novoValor = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registar pagamento'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Total já pago',
            prefixText: '€ ',
            helperText: e.temValor
                ? 'Valor da encomenda: ${e.valorTotal.toStringAsFixed(2)} €'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              double.tryParse(controller.text.replaceAll(',', '.')) ?? 0,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (novoValor == null) return;
    final itens = await ref.read(encomendaItensProvider(encomendaId).future);
    await ref.read(encomendasActionsProvider).atualizar(
          encomendaId,
          EncomendaInput(
            clienteNome: e.clienteNome,
            clienteTelefone: e.clienteTelefone,
            clienteNotas: e.clienteNotas,
            dataHora: e.dataHora,
            notas: e.notas,
            valorTotal: e.valorTotal,
            valorPago: novoValor,
            itens: itens
                .map((it) => EncomendaItemInput(
                      fichaId: it.fichaId,
                      fichaNome: '',
                      quantidade: it.quantidade,
                      notas: it.notas,
                    ))
                .toList(),
          ),
        );
  }

  Future<void> _imprimir(
    BuildContext context,
    WidgetRef ref,
    Encomenda e,
    List<EncomendaItem> itens,
    List<FichaTecnica> fichas,
  ) async {
    final nomeEmpresa = ref.read(currentEmpresaProvider).valueOrNull?.nome ?? '';
    final tamanho = ref.read(configuracaoEncomendasProvider).valueOrNull
            ?.talaoTamanho ??
        TalaoTamanho.termico80;
    final fmt = ref.read(moneyFormatProvider);
    abrirImpressao(
      'Talão — ${e.clienteNome}',
      talaoHtml(e, itens, fichas, nomeEmpresa, tamanho, fmt),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final podeEditar = ref.read(currentPapelProvider).canEditBusiness;
    final async = ref.watch(encomendaByIdProvider(encomendaId));
    final encomendaCarregada = async.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Encomenda'),
        actions: [
          IconButton(
            tooltip: 'Imprimir talão',
            icon: const Icon(Icons.print_outlined),
            onPressed: encomendaCarregada == null
                ? null
                : () async {
                    final e = encomendaCarregada;
                    final itens = await ref
                        .read(encomendaItensProvider(encomendaId).future);
                    final fichas =
                        await ref.read(fichasListProvider(false).future);
                    if (context.mounted) {
                      await _imprimir(context, ref, e, itens, fichas);
                    }
                  },
          ),
          if (podeEditar && encomendaCarregada != null)
            PopupMenuButton<String>(
              onSelected: (v) {
                switch (v) {
                  case 'editar':
                    _editar(context, ref, encomendaCarregada);
                  case 'pagamento':
                    _registarPagamento(context, ref, encomendaCarregada);
                  case 'cancelar':
                    _cancelar(context, ref);
                  case 'apagar':
                    _apagar(context, ref);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'editar', child: Text('Editar')),
                PopupMenuItem(
                    value: 'pagamento', child: Text('Registar pagamento')),
                PopupMenuItem(value: 'cancelar', child: Text('Cancelar encomenda')),
                PopupMenuItem(value: 'apagar', child: Text('Apagar')),
              ],
            ),
        ],
      ),
      body: AsyncValueView<Encomenda>(
        value: async,
        onRetry: () => ref.invalidate(encomendaByIdProvider(encomendaId)),
        data: (e) => _corpo(context, ref, e, podeEditar),
      ),
    );
  }

  Widget _corpo(
    BuildContext context,
    WidgetRef ref,
    Encomenda e,
    bool podeEditar,
  ) {
    final itensAsync = ref.watch(encomendaItensProvider(encomendaId));
    final fichasAsync = ref.watch(fichasListProvider(false));
    final fmt = ref.watch(moneyFormatProvider);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: e.estado == EstadoEncomenda.cancelada ? cs.errorContainer : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.clienteNome, style: tt.titleLarge),
                if (e.clienteTelefone.isNotEmpty)
                  Text(e.clienteTelefone, style: tt.bodyMedium),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.event_outlined, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Text(
                      '${diaSemana(e.dataHora)}, '
                      '${e.dataHora.day.toString().padLeft(2, '0')}/'
                      '${e.dataHora.month.toString().padLeft(2, '0')}/${e.dataHora.year} '
                      'às ${e.dataHora.hour.toString().padLeft(2, '0')}:'
                      '${e.dataHora.minute.toString().padLeft(2, '0')}',
                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (e.clienteNotas.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('Notas do cliente', style: tt.labelMedium),
                  Text(e.clienteNotas),
                ],
                if (e.notas.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('Notas internas', style: tt.labelMedium),
                  Text(e.notas),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _pagamentoCard(context, ref, e, fmt, podeEditar),
        const SizedBox(height: 16),
        if (podeEditar && e.estado.ativa) _estadoActions(context, ref, e),
        const SizedBox(height: 16),
        Text('Produtos', style: tt.titleMedium),
        const SizedBox(height: 8),
        itensAsync.when(
          data: (itens) => fichasAsync.when(
            data: (fichas) => Card(
              child: Column(
                children: [
                  for (final it in itens)
                    ListTile(
                      title: Text(nomeFicha(it.fichaId, fichas)),
                      subtitle: it.notas.isNotEmpty ? Text(it.notas) : null,
                      trailing: Text(
                        '${it.quantidade.toStringAsFixed(it.quantidade.truncateToDouble() == it.quantidade ? 0 : 1)}x',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e2, _) => Text('Erro: $e2'),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e2, _) => Text('Erro: $e2'),
        ),
      ],
    );
  }

  Widget _pagamentoCard(
    BuildContext context,
    WidgetRef ref,
    Encomenda e,
    MoneyFmt fmt,
    bool podeEditar,
  ) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final cor = switch (e.estadoPagamento) {
      EstadoPagamento.pago => cs.primary,
      EstadoPagamento.parcial => cs.tertiary,
      EstadoPagamento.porPagar => cs.error,
      EstadoPagamento.semValor => cs.onSurfaceVariant,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pagamento', style: tt.titleSmall),
            const SizedBox(height: 4),
            Text(
              e.temValor ? fmt(e.valorTotal) : 'Sem valor definido',
              style: tt.titleMedium,
            ),
            Text(
              e.estadoPagamento == EstadoPagamento.parcial
                  ? '${e.estadoPagamento.label} — falta ${fmt(e.valorEmFalta)}'
                  : e.estadoPagamento.label,
              style: tt.bodySmall?.copyWith(color: cor, fontWeight: FontWeight.w600),
            ),
            if (podeEditar && e.temValor && e.estadoPagamento != EstadoPagamento.pago) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _registarPagamento(context, ref, e),
                child: const Text('Registar pagamento'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _estadoActions(BuildContext context, WidgetRef ref, Encomenda e) {
    final proximo = e.estado.proximo;
    if (proximo == null) return const SizedBox.shrink();
    return FilledButton.icon(
      onPressed: () => _mudarEstado(context, ref, proximo),
      icon: const Icon(Icons.arrow_forward),
      label: Text('Marcar como "${proximo.label}"'),
    );
  }
}

