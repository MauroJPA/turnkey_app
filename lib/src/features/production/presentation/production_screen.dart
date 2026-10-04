import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/errors/mensagem_amigavel.dart';
import '../../../core/formatting/money_provider.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/help_actions.dart';
import '../../cookie_formats/application/cookie_format_providers.dart';
import '../../cookie_formats/domain/cookie_format.dart';
import '../../mise_en_place/application/mep_providers.dart';
import '../../mise_en_place/data/mep_repository.dart';
import '../../mise_en_place/domain/mep_plano.dart';
import '../../mise_en_place/presentation/mep_plano_view.dart';
import '../../recipes/data/recipe_repository.dart';
import '../../recipes/domain/recipe.dart';
import '../../recipes/presentation/procedimento_sheet.dart';
import '../../tech_sheets/domain/tech_sheet.dart';
import '../application/agenda_cart.dart';
import '../application/production_providers.dart';
import '../domain/production.dart';
import 'agenda_ficha_sheet.dart';
import 'agenda_line_sheet.dart';
import 'produto_picker_sheet.dart';

/// Produzir: escolhe o produto (ficha técnica ou receita) e a quantidade; vê o
/// mise en place (o que produzir primeiro e os ingredientes a pesar, com
/// caixas para ir marcando) e o custo; e depois **regista a produção agora**
/// ou **agenda-a** para outro dia. (Junta o antigo "Produzir" e o "Mise en
/// place".)
class ProductionScreen extends ConsumerStatefulWidget {
  const ProductionScreen({
    super.key,
    this.receitaId,
    this.kgInicial,
    this.embedded = false,
  });

  /// Abre já com esta receita escolhida (ex.: "Abrir" num intermédio).
  final String? receitaId;
  final double? kgInicial;

  /// Dentro da página Produção: sem barra própria.
  final bool embedded;

  @override
  ConsumerState<ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends ConsumerState<ProductionScreen> {
  Receita? _receita;
  FichaTecnica? _ficha;
  late final _kg = TextEditingController(
    text: (widget.kgInicial ?? 0) > 0
        ? widget.kgInicial!.toStringAsFixed(2)
        : '',
  );
  FormatoCookie? _formato;
  final _feitos = <String>{};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.receitaId != null) {
      Future.microtask(() async {
        try {
          final r = await ref
              .read(recipeRepositoryProvider)
              .getById(widget.receitaId!);
          if (mounted) setState(() => _receita = r);
        } on Object {
          // receita apagada ou sem acesso: fica o ecrã vazio para escolher
        }
      });
    }
  }

  @override
  void dispose() {
    _kg.dispose();
    super.dispose();
  }

  double get _kgValor =>
      double.tryParse(_kg.text.replaceAll(',', '.').trim()) ?? 0;

  double get _alvoG => _kgValor * 1000;

  int get _unidades => int.tryParse(_kg.text.trim()) ?? 0;

  MepArgs? get _args {
    final r = _receita;
    if (r == null || _kgValor <= 0) return null;
    return (
      receitaId: r.id,
      kg: _kgValor,
      formatoId: _formato?.id,
      recheioId: null,
    );
  }

  MepFichaArgs? get _fichaArgs {
    final f = _ficha;
    if (f == null || _unidades <= 0) return null;
    return (fichaId: f.id, unidades: _unidades);
  }

  void _reset() => setState(_feitos.clear);

  Future<void> _escolher() async {
    // Produtos finais (fichas técnicas) ou receitas (massa, recheio, base).
    final p = await showProdutoPickerSheet(context);
    if (p == null) return;
    setState(() {
      _feitos.clear();
      _kg.clear();
      _formato = null;
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

  void _toggle(String id, bool v) => setState(() {
    if (v) {
      _feitos.add(id);
    } else {
      _feitos.remove(id);
    }
  });

  void _abrirIntermedio(MepIntermedio it) {
    context.push('${Routes.production}?receita=${it.receitaId}');
  }

  Future<void> _adicionarAgenda() async {
    final args = _fichaArgs;
    if (args != null) {
      try {
        final plano = await ref.read(mepPlanoFichaProvider(args).future);
        if (mounted) await showAgendaFichaSheet(context, plano);
      } on Object catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
        }
      }
      return;
    }
    final receita = _receita;
    if (receita == null) return;
    await showAgendaLineSheet(context, receita: receita, kgInicial: _kgValor);
  }

  /// Regista a produção feita agora: dá baixa no stock, guarda na agenda como
  /// concluída e (se faltou algo) pode juntar o que falta à lista de compras.
  Future<void> _produzir(MepPlano plano) async {
    final router = GoRouter.of(context);
    final totalItems = plano.comprar.length + plano.intermedios.length;
    if (_feitos.length < totalItems) {
      final ok = await confirmDialog(
        context,
        titulo: 'Ainda há itens por marcar',
        mensagem:
            'Marcaste ${_feitos.length} de $totalItems. '
            'Queres registar a produção na mesma?',
        confirmar: 'Continuar',
      );
      if (!ok || !mounted) return;
    }

    final ok1 = await confirmDialog(
      context,
      titulo: 'Registar produção?',
      mensagem:
          'Guarda na Agenda como concluída e dá baixa no stock dos ingredientes '
          'e intermédios usados.',
      confirmar: 'Sim, registar',
    );
    if (!ok1 || !mounted) return;

    var gerarCompras = false;
    if (plano.comprar.any((c) => c.faltaStock)) {
      gerarCompras = await confirmDialog(
        context,
        titulo: 'Falta stock de alguns ingredientes',
        mensagem: 'Queres adicionar o que faltou à lista de compras?',
        confirmar: 'Adicionar',
        cancelar: 'Agora não',
      );
      if (!mounted) return;
    }

    setState(() => _busy = true);
    try {
      final res = await ref
          .read(mepRepositoryProvider)
          .produzirAgora(
            plano.receitaId,
            plano.kg,
            formatoId: plano.fichaId.isNotEmpty
                ? plano.formatoId
                : _formato?.id,
            fichaId: plano.fichaId,
            tituloReceita: plano.nome,
            gerarCompras: gerarCompras,
          );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Produção registada'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Consumos: ${res.resumo.consumos.length}'),
                Text('Entradas em stock: ${res.resumo.saidas.length}'),
                if (gerarCompras)
                  Text('Lista de compras: ${res.linhasCompra} linha(s)'),
                if (res.resumo.faltas.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Avisos:',
                    style: TextStyle(
                      color: Theme.of(ctx).colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  for (final f in res.resumo.faltas) Text('• $f'),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                router.push('${Routes.schedule}/${res.planoId}');
              },
              child: const Text('Ver na agenda'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) {
        setState(() {
          _feitos.clear();
          _receita = null;
          _ficha = null;
          _kg.clear();
          _formato = null;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _plano(MepPlano plano) => MepPlanoView(
    plano: plano,
    feitos: _feitos,
    onToggle: _toggle,
    onAbrirIntermedio: _abrirIntermedio,
    onProduzir: _busy ? null : () => _produzir(plano),
    busy: _busy,
  );

  @override
  Widget build(BuildContext context) {
    final fmt = ref.watch(moneyFormatProvider);
    final formatos = ref.watch(formatosAtivosProvider).valueOrNull ?? const [];
    final pronto = _fichaArgs != null || _args != null;
    final carrinho = ref.watch(agendaCartProvider);

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
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
              label: const Text('Agendar'),
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
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text(
                    _ficha?.nome ?? _receita?.nome ?? 'Escolher produto',
                  ),
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
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _kg,
                          keyboardType: _ficha != null
                              ? TextInputType.number
                              : const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                          decoration: InputDecoration(
                            labelText: _ficha != null
                                ? 'Unidades a produzir'
                                : 'Quantidade a produzir',
                            suffixText: _ficha != null ? 'un' : 'kg',
                          ),
                          onChanged: (_) => _reset(),
                        ),
                      ),
                      if (_receita != null) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<FormatoCookie?>(
                            initialValue: _formato,
                            decoration: const InputDecoration(
                              labelText: 'Formato',
                              helperText: 'só p/ produto final',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('— nenhum —'),
                              ),
                              for (final f in formatos)
                                DropdownMenuItem(value: f, child: Text(f.nome)),
                            ],
                            onChanged: (f) => setState(() {
                              _formato = f;
                              _feitos.clear();
                            }),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_receita != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton.icon(
                onPressed: () => showProcedimentoSheet(context, _receita!),
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('Procedimento e imagens desta receita'),
              ),
            ),
          const SizedBox(height: 8),
          if (!pronto)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Center(
                child: Text(
                  _ficha != null
                      ? 'Indica quantas unidades queres produzir.'
                      : 'Escolhe o produto e a quantidade.',
                ),
              ),
            )
          else if (_fichaArgs != null)
            AsyncValueView<MepPlano>(
              value: ref.watch(mepPlanoFichaProvider(_fichaArgs!)),
              onRetry: () => ref.invalidate(mepPlanoFichaProvider(_fichaArgs!)),
              data: _plano,
            )
          else ...[
            AsyncValueView<MepPlano>(
              value: ref.watch(mepPlanoProvider(_args!)),
              onRetry: () => ref.invalidate(mepPlanoProvider(_args!)),
              data: _plano,
            ),
            // o custo desta receita, por sub-receita
            Card(
              margin: const EdgeInsets.only(top: 12),
              child: ExpansionTile(
                leading: const Icon(Icons.euro_outlined),
                title: const Text('Custo por receita'),
                childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                children: [
                  AsyncValueView<ProductionNode>(
                    value: ref.watch(
                      productionProvider((recipeId: _receita!.id, alvoG: _alvoG)),
                    ),
                    onRetry: () => ref.invalidate(
                      productionProvider((recipeId: _receita!.id, alvoG: _alvoG)),
                    ),
                    data: (node) => _NodeView(node: node, fmt: fmt, nivel: 0),
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
