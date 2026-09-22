import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/money_provider.dart';
import '../../../core/printing/print_html.dart';
import '../../settings/application/empresa_providers.dart';
import '../../tech_sheets/domain/tech_sheet.dart';
import '../../tech_sheets/presentation/ficha_picker_sheet.dart';
import '../application/encomendas_providers.dart';
import '../data/configuracoes_encomendas_repository.dart';
import '../domain/configuracao_encomendas.dart';
import '../domain/encomenda.dart';
import 'encomenda_talao.dart';

/// Abre a folha de criação/edição de uma encomenda (cliente + data/hora +
/// produtos + valor/pagamento). Devolve `true` se foi criada/atualizada.
///
/// Para editar, passa [existente] com as linhas já carregadas em
/// [itensExistentes] (e as fichas correspondentes em [fichasDosItens], só
/// para conseguir mostrar o nome/preço — não é preciso passar a lista
/// completa de fichas da empresa).
Future<bool?> showEncomendaFormSheet(
  BuildContext context, {
  Encomenda? existente,
  List<EncomendaItem>? itensExistentes,
  List<FichaTecnica>? fichasDosItens,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => _EncomendaFormSheet(
      existente: existente,
      itensExistentes: itensExistentes ?? const [],
      fichasDosItens: fichasDosItens ?? const [],
    ),
  );
}

class _Linha {
  _Linha(this.ficha, {double quantidadeInicial = 1, String notasIniciais = ''})
      : quantidade =
            TextEditingController(text: quantidadeInicial.toStringAsFixed(0)),
        notas = TextEditingController(text: notasIniciais);

  final FichaTecnica ficha;
  final TextEditingController quantidade;
  final TextEditingController notas;

  double get qtd => double.tryParse(quantidade.text.replaceAll(',', '.')) ?? 0;
  double get valor => ficha.temPrecoVenda ? ficha.precoVenda * qtd : 0;

  void dispose() {
    quantidade.dispose();
    notas.dispose();
  }
}

class _EncomendaFormSheet extends ConsumerStatefulWidget {
  const _EncomendaFormSheet({
    required this.existente,
    required this.itensExistentes,
    required this.fichasDosItens,
  });

  final Encomenda? existente;
  final List<EncomendaItem> itensExistentes;
  final List<FichaTecnica> fichasDosItens;

  @override
  ConsumerState<_EncomendaFormSheet> createState() =>
      _EncomendaFormSheetState();
}

class _EncomendaFormSheetState extends ConsumerState<_EncomendaFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _clienteNome = TextEditingController();
  final _clienteTelefone = TextEditingController();
  final _clienteNotas = TextEditingController();
  final _notas = TextEditingController();
  final _valorTotal = TextEditingController();
  final _valorPago = TextEditingController();
  late DateTime _data;
  late TimeOfDay _hora;
  final List<_Linha> _linhas = [];
  bool _valorManual = false;
  bool _busy = false;

  bool get _editando => widget.existente != null;

  @override
  void initState() {
    super.initState();
    final ex = widget.existente;
    final agora = DateTime.now();
    _data = ex != null
        ? DateTime(ex.dataHora.year, ex.dataHora.month, ex.dataHora.day)
        : agora.add(const Duration(days: 1));
    _hora = ex != null
        ? TimeOfDay(hour: ex.dataHora.hour, minute: ex.dataHora.minute)
        : const TimeOfDay(hour: 10, minute: 0);

    if (ex != null) {
      _clienteNome.text = ex.clienteNome;
      _clienteTelefone.text = ex.clienteTelefone;
      _clienteNotas.text = ex.clienteNotas;
      _notas.text = ex.notas;
      _valorPago.text = ex.valorPago > 0 ? ex.valorPago.toStringAsFixed(2) : '';
      // Um valor já gravado é sempre tratado como manual — não o vamos
      // sobrescrever silenciosamente ao abrir para editar.
      _valorManual = ex.valorTotal > 0;
      _valorTotal.text = ex.valorTotal > 0 ? ex.valorTotal.toStringAsFixed(2) : '';

      for (final it in widget.itensExistentes) {
        final ficha = widget.fichasDosItens
            .where((f) => f.id == it.fichaId)
            .cast<FichaTecnica?>()
            .firstWhere((_) => true, orElse: () => null);
        if (ficha != null) {
          _linhas.add(_Linha(
            ficha,
            quantidadeInicial: it.quantidade,
            notasIniciais: it.notas,
          ));
        }
      }
    }
  }

  @override
  void dispose() {
    _clienteNome.dispose();
    _clienteTelefone.dispose();
    _clienteNotas.dispose();
    _notas.dispose();
    _valorTotal.dispose();
    _valorPago.dispose();
    for (final l in _linhas) {
      l.dispose();
    }
    super.dispose();
  }

  double get _valorSugerido => _linhas.fold(0, (s, l) => s + l.valor);

  void _recalcularValorSugerido() {
    if (_valorManual) return;
    final soma = _valorSugerido;
    setState(() => _valorTotal.text = soma > 0 ? soma.toStringAsFixed(2) : '');
  }

  Future<void> _escolherData() async {
    final novo = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (novo != null) setState(() => _data = novo);
  }

  Future<void> _escolherHora() async {
    final nova = await showTimePicker(context: context, initialTime: _hora);
    if (nova != null) setState(() => _hora = nova);
  }

  Future<void> _adicionarProduto() async {
    final ficha = await showFichaPickerSheet(context);
    if (ficha == null || !mounted) return;
    setState(() => _linhas.add(_Linha(ficha)));
    _recalcularValorSugerido();
  }

  void _remover(_Linha l) {
    setState(() {
      _linhas.remove(l);
      l.dispose();
    });
    _recalcularValorSugerido();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final linhasValidas = _linhas.where((l) => l.qtd > 0);
    if (linhasValidas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adiciona pelo menos um produto.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final dataHora = DateTime(
        _data.year,
        _data.month,
        _data.day,
        _hora.hour,
        _hora.minute,
      );
      final input = EncomendaInput(
        clienteNome: _clienteNome.text,
        clienteTelefone: _clienteTelefone.text,
        clienteNotas: _clienteNotas.text,
        dataHora: dataHora,
        notas: _notas.text,
        valorTotal: double.tryParse(_valorTotal.text.replaceAll(',', '.')) ?? 0,
        valorPago: double.tryParse(_valorPago.text.replaceAll(',', '.')) ?? 0,
        itens: linhasValidas
            .map((l) => EncomendaItemInput(
                  fichaId: l.ficha.id,
                  fichaNome: l.ficha.nome,
                  quantidade: l.qtd,
                  notas: l.notas.text,
                ))
            .toList(),
      );

      Encomenda resultado;
      if (_editando) {
        await ref
            .read(encomendasActionsProvider)
            .atualizar(widget.existente!.id, input);
        resultado = Encomenda(
          id: widget.existente!.id,
          clienteNome: input.clienteNome,
          clienteTelefone: input.clienteTelefone,
          clienteNotas: input.clienteNotas,
          dataHora: input.dataHora,
          estado: widget.existente!.estado,
          notas: input.notas,
          valorTotal: input.valorTotal,
          valorPago: input.valorPago,
        );
      } else {
        resultado = await ref.read(encomendasActionsProvider).criar(input);
      }

      final config = ref.read(configuracaoEncomendasProvider).valueOrNull ??
          ConfiguracaoEncomendas.vazia;
      if (!_editando && config.imprimirAuto) {
        final nomeEmpresa =
            ref.read(currentEmpresaProvider).valueOrNull?.nome ?? '';
        final itensImpressao = linhasValidas
            .map((l) => EncomendaItem(
                  id: '',
                  encomendaId: resultado.id,
                  fichaId: l.ficha.id,
                  quantidade: l.qtd,
                  notas: l.notas.text,
                ))
            .toList();
        final fichasImpressao = linhasValidas.map((l) => l.ficha).toList();
        final fmt = ref.read(moneyFormatProvider);
        abrirImpressao(
          'Talão — ${resultado.clienteNome}',
          talaoHtml(
            resultado,
            itensImpressao,
            fichasImpressao,
            nomeEmpresa,
            config.talaoTamanho,
            fmt,
          ),
        );
      }

      if (mounted) Navigator.pop(context, true);
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
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_editando ? 'Editar encomenda' : 'Nova encomenda',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _clienteNome,
                autofocus: !_editando,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nome do cliente *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _clienteTelefone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telefone (opcional)',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _escolherData,
                      icon: const Icon(Icons.event_outlined, size: 18),
                      label: Text(
                        '${_data.day.toString().padLeft(2, '0')}/'
                        '${_data.month.toString().padLeft(2, '0')}/${_data.year}',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _escolherHora,
                      icon: const Icon(Icons.schedule_outlined, size: 18),
                      label: Text(_hora.format(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Produtos', style: Theme.of(context).textTheme.titleSmall),
              if (_linhas.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text('Ainda sem produtos. Adiciona pelo menos um.'),
                )
              else
                for (final l in _linhas)
                  _LinhaTile(
                    linha: l,
                    onRemover: () => _remover(l),
                    onChanged: _recalcularValorSugerido,
                  ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _adicionarProduto,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Adicionar produto'),
              ),
              const Divider(height: 28),
              Text('Valor e pagamento',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _valorTotal,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Valor total',
                        prefixText: '€ ',
                        helperText: _valorManual
                            ? null
                            : 'Sugerido a partir dos preços de venda',
                      ),
                      onChanged: (_) => setState(() => _valorManual = true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _valorPago,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Já pago',
                        prefixText: '€ ',
                        helperText: 'Deixa 0 se ainda não pagou nada',
                      ),
                    ),
                  ),
                ],
              ),
              if (_valorManual)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: TextButton(
                    onPressed: () {
                      setState(() => _valorManual = false);
                      _recalcularValorSugerido();
                    },
                    child: const Text('Voltar a calcular automaticamente'),
                  ),
                ),
              const Divider(height: 28),
              TextFormField(
                controller: _clienteNotas,
                decoration: const InputDecoration(
                  labelText: 'Notas do cliente (opcional)',
                  hintText: 'Ex.: alergias, preferências',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _notas,
                decoration: const InputDecoration(labelText: 'Notas internas (opcional)'),
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
                    : Text(_editando ? 'Guardar alterações' : 'Criar encomenda'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinhaTile extends StatelessWidget {
  const _LinhaTile({
    required this.linha,
    required this.onRemover,
    required this.onChanged,
  });

  final _Linha linha;
  final VoidCallback onRemover;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Text(linha.ficha.nome,
                style: Theme.of(context).textTheme.labelLarge),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: TextField(
              controller: linha.quantidade,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Qtd', isDense: true),
              onChanged: (_) => onChanged(),
            ),
          ),
          IconButton(
            tooltip: 'Remover',
            icon: const Icon(Icons.close, size: 18),
            onPressed: onRemover,
          ),
        ],
      ),
    );
  }
}
