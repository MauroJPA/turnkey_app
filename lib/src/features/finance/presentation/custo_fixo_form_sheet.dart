import 'package:flutter/material.dart';

import '../domain/custo_fixo.dart';

/// Abre a folha de criação/edição de um custo fixo/variável.
Future<CustoFixoInput?> showCustoFixoFormSheet(
  BuildContext context, {
  CustoFixo? existente,
}) {
  return showModalBottomSheet<CustoFixoInput>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CustoFixoFormSheet(existente: existente),
  );
}

class _CustoFixoFormSheet extends StatefulWidget {
  const _CustoFixoFormSheet({this.existente});
  final CustoFixo? existente;

  @override
  State<_CustoFixoFormSheet> createState() => _CustoFixoFormSheetState();
}

class _CustoFixoFormSheetState extends State<_CustoFixoFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.existente?.nome ?? '');
  late final _valor = TextEditingController(
    text: widget.existente != null && widget.existente!.valorMensal > 0
        ? widget.existente!.valorMensal.toStringAsFixed(2)
        : '',
  );
  late final _notas = TextEditingController(text: widget.existente?.notas ?? '');
  late final _diaPagamento = TextEditingController(
    text: widget.existente?.diaPagamento?.toString() ?? '',
  );
  late final _categoria = TextEditingController(
    text: widget.existente?.categoria ?? '',
  );
  late TipoCusto _tipo = widget.existente?.tipo ?? TipoCusto.fixo;

  @override
  void dispose() {
    _nome.dispose();
    _valor.dispose();
    _notas.dispose();
    _diaPagamento.dispose();
    _categoria.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      CustoFixoInput(
        nome: _nome.text,
        tipo: _tipo,
        valorMensal: double.parse(_valor.text.replaceAll(',', '.')),
        notas: _notas.text,
        diaPagamento: int.tryParse(_diaPagamento.text.trim()),
        categoria: _categoria.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editar = widget.existente != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              editar ? 'Editar custo' : 'Novo custo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nome,
              autofocus: !editar,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nome *',
                hintText: 'Ex.: Aluguel, Salários, Internet',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
            ),
            const SizedBox(height: 12),
            SegmentedButton<TipoCusto>(
              segments: const [
                ButtonSegment(value: TipoCusto.fixo, label: Text('Fixo')),
                ButtonSegment(
                    value: TipoCusto.variavel, label: Text('Variável')),
              ],
              selected: {_tipo},
              onSelectionChanged: (s) => setState(() => _tipo = s.first),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _tipo == TipoCusto.fixo
                    ? 'Fixo: não dá para eliminar sem fechar ou mudar o '
                        'negócio (renda, salários, seguros…).'
                    : 'Variável: dá para reduzir ou cortar, por um período '
                        'ou para sempre (marketing, subscrições, consumos…).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _valor,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Valor mensal *',
                prefixText: '€ ',
              ),
              validator: (v) {
                final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                return (n == null || n <= 0) ? 'Valor inválido' : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _categoria,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Categoria (opcional)',
                hintText: 'Ex.: Controlo operacional',
                helperText:
                    'Agrupa custos parecidos (HACCP, pragas, extintores…).',
              ),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 0,
              children: [
                for (final c in categoriasCustoSugeridas)
                  ActionChip(
                    label: Text(c),
                    onPressed: () => setState(() => _categoria.text = c),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _diaPagamento,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Dia de pagamento (opcional)',
                hintText: 'Ex.: 8 — para o lembrete no Início',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final n = int.tryParse(v.trim());
                return (n == null || n < 1 || n > 31)
                    ? 'Dia entre 1 e 31'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notas,
              decoration: const InputDecoration(labelText: 'Notas (opcional)'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              child: Text(editar ? 'Guardar' : 'Criar'),
            ),
          ],
        ),
      ),
    );
  }
}
