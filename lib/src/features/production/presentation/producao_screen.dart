import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/help_actions.dart';
import '../../../core/widgets/hub_segmentos.dart';
import '../../schedule/application/schedule_providers.dart';
import '../../schedule/domain/production_plan.dart';
import '../../schedule/presentation/schedule_screen.dart';
import '../../traceability/presentation/lotes_view.dart';
import 'previsao_assar_view.dart';
import 'production_screen.dart';

/// As secções da Produção.
enum SecaoProducao {
  produzir('Produzir', Icons.blender_outlined, Routes.production),
  agenda('Agenda', Icons.event_note_outlined, Routes.schedule),
  previsao('Quantos assar', Icons.auto_graph, Routes.productionPrevisao),
  lotes('Lotes', Icons.qr_code_2, Routes.productionLotes);

  const SecaoProducao(this.label, this.icon, this.rota);
  final String label;
  final IconData icon;
  final String rota;

  HelpTopic get ajuda => switch (this) {
    SecaoProducao.produzir => HelpTopic.produzir,
    SecaoProducao.agenda => HelpTopic.agenda,
    SecaoProducao.previsao => HelpTopic.previsaoAssar,
    SecaoProducao.lotes => HelpTopic.lotes,
  };
}

/// Produção: tudo numa página — **Produzir** (escolher o produto, ver o mise
/// en place e o custo, registar agora ou agendar) e a **Agenda** das produções
/// planeadas.
class ProducaoScreen extends ConsumerWidget {
  const ProducaoScreen({
    super.key,
    required this.secao,
    this.receitaId,
    this.kgInicial,
  });

  final SecaoProducao secao;
  final String? receitaId;
  final double? kgInicial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // quantas produções ainda por fazer (a partir de hoje)
    final hoje = DateTime.now();
    final dia = DateTime(hoje.year, hoje.month, hoje.day);
    final porFazer =
        (ref.watch(plansListProvider).valueOrNull ?? const <ProducaoPlan>[])
            .where(
              (p) =>
                  p.estado == EstadoProducao.planeada && !p.data.isBefore(dia),
            )
            .length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
        title: const Text('Produção'),
        actions: [HelpActions(topic: secao.ajuda)],
      ),
      body: Column(
        children: [
          HubSegmentos<SecaoProducao>(
            principais: SecaoProducao.values,
            atual: secao,
            rotulo: (s) => s.label,
            icone: (s) => s.icon,
            aoEscolher: (s) => context.go(s.rota),
            emblema: (s) => s == SecaoProducao.agenda && porFazer > 0
                ? (texto: '$porFazer', alerta: false)
                : null,
          ),
          Expanded(
            child: switch (secao) {
              SecaoProducao.produzir => ProductionScreen(
                key: ValueKey('prod-$receitaId'),
                receitaId: receitaId,
                kgInicial: kgInicial,
                embedded: true,
              ),
              SecaoProducao.agenda => const ScheduleScreen(
                key: ValueKey('prod-agenda'),
                embedded: true,
              ),
              SecaoProducao.previsao => const PrevisaoAssarView(
                key: ValueKey('prod-previsao'),
              ),
              SecaoProducao.lotes => const LotesView(
                key: ValueKey('prod-lotes'),
              ),
            },
          ),
        ],
      ),
    );
  }
}
