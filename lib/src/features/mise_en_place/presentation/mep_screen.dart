import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/help_actions.dart';
import '../../cookie_formats/application/cookie_format_providers.dart';
import '../../cookie_formats/domain/cookie_format.dart';
import '../../production/presentation/produto_picker_sheet.dart';
import '../../recipes/data/recipe_repository.dart';
import '../../recipes/domain/recipe.dart';
import '../../recipes/presentation/procedimento_sheet.dart';
import '../../tech_sheets/domain/tech_sheet.dart';
import '../application/mep_providers.dart';
import '../data/mep_repository.dart';
import '../domain/mep_plano.dart';
import 'mep_plano_view.dart';

class MiseEnPlaceScreen extends ConsumerStatefulWidget {
  const MiseEnPlaceScreen({super.key, this.receitaId, this.kgInicial});

  final String? receitaId;
  final double? kgInicial;

  @override
  ConsumerState<MiseEnPlaceScreen> createState() => _MiseEnPlaceScreenState();
}

class _MiseEnPlaceScreenState extends ConsumerState<MiseEnPlaceScreen> {
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
        } catch (_) {}
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
    final un = int.tryParse(_kg.text.trim()) ?? 0;
    if (f == null || un <= 0) return null;
    return (fichaId: f.id, unidades: un);
  }

  void _reset() => setState(_feitos.clear);

  Future<void> _escolherReceita() async {
    // Produto final (ficha técnica) ou receita.
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

  void _abrirIntermedio(MepIntermedio it) {
    context.push('${Routes.miseEnPlace}?receita=${it.receitaId}');
  }

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
          'e intermédios usados. O produto acabado entra em stock.',
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
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatos = ref.watch(formatosAtivosProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
        title: const Text('Mise en place'),
        actions: const [HelpActions(topic: HelpTopic.miseEnPlace)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.blender_outlined),
                  title: Text(
                    _ficha?.nome ?? _receita?.nome ?? 'Escolher produto',
                  ),
                  subtitle: _ficha != null
                      ? const Text('Produto final (ficha técnica)')
                      : _receita == null
                      ? const Text('Produto final ou receita')
                      : Text(_receita!.categoria.label),
                  trailing: const Icon(Icons.expand_more),
                  onTap: _escolherReceita,
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _kg,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: _ficha != null
                                ? 'Unidades'
                                : 'Quantidade',
                            suffixText: _ficha != null ? 'un' : 'kg',
                          ),
                          onChanged: (_) => _reset(),
                        ),
                      ),
                      if (_ficha == null) const SizedBox(width: 12),
                      if (_ficha == null)
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
                  ),
                ),
              ],
            ),
          ),
          if (_receita != null)
            OutlinedButton.icon(
              onPressed: () => showProcedimentoSheet(context, _receita!),
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('Procedimento e imagens desta receita'),
            ),
          const SizedBox(height: 8),
          if (_fichaArgs != null)
            AsyncValueView<MepPlano>(
              value: ref.watch(mepPlanoFichaProvider(_fichaArgs!)),
              onRetry: () => ref.invalidate(mepPlanoFichaProvider(_fichaArgs!)),
              data: (plano) => MepPlanoView(
                plano: plano,
                feitos: _feitos,
                onToggle: (id, v) => setState(() {
                  if (v) {
                    _feitos.add(id);
                  } else {
                    _feitos.remove(id);
                  }
                }),
                onAbrirIntermedio: _abrirIntermedio,
                onProduzir: _busy ? null : () => _produzir(plano),
                busy: _busy,
              ),
            )
          else if (_args == null)
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
          else
            AsyncValueView<MepPlano>(
              value: ref.watch(mepPlanoProvider(_args!)),
              onRetry: () => ref.invalidate(mepPlanoProvider(_args!)),
              data: (plano) => MepPlanoView(
                plano: plano,
                feitos: _feitos,
                onToggle: (id, v) => setState(() {
                  if (v) {
                    _feitos.add(id);
                  } else {
                    _feitos.remove(id);
                  }
                }),
                onAbrirIntermedio: _abrirIntermedio,
                onProduzir: _busy ? null : () => _produzir(plano),
                busy: _busy,
              ),
            ),
        ],
      ),
    );
  }
}
