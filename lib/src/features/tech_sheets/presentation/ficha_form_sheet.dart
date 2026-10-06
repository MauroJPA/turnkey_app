import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cookie_formats/application/cookie_format_providers.dart';
import '../../cookie_formats/domain/cookie_format.dart';
import '../../cookie_formats/presentation/formato_sheet.dart';
import '../../products/domain/produto_rotulo.dart';
import '../application/tech_sheets_providers.dart';
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
  late final _temperatura = TextEditingController(
    text: (widget.existente?.temperaturaFornoC ?? 0) > 0
        ? '${widget.existente!.temperaturaFornoC}'
        : '',
  );
  late final _assadura = TextEditingController(
    text: (widget.existente?.tempoAssaduraMin ?? 0) > 0
        ? '${widget.existente!.tempoAssaduraMin}'
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
    _assadura.dispose();
    _temperatura.dispose();
    _conservacao.dispose();
    super.dispose();
  }

  /// Valor do item "＋ Novo formato…" do seletor.
  static const _novoFormato = '__novo_formato';

  Future<void> _criarFormato() async {
    final r = await showFormatoSheet(context);
    if (r?.formato != null && mounted) {
      setState(() => _formatoId = r!.formato!.id);
    }
  }

  Future<void> _editarFormato(FormatoCookie f) async {
    final r = await showFormatoSheet(context, existente: f);
    if (r == null || !mounted) return;
    if (r.apagado) setState(() => _formatoId = '');
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
        tempoAssaduraMin: int.tryParse(_assadura.text.trim()) ?? 0,
        temperaturaFornoC: int.tryParse(_temperatura.text.trim()) ?? 0,
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
    final categoriasUsadas = {
      for (final f
          in ref.watch(fichasListProvider(false)).valueOrNull ??
              const <FichaTecnica>[])
        if (f.categoria.trim().isNotEmpty) f.categoria.trim(),
    }.toList()..sort();
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
      // os campos rolam; o botão Guardar fica sempre à vista por baixo
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
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
                      decoration: const InputDecoration(
                        labelText: 'Nome do produto *',
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Obrigatório'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _categoria,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Categoria (opcional)',
                        helperText: 'Escreve uma nova ou toca numa já usada.',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (categoriasUsadas.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 0,
                          children: [
                            for (final c in categoriasUsadas)
                              ChoiceChip(
                                label: Text(c),
                                selected: _categoria.text.trim() == c,
                                onSelected: (_) => setState(
                                  () => _categoria.text =
                                      _categoria.text.trim() == c ? '' : c,
                                ),
                              ),
                          ],
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
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: valor,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Formato do cookie (opcional)',
                              helperText:
                                  'Mini, Recheado, Simples… define o peso por '
                                  'unidade. Se não existe, cria-o aqui.',
                              helperMaxLines: 2,
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('Sem formato'),
                              ),
                              for (final f in visiveis)
                                DropdownMenuItem(
                                  value: f.id,
                                  child: Text(
                                    f.rotulo,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              const DropdownMenuItem(
                                value: _novoFormato,
                                child: Text('＋ Novo formato…'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v == _novoFormato) {
                                _criarFormato();
                              } else {
                                setState(() => _formatoId = v ?? '');
                              }
                            },
                          ),
                        ),
                        if (valor.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: IconButton(
                              tooltip: 'Editar ou apagar este formato',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _editarFormato(
                                visiveis.firstWhere((f) => f.id == valor),
                              ),
                            ),
                          ),
                      ],
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
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _validade,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Validade (dias)',
                        helperText: 'a contar da data de fabrico',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _assadura,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Tempo de assadura (minutos)',
                        helperText:
                            'Aparece na montagem do produto e no cronómetro do '
                            'forno.',
                        helperMaxLines: 2,
                      ),
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return null;
                        final n = int.tryParse(t);
                        return (n == null || n < 1 || n > 600)
                            ? 'Entre 1 e 600 minutos'
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _temperatura,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Temperatura do forno (°C)',
                        suffixText: '°C',
                        helperText:
                            'Aparece ao assar, junto com o tempo: "Assar a 170 °C '
                            'durante 11 min".',
                        helperMaxLines: 2,
                      ),
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return null;
                        final n = int.tryParse(t);
                        return (n == null || n < 50 || n > 400)
                            ? 'Entre 50 e 400 °C'
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey('conservacao-$_conservacaoSel'),
                      initialValue: _conservacaoSel,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Conservação',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('— escolher —'),
                        ),
                        for (final c in conservacoesPadrao)
                          DropdownMenuItem(value: c, child: Text(c)),
                        const DropdownMenuItem(
                          value: _outro,
                          child: Text('Outro…'),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _conservacaoSel = v ?? ''),
                    ),
                    if (_conservacaoSel == _outro)
                      TextFormField(
                        controller: _conservacao,
                        maxLength: 200,
                        decoration: const InputDecoration(
                          labelText: 'Modo de conservação',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _submit,
            child: Text(editar ? 'Guardar' : 'Criar'),
          ),
        ],
      ),
    );
  }
}
