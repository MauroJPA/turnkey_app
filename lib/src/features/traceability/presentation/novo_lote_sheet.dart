import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/errors/mensagem_amigavel.dart';
import '../../tech_sheets/domain/tech_sheet.dart';
import '../../tech_sheets/presentation/ficha_picker_sheet.dart';
import '../data/lotes_repository.dart';
import '../domain/lote.dart';

/// Regista um lote de produção: produto, data, quantidade, validade e o lote
/// de cada ingrediente usado. Devolve o lote criado.
Future<LoteProducao?> showNovoLoteSheet(
  BuildContext context, {
  FichaTecnica? ficha,
}) {
  return showModalBottomSheet<LoteProducao>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => _NovoLote(fichaInicial: ficha),
  );
}

const _semLote = '__sem__';
const _novoLote = '__novo__';

class _Escolha {
  _Escolha(this.ing, List<LoteSugerido> lotes) : lotes = [...lotes] {
    final valido = this.lotes.where(
      (l) =>
          l.validade == null ||
          !l.validade!.isBefore(
            DateTime(
              DateTime.now().year,
              DateTime.now().month,
              DateTime.now().day,
            ),
          ),
    );
    escolhido = valido.isEmpty ? _semLote : valido.first.id;
  }

  final IngredienteComLotes ing;
  final List<LoteSugerido> lotes;
  late String escolhido;

  LoteSugerido? get lote =>
      lotes.where((l) => l.id == escolhido).cast<LoteSugerido?>().firstOrNull;
}

class _NovoLote extends ConsumerStatefulWidget {
  const _NovoLote({this.fichaInicial});
  final FichaTecnica? fichaInicial;

  @override
  ConsumerState<_NovoLote> createState() => _NovoLoteState();
}

class _NovoLoteState extends ConsumerState<_NovoLote> {
  FichaTecnica? _ficha;
  DateTime _data = () {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }();
  DateTime? _validade;
  final _qtd = TextEditingController();
  final _resp = TextEditingController();
  final _notas = TextEditingController();
  List<_Escolha> _ingredientes = const [];
  bool _aCarregar = false;
  bool _aGuardar = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _resp.text = ref.read(currentUserNameProvider) ?? '';
    if (widget.fichaInicial != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _escolherFicha(widget.fichaInicial!),
      );
    }
  }

  @override
  void dispose() {
    _qtd.dispose();
    _resp.dispose();
    _notas.dispose();
    super.dispose();
  }

  DateTime? _validadeAuto() => _ficha != null && _ficha!.validadeDias > 0
      ? _data.add(Duration(days: _ficha!.validadeDias))
      : null;

  Future<void> _escolherFicha(FichaTecnica f) async {
    setState(() {
      _ficha = f;
      _validade = _validadeAuto();
      _aCarregar = true;
      _erro = null;
    });
    try {
      final ings = await ref
          .read(lotesRepositoryProvider)
          .ingredientesDaFicha(f.id);
      if (!mounted) return;
      setState(
        () => _ingredientes = [for (final i in ings) _Escolha(i, i.lotes)],
      );
    } on Object catch (e) {
      if (mounted) setState(() => _erro = mensagemAmigavel(e));
    } finally {
      if (mounted) setState(() => _aCarregar = false);
    }
  }

  Future<DateTime?> _escolherData(DateTime inicial, {DateTime? min}) =>
      showDatePicker(
        context: context,
        initialDate: inicial,
        firstDate: min ?? DateTime(2020),
        lastDate: DateTime(2100),
      );

  Future<void> _novoLoteDe(_Escolha e) async {
    final lote = TextEditingController();
    final forn = TextEditingController();
    DateTime? val;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Novo lote — ${e.ing.nome}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: lote,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Lote (como está na embalagem) *',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: forn,
                  decoration: const InputDecoration(labelText: 'Fornecedor'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final d = await _escolherData(
                      val ?? DateTime.now(),
                      min: DateTime.now().subtract(const Duration(days: 30)),
                    );
                    if (d != null) setD(() => val = d);
                  },
                  icon: const Icon(Icons.event),
                  label: Text(
                    val == null
                        ? 'Validade (opcional)'
                        : 'Validade: ${val!.day}/${val!.month}/${val!.year}',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    final texto = lote.text.trim();
    final fornecedor = forn.text;
    lote.dispose();
    forn.dispose();
    if (ok != true || texto.isEmpty) return;
    try {
      final novo = await ref
          .read(lotesRepositoryProvider)
          .registarLoteIngrediente(
            ingredienteId: e.ing.id,
            lote: texto,
            validade: val,
            fornecedor: fornecedor,
          );
      if (!mounted) return;
      setState(() {
        if (!e.lotes.any((l) => l.id == novo.id)) e.lotes.insert(0, novo);
        e.escolhido = novo.id;
      });
    } on Object catch (err) {
      if (mounted) setState(() => _erro = mensagemAmigavel(err));
    }
  }

  Future<void> _guardar() async {
    final f = _ficha;
    if (f == null) return;
    setState(() {
      _aGuardar = true;
      _erro = null;
    });
    try {
      final criado = await ref
          .read(lotesRepositoryProvider)
          .criar(
            fichaId: f.id,
            fichaNome: f.nome,
            data: _data,
            quantidade:
                double.tryParse(_qtd.text.replaceAll(',', '.').trim()) ?? 0,
            validade: _validade,
            responsavel: _resp.text.trim(),
            notas: _notas.text.trim(),
            ingredientes: [
              for (final e in _ingredientes)
                LoteUsado(
                  ingredienteId: e.ing.id,
                  nome: e.ing.nome,
                  lote: e.lote?.lote ?? '',
                  validade: e.lote?.validade,
                  fornecedor: e.lote?.fornecedor ?? '',
                ),
            ],
          );
      ref.invalidate(lotesRecentesProvider);
      if (mounted) Navigator.pop(context, criado);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _aGuardar = false;
          _erro = mensagemAmigavel(e);
        });
      }
    }
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Novo lote de produção', style: tt.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Regista o que fizeste e os lotes dos ingredientes usados — fica '
              'rastreável e podes imprimir a etiqueta com QR.',
              style: tt.bodySmall,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () async {
                final f = await showFichaPickerSheet(context);
                if (f != null) await _escolherFicha(f);
              },
              icon: const Icon(Icons.receipt_long_outlined),
              label: Text(_ficha?.nome ?? 'Escolher o produto'),
            ),
            if (_ficha != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                      ),
                      onPressed: () async {
                        final d = await _escolherData(_data);
                        if (d != null) {
                          setState(() {
                            _data = d;
                            _validade = _validadeAuto();
                          });
                        }
                      },
                      icon: const Icon(Icons.event),
                      label: Text('Produzido: ${_fmt(_data)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _qtd,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Unidades',
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () async {
                  final d = await _escolherData(_validade ?? _data, min: _data);
                  if (d != null) setState(() => _validade = d);
                },
                icon: const Icon(Icons.hourglass_bottom),
                label: Text(
                  _validade == null
                      ? 'Validade (sem prazo na ficha)'
                      : 'Validade: ${_fmt(_validade!)}',
                ),
              ),
              const SizedBox(height: 12),
              Text('Ingredientes e lotes', style: tt.titleSmall),
              if (_aCarregar) const LinearProgressIndicator(),
              if (!_aCarregar && _ingredientes.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Esta ficha ainda não tem ingredientes.',
                    style: tt.bodySmall,
                  ),
                ),
              for (final e in _ingredientes)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: DropdownButtonFormField<String>(
                    initialValue: e.escolhido,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: e.ing.nome,
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: _semLote,
                        child: Text('Sem lote / não sei'),
                      ),
                      for (final l in e.lotes)
                        DropdownMenuItem(
                          value: l.id,
                          child: Text(
                            l.validade == null
                                ? l.lote
                                : '${l.lote} · val. ${_fmt(l.validade!)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const DropdownMenuItem(
                        value: _novoLote,
                        child: Text('＋ Novo lote…'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == _novoLote) {
                        _novoLoteDe(e);
                      } else if (v != null) {
                        setState(() => e.escolhido = v);
                      }
                    },
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _resp,
                decoration: const InputDecoration(
                  labelText: 'Responsável',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notas,
                decoration: const InputDecoration(
                  labelText: 'Notas (opcional)',
                  isDense: true,
                ),
              ),
            ],
            if (_erro != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_erro!, style: TextStyle(color: cs.error)),
              ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: _ficha == null || _aGuardar || _aCarregar
                  ? null
                  : _guardar,
              child: Text(_aGuardar ? 'A guardar…' : 'Criar lote'),
            ),
          ],
        ),
      ),
    );
  }
}
