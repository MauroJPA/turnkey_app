import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/formatting/dates.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/history_sheet.dart';
import '../../settings/application/empresa_providers.dart';
import '../application/invoice_providers.dart';
import '../domain/analise_resumo.dart';
import '../domain/fatura.dart';
import '../domain/invoice_erros.dart';

/// Só o proprietário corrige e apaga faturas.
bool ehProprietario(WidgetRef ref) =>
    ref.read(currentPapelProvider) == Papel.owner;

/// Corrigir fornecedor, número, data e total de uma fatura. Devolve `true` se guardou.
Future<bool> mostrarEditarFatura(
  BuildContext context,
  WidgetRef ref,
  Fatura f,
) async {
  final forn = TextEditingController(text: f.fornecedor);
  final num = TextEditingController(text: f.numero);
  final total = TextEditingController(
    text: f.total > 0 ? f.total.toStringAsFixed(2) : '',
  );
  DateTime? data = f.dataFatura.isEmpty
      ? null
      : DateTime.tryParse(f.dataFatura);
  String? erro;
  var busy = false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) => AlertDialog(
        title: const Text('Corrigir fatura'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: forn,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Fornecedor'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: num,
                decoration: const InputDecoration(labelText: 'Número'),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.event),
                    label: Text(
                      data == null
                          ? 'Data da fatura'
                          : formatDateShort(data!.toIso8601String()),
                    ),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: data ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 366)),
                      );
                      if (d != null) setSt(() => data = d);
                    },
                  ),
                  if (data != null)
                    TextButton(
                      onPressed: () => setSt(() => data = null),
                      child: const Text('Limpar'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: total,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Total (opcional)',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'A alteração fica no histórico da fatura, com os valores '
                'antes e depois. Não muda o que já foi aplicado aos preços e '
                'ao stock.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              if (erro != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    erro!,
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    setSt(() {
                      busy = true;
                      erro = null;
                    });
                    try {
                      await ref
                          .read(invoiceActionsProvider)
                          .editar(
                            f.id,
                            fornecedor: forn.text,
                            numero: num.text,
                            data: data,
                            total: double.tryParse(
                              total.text.replaceAll(',', '.').trim(),
                            ),
                          );
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } on Object catch (e) {
                      setSt(() {
                        busy = false;
                        erro = mensagemAmigavel(e);
                      });
                    }
                  },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
  forn.dispose();
  num.dispose();
  total.dispose();
  return ok == true;
}

/// Apagar uma fatura (só o proprietário): fica escondida, com registo, e pode ser restaurada.
Future<bool> apagarFaturaComConfirmacao(
  BuildContext context,
  WidgetRef ref,
  Fatura f,
) async {
  final ok = await confirmDialog(
    context,
    titulo: 'Apagar fatura?',
    mensagem:
        '${f.fornecedor.isEmpty ? 'Fatura' : f.fornecedor}'
        '${f.numero.isEmpty ? '' : ' nº ${f.numero}'} deixa de aparecer, mas '
        'continua guardada (com o ficheiro) e fica no histórico. Podes '
        'restaurá-la em "Faturas apagadas".',
    confirmar: 'Apagar',
    destrutivo: true,
  );
  if (!ok) return false;
  await ref.read(invoiceActionsProvider).apagar(f.id);
  return true;
}

/// Lista das faturas apagadas, com "Restaurar" (só o proprietário).
void mostrarFaturasApagadas(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _FaturasApagadasSheet(),
  );
}

class _FaturasApagadasSheet extends ConsumerWidget {
  const _FaturasApagadasSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(faturasApagadasProvider);
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Faturas apagadas',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: AsyncValueView<List<Fatura>>(
              value: async,
              onRetry: () => ref.invalidate(faturasApagadasProvider),
              data: (lista) => lista.isEmpty
                  ? const Center(child: Text('Nenhuma fatura apagada.'))
                  : ListView.separated(
                      itemCount: lista.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final f = lista[i];
                        return ListTile(
                          title: Text(
                            f.fornecedor.isEmpty ? 'Fornecedor?' : f.fornecedor,
                          ),
                          subtitle: Text(
                            [
                              if (f.numero.isNotEmpty) 'nº ${f.numero}',
                              if (f.dataFatura.isNotEmpty)
                                formatDateShort(f.dataFatura),
                              if (f.apagadaEm.isNotEmpty)
                                'apagada em ${formatDateShort(f.apagadaEm)}',
                              if (f.apagadaPor.isNotEmpty)
                                'por ${f.apagadaPor}',
                            ].join(' · '),
                          ),
                          trailing: TextButton(
                            onPressed: () async {
                              await ref
                                  .read(invoiceActionsProvider)
                                  .restaurar(f.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Fatura restaurada.'),
                                  ),
                                );
                              }
                            },
                            child: const Text('Restaurar'),
                          ),
                        );
                      },
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextButton(
              onPressed: () {
                final emp = ref.read(currentEmpresaProvider).valueOrNull;
                if (emp != null) {
                  showHistorySheet(
                    context,
                    tipo: 'faturas_apagadas',
                    id: emp.id,
                    titulo: 'Registo antigo de faturas apagadas',
                  );
                }
              },
              child: const Text('Ver o registo antigo (antes da 1.18)'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Detalhe do que ficou depois de analisar um ficheiro com várias faturas.
void mostrarResumoAnalise(
  BuildContext context,
  String titulo,
  ResumoAnalise r,
) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Resumo · $titulo'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final i in r.itens)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    i.duplicada
                        ? Icons.content_copy
                        : (i.ok
                              ? Icons.check_circle_outline
                              : Icons.error_outline),
                    color: i.ok ? null : Theme.of(ctx).colorScheme.error,
                  ),
                  title: Text(
                    '${i.fornecedor.isEmpty ? 'Fornecedor?' : i.fornecedor}'
                    '${i.numero.isEmpty ? '' : ' · nº ${i.numero}'}',
                  ),
                  subtitle: Text(
                    [
                      if (i.data.isNotEmpty) formatDateShort(i.data),
                      if (i.paginas.isNotEmpty) 'págs. ${i.paginas}',
                      if (i.duplicada)
                        'DUPLICADA: já existia, não foi importada'
                      else if (i.estado == 'erro')
                        'a IA não conseguiu ler'
                      else if (i.linhas == 0)
                        'sem linhas (guia de remessa ou sem preços?)'
                      else
                        '${i.linhas} linha(s)',
                    ].join(' · '),
                  ),
                ),
              if (r.paginasSemFatura.isNotEmpty) ...[
                const Divider(),
                Text(
                  'Páginas em que a IA não reconheceu nenhuma fatura: '
                  '${r.paginasSemFatura}. Confere no PDF original se falta '
                  'alguma.',
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Duplicada = a fatura (fornecedor + número) já estava na app. '
                'Erro = a IA não conseguiu ler essas páginas: abre a fatura e '
                'usa "Tentar de novo", ou corrige os dados à mão.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Fechar'),
        ),
      ],
    ),
  );
}
