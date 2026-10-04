import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/formatting/money_provider.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/help_actions.dart';
import '../../finance/domain/periodo.dart';
import '../../finance/presentation/seletor_periodo.dart';
import '../../tech_sheets/application/tech_sheets_providers.dart';
import '../application/contagem_providers.dart';
import '../domain/contagem_dia.dart';
import '../domain/local.dart';
import '../domain/movimento_produto.dart';

String _n(double v) =>
    v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);

/// Relatórios da contagem: onde se perde cookies (desperdício por motivo,
/// sabor e local) e o balanço de cada local (ex.: quantos foram para
/// Alvalade e quantos voltaram).
class ContagemRelatoriosScreen extends ConsumerStatefulWidget {
  const ContagemRelatoriosScreen({super.key});

  @override
  ConsumerState<ContagemRelatoriosScreen> createState() =>
      _ContagemRelatoriosScreenState();
}

class _ContagemRelatoriosScreenState
    extends ConsumerState<ContagemRelatoriosScreen> {
  Periodo _periodo = Periodo.semanaAtual();
  String? _localId;

  @override
  Widget build(BuildContext context) {
    final intervalo = (desde: _periodo.desde, ate: _periodo.ate);
    final movs = ref.watch(movimentosProvider(intervalo));
    final vendas = ref.watch(vendasPorLocalProvider(intervalo));
    final locais = ref.watch(locaisProvider).valueOrNull ?? const <Local>[];
    final fichas = ref.watch(fichasListProvider(false)).valueOrNull ?? const [];
    final nomes = {for (final f in fichas) f.id: f.nome};
    final custos = {for (final f in fichas) f.id: f.custoProduto};

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(Routes.contagem),
          ),
          title: const Text('Desperdício e locais'),
          actions: const [HelpActions(topic: HelpTopic.contagem)],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Desperdício'),
              Tab(text: 'Balanço por local'),
            ],
          ),
        ),
        body: Column(
          children: [
            SeletorPeriodo(
              periodo: _periodo,
              onChanged: (p) => setState(() => _periodo = p),
            ),
            Expanded(
              child: AsyncValueView<List<MovimentoProduto>>(
                value: movs,
                onRetry: () => ref.invalidate(movimentosProvider),
                data: (todos) => TabBarView(
                  children: [
                    _Desperdicio(
                      movimentos: todos,
                      nomes: nomes,
                      custos: custos,
                      locais: locais,
                    ),
                    _Balanco(
                      movimentos: todos,
                      vendas: vendas.valueOrNull ?? const [],
                      nomes: nomes,
                      locais: locais,
                      localId: _localId,
                      onLocal: (id) => setState(() => _localId = id),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Desperdicio extends ConsumerWidget {
  const _Desperdicio({
    required this.movimentos,
    required this.nomes,
    required this.custos,
    required this.locais,
  });

  final List<MovimentoProduto> movimentos;
  final Map<String, String> nomes;
  final Map<String, double> custos;
  final List<Local> locais;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final fmt = ref.watch(moneyFormatProvider);
    final r = resumoDesperdicio(movimentos: movimentos, custoPorFicha: custos);
    final nomeLocal = {for (final l in locais) l.id: l.nome};

    if (r.unidades == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            r.assados > 0
                ? 'Sem desperdício registado neste período. Assados: ${_n(r.assados)}.'
                : 'Sem registos neste período.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    Widget barra(String titulo, double valor, double max) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(titulo)),
              Text(
                _n(valor),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          LinearProgressIndicator(value: max > 0 ? valor / max : 0),
        ],
      ),
    );

    List<MapEntry<K, double>> ordenado<K>(Map<K, double> m) =>
        m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _kpi('Deitados fora', _n(r.unidades), tt),
                _kpi('Custo', fmt(r.custo), tt),
                if (r.assados > 0)
                  _kpi(
                    '% dos assados',
                    '${r.percentDosAssados.toStringAsFixed(1)}%',
                    tt,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('Por motivo', style: tt.titleSmall),
        for (final e in ordenado(r.porMotivo))
          barra(e.key?.label ?? 'Sem motivo', e.value, r.unidades),
        const SizedBox(height: 12),
        Text('Por sabor', style: tt.titleSmall),
        for (final e in ordenado(r.porSabor))
          barra(nomes[e.key] ?? 'Produto', e.value, r.unidades),
        if (r.porLocal.length > 1) ...[
          const SizedBox(height: 12),
          Text('Por local', style: tt.titleSmall),
          for (final e in ordenado(r.porLocal))
            barra(nomeLocal[e.key] ?? 'Local', e.value, r.unidades),
        ],
        const SizedBox(height: 12),
        Text(
          'O custo é o da matéria-prima de cada sabor (custo atual da ficha).',
          style: tt.bodySmall,
        ),
      ],
    );
  }

  Widget _kpi(String k, String v, TextTheme tt) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(k, style: tt.bodySmall),
      Text(v, style: tt.titleLarge),
    ],
  );
}

class _Balanco extends StatelessWidget {
  const _Balanco({
    required this.movimentos,
    required this.vendas,
    required this.nomes,
    required this.locais,
    required this.localId,
    required this.onLocal,
  });

  final List<MovimentoProduto> movimentos;
  final List<VendaDoLocal> vendas;
  final Map<String, String> nomes;
  final List<Local> locais;
  final String? localId;
  final ValueChanged<String> onLocal;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    if (locais.isEmpty) {
      return const Center(child: Text('Ainda não há locais.'));
    }
    // por omissão, o primeiro local que não é a loja (ex.: Alvalade)
    final local = locais.firstWhere(
      (l) => l.id == localId,
      orElse: () => locais.firstWhere(
        (l) => l.tipo != TipoLocal.loja,
        orElse: () => locais.first,
      ),
    );
    final b = balancoDoLocal(
      localId: local.id,
      movimentos: movimentos,
      vendas: vendas,
    );
    double total(double Function(BalancoSabor) f) =>
        b.fold<double>(0, (s, x) => s + f(x));
    final eLoja = local.tipo == TipoLocal.loja;

    Widget celula(String t, {bool negrito = false, double largura = 58}) =>
        SizedBox(
          width: largura,
          child: Text(
            t,
            textAlign: TextAlign.right,
            style: negrito
                ? const TextStyle(fontWeight: FontWeight.bold)
                : null,
          ),
        );

    Widget linha(String nome, List<String> valores, {bool negrito = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  nome,
                  overflow: TextOverflow.ellipsis,
                  style: negrito
                      ? const TextStyle(fontWeight: FontWeight.bold)
                      : null,
                ),
              ),
              for (final v in valores) celula(v, negrito: negrito),
            ],
          ),
        );

    // colunas: as que estão sempre a zero (ex.: "Assados" em Alvalade)
    // escondem-se; vendidos, desperdício e saldo ficam sempre.
    final colunas = <(String, double Function(BalancoSabor), bool)>[
      ('Assados', (x) => x.assados, false),
      ('Receb.', (x) => x.recebido, false),
      (eLoja ? 'Env.' : 'Devolv.', (x) => x.enviado, false),
      ('Vend.', (x) => x.vendido, true),
      ('Desp.', (x) => x.desperdicio, true),
      ('Saldo', (x) => x.saldo, true),
    ].where((c) => c.$3 || total(c.$2) != 0).toList();
    final cab = [for (final c in colunas) c.$1];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final l in locais)
              ChoiceChip(
                label: Text(l.nome),
                selected: l.id == local.id,
                onSelected: (_) => onLocal(l.id),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (b.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Sem registos neste local e período.',
              textAlign: TextAlign.center,
            ),
          )
        else ...[
          Text(
            eLoja
                ? 'Saldo = assados + recebidos − enviados − vendidos − desperdício.'
                : 'Receb. = o que foi enviado para ${local.nome}; Devolv. = o que '
                      'voltou. Saldo = recebidos − devolvidos − vendidos − '
                      'desperdício (o que devia lá ter ficado).',
            style: tt.bodySmall,
          ),
          const SizedBox(height: 8),
          linha('Sabor', cab, negrito: true),
          const Divider(height: 1),
          for (final x in b)
            linha(nomes[x.fichaId] ?? 'Produto', [
              for (final c in colunas) _n(c.$2(x)),
            ]),
          const Divider(height: 1),
          linha('Total', [
            for (final c in colunas) _n(total(c.$2)),
          ], negrito: true),
        ],
      ],
    );
  }
}
