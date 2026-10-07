import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/mensagem_amigavel.dart';
import '../../../core/widgets/desfazer.dart';
import '../../pricing/domain/dias_trabalho.dart';
import '../application/escala_providers.dart';
import '../data/escala_repository.dart';
import '../domain/escala.dart';

/// Refaz o que a escala mostra (horário habitual, alterações e regras).
void atualizarEscala(WidgetRef ref) {
  ref.invalidate(escalaModeloProvider);
  ref.invalidate(escalaRegrasProvider);
  ref.invalidate(escalaExcecoesProvider);
}

Future<int?> escolherHora(BuildContext context, int atual) async {
  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: atual ~/ 60, minute: atual % 60),
    builder: (ctx, child) => MediaQuery(
      data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );
  return t == null ? null : t.hour * 60 + t.minute;
}

/// Uma pessoa da equipa, como a escala a identifica.
typedef PessoaEscala = ({String chave, String nome, String userId});

String _dmy(DateTime d) => '${d.day}/${d.month}/${d.year}';

const _pausas = [0, 15, 30, 45, 60, 90];

/// Abre o "Horário em lote": o mesmo horário (ou folga) para várias pessoas e
/// vários dias da semana de uma só vez, para sempre ou até uma data.
Future<void> abrirLoteEscala(
  BuildContext context, {
  required List<PessoaEscala> pessoas,
  required Set<int> diasTrab,
  Set<String> selecionadas = const {},
  DateTime? de,
  DateTime? ate,
  bool folga = false,
  Set<int> dias = const {},
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => LoteEscalaSheet(
      pessoas: pessoas,
      diasTrab: diasTrab,
      selecionadas: selecionadas,
      de: de,
      ate: ate,
      folga: folga,
      dias: dias,
    ),
  );
}

class LoteEscalaSheet extends ConsumerStatefulWidget {
  const LoteEscalaSheet({
    super.key,
    required this.pessoas,
    required this.diasTrab,
    this.selecionadas = const {},
    this.de,
    this.ate,
    this.folga = false,
    this.dias = const {},
  });

  final List<PessoaEscala> pessoas;
  final Set<int> diasTrab;
  final Set<String> selecionadas;
  final DateTime? de;
  final DateTime? ate;
  final bool folga;
  final Set<int> dias;

  @override
  ConsumerState<LoteEscalaSheet> createState() => _LoteEscalaSheetState();
}

class _LoteEscalaSheetState extends ConsumerState<LoteEscalaSheet> {
  late final Set<String> _sel = {...widget.selecionadas};
  late bool _trabalha = !widget.folga;
  int _inicio = 8 * 60;
  int _fim = 16 * 60 + 30;
  int _pausa = 30;
  late final Set<int> _dias = widget.dias.isNotEmpty
      ? {...widget.dias}
      : (widget.folga ? <int>{} : {...widget.diasTrab});
  late DateTime _de = widget.de ?? _hoje();
  late bool _paraSempre = widget.ate == null && widget.de == null;
  late DateTime _ate = widget.ate ?? _hoje().add(const Duration(days: 13));
  int _cada = 1;
  bool _saltarFeriados = false;
  final _notas = TextEditingController();
  bool _ocupado = false;

  static DateTime _hoje() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void dispose() {
    _notas.dispose();
    super.dispose();
  }

  bool _fechado(int d) => !widget.diasTrab.contains(d);

  Set<int> _abertos(Iterable<int> dias) => {
    for (final d in dias)
      if (!_fechado(d)) d,
  };

  String? _erro() {
    if (_sel.isEmpty) return 'Escolhe pelo menos uma pessoa.';
    if (_dias.isEmpty) return 'Escolhe pelo menos um dia da semana.';
    if (_trabalha && _inicio == _fim) {
      return 'A hora de entrada e a de saída não podem ser iguais.';
    }
    if (!_paraSempre && _ate.isBefore(_de)) {
      return 'A data final é anterior à inicial.';
    }
    return null;
  }

  RegraEscala _regra() => RegraEscala(
    pessoa: '',
    dias: _dias,
    de: _de,
    ate: _paraSempre ? null : _ate,
    folga: !_trabalha,
    inicio: _trabalha ? _inicio : null,
    fim: _trabalha ? _fim : null,
    pausaMin: _pausa,
    cadaSemanas: _cada,
  );

  Future<void> _data(bool inicio) async {
    final base = inicio ? _de : _ate;
    final hoje = _hoje();
    final d = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(hoje.year - 1),
      lastDate: DateTime(hoje.year + 3, 12, 31),
    );
    if (d == null) return;
    setState(() {
      if (inicio) {
        _de = d;
        if (!_paraSempre && _ate.isBefore(d)) _ate = d;
      } else {
        _ate = d;
      }
    });
  }

  Future<void> _aplicar() async {
    final e = _erro();
    if (e != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e)));
      return;
    }
    setState(() => _ocupado = true);
    try {
      final pessoas = [
        for (final p in widget.pessoas)
          if (_sel.contains(p.chave))
            (pessoa: p.chave, nome: p.nome, userId: p.userId),
      ];
      await ref
          .read(escalaRepositoryProvider)
          .criarLote(
            pessoas: pessoas,
            dias: _dias,
            de: _de,
            ate: _paraSempre ? null : _ate,
            horario: _trabalha
                ? (inicio: _inicio, fim: _fim, pausaMin: _pausa)
                : null,
            cadaSemanas: _cada,
            saltarFeriados: _saltarFeriados,
            notas: _notas.text,
          );
      atualizarEscala(ref);
      if (!mounted) return;
      final n = pessoas.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _trabalha
                ? 'Horário aplicado a $n ${n == 1 ? 'pessoa' : 'pessoas'}.'
                : 'Folgas marcadas para $n ${n == 1 ? 'pessoa' : 'pessoas'}.',
          ),
        ),
      );
      Navigator.pop(context);
    } on Object catch (e) {
      if (mounted) {
        setState(() => _ocupado = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
      }
    }
  }

  Widget _titulo(String t) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 6),
    child: Text(t, style: Theme.of(context).textTheme.titleSmall),
  );

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final fechados = [
      for (var d = 1; d <= 7; d++)
        if (_fechado(d)) nomesDiasCurtos[d - 1],
    ];
    final erro = _erro();
    final nomes = [
      for (final p in widget.pessoas)
        if (_sel.contains(p.chave)) p.nome,
    ];
    final resumo = erro != null
        ? null
        : '${nomes.length <= 3 ? nomes.join(', ') : '${nomes.take(2).join(', ')} e mais ${nomes.length - 2}'}'
              ' · ${_regra().resumo}';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Horário em lote', style: tt.titleLarge),
            const SizedBox(height: 2),
            Text(
              'Define uma vez e repete: para várias pessoas, vários dias da '
              'semana, para sempre ou até uma data.',
              style: tt.bodySmall?.copyWith(color: cs.outline),
            ),
            _titulo('1. Quem'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final p in widget.pessoas)
                  FilterChip(
                    label: Text(p.nome.isEmpty ? '—' : p.nome),
                    selected: _sel.contains(p.chave),
                    onSelected: (v) => setState(
                      () => v ? _sel.add(p.chave) : _sel.remove(p.chave),
                    ),
                  ),
              ],
            ),
            Wrap(
              children: [
                TextButton(
                  onPressed: () => setState(
                    () => _sel.addAll(widget.pessoas.map((p) => p.chave)),
                  ),
                  child: const Text('Toda a equipa'),
                ),
                TextButton(
                  onPressed: () => setState(_sel.clear),
                  child: const Text('Ninguém'),
                ),
              ],
            ),
            _titulo('2. O que muda'),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.schedule),
                  label: Text('Trabalha'),
                ),
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.weekend_outlined),
                  label: Text('Folga'),
                ),
              ],
              selected: {_trabalha},
              onSelectionChanged: (s) => setState(() => _trabalha = s.first),
            ),
            if (_trabalha) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final h = await escolherHora(context, _inicio);
                        if (h != null) setState(() => _inicio = h);
                      },
                      child: Text(escreverHora(_inicio)),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('até'),
                  ),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final h = await escolherHora(context, _fim);
                        if (h != null) setState(() => _fim = h);
                      },
                      child: Text(escreverHora(_fim)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _pausas.contains(_pausa) ? _pausa : 30,
                decoration: const InputDecoration(labelText: 'Pausa'),
                items: [
                  for (final m in _pausas)
                    DropdownMenuItem(
                      value: m,
                      child: Text(m == 0 ? 'Sem pausa' : '$m minutos'),
                    ),
                ],
                onChanged: (v) => setState(() => _pausa = v ?? 30),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Folga fixa: p. ex. todas as quartas-feiras, para sempre.',
                  style: tt.bodySmall?.copyWith(color: cs.outline),
                ),
              ),
            _titulo('3. Em que dias da semana'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (var d = 1; d <= 7; d++)
                  FilterChip(
                    label: Text(
                      _fechado(d)
                          ? '${nomesDiasCurtos[d - 1]} · fechado'
                          : nomesDiasCurtos[d - 1],
                    ),
                    selected: _dias.contains(d),
                    onSelected: _fechado(d)
                        ? null
                        : (v) => setState(
                            () => v ? _dias.add(d) : _dias.remove(d),
                          ),
                  ),
              ],
            ),
            Wrap(
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    _dias
                      ..clear()
                      ..addAll(widget.diasTrab);
                  }),
                  child: const Text('Dias de trabalho'),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _dias
                      ..clear()
                      ..addAll(_abertos(const [1, 2, 3, 4, 5]));
                  }),
                  child: const Text('Seg a sex'),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _dias
                      ..clear()
                      ..addAll(_abertos(const [6, 7]));
                  }),
                  child: const Text('Fim de semana'),
                ),
              ],
            ),
            if (fechados.isNotEmpty)
              Text(
                'Dias fechados (${fechados.join(', ')}) já são folga automática '
                'para todos — não precisas de os marcar.',
                style: tt.bodySmall?.copyWith(color: cs.outline),
              ),
            _titulo('4. Durante quanto tempo'),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Para sempre')),
                ButtonSegment(value: false, label: Text('Até uma data')),
              ],
              selected: {_paraSempre},
              onSelectionChanged: (s) => setState(() => _paraSempre = s.first),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _data(true),
                    icon: const Icon(Icons.event, size: 18),
                    label: Text('Desde ${_dmy(_de)}'),
                  ),
                ),
                if (!_paraSempre) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _data(false),
                      icon: const Icon(Icons.event_available, size: 18),
                      label: Text('Até ${_dmy(_ate)}'),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('Todas as semanas')),
                ButtonSegment(value: 2, label: Text('Semanas alternadas')),
              ],
              selected: {_cada},
              onSelectionChanged: (s) => setState(() => _cada = s.first),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _saltarFeriados,
              onChanged: (v) => setState(() => _saltarFeriados = v ?? false),
              title: const Text('Não aplicar nos feriados nacionais'),
            ),
            TextField(
              controller: _notas,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Nota (opcional)',
                helperText: 'Ex.: horário de verão',
              ),
            ),
            const SizedBox(height: 4),
            Card(
              margin: EdgeInsets.zero,
              color: cs.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  resumo ?? erro!,
                  style: tt.bodyMedium?.copyWith(
                    color: resumo == null ? cs.error : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Passa por cima do horário habitual nesses dias. As férias e '
              'baixas aprovadas e as alterações de um só dia continuam a ter '
              'prioridade; a regra mais recente ganha às anteriores.',
              style: tt.bodySmall?.copyWith(color: cs.outline),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _ocupado ? null : _aplicar,
              icon: const Icon(Icons.done_all),
              label: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// As regras de horário em vigor (ou futuras), agrupadas por lote.
class ListaRegrasEscala extends ConsumerWidget {
  const ListaRegrasEscala({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ocultos = ref.watch(ocultosProvider);
    final regras = [
      for (final r
          in ref.watch(escalaRegrasProvider).valueOrNull ??
              const <RegraEscala>[])
        if (!ocultos.contains(r.lote)) r,
    ];
    final n = DateTime.now();
    final hoje = DateTime(n.year, n.month, n.day);
    final porLote = <String, List<RegraEscala>>{};
    for (final r in regras) {
      if (r.ate != null && r.ate!.isBefore(hoje)) continue; // já acabou
      porLote.putIfAbsent(r.lote, () => []).add(r);
    }
    if (porLote.isEmpty) return const SizedBox.shrink();
    final lotes = porLote.values.toList()
      ..sort((a, b) => b.first.de.compareTo(a.first.de));
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    Future<void> acao(List<RegraEscala> l, String a) async {
      final repo = ref.read(escalaRepositoryProvider);
      try {
        if (a == 'parar') {
          await repo.terminarLote(
            l.first.lote,
            hoje.subtract(const Duration(days: 1)),
          );
          atualizarEscala(ref);
        } else {
          await apagarComDesfazer(
            context,
            id: l.first.lote,
            mensagem: 'Regra apagada — os dias voltam ao horário habitual',
            apagar: () => repo.apagarLote(l.first.lote),
            depois: () => atualizarEscala(ref),
            aoFalhar: (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
              }
            },
          );
        }
      } on Object catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
        }
      }
    }

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(Icons.repeat),
        title: Text('Regras de horário (${lotes.length})'),
        subtitle: Text(
          'Mudanças que se repetem — toca para ver, parar ou apagar',
          style: tt.bodySmall?.copyWith(color: cs.outline),
        ),
        children: [
          for (final l in lotes)
            ListTile(
              dense: true,
              title: Text(
                l.length <= 3
                    ? l.map((r) => r.nome).join(', ')
                    : '${l.take(2).map((r) => r.nome).join(', ')} e mais ${l.length - 2}',
              ),
              subtitle: Text(
                '${l.first.resumo}${l.first.notas.isEmpty ? '' : '\n${l.first.notas}'}',
              ),
              isThreeLine: l.first.notas.isNotEmpty,
              trailing: PopupMenuButton<String>(
                tooltip: 'Opções da regra',
                onSelected: (a) => acao(l, a),
                itemBuilder: (_) => [
                  if (!l.first.de.isAfter(hoje) &&
                      (l.first.ate == null || !l.first.ate!.isBefore(hoje)))
                    const PopupMenuItem(
                      value: 'parar',
                      child: Text('Parar a partir de hoje'),
                    ),
                  const PopupMenuItem(value: 'apagar', child: Text('Apagar')),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
