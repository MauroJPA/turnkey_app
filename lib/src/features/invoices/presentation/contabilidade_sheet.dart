import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/invoice_repository.dart';

Future<void> showContabilidadeSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _Sheet(),
  );
}

class _Sheet extends ConsumerStatefulWidget {
  const _Sheet();
  @override
  ConsumerState<_Sheet> createState() => _SheetState();
}

class _SheetState extends ConsumerState<_Sheet> {
  late DateTime _mes;
  Future<List<Map<String, dynamic>>>? _fut;

  @override
  void initState() {
    super.initState();
    final agora = DateTime.now();
    _mes = DateTime(agora.year, agora.month - 1); // mês anterior
    _carregar();
  }

  ({String de, String ate}) get _intervalo {
    final ini = DateTime(_mes.year, _mes.month, 1);
    final fim = DateTime(_mes.year, _mes.month + 1, 0);
    String d(DateTime x) =>
        '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
    return (de: d(ini), ate: d(fim));
  }

  void _carregar() {
    final i = _intervalo;
    setState(() => _fut = ref
        .read(invoiceRepositoryProvider)
        .exportContabilidade(de: i.de, ate: i.ate));
  }

  void _mudarMes(int delta) {
    setState(() => _mes = DateTime(_mes.year, _mes.month + delta));
    _carregar();
  }

  String _csv(List<Map<String, dynamic>> fs) {
    final linhas = <List<Object?>>[
      ['ficheiro', 'fornecedor', 'data', 'numero', 'total', 'iva'],
      for (final f in fs)
        [
          f['nomeFicheiro'] ?? '',
          f['fornecedor'] ?? '',
          (f['dataFatura'] ?? '').toString().split(' ').first,
          f['numero'] ?? '',
          (f['total'] as num?)?.toStringAsFixed(2) ?? '0.00',
          (f['iva'] as num?)?.toStringAsFixed(2) ?? '0.00',
        ],
    ];
    return const ListToCsvConverter(fieldDelimiter: ';').convert(linhas);
  }

  @override
  Widget build(BuildContext context) {
    final rotulo =
        '${_mes.month.toString().padLeft(2, '0')}/${_mes.year}';
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Faturas para a contabilidade',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: () => _mudarMes(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(rotulo, textAlign: TextAlign.center),
                ),
                IconButton(
                  onPressed: () => _mudarMes(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _fut,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text('${snap.error}'));
                  }
                  final fs = snap.data ?? const [];
                  if (fs.isEmpty) {
                    return const Center(
                      child: Text('Nenhuma fatura confirmada neste mês.'),
                    );
                  }
                  final total = fs.fold<double>(
                      0, (s, f) => s + ((f['total'] as num?)?.toDouble() ?? 0));
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${fs.length} fatura(s)'),
                            Text('Total ${total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          itemCount: fs.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final f = fs[i];
                            final url = (f['ficheiroUrl'] ?? '').toString();
                            return ListTile(
                              dense: true,
                              title: Text('${f['nomeFicheiro'] ?? '—'}'),
                              subtitle: Text([
                                f['fornecedor'] ?? '',
                                if ((f['numero'] ?? '').toString().isNotEmpty)
                                  'nº ${f['numero']}',
                                ((f['total'] as num?)?.toStringAsFixed(2) ??
                                    ''),
                              ].join(' · ')),
                              trailing: url.isEmpty
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.open_in_new,
                                          size: 18),
                                      onPressed: () => launchUrl(
                                        Uri.parse(url),
                                        mode: LaunchMode.externalApplication,
                                      ),
                                    ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: FilledButton.icon(
                          icon: const Icon(Icons.copy),
                          label: const Text('Copiar resumo (CSV)'),
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: _csv(fs)));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Resumo copiado.')),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Envio mensal automático por email: configura '
                          'TURNKEY_CONTAB_EMAIL no servidor (ver DEPLOY).',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
