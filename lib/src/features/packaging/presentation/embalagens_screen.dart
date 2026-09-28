import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/data/marcas_fornecedores_providers.dart';
import '../../../core/formatting/money_provider.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/autocomplete_text_field.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/help_actions.dart';
import '../../cookie_formats/application/cookie_format_providers.dart';
import '../application/embalagem_kit_providers.dart';
import '../application/embalagem_providers.dart';
import '../domain/embalagem.dart';
import '../domain/embalagem_kit.dart';
import 'kit_editor_sheet.dart';

class EmbalagensScreen extends ConsumerStatefulWidget {
  const EmbalagensScreen({super.key});

  @override
  ConsumerState<EmbalagensScreen> createState() => _EmbalagensScreenState();
}

class _EmbalagensScreenState extends ConsumerState<EmbalagensScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this)
    ..addListener(() => setState(() {}));

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  bool get _podeEditar => ref.read(currentPapelProvider).canEditBusiness;

  Future<void> _formEmbalagem({Embalagem? existente}) async {
    final input = await showModalBottomSheet<EmbalagemInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EmbalagemForm(existente: existente),
    );
    if (input == null) return;
    final a = ref.read(embalagemActionsProvider);
    try {
      if (existente == null) {
        await a.criar(input);
      } else {
        await a.atualizar(existente.id, input);
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _novoKit() async {
    final nomeCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Novo kit'),
        content: TextField(
          controller: nomeCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nome do kit',
            hintText: 'Ex.: Take-away, Loja, Oferta',
          ),
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    if (ok != true || nomeCtrl.text.trim().isEmpty) return;
    try {
      final kit = await ref
          .read(embalagemKitActionsProvider)
          .criar(EmbalagemKitInput(nome: nomeCtrl.text));
      if (mounted) await showKitEditorSheet(context, kitId: kit.id);
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = ref.watch(moneyFormatProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
        title: const Text('Embalagens'),
        actions: const [HelpActions(topic: HelpTopic.embalagens)],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Peças'),
            Tab(text: 'Kits'),
          ],
        ),
      ),
      floatingActionButton: _podeEditar
          ? FloatingActionButton.extended(
              onPressed: _tab.index == 0 ? () => _formEmbalagem() : _novoKit,
              icon: const Icon(Icons.add),
              label: Text(_tab.index == 0 ? 'Embalagem' : 'Kit'),
            )
          : null,
      body: TabBarView(
        controller: _tab,
        children: [
          _PecasTab(podeEditar: _podeEditar, fmt: fmt, onEdit: _formEmbalagem),
          _KitsTab(podeEditar: _podeEditar, fmt: fmt),
        ],
      ),
    );
  }
}

class _PecasTab extends ConsumerWidget {
  const _PecasTab({
    required this.podeEditar,
    required this.fmt,
    required this.onEdit,
  });
  final bool podeEditar;
  final MoneyFmt fmt;
  final Future<void> Function({Embalagem? existente}) onEdit;

  static String _n(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(embalagensListProvider);
    return AsyncValueView<List<Embalagem>>(
      value: async,
      onRetry: () => ref.invalidate(embalagensListProvider),
      data: (itens) {
        if (itens.isEmpty) {
          return const EmptyState(
            icon: Icons.inventory_2_outlined,
            titulo: 'Sem embalagens',
            mensagem:
                'Caixas, sacos, saquetas, adesivos, fita… com o custo, '
                'para entrar nas fichas técnicas.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: itens.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final e = itens[i];
            final sub = [
              if (e.tipo.isNotEmpty) e.tipo,
              if (e.caracteristica.isNotEmpty) e.caracteristica,
              'compra ${fmt(e.precoCompra)} / ${_n(e.unidadesCompra)} pç',
              if (e.rendeUnidades > 1) 'rende ${_n(e.rendeUnidades)} un',
              if (e.uso != null) e.uso!.label,
              if (e.fornecedor.isNotEmpty) e.fornecedor,
            ].join(' · ');
            return ListTile(
              title: Text(e.nome),
              subtitle: Text(sub),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    fmt(e.custoUnidade),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'por unidade',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              onTap: podeEditar ? () => onEdit(existente: e) : null,
              onLongPress: podeEditar
                  ? () async {
                      final ok = await confirmDialog(
                        context,
                        titulo: 'Apagar embalagem?',
                        mensagem:
                            'Remove "${e.nome}". As fichas e kits que a usam '
                            'perdem esse custo.',
                        confirmar: 'Apagar',
                        destrutivo: true,
                      );
                      if (ok) {
                        await ref.read(embalagemActionsProvider).apagar(e.id);
                      }
                    }
                  : null,
            );
          },
        );
      },
    );
  }
}

class _KitsTab extends ConsumerWidget {
  const _KitsTab({required this.podeEditar, required this.fmt});
  final bool podeEditar;
  final MoneyFmt fmt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(embalagemKitsListProvider);
    return AsyncValueView<List<EmbalagemKit>>(
      value: async,
      onRetry: () => ref.invalidate(embalagemKitsListProvider),
      data: (kits) {
        if (kits.isEmpty) {
          return const EmptyState(
            icon: Icons.widgets_outlined,
            titulo: 'Sem kits',
            mensagem:
                'Um kit junta várias embalagens numa combinação com '
                'nome (ex.: "Take-away" = 1 saqueta + 1 caixa + 2 adesivos). '
                'Na ficha técnica escolhes o kit para precificar de uma vez.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: kits.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final k = kits[i];
            return ListTile(
              title: Text(k.nome),
              subtitle: k.descricao.isEmpty ? null : Text(k.descricao),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    fmt(k.custoUnitario),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'por unidade',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              onTap: podeEditar
                  ? () => showKitEditorSheet(context, kitId: k.id)
                  : null,
              onLongPress: podeEditar
                  ? () async {
                      final ok = await confirmDialog(
                        context,
                        titulo: 'Apagar kit?',
                        mensagem:
                            'Remove "${k.nome}". As fichas que o usam perdem '
                            'esse custo.',
                        confirmar: 'Apagar',
                        destrutivo: true,
                      );
                      if (ok) {
                        await ref
                            .read(embalagemKitActionsProvider)
                            .apagar(k.id);
                      }
                    }
                  : null,
            );
          },
        );
      },
    );
  }
}

class _EmbalagemForm extends ConsumerStatefulWidget {
  const _EmbalagemForm({this.existente});
  final Embalagem? existente;

  @override
  ConsumerState<_EmbalagemForm> createState() => _EmbalagemFormState();
}

class _EmbalagemFormState extends ConsumerState<_EmbalagemForm> {
  late final _nome = TextEditingController(text: widget.existente?.nome ?? '');
  late final _caracteristica = TextEditingController(
    text: widget.existente?.caracteristica ?? '',
  );
  late final _forn = TextEditingController(
    text: widget.existente?.fornecedor ?? '',
  );
  late final _preco = TextEditingController(
    text: widget.existente == null ? '' : _s(widget.existente!.precoCompra),
  );
  late final _pecas = TextEditingController(
    text: widget.existente == null ? '1' : _s(widget.existente!.unidadesCompra),
  );
  late final _rende = TextEditingController(
    text: widget.existente == null ? '1' : _s(widget.existente!.rendeUnidades),
  );
  late String _tipo = widget.existente?.tipo.isNotEmpty == true
      ? widget.existente!.tipo
      : 'Caixa';
  late UsoEmbalagem? _uso = widget.existente?.uso;
  late final Set<String> _formatos = {...?widget.existente?.formatosCookieIds};

  static String _s(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';
  double _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.').trim()) ?? 0;

  @override
  void dispose() {
    for (final c in [_nome, _caracteristica, _forn, _preco, _pecas, _rende]) {
      c.dispose();
    }
    super.dispose();
  }

  void _guardar() {
    if (_nome.text.trim().isEmpty) return;
    Navigator.pop(
      context,
      EmbalagemInput(
        nome: _nome.text,
        tipo: _tipo,
        caracteristica: _caracteristica.text,
        uso: _uso,
        formatosCookieIds: _formatos.toList(),
        precoCompra: _num(_preco),
        unidadesCompra: _num(_pecas),
        rendeUnidades: _num(_rende),
        fornecedor: _forn.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final custoUn =
        (_num(_preco) / (_num(_pecas) <= 0 ? 1 : _num(_pecas))) /
        (_num(_rende) <= 0 ? 1 : _num(_rende));
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existente == null ? 'Nova embalagem' : 'Editar embalagem',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nome,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nome *',
                hintText: 'Ex.: Caixa 6 un, Saco kraft, Adesivo 4 cm',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _tipo,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: [
                for (final t in kTiposEmbalagem)
                  DropdownMenuItem(value: t, child: Text(t)),
              ],
              onChanged: (v) => setState(() => _tipo = v ?? 'Caixa'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _caracteristica,
              decoration: const InputDecoration(
                labelText: 'Característica (opcional)',
                hintText: 'Kraft com janela, transparente, 250 ml…',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<UsoEmbalagem?>(
              initialValue: _uso,
              decoration: const InputDecoration(labelText: 'Uso (opcional)'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Não definido'),
                ),
                for (final u in UsoEmbalagem.values)
                  DropdownMenuItem(value: u, child: Text(u.label)),
              ],
              onChanged: (v) => setState(() {
                _uso = v;
                // Individual é sempre 1 peça; múltiplo pede uma quantidade
                // (2, 3, 4…) — arranca em 2 se ainda estava em 1 ou vazio.
                if (v == UsoEmbalagem.individual) {
                  _rende.text = '1';
                } else if (v == UsoEmbalagem.multiplo && _num(_rende) <= 1) {
                  _rende.text = '2';
                }
              }),
            ),
            if (_uso == UsoEmbalagem.multiplo) ...[
              const SizedBox(height: 8),
              Text(
                'Quantidade do múltiplo',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final n in const [2, 3, 4, 5, 6, 8, 10, 12])
                    ChoiceChip(
                      label: Text('$n'),
                      selected: _num(_rende) == n,
                      onSelected: (_) =>
                          setState(() => _rende.text = _s(n.toDouble())),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Formatos de cookie (opcional)',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Para que formatos serve esta embalagem — em branco serve para '
              'qualquer um.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Builder(
              builder: (context) {
                final async = ref.watch(formatosAtivosProvider);
                return async.when(
                  loading: () => const SizedBox(
                    height: 24,
                    child: Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (formatos) => formatos.isEmpty
                      ? Text(
                          'Sem formatos de cookie criados ainda.',
                          style: Theme.of(context).textTheme.bodySmall,
                        )
                      : Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final f in formatos)
                              FilterChip(
                                label: Text(f.nome),
                                selected: _formatos.contains(f.id),
                                onSelected: (v) => setState(() {
                                  if (v) {
                                    _formatos.add(f.id);
                                  } else {
                                    _formatos.remove(f.id);
                                  }
                                }),
                              ),
                          ],
                        ),
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _preco,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Preço da compra',
                      prefixText: '€ ',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _pecas,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Peças na compra',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rende,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Uma peça embala quantas unidades?',
                hintText: '1 saco = 1 un; 1 caixa = 6 un',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            AutocompleteTextField(
              controller: _forn,
              options: ref.watch(fornecedoresConhecidosProvider),
              labelText: 'Fornecedor',
            ),
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Custo por unidade de produto: '
                  '€ ${custoUn.toStringAsFixed(4)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _guardar,
              child: Text(widget.existente == null ? 'Adicionar' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
