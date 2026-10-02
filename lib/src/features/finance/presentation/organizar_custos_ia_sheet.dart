import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/money_provider.dart';
import '../../invoices/domain/invoice_erros.dart';
import '../application/custos_fixos_providers.dart';
import '../application/ia_financeira_service.dart';
import '../domain/custo_fixo.dart';
import '../domain/ia_financeira.dart';

/// Pede à IA para organizar os custos em fixos / variáveis e mostra as
/// sugestões; a pessoa escolhe quais aplicar (nada muda sem confirmar).
Future<void> showOrganizarCustosIaSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 720),
    builder: (_) => const _Sheet(),
  );
}

class _Sheet extends ConsumerStatefulWidget {
  const _Sheet();

  @override
  ConsumerState<_Sheet> createState() => _SheetState();
}

class _SheetState extends ConsumerState<_Sheet> {
  bool _aPensar = true;
  bool _aGuardar = false;
  String? _erro;
  List<SugestaoCusto> _sugestoes = const [];
  final Set<String> _aplicar = {};

  @override
  void initState() {
    super.initState();
    _pedir();
  }

  Future<void> _pedir() async {
    setState(() {
      _aPensar = true;
      _erro = null;
    });
    try {
      final s = await ref.read(iaFinanceiraServiceProvider).classificarCustos();
      if (!mounted) return;
      setState(() {
        _sugestoes = s;
        _aplicar
          ..clear()
          ..addAll([
            for (final x in s)
              if (x.muda) x.id,
          ]);
        _aPensar = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = mensagemAmigavel(e);
        _aPensar = false;
      });
    }
  }

  Future<void> _guardar() async {
    setState(() => _aGuardar = true);
    try {
      await ref.read(custosFixosActionsProvider).definirTipos({
        for (final s in _sugestoes)
          if (_aplicar.contains(s.id)) s.id: s.tipoSugerido,
      });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_aplicar.length} custo(s) reclassificado(s).'),
        ),
      );
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _aGuardar = false;
        _erro = mensagemAmigavel(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fmt = ref.watch(moneyFormatProvider);
    final mudam = _sugestoes.where((s) => s.muda).toList();
    final iguais = _sugestoes.where((s) => !s.muda).toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Organizar custos com IA', style: tt.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Fixo = não dá para eliminar sem fechar ou mudar o negócio. '
              'Variável = dá para reduzir ou cortar (por um período ou para '
              'sempre) e/ou muda com as vendas. É só uma sugestão: tu decides.',
              style: tt.bodySmall,
            ),
            const SizedBox(height: 12),
            if (_aPensar)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('A IA está a analisar os teus custos…'),
                    ],
                  ),
                ),
              )
            else if (_erro != null)
              Card(
                color: cs.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _erro!,
                        style: TextStyle(color: cs.onErrorContainer),
                      ),
                      TextButton(
                        onPressed: _aGuardar ? null : _pedir,
                        child: const Text('Tentar de novo'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (mudam.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'A IA concorda com a classificação atual de todos '
                          'os custos.',
                          style: tt.bodyMedium,
                        ),
                      )
                    else ...[
                      Text(
                        'Sugere mudar (${mudam.length})',
                        style: tt.titleSmall,
                      ),
                      for (final s in mudam) _tile(s, fmt, comCaixa: true),
                    ],
                    if (iguais.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Já estão bem classificados (${iguais.length})',
                        style: tt.titleSmall,
                      ),
                      for (final s in iguais) _tile(s, fmt, comCaixa: false),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 12),
            if (!_aPensar && _erro == null)
              FilledButton.icon(
                onPressed: _aplicar.isEmpty || _aGuardar ? null : _guardar,
                icon: const Icon(Icons.check),
                label: Text(
                  _aplicar.isEmpty
                      ? 'Nada a aplicar'
                      : 'Aplicar ${_aplicar.length} alteração(ões)',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tile(SugestaoCusto s, MoneyFmt fmt, {required bool comCaixa}) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final variavel = s.tipoSugerido == TipoCusto.variavel;
    final acaoTexto = switch (s.acao) {
      AcaoCusto.manter => null,
      _ => s.acao.label,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (comCaixa)
                Checkbox(
                  value: _aplicar.contains(s.id),
                  onChanged: (v) => setState(() {
                    if (v ?? false) {
                      _aplicar.add(s.id);
                    } else {
                      _aplicar.remove(s.id);
                    }
                  }),
                )
              else
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.check_circle_outline, size: 20),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.nome,
                            style: tt.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${fmt(s.valorMensal)}/mês',
                          style: tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.muda
                          ? 'Passa de ${s.tipoAtual.label} a ${s.tipoSugerido.label}'
                          : s.tipoSugerido.label,
                      style: tt.bodySmall?.copyWith(
                        color: s.muda ? cs.primary : cs.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (s.motivo.isNotEmpty)
                      Text(s.motivo, style: tt.bodySmall),
                    if (variavel && acaoTexto != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Se apertar: $acaoTexto'
                          '${s.dica.isNotEmpty ? ' — ${s.dica}' : ''}',
                          style: tt.bodySmall?.copyWith(color: cs.tertiary),
                        ),
                      )
                    else if (s.dica.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Dica: ${s.dica}',
                          style: tt.bodySmall?.copyWith(color: cs.tertiary),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
