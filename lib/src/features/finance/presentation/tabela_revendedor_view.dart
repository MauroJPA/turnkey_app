import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/formatting/money_provider.dart';
import '../../../core/printing/print_html.dart';
import '../../../core/storage/prefs_locais.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../pricing/data/canal_venda_repository.dart';
import '../../pricing/data/cost_config_repository.dart';
import '../../pricing/domain/canal_venda.dart';
import '../../settings/application/empresa_providers.dart';
import '../../tech_sheets/application/tech_sheets_providers.dart';
import '../../tech_sheets/domain/tech_sheet.dart';
import '../domain/tabela_revendedor.dart';

const _pDesconto = 'rev_desconto';
const _pCanal = 'rev_canal';
const _pEscalas = 'rev_escalas';
const _pExcluidos = 'rev_excluidos';

/// Tabela de preços para revendedores: o preço de cada produto (sem IVA e com
/// IVA) com desconto por volume, pronta a mandar por WhatsApp ou a imprimir
/// em PDF. As escolhas ficam guardadas neste aparelho.
class TabelaRevendedorView extends ConsumerStatefulWidget {
  const TabelaRevendedorView({super.key});

  @override
  ConsumerState<TabelaRevendedorView> createState() => _TabelaRevendedorState();
}

class _TabelaRevendedorState extends ConsumerState<TabelaRevendedorView> {
  String _canalId =
      lerPref(_pCanal) ?? ''; // '' = desconto sobre o preço público
  late final _desconto = TextEditingController(
    text: lerPref(_pDesconto) ?? '30',
  );
  late List<EscalaDesconto> _escalas = lerPref(_pEscalas) == null
      ? const [EscalaDesconto(24, 5), EscalaDesconto(48, 10)]
      : lerEscalas(lerPref(_pEscalas));
  late Set<String> _excluidos = {
    for (final s in (lerPref(_pExcluidos) ?? '').split(','))
      if (s.isNotEmpty) s,
  };

  @override
  void dispose() {
    _desconto.dispose();
    super.dispose();
  }

  double get _descontoPct {
    final v = double.tryParse(_desconto.text.replaceAll(',', '.').trim());
    return (v == null || v < 0 || v >= 100) ? 0 : v;
  }

  void _guardarEscalas(List<EscalaDesconto> e) {
    setState(() => _escalas = e);
    guardarPref(_pEscalas, escreverEscalas(e));
  }

  Future<void> _novaEscala() async {
    final qtd = TextEditingController();
    final pct = TextEditingController();
    final nova = await showDialog<EscalaDesconto>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desconto por quantidade'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtd,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'A partir de (unidades do mesmo produto)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pct,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Desconto (%)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final e = lerEscalas('${qtd.text}:${pct.text}');
              if (e.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Escreve uma quantidade (2 ou mais) e um desconto entre 0 e 100.',
                    ),
                  ),
                );
                return;
              }
              Navigator.pop(ctx, e.single);
            },
            child: const Text('Juntar'),
          ),
        ],
      ),
    );
    qtd.dispose();
    pct.dispose();
    if (nova == null) return;
    _guardarEscalas(lerEscalas(escreverEscalas([..._escalas, nova])));
  }

  void _alternar(String id, bool incluir) {
    setState(() {
      incluir ? _excluidos.remove(id) : _excluidos.add(id);
      _excluidos = {..._excluidos};
    });
    guardarPref(_pExcluidos, _excluidos.join(','));
  }

  @override
  Widget build(BuildContext context) {
    final fichas = ref.watch(fichasListProvider(false));
    final config = ref.watch(costConfigProvider);
    final canais = ref.watch(canaisVendaProvider).valueOrNull ?? const [];
    final empresa = ref.watch(currentEmpresaProvider).valueOrNull?.nome ?? '';
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
        final todos = calcularTabela(
          fichas: lista,
          config: cfg,
          descontoPct: _descontoPct,
          canal: canal,
          escalas: _escalas,
        );
        final linhas = [
          for (final l in todos)
            if (!_excluidos.contains(l.ficha.id)) l,
        ];
        final agora = DateTime.now();
        String texto() => tabelaTexto(
          linhas: linhas,
          escalas: _escalas,
          ivaPct: cfg.ivaVendas,
          empresa: empresa,
          fmt: fmt,
          data: agora,
        );

        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                'A tabela que mandas a quem revende os teus produtos: preço por '
                'unidade sem IVA e com IVA, e o desconto por quantidade.',
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
                      label: const Text('Desconto sobre o preço ao público'),
                      selected: canal == null,
                      onSelected: (_) {
                        setState(() => _canalId = '');
                        guardarPref(_pCanal, '');
                      },
                    ),
                  ),
                  for (final c in canais)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c.nome),
                        selected: _canalId == c.id,
                        onSelected: (_) {
                          setState(() => _canalId = c.id);
                          guardarPref(_pCanal, c.id);
                        },
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: canal == null
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 130,
                          child: TextField(
                            controller: _desconto,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (v) {
                              guardarPref(_pDesconto, v.trim());
                              setState(() {});
                            },
                            decoration: const InputDecoration(
                              labelText: 'Desconto (%)',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'O revendedor paga o preço de venda ao público (sem '
                            'IVA) menos este desconto.',
                            style: tt.bodySmall,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'O revendedor paga o que te chega com as taxas do canal '
                      '(${canal.resumo}) tiradas ao preço ao público.',
                      style: tt.bodySmall,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('Desconto por quantidade', style: tt.titleSmall),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final e in _escalas)
                    InputChip(
                      label: Text('${e.minUn}+ un · −${e.pct}%'),
                      onDeleted: () => _guardarEscalas([
                        for (final x in _escalas)
                          if (x != e) x,
                      ]),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: const Text('Degrau'),
                    onPressed: _novaEscala,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: linhas.isEmpty
                          ? null
                          : () async {
                              final msg = ScaffoldMessenger.of(context);
                              await Clipboard.setData(
                                ClipboardData(text: texto()),
                              );
                              msg.showSnackBar(
                                const SnackBar(
                                  content: Text('Tabela copiada.'),
                                ),
                              );
                            },
                      child: const FittedBox(child: Text('Copiar')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: linhas.isEmpty
                          ? null
                          : () async {
                              final t = texto();
                              final msg = ScaffoldMessenger.of(context);
                              await Clipboard.setData(ClipboardData(text: t));
                              await launchUrl(
                                Uri(
                                  scheme: 'https',
                                  host: 'wa.me',
                                  queryParameters: {'text': t},
                                ),
                                webOnlyWindowName: '_blank',
                              );
                              msg.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Texto também copiado — se a mensagem vier '
                                    'cortada, cola-o.',
                                  ),
                                ),
                              );
                            },
                      child: const FittedBox(child: Text('WhatsApp')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: linhas.isEmpty
                          ? null
                          : () => abrirImpressao(
                              'Tabela de preços',
                              tabelaHtml(
                                linhas: linhas,
                                escalas: _escalas,
                                ivaPct: cfg.ivaVendas,
                                empresa: empresa,
                                fmt: fmt,
                                data: agora,
                              ),
                              estiloExtra: tabelaEstilo,
                            ),
                      child: const FittedBox(child: Text('PDF')),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 28),
            if (todos.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'Ainda não há produtos com preço de venda. Define o preço '
                    'nas fichas técnicas.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            if (todos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  'Produtos na tabela (desmarca os que não queres mostrar):',
                  style: tt.bodySmall,
                ),
              ),
            for (final l in todos)
              CheckboxListTile(
                dense: true,
                value: !_excluidos.contains(l.ficha.id),
                onChanged: (v) => _alternar(l.ficha.id, v ?? true),
                title: Text(l.nome),
                subtitle: Text(
                  [
                    fmt(l.precoSemIva),
                    if (cfg.ivaVendas > 0) '${fmt(l.precoComIva)} c/IVA',
                    for (var i = 0; i < _escalas.length; i++)
                      '${_escalas[i].minUn}+: ${fmt(l.escalas[i])}',
                  ].join(' · '),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                cfg.ivaVendas > 0
                    ? 'O IVA usado é o das Configurações (${cfg.ivaVendas.toStringAsFixed(0)} %). '
                          'As escolhas ficam guardadas neste aparelho.'
                    : 'Define o IVA das vendas nas Configurações para a coluna com IVA. '
                          'As escolhas ficam guardadas neste aparelho.',
                style: tt.bodySmall?.copyWith(color: cs.outline),
              ),
            ),
          ],
        );
      },
    );
  }
}
