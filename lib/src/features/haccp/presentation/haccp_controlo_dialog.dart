import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../invoices/domain/invoice_erros.dart';
import '../application/haccp_providers.dart';
import '../domain/haccp.dart';

const _periodicidades = <(int, String)>[
  (1, 'Todos os dias'),
  (7, 'Todas as semanas'),
  (14, 'De 15 em 15 dias'),
  (30, 'Todos os meses'),
  (90, 'Todos os trimestres'),
  (180, 'De 6 em 6 meses'),
  (365, 'Todos os anos'),
  (0, 'Ocasional (só quando for preciso)'),
];

/// Cria (ou edita, se [existente] vier preenchido) um controlo HACCP.
Future<void> showHaccpControloDialog(
  BuildContext context, {
  ControloHaccp? existente,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ControloDialog(existente: existente),
  );
}

class _ControloDialog extends ConsumerStatefulWidget {
  const _ControloDialog({this.existente});
  final ControloHaccp? existente;

  @override
  ConsumerState<_ControloDialog> createState() => _ControloDialogState();
}

class _ControloDialogState extends ConsumerState<_ControloDialog> {
  late final _nome = TextEditingController(text: widget.existente?.nome);
  late final _local = TextEditingController(text: widget.existente?.local);
  late final _instrucoes = TextEditingController(
    text: widget.existente?.instrucoes,
  );
  late final _min = TextEditingController(
    text: _txt(widget.existente?.limiteMin),
  );
  late final _max = TextEditingController(
    text: _txt(widget.existente?.limiteMax),
  );
  late final _vezes = TextEditingController(
    text: '${widget.existente?.vezesPorDia ?? 1}',
  );
  late TipoControlo _tipo = widget.existente?.tipo ?? TipoControlo.limpeza;
  late int _periodicidade = widget.existente?.periodicidadeDias ?? 1;
  bool _aGuardar = false;
  String? _erro;

  static String _txt(double? v) => v == null
      ? ''
      : (v == v.roundToDouble() ? '${v.toInt()}' : '$v').replaceAll('.', ',');

  @override
  void dispose() {
    _nome.dispose();
    _local.dispose();
    _instrucoes.dispose();
    _min.dispose();
    _max.dispose();
    _vezes.dispose();
    super.dispose();
  }

  double? _num(TextEditingController c) {
    final t = c.text.trim().replaceAll(',', '.');
    return t.isEmpty ? null : double.tryParse(t);
  }

  Future<void> _guardar() async {
    if (_nome.text.trim().isEmpty) {
      setState(() => _erro = 'Dá um nome ao controlo.');
      return;
    }
    final min = _tipo == TipoControlo.temperatura ? _num(_min) : null;
    final max = _tipo == TipoControlo.temperatura ? _num(_max) : null;
    if (min != null && max != null && min > max) {
      setState(() => _erro = 'O mínimo não pode ser maior que o máximo.');
      return;
    }
    final input = ControloInput(
      nome: _nome.text,
      tipo: _tipo,
      periodicidadeDias: _periodicidade,
      vezesPorDia: _periodicidade == 1
          ? (int.tryParse(_vezes.text.trim()) ?? 1).clamp(1, 12)
          : 1,
      limiteMin: min,
      limiteMax: max,
      unidade: _tipo == TipoControlo.temperatura ? '°C' : '',
      local: _local.text,
      instrucoes: _instrucoes.text,
      ordem: widget.existente?.ordem ?? 100,
    );
    setState(() {
      _aGuardar = true;
      _erro = null;
    });
    try {
      final acoes = ref.read(haccpActionsProvider);
      if (widget.existente == null) {
        await acoes.criarControlo(input);
      } else {
        await acoes.atualizarControlo(widget.existente!.id, input);
      }
      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _aGuardar = false;
        _erro = mensagemAmigavel(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.existente == null ? 'Novo controlo' : 'Editar controlo'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nome,
                autofocus: widget.existente == null,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'O que se controla',
                  hintText: 'Ex.: Temperatura do frigorífico',
                ),
              ),
              DropdownButtonFormField<TipoControlo>(
                initialValue: _tipo,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: [
                  for (final t in TipoControlo.values)
                    DropdownMenuItem(value: t, child: Text(t.label)),
                ],
                onChanged: (v) => setState(() => _tipo = v ?? _tipo),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _periodicidades.any((p) => p.$1 == _periodicidade)
                    ? _periodicidade
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Com que frequência'),
                items: [
                  for (final p in _periodicidades)
                    DropdownMenuItem(value: p.$1, child: Text(p.$2)),
                ],
                onChanged: (v) => setState(() => _periodicidade = v ?? 1),
              ),
              if (_periodicidade == 1)
                TextField(
                  controller: _vezes,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Registos por dia',
                    helperText: 'Ex.: 2 = de manhã e ao fim do dia.',
                  ),
                ),
              if (_tipo == TipoControlo.temperatura) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _min,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Mínimo (°C)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _max,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Máximo (°C)',
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Frigorífico: 0 a 5. Arca congeladora: só máximo -18. '
                    'Deixa em branco o limite que não existe.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
              TextField(
                controller: _local,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Local (opcional)',
                  hintText: 'Ex.: Cozinha, Loja',
                ),
              ),
              TextField(
                controller: _instrucoes,
                maxLength: 500,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Instruções (opcional)',
                  helperText: 'Aparecem quando se regista.',
                ),
              ),
              if (_erro != null)
                Text(_erro!, style: TextStyle(color: cs.error)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _aGuardar ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _aGuardar ? null : _guardar,
          child: Text(_aGuardar ? 'A guardar…' : 'Guardar'),
        ),
      ],
    );
  }
}
