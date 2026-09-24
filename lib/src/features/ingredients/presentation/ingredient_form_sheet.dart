import 'package:flutter/material.dart';

import '../../../core/nutrition/nutrition.dart';
import '../domain/ingredient.dart';
import '../domain/nutri_ingresso.dart';

/// Folha de baixo para criar/editar um ingrediente. Ao criar, também se pode
/// já preencher a informação nutricional (opcional).
/// Devolve um [IngredienteFormResultado] ou `null` se cancelado.
Future<IngredienteFormResultado?> showIngredientFormSheet(
  BuildContext context, {
  Ingrediente? existente,
}) {
  return showModalBottomSheet<IngredienteFormResultado>(
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

  // Nutrição (só ao criar), por 100 g / 100 ml.
  final _kcal = TextEditingController();
  final _lip = TextEditingController();
  final _sat = TextEditingController();
  final _hc = TextEditingController();
  final _ac = TextEditingController();
  final _fib = TextEditingController();
  final _prot = TextEditingController();
  final _sal = TextEditingController();
  String _baseNutri = '100g';
  final _alerg = <String>{};
  bool _abrirNutricao = false;

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
      _kcal,
      _lip,
      _sat,
      _hc,
      _ac,
      _fib,
      _prot,
      _sal,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.').trim()) ?? 0;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final nutri = NutriIngresso(
      nutri: Nutrientes(
        kcal: _num(_kcal),
        lipidos: _num(_lip),
        saturados: _num(_sat),
        hidratos: _num(_hc),
        acucares: _num(_ac),
        fibra: _num(_fib),
        proteina: _num(_prot),
        sal: _num(_sal),
      ),
      base: _baseNutri,
      alergenios: _alerg.toList(),
    );
    final criar = widget.existente == null;
    Navigator.pop(
      context,
      IngredienteFormResultado(
        input: IngredienteInput(
          nome: _nome.text,
          caracteristica: _caracteristica.text,
          marca: _marca.text,
          fornecedor: _fornecedor.text,
          preco: _num(_preco),
          gramasEmbalagem: _num(_gramas),
          disponivel: _disponivel,
          origem: _origem,
        ),
        nutri: criar && nutri.temDados ? nutri : null,
        abrirNutricao: criar && _abrirNutricao,
      ),
    );
  }

  Widget _campoNutri(String label, TextEditingController c) => TextFormField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, isDense: true),
      );

  Widget _par(Widget a, Widget b) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Expanded(child: a),
            const SizedBox(width: 12),
            Expanded(child: b),
          ],
        ),
      );

  Widget _seccaoNutricao() => ExpansionTile(
        key: const ValueKey('nutri-opcional'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        leading: const Icon(Icons.local_dining_outlined),
        title: const Text('Informação nutricional (opcional)'),
        subtitle: const Text('Valores por 100 g / 100 ml e alergénios'),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '100g', label: Text('por 100 g')),
              ButtonSegment(value: '100ml', label: Text('por 100 ml')),
            ],
            selected: {_baseNutri},
            onSelectionChanged: (s) => setState(() => _baseNutri = s.first),
          ),
          const SizedBox(height: 12),
          _par(_campoNutri('Energia (kcal)', _kcal),
              _campoNutri('Lípidos (g)', _lip)),
          _par(_campoNutri('dos quais saturados (g)', _sat),
              _campoNutri('Hidratos de carbono (g)', _hc)),
          _par(_campoNutri('dos quais açúcares (g)', _ac),
              _campoNutri('Fibra (g)', _fib)),
          _par(_campoNutri('Proteína (g)', _prot),
              _campoNutri('Sal (g)', _sal)),
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text('Contém (alergénios)'),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final a in kAlergenios)
                FilterChip(
                  label: Text(a),
                  selected: _alerg.contains(a),
                  onSelected: (v) => setState(() {
                    v ? _alerg.add(a) : _alerg.remove(a);
                  }),
                ),
            ],
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'Abrir a folha completa depois (tabela INSA, foto do rótulo)',
            ),
            value: _abrirNutricao,
            onChanged: (v) => setState(() => _abrirNutricao = v ?? false),
          ),
        ],
      );

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
              if (!editar) _seccaoNutricao(),
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
