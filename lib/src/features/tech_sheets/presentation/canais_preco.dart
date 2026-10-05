import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/mensagem_amigavel.dart';
import '../../../core/formatting/money_provider.dart';
import '../../pricing/data/canal_venda_repository.dart';
import '../../pricing/domain/canal_venda.dart';
import '../../pricing/domain/cost_config.dart';
import 'canal_sheet.dart';

/// Preços por canal de venda: a loja, as plataformas de entrega, os
/// revendedores… Cada canal tem as suas taxas em cascata. Para cada um mostra
/// o preço a cobrar para manteres o lucro da loja (preço limpo + taxas + IVA no
/// fim) e o lucro se o vendes ao mesmo preço da loja.
class CanaisPrecoTile extends ConsumerWidget {
  const CanaisPrecoTile({
    super.key,
    required this.custo,
    required this.config,
    required this.fmt,
    required this.podeEditar,
    this.custoPlataforma,
    this.precoVenda = 0,
  });

  /// Custo por unidade (matéria-prima + embalagem).
  final double custo;

  /// Custo se o canal usar a embalagem para plataformas (`null` = a ficha
  /// não tem essa embalagem).
  final double? custoPlataforma;

  /// Preço de venda ao público (com IVA); 0 = ainda não definido.
  final double precoVenda;
  final CostConfig config;
  final MoneyFmt fmt;
  final bool podeEditar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final canais = ref.watch(canaisVendaProvider);
    final temVenda = precoVenda > 0;
    final base = temVenda
        ? config.semIva(precoVenda)
        : config.precoSugerido(custo);
    final lista = canais.valueOrNull ?? const <CanalVenda>[];

    Future<void> editar([CanalVenda? c]) async {
      await showCanalSheet(context, existente: c);
    }

    return ExpansionTile(
      title: const Text('Preços por canal (plataformas e terceiros)'),
      subtitle: Text(
        lista.isEmpty
            ? 'Loja · adiciona plataformas e revendedores'
            : 'Loja + ${lista.length} ${lista.length == 1 ? 'canal' : 'canais'}',
      ),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
      expandedAlignment: Alignment.centerLeft,
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (base <= 0 || custo <= 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Preciso do custo da ficha e de um preço de venda (ou dos '
              'percentuais em Configurações) para calcular os canais.',
              style: tt.bodySmall,
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Parte do preço da loja sem IVA: ${fmt(base)}'
              '${temVenda ? '' : ' (sugerido)'}. O IVA soma-se sempre no fim, '
              'em cima do preço limpo.',
              style: tt.bodySmall,
            ),
          ),
          _CartaoCanal(
            nome: 'Loja física',
            resumo: 'sem taxas',
            canal: const CanalVenda(id: '', nome: 'Loja física'),
            base: base,
            custo: custo,
            custoPlataforma: custoPlataforma,
            config: config,
            fmt: fmt,
          ),
          for (final c in lista)
            _CartaoCanal(
              nome: c.nome,
              resumo: c.resumo,
              canal: c,
              base: base,
              custo: custo,
              custoPlataforma: custoPlataforma,
              config: config,
              fmt: fmt,
              onEditar: podeEditar ? () => editar(c) : null,
            ),
        ],
        if (canais.hasError)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              mensagemAmigavel(canais.error!),
              style: tt.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        if (podeEditar)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => editar(),
              icon: const Icon(Icons.add),
              label: const Text('Novo canal (plataforma, revendedor…)'),
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _CartaoCanal extends StatelessWidget {
  const _CartaoCanal({
    required this.nome,
    required this.resumo,
    required this.canal,
    required this.base,
    required this.custo,
    required this.config,
    required this.fmt,
    this.custoPlataforma,
    this.onEditar,
  });

  final String nome;
  final String resumo;
  final CanalVenda canal;

  /// Preço da loja sem IVA (o que queremos receber).
  final double base;
  final double custo;
  final double? custoPlataforma;
  final CostConfig config;
  final MoneyFmt fmt;
  final VoidCallback? onEditar;

  static String _pct(double v) => '${v.toStringAsFixed(1)}%';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final custoCanal = canal.embalagemPlataforma && custoPlataforma != null
        ? custoPlataforma!
        : custo;
    final fator = 1 - config.somaCustos / 100;
    // receita que mantém o lucro da loja, mesmo com a embalagem extra
    final receitaAlvo = fator > 0 ? base + (custoCanal - custo) / fator : base;
    final recomendado = canal.paraReceber(receitaAlvo);
    final aoPrecoLoja = canal.aoPreco(base);

    Widget linha(
      String nome,
      String valor, {
      bool negrito = false,
      Color? cor,
      String? extra,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                valor,
                style: TextStyle(
                  fontWeight: negrito ? FontWeight.bold : null,
                  color: cor,
                ),
              ),
              if (extra != null)
                Text(extra, style: tt.bodySmall?.copyWith(color: cor)),
            ],
          ),
        ],
      ),
    );

    // --- cenário A: preço recomendado (mantém o lucro) -----------------------
    Widget cenarioA() {
      if (recomendado == null) {
        return Text(
          'Há uma taxa de 100% ou mais: não há preço que chegue.',
          style: tt.bodySmall?.copyWith(color: cs.error),
        );
      }
      final r = recomendado;
      final ivaVal = config.comIva(r.precoCliente) - r.precoCliente;
      final lucro = config.lucroSemIva(custoCanal, r.receita);
      final estrutura =
          r.receita * config.somaCustos / 100;
      final temIva = config.ivaVendas > 0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          linha('Preço sem IVA', fmt(r.precoCliente)),
          if (temIva)
            linha('IVA (${config.ivaVendas.toStringAsFixed(0)}%)', fmt(ivaVal)),
          linha(
            temIva ? 'A cobrar ao cliente (com IVA)' : 'A cobrar ao cliente',
            fmt(config.comIva(r.precoCliente)),
            negrito: true,
            cor: cs.primary,
          ),
          if (r.taxas.isNotEmpty) ...[
            const Divider(height: 14),
            for (final t in r.taxas)
              linha('− ${t.nome}', fmt(t.valor), cor: cs.error),
            linha(
              'Chega a nós (sem IVA)',
              fmt(r.receita),
              extra: '${_pct(100 - r.totalTaxasPercent)} do preço',
            ),
          ],
          const SizedBox(height: 6),
          _Barra(
            total: r.precoCliente,
            segmentos: [
              if (r.totalTaxas > 0) _Seg('Taxas', r.totalTaxas, cs.error),
              _Seg('Custo', custoCanal, cs.tertiary),
              _Seg('Estrutura', estrutura, cs.secondary),
              if (lucro > 0) _Seg('Lucro', lucro, Colors.green),
            ],
            fmt: fmt,
          ),
          const SizedBox(height: 4),
          linha(
            'Lucro por unidade',
            fmt(lucro),
            negrito: true,
            cor: lucro < 0 ? cs.error : null,
            extra: r.receita > 0
                ? 'margem ${_pct(lucro / r.receita * 100)}'
                : null,
          ),
        ],
      );
    }

    // --- cenário B: ao mesmo preço da loja ------------------------------------
    Widget cenarioB() {
      if (canal.taxas.isEmpty && custoCanal == custo) {
        return const SizedBox.shrink();
      }
      final lucro = config.lucroSemIva(custoCanal, aoPrecoLoja.receita);
      final eq = config.precoEquilibrio(custoCanal);
      final maxTaxas = base > 0 && eq > 0 ? (1 - eq / base) * 100 : 0.0;
      final prejuizo = lucro < 0;
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('E se vendo ao preço da loja?', style: tt.labelLarge),
            const SizedBox(height: 4),
            linha(
              'Chega a nós (sem IVA)',
              fmt(aoPrecoLoja.receita),
              extra: aoPrecoLoja.totalTaxas > 0
                  ? '− ${fmt(aoPrecoLoja.totalTaxas)} de taxas'
                  : null,
            ),
            linha(
              'Lucro por unidade',
              fmt(lucro),
              negrito: true,
              cor: prejuizo ? cs.error : null,
              extra: aoPrecoLoja.receita > 0
                  ? 'margem ${_pct(lucro / aoPrecoLoja.receita * 100)}'
                  : null,
            ),
            if (canal.taxas.isNotEmpty && maxTaxas > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Aguenta taxas até ${_pct(maxTaxas)} do preço antes de dar '
                  'prejuízo (este canal paga ${_pct(aoPrecoLoja.totalTaxasPercent)}).',
                  style: tt.bodySmall,
                ),
              ),
            if (prejuizo)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'A este preço dás prejuízo: sobe o preço neste canal ou '
                  'renegoceia a taxa.',
                  style: tt.bodySmall?.copyWith(color: cs.error),
                ),
              ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 440),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(nome, style: tt.titleSmall)),
              if (onEditar != null)
                IconButton(
                  tooltip: 'Editar canal',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: onEditar,
                ),
            ],
          ),
          Text(resumo, style: tt.bodySmall),
          const SizedBox(height: 8),
          cenarioA(),
          cenarioB(),
        ],
      ),
    );
  }
}

class _Seg {
  const _Seg(this.nome, this.valor, this.cor);
  final String nome;
  final double valor;
  final Color cor;
}

/// Para onde vai o preço (sem IVA) pago pelo cliente: taxas, custo,
/// estrutura e lucro.
class _Barra extends StatelessWidget {
  const _Barra({
    required this.total,
    required this.segmentos,
    required this.fmt,
  });

  final double total;
  final List<_Seg> segmentos;
  final MoneyFmt fmt;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final visiveis = [
      for (final s in segmentos)
        if (s.valor > 0) s,
    ];
    if (total <= 0 || visiveis.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 10,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final s in visiveis)
                  Expanded(
                    flex: (s.valor / total * 1000).round().clamp(1, 1000),
                    child: ColoredBox(color: s.cor),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 2,
          children: [
            for (final s in visiveis)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: s.cor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${s.nome} ${(s.valor / total * 100).toStringAsFixed(0)}%',
                    style: tt.bodySmall,
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
