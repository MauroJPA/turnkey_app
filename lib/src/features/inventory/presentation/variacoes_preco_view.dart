import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/money_provider.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../pricing/data/cost_config_repository.dart';
import '../data/variacao_preco_repository.dart';
import '../domain/variacao_preco.dart';

enum _Filtro { subidas, descidas, todas }

/// Variações de preço: o que subiu (ou desceu) numa fatura e que fichas
/// técnicas — e margens — ficam afetadas.
class VariacoesPrecoView extends ConsumerStatefulWidget {
  const VariacoesPrecoView({super.key});

  @override
  ConsumerState<VariacoesPrecoView> createState() => _VariacoesPrecoViewState();
}

class _VariacoesPrecoViewState extends ConsumerState<VariacoesPrecoView> {
  _Filtro _filtro = _Filtro.subidas;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(variacoesPrecoProvider);
    final cfg = ref.watch(costConfigProvider).valueOrNull;
    final limiar = cfg?.alertaPrecoPct ?? 5;
    final iva = cfg?.ivaVendas ?? 0;
    final fmt = ref.watch(moneyFormatProvider);
    final tt = Theme.of(context).textTheme;
    final visto = precosVistosAte();

    return AsyncValueView<List<VariacaoPreco>>(
      value: async,
      onRetry: () => ref.invalidate(variacoesPrecoProvider),
      data: (todas) {
        final lista = [
          for (final v in todas)
            if (switch (_filtro) {
              _Filtro.subidas => v.subidaAcima(limiar),
              _Filtro.descidas => v.pct <= -limiar,
              _Filtro.todas => true,
            })
              v,
        ];
        final porVer = ref.watch(subidasPorVerProvider).length;
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(variacoesPrecoProvider),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(
                  'Quando uma fatura muda o preço de um ingrediente, vês aqui o '
                  'que mudou e que fichas técnicas ficam mais caras ou mais '
                  'baratas. Aviso a partir de ${limiar.toStringAsFixed(0)}% '
                  '(muda em Configurações → Percentuais de custo).',
                  style: tt.bodySmall,
                ),
              ),
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  children: [
                    for (final f in _Filtro.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(switch (f) {
                            _Filtro.subidas => 'Subidas',
                            _Filtro.descidas => 'Descidas',
                            _Filtro.todas => 'Todas',
                          }),
                          selected: _filtro == f,
                          onSelected: (_) => setState(() => _filtro = f),
                        ),
                      ),
                    if (porVer > 0)
                      ActionChip(
                        avatar: const Icon(Icons.done_all, size: 18),
                        label: Text('Marcar $porVer como vistas'),
                        onPressed: () {
                          marcarPrecosVistos();
                          ref.invalidate(variacoesPrecoProvider);
                          setState(() {});
                        },
                      ),
                  ],
                ),
              ),
              if (lista.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      todas.isEmpty
                          ? 'Ainda sem variações de preço. Aparecem quando '
                                'aplicas uma fatura com preços diferentes.'
                          : 'Nada neste filtro nos últimos 90 dias.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              for (final v in lista)
                _CartaoVariacao(
                  v: v,
                  nova: visto == null || v.criada.isAfter(visto),
                  iva: iva,
                  fmt: fmt,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CartaoVariacao extends StatelessWidget {
  const _CartaoVariacao({
    required this.v,
    required this.nova,
    required this.iva,
    required this.fmt,
  });

  final VariacaoPreco v;
  final bool nova;
  final double iva;
  final MoneyFmt fmt;

  static String _data(DateTime d) {
    final l = d.toLocal();
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(l.day)}/${dois(l.month)}/${l.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final cor = v.subiu ? cs.error : Colors.green;
    final sinal = v.pct > 0 ? '+' : '';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(
          v.subiu ? Icons.trending_up : Icons.trending_down,
          color: cor,
        ),
        title: Text(
          v.ingredienteNome.isEmpty ? 'Ingrediente' : v.ingredienteNome,
          style: nova ? const TextStyle(fontWeight: FontWeight.bold) : null,
        ),
        subtitle: Text(
          '${fmt(v.antes)} → ${fmt(v.depois)} /kg · ${_data(v.criada)}'
          '${v.afetadas.isEmpty ? '' : ' · ${v.afetadas.length} ficha(s)'}',
        ),
        trailing: Text(
          '$sinal${v.pct.toStringAsFixed(1)}%',
          style: tt.titleMedium?.copyWith(
            color: cor,
            fontWeight: FontWeight.bold,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (v.afetadas.isEmpty)
            Text(
              'Nenhuma ficha técnica usa este ingrediente (ou o custo não mudou).',
              style: tt.bodySmall,
            )
          else ...[
            Text('Fichas afetadas', style: tt.labelLarge),
            const SizedBox(height: 4),
            for (final f in v.afetadas)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(f.nome)),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${fmt(f.custoAntes)} → ${fmt(f.custoDepois)}'),
                        if (f.margem(f.custoAntes, iva) != null)
                          Text(
                            'margem ${f.margem(f.custoAntes, iva)!.toStringAsFixed(0)}% '
                            '→ ${f.margem(f.custoDepois, iva)!.toStringAsFixed(0)}%',
                            style: tt.bodySmall?.copyWith(
                              color: f.custoDepois > f.custoAntes
                                  ? cs.error
                                  : Colors.green,
                            ),
                          )
                        else
                          Text('sem preço de venda', style: tt.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
