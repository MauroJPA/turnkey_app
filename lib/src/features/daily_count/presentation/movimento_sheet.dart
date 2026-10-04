import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../invoices/domain/invoice_erros.dart';
import '../../tech_sheets/application/tech_sheets_providers.dart';
import '../application/contagem_providers.dart';
import '../domain/local.dart';
import '../domain/movimento_produto.dart';

/// Regista assados, um envio/devolução para outro local ou desperdício.
Future<void> showMovimentoSheet(
  BuildContext context, {
  required Local local,
  required List<Local> locais,
  required DateTime dia,
  TipoMovimento tipo = TipoMovimento.producao,
  String? fichaId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => _Sheet(
      local: local,
      locais: locais,
      dia: dia,
      tipoInicial: tipo,
      fichaInicial: fichaId,
    ),
  );
}

String _dmy(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class _Sheet extends ConsumerStatefulWidget {
  const _Sheet({
    required this.local,
    required this.locais,
    required this.dia,
    required this.tipoInicial,
    this.fichaInicial,
  });

  final Local local;
  final List<Local> locais;
  final DateTime dia;
  final TipoMovimento tipoInicial;
  final String? fichaInicial;

  @override
  ConsumerState<_Sheet> createState() => _SheetState();
}

class _SheetState extends ConsumerState<_Sheet> {
  late TipoMovimento _tipo = widget.tipoInicial;
  late String? _fichaId = widget.fichaInicial;
  String? _destinoId;
  MotivoDesperdicio _motivo = MotivoDesperdicio.queimado;
  final _quantidade = TextEditingController(text: '1');
  final _notas = TextEditingController();
  bool _aGuardar = false;
  String? _erro;

  @override
  void dispose() {
    _quantidade.dispose();
    _notas.dispose();
    super.dispose();
  }

  double get _qtd =>
      double.tryParse(_quantidade.text.trim().replaceAll(',', '.')) ?? 0;

  void _mudar(double delta) {
    final novo = (_qtd + delta).clamp(0, 100000).toDouble();
    setState(() {
      _quantidade.text = novo == novo.roundToDouble()
          ? '${novo.toInt()}'
          : '$novo';
    });
  }

  List<Local> get _outros => [
    for (final l in widget.locais)
      if (l.id != widget.local.id) l,
  ];

  Future<void> _guardar() async {
    if (_fichaId == null) {
      setState(() => _erro = 'Escolhe o sabor.');
      return;
    }
    if (_qtd <= 0) {
      setState(() => _erro = 'A quantidade tem de ser maior que zero.');
      return;
    }
    if (_tipo == TipoMovimento.transferencia && _destinoId == null) {
      setState(() => _erro = 'Escolhe para onde vão.');
      return;
    }
    setState(() {
      _aGuardar = true;
      _erro = null;
    });
    try {
      await ref
          .read(contagemActionsProvider)
          .adicionar(
            data: widget.dia,
            localId: widget.local.id,
            fichaId: _fichaId!,
            tipo: _tipo,
            quantidade: _qtd,
            destinoId: _tipo == TipoMovimento.transferencia ? _destinoId : null,
            motivo: _tipo == TipoMovimento.desperdicio ? _motivo : null,
            notas: _notas.text,
          );
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
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final fichas = ref.watch(fichasListProvider(false)).valueOrNull ?? const [];

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Registar — ${widget.local.nome}', style: tt.titleLarge),
            Text(_dmy(widget.dia), style: tt.bodySmall),
            const SizedBox(height: 12),
            SegmentedButton<TipoMovimento>(
              showSelectedIcon: false,
              segments: [
                const ButtonSegment(
                  value: TipoMovimento.producao,
                  label: Text('Assados'),
                  icon: Icon(Icons.local_fire_department_outlined),
                ),
                ButtonSegment(
                  value: TipoMovimento.transferencia,
                  label: const Text('Enviar'),
                  icon: const Icon(Icons.swap_horiz),
                  enabled: _outros.isNotEmpty,
                ),
                const ButtonSegment(
                  value: TipoMovimento.desperdicio,
                  label: Text('Desperdício'),
                  icon: Icon(Icons.delete_outline),
                ),
              ],
              selected: {_tipo},
              onSelectionChanged: (s) => setState(() => _tipo = s.first),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _fichaId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Sabor'),
              items: [
                for (final f in fichas)
                  DropdownMenuItem(value: f.id, child: Text(f.nome)),
              ],
              onChanged: _aGuardar ? null : (v) => setState(() => _fichaId = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: _aGuardar ? null : () => _mudar(-1),
                  icon: const Icon(Icons.remove),
                  tooltip: 'Menos 1',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _quantidade,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(labelText: 'Quantidade'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _aGuardar ? null : () => _mudar(1),
                  icon: const Icon(Icons.add),
                  tooltip: 'Mais 1',
                ),
                IconButton.filledTonal(
                  onPressed: _aGuardar ? null : () => _mudar(6),
                  icon: const Text('+6'),
                  tooltip: 'Mais 6',
                ),
              ],
            ),
            if (_tipo == TipoMovimento.transferencia) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _destinoId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Enviar de ${widget.local.nome} para…',
                  helperText:
                      'Também serve para devolver (ex.: de Alvalade para a Loja).',
                ),
                items: [
                  for (final l in _outros)
                    DropdownMenuItem(value: l.id, child: Text(l.nome)),
                ],
                onChanged: _aGuardar
                    ? null
                    : (v) => setState(() => _destinoId = v),
              ),
            ],
            if (_tipo == TipoMovimento.desperdicio) ...[
              const SizedBox(height: 12),
              Text('Motivo', style: tt.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final m in MotivoDesperdicio.values)
                    ChoiceChip(
                      label: Text(m.label),
                      selected: _motivo == m,
                      onSelected: _aGuardar
                          ? null
                          : (_) => setState(() => _motivo = m),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _notas,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Notas (opcional)'),
            ),
            if (_erro != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_erro!, style: TextStyle(color: cs.error)),
              ),
            FilledButton.icon(
              onPressed: _aGuardar ? null : _guardar,
              icon: const Icon(Icons.check),
              label: Text(_aGuardar ? 'A guardar…' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
