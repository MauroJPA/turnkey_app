import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../domain/recipe.dart';

/// Imagem escolhida no formulário (ainda não enviada).
typedef ImagemNova = ({String nome, List<int> bytes});

/// O que o formulário de receita devolve: os dados e, ao criar, as imagens
/// opcionais a anexar depois de a receita existir.
class RecipeFormResultado {
  const RecipeFormResultado({required this.input, this.imagens = const []});
  final RecipeInput input;
  final List<ImagemNova> imagens;
}

Future<RecipeFormResultado?> showRecipeFormSheet(
  BuildContext context, {
  Receita? existente,
}) {
  return showModalBottomSheet<RecipeFormResultado>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _RecipeFormSheet(existente: existente),
  );
}

class _RecipeFormSheet extends StatefulWidget {
  const _RecipeFormSheet({this.existente});
  final Receita? existente;

  @override
  State<_RecipeFormSheet> createState() => _RecipeFormSheetState();
}

class _RecipeFormSheetState extends State<_RecipeFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.existente?.nome ?? '');
  late final _rendimento = TextEditingController(
    text: (widget.existente?.rendimentoManual ?? false)
        ? widget.existente!.rendimentoEsperado.toStringAsFixed(0)
        : '',
  );
  late CategoriaReceita _categoria =
      widget.existente?.categoria ?? CategoriaReceita.massa;
  late bool _manual = widget.existente?.rendimentoManual ?? false;
  late bool _publicar = widget.existente?.publicarComoIngrediente ?? false;
  late final _procedimento = TextEditingController(
    text: widget.existente?.procedimento ?? '',
  );

  final _imagens = <ImagemNova>[];

  @override
  void dispose() {
    _nome.dispose();
    _rendimento.dispose();
    _procedimento.dispose();
    super.dispose();
  }

  Future<void> _escolherImagens() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: true,
    );
    if (picked == null) return;
    setState(() {
      for (final f in picked.files) {
        if (f.bytes != null) {
          _imagens.add((nome: f.name, bytes: f.bytes!.toList()));
        }
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      RecipeFormResultado(
        input: RecipeInput(
          nome: _nome.text,
          categoria: _categoria,
          rendimentoManual: _manual,
          rendimentoEsperado:
              double.tryParse(_rendimento.text.replaceAll(',', '.')) ?? 0,
          publicarComoIngrediente: _publicar,
          procedimento: _procedimento.text,
        ),
        imagens: widget.existente == null ? List.of(_imagens) : const [],
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
                editar ? 'Editar receita' : 'Nova receita',
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
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  for (final c in CategoriaReceita.values)
                    ChoiceChip(
                      label: Text(c.label),
                      selected: _categoria == c,
                      onSelected: (_) => setState(() => _categoria = c),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Rendimento manual'),
                subtitle: const Text(
                  'Se desligado, é a soma das quantidades das linhas.',
                ),
                value: _manual,
                onChanged: (v) => setState(() => _manual = v),
              ),
              if (_manual)
                TextFormField(
                  controller: _rendimento,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Rendimento esperado (g)',
                  ),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Publicar como ingrediente'),
                subtitle: const Text(
                  'Fica disponível para usar noutras receitas e fichas.',
                ),
                value: _publicar,
                onChanged: (v) => setState(() => _publicar = v),
              ),
              const Divider(height: 24),
              Text(
                'Procedimento e imagens (opcional)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _procedimento,
                minLines: 3,
                maxLines: 10,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Procedimento',
                  hintText: 'Um passo por linha',
                  alignLabelWithHint: true,
                ),
              ),
              if (!editar) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _escolherImagens,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(
                    _imagens.isEmpty
                        ? 'Anexar imagens'
                        : 'Juntar mais imagens (${_imagens.length})',
                  ),
                ),
                if (_imagens.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < _imagens.length; i++)
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  Uint8List.fromList(_imagens[i].bytes),
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 72,
                                    height: 72,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    child: const Icon(Icons.image_outlined),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: -8,
                                top: -8,
                                child: InkWell(
                                  onTap: () =>
                                      setState(() => _imagens.removeAt(i)),
                                  child: const CircleAvatar(
                                    radius: 11,
                                    child: Icon(Icons.close, size: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _submit,
                child: Text(editar ? 'Guardar' : 'Criar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
