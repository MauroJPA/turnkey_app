import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/cores_estado.dart';
import '../../../core/formatting/money_provider.dart';
import '../application/comparar_precos_providers.dart';
import '../domain/comparar_precos.dart';

/// "Mais barato noutro sítio": para cada ingrediente comprado de mais de uma
/// forma, o preço ao kg de cada marca/fornecedor e quanto se poupa.
class CompararPrecosLista extends ConsumerStatefulWidget {
  const CompararPrecosLista({super.key});

  @override
  ConsumerState<CompararPrecosLista> createState() =>
      _CompararPrecosListaState();
}

class _CompararPrecosListaState extends ConsumerState<CompararPrecosLista> {
  bool _todos = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(comparacoesPrecoProvider);
    final fmt = ref.watch(moneyFormatProvider);
    final tt = Theme.of(context).textTheme;
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: TextButton(
            onPressed: () => ref.invalidate(comparacoesPrecoProvider),
            child: const Text('Não consegui comparar. Tentar de novo'),
          ),
        ),
      ),
      data: (todas) {
        final comPoupanca = [
          for (final c in todas)
            if (c.temPoupanca) c,
        ];
        final lista = _todos ? todas : comPoupanca;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                'Compara as marcas e fornecedores de cada ingrediente ao '
                'kg/litro (só preços dos últimos $diasPrecoAntigo dias entram '
                'na recomendação). Os preços vêm das faturas que aplicas.',
                style: tt.bodySmall,
              ),
            ),
            if (todas.length > comPoupanca.length)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FilterChip(
                    label: Text('Mostrar todos (${todas.length})'),
                    selected: _todos,
                    onSelected: (v) => setState(() => _todos = v),
                  ),
                ),
              ),
            if (lista.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    todas.isEmpty
                        ? 'Ainda não há ingredientes comprados de duas formas '
                              'diferentes. Quando aplicares faturas de outra '
                              'marca ou fornecedor, a comparação aparece aqui.'
                        : 'Nada a poupar: o que compras agora já é o mais '
                              'barato de cada ingrediente.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            for (final c in lista) _CartaoComparacao(c: c, fmt: fmt),
          ],
        );
      },
    );
  }
}

class _CartaoComparacao extends StatelessWidget {
  const _CartaoComparacao({required this.c, required this.fmt});

  final ComparacaoIngrediente c;
  final MoneyFmt fmt;

  static String _quando(int? dias) {
    if (dias == null) return 'sem data';
    if (dias <= 0) return 'hoje';
    if (dias < 60) return 'há $dias dias';
    return 'há ${(dias / 30).round()} meses';
  }

  static String _nomeOpcao(OpcaoPreco o) {
    final p = o.produto;
    final forn = p.fornecedor.trim();
    final nome = p.marca.trim().isNotEmpty ? p.marca.trim() : p.nome;
    return forn.isEmpty ? nome : '$nome ($forn)';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final barata = c.maisBarata;
    final uso = c.emUso;
    final u = c.unidadePreco;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(
          c.temPoupanca ? Icons.savings_outlined : Icons.check_circle_outline,
          color: c.temPoupanca ? cs.sucesso : cs.outline,
        ),
        title: Text(c.ingrediente.nomeComCaracteristica),
        subtitle: Text(
          c.temPoupanca && barata != null && uso != null
              ? '${_nomeOpcao(barata)} é mais barato: '
                    '${fmt(barata.custo)}/$u em vez de ${fmt(uso.custo)}/$u'
              : 'Já compras o mais barato (${c.opcoes.length} opções)',
        ),
        trailing: c.temPoupanca
            ? Text(
                '−${c.poupancaPct.toStringAsFixed(0)}%',
                style: tt.titleMedium?.copyWith(
                  color: cs.sucesso,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final o in c.opcoes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_nomeOpcao(o)),
                        Text(
                          '${o.produto.resumo} · ${_quando(o.diasDesdeCompra)}'
                          '${identical(o, uso) ? ' · o que compras agora' : ''}'
                          '${o.antigo ? ' · preço antigo' : ''}',
                          style: tt.bodySmall?.copyWith(
                            color: o.antigo ? cs.outline : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${fmt(o.custo)}/$u',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: identical(o, barata) ? cs.sucesso : null,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
