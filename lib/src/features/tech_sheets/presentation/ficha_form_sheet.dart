import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cookie_formats/application/cookie_format_providers.dart';
import '../domain/tech_sheet.dart';

Future<FichaInput?> showFichaFormSheet(
  BuildContext context, {
  FichaTecnica? existente,
}) {
  return showModalBottomSheet<FichaInput>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _FichaFormSheet(existente: existente),
  );
}

class _FichaFormSheet extends ConsumerStatefulWidget {
  const _FichaFormSheet({this.existente});
  final FichaTecnica? existente;

  @override
  ConsumerState<_FichaFormSheet> createState() => _FichaFormSheetState();
}

class _FichaFormSheetState extends ConsumerState<_FichaFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.existente?.nome ?? '');
  late final _categoria =
      TextEditingController(text: widget.existente?.categoria ?? '');
  late String _formatoId = widget.existente?.formatoId ?? '';

  @override
  void dispose() {
    _nome.dispose();
    _categoria.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      FichaInput(
        nome: _nome.text,
        categoria: _categoria.text,
        formatoId: _formatoId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editar = widget.existente != null;
    final formatos = ref.watch(formatosProvider).valueOrNull ?? const [];
    final visiveis =
        formatos.where((f) => f.ativo || f.id == _formatoId).toList();
    final valor = visiveis.any((f) => f.id == _formatoId) ? _formatoId : '';

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              editar ? 'Editar ficha' : 'Nova ficha técnica',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nome,
              decoration: const InputDecoration(labelText: 'Nome do produto *'),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _categoria,
              decoration: const InputDecoration(
                labelText: 'Categoria (opcional)',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: valor,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Formato do cookie (opcional)',
                helperText: 'Mini, Recheado, Simples… define o peso por '
                    'unidade e liga este produto à produção.',
                helperMaxLines: 2,
              ),
              items: [
                const DropdownMenuItem(value: '', child: Text('Sem formato')),
                for (final f in visiveis)
                  DropdownMenuItem(
                    value: f.id,
                    child: Text(f.rotulo, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _formatoId = v ?? ''),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              child: Text(editar ? 'Guardar' : 'Criar'),
            ),
          ],
        ),
      ),
    );
  }
}
