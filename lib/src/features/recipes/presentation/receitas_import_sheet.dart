import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../import_csv/domain/import_result.dart';
import '../application/receitas_import_service.dart';

/// Folha para importar receitas: colar o texto (ex.: copiado de uma folha de
/// cálculo) ou escolher um ficheiro CSV.
Future<void> showImportarReceitasSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => const _ImportarReceitasSheet(),
  );
}

class _ImportarReceitasSheet extends ConsumerStatefulWidget {
  const _ImportarReceitasSheet();

  @override
  ConsumerState<_ImportarReceitasSheet> createState() =>
      _ImportarReceitasSheetState();
}

class _ImportarReceitasSheetState
    extends ConsumerState<_ImportarReceitasSheet> {
  final _texto = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _escolherFicheiro() async {
    try {
      final conteudo = await ref.read(receitasImportServiceProvider).pickCsv();
      if (mounted) setState(() => _texto.text = conteudo);
    } on ImportCancelled {
      // nada escolhido
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _importar() async {
    setState(() => _busy = true);
    try {
      final r =
          await ref.read(receitasImportServiceProvider).importCsv(_texto.text);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Importação de receitas'),
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
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
            Text('Importar receitas', style: tt.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Uma linha por ingrediente: nome da receita, categoria, '
              'ingrediente e quantidade em gramas (separados por tab, ; ou ,). '
              'Podes colar direto da folha de cálculo. Ingredientes sem '
              'correspondência ficam pendentes para ligares depois.',
              style: tt.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _texto,
              minLines: 6,
              maxLines: 10,
              decoration: const InputDecoration(
                hintText: 'Massa_Normandia\tMassas\tManteiga\t191',
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
