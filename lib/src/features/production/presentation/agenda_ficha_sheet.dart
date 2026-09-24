import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../mise_en_place/domain/mep_plano.dart';
import '../../schedule/domain/production_plan.dart';
import '../application/agenda_cart.dart';

/// Junta um produto final (ficha técnica) ao carrinho da agenda. As unidades
/// e a massa já vêm calculadas em [plano]; aqui só se escolhe a prioridade e
/// a hora limite.
Future<void> showAgendaFichaSheet(BuildContext context, MepPlano plano) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AgendaFichaSheet(plano: plano),
  );
}

class _AgendaFichaSheet extends ConsumerStatefulWidget {
  const _AgendaFichaSheet({required this.plano});
  final MepPlano plano;

  @override
  ConsumerState<_AgendaFichaSheet> createState() => _AgendaFichaSheetState();
}

class _AgendaFichaSheetState extends ConsumerState<_AgendaFichaSheet> {
  Prioridade _prioridade = Prioridade.media;
  TimeOfDay? _hora;

  String get _horaTexto => _hora == null
      ? ''
      : '${_hora!.hour.toString().padLeft(2, '0')}:'
          '${_hora!.minute.toString().padLeft(2, '0')}';

  void _confirmar() {
    final p = widget.plano;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    ref.read(agendaCartProvider.notifier).adicionar(
          CartLinha(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            receitaId: p.receitaId,
            receitaNome: p.nome,
            kg: p.kg,
            formatoId: p.formatoId,
            formatoNome: p.formato,
            unidadesPrevistas: p.unidades,
            fichaId: p.fichaId,
            fichaNome: p.nome,
            prioridade: _prioridade,
            horaLimite: _horaTexto,
          ),
        );
    Navigator.pop(context);
    final total = ref.read(agendaCartProvider).length;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Adicionado ao carrinho ($total '
          '${total == 1 ? 'produção' : 'produções'}).',
        ),
        action: SnackBarAction(
          label: 'Ver produção',
          onPressed: () => router.go('${Routes.production}/agendar'),
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.plano;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(p.nome, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            [
              '${p.unidades} un',
              '${p.kg.toStringAsFixed(2)} kg de massa',
              if (p.formato.isNotEmpty) p.formato,
            ].join(' · '),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Text('Prioridade', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          SegmentedButton<Prioridade>(
            segments: const [
              ButtonSegment(value: Prioridade.alta, label: Text('Alta')),
              ButtonSegment(value: Prioridade.media, label: Text('Média')),
              ButtonSegment(value: Prioridade.baixa, label: Text('Baixa')),
            ],
            selected: {_prioridade},
            onSelectionChanged: (s) => setState(() => _prioridade = s.first),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: Text(
              _hora == null ? 'Hora limite (opcional)' : 'Pronto até $_horaTexto',
            ),
            trailing: _hora == null
                ? const Icon(Icons.chevron_right)
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _hora = null),
                  ),
            onTap: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: _hora ?? const TimeOfDay(hour: 14, minute: 0),
              );
              if (t != null) setState(() => _hora = t);
            },
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _confirmar,
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }
}
