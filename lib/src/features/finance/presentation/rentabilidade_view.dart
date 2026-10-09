import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/cores_estado.dart';
import '../../../core/formatting/money_provider.dart';
import '../../../core/storage/prefs_locais.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../pricing/data/canal_venda_repository.dart';
import '../../pricing/data/cost_config_repository.dart';
import '../../pricing/domain/canal_venda.dart';
import '../../tech_sheets/application/tech_sheets_providers.dart';
import '../../tech_sheets/domain/tech_sheet.dart';
import '../data/capacidade_forno_repository.dart';
import '../domain/rentabilidade.dart';

/// Rentabilidade: que produtos dão mais lucro — por unidade, por hora de forno
/// e em margem — vendidos na loja ou em cada canal (com as suas taxas).
class RentabilidadeView extends ConsumerStatefulWidget {
  const RentabilidadeView({super.key});

  @override
  ConsumerState<RentabilidadeView> createState() => _RentabilidadeViewState();
}

class _RentabilidadeViewState extends ConsumerState<RentabilidadeView> {
  String? _canalId; // null = loja física
  OrdemRentabilidade _ordem = OrdemRentabilidade.lucroUnidade;
  late final _capacidade = TextEditingController(
    text: lerPref(chaveCapacidadeForno) ?? '',
  );

  @override
  void dispose() {
    _capacidade.dispose();
    super.dispose();
  }

  double _capacidadeEscolhida(double auto) {
    final manual = double.tryParse(
      _capacidade.text.replaceAll(',', '.').trim(),
    );
    return (manual != null && manual > 0) ? manual : auto;
  }

  @override
  Widget build(BuildContext context) {
    final fichas = ref.watch(fichasListProvider(false));
    final config = ref.watch(costConfigProvider);
    final canais = ref.watch(canaisVendaProvider).valueOrNull ?? const [];
    final auto = ref.watch(capacidadeFornoProvider).valueOrNull ?? 0;
    final fmt = ref.watch(moneyFormatProvider);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return AsyncValueView<List<FichaTecnica>>(
      value: fichas,
      onRetry: () => ref.invalidate(fichasListProvider(false)),
      data: (lista) {
        final cfg = config.valueOrNull;
        if (cfg == null) {
          return const Center(child: CircularProgressIndicator());
        }
        CanalVenda? canal;
        for (final c in canais) {
          if (c.id == _canalId) {
            canal = c;
          }
        }
        final cap = _capacidadeEscolhida(auto);
        final linhas = calcularRentabilidade(
          fichas: lista,
          config: cfg,
          canal: canal,
          capacidadeForno: cap,
          ordem: _ordem,
        );
        final semPreco = lista
            .where(
              (f) => !f.deletado && (!f.temPrecoVenda || f.custoProduto <= 0),
            )
            .length;
        final maxAbs = linhas.fold<double>(
          0.01,
          (m, l) => [m, l.lucroUn.abs()].reduce((a, b) => a > b ? a : b),
        );

        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                'O que cada produto deixa de lucro (sem IVA), ao preço de venda que '
                'tem hoje, depois das taxas do canal e dos custos da empresa.',
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
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: const Icon(Icons.storefront_outlined, size: 18),
                      label: const Text('Loja física'),
                      selected: _canalId == null,
                      onSelected: (_) => setState(() => _canalId = null),
                    ),
                  ),
                  for (final c in canais)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c.nome),
                        selected: _canalId == c.id,
                        onSelected: (_) => setState(() => _canalId = c.id),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final o in OrdemRentabilidade.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(o.label),
                        selected: _ordem == o,
                        onSelected: (_) => setState(() => _ordem = o),
                      ),
                    ),
                ],
              ),
            ),
            if (canal != null && canal.taxas.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text('Taxas: ${canal.resumo}', style: tt.bodySmall),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 130,
                    child: TextField(
                      controller: _capacidade,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (v) {
                        guardarPref(chaveCapacidadeForno, v.trim());
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        labelText: 'Por fornada',
                        hintText: auto > 0 ? auto.toStringAsFixed(0) : '12',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      auto > 0
                          ? 'Média das tuas fornadas: ${auto.toStringAsFixed(0)} un '
                                '(deixa vazio para usar). Serve para o lucro por hora de forno.'
                                '${auto < capacidadeAutoSuspeita && _capacidade.text.trim().isEmpty ? ' É muito baixa: se o forno leva mais, escreve aqui quantas unidades cabem.' : ''}'
                          : 'Ainda sem fornadas registadas: escreve quantas unidades '
                                'cabem numa fornada para ver o lucro por hora de forno.',
                      style: tt.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            if (linhas.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'Ainda não há produtos com custo e preço de venda. Define o '
                    'preço nas fichas técnicas.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            for (var i = 0; i < linhas.length; i++)
              _Linha(
                posicao: i + 1,
                l: linhas[i],
                maxAbs: maxAbs,
                fmt: fmt,
                destaqueHora: _ordem == OrdemRentabilidade.lucroHoraForno,
                destaqueMargem: _ordem == OrdemRentabilidade.margem,
              ),
            if (linhas.any((l) => l.ficha.tempoAssaduraMin <= 0))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  '${linhas.where((l) => l.ficha.tempoAssaduraMin <= 0).length} '
                  'produto(s) sem tempo de assadura na ficha: não têm lucro por '
                  'hora de forno (aparece "— /h").',
                  style: tt.bodySmall?.copyWith(color: cs.outline),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.go(Routes.saudeDados),
                icon: const Icon(Icons.health_and_safety_outlined, size: 18),
                label: const Text('Ver o que falta preencher'),
              ),
            ),
            if (semPreco > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  '$semPreco produto(s) ficam de fora por falta de custo ou de '
                  'preço de venda.',
                  style: tt.bodySmall?.copyWith(color: cs.outline),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Não inclui a embalagem extra para plataformas. O lucro usa as '
                'percentagens de custo das Configurações (salário, aluguel…) '
                'sobre o que chega a nós.',
                style: tt.bodySmall?.copyWith(color: cs.outline),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha({
    required this.posicao,
    required this.l,
    required this.maxAbs,
    required this.fmt,
    required this.destaqueHora,
    required this.destaqueMargem,
  });

  final int posicao;
  final LinhaRentabilidade l;
  final double maxAbs;
  final MoneyFmt fmt;
  final bool destaqueHora;
  final bool destaqueMargem;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final cor = l.prejuizo ? cs.error : cs.sucesso;
    final frac = (l.lucroUn.abs() / maxAbs).clamp(0.02, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '$posicao',
              style: tt.titleSmall?.copyWith(color: cs.outline),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.ficha.subnome.isEmpty
                      ? l.ficha.nome
                      : '${l.ficha.nome} · ${l.ficha.subnome}',
                  style: tt.titleSmall,
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: frac,
                    minHeight: 6,
                    color: cor,
                    backgroundColor: cs.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    'preço ${fmt(l.precoSemIva)} s/IVA',
                    if (l.receita != l.precoSemIva) 'chega ${fmt(l.receita)}',
                    if (l.ficha.tempoAssaduraMin > 0)
                      '${l.ficha.tempoAssaduraMin} min forno',
                  ].join(' · '),
                  style: tt.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                fmt(l.lucroUn),
                style: tt.titleMedium?.copyWith(
                  color: cor,
                  fontWeight: destaqueHora || destaqueMargem
                      ? FontWeight.normal
                      : FontWeight.bold,
                ),
              ),
              Text(
                '${l.margemPct.toStringAsFixed(0)}%',
                style: tt.bodySmall?.copyWith(
                  fontWeight: destaqueMargem ? FontWeight.bold : null,
                ),
              ),
              Text(
                l.lucroHora == null ? '— /h' : '${fmt(l.lucroHora!)}/h',
                style: tt.bodySmall?.copyWith(
                  fontWeight: destaqueHora ? FontWeight.bold : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
