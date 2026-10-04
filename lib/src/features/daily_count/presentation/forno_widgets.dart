import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/alerts/alerta_forno.dart';
import '../../tech_sheets/application/tech_sheets_providers.dart';
import '../application/contagem_providers.dart';
import '../domain/fornada.dart';

String _n(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

/// Lembra que sabores já avisaram (bipe + vibração) quando chegam ao fim do
/// tempo: só avisa os que viu a contar, não os que já estavam prontos ao abrir.
class AvisosForno {
  final _vistos = <String>{};
  final _avisados = <String>{};

  void verificar(List<Fornada> fornadas, DateTime agora) {
    for (final s in saboresNoForno(fornadas, agora)) {
      final chave = '${s.fornada.id}:${s.item.fichaId}';
      if (!s.fornada.prontoItem(s.item, agora)) {
        _vistos.add(chave);
      } else if (_vistos.contains(chave) && _avisados.add(chave)) {
        avisarForno();
      }
    }
  }
}

/// Uma fornada no forno: cada sabor com o seu tempo — quanto passou, quanto
/// falta e um botão para quando sair.
class CartaoFornada extends StatelessWidget {
  const CartaoFornada({
    super.key,
    required this.fornada,
    required this.nomes,
    required this.agora,
    required this.ocupado,
    required this.onTirarItem,
    required this.onTirarTudo,
    required this.onCancelar,
  });

  final Fornada fornada;
  final Map<String, String> nomes;
  final DateTime agora;
  final bool ocupado;
  final void Function(ItemFornada) onTirarItem;
  final VoidCallback onTirarTudo;
  final VoidCallback onCancelar;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final noForno = fornada.noForno(agora);
    final algumPronto = noForno.any((i) => fornada.prontoItem(i, agora));
    final tirados = [
      for (final i in fornada.itens)
        if (i.tirado) i,
    ];
    final hh = fornada.inicio.hour.toString().padLeft(2, '0');
    final mm = fornada.inicio.minute.toString().padLeft(2, '0');
    return Card(
      color: algumPronto ? cs.errorContainer : cs.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(algumPronto ? Icons.notifications_active : Icons.timer_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No forno desde as $hh:$mm',
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final i in noForno)
              _LinhaSabor(
                nome: nomes[i.fichaId] ?? 'Produto',
                item: i,
                fornada: fornada,
                agora: agora,
                ocupado: ocupado,
                onTirar: () => onTirarItem(i),
              ),
            for (final i in tirados)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '✓ ${nomes[i.fichaId] ?? 'Produto'} ${_n(i.quantidade)} — já saiu',
                  style: tt.bodySmall,
                ),
              ),
            if (noForno.length > 1)
              TextButton.icon(
                onPressed: ocupado ? null : onTirarTudo,
                icon: const Icon(Icons.done_all),
                label: const Text('Tirei tudo'),
              ),
            TextButton(
              onPressed: ocupado ? null : onCancelar,
              child: const Text('Foi engano — cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinhaSabor extends StatelessWidget {
  const _LinhaSabor({
    required this.nome,
    required this.item,
    required this.fornada,
    required this.agora,
    required this.ocupado,
    required this.onTirar,
  });

  final String nome;
  final ItemFornada item;
  final Fornada fornada;
  final DateTime agora;
  final bool ocupado;
  final VoidCallback onTirar;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final restante = fornada.restanteDe(item, agora);
    final pronto = fornada.prontoItem(item, agora);
    final total = Duration(minutes: item.duracaoMin);
    final decorrido = fornada.decorrido(agora);
    final progresso = total.inSeconds == 0
        ? 1.0
        : (decorrido.inSeconds / total.inSeconds).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: pronto
              ? cs.error.withValues(alpha: 0.18)
              : cs.surface.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$nome · ${_n(item.quantidade)}',
                    style: tt.titleSmall,
                  ),
                ),
                Text('${item.duracaoMin} min', style: tt.bodySmall),
              ],
            ),
            const SizedBox(height: 4),
            if (pronto)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'PRONTO! passou há ${cronometro(restante)}',
                      style: tt.titleMedium?.copyWith(
                        color: cs.error,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: ocupado ? null : onTirar,
                    child: const Text('Tirei'),
                  ),
                ],
              )
            else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'faltam ${cronometro(restante)}',
                    style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  Text(
                    'passaram ${cronometro(decorrido)}',
                    style: tt.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: progresso,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// O que está no forno, em resumo (uma linha por sabor, com o tempo que
/// falta) — para o Início e o quiosque. Não aparece se o forno está vazio.
class ResumoFornoCard extends ConsumerStatefulWidget {
  const ResumoFornoCard({super.key});

  @override
  ConsumerState<ResumoFornoCard> createState() => _ResumoFornoCardState();
}

class _ResumoFornoCardState extends ConsumerState<ResumoFornoCard> {
  Timer? _tick;
  int _segundos = 0;
  final _avisos = AvisosForno();

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _segundos++;
      if (_segundos % 30 == 0) ref.invalidate(fornadasNoFornoTodasProvider);
      final f = ref.read(fornadasNoFornoTodasProvider).valueOrNull;
      if (f != null) _avisos.verificar(f, DateTime.now());
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fornadas =
        ref.watch(fornadasNoFornoTodasProvider).valueOrNull ?? const <Fornada>[];
    final agora = DateTime.now();
    final sabores = saboresNoForno(fornadas, agora);
    if (sabores.isEmpty) return const SizedBox.shrink();
    final nomes = {
      for (final f in ref.watch(fichasListProvider(false)).valueOrNull ?? [])
        f.id: f.nome,
    };
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final algumPronto = sabores.any(
      (s) => s.fornada.prontoItem(s.item, agora),
    );
    return Card(
      color: algumPronto ? cs.errorContainer : cs.secondaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go(Routes.contagem),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    algumPronto
                        ? Icons.notifications_active
                        : Icons.local_fire_department_outlined,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    algumPronto ? 'Tirar do forno!' : 'No forno',
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              for (final s in sabores)
                Builder(
                  builder: (_) {
                    final pronto = s.fornada.prontoItem(s.item, agora);
                    final r = s.fornada.restanteDe(s.item, agora);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${nomes[s.item.fichaId] ?? 'Produto'} · ${_n(s.item.quantidade)}',
                            ),
                          ),
                          Text(
                            pronto
                                ? 'PRONTO (há ${cronometro(r)})'
                                : 'faltam ${cronometro(r)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: pronto ? cs.error : null,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
