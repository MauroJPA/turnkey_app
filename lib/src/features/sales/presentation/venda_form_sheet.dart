import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/mensagem_amigavel.dart';
import '../../../core/formatting/money_provider.dart';
import '../../pricing/data/cost_config_repository.dart';
import '../../tech_sheets/domain/tech_sheet.dart';
import '../../tech_sheets/presentation/ficha_picker_sheet.dart';
import '../application/sales_providers.dart';
import '../domain/venda.dart';
import 'campo_sugestoes.dart';

/// Abre a folha de registo manual de uma venda (data + linhas de produto).
/// Devolve `true` se a venda foi criada.
Future<bool?> showVendaFormSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => const _VendaFormSheet(),
  );
}

class _Linha {
  _Linha({this.ficha, String descricaoInicial = '', double precoInicial = 0})
      : descricao = TextEditingController(text: descricaoInicial),
        quantidade = TextEditingController(text: '1'),
        preco = TextEditingController(
          text: precoInicial > 0 ? precoInicial.toStringAsFixed(2) : '',
        );

  FichaTecnica? ficha;
  final TextEditingController descricao;
  final TextEditingController quantidade;
  final TextEditingController preco;

  double get qtd => double.tryParse(quantidade.text.replaceAll(',', '.')) ?? 0;
  double get precoUn => double.tryParse(preco.text.replaceAll(',', '.')) ?? 0;
  double get total => qtd * precoUn;

  void dispose() {
    descricao.dispose();
    quantidade.dispose();
    preco.dispose();
  }
}

class _VendaFormSheet extends ConsumerStatefulWidget {
  const _VendaFormSheet();

  @override
  ConsumerState<_VendaFormSheet> createState() => _VendaFormSheetState();
}

class _VendaFormSheetState extends ConsumerState<_VendaFormSheet> {
  DateTime _data = DateTime.now();
  final List<_Linha> _linhas = [];
  final _notas = TextEditingController();
  final _numeroDocumento = TextEditingController();
  final _canal = TextEditingController(text: canaisVenda.first);
  final _metodo = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    for (final l in _linhas) {
      l.dispose();
    }
    _notas.dispose();
    _numeroDocumento.dispose();
    _canal.dispose();
    _metodo.dispose();
    super.dispose();
  }

  double get _totalGeral => _linhas.fold(0, (s, l) => s + l.total);

  Future<void> _escolherData() async {
    final novo = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (novo != null) setState(() => _data = novo);
  }

  Future<void> _adicionarProduto() async {
    final ficha = await showFichaPickerSheet(context);
    if (ficha == null || !mounted) return;
    final config = ref.read(costConfigProvider).valueOrNull;
    final preco = ficha.temPrecoVenda
        ? ficha.precoVenda
        : (config?.precoSugeridoComIva(ficha.custoProduto) ?? 0);
    setState(() => _linhas.add(_Linha(ficha: ficha, precoInicial: preco)));
  }

  void _adicionarLivre() {
    setState(() => _linhas.add(_Linha()));
  }

  void _remover(_Linha l) {
    setState(() {
      _linhas.remove(l);
      l.dispose();
    });
  }

  Future<void> _guardar() async {
    final linhasValidas = _linhas.where((l) => l.qtd > 0 && l.precoUn > 0);
    if (linhasValidas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adiciona pelo menos uma linha válida.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(salesActionsProvider).criar(
            data: _data,
            origem: OrigemVenda.manual,
            numeroDocumento: _numeroDocumento.text,
            notas: _notas.text,
            canal: _canal.text,
            metodoPagamento: _metodo.text,
            linhas: linhasValidas
                .map((l) => VendaItemInput(
                      fichaId: l.ficha?.id,
                      descricao: l.ficha?.nome ?? l.descricao.text,
                      quantidade: l.qtd,
                      precoUnitario: l.precoUn,
                      custoUnitarioSnapshot: l.ficha?.custoProduto ?? 0,
                    ))
                .toList(),
          );
      if (mounted) Navigator.pop(context, true);
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = ref.watch(moneyFormatProvider);
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
            Text('Registar venda', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _escolherData,
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(
                '${_data.day.toString().padLeft(2, '0')}/'
                '${_data.month.toString().padLeft(2, '0')}/${_data.year}',
              ),
            ),
            const SizedBox(height: 16),
            if (_linhas.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Ainda sem produtos. Adiciona pelo menos um.'),
              )
            else
              for (final l in _linhas)
                _LinhaTile(
                  linha: l,
                  fmt: fmt,
                  onRemover: () => _remover(l),
                  onChanged: () => setState(() {}),
                ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _adicionarProduto,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Produto (ficha técnica)'),
                ),
                TextButton.icon(
                  onPressed: _adicionarLivre,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Item livre'),
                ),
              ],
            ),
            const Divider(height: 28),
            CampoSugestoes(
              controller: _canal,
              label: 'Canal de venda',
              sugestoes: canaisVenda,
            ),
            const SizedBox(height: 10),
            CampoSugestoes(
              controller: _metodo,
              label: 'Método de pagamento (opcional)',
              sugestoes: metodosPagamento,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _numeroDocumento,
              decoration: const InputDecoration(
                labelText: 'Nº documento (opcional)',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notas,
              decoration: const InputDecoration(labelText: 'Notas (opcional)'),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total', style: Theme.of(context).textTheme.titleMedium),
                Text(
                  fmt(_totalGeral),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _guardar,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar venda'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinhaTile extends StatelessWidget {
  const _LinhaTile({
    required this.linha,
    required this.fmt,
    required this.onRemover,
    required this.onChanged,
  });

  final _Linha linha;
  final MoneyFmt fmt;
  final VoidCallback onRemover;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: linha.ficha != null
                    ? Text(linha.ficha!.nome,
                        style: Theme.of(context).textTheme.labelLarge)
                    : TextField(
                        controller: linha.descricao,
                        decoration: const InputDecoration(
                          labelText: 'Descrição',
                          isDense: true,
                        ),
                      ),
              ),
              IconButton(
                tooltip: 'Remover',
                icon: const Icon(Icons.close, size: 18),
                onPressed: onRemover,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: linha.quantidade,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Qtd',
                    isDense: true,
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: linha.preco,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Preço unitário',
                    isDense: true,
                    prefixText: '€ ',
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 76,
                child: Text(
                  fmt(linha.total),
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
