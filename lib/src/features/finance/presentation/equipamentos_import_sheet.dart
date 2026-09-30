import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../import_csv/domain/import_result.dart';
import '../application/equipamentos_import_service.dart';

/// Folha para importar vários equipamentos de uma vez, colando texto
/// (direto da folha de cálculo) ou escolhendo um ficheiro CSV.
Future<void> showImportarEquipamentosSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => const _ImportarEquipamentosSheet(),
  );
}

class _ImportarEquipamentosSheet extends ConsumerStatefulWidget {
  const _ImportarEquipamentosSheet();

  @override
  ConsumerState<_ImportarEquipamentosSheet> createState() =>
      _ImportarEquipamentosSheetState();
}

class _ImportarEquipamentosSheetState
    extends ConsumerState<_ImportarEquipamentosSheet> {
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
          .read(equipamentosImportServiceProvider)
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
          .read(equipamentosImportServiceProvider)
          .importCsv(_texto.text);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Importação de equipamentos'),
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
            Text('Importar equipamentos', style: tt.titleLarge),
            const SizedBox(height: 10),
            Text(
              'Uma linha por equipamento: nome, custo de compra, vida útil '
              '(anos) e notas (a última é opcional, separados por tab, ; ou '
              'vírgula). Podes colar direto da folha de cálculo.',
              style: tt.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _texto,
              minLines: 6,
              maxLines: 10,
              decoration: const InputDecoration(
                hintText: 'Computador\t€500,00\t3',
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
