import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../invoices/domain/invoice_erros.dart';
import '../application/ia_financeira_service.dart';
import '../domain/ia_financeira.dart';
import '../domain/resumo_financeiro.dart';

/// Dicas para melhorar, geradas por IA a partir dos números do período
/// mostrado. Só são pedidas quando a pessoa toca no botão (cada pedido tem
/// um pequeno custo de IA); mudar de período volta ao estado inicial.
class DicasIaCard extends ConsumerStatefulWidget {
  const DicasIaCard({super.key, required this.comparacao});

  final ComparacaoFinanceira comparacao;

  @override
  ConsumerState<DicasIaCard> createState() => _DicasIaCardState();
}

class _DicasIaCardState extends ConsumerState<DicasIaCard> {
  bool _aPensar = false;
  String? _erro;
  DicasFinanceiras? _dicas;

  @override
  void didUpdateWidget(DicasIaCard old) {
    super.didUpdateWidget(old);
    if (old.comparacao.atual.periodo != widget.comparacao.atual.periodo) {
      _dicas = null;
      _erro = null;
    }
  }

  Future<void> _gerar() async {
    final periodo = widget.comparacao.atual.periodo;
    setState(() {
      _aPensar = true;
      _erro = null;
    });
    try {
      final d = await ref
          .read(iaFinanceiraServiceProvider)
          .gerarDicas(widget.comparacao);
      // Se entretanto mudou de período, a resposta já não vale.
      if (!mounted || widget.comparacao.atual.periodo != periodo) return;
      setState(() => _dicas = d);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _erro = mensagemAmigavel(e));
    } finally {
      if (mounted) setState(() => _aPensar = false);
    }
  }

  Color _cor(PrioridadeDica p, ColorScheme cs) => switch (p) {
    PrioridadeDica.alta => cs.error,
    PrioridadeDica.media => cs.tertiary,
    PrioridadeDica.baixa => cs.onSurfaceVariant,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final p = widget.comparacao.atual.periodo;
    final dicas = _dicas;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Dicas para melhorar', style: tt.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Geradas por IA a partir dos números de ${p.label.toLowerCase()} '
              '(${p.intervaloTexto}) e do período anterior. São sugestões: '
              'avalia antes de agir.',
              style: tt.bodySmall,
            ),
            const SizedBox(height: 12),
            if (_aPensar)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (_erro != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_erro!, style: TextStyle(color: cs.error)),
                ),
              if (dicas != null) ...[
                if (dicas.resumo.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(dicas.resumo, style: tt.bodyMedium),
                  ),
                for (final d in dicas.dicas)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6, right: 10),
                          child: Tooltip(
                            message: d.prioridade.label,
                            child: Icon(
                              Icons.circle,
                              size: 10,
                              color: _cor(d.prioridade, cs),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d.titulo, style: tt.titleSmall),
                              Text(d.texto, style: tt.bodyMedium),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              OutlinedButton.icon(
                onPressed: _gerar,
                icon: Icon(dicas == null ? Icons.auto_awesome : Icons.refresh),
                label: Text(
                  dicas == null ? 'Gerar dicas com IA' : 'Gerar de novo',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
