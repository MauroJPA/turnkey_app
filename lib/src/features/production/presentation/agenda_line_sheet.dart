import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cookie_formats/application/cookie_format_providers.dart';
import '../../cookie_formats/domain/cookie_format.dart';
import '../../recipes/domain/recipe.dart';
import '../../recipes/presentation/recipe_picker_sheet.dart';
import '../../schedule/application/schedule_providers.dart';
import '../../schedule/domain/production_plan.dart';
import '../application/agenda_cart.dart';

/// Abre a folha "Adicionar à agenda" para uma receita e junta a linha ao
/// carrinho de produção (`agendaCartProvider`).
Future<void> showAgendaLineSheet(
  BuildContext context, {
  required Receita receita,
  double kgInicial = 0,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AgendaLinhaSheet(receita: receita, kgInicial: kgInicial),
  );
}

class _AgendaLinhaSheet extends ConsumerStatefulWidget {
  const _AgendaLinhaSheet({required this.receita, required this.kgInicial});

  final Receita receita;
  final double kgInicial;

  @override
  ConsumerState<_AgendaLinhaSheet> createState() => _AgendaLinhaSheetState();
}

class _AgendaLinhaSheetState extends ConsumerState<_AgendaLinhaSheet> {
  late final _kg = TextEditingController(
    text: widget.kgInicial > 0 ? _fmtKg(widget.kgInicial) : '',
  );
  FormatoCookie? _formato;
  bool _formatoEscolhido = false;
  Receita? _recheio;
  Prioridade _prioridade = Prioridade.media;
  TimeOfDay? _hora;

  static String _fmtKg(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    _kg.dispose();
    super.dispose();
  }

  double get _kgValor =>
      double.tryParse(_kg.text.replaceAll(',', '.').trim()) ?? 0;

  String get _horaTexto => _hora == null
      ? ''
      : '${_hora!.hour.toString().padLeft(2, '0')}:'
          '${_hora!.minute.toString().padLeft(2, '0')}';

  Future<void> _escolherRecheio() async {
    final r = await showRecipePickerSheet(
      context,
      soFabricoProprio: false,
      categoria: CategoriaReceita.recheio,
    );
    if (r != null) setState(() => _recheio = r);
  }

  bool _temFicha = false;

  void _confirmar() {
    final formato = _formato;
    if (formato == null || _kgValor <= 0) return;
    if (formato.temRecheio && !_temFicha && _recheio == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolhe o recheio deste formato.')),
      );
      return;
    }
    ref.read(agendaCartProvider.notifier).adicionar(
          CartLinha(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            receitaId: widget.receita.id,
            receitaNome: widget.receita.nome,
            kg: _kgValor,
            formatoId: formato.id,
            formatoNome: formato.nome,
            unidadesPrevistas: formato.unidades(_kgValor),
            recheioId: _recheio?.id,
            recheioNome: _recheio?.nome,
            prioridade: _prioridade,
            horaLimite: _horaTexto,
          ),
        );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Adicionado ao carrinho de produção.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatosAsync = ref.watch(formatosAtivosProvider);
    final sugerido =
        ref.watch(formatoSugeridoProvider(widget.receita.id)).valueOrNull;

    // Ficha técnica correspondente (recheio/coberturas automáticos).
    final ficha = _formato == null
        ? null
        : ref
            .watch(fichaResolvidaProvider((
              massaId: widget.receita.id,
              formatoId: _formato!.id,
              recheioId: _recheio?.id,
            )))
            .valueOrNull;
    final temFicha = ficha?.existe ?? false;
    _temFicha = temFicha;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.receita.nome,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Adicionar à agenda',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          formatosAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (formatos) {
              if (!_formatoEscolhido && formatos.isNotEmpty) {
                _formato = formatos.firstWhere(
                  (f) => f.id == sugerido,
                  orElse: () => formatos.first,
                );
              }
              return DropdownButtonFormField<FormatoCookie>(
                value: _formato,
                decoration: InputDecoration(
                  labelText: 'Formato',
                  helperText: (_formato != null && _formato!.id == sugerido)
                      ? 'O mais usado nesta receita'
                      : null,
                ),
                items: [
                  for (final f in formatos)
                    DropdownMenuItem(value: f, child: Text(f.rotulo)),
                ],
                onChanged: (f) => setState(() {
                  _formato = f;
                  _formatoEscolhido = true;
                  if (f != null && !f.temRecheio) _recheio = null;
                }),
              );
            },
          ),
          if (temFicha) ...[
            const SizedBox(height: 8),
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Ficha técnica: ${ficha!.nome}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (ficha.componentes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('Só massa.'),
                      )
                    else
                      for (final c in ficha.componentes)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '• ${c.slotLabel}: ${c.nome} '
                            '(${c.gPorUnidade.toStringAsFixed(0)} g/un)',
                          ),
                        ),
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Recheios e coberturas são usados automaticamente.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (_formato?.temRecheio ?? false) ...[
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cake_outlined),
              title: Text(_recheio?.nome ?? 'Escolher recheio'),
              subtitle: const Text('Sem ficha técnica para esta massa'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _escolherRecheio,
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _kg,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Massa a produzir',
              suffixText: 'kg',
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_formato != null && _kgValor > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '≈ ${_formato!.unidades(_kgValor)} unidades'
                '${_formato!.temRecheio ? ' · recheio '
                    '${(_formato!.unidades(_kgValor) * _formato!.recheioG / 1000).toStringAsFixed(2)} kg' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 16),
          Text('Prioridade', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          SegmentedButton<Prioridade>(
            segments: const [
              ButtonSegment(value: Prioridade.alta, label: Text('Alta')),
              ButtonSegment(value: Prioridade.media, label: Text('Média')),
              ButtonSegment(value: Prioridade.baixa, label: Text('Baixa')),
            ],
            selected: {_prioridade},
            onSelectionChanged: (s) => setState(() => _prioridade = s.first),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: Text(
              _hora == null ? 'Hora limite (opcional)' : 'Pronto até $_horaTexto',
            ),
            trailing: _hora == null
                ? const Icon(Icons.chevron_right)
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _hora = null),
                  ),
            onTap: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: _hora ?? const TimeOfDay(hour: 14, minute: 0),
              );
              if (t != null) setState(() => _hora = t);
            },
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: (_formato != null && _kgValor > 0) ? _confirmar : null,
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }
}
