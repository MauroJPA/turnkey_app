import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../invoices/domain/invoice_erros.dart';
import '../../tech_sheets/domain/tech_sheet.dart';
import '../application/contagem_providers.dart';
import '../domain/contagem_dia.dart';
import '../domain/local.dart';
import '../domain/movimento_produto.dart';

/// Contagem de todos os sabores de uma vez: de abertura (início do dia) ou de
/// fecho (o que sobrou). Os campos em branco ficam como estão.
Future<void> showContagemRapidaSheet(
  BuildContext context, {
  required Local local,
  required DateTime dia,
  required TipoMovimento tipo,
  required List<FichaTecnica> fichas,
  required List<LinhaContagem> linhas,
}) {
  assert(tipo.eContagem);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => _Sheet(
      local: local,
      dia: dia,
      tipo: tipo,
      fichas: fichas,
      linhas: {for (final l in linhas) l.fichaId: l},
    ),
  );
}

class _Sheet extends ConsumerStatefulWidget {
  const _Sheet({
    required this.local,
    required this.dia,
    required this.tipo,
    required this.fichas,
    required this.linhas,
  });

  final Local local;
  final DateTime dia;
  final TipoMovimento tipo;
  final List<FichaTecnica> fichas;
  final Map<String, LinhaContagem> linhas;

  @override
  ConsumerState<_Sheet> createState() => _SheetState();
}

String _n(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

class _SheetState extends ConsumerState<_Sheet> {
  late final Map<String, TextEditingController> _ctrl;
  bool _aGuardar = false;
  String? _erro;

  bool get _fecho => widget.tipo == TipoMovimento.contagemFecho;

  @override
  void initState() {
    super.initState();
    _ctrl = {
      for (final f in widget.fichas)
        f.id: TextEditingController(text: _inicial(widget.linhas[f.id])),
    };
  }

  /// O que já foi contado nesse dia (para corrigir), senão em branco.
  String _inicial(LinhaContagem? l) {
    if (l == null) return '';
    if (_fecho) return l.fecho == null ? '' : _n(l.fecho!);
    return l.aberturaContada ? _n(l.abertura) : '';
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    final valores = <String, double>{};
    for (final e in _ctrl.entries) {
      final t = e.value.text.trim().replaceAll(',', '.');
      if (t.isEmpty) continue;
      final v = double.tryParse(t);
      if (v == null || v < 0) {
        setState(() => _erro = 'Há uma quantidade inválida.');
        return;
      }
      valores[e.key] = v;
    }
    if (valores.isEmpty) {
      setState(() => _erro = 'Não preencheste nenhuma quantidade.');
      return;
    }
    setState(() {
      _aGuardar = true;
      _erro = null;
    });
    try {
      await ref
          .read(contagemActionsProvider)
          .guardarContagens(
            tipo: widget.tipo,
            data: widget.dia,
            localId: widget.local.id,
            porFicha: valores,
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

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _fecho
                  ? 'Contagem de fecho — ${widget.local.nome}'
                  : 'Contagem de abertura — ${widget.local.nome}',
              style: tt.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              _fecho
                  ? 'Conta o que sobrou no fim do dia. O número pequeno é o '
                        'que devia haver pelas contas.'
                  : 'Conta o que há ao abrir. O número pequeno é o que ficou '
                        'da contagem de fecho anterior.',
              style: tt.bodySmall,
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final f in widget.fichas)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(f.nome, style: tt.bodyLarge),
                                if (widget.linhas[f.id] case final l?)
                                  Text(
                                    _fecho
                                        ? 'devia haver ${_n(l.esperado)}'
                                        : l.fechoAnterior == null
                                        ? 'sem fecho anterior'
                                        : 'fecho anterior ${_n(l.fechoAnterior!)}',
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 96,
                            child: TextField(
                              controller: _ctrl[f.id],
                              textAlign: TextAlign.center,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                isDense: true,
                                hintText: '—',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (_erro != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_erro!, style: TextStyle(color: cs.error)),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _aGuardar ? null : _guardar,
              icon: const Icon(Icons.check),
              label: Text(_aGuardar ? 'A guardar…' : 'Guardar contagem'),
            ),
          ],
        ),
      ),
    );
  }
}
