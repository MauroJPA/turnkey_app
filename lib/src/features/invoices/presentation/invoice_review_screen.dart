import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/formatting/dates.dart';
import '../../../core/formatting/quantities.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/help_actions.dart';
import '../../ingredients/application/ingredients_providers.dart';
import '../../ingredients/domain/ingredient.dart';
import '../application/invoice_providers.dart';
import '../data/invoice_repository.dart';
import '../domain/fatura.dart';
import '../domain/match_ingrediente.dart';

class InvoiceReviewScreen extends ConsumerWidget {
  const InvoiceReviewScreen({super.key, required this.faturaId});
  final String faturaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faturaAsync = ref.watch(faturaProvider(faturaId));
    final ingsAsync = ref.watch(ingredientsListProvider(false));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(Routes.invoices),
        ),
        title: const Text('Rever fatura'),
        actions: const [HelpActions(topic: HelpTopic.faturaRevisao)],
      ),
      body: AsyncValueView<Fatura>(
        value: faturaAsync,
        onRetry: () => ref.invalidate(faturaProvider(faturaId)),
        data: (fatura) {
          if (fatura.estado == FaturaEstado.erro) {
            return _Erro(fatura: fatura);
          }
          if (fatura.linhasIa.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'A IA ainda não devolveu linhas. Se acabaste de criar a '
                'fatura, aguarda uns segundos e recarrega.',
              ),
            );
          }
          return ingsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (ings) => _Revisao(fatura: fatura, ingredientes: ings),
          );
        },
      ),
    );
  }
}

class _Erro extends ConsumerWidget {
  const _Erro({required this.fatura});
  final Fatura fatura;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline,
              size: 40, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Text('A análise falhou: ${fatura.erroIa}',
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          const Text(
            'Verifica a chave da IA no servidor (ANTHROPIC_API_KEY) e '
            'tenta de novo com uma foto nítida.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LinhaState {
  _LinhaState(this.ia, Ingrediente? match, bool isLista)
      : ingrediente = match,
        qtd = TextEditingController(
          text: ia.quantidadeG > 0 ? ia.quantidadeG.toStringAsFixed(0) : '',
        ),
        preco = TextEditingController(
          text: (ia.precoUnitario ?? 0) > 0
              ? ia.precoUnitario!.toStringAsFixed(2)
              : '',
        ),
        emb = TextEditingController(
          text: (ia.embalagemG ?? 0) > 0
              ? ia.embalagemG!.toStringAsFixed(0)
              : (match != null && match.gramasEmbalagem > 0
                  ? match.gramasEmbalagem.toStringAsFixed(0)
                  : ''),
        ),
        acao = match == null
            ? AcaoFatura.ignorar
            : (isLista ? AcaoFatura.preco : AcaoFatura.ambos);

  final FaturaLinhaIa ia;
  Ingrediente? ingrediente;
  final TextEditingController qtd;
  final TextEditingController preco;
  final TextEditingController emb;
  AcaoFatura acao;

  double _n(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.').trim()) ?? 0;

  LinhaAAplicar toAplicar() => (
        ingredienteId: ingrediente?.id,
        descricaoFatura: ia.descricao,
        quantidadeG: _n(qtd),
        precoUnitario: _n(preco),
        totalLinha: ia.total ?? 0,
        embalagemG: _n(emb),
        acao: acao,
      );
}

class _Revisao extends ConsumerStatefulWidget {
  const _Revisao({required this.fatura, required this.ingredientes});
  final Fatura fatura;
  final List<Ingrediente> ingredientes;

  @override
  ConsumerState<_Revisao> createState() => _RevisaoState();
}

class _RevisaoState extends ConsumerState<_Revisao> {
  late final List<_LinhaState> _linhas;
  bool _busy = false;

  bool get _isLista => widget.fatura.tipo == FaturaTipo.listaPrecos;

  @override
  void initState() {
    super.initState();
    _linhas = [
      for (final ia in widget.fatura.linhasIa)
        _LinhaState(
          ia,
          melhorMatch(ia.descricao, widget.ingredientes),
          _isLista,
        ),
    ];
  }

  Future<void> _escolherIngrediente(_LinhaState l) async {
    final r = await showModalBottomSheet<Ingrediente>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _IngredientePicker(ingredientes: widget.ingredientes),
    );
    if (r != null) {
      setState(() {
        l.ingrediente = r;
        if (l.acao == AcaoFatura.ignorar) {
          l.acao = _isLista ? AcaoFatura.preco : AcaoFatura.ambos;
        }
        if (l.emb.text.trim().isEmpty && r.gramasEmbalagem > 0) {
          l.emb.text = r.gramasEmbalagem.toStringAsFixed(0);
        }
      });
    }
  }

  Future<void> _aplicar() async {
    final aAplicar = _linhas.where((l) => l.acao != AcaoFatura.ignorar).toList();
    if (aAplicar.any((l) => l.ingrediente == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Há linhas sem ingrediente. Liga ou põe em Ignorar.'),
      ));
      return;
    }
    final ok = await confirmDialog(
      context,
      titulo: 'Aplicar ${aAplicar.length} linha(s)?',
      mensagem: 'Atualiza os preços dos ingredientes escolhidos e dá entrada '
          'no inventário das quantidades marcadas. A fatura fica confirmada.',
      confirmar: 'Aplicar',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      final res = await ref.read(invoiceActionsProvider).aplicar(
            widget.fatura.id,
            _linhas.map((l) => l.toAplicar()).toList(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          '${res.precos} preço(s) atualizado(s), '
          '${res.movimentos} entrada(s) de stock.',
        ),
      ));
      if (context.canPop()) context.pop();
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
    final f = widget.fatura;
    final url = ref.read(invoiceRepositoryProvider).ficheiroUrl(f, thumb: true);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: [
        Card(
          child: ListTile(
            leading: url.isEmpty
                ? const Icon(Icons.receipt_long_outlined, size: 40)
                : GestureDetector(
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (_) => Dialog(
                        child: InteractiveViewer(
                          child: Image.network(
                            ref
                                .read(invoiceRepositoryProvider)
                                .ficheiroUrl(f),
                          ),
                        ),
                      ),
                    ),
                    child: Image.network(url,
                        width: 48, height: 48, fit: BoxFit.cover),
                  ),
            title: Text(f.fornecedor.isEmpty ? 'Fornecedor?' : f.fornecedor),
            subtitle: Text([
              f.tipo.label,
              if (f.numero.isNotEmpty) 'nº ${f.numero}',
              if (f.dataFatura.isNotEmpty) formatDateShort(f.dataFatura),
              if (f.total > 0) 'total ${f.total.toStringAsFixed(2)}',
            ].join(' · ')),
          ),
        ),
        const SizedBox(height: 8),
        Text('Linhas lidas pela IA — confirma cada uma',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        for (final l in _linhas)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 3),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.ia.descricao,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _escolherIngrediente(l),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Ingrediente',
                        isDense: true,
                      ),
                      child: Text(
                        l.ingrediente?.nome ?? 'Escolher ingrediente…',
                        style: TextStyle(
                          color: l.ingrediente == null
                              ? Theme.of(context).colorScheme.error
                              : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (!_isLista) ...[
                        Expanded(
                          child: TextField(
                            controller: l.qtd,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Comprado',
                              suffixText: 'g',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: TextField(
                          controller: l.preco,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Preço embalagem',
                            prefixText: '€ ',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: l.emb,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Embalagem',
                            suffixText: 'g',
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<AcaoFatura>(
                    value: l.acao,
                    decoration: const InputDecoration(
                        labelText: 'Ação', isDense: true),
                    items: [
                      for (final a in AcaoFatura.values)
                        if (!_isLista ||
                            a == AcaoFatura.preco ||
                            a == AcaoFatura.ignorar)
                          DropdownMenuItem(value: a, child: Text(a.label)),
                    ],
                    onChanged: (a) =>
                        setState(() => l.acao = a ?? AcaoFatura.ignorar),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _aplicar,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: const Text('Aplicar aos ingredientes'),
        ),
      ],
    );
  }
}

class _IngredientePicker extends StatefulWidget {
  const _IngredientePicker({required this.ingredientes});
  final List<Ingrediente> ingredientes;

  @override
  State<_IngredientePicker> createState() => _IngredientePickerState();
}

class _IngredientePickerState extends State<_IngredientePicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final itens = widget.ingredientes
        .where((i) => _q.isEmpty || i.nome.toLowerCase().contains(_q.toLowerCase()))
        .toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Procurar ingrediente',
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: itens.length,
              itemBuilder: (_, i) => ListTile(
                title: Text(itens[i].nome),
                subtitle: Text([
                  if (itens[i].marca.isNotEmpty) itens[i].marca,
                  if (itens[i].gramasEmbalagem > 0)
                    gramasParaTexto(itens[i].gramasEmbalagem),
                ].join(' · ')),
                onTap: () => Navigator.pop(context, itens[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
