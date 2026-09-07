import 'package:flutter/material.dart';

import '../domain/ingredient.dart';

/// Folha de baixo para criar/editar um ingrediente.
/// Devolve um [IngredienteInput] ou `null` se cancelado.
Future<IngredienteInput?> showIngredientFormSheet(
  BuildContext context, {
  Ingrediente? existente,
}) {
  return showModalBottomSheet<IngredienteInput>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _IngredientFormSheet(existente: existente),
  );
}

class _IngredientFormSheet extends StatefulWidget {
  const _IngredientFormSheet({this.existente});

  final Ingrediente? existente;

  @override
  State<_IngredientFormSheet> createState() => _IngredientFormSheetState();
}

class _IngredientFormSheetState extends State<_IngredientFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.existente?.nome ?? '');
  late final _caracteristica =
      TextEditingController(text: widget.existente?.caracteristica ?? '');
  late final _marca = TextEditingController(text: widget.existente?.marca ?? '');
  late final _fornecedor =
      TextEditingController(text: widget.existente?.fornecedor ?? '');
  late final _preco = TextEditingController(
    text: widget.existente == null ? '' : _n(widget.existente!.preco),
  );
  late final _gramas = TextEditingController(
    text: widget.existente == null
        ? ''
        : _n(widget.existente!.gramasEmbalagem),
  );
  late OrigemIngrediente _origem =
      widget.existente?.origem ?? OrigemIngrediente.comprado;
  late bool _disponivel = widget.existente?.disponivel ?? true;

  static String _n(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toString();

  @override
  void dispose() {
    for (final c in [
      _nome,
      _caracteristica,
      _marca,
      _fornecedor,
      _preco,
      _gramas,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.').trim()) ?? 0;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      IngredienteInput(
        nome: _nome.text,
        caracteristica: _caracteristica.text,
        marca: _marca.text,
        fornecedor: _fornecedor.text,
        preco: _num(_preco),
        gramasEmbalagem: _num(_gramas),
        disponivel: _disponivel,
        origem: _origem,
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
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                editar ? 'Editar ingrediente' : 'Novo ingrediente',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nome,
                decoration: const InputDecoration(labelText: 'Nome *'),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _caracteristica,
                decoration: const InputDecoration(
                  labelText: 'Tipo / característica',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _marca,
                      decoration: const InputDecoration(labelText: 'Marca'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _fornecedor,
                      decoration:
                          const InputDecoration(labelText: 'Fornecedor'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _preco,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Preço da embalagem (€) *',
                      ),
                      validator: (v) =>
                          _num(_preco) <= 0 ? 'Indica o preço' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _gramas,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Gramas da embalagem *',
                      ),
                      validator: (v) =>
                          _num(_gramas) <= 0 ? 'Indica as gramas' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SegmentedButton<OrigemIngrediente>(
                segments: const [
                  ButtonSegment(
                    value: OrigemIngrediente.comprado,
                    label: Text('Comprado'),
                  ),
                  ButtonSegment(
                    value: OrigemIngrediente.fabricoProprio,
                    label: Text('Fabrico próprio'),
                  ),
                ],
                selected: {_origem},
                onSelectionChanged: (s) => setState(() => _origem = s.first),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Disponível no fornecedor'),
                value: _disponivel,
                onChanged: (v) => setState(() => _disponivel = v),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _submit,
                child: Text(editar ? 'Guardar' : 'Adicionar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
