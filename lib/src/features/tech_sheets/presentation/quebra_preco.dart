import 'package:flutter/material.dart';

import '../../../core/formatting/money_provider.dart';
import '../../pricing/domain/cost_config.dart';

/// Quebra do preço da ficha técnica, **sempre sobre o preço sem IVA**: o IVA
/// é cobrado em cima do preço limpo e por isso entra por último. Mostra o
/// esperado (pelos percentuais) lado a lado com o real (o preço de venda
/// praticado) e, por baixo, o simulador de desconto para revendedores.
class QuebraPrecoTile extends StatelessWidget {
  const QuebraPrecoTile({
    super.key,
    required this.custo,
    required this.config,
    required this.fmt,
    this.precoVenda = 0,
    this.cmvReal,
    this.custoEmbalagem = 0,
  });

  /// Custo por unidade (matéria-prima + embalagem).
  final double custo;

  /// A parte do [custo] que é embalagem (linha à parte na quebra).
  final double custoEmbalagem;

  /// Preço de venda ao público (com IVA), como está na ficha.
  final double precoVenda;
  final double? cmvReal;
  final CostConfig config;
  final MoneyFmt fmt;

  static String _pct(double v) => '${v.toStringAsFixed(1)}%';

  Widget _celula(
    BuildContext context,
    double? valor,
    double? pct, {
    bool negrito = false,
    Color? cor,
  }) {
    final tt = Theme.of(context).textTheme;
    if (valor == null) {
      return SizedBox(
        width: 84,
        child: Text('—', textAlign: TextAlign.end, style: tt.bodyMedium),
      );
    }
    final estilo = TextStyle(
      fontWeight: negrito ? FontWeight.bold : null,
      color: cor,
    );
    return SizedBox(
      width: 84,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(fmt(valor), style: estilo),
          if (pct != null)
            Text(_pct(pct), style: tt.bodySmall?.copyWith(color: cor)),
        ],
      ),
    );
  }

  Widget _linha(
    BuildContext context,
    String nome,
    double? esperado,
    double? real, {
    double? esperadoPct,
    double? realPct,
    bool negrito = false,
    Color? corReal,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              nome,
              style: negrito
                  ? const TextStyle(fontWeight: FontWeight.bold)
                  : null,
            ),
          ),
          _celula(context, esperado, esperadoPct, negrito: negrito),
          _celula(context, real, realPct, negrito: negrito, cor: corReal),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final q = config.quebraComparada(
      custo,
      precoVenda,
      custoEmbalagem: custoEmbalagem,
    );
    final semReal = q.precoReal == null;
    final temIva = q.ivaPct > 0;
    final ivaTxt = q.ivaPct == q.ivaPct.roundToDouble()
        ? q.ivaPct.toStringAsFixed(0)
        : q.ivaPct.toStringAsFixed(1);
    return ExpansionTile(
      title: const Text('Quebra do preço (sem IVA)'),
      subtitle: Text(
        config.cmvPercent <= 0
            ? 'Percentuais somam ≥ 100% — ajusta em Configurações'
            : 'CMV esperado ${config.cmvPercent.toStringAsFixed(1)}%'
                  '${cmvReal == null ? '' : ' · real ${cmvReal!.toStringAsFixed(1)}%'}',
      ),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
      expandedAlignment: Alignment.centerLeft,
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Expanded(child: SizedBox.shrink()),
                          SizedBox(
                            width: 84,
                            child: Text(
                              'Esperado',
                              textAlign: TextAlign.end,
                              style: tt.labelMedium,
                            ),
                          ),
                          SizedBox(
                            width: 84,
                            child: Text(
                              'Real',
                              textAlign: TextAlign.end,
                              style: tt.labelMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // rubricas a 0% (ex.: Despesas fixas vazias) não aparecem:
                    // menos linhas, mais fácil de ler
                    for (final l in q.linhas.where(
                      (l) =>
                          l.nome == 'Matéria-prima' ||
                          l.nome == 'Margem de lucro' ||
                          l.esperado != 0 ||
                          (l.real ?? 0) != 0,
                    ))
                      _linha(
                        context,
                        l.nome,
                        l.esperado,
                        l.real,
                        esperadoPct: l.esperadoPct,
                        realPct: l.realPct,
                        corReal: (l.real != null && l.real! < 0)
                            ? cs.error
                            : null,
                      ),
                    const Divider(),
                    _linha(
                      context,
                      temIva ? 'PREÇO SEM IVA' : 'PREÇO FINAL',
                      q.precoEsperado,
                      q.precoReal,
                      esperadoPct: 100,
                      realPct: semReal ? null : 100,
                      negrito: true,
                    ),
                    if (temIva) ...[
                      _linha(
                        context,
                        'IVA ($ivaTxt%)',
                        q.precoEsperadoComIva - q.precoEsperado,
                        q.precoRealComIva == null
                            ? null
                            : q.precoRealComIva! - q.precoReal!,
                      ),
                      const Divider(),
                      _linha(
                        context,
                        'PREÇO FINAL (com IVA)',
                        q.precoEsperadoComIva,
                        q.precoRealComIva,
                        negrito: true,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            [
              if (semReal)
                'Define o preço de venda para ver a coluna Real.'
              else
                'Esperado = preço sugerido pelos percentuais. Real = o preço '
                    'de venda que praticas (sem o IVA): a matéria-prima é o '
                    'custo verdadeiro e a margem de lucro é o que sobra.',
              if (temIva)
                'O IVA é calculado em cima do preço sem IVA, por isso entra '
                    'por último.'
              else
                'Define o IVA das vendas em Configurações → Percentuais de '
                    'custo para ver o preço final com IVA.',
            ].join(' '),
            style: tt.bodySmall,
          ),
        ),
        _SimuladorRevenda(
          custo: custo,
          config: config,
          fmt: fmt,
          precoVenda: precoVenda,
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// "O que posso cobrar?": preço de equilíbrio (sem lucro) e simulador de
/// desconto para revendedores — o desconto é dado no preço sem IVA e o IVA
/// soma-se depois.
class _SimuladorRevenda extends StatefulWidget {
  const _SimuladorRevenda({
    required this.custo,
    required this.config,
    required this.fmt,
    required this.precoVenda,
  });

  final double custo;
  final CostConfig config;
  final MoneyFmt fmt;
  final double precoVenda;

  @override
  State<_SimuladorRevenda> createState() => _SimuladorRevendaState();
}

class _SimuladorRevendaState extends State<_SimuladorRevenda> {
  final _desconto = TextEditingController();
  double _d = 0;

  @override
  void dispose() {
    _desconto.dispose();
    super.dispose();
  }

  void _set(double v) {
    final d = v.clamp(0, 100).toDouble();
    setState(() => _d = d);
    final t = d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toString();
    _desconto.text = d == 0 ? '' : t;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final c = widget.config;
    final fmt = widget.fmt;
    final temVenda = widget.precoVenda > 0;
    // preço de partida (sem IVA): o de venda praticado, ou o sugerido
    final base = temVenda
        ? c.semIva(widget.precoVenda)
        : c.precoSugerido(widget.custo);
    if (base <= 0 || widget.custo <= 0) return const SizedBox.shrink();
    final equilibrio = c.precoEquilibrio(widget.custo);
    final liquido = base * (1 - _d / 100);
    final iva = c.comIva(liquido) - liquido;
    final lucro = c.lucroSemIva(widget.custo, liquido);
    final margem = liquido > 0 ? lucro / liquido * 100 : 0.0;
    final descontoMax = equilibrio > 0 && base > equilibrio
        ? (1 - equilibrio / base) * 100
        : 0.0;
    final prejuizo = lucro < 0;

    Widget linha(
      String nome,
      String valor, {
      bool negrito = false,
      Color? cor,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              nome,
              style: negrito
                  ? const TextStyle(fontWeight: FontWeight.bold)
                  : null,
            ),
          ),
          Text(
            valor,
            style: TextStyle(
              fontWeight: negrito ? FontWeight.bold : null,
              color: cor,
            ),
          ),
        ],
      ),
    );

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 440),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quanto posso cobrar? (revenda)', style: tt.titleSmall),
          const SizedBox(height: 4),
          Text(
            'O desconto é dado no preço sem IVA; o IVA soma-se depois.',
            style: tt.bodySmall,
          ),
          const SizedBox(height: 8),
          linha(
            temVenda ? 'Preço atual sem IVA' : 'Preço sugerido sem IVA',
            fmt(base),
          ),
          linha('Preço de equilíbrio sem IVA (lucro 0)', fmt(equilibrio)),
          if (descontoMax > 0)
            linha(
              'Desconto máximo antes de dar prejuízo',
              '${descontoMax.toStringAsFixed(0)}%',
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _desconto,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Desconto',
                    suffixText: '%',
                    isDense: true,
                  ),
                  onChanged: (v) => setState(
                    () => _d =
                        (double.tryParse(v.replaceAll(',', '.').trim()) ?? 0)
                            .clamp(0, 100)
                            .toDouble(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final p in const [5, 10, 15, 20])
                      ActionChip(
                        label: Text('$p%'),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _set(p.toDouble()),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          linha('Preço sem IVA', fmt(liquido), negrito: true),
          if (c.ivaVendas > 0) ...[
            linha('IVA', fmt(iva)),
            linha('A cobrar (com IVA)', fmt(liquido + iva), negrito: true),
          ],
          const Divider(height: 16),
          linha(
            'Lucro por unidade (sem IVA)',
            fmt(lucro),
            negrito: true,
            cor: prejuizo ? cs.error : null,
          ),
          linha(
            'Margem sobre o preço sem IVA',
            '${margem.toStringAsFixed(1)}%',
            cor: prejuizo ? cs.error : null,
          ),
          if (prejuizo)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Abaixo do preço de equilíbrio: a este preço dás prejuízo.',
                style: tt.bodySmall?.copyWith(color: cs.error),
              ),
            ),
        ],
      ),
    );
  }
}
