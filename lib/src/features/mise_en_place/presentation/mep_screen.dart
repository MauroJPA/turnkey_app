import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/formatting/quantities.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/help_actions.dart';
import '../../cookie_formats/application/cookie_format_providers.dart';
import '../../cookie_formats/domain/cookie_format.dart';
import '../../recipes/data/recipe_repository.dart';
import '../../recipes/domain/recipe.dart';
import '../../recipes/presentation/procedimento_sheet.dart';
import '../../recipes/presentation/recipe_picker_sheet.dart';
import '../application/mep_providers.dart';
import '../data/mep_repository.dart';
import '../domain/mep_plano.dart';

class MiseEnPlaceScreen extends ConsumerStatefulWidget {
  const MiseEnPlaceScreen({super.key, this.receitaId, this.kgInicial});

  final String? receitaId;
  final double? kgInicial;

  @override
  ConsumerState<MiseEnPlaceScreen> createState() => _MiseEnPlaceScreenState();
}

class _MiseEnPlaceScreenState extends ConsumerState<MiseEnPlaceScreen> {
  Receita? _receita;
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
          final r =
              await ref.read(recipeRepositoryProvider).getById(widget.receitaId!);
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

  void _reset() => setState(_feitos.clear);

  Future<void> _escolherReceita() async {
    final r = await showRecipePickerSheet(context, soFabricoProprio: false);
    if (r != null) {
      setState(() {
        _receita = r;
        _feitos.clear();
      });
    }
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
        mensagem: 'Marcaste ${_feitos.length} de $totalItems. '
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
      final res = await ref.read(mepRepositoryProvider).produzirAgora(
            plano.receitaId,
            plano.kg,
            formatoId: _formato?.id,
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
                  Text('Avisos:',
                      style: TextStyle(
                        color: Theme.of(ctx).colorScheme.error,
                        fontWeight: FontWeight.bold,
                      )),
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
          _kg.clear();
          _formato = null;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
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
                  title: Text(_receita?.nome ?? 'Escolher receita'),
                  subtitle: _receita == null
                      ? null
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
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Quantidade',
                            suffixText: 'kg',
                          ),
                          onChanged: (_) => _reset(),
                        ),
                      ),
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
                                value: null, child: Text('— nenhum —')),
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
          if (_args == null)
            const Padding(
              padding: EdgeInsets.only(top: 32),
              child: Center(
                child: Text('Escolhe a receita e a quantidade.'),
              ),
            )
          else
            AsyncValueView<MepPlano>(
              value: ref.watch(mepPlanoProvider(_args!)),
              onRetry: () => ref.invalidate(mepPlanoProvider(_args!)),
              data: (plano) => _Conteudo(
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

class _Conteudo extends StatelessWidget {
  const _Conteudo({
    required this.plano,
    required this.feitos,
    required this.onToggle,
    required this.onAbrirIntermedio,
    required this.onProduzir,
    required this.busy,
  });

  final MepPlano plano;
  final Set<String> feitos;
  final void Function(String id, bool v) onToggle;
  final void Function(MepIntermedio) onAbrirIntermedio;
  final VoidCallback? onProduzir;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            [
              '${plano.kg.toStringAsFixed(2)} kg',
              if (plano.formato.isNotEmpty) plano.formato,
              if (plano.unidades > 0) '≈ ${plano.unidades} unidades',
              if (plano.recheio.isNotEmpty) 'recheio ${plano.recheio}',
            ].join('  ·  '),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (plano.intermedios.isNotEmpty) ...[
          Text('Produzir primeiro',
              style: Theme.of(context).textTheme.titleSmall),
          for (final it in plano.intermedios)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 3),
              child: CheckboxListTile(
                controlAffinity: ListTileControlAffinity.leading,
                value: feitos.contains('int:${it.receitaId}'),
                onChanged: (v) => onToggle('int:${it.receitaId}', v ?? false),
                title: Text(it.nome,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(gramasParaTexto(it.gramas)),
                secondary: TextButton(
                  onPressed: () => onAbrirIntermedio(it),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          const SizedBox(height: 12),
        ],
        Text('Ingredientes', style: Theme.of(context).textTheme.titleSmall),
        for (final c in plano.comprar)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 3),
            child: CheckboxListTile(
              controlAffinity: ListTileControlAffinity.leading,
              value: feitos.contains('ing:${c.ingredienteId}'),
              onChanged: (v) => onToggle('ing:${c.ingredienteId}', v ?? false),
              title: Text(c.nome, style: const TextStyle(fontSize: 16)),
              subtitle: Text(
                c.faltaStock
                    ? '${gramasParaTexto(c.gramas)} · em stock só '
                        '${gramasParaTexto(c.emStock)}'
                    : '${gramasParaTexto(c.gramas)} · em stock',
                style: TextStyle(
                  color: c.faltaStock ? cs.error : cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onProduzir,
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.task_alt),
          label: const Text('Produção feita'),
        ),
      ],
    );
  }
}
