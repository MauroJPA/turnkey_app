import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/download/web_download.dart';
import '../data/invoice_repository.dart';
import '../domain/invoice_erros.dart';

enum _Periodo { mes, tudo }

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
  _Periodo _periodo = _Periodo.mes;
  Future<List<Map<String, dynamic>>>? _fut;
  final _email = TextEditingController();
  final _nota = TextEditingController();
  bool _enviando = false;
  bool _baixando = false;

  @override
  void initState() {
    super.initState();
    final agora = DateTime.now();
    _mes = DateTime(agora.year, agora.month - 1); // mês anterior
    _carregar();
    ref.read(invoiceRepositoryProvider).emailContabilidadeAtual().then((e) {
      if (mounted && e.isNotEmpty) setState(() => _email.text = e);
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _nota.dispose();
    super.dispose();
  }

  ({String? de, String? ate}) get _intervalo {
    if (_periodo == _Periodo.tudo) return (de: null, ate: null);
    final ini = DateTime(_mes.year, _mes.month, 1);
    final fim = DateTime(_mes.year, _mes.month + 1, 0);
    String d(DateTime x) =>
        '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
    return (de: d(ini), ate: d(fim));
  }

  void _carregar() {
    final i = _intervalo;
    final fut = ref
        .read(invoiceRepositoryProvider)
        .exportContabilidade(de: i.de, ate: i.ate);
    // Bloco (não expressão): uma closure `() => _fut = fut` devolveria o
    // valor da atribuição (a própria Future) e o setState rejeita-a em
    // modo debug ("callback argument returned a Future").
    setState(() {
      _fut = fut;
    });
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

  Future<void> _enviarEmail(List<Map<String, dynamic>> fs) async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escreve o email da contabilidade.')),
      );
      return;
    }
    setState(() => _enviando = true);
    try {
      final i = _intervalo;
      final r = await ref
          .read(invoiceRepositoryProvider)
          .enviarContabilidade(
            de: i.de,
            ate: i.ate,
            email: email,
            nota: _nota.text,
          );
      if (!mounted) return;
      _nota.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Enviado: ${r.quantidade} fatura(s), '
            'total ${r.total.toStringAsFixed(2)}.',
          ),
        ),
      );
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _baixarZip(List<Map<String, dynamic>> fs) async {
    setState(() => _baixando = true);
    try {
      final repo = ref.read(invoiceRepositoryProvider);
      final arquivo = Archive();
      var falhas = 0;
      for (final f in fs) {
        final url = (f['ficheiroUrl'] ?? '').toString();
        final nome = (f['nomeFicheiro'] ?? '').toString();
        if (url.isEmpty || nome.isEmpty) continue;
        try {
          final comToken = await repo.comToken(url);
          final resp = await http.get(Uri.parse(comToken));
          if (resp.statusCode != 200) {
            falhas++;
            continue;
          }
          arquivo.addFile(
            ArchiveFile(nome, resp.bodyBytes.length, resp.bodyBytes),
          );
        } on Object {
          falhas++;
        }
      }
      if (arquivo.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nenhum ficheiro para baixar.')),
          );
        }
        return;
      }
      final zipBytes = ZipEncoder().encode(arquivo);
      if (zipBytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível criar o ZIP.')),
          );
        }
        return;
      }
      final rotulo = _periodo == _Periodo.tudo
          ? 'todas'
          : '${_mes.year}-${_mes.month.toString().padLeft(2, '0')}';
      baixarFicheiro('faturas-$rotulo.zip', zipBytes);
      if (mounted && falhas > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$falhas ficheiro(s) não conseguiram ser lidos.'),
          ),
        );
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
      }
    } finally {
      if (mounted) setState(() => _baixando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rotulo = '${_mes.month.toString().padLeft(2, '0')}/${_mes.year}';
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Faturas para a contabilidade',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            SegmentedButton<_Periodo>(
              segments: const [
                ButtonSegment(value: _Periodo.mes, label: Text('Um mês')),
                ButtonSegment(value: _Periodo.tudo, label: Text('Todas')),
              ],
              selected: {_periodo},
              onSelectionChanged: (s) {
                setState(() => _periodo = s.first);
                _carregar();
              },
            ),
            if (_periodo == _Periodo.mes) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  IconButton(
                    onPressed: () => _mudarMes(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(child: Text(rotulo, textAlign: TextAlign.center)),
                  IconButton(
                    onPressed: () => _mudarMes(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
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
                      child: Text('Nenhuma fatura confirmada neste período.'),
                    );
                  }
                  final total = fs.fold<double>(
                    0,
                    (s, f) => s + ((f['total'] as num?)?.toDouble() ?? 0),
                  );
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${fs.length} fatura(s)'),
                            Text(
                              'Total ${total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          itemCount: fs.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final f = fs[i];
                            final url = (f['ficheiroUrl'] ?? '').toString();
                            return ListTile(
                              dense: true,
                              title: Text('${f['nomeFicheiro'] ?? '—'}'),
                              subtitle: Text(
                                [
                                  f['fornecedor'] ?? '',
                                  if ((f['numero'] ?? '').toString().isNotEmpty)
                                    'nº ${f['numero']}',
                                  ((f['total'] as num?)?.toStringAsFixed(2) ??
                                      ''),
                                ].join(' · '),
                              ),
                              trailing: url.isEmpty
                                  ? null
                                  : IconButton(
                                      icon: const Icon(
                                        Icons.open_in_new,
                                        size: 18,
                                      ),
                                      onPressed: () async {
                                        final u = await ref
                                            .read(invoiceRepositoryProvider)
                                            .comToken(url);
                                        await launchUrl(
                                          Uri.parse(u),
                                          mode: LaunchMode.externalApplication,
                                        );
                                      },
                                    ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email da contabilidade',
                          isDense: true,
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nota,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Nota para a contabilidade (opcional)',
                          hintText: 'Ex.: falta a fatura da EDP, chega depois',
                          isDense: true,
                          prefixIcon: Icon(Icons.sticky_note_2_outlined),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            icon: _enviando
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send_outlined),
                            label: const Text('Enviar por email'),
                            onPressed: _enviando
                                ? null
                                : () => _enviarEmail(fs),
                          ),
                          OutlinedButton.icon(
                            icon: _baixando
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.folder_zip_outlined),
                            label: const Text('Baixar ZIP'),
                            onPressed: _baixando ? null : () => _baixarZip(fs),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.copy),
                            label: const Text('Copiar resumo (CSV)'),
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: _csv(fs)),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Resumo copiado.'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'O assunto do email é gerado automaticamente '
                        '(identifica a app e a empresa). O email fica '
                        'guardado para o envio mensal automático (dia 1, '
                        'requer SMTP configurado no servidor).',
                        style: Theme.of(context).textTheme.bodySmall,
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
