import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/errors/mensagem_amigavel.dart';
import '../../../core/formatting/money_provider.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../pricing/data/cost_config_repository.dart';
import '../../tech_sheets/application/tech_sheets_providers.dart';
import '../application/comparar_precos_providers.dart';
import '../data/variacao_preco_repository.dart';
import '../domain/sugestao_preco.dart';
import '../domain/variacao_preco.dart';
import 'comparar_precos_lista.dart';

enum _Filtro { subidas, descidas, todas, maisBaratos }

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
              _Filtro.maisBaratos => false,
            })
              v,
        ];
        final porVer = ref.watch(subidasPorVerProvider).length;
        final poupancas = ref.watch(poupancasPossiveisProvider);
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
                            _Filtro.maisBaratos =>
                              poupancas > 0
                                  ? 'Mais barato noutro · $poupancas'
                                  : 'Mais barato noutro',
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
              if (_filtro == _Filtro.maisBaratos)
                const CompararPrecosLista()
              else if (lista.isEmpty)
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
              if (_filtro != _Filtro.maisBaratos)
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

/// "Sugestão: €1,60 para a margem voltar a 48 %" com um botão para aplicar.
/// Usa o preço e o custo de HOJE da ficha (não os do momento da fatura), por
/// isso desaparece sozinha quando o preço já foi corrigido.
class _SugestaoPreco extends ConsumerWidget {
  const _SugestaoPreco({
    required this.afetada,
    required this.iva,
    required this.fmt,
  });

  final FichaAfetada afetada;
  final double iva;
  final MoneyFmt fmt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fichas = ref.watch(fichasListProvider(false)).valueOrNull ?? const [];
    final ficha = fichas.where((x) => x.id == afetada.id).firstOrNull;
    if (ficha == null) return const SizedBox.shrink();
    final s = sugerirPreco(
      custoAntes: afetada.custoAntes,
      custoAtual: ficha.custoProduto,
      precoAtualComIva: ficha.precoVenda,
      precoAntesComIva: afetada.precoVenda,
      ivaPct: iva,
    );
    if (s == null) return const SizedBox.shrink();
    final tt = Theme.of(context).textTheme;
    final podeEditar = ref.watch(currentPapelProvider).canEditBusiness;

    Future<void> aplicar() async {
      final ok = await confirmDialog(
        context,
        titulo: 'Subir o preço de "${ficha.nome}"?',
        mensagem:
            'O preço passa de ${fmt(s.precoAtual)} para ${fmt(s.precoSugerido)} '
            '(+${s.aumentoPct.toStringAsFixed(1)}%) e a margem volta a '
            '${s.margemAlvo.toStringAsFixed(0)}%. Podes mudá-lo depois na ficha.',
        confirmar: 'Aplicar ${fmt(s.precoSugerido)}',
      );
      if (!ok || !context.mounted) return;
      try {
        await ref
            .read(fichaActionsProvider)
            .setPrecoVenda(ficha.id, s.precoSugerido);
        ref.invalidate(fichasListProvider);
      } on Object catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Text(
            'Sugestão: ${fmt(s.precoSugerido)} (hoje ${fmt(s.precoAtual)}) '
            'para a margem voltar a ${s.margemAlvo.toStringAsFixed(0)}% '
            '(hoje ${s.margemAtual.toStringAsFixed(0)}%)',
            style: tt.bodySmall?.copyWith(color: Colors.orange),
          ),
          if (podeEditar)
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(0, 36)),
              onPressed: aplicar,
              child: Text('Aplicar ${fmt(s.precoSugerido)}'),
            ),
        ],
      ),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                            Text(
                              '${fmt(f.custoAntes)} → ${fmt(f.custoDepois)}',
                            ),
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
                  _SugestaoPreco(afetada: f, iva: iva, fmt: fmt),
                ],
              ),
          ],
        ],
      ),
    );
  }
}
