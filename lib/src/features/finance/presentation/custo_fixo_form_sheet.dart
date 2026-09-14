import 'package:flutter/material.dart';

import '../domain/custo_fixo.dart';

/// Abre a folha de criação/edição de um custo fixo/variável.
Future<CustoFixoInput?> showCustoFixoFormSheet(
  BuildContext context, {
  CustoFixo? existente,
}) {
  return showModalBottomSheet<CustoFixoInput>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CustoFixoFormSheet(existente: existente),
  );
}

class _CustoFixoFormSheet extends StatefulWidget {
  const _CustoFixoFormSheet({this.existente});
  final CustoFixo? existente;

  @override
  State<_CustoFixoFormSheet> createState() => _CustoFixoFormSheetState();
}

class _CustoFixoFormSheetState extends State<_CustoFixoFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.existente?.nome ?? '');
  late final _valor = TextEditingController(
    text: widget.existente != null && widget.existente!.valorMensal > 0
        ? widget.existente!.valorMensal.toStringAsFixed(2)
        : '',
  );
  late final _notas = TextEditingController(text: widget.existente?.notas ?? '');
  late TipoCusto _tipo = widget.existente?.tipo ?? TipoCusto.fixo;

  @override
  void dispose() {
    _nome.dispose();
    _valor.dispose();
    _notas.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      CustoFixoInput(
        nome: _nome.text,
        tipo: _tipo,
        valorMensal: double.parse(_valor.text.replaceAll(',', '.')),
        notas: _notas.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editar = widget.existente != null;
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
              editar ? 'Editar custo' : 'Novo custo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nome,
              autofocus: !editar,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nome *',
                hintText: 'Ex.: Aluguel, Salários, Internet',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
            ),
            const SizedBox(height: 12),
            SegmentedButton<TipoCusto>(
              segments: const [
                ButtonSegment(value: TipoCusto.fixo, label: Text('Fixo')),
                ButtonSegment(
                    value: TipoCusto.variavel, label: Text('Variável')),
              ],
              selected: {_tipo},
              onSelectionChanged: (s) => setState(() => _tipo = s.first),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _valor,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Valor mensal *',
                prefixText: '€ ',
              ),
              validator: (v) {
                final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                return (n == null || n <= 0) ? 'Valor inválido' : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notas,
              decoration: const InputDecoration(labelText: 'Notas (opcional)'),
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
