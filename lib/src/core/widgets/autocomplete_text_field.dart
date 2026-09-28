import 'package:flutter/material.dart';

/// Campo de texto com sugestões dos valores já usados (marca, fornecedor…):
/// ao tocar/escrever aparece uma lista do que já existe para escolher, mas
/// nunca obriga — continua a dar para escrever um valor novo à mão. Usa
/// [controller] diretamente (tal como um `TextField` normal), por isso os
/// sítios que já leem `.text` desse controlador ao guardar não mudam nada.
class AutocompleteTextField extends StatefulWidget {
  const AutocompleteTextField({
    super.key,
    required this.controller,
    required this.options,
    this.labelText,
    this.hintText,
    this.isDense = false,
    this.textCapitalization = TextCapitalization.words,
    this.onChanged,
    this.readOnly = false,
    this.helperText,
    this.helperMaxLines,
  });

  final TextEditingController controller;

  /// Valores já usados (marcas ou fornecedores conhecidos da empresa),
  /// tipicamente vindos de um provider — já sem duplicados, ordenados.
  final List<String> options;

  final String? labelText;
  final String? hintText;
  final bool isDense;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final String? helperText;
  final int? helperMaxLines;

  @override
  State<AutocompleteTextField> createState() => _AutocompleteTextFieldState();
}

class _AutocompleteTextFieldState extends State<AutocompleteTextField> {
  // Só usado quando há sugestões (RawAutocomplete exige um FocusNode nosso
  // quando lhe damos o próprio TextEditingController); tem de viver aqui,
  // não em cada build, senão o campo perde o foco a cada letra escrita.
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.options.isEmpty || widget.readOnly) {
      // Sem nada ainda usado (ou campo só de leitura): campo simples, sem
      // overhead do Autocomplete.
      return TextField(
        controller: widget.controller,
        readOnly: widget.readOnly,
        textCapitalization: widget.textCapitalization,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
          isDense: widget.isDense,
          helperText: widget.helperText,
          helperMaxLines: widget.helperMaxLines,
        ),
        onChanged: widget.onChanged,
      );
    }
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (v) {
        final q = v.text.trim().toLowerCase();
        if (q.isEmpty) return widget.options;
        return widget.options.where((o) => o.toLowerCase().contains(q));
      },
      onSelected: (v) => widget.onChanged?.call(v),
      fieldViewBuilder: (context, fieldController, focusNode, onSubmitted) {
        return TextField(
          controller: fieldController,
          focusNode: focusNode,
          textCapitalization: widget.textCapitalization,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            isDense: widget.isDense,
            helperText: widget.helperText,
            helperMaxLines: widget.helperMaxLines,
            suffixIcon: const Icon(Icons.arrow_drop_down, size: 20),
          ),
          onChanged: widget.onChanged,
          onSubmitted: (_) => onSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, opts) {
        final lista = opts.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, minWidth: 220),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: lista.length,
                itemBuilder: (context, i) {
                  final o = lista[i];
                  return ListTile(
                    dense: true,
                    title: Text(o),
                    onTap: () => onSelected(o),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
