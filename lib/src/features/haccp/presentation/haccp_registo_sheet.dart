import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_user.dart';
import '../../invoices/domain/invoice_erros.dart';
import '../application/haccp_providers.dart';
import '../domain/haccp.dart';

String _dmy(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Regista que um controlo foi feito (temperatura medida, limpeza feita,
/// inspeção de pragas, revisão do extintor…).
Future<void> showHaccpRegistoSheet(
  BuildContext context,
  ControloHaccp controlo,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => _RegistoSheet(controlo: controlo),
  );
}

class _RegistoSheet extends ConsumerStatefulWidget {
  const _RegistoSheet({required this.controlo});
  final ControloHaccp controlo;

  @override
  ConsumerState<_RegistoSheet> createState() => _RegistoSheetState();
}

class _RegistoSheetState extends ConsumerState<_RegistoSheet> {
  final _valor = TextEditingController();
  final _responsavel = TextEditingController();
  final _notas = TextEditingController();
  final _acao = TextEditingController();
  bool _conformeManual = true;
  DateTime? _proximo;
  bool _aGuardar = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _responsavel.text = ref.read(currentUserNameProvider) ?? '';
  }

  @override
  void dispose() {
    _valor.dispose();
    _responsavel.dispose();
    _notas.dispose();
    _acao.dispose();
    super.dispose();
  }

  ControloHaccp get _c => widget.controlo;

  double? get _valorNum {
    final t = _valor.text.trim().replaceAll(',', '.');
    return t.isEmpty ? null : double.tryParse(t);
  }

  /// Nas temperaturas a conformidade sai do valor medido; nos outros controlos
  /// é a pessoa que diz.
  bool get _conforme {
    if (_c.medeValor) {
      final v = _valorNum;
      return v == null ? true : _c.valorConforme(v);
    }
    return _conformeManual;
  }

  Future<void> _escolherProximo() async {
    final hoje = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _proximo ?? hoje.add(const Duration(days: 30)),
      firstDate: DateTime(hoje.year, hoje.month, hoje.day),
      lastDate: DateTime(hoje.year + 10),
    );
    if (d != null) setState(() => _proximo = d);
  }

  Future<void> _guardar() async {
    if (_c.medeValor && _valorNum == null) {
      setState(() => _erro = 'Indica a temperatura medida.');
      return;
    }
    if (!_conforme && _acao.text.trim().isEmpty) {
      setState(() => _erro = 'Indica a ação corretiva (o que fizeste).');
      return;
    }
    setState(() {
      _aGuardar = true;
      _erro = null;
    });
    try {
      await ref
          .read(haccpActionsProvider)
          .registar(
            controloId: _c.id,
            dataHora: DateTime.now(),
            valor: _c.medeValor ? _valorNum : null,
            conforme: _conforme,
            responsavel: _responsavel.text,
            notas: _notas.text,
            acaoCorretiva: _conforme ? '' : _acao.text,
            proximoVencimento: _proximo,
          );
      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _aGuardar = false;
        _erro = mensagemAmigavel(e);
      });
    }
  }

  String get _rotuloConforme => switch (_c.tipo) {
    TipoControlo.praga => 'Sem sinais de pragas',
    TipoControlo.limpeza => 'Limpeza feita e correta',
    TipoControlo.manutencao => 'Tudo em ordem',
    _ => 'Conforme',
  };

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final u = _c.unidade.isEmpty ? '°C' : _c.unidade;
    final v = _valorNum;
    final fora = _c.medeValor && v != null && !_c.valorConforme(v);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_c.nome, style: tt.titleLarge),
            if (_c.instrucoes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(_c.instrucoes, style: tt.bodySmall),
              ),
            const SizedBox(height: 12),
            if (_c.medeValor) ...[
              TextField(
                controller: _valor,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Temperatura medida ($u)',
                  helperText: _c.limitesTexto.isEmpty
                      ? null
                      : 'Limites: ${_c.limitesTexto}',
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (fora)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Fora dos limites — fica registado como não conformidade.',
                    style: TextStyle(color: cs.error),
                  ),
                ),
            ] else
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_rotuloConforme),
                subtitle: _conformeManual
                    ? null
                    : const Text('Fica registado como não conformidade.'),
                value: _conformeManual,
                onChanged: _aGuardar
                    ? null
                    : (x) => setState(() => _conformeManual = x),
              ),
            if (!_conforme) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _acao,
                maxLength: 500,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Ação corretiva',
                  helperText: 'O que fizeste ou vais fazer para resolver.',
                ),
              ),
            ],
            if (_c.tipo == TipoControlo.manutencao) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                ),
                onPressed: _aGuardar ? null : _escolherProximo,
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  _proximo == null
                      ? 'Próxima revisão / validade (opcional)'
                      : 'Próxima: ${_dmy(_proximo!)}',
                ),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _responsavel,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Quem fez'),
            ),
            TextField(
              controller: _notas,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Notas (opcional)'),
            ),
            if (_erro != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_erro!, style: TextStyle(color: cs.error)),
              ),
            FilledButton.icon(
              onPressed: _aGuardar ? null : _guardar,
              icon: const Icon(Icons.check),
              label: Text(_aGuardar ? 'A guardar…' : 'Registar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Resolve uma não conformidade: pede o que foi feito.
Future<void> resolverNaoConformidade(
  BuildContext context,
  WidgetRef ref,
  RegistoHaccp r,
) async {
  final acao = await showDialog<String>(
    context: context,
    builder: (_) => _ResolverDialog(inicial: r.acaoCorretiva),
  );
  if (acao == null) return;
  await ref.read(haccpActionsProvider).resolver(r.id, acaoCorretiva: acao);
}

class _ResolverDialog extends StatefulWidget {
  const _ResolverDialog({required this.inicial});
  final String inicial;

  @override
  State<_ResolverDialog> createState() => _ResolverDialogState();
}

class _ResolverDialogState extends State<_ResolverDialog> {
  late final _acao = TextEditingController(text: widget.inicial);

  @override
  void dispose() {
    _acao.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Resolver não conformidade'),
      content: TextField(
        controller: _acao,
        maxLength: 500,
        maxLines: 3,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'O que foi feito para resolver',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _acao.text),
          child: const Text('Marcar como resolvida'),
        ),
      ],
    );
  }
}
