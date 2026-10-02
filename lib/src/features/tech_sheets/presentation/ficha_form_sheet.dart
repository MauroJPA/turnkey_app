import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cookie_formats/application/cookie_format_providers.dart';
import '../../products/domain/produto_rotulo.dart';
import '../domain/tech_sheet.dart';

Future<FichaInput?> showFichaFormSheet(
  BuildContext context, {
  FichaTecnica? existente,

  /// Nome a pré-preencher ao criar uma ficha nova (ignorado se [existente]
  /// estiver definido) — ex.: a partir da descrição de uma linha de venda
  /// sem produto identificado.
  String nomeInicial = '',
}) {
  return showModalBottomSheet<FichaInput>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        _FichaFormSheet(existente: existente, nomeInicial: nomeInicial),
  );
}

class _FichaFormSheet extends ConsumerStatefulWidget {
  const _FichaFormSheet({this.existente, this.nomeInicial = ''});
  final FichaTecnica? existente;
  final String nomeInicial;

  @override
  ConsumerState<_FichaFormSheet> createState() => _FichaFormSheetState();
}

class _FichaFormSheetState extends ConsumerState<_FichaFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nome = TextEditingController(
    text: widget.existente?.nome ?? widget.nomeInicial,
  );
  late final _categoria = TextEditingController(
    text: widget.existente?.categoria ?? '',
  );
  late String _formatoId = widget.existente?.formatoId ?? '';
  late final _subnome = TextEditingController(
    text: widget.existente?.subnome ?? '',
  );
  late final _descricao = TextEditingController(
    text: widget.existente?.descricao ?? '',
  );
  late final _validade = TextEditingController(
    text: (widget.existente?.validadeDias ?? 0) > 0
        ? '${widget.existente!.validadeDias}'
        : '',
  );
  late final _conservacao = TextEditingController(
    text: widget.existente?.conservacao ?? '',
  );

  /// '' = sem escolha, uma das [conservacoesPadrao], ou [_outro] (texto livre).
  static const _outro = '__outro';
  late String _conservacaoSel = () {
    final c = (widget.existente?.conservacao ?? '').trim();
    if (c.isEmpty) return '';
    return conservacoesPadrao.contains(c) ? c : _outro;
  }();

  @override
  void dispose() {
    _nome.dispose();
    _categoria.dispose();
    _subnome.dispose();
    _descricao.dispose();
    _validade.dispose();
    _conservacao.dispose();
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
        subnome: _subnome.text,
        descricao: _descricao.text,
        validadeDias: int.tryParse(_validade.text.trim()) ?? 0,
        conservacao: _conservacaoSel == _outro
            ? _conservacao.text
            : _conservacaoSel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editar = widget.existente != null;
    final formatos = ref.watch(formatosProvider).valueOrNull ?? const [];
    final visiveis = formatos
        .where((f) => f.ativo || f.id == _formatoId)
        .toList();
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
            TextFormField(
              controller: _subnome,
              maxLength: 60,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Subnome (opcional)',
                helperText:
                    'Ex.: Red Velvet. Pode ir na etiqueta, por baixo '
                    'do nome.',
              ),
            ),
            DropdownButtonFormField<String>(
              initialValue: valor,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Formato do cookie (opcional)',
                helperText:
                    'Mini, Recheado, Simples… define o peso por '
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
            const SizedBox(height: 12),
            TextFormField(
              controller: _descricao,
              maxLength: 300,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Característica (opcional)',
                helperText:
                    'Curta: aparece por baixo do nome na etiqueta. '
                    'Ex.: Brigadeiro de queijo creme e compota de frutos '
                    'vermelhos.',
                helperMaxLines: 2,
              ),
            ),
            TextFormField(
              controller: _validade,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Validade (dias)',
                helperText: 'a contar da data de fabrico',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('conservacao-$_conservacaoSel'),
              initialValue: _conservacaoSel,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Conservação'),
              items: [
                const DropdownMenuItem(value: '', child: Text('— escolher —')),
                for (final c in conservacoesPadrao)
                  DropdownMenuItem(value: c, child: Text(c)),
                const DropdownMenuItem(value: _outro, child: Text('Outro…')),
              ],
              onChanged: (v) => setState(() => _conservacaoSel = v ?? ''),
            ),
            if (_conservacaoSel == _outro)
              TextFormField(
                controller: _conservacao,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Modo de conservação',
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
