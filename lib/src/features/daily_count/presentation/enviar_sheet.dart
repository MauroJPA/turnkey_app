import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/quantidade_stepper.dart';
import '../../invoices/domain/invoice_erros.dart';
import '../../tech_sheets/application/tech_sheets_providers.dart';
import '../application/contagem_providers.dart';
import '../domain/local.dart';
import '../domain/movimento_produto.dart';

/// Envia cookies de um local para outro (ex.: da Loja para Alvalade) ou
/// devolve-os (de Alvalade para a Loja): sai de [local] e entra no destino.
Future<void> showEnviarSheet(
  BuildContext context, {
  required Local local,
  required List<Local> locais,
  required DateTime dia,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => _Sheet(local: local, locais: locais, dia: dia),
  );
}

String _dmy(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class _Sheet extends ConsumerStatefulWidget {
  const _Sheet({required this.local, required this.locais, required this.dia});

  final Local local;
  final List<Local> locais;
  final DateTime dia;

  @override
  ConsumerState<_Sheet> createState() => _SheetState();
}

class _SheetState extends ConsumerState<_Sheet> {
  String? _fichaId;
  String? _destinoId;
  double _quantidade = 1;
  final _notas = TextEditingController();
  bool _aGuardar = false;
  String? _erro;

  @override
  void dispose() {
    _notas.dispose();
    super.dispose();
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
    if (_quantidade <= 0) {
      setState(() => _erro = 'A quantidade tem de ser maior que zero.');
      return;
    }
    if (_destinoId == null) {
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
            tipo: TipoMovimento.transferencia,
            quantidade: _quantidade,
            destinoId: _destinoId,
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
    final fichas = [
      for (final f
          in ref.watch(fichasListProvider(false)).valueOrNull ?? const [])
        if (!f.revenda) f,
    ];

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
            Text(
              'Enviar / devolver — ${widget.local.nome}',
              style: tt.titleLarge,
            ),
            Text(_dmy(widget.dia), style: tt.bodySmall),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _destinoId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Enviar de ${widget.local.nome} para…',
                helperText:
                    'Também serve para devolver (ex.: de Alvalade para a Loja).',
                helperMaxLines: 2,
              ),
              items: [
                for (final l in _outros)
                  DropdownMenuItem(value: l.id, child: Text(l.nome)),
              ],
              onChanged: _aGuardar
                  ? null
                  : (v) => setState(() => _destinoId = v),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Quantidade', style: tt.bodyLarge),
                QuantidadeStepper(
                  valor: _quantidade,
                  min: 1,
                  onChanged: (v) => setState(() => _quantidade = v),
                ),
              ],
            ),
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
