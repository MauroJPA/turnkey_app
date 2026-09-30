import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../import_csv/domain/import_result.dart';
import '../application/custos_fixos_import_service.dart';

/// Folha para importar vários custos fixos/variáveis de uma vez, colando
/// texto (direto da folha de cálculo) ou escolhendo um ficheiro CSV.
Future<void> showImportarCustosFixosSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => const _ImportarCustosFixosSheet(),
  );
}

class _ImportarCustosFixosSheet extends ConsumerStatefulWidget {
  const _ImportarCustosFixosSheet();

  @override
  ConsumerState<_ImportarCustosFixosSheet> createState() =>
      _ImportarCustosFixosSheetState();
}

class _ImportarCustosFixosSheetState
    extends ConsumerState<_ImportarCustosFixosSheet> {
  bool _busy = false;
  final _texto = TextEditingController();

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _escolherFicheiro() async {
    try {
      final conteudo = await ref
          .read(custosFixosImportServiceProvider)
          .pickCsv();
      if (mounted) setState(() => _texto.text = conteudo);
    } on ImportCancelled {
      // nada escolhido
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _importar() async {
    setState(() => _busy = true);
    try {
      final r = await ref
          .read(custosFixosImportServiceProvider)
          .importCsv(_texto.text);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Importação de custos'),
          content: SingleChildScrollView(
            child: Text(
              r.semErros
                  ? r.resumo
                  : '${r.resumo}\n\n'
                        '${r.erros.take(12).join('\n')}'
                        '${r.erros.length > 12 ? '\n…' : ''}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Ok'),
            ),
          ],
        ),
      );
      if (mounted && r.criados > 0) Navigator.pop(context);
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_busy) const LinearProgressIndicator(),
            Text('Importar custos fixos/variáveis', style: tt.titleLarge),
            const SizedBox(height: 10),
            Text(
              'Uma linha por custo: nome, valor, dia de pagamento e notas '
              '(as duas últimas são opcionais, separadas por tab, ; ou ,). '
              'Podes colar direto da folha de cálculo. Todos entram como '
              '"Fixo" — muda o tipo depois na app se algum for variável.',
              style: tt.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _texto,
              minLines: 6,
              maxLines: 10,
              decoration: const InputDecoration(
                hintText: 'Energia\t€140,00\t31\tnotas',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _escolherFicheiro,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Escolher ficheiro CSV'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy ? null : _importar,
              child: const Text('Importar'),
            ),
          ],
        ),
      ),
    );
  }
}
