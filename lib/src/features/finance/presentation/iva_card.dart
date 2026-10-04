import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/money_provider.dart';
import '../application/iva_providers.dart';
import '../domain/periodo.dart';

const _sem = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];

/// "IVA a separar": o IVA cobrado nas vendas menos o IVA das compras = o que
/// há a entregar ao Estado. Com a lista dia a dia.
class IvaCard extends ConsumerWidget {
  const IvaCard({super.key, required this.periodo});

  final Periodo periodo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final fmt = ref.watch(moneyFormatProvider);
    final async = ref.watch(ivaPeriodoProvider(periodo));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: async.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(8),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => Text(
            'Não foi possível calcular o IVA.',
            style: TextStyle(color: cs.error),
          ),
          data: (d) {
            final r = d.resumo;
            Widget linha(String k, String v, {bool forte = false, Color? cor}) {
              final st = forte ? tt.titleSmall : tt.bodyMedium;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(k, style: st?.copyWith(color: cor)),
                    Text(
                      v,
                      style: st?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cor,
                      ),
                    ),
                  ],
                ),
              );
            }

            final entregar = r.aEntregar;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_balance_outlined, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('IVA a separar', style: tt.titleMedium),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Do dinheiro que entrou, esta parte não é teu: é do Estado.',
                  style: tt.bodySmall,
                ),
                const SizedBox(height: 8),
                linha('IVA cobrado nas vendas', fmt(r.ivaLiquidado)),
                linha(
                  'IVA das compras (faturas confirmadas)',
                  '− ${fmt(r.ivaDedutivel)}',
                ),
                const Divider(height: 16),
                linha(
                  entregar >= 0 ? 'A entregar ao Estado' : 'Crédito de IVA',
                  fmt(entregar.abs()),
                  forte: true,
                  cor: entregar > 0 ? cs.error : cs.primary,
                ),
                if (r.vendidoComIva > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'De ${fmt(r.vendidoComIva)} vendidos (com IVA), '
                      '${fmt(r.ivaLiquidado)} é IVA.',
                      style: tt.bodySmall,
                    ),
                  ),
                if (r.temEstimativas || r.incompleto)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      [
                        if (r.temEstimativas)
                          '${r.linhasEstimadas} linha(s) de venda estimadas com '
                              '${d.taxaPadrao.toStringAsFixed(d.taxaPadrao == d.taxaPadrao.roundToDouble() ? 0 : 1)}% '
                              '(o Vendus não indicou o valor sem IVA).',
                        if (r.incompleto)
                          '${r.linhasDesconhecidas} linha(s) de venda sem valor '
                              'sem IVA e sem taxa definida: o IVA delas não '
                              'está contado. Define a taxa em Configurações → '
                              'Percentuais de custo → IVA das vendas.',
                      ].join(' '),
                      style: tt.bodySmall?.copyWith(
                        color: r.incompleto ? cs.error : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (r.dias.length > 1 || periodo.dias > 1)
                  Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Dia a dia'),
                      children: [
                        if (r.dias.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(8),
                            child: Text('Sem vendas neste período.'),
                          ),
                        for (final dia in r.dias.reversed)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${_sem[dia.dia.weekday - 1]} '
                                    '${dia.dia.day.toString().padLeft(2, '0')}/'
                                    '${dia.dia.month.toString().padLeft(2, '0')}',
                                  ),
                                ),
                                Text(fmt(dia.bruto)),
                                SizedBox(
                                  width: 90,
                                  child: Text(
                                    'IVA ${fmt(dia.iva)}',
                                    textAlign: TextAlign.right,
                                    style: tt.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
