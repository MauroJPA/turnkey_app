import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/formatting/money_provider.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../cookie_formats/application/cookie_format_providers.dart';
import '../../cookie_formats/domain/cookie_format.dart';
import '../../recipes/domain/recipe.dart';
import '../../recipes/presentation/recipe_picker_sheet.dart';
import '../../schedule/domain/production_plan.dart';
import '../application/agenda_cart.dart';
import '../application/production_providers.dart';
import '../domain/production.dart';

class ProductionScreen extends ConsumerStatefulWidget {
  const ProductionScreen({super.key});

  @override
  ConsumerState<ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends ConsumerState<ProductionScreen> {
  Receita? _receita;
  final _kg = TextEditingController();

  @override
  void dispose() {
    _kg.dispose();
    super.dispose();
  }

  double get _alvoG {
    final kg = double.tryParse(_kg.text.replaceAll(',', '.').trim()) ?? 0;
    return kg * 1000;
  }

  Future<void> _escolher() async {
    final r = await showRecipePickerSheet(context);
    if (r != null) setState(() => _receita = r);
  }

  Future<void> _adicionarAgenda() async {
    final receita = _receita;
    if (receita == null) return;
    final kg = double.tryParse(_kg.text.replaceAll(',', '.').trim()) ?? 0;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AgendaLinhaSheet(receita: receita, kgInicial: kg),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = ref.watch(moneyFormatProvider);
    final pronto = _receita != null && _alvoG > 0;
    final carrinho = ref.watch(agendaCartProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
        title: const Text('Produzir'),
      ),
      floatingActionButton: pronto
          ? FloatingActionButton.extended(
              onPressed: _adicionarAgenda,
              icon: const Icon(Icons.event_note_outlined),
              label: const Text('Adicionar à agenda'),
            )
          : null,
      bottomNavigationBar: carrinho.isEmpty
          ? null
          : SafeArea(
              child: Material(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: InkWell(
                  onTap: () => context.go('${Routes.production}/agendar'),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Row(
                      children: [
                        const Icon(Icons.shopping_basket_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${carrinho.length} '
                            '${carrinho.length == 1 ? 'receita' : 'receitas'} '
                            'para agendar',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Text('Rever e agendar'),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text(_receita?.nome ?? 'Escolher produto'),
              subtitle: _receita == null
                  ? const Text('Receita de fabrico próprio')
                  : Text(
                      '${_receita!.categoria.label} · rendimento base '
                      '${_receita!.rendimentoEsperado.toStringAsFixed(0)} g',
                    ),
              trailing: const Icon(Icons.expand_more),
              onTap: _escolher,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _kg,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Quantidade a produzir',
              suffixText: 'kg',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          if (!pronto)
            const Padding(
              padding: EdgeInsets.only(top: 32),
              child: Center(
                child: Text('Escolhe um produto e indica os kg.'),
              ),
            )
          else
            AsyncValueView<ProductionNode>(
              value: ref.watch(
                productionProvider(
                  (recipeId: _receita!.id, alvoG: _alvoG),
                ),
              ),
              onRetry: () => ref.invalidate(
                productionProvider(
                  (recipeId: _receita!.id, alvoG: _alvoG),
                ),
              ),
              data: (node) => _NodeView(node: node, fmt: fmt, nivel: 0),
            ),
        ],
      ),
    );
  }
}

class _NodeView extends StatelessWidget {
  const _NodeView({
    required this.node,
    required this.fmt,
    required this.nivel,
  });

  final ProductionNode node;
  final MoneyFmt fmt;
  final int nivel;

  String _g(double g) => g >= 1000
      ? '${(g / 1000).toStringAsFixed(3)} kg'
      : '${g.toStringAsFixed(g < 10 ? 1 : 0)} g';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: EdgeInsets.only(left: nivel * 12.0, top: nivel == 0 ? 0 : 8),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  node.nome,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: scheme.primary),
                ),
                const SizedBox(height: 2),
                if (node.ciclo)
                  Text(
                    'Sub-receita em ciclo — não expandida.',
                    style: TextStyle(color: scheme.error),
                  )
                else if (node.semRendimento)
                  Text(
                    'Sem rendimento definido — não é possível escalar.',
                    style: TextStyle(color: scheme.error),
                  )
                else
                  Text(
                    'Produzir ${_g(node.alvoG)}  ·  '
                    '×${node.fator.toStringAsFixed(3)}  ·  '
                    'base ${_g(node.rendimentoBase)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          if (!node.ciclo && !node.semRendimento) ...[
            for (final l in node.linhas)
              ListTile(
                dense: true,
                title: Text(
                  l.nome,
                  style: l.pendente
                      ? TextStyle(color: scheme.error)
                      : null,
                ),
                trailing: Text(
                  _g(l.quantidadeG),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: l.pendente
                    ? const Text('vínculo pendente')
                    : Text(fmt(l.custo)),
              ),
            for (final sub in node.subReceitas)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: _NodeView(node: sub, fmt: fmt, nivel: nivel + 1),
              ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total ${node.nome}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    fmt(node.custoTotal),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Folha para configurar uma linha do carrinho da agenda.
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

  void _confirmar() {
    final formato = _formato;
    if (formato == null || _kgValor <= 0) return;
    if (formato.temRecheio && _recheio == null) {
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
            recheioId: formato.temRecheio ? _recheio!.id : null,
            recheioNome: formato.temRecheio ? _recheio!.nome : null,
            prioridade: _prioridade,
            horaLimite: _horaTexto,
          ),
        );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final formatosAsync = ref.watch(formatosAtivosProvider);

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
              _formato ??= formatos.isNotEmpty ? formatos.first : null;
              return DropdownButtonFormField<FormatoCookie>(
                value: _formato,
                decoration: const InputDecoration(labelText: 'Formato'),
                items: [
                  for (final f in formatos)
                    DropdownMenuItem(value: f, child: Text(f.rotulo)),
                ],
                onChanged: (f) => setState(() {
                  _formato = f;
                  if (f != null && !f.temRecheio) _recheio = null;
                }),
              );
            },
          ),
          if (_formato?.temRecheio ?? false) ...[
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cake_outlined),
              title: Text(_recheio?.nome ?? 'Escolher recheio'),
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
            onPressed:
                (_formato != null && _kgValor > 0) ? _confirmar : null,
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }
}
