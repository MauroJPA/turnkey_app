import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/errors/mensagem_amigavel.dart';
import '../../../core/formatting/money_provider.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/help_actions.dart';
import '../../mise_en_place/application/mep_providers.dart';
import '../../mise_en_place/domain/mep_plano.dart';
import '../../mise_en_place/presentation/mep_plano_view.dart';
import '../../recipes/domain/recipe.dart';
import '../../tech_sheets/domain/tech_sheet.dart';
import '../application/agenda_cart.dart';
import '../application/production_providers.dart';
import '../domain/production.dart';
import 'agenda_ficha_sheet.dart';
import 'agenda_line_sheet.dart';
import 'produto_picker_sheet.dart';

class ProductionScreen extends ConsumerStatefulWidget {
  const ProductionScreen({super.key});

  @override
  ConsumerState<ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends ConsumerState<ProductionScreen> {
  Receita? _receita;
  FichaTecnica? _ficha;
  final _kg = TextEditingController();
  final _feitos = <String>{};

  @override
  void dispose() {
    _kg.dispose();
    super.dispose();
  }

  double get _alvoG {
    final kg = double.tryParse(_kg.text.replaceAll(',', '.').trim()) ?? 0;
    return kg * 1000;
  }

  int get _unidades => int.tryParse(_kg.text.trim()) ?? 0;

  MepFichaArgs? get _fichaArgs {
    final f = _ficha;
    if (f == null || _unidades <= 0) return null;
    return (fichaId: f.id, unidades: _unidades);
  }

  Future<void> _escolher() async {
    // Produtos finais (fichas técnicas) ou receitas (massa, recheio, base).
    final p = await showProdutoPickerSheet(context);
    if (p == null) return;
    setState(() {
      _feitos.clear();
      _kg.clear();
      switch (p) {
        case ProdutoFicha(:final ficha):
          _ficha = ficha;
          _receita = null;
        case ProdutoReceita(:final receita):
          _receita = receita;
          _ficha = null;
      }
    });
  }

  Future<void> _adicionarAgenda() async {
    final args = _fichaArgs;
    if (args != null) {
      try {
        final plano = await ref.read(mepPlanoFichaProvider(args).future);
        if (mounted) await showAgendaFichaSheet(context, plano);
      } on Object catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
        }
      }
      return;
    }
    final receita = _receita;
    if (receita == null) return;
    final kg = double.tryParse(_kg.text.replaceAll(',', '.').trim()) ?? 0;
    await showAgendaLineSheet(context, receita: receita, kgInicial: kg);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = ref.watch(moneyFormatProvider);
    final pronto = _fichaArgs != null || (_receita != null && _alvoG > 0);
    final carrinho = ref.watch(agendaCartProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
        title: const Text('Produzir'),
        actions: const [HelpActions(topic: HelpTopic.produzir)],
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
              title: Text(_ficha?.nome ?? _receita?.nome ?? 'Escolher produto'),
              subtitle: _ficha != null
                  ? const Text('Produto final (ficha técnica)')
                  : _receita == null
                      ? const Text('Produto final ou receita')
                      : Text(
                          '${_receita!.categoria} · rendimento base '
                          '${_receita!.rendimentoEsperado.toStringAsFixed(0)} g',
                        ),
              trailing: const Icon(Icons.expand_more),
              onTap: _escolher,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _kg,
            keyboardType: _ficha != null
                ? TextInputType.number
                : const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _ficha != null
                  ? 'Unidades a produzir'
                  : 'Quantidade a produzir',
              suffixText: _ficha != null ? 'un' : 'kg',
            ),
            onChanged: (_) => setState(_feitos.clear),
          ),
          const SizedBox(height: 16),
          if (!pronto)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Center(
                child: Text(
                  _ficha != null
                      ? 'Indica quantas unidades queres produzir.'
                      : 'Escolhe um produto e indica a quantidade.',
                ),
              ),
            )
          else if (_fichaArgs != null)
            AsyncValueView<MepPlano>(
              value: ref.watch(mepPlanoFichaProvider(_fichaArgs!)),
              onRetry: () => ref.invalidate(mepPlanoFichaProvider(_fichaArgs!)),
              data: (plano) => MepPlanoView(
                plano: plano,
                feitos: _feitos,
                mostrarProduzir: false,
                onToggle: (id, v) => setState(() {
                  v ? _feitos.add(id) : _feitos.remove(id);
                }),
                onAbrirIntermedio: (it) =>
                    context.push('${Routes.miseEnPlace}?receita=${it.receitaId}'),
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
                    'Receita sem ingredientes — não é possível escalar.',
                    style: TextStyle(color: scheme.error),
                  )
                else
                  Text(
                    'Produzir ${_g(node.alvoG)}  ·  '
                    '×${node.fator.toStringAsFixed(3)}  ·  '
                    'mistura base ${_g(node.rendimentoBase)}',
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
