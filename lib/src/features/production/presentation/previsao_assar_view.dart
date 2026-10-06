import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/errors/mensagem_amigavel.dart';
import '../../../core/formatting/money_provider.dart';
import '../../../core/storage/prefs_locais.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../finance/data/capacidade_forno_repository.dart';
import '../../mise_en_place/data/mep_repository.dart';
import '../../pricing/data/cost_config_repository.dart';
import '../../pricing/domain/dias_trabalho.dart';
import '../../sales/data/sales_repository.dart';
import '../../sales/domain/estado_vendus.dart';
import '../../schedule/application/schedule_providers.dart';
import '../../schedule/data/schedule_repository.dart';
import '../../schedule/domain/production_plan.dart';
import '../../shopping/application/shopping_providers.dart';
import '../../tech_sheets/application/tech_sheets_providers.dart';
import '../application/previsao_providers.dart';
import '../domain/previsao_assar.dart';

String _rotuloDia(DateTime d, int offset) => offset == 0
    ? 'Hoje'
    : offset == 1
    ? 'Amanhã'
    : '${nomesDiasCurtos[d.weekday - 1]} ${d.day}/${d.month}';

String _n(double v) => v == v.roundToDouble()
    ? v.toStringAsFixed(0)
    : v.toStringAsFixed(1).replaceAll('.', ',');

/// "Quantos assar amanhã": por sabor, o que convém ter pronto, calculado pelas
/// vendas dos mesmos dias da semana nas últimas semanas, pelo desperdício e
/// pelo que ainda há em stock. A app testa vários modelos nos dias passados e
/// usa o que erra menos — quanto mais histórico, melhor acerta.
/// Preferência local: gerar a lista de compras ao agendar a produção.
const chaveGerarCompras = 'previsao_gerar_compras';

class PrevisaoAssarView extends ConsumerStatefulWidget {
  const PrevisaoAssarView({super.key});

  @override
  ConsumerState<PrevisaoAssarView> createState() => _PrevisaoAssarViewState();
}

class _PrevisaoAssarViewState extends ConsumerState<PrevisaoAssarView> {
  int? _escolhido; // dias a partir de hoje (null = o primeiro dia de trabalho)
  double _ajuste = 0;
  bool _descontarStock = true;
  bool _agendando = false;

  /// Preparar a lista de compras ao agendar (ligado por omissão).
  bool get _gerarCompras => lerPref(chaveGerarCompras) != '0';
  bool _sincronizando = false;

  /// Quando se sincronizou o Vendus automaticamente nesta sessão (para não
  /// repetir de cada vez que se abre a página).
  static DateTime? _ultimaSincAuto;

  @override
  void initState() {
    super.initState();
    // ao abrir, se as vendas têm mais de 3 horas, atualiza-as em segundo plano
    ref.listenManual(estadoVendusProvider, (_, next) {
      final e = next.valueOrNull;
      if (e == null || _sincronizando) return;
      final agora = DateTime.now();
      final recente =
          _ultimaSincAuto != null &&
          agora.difference(_ultimaSincAuto!) < const Duration(minutes: 15);
      if (e.pedeSincronizar(agora) &&
          !recente &&
          ref.read(currentPapelProvider).canEditBusiness) {
        _ultimaSincAuto = agora;
        _sincronizar(silencioso: true);
      }
    }, fireImmediately: true);
  }

  Future<void> _sincronizar({bool silencioso = false}) async {
    if (_sincronizando) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sincronizando = true);
    try {
      final r = await ref.read(salesRepositoryProvider).sincronizarVendus();
      ref.invalidate(consumoRecenteProvider);
      ref.invalidate(estadoVendusProvider);
      if (!silencioso) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              r.vendasCriadas > 0
                  ? '${r.vendasCriadas} venda(s) nova(s) do Vendus.'
                  : 'As vendas já estavam em dia.',
            ),
          ),
        );
      }
    } on Object catch (e) {
      if (!silencioso) {
        messenger.showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
      }
    } finally {
      if (mounted) setState(() => _sincronizando = false);
    }
  }

  // a avaliação dos últimos dias só se refaz quando os dados mudam
  List<ConsumoDia>? _avalDados;
  Set<int>? _avalDias;
  List<AvaliacaoDia> _aval = const [];

  List<AvaliacaoDia> _avaliacoes(
    DateTime hoje,
    List<ConsumoDia> dados,
    Set<int> dias,
  ) {
    if (!identical(_avalDados, dados) || _avalDias?.length != dias.length) {
      _avalDados = dados;
      _avalDias = dias;
      _aval = avaliarPrevisoes(hoje: hoje, consumo: dados, diasTrabalho: dias);
    }
    return _aval;
  }

  /// Cria a produção desse dia com as quantidades da previsão: um toque.
  Future<void> _agendar(
    DateTime alvo,
    String rotulo,
    List<({String fichaId, int unidades})> itens,
  ) async {
    if (itens.isEmpty || _agendando) return;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _agendando = true);
    try {
      // já há uma produção da previsão para este dia?
      final planos = await ref.read(plansListProvider.future);
      ProducaoPlan? existente;
      for (final p in planos) {
        if (p.estado == EstadoProducao.planeada &&
            p.data.year == alvo.year &&
            p.data.month == alvo.month &&
            p.data.day == alvo.day &&
            p.titulo.startsWith('Previsão')) {
          existente = p;
        }
      }
      if (existente != null) {
        if (!mounted) return;
        final r = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Já está agendado'),
            content: Text(
              'Já tens a produção da previsão para $rotulo '
              '("${existente!.titulo}"). Queres abri-la ou criar outra?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'outra'),
                child: const Text('Criar outra'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, 'abrir'),
                child: const Text('Abrir'),
              ),
            ],
          ),
        );
        if (r == null) return;
        if (r == 'abrir') {
          router.go('${Routes.schedule}/${existente.id}');
          return;
        }
      }
      final mep = ref.read(mepRepositoryProvider);
      final resultados = await Future.wait([
        for (final i in itens)
          () async {
            try {
              return await mep.planoFicha(i.fichaId, i.unidades);
            } on Object {
              return null;
            }
          }(),
      ]);
      final validos = [
        for (final p in resultados)
          if (p != null && p.receitaId.isNotEmpty && p.kg > 0) p,
      ];
      if (validos.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Não consegui agendar: estes produtos não têm receita de massa '
              'ligada na ficha técnica.',
            ),
          ),
        );
        return;
      }
      final repo = ref.read(scheduleRepositoryProvider);
      final plano = await repo.createPlan(
        data: alvo,
        titulo: 'Previsão: assar $rotulo',
      );
      for (final p in validos) {
        await repo.addItem(
          plano.id,
          receitaId: p.receitaId,
          quantidadeKg: p.kg,
          formatoId: p.formatoId.isEmpty ? null : p.formatoId,
          fichaId: p.fichaId,
          unidadesPrevistas: p.unidades,
        );
      }
      ref.invalidate(plansListProvider);
      final falharam = itens.length - validos.length;
      // a lista de compras sai logo daqui (o que falta, contra o stock de hoje)
      String compras = '';
      var paraCompras = false;
      if (_gerarCompras) {
        try {
          final r = await repo.gerarListaComprasResumo(plano.id);
          ref.invalidate(shoppingListProvider);
          if (r.aComprar > 0) {
            paraCompras = true;
            final fmt = ref.read(moneyFormatProvider);
            compras =
                ' Faltam ${r.aComprar} ingrediente(s) para comprar'
                '${r.custo > 0 ? ' (≈ ${fmt(r.custo)})' : ''}.';
          } else if (r.linhas > 0) {
            compras = ' O stock chega: não falta comprar nada.';
          }
        } on Object {
          compras = ' (Não consegui preparar a lista de compras.)';
        }
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Produção agendada: ${validos.length} produto(s) para $rotulo'
            '${falharam > 0 ? ' ($falharam sem receita ligada ficaram de fora)' : ''}.'
            '$compras',
          ),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: paraCompras ? 'Ver compras' : 'Ver',
            onPressed: () => router.go(
              paraCompras ? Routes.shopping : '${Routes.schedule}/${plano.id}',
            ),
          ),
        ),
      );
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
    } finally {
      if (mounted) setState(() => _agendando = false);
    }
  }

  Future<void> _editarCapacidade(double auto) async {
    final c = TextEditingController(text: lerPref(chaveCapacidadeForno) ?? '');
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unidades por fornada'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Quantas cabem no forno',
            helperText: auto > 0
                ? 'Deixa vazio para usar a média das tuas fornadas (${auto.toStringAsFixed(0)} un).'
                : 'Ainda sem fornadas registadas.',
            helperMaxLines: 3,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    c.dispose();
    if (v == null) return;
    guardarPref(chaveCapacidadeForno, v);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final consumo = ref.watch(consumoRecenteProvider);
    final fichas = ref.watch(fichasListProvider(false));
    final stock = ref.watch(stockAgoraProvider).valueOrNull ?? const {};
    final auto = ref.watch(capacidadeFornoProvider).valueOrNull ?? 0;
    final porFornada = capacidadeFornoEscolhida(auto);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final podeAgendar = ref.watch(currentPapelProvider).canEditBusiness;
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final diasTrab =
        ref.watch(costConfigProvider).valueOrNull?.diasDeTrabalho ??
        todosOsDias;
    // hoje e os 7 dias seguintes, só os de trabalho
    final opcoes = [
      for (var o = 0; o <= 7; o++)
        if (diasTrab.contains(hoje.add(Duration(days: o)).weekday)) o,
    ];
    final offset = opcoes.contains(_escolhido) ? _escolhido! : opcoes.first;
    final alvo = hoje.add(Duration(days: offset));

    return AsyncValueView<List<ConsumoDia>>(
      value: consumo,
      onRetry: () => ref.invalidate(consumoRecenteProvider),
      data: (dados) {
        final nomes = <String, String>{
          for (final f in fichas.valueOrNull ?? const [])
            f.id: f.subnome.isEmpty ? f.nome : '${f.nome} · ${f.subnome}',
        };
        final previsoes = [
          for (final p in preverDia(
            hoje: hoje,
            alvo: alvo,
            consumo: dados,
            ajustePct: _ajuste,
            diasTrabalho: diasTrab,
          ))
            if (nomes.containsKey(p.fichaId)) p,
        ];
        // hoje: o que já se vendeu hoje já saiu do stock, por isso só falta
        // o resto do dia
        final vendidoHoje = <String, double>{};
        if (offset == 0) {
          for (final c in dados) {
            if (c.dia.year == hoje.year &&
                c.dia.month == hoje.month &&
                c.dia.day == hoje.day) {
              vendidoHoje[c.fichaId] =
                  (vendidoHoje[c.fichaId] ?? 0) + c.vendido;
            }
          }
        }
        int aAssar(PrevisaoFicha p) {
          final s = _descontarStock ? (stock[p.fichaId] ?? 0) : 0.0;
          final v = (p.sugerido - (vendidoHoje[p.fichaId] ?? 0) - s).ceil();
          return v < 0 ? 0 : v;
        }

        final lista = [...previsoes]
          ..sort((a, b) => aAssar(b).compareTo(aAssar(a)));
        final total = lista.fold<int>(0, (s, p) => s + aAssar(p));
        final fornadas = porFornada > 0 ? total / porFornada : null;

        String texto() {
          final b = StringBuffer(
            'Assar ${_rotuloDia(alvo, offset).toLowerCase()} '
            '(${nomesDiasCurtos[alvo.weekday - 1]} ${alvo.day}/${alvo.month}):',
          );
          for (final p in lista) {
            final q = aAssar(p);
            if (q > 0) b.write('\n• ${nomes[p.fichaId]}: $q');
          }
          b.write('\nTotal: $total');
          return b.toString();
        }

        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                'O que convém ter pronto, sabor a sabor, pelas vendas dos mesmos '
                'dias da semana, pelo desperdício e pelo que ainda há.',
                style: tt.bodySmall,
              ),
            ),
            _VendasAtualizadas(
              estado: ref.watch(estadoVendusProvider).valueOrNull,
              sincronizando: _sincronizando,
              onAtualizar: () => _sincronizar(),
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
                  for (final o in opcoes)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_rotuloDia(hoje.add(Duration(days: o)), o)),
                        selected: offset == o,
                        onSelected: (_) => setState(() => _escolhido = o),
                      ),
                    ),
                ],
              ),
            ),
            if (diasTrab.length < 7)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  'Trabalham ${resumoDiasTrabalho(diasTrab)} (muda em '
                  'Configurações → Dias de trabalho); as folgas não aparecem.',
                  style: tt.bodySmall?.copyWith(color: cs.outline),
                ),
              ),
            if (offset == 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  'Hoje: conta o que já se vendeu hoje e o stock que ainda há.',
                  style: tt.bodySmall?.copyWith(color: cs.outline),
                ),
              ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final a in const [-20.0, 0.0, 20.0, 50.0])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          a == 0
                              ? 'Dia normal'
                              : '${a > 0 ? '+' : '−'}${a.abs().toStringAsFixed(0)}%'
                                    '${a == 50 ? ' (evento)' : ''}',
                        ),
                        selected: _ajuste == a,
                        onSelected: (_) => setState(() => _ajuste = a),
                      ),
                    ),
                ],
              ),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              title: const Text('Descontar o que já há em stock'),
              subtitle: Text(
                stock.isEmpty
                    ? 'Sem stock registado agora.'
                    : 'Pelas contagens e contas de hoje (estimativa se ainda '
                          'não contaste o fecho).',
              ),
              value: _descontarStock,
              onChanged: (v) => setState(() => _descontarStock = v),
            ),
            Card(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$total para assar',
                                style: tt.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                fornadas == null
                                    ? 'Ainda sem fornadas registadas para estimar as fornadas.'
                                    : '≈ ${fornadas.toStringAsFixed(1).replaceAll('.', ',')} fornadas '
                                          'de ${porFornada.toStringAsFixed(0)} un'
                                          '${lerPref(chaveCapacidadeForno) == null && auto < capacidadeAutoSuspeita ? ' (média baixa: toca no lápis e escreve a capacidade do forno)' : ''}',
                                style: tt.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Unidades por fornada',
                          onPressed: () => _editarCapacidade(auto),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Copiar a lista',
                          onPressed: total == 0
                              ? null
                              : () async {
                                  final msg = ScaffoldMessenger.of(context);
                                  await Clipboard.setData(
                                    ClipboardData(text: texto()),
                                  );
                                  msg.showSnackBar(
                                    const SnackBar(
                                      content: Text('Lista copiada.'),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.copy),
                        ),
                      ],
                    ),
                    if (total > 0 && podeAgendar) ...[
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('Preparar também a lista de compras'),
                        subtitle: const Text(
                          'O que falta para esta produção, contra o stock de hoje',
                        ),
                        value: _gerarCompras,
                        onChanged: (v) {
                          guardarPref(
                            chaveGerarCompras,
                            (v ?? true) ? '1' : '0',
                          );
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 4),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: _agendando
                            ? null
                            : () => _agendar(
                                alvo,
                                _rotuloDia(alvo, offset).toLowerCase(),
                                [
                                  for (final p in lista)
                                    if (aAssar(p) > 0)
                                      (fichaId: p.fichaId, unidades: aAssar(p)),
                                ],
                              ),
                        icon: const Icon(Icons.event_available_outlined),
                        label: Text(
                          'Agendar produção para ${_rotuloDia(alvo, offset).toLowerCase()}',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (lista.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'Ainda não há vendas de produtos com ficha técnica nas '
                    'últimas semanas. Quando as vendas entrarem (Vendus ou '
                    'importação), a previsão aparece aqui.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            for (final p in lista)
              _Linha(
                nome: nomes[p.fichaId] ?? '',
                p: p,
                stock: stock[p.fichaId] ?? 0,
                descontar: _descontarStock,
                aAssar: aAssar(p),
                vendidoHoje: vendidoHoje[p.fichaId] ?? 0,
              ),
            if (lista.isNotEmpty)
              _ComoAcertou(
                avaliacoes: _avaliacoes(hoje, dados, diasTrab),
                nomes: nomes,
              ),
            if (lista.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  'Como funciona: para cada sabor, a app olha para as últimas '
                  '$semanasDeHistorico semanas, só os dias iguais a este (e em '
                  'que a loja vendeu), testa vários modelos nos dias já passados '
                  'e usa o que errou menos. A margem de segurança vem desse erro '
                  'e desaparece nos sabores que costumam ir para o lixo. Com mais '
                  'semanas de vendas acerta melhor. Feriados e tempo não entram — '
                  'usa o ajuste do dia.',
                  style: tt.bodySmall?.copyWith(color: cs.outline),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// "Vendas atualizadas às 14:05 ↻": a hora da última sincronização com o
/// Vendus e um botão para atualizar já (só se o Vendus está ligado).
class _VendasAtualizadas extends StatelessWidget {
  const _VendasAtualizadas({
    required this.estado,
    required this.sincronizando,
    required this.onAtualizar,
  });

  final EstadoVendus? estado;
  final bool sincronizando;
  final VoidCallback onAtualizar;

  @override
  Widget build(BuildContext context) {
    final e = estado;
    if (e == null || !e.configurado) return const SizedBox.shrink();
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final velho = e.desatualizado(DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 8, 0),
      child: Row(
        children: [
          Icon(
            velho ? Icons.sync_problem : Icons.sync,
            size: 16,
            color: velho ? cs.error : cs.outline,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              sincronizando
                  ? 'A atualizar as vendas do Vendus…'
                  : 'Vendas do Vendus atualizadas: ${e.quando(DateTime.now())}'
                        '${velho ? ' — há problemas a sincronizar' : ''}',
              style: tt.bodySmall?.copyWith(
                color: velho ? cs.error : cs.outline,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Atualizar as vendas agora',
            onPressed: sincronizando ? null : onAtualizar,
            icon: const Icon(Icons.refresh, size: 20),
          ),
        ],
      ),
    );
  }
}

/// "Como tem acertado": a previsão refeita para os últimos dias (só com o
/// que havia antes de cada um) contra o que se vendeu.
class _ComoAcertou extends StatelessWidget {
  const _ComoAcertou({required this.avaliacoes, required this.nomes});

  final List<AvaliacaoDia> avaliacoes;
  final Map<String, String> nomes;

  @override
  Widget build(BuildContext context) {
    if (avaliacoes.isEmpty) return const SizedBox.shrink();
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final erro = erroMedioPct(avaliacoes) ?? 0;
    final certo = (100 - erro).clamp(0, 100);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(Icons.fact_check_outlined),
        title: Text(
          'Como a previsão tem acertado: ${certo.toStringAsFixed(0)} %',
        ),
        subtitle: Text(
          'Nos últimos ${avaliacoes.length} dias de venda, em média errou '
          '${erro.toStringAsFixed(0)} % por sabor.',
          style: tt.bodySmall,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          for (final a in avaliacoes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 74,
                    child: Text(
                      '${nomesDiasCurtos[a.dia.weekday - 1]} ${a.dia.day}/${a.dia.month}',
                      style: tt.bodySmall,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'previsto ${_n(a.previsto)} · vendido ${_n(a.vendido)}',
                      style: tt.bodySmall,
                    ),
                  ),
                  Text(
                    a.desvioPct.abs() < 1
                        ? 'certo'
                        : '${a.desvioPct > 0 ? 'sobrou' : 'faltou'} ${a.desvioPct.abs().toStringAsFixed(0)} %',
                    style: tt.bodySmall?.copyWith(
                      color: a.desvioPct < -5
                          ? cs.error
                          : (a.desvioPct > 5 ? Colors.orange : cs.primary),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          if (avaliacoes.first.piores.isNotEmpty)
            Text(
              'Onde mais falhou (${nomesDiasCurtos[avaliacoes.first.dia.weekday - 1]}): '
              '${avaliacoes.first.piores.map((p) => '${nomes[p.fichaId] ?? '—'} (previsto ${_n(p.previsto)}, vendido ${_n(p.vendido)})').join('; ')}.',
              style: tt.bodySmall?.copyWith(color: cs.outline),
            ),
        ],
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha({
    required this.nome,
    required this.p,
    required this.stock,
    required this.descontar,
    required this.aAssar,
    this.vendidoHoje = 0,
  });

  final String nome;
  final PrevisaoFicha p;
  final double stock;
  final bool descontar;
  final int aAssar;
  final double vendidoHoje;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final cor = switch (p.confianca) {
      Confianca.alta => Colors.green,
      Confianca.media => Colors.orange,
      Confianca.baixa => cs.error,
    };
    final detalhe = [
      'prevê vender ${_n(p.previsto)}',
      if (p.margem >= 0.5) '+${_n(p.margem)} de margem',
      if (vendidoHoje > 0) 'já vendeu ${_n(vendidoHoje)} hoje',
      if (descontar && stock > 0) 'há ${_n(stock)} em stock',
    ].join(' · ');
    final tecnico = [
      p.deFallback
          ? 'só ${p.pontos} dia(s) igual(is): média geral do sabor'
          : '${p.pontos} dias iguais · ${p.modelo.label}',
      if (p.erroMedio != null) 'erra ±${_n(p.erroMedio!)} em média',
      if (p.desperdicioPct >= 1)
        '${p.desperdicioPct.toStringAsFixed(0)}% foi para o lixo',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nome, style: tt.titleSmall),
                const SizedBox(height: 2),
                Text(detalhe, style: tt.bodySmall),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.circle, size: 9, color: cor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${p.confianca.label} — $tecnico',
                        style: tt.bodySmall?.copyWith(color: cs.outline),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$aAssar',
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: aAssar == 0 ? cs.outline : null,
            ),
          ),
        ],
      ),
    );
  }
}
