import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/cores_estado.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/errors/mensagem_amigavel.dart';
import '../../../core/printing/print_html.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../pricing/data/cost_config_repository.dart';
import '../../pricing/domain/dias_trabalho.dart';
import '../../quiosque/application/colaboradores_providers.dart';
import '../../quiosque/domain/colaborador.dart';
import '../../settings/application/empresa_providers.dart';
import '../application/escala_providers.dart';
import '../application/ferias_providers.dart';
import '../data/escala_repository.dart';
import '../domain/escala.dart';
import '../domain/ferias.dart';
import '../domain/ponto.dart';
import 'escala_lote_sheet.dart';

void _atualizar(WidgetRef ref) => atualizarEscala(ref);

String _dm(DateTime d) => '${d.day}/${d.month}';

/// A escala semanal da equipa: quem trabalha quando. O horário habitual de
/// cada pessoa define-se uma vez; os dias especiais mudam-se com um toque.
class EscalaView extends ConsumerStatefulWidget {
  const EscalaView({super.key});

  @override
  ConsumerState<EscalaView> createState() => _EscalaViewState();
}

class _EscalaViewState extends ConsumerState<EscalaView> {
  DateTime _segunda = segundaDaSemana(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(currentPapelProvider).canEditConfig;
    final uid = ref.watch(escalaRepositoryProvider).utilizadorId;
    final empresa = ref.watch(currentEmpresaProvider).valueOrNull?.nome ?? '';
    final diasTrab =
        ref.watch(costConfigProvider).valueOrNull?.diasDeTrabalho ??
        todosOsDias;
    final domingo = _segunda.add(const Duration(days: 6));
    final semana = (de: _segunda, ate: _segunda.add(const Duration(days: 7)));
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final hoje = DateTime.now();

    // férias podem estar em dois anos diferentes numa semana de fim de ano
    final ausencias = [
      ...(ref.watch(feriasAnoProvider(_segunda.year)).valueOrNull ??
          const <Ausencia>[]),
      if (domingo.year != _segunda.year)
        ...(ref.watch(feriasAnoProvider(domingo.year)).valueOrNull ??
            const <Ausencia>[]),
    ];
    final pessoasTodas = admin
        ? (ref.watch(todosColaboradoresProvider).valueOrNull ??
              const <Colaborador>[])
        : const <Colaborador>[];

    return AsyncValueView<List<TurnoModelo>>(
      value: ref.watch(escalaModeloProvider),
      onRetry: () => ref.invalidate(escalaModeloProvider),
      data: (modelo) {
        final excecoes =
            ref.watch(escalaExcecoesProvider(semana)).valueOrNull ??
            const <ExcecaoEscala>[];
        final regras =
            ref.watch(escalaRegrasProvider).valueOrNull ??
            const <RegraEscala>[];

        // quem aparece: a administração vê toda a equipa (para a poder
        // configurar); os outros veem quem já tem horário
        final pessoas = <String, ({String nome, String userId})>{};
        for (final m in modelo) {
          pessoas[m.pessoa] = (nome: m.nome, userId: m.userId);
        }
        for (final e in excecoes) {
          pessoas.putIfAbsent(e.pessoa, () => (nome: e.nome, userId: e.userId));
        }
        for (final c in pessoasTodas.where((c) => c.ativo)) {
          pessoas[chavePessoa(c)] = (nome: c.nome, userId: c.userId);
        }
        final linhas = pessoas.entries.toList()
          ..sort(
            (a, b) => a.value.nome.toLowerCase().compareTo(
              b.value.nome.toLowerCase(),
            ),
          );

        List<DiaEscala> semanaDe(String pessoa) => [
          for (var i = 0; i < 7; i++)
            diaDaEscala(
              pessoa: pessoa,
              dia: _segunda.add(Duration(days: i)),
              modelo: modelo,
              excecoes: excecoes,
              regras: regras,
              ausencias: ausencias,
              diasTrabalho: diasTrab,
            ),
        ];

        // para o "Horário em lote": toda a equipa que a escala conhece
        final equipa = <PessoaEscala>[
          for (final p in linhas)
            (chave: p.key, nome: p.value.nome, userId: p.value.userId),
        ];

        final meu = uid == null ? null : semanaDe('u:$uid');

        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Semana anterior',
                  onPressed: () => setState(
                    () => _segunda = _segunda.subtract(const Duration(days: 7)),
                  ),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(
                      () => _segunda = segundaDaSemana(DateTime.now()),
                    ),
                    child: Text(
                      '${_dm(_segunda)} a ${_dm(domingo)}',
                      textAlign: TextAlign.center,
                      style: tt.titleMedium,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Semana seguinte',
                  onPressed: () => setState(
                    () => _segunda = _segunda.add(const Duration(days: 7)),
                  ),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            if (meu != null && meu.any((d) => d.estado != EstadoDia.fechado))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('O meu horário', style: tt.titleSmall),
                      const SizedBox(height: 4),
                      for (final d in meu)
                        if (d.estado != EstadoDia.fechado)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 78,
                                  child: Text(
                                    '${nomesDiasCurtos[d.dia.weekday - 1]} ${_dm(d.dia)}',
                                    style: tt.bodySmall?.copyWith(
                                      fontWeight:
                                          d.dia ==
                                              DateTime(
                                                hoje.year,
                                                hoje.month,
                                                hoje.day,
                                              )
                                          ? FontWeight.bold
                                          : null,
                                    ),
                                  ),
                                ),
                                Text(
                                  d.texto,
                                  style: tt.bodyMedium?.copyWith(
                                    color: d.estado == EstadoDia.turno
                                        ? null
                                        : cs.outline,
                                  ),
                                ),
                                if (d.excecao && d.estado != EstadoDia.ausente)
                                  Text(
                                    '  (alterado)',
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.primary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            _Cabecalho(segunda: _segunda, diasTrab: diasTrab),
            if (linhas.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  admin
                      ? 'Ainda não há pessoas. Adiciona-as em Equipa e cartões.'
                      : 'Ainda não há horário definido.',
                  textAlign: TextAlign.center,
                ),
              ),
            for (final p in linhas)
              _LinhaPessoa(
                nome: p.value.nome,
                dias: semanaDe(p.key),
                onNome: admin
                    ? () => _editarModelo(
                        p.key,
                        p.value.nome,
                        p.value.userId,
                        modelo,
                        diasTrab,
                      )
                    : null,
                onDia: admin
                    ? (d) => _editarDia(
                        p.key,
                        p.value.nome,
                        p.value.userId,
                        d,
                        equipa,
                        diasTrab,
                      )
                    : null,
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (admin && equipa.isNotEmpty)
                  FilledButton.tonalIcon(
                    onPressed: () => abrirLoteEscala(
                      context,
                      pessoas: equipa,
                      diasTrab: diasTrab,
                    ),
                    icon: const Icon(Icons.playlist_add_check),
                    label: const Text('Horário em lote'),
                  ),
                if (linhas.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => abrirImpressao(
                      'Mapa de horário',
                      mapaHorarioHtml(
                        empresa: empresa,
                        segunda: _segunda,
                        linhas: [
                          for (final p in linhas)
                            (nome: p.value.nome, dias: semanaDe(p.key)),
                        ],
                      ),
                      estiloExtra: mapaHorarioEstilo,
                    ),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Imprimir o mapa de horário'),
                  ),
              ],
            ),
            if (admin) const ListaRegrasEscala(),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                admin
                    ? 'Nome: horário habitual (dia sem turno = folga fixa). '
                          'Dia: muda só esse dia. "Horário em lote": várias '
                          'pessoas e dias, para sempre ou até uma data. Dias '
                          'fechados são folga automática. Contorno forte = '
                          'alterado só nesse dia; suave = regra em lote.'
                    : 'Dias fechados são folga automática.',
                style: tt.bodySmall?.copyWith(color: cs.outline),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editarModelo(
    String pessoa,
    String nome,
    String userId,
    List<TurnoModelo> todos,
    Set<int> diasTrab,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ModeloDialog(
        pessoa: pessoa,
        nome: nome,
        userId: userId,
        atual: [
          for (final m in todos)
            if (m.pessoa == pessoa) m,
        ],
        diasTrabalho: diasTrab,
      ),
    );
  }

  Future<void> _editarDia(
    String pessoa,
    String nome,
    String userId,
    DiaEscala d,
    List<PessoaEscala> equipa,
    Set<int> diasTrab,
  ) async {
    if (d.estado == EstadoDia.ausente) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${d.texto}: muda em Férias se preciso. A escala respeita as '
            'ausências aprovadas.',
          ),
        ),
      );
      return;
    }
    final lote = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _DiaDialog(pessoa: pessoa, nome: nome, userId: userId, dia: d),
    );
    if (lote == true && mounted) {
      await abrirLoteEscala(
        context,
        pessoas: equipa,
        diasTrab: diasTrab,
        selecionadas: {pessoa},
        de: d.dia,
        ate: d.dia,
        folga: d.estado != EstadoDia.turno,
        dias: {d.dia.weekday},
      );
    }
  }
}

/// A linha dos dias da semana.
class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.segunda, required this.diasTrab});

  final DateTime segunda;
  final Set<int> diasTrab;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final hoje = DateTime.now();
    return Row(
      children: [
        const SizedBox(width: 72),
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Builder(
              builder: (_) {
                final d = segunda.add(Duration(days: i));
                final eHoje =
                    d.year == hoje.year &&
                    d.month == hoje.month &&
                    d.day == hoje.day;
                return Column(
                  children: [
                    Text(
                      nomesDiasCurtos[i],
                      style: tt.labelSmall?.copyWith(
                        fontWeight: eHoje ? FontWeight.bold : null,
                        color: diasTrab.contains(i + 1) ? null : cs.outline,
                      ),
                    ),
                    Text(
                      '${d.day}',
                      style: tt.labelSmall?.copyWith(
                        fontWeight: eHoje ? FontWeight.bold : null,
                        color: eHoje ? cs.primary : cs.outline,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}

class _LinhaPessoa extends StatelessWidget {
  const _LinhaPessoa({
    required this.nome,
    required this.dias,
    this.onNome,
    this.onDia,
  });

  final String nome;
  final List<DiaEscala> dias;
  final VoidCallback? onNome;
  final void Function(DiaEscala)? onDia;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final total = dias.fold(Duration.zero, (s, d) => s + d.previsto);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: InkWell(
              onTap: onNome,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nome.isEmpty ? '—' : nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelLarge,
                    ),
                    Text(
                      '${total.inMinutes ~/ 60}h${total.inMinutes % 60 == 0 ? '' : ' ${total.inMinutes % 60}m'}',
                      style: tt.labelSmall?.copyWith(color: cs.outline),
                    ),
                  ],
                ),
              ),
            ),
          ),
          for (final d in dias)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(1.5),
                child: _Celula(
                  dia: d,
                  onTap: onDia == null ? null : () => onDia!(d),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Celula extends StatelessWidget {
  const _Celula({required this.dia, this.onTap});

  final DiaEscala dia;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final (fundo, texto) = switch (dia.estado) {
      EstadoDia.turno => (cs.primaryContainer, cs.onPrimaryContainer),
      EstadoDia.folga => (cs.surfaceContainerHighest, cs.outline),
      EstadoDia.fechado => (
        cs.surfaceContainerLow,
        cs.outline.withValues(alpha: 0.7),
      ),
      EstadoDia.ausente => (
        dia.ausencia?.tipo == TipoAusencia.ferias
            ? cs.sucesso.withValues(alpha: 0.35)
            : cs.aviso.withValues(alpha: 0.35),
        cs.onSurface,
      ),
    };
    final estilo = tt.labelSmall?.copyWith(
      fontSize: 10,
      color: texto,
      height: 1.15,
    );
    return Material(
      color: fundo,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          height: 40,
          decoration: dia.excecao
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: cs.primary, width: 1.2),
                )
              : (dia.regra
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: cs.tertiary.withValues(alpha: 0.8),
                          width: 1,
                        ),
                      )
                    : null),
          alignment: Alignment.center,
          child: dia.estado == EstadoDia.turno
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(escreverHora(dia.inicio), style: estilo),
                    Text(escreverHora(dia.fim), style: estilo),
                  ],
                )
              : Text(switch (dia.estado) {
                  EstadoDia.folga => 'folga',
                  EstadoDia.fechado => 'folga',
                  _ => dia.texto.toLowerCase(),
                }, style: estilo),
        ),
      ),
    );
  }
}

/// O horário habitual de uma pessoa: um dia por linha.
class _ModeloDialog extends ConsumerStatefulWidget {
  const _ModeloDialog({
    required this.pessoa,
    required this.nome,
    required this.userId,
    required this.atual,
    required this.diasTrabalho,
  });

  final String pessoa;
  final String nome;
  final String userId;
  final List<TurnoModelo> atual;
  final Set<int> diasTrabalho;

  @override
  ConsumerState<_ModeloDialog> createState() => _ModeloDialogState();
}

class _ModeloDialogState extends ConsumerState<_ModeloDialog> {
  late final Map<int, bool> _ativo;
  late final Map<int, int> _inicio;
  late final Map<int, int> _fim;
  late final Map<int, int> _pausa;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    final semModelo = widget.atual.isEmpty;
    _ativo = {};
    _inicio = {};
    _fim = {};
    _pausa = {};
    for (var d = 1; d <= 7; d++) {
      TurnoModelo? m;
      for (final t in widget.atual) {
        if (t.diaSemana == d) m = t;
      }
      // um dia em que a empresa fecha já é folga automática
      _ativo[d] = widget.diasTrabalho.contains(d) && (m != null || semModelo);
      _inicio[d] = m?.inicio ?? 8 * 60;
      _fim[d] = m?.fim ?? 16 * 60 + 30;
      _pausa[d] = m?.pausaMin ?? 30;
    }
  }

  void _igualAoPrimeiro() {
    final primeiro = [
      for (var d = 1; d <= 7; d++)
        if (_ativo[d]!) d,
    ];
    if (primeiro.isEmpty) return;
    final p = primeiro.first;
    setState(() {
      for (final d in primeiro) {
        _inicio[d] = _inicio[p]!;
        _fim[d] = _fim[p]!;
        _pausa[d] = _pausa[p]!;
      }
    });
  }

  Future<void> _guardar() async {
    setState(() => _ocupado = true);
    try {
      await ref
          .read(escalaRepositoryProvider)
          .guardarModelo(
            pessoa: widget.pessoa,
            nome: widget.nome,
            userId: widget.userId,
            dias: {
              for (var d = 1; d <= 7; d++)
                if (_ativo[d]!)
                  d: (inicio: _inicio[d]!, fim: _fim[d]!, pausaMin: _pausa[d]!),
            },
          );
      _atualizar(ref);
      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      if (mounted) {
        setState(() => _ocupado = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text('Horário de ${widget.nome}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Marca os dias em que trabalha e as horas. Os dias sem marca '
                'são folga fixa, todas as semanas (e os dias fechados já são '
                'folga automática).',
                style: tt.bodySmall,
              ),
              const SizedBox(height: 8),
              for (var d = 1; d <= 7; d++)
                Row(
                  children: [
                    Checkbox(
                      value: _ativo[d],
                      onChanged: !widget.diasTrabalho.contains(d)
                          ? null
                          : (v) => setState(() => _ativo[d] = v ?? false),
                    ),
                    SizedBox(
                      width: 34,
                      child: Text(
                        nomesDiasCurtos[d - 1],
                        style: tt.bodyMedium?.copyWith(
                          color: _ativo[d]! ? null : cs.outline,
                        ),
                      ),
                    ),
                    if (!widget.diasTrabalho.contains(d))
                      Expanded(
                        child: Text(
                          'fechado · folga automática',
                          style: tt.bodySmall?.copyWith(color: cs.outline),
                        ),
                      )
                    else ...[
                      Expanded(
                        child: TextButton(
                          onPressed: !_ativo[d]!
                              ? null
                              : () async {
                                  final h = await escolherHora(
                                    context,
                                    _inicio[d]!,
                                  );
                                  if (h != null) setState(() => _inicio[d] = h);
                                },
                          child: Text(escreverHora(_inicio[d]!)),
                        ),
                      ),
                      const Text('–'),
                      Expanded(
                        child: TextButton(
                          onPressed: !_ativo[d]!
                              ? null
                              : () async {
                                  final h = await escolherHora(
                                    context,
                                    _fim[d]!,
                                  );
                                  if (h != null) setState(() => _fim[d] = h);
                                },
                          child: Text(escreverHora(_fim[d]!)),
                        ),
                      ),
                      SizedBox(
                        width: 70,
                        child: DropdownButton<int>(
                          value:
                              const [0, 15, 30, 45, 60, 90].contains(_pausa[d])
                              ? _pausa[d]
                              : 30,
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          items: [
                            for (final m in const [0, 15, 30, 45, 60, 90])
                              DropdownMenuItem(
                                value: m,
                                child: Text(m == 0 ? 'sem pausa' : '${m}m'),
                              ),
                          ],
                          onChanged: _ativo[d]!
                              ? (v) => setState(() => _pausa[d] = v ?? 30)
                              : null,
                        ),
                      ),
                    ],
                  ],
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _igualAoPrimeiro,
                  icon: const Icon(Icons.content_copy, size: 18),
                  label: const Text('Igual ao primeiro dia marcado'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _ocupado ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _ocupado ? null : _guardar,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

/// Mudar um dia concreto: outro turno ou folga.
class _DiaDialog extends ConsumerStatefulWidget {
  const _DiaDialog({
    required this.pessoa,
    required this.nome,
    required this.userId,
    required this.dia,
  });

  final String pessoa;
  final String nome;
  final String userId;
  final DiaEscala dia;

  @override
  ConsumerState<_DiaDialog> createState() => _DiaDialogState();
}

class _DiaDialogState extends ConsumerState<_DiaDialog> {
  late bool _trabalha = widget.dia.estado == EstadoDia.turno;
  late int _inicio = widget.dia.estado == EstadoDia.turno
      ? widget.dia.inicio
      : 8 * 60;
  late int _fim = widget.dia.estado == EstadoDia.turno
      ? widget.dia.fim
      : 16 * 60 + 30;
  late int _pausa = widget.dia.estado == EstadoDia.turno
      ? widget.dia.pausaMin
      : 30;
  late final _notas = TextEditingController(text: widget.dia.notas);
  bool _ocupado = false;

  @override
  void dispose() {
    _notas.dispose();
    super.dispose();
  }

  Future<void> _fazer(Future<void> Function() acao) async {
    setState(() => _ocupado = true);
    try {
      await acao();
      _atualizar(ref);
      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      if (mounted) {
        setState(() => _ocupado = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.dia.dia;
    final repo = ref.read(escalaRepositoryProvider);
    return AlertDialog(
      title: Text(
        '${widget.nome} · ${nomesDiasCurtos[d.weekday - 1]} ${_dm(d)}',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Trabalha')),
                ButtonSegment(value: false, label: Text('Folga')),
              ],
              selected: {_trabalha},
              onSelectionChanged: (s) => setState(() => _trabalha = s.first),
            ),
            if (_trabalha) ...[
              const SizedBox(height: 12),
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
                initialValue: const [0, 15, 30, 45, 60, 90].contains(_pausa)
                    ? _pausa
                    : 30,
                decoration: const InputDecoration(labelText: 'Pausa'),
                items: [
                  for (final m in const [0, 15, 30, 45, 60, 90])
                    DropdownMenuItem(
                      value: m,
                      child: Text(m == 0 ? 'Sem pausa' : '$m minutos'),
                    ),
                ],
                onChanged: (v) => setState(() => _pausa = v ?? 30),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _notas,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Nota (opcional)',
                helperText: 'Ex.: troca com o Rui',
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.dia.excecao)
          TextButton(
            onPressed: _ocupado
                ? null
                : () => _fazer(
                    () => repo.removerExcecao(pessoa: widget.pessoa, dia: d),
                  ),
            child: const Text('Voltar ao habitual'),
          ),
        TextButton(
          onPressed: _ocupado ? null : () => Navigator.pop(context, true),
          child: const Text('Vários dias…'),
        ),
        TextButton(
          onPressed: _ocupado ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _ocupado
              ? null
              : () => _fazer(
                  () => repo.definirExcecao(
                    pessoa: widget.pessoa,
                    nome: widget.nome,
                    userId: widget.userId,
                    dia: d,
                    horario: _trabalha
                        ? (inicio: _inicio, fim: _fim, pausaMin: _pausa)
                        : null,
                    notas: _notas.text,
                  ),
                ),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
