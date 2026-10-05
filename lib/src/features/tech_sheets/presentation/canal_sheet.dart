import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/mensagem_amigavel.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../pricing/data/canal_venda_repository.dart';
import '../../pricing/domain/canal_venda.dart';

/// Cria ou edita um canal de venda (plataforma de entrega, revendedor…) com
/// as suas taxas em cascata. Devolve `true` se algo mudou.
Future<bool?> showCanalSheet(BuildContext context, {CanalVenda? existente}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => _CanalSheet(existente: existente),
  );
}

class _LinhaTaxa {
  _LinhaTaxa({String nome = '', double percent = 0, double fixo = 0})
    : nome = TextEditingController(text: nome),
      percent = TextEditingController(text: percent > 0 ? _n(percent) : ''),
      fixo = TextEditingController(text: fixo > 0 ? _n(fixo) : '');

  final TextEditingController nome;
  final TextEditingController percent;
  final TextEditingController fixo;

  static String _n(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  static double _v(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.').trim()) ?? 0;

  TaxaCanal toTaxa() => TaxaCanal(
    nome: nome.text.trim(),
    percent: _v(percent).clamp(0, 99.9).toDouble(),
    fixo: _v(fixo) < 0 ? 0 : _v(fixo),
  );

  void dispose() {
    nome.dispose();
    percent.dispose();
    fixo.dispose();
  }
}

class _CanalSheet extends ConsumerStatefulWidget {
  const _CanalSheet({this.existente});
  final CanalVenda? existente;

  @override
  ConsumerState<_CanalSheet> createState() => _CanalSheetState();
}

class _CanalSheetState extends ConsumerState<_CanalSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.existente?.nome ?? '');
  late final List<_LinhaTaxa> _linhas = [
    for (final t in widget.existente?.taxas ?? const <TaxaCanal>[])
      _LinhaTaxa(nome: t.nome, percent: t.percent, fixo: t.fixo),
  ];
  late bool _embalagem = widget.existente?.embalagemPlataforma ?? false;
  bool _aGuardar = false;
  String? _erro;

  @override
  void dispose() {
    _nome.dispose();
    for (final l in _linhas) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _aGuardar = true;
      _erro = null;
    });
    final taxas = [
      for (final l in _linhas)
        if (l.nome.text.trim().isNotEmpty ||
            l.percent.text.trim().isNotEmpty ||
            l.fixo.text.trim().isNotEmpty)
          l.toTaxa(),
    ];
    try {
      final repo = ref.read(canalVendaRepositoryProvider);
      if (widget.existente == null) {
        await repo.create(
          nome: _nome.text,
          taxas: taxas,
          embalagemPlataforma: _embalagem,
        );
      } else {
        await repo.update(
          widget.existente!.id,
          nome: _nome.text,
          taxas: taxas,
          embalagemPlataforma: _embalagem,
          ordem: widget.existente!.ordem,
        );
      }
      ref.invalidate(canaisVendaProvider);
      if (mounted) Navigator.pop(context, true);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _aGuardar = false;
        _erro = mensagemAmigavel(e);
      });
    }
  }

  Future<void> _apagar() async {
    final ok = await confirmDialog(
      context,
      titulo: 'Apagar canal?',
      mensagem: 'Remove "${widget.existente!.nome}" e as suas taxas.',
      confirmar: 'Apagar',
      destrutivo: true,
    );
    if (!ok) return;
    try {
      await ref.read(canalVendaRepositoryProvider).delete(widget.existente!.id);
      ref.invalidate(canaisVendaProvider);
      if (mounted) Navigator.pop(context, true);
    } on Object catch (e) {
      if (mounted) setState(() => _erro = mensagemAmigavel(e));
    }
  }

  void _mover(int i, int delta) {
    final j = i + delta;
    if (j < 0 || j >= _linhas.length) return;
    setState(() {
      final l = _linhas.removeAt(i);
      _linhas.insert(j, l);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
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
                editar ? 'Editar canal' : 'Novo canal de venda',
                style: tt.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Uma plataforma de entrega, um revendedor, um terceiro… Cada '
                'um pode ter as suas taxas.',
                style: tt.bodySmall,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nome,
                autofocus: !editar,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nome *',
                  hintText: 'Ex.: Uber Eats, Revendedor Alvalade',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 16),
              Text('Taxas em cascata', style: tt.titleSmall),
              const SizedBox(height: 2),
              Text(
                'Pela ordem em que cada uma tira a sua parte do que o cliente '
                'paga: a primeira é a de fora (ex.: a plataforma), a última é '
                'a mais perto de nós (ex.: o revendedor). Cada % é sobre o '
                'valor do seu nível. O "€ fixo" é por venda.',
                style: tt.bodySmall,
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < _linhas.length; i++)
                _CartaoTaxa(
                  key: ObjectKey(_linhas[i]),
                  linha: _linhas[i],
                  indice: i,
                  total: _linhas.length,
                  onCima: () => _mover(i, -1),
                  onBaixo: () => _mover(i, 1),
                  onRemover: () => setState(() {
                    _linhas.removeAt(i).dispose();
                  }),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _linhas.add(_LinhaTaxa())),
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar taxa'),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Usa a embalagem para plataformas'),
                subtitle: const Text(
                  'Soma ao custo a "Embalagem para plataformas" da ficha.',
                ),
                value: _embalagem,
                onChanged: (v) => setState(() => _embalagem = v),
              ),
              if (_erro != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_erro!, style: TextStyle(color: cs.error)),
                ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _aGuardar ? null : _guardar,
                child: Text(_aGuardar ? 'A guardar…' : 'Guardar'),
              ),
              if (editar)
                TextButton.icon(
                  onPressed: _aGuardar ? null : _apagar,
                  icon: Icon(Icons.delete_outline, color: cs.error),
                  label: Text(
                    'Apagar canal',
                    style: TextStyle(color: cs.error),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartaoTaxa extends StatelessWidget {
  const _CartaoTaxa({
    super.key,
    required this.linha,
    required this.indice,
    required this.total,
    required this.onCima,
    required this.onBaixo,
    required this.onRemover,
  });

  final _LinhaTaxa linha;
  final int indice;
  final int total;
  final VoidCallback onCima;
  final VoidCallback onBaixo;
  final VoidCallback onRemover;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                TextField(
                  controller: linha.nome,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: '${indice + 1}.ª taxa — nome',
                    hintText: 'Ex.: Plataforma, Revendedor',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: linha.percent,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: '% do preço',
                          suffixText: '%',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: linha.fixo,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: '€ fixo/venda',
                          suffixText: '€',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                tooltip: 'Subir (mais de fora)',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.keyboard_arrow_up),
                onPressed: indice > 0 ? onCima : null,
              ),
              IconButton(
                tooltip: 'Descer (mais perto de nós)',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.keyboard_arrow_down),
                onPressed: indice < total - 1 ? onBaixo : null,
              ),
              IconButton(
                tooltip: 'Remover taxa',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close, color: cs.error),
                onPressed: onRemover,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
