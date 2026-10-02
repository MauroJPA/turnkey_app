import 'package:flutter/material.dart';

import '../domain/periodo.dart';

/// Escolha do período dos ecrãs financeiros: **Semana** (domingo a sábado,
/// ignora o mês) ou **Mês** (dia 1 ao último dia), com setas para ir a
/// qualquer período passado, e sempre com as datas exatas à vista.
class SeletorPeriodo extends StatelessWidget {
  const SeletorPeriodo({
    super.key,
    required this.periodo,
    required this.onChanged,
  });

  final Periodo periodo;
  final ValueChanged<Periodo> onChanged;

  static DateTime get _hoje {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  TipoPeriodo get _tipo => periodo.tipo ?? TipoPeriodo.semana;

  Periodo _de(TipoPeriodo t, DateTime ref) => switch (t) {
    TipoPeriodo.mes => Periodo.mesDe(ref),
    TipoPeriodo.ano => Periodo.anoDe(ref),
    TipoPeriodo.semana => Periodo.semanaDe(ref),
  };

  String get _nomeTipo => switch (_tipo) {
    TipoPeriodo.mes => 'mês',
    TipoPeriodo.ano => 'ano',
    TipoPeriodo.semana => 'semana',
  };

  Future<void> _escolherData(BuildContext context) async {
    final hoje = _hoje;
    final inicial = periodo.contem(hoje) ? hoje : periodo.desde;
    final d = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2020),
      lastDate: DateTime(hoje.year + 1, 12, 31),
      helpText: 'Escolhe um dia do $_nomeTipo',
    );
    if (d != null) onChanged(_de(_tipo, d));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hoje = _hoje;
    final atual = periodo.contem(hoje);
    final aDecorrer = atual && periodo.ate.isAfter(hoje);
    final podeAvancar = !periodo.seguinte.desde.isAfter(hoje);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<TipoPeriodo>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: TipoPeriodo.semana,
                label: Text('Semana'),
                icon: Icon(Icons.view_week_outlined),
              ),
              ButtonSegment(
                value: TipoPeriodo.mes,
                label: Text('Mês'),
                icon: Icon(Icons.calendar_month_outlined),
              ),
              ButtonSegment(
                value: TipoPeriodo.ano,
                label: Text('Ano'),
                icon: Icon(Icons.event_note_outlined),
              ),
            ],
            selected: {_tipo},
            onSelectionChanged: (s) =>
                onChanged(_de(s.first, atual ? hoje : periodo.desde)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                tooltip: 'Anterior ($_nomeTipo)',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => onChanged(periodo.anterior),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _escolherData(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        Text(
                          periodo.label,
                          style: tt.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          periodo.intervaloTexto,
                          style: tt.bodyMedium?.copyWith(color: cs.primary),
                          textAlign: TextAlign.center,
                        ),
                        if (aDecorrer)
                          Text(
                            'ainda a decorrer — o período é contado inteiro',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!atual)
                IconButton(
                  tooltip: 'Voltar a hoje',
                  icon: const Icon(Icons.today_outlined),
                  onPressed: () => onChanged(_de(_tipo, hoje)),
                ),
              IconButton(
                tooltip: 'Seguinte ($_nomeTipo)',
                icon: const Icon(Icons.chevron_right),
                onPressed: podeAvancar
                    ? () => onChanged(periodo.seguinte)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
