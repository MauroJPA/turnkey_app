import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/prefs_locais.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../finance/data/capacidade_forno_repository.dart';
import '../../pricing/data/cost_config_repository.dart';
import '../../pricing/domain/dias_trabalho.dart';
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
class PrevisaoAssarView extends ConsumerStatefulWidget {
  const PrevisaoAssarView({super.key});

  @override
  ConsumerState<PrevisaoAssarView> createState() => _PrevisaoAssarViewState();
}

class _PrevisaoAssarViewState extends ConsumerState<PrevisaoAssarView> {
  int? _escolhido; // dias a partir de hoje (null = o primeiro dia de trabalho)
  double _ajuste = 0;
  bool _descontarStock = true;

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
        final nomes = {
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
                child: Row(
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
                                const SnackBar(content: Text('Lista copiada.')),
                              );
                            },
                      icon: const Icon(Icons.copy),
                    ),
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
