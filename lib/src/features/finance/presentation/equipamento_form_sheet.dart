import 'package:flutter/material.dart';

import '../domain/equipamento.dart';

/// Abre a folha de criação/edição de um equipamento.
Future<EquipamentoInput?> showEquipamentoFormSheet(
  BuildContext context, {
  Equipamento? existente,
}) {
  return showModalBottomSheet<EquipamentoInput>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _EquipamentoFormSheet(existente: existente),
  );
}

class _EquipamentoFormSheet extends StatefulWidget {
  const _EquipamentoFormSheet({this.existente});
  final Equipamento? existente;

  @override
  State<_EquipamentoFormSheet> createState() => _EquipamentoFormSheetState();
}

class _EquipamentoFormSheetState extends State<_EquipamentoFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.existente?.nome ?? '');
  late final _custo = TextEditingController(
    text: widget.existente != null && widget.existente!.custo > 0
        ? widget.existente!.custo.toStringAsFixed(2)
        : '',
  );
  late final _vidaUtil = TextEditingController(
    text: widget.existente != null && widget.existente!.vidaUtilAnos > 0
        ? widget.existente!.vidaUtilAnos.toStringAsFixed(0)
        : '',
  );
  late final _notas = TextEditingController(text: widget.existente?.notas ?? '');

  double get _custoMensal {
    final custo = double.tryParse(_custo.text.replaceAll(',', '.')) ?? 0;
    final anos = double.tryParse(_vidaUtil.text.replaceAll(',', '.')) ?? 0;
    return anos > 0 ? custo / (anos * 12) : 0;
  }

  @override
  void dispose() {
    _nome.dispose();
    _custo.dispose();
    _vidaUtil.dispose();
    _notas.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      EquipamentoInput(
        nome: _nome.text,
        custo: double.parse(_custo.text.replaceAll(',', '.')),
        vidaUtilAnos: double.parse(_vidaUtil.text.replaceAll(',', '.')),
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
              editar ? 'Editar equipamento' : 'Novo equipamento',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nome,
              autofocus: !editar,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nome *',
                hintText: 'Ex.: Forno, Balcão, Computador',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _custo,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Custo de compra *',
                prefixText: '€ ',
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                return (n == null || n <= 0) ? 'Valor inválido' : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _vidaUtil,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Vida útil (anos) *',
                hintText: 'Ex.: 3, 5, 10',
              ),
              onChanged: (_) => setState(() {}),
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
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Depreciação mensal'),
                  Text(
                    '€ ${_custoMensal.toStringAsFixed(2)}/mês',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
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
