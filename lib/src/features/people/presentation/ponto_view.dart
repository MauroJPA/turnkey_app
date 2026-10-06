import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/errors/mensagem_amigavel.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../pricing/data/cost_config_repository.dart';
import '../../pricing/domain/dias_trabalho.dart';
import '../../quiosque/application/colaboradores_providers.dart';
import '../../quiosque/domain/colaborador.dart';
import '../application/escala_providers.dart';
import '../application/ferias_providers.dart';
import '../application/ponto_providers.dart';
import '../application/saidas_providers.dart';
import '../data/ponto_repository.dart';
import '../domain/escala.dart';
import '../domain/ferias.dart';
import '../domain/ponto.dart';

const _meses = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];
const _dias = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];

String _hora(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
String _data(DateTime d) => '${_dias[d.weekday - 1]} ${d.day}/${d.month}';

void _atualizar(WidgetRef ref) {
  ref.invalidate(pontoMesProvider);
  ref.invalidate(pontoRecenteProvider);
  ref.invalidate(pontoEstadoProvider);
}

/// Registo de ponto: marcar a entrada, a pausa e a saída (também feito no
/// quiosque), ver quem está a trabalhar e as horas do mês. O administrador vê
/// e corrige tudo; cada pessoa vê o seu.
class PontoView extends ConsumerStatefulWidget {
  const PontoView({super.key});

  @override
  ConsumerState<PontoView> createState() => _PontoViewState();
}

class _PontoViewState extends ConsumerState<PontoView> {
  late DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month);
  bool _ocupado = false;

  bool get _admin => ref.read(currentPapelProvider).canEditConfig;

  Future<void> _marcar(TipoPonto tipo) async {
    final repo = ref.read(pontoRepositoryProvider);
    final uid = repo.utilizadorId;
    if (uid == null || _ocupado) return;
    setState(() => _ocupado = true);
    try {
      await repo.registar(
        pessoa: 'u:$uid',
        nome: ref.read(currentUserNameProvider) ?? '',
        userId: uid,
        tipo: tipo,
        dataHora: DateTime.now(),
      );
      _atualizar(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tipo.label} às ${_hora(DateTime.now())}.')),
        );
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  /// Regista a saída esquecida de [s]: à hora do fim do turno (um toque) ou
  /// à hora que a administração escolher.
  Future<void> _registarSaida(SaidaPorMarcar s, {bool escolher = false}) async {
    var quando = s.fimPrevisto;
    if (quando == null || escolher) {
      final base = quando ?? DateTime.now();
      final h = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(base),
        helpText: 'Hora da saída de ${s.nome}',
        builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
      );
      if (h == null) return;
      // no dia da entrada; se a hora fica antes da entrada, é no dia seguinte
      var d = DateTime(
        s.entrada.year,
        s.entrada.month,
        s.entrada.day,
        h.hour,
        h.minute,
      );
      if (!d.isAfter(s.entrada)) d = d.add(const Duration(days: 1));
      quando = d;
    }
    final repo = ref.read(pontoRepositoryProvider);
    try {
      await repo.registar(
        pessoa: s.pessoa,
        nome: s.nome,
        userId: s.pessoa.startsWith('u:') ? s.pessoa.substring(2) : '',
        tipo: TipoPonto.saida,
        dataHora: quando,
        origem: OrigemPonto.manual,
        notas: 'Saída esquecida, registada pela administração',
      );
      _atualizar(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saída de ${s.nome} registada às ${_hora(quando)}.'),
          ),
        );
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final agora = DateTime.now();
    final saidas = ref.watch(saidasPorMarcarProvider);
    final admin = ref.watch(currentPapelProvider).canEditConfig;
    final podeMarcar = ref.watch(currentPapelProvider).canEditBusiness;
    final uid = ref.watch(pontoRepositoryProvider).utilizadorId;
    final recente = ref.watch(pontoRecenteProvider).valueOrNull ?? const [];
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    // horas previstas (escala) para comparar com as marcadas
    final modeloEscala =
        ref.watch(escalaModeloProvider).valueOrNull ?? const <TurnoModelo>[];
    final mesInicio = DateTime(_mes.year, _mes.month);
    final mesFim = DateTime(_mes.year, _mes.month + 1);
    final excecoesMes =
        ref
            .watch(escalaExcecoesProvider((de: mesInicio, ate: mesFim)))
            .valueOrNull ??
        const <ExcecaoEscala>[];
    final ausenciasAno =
        ref.watch(feriasAnoProvider(_mes.year)).valueOrNull ??
        const <Ausencia>[];
    final diasTrab =
        ref.watch(costConfigProvider).valueOrNull?.diasDeTrabalho ??
        todosOsDias;
    // compara-se até ontem (hoje ainda não acabou)
    final hoje0 = DateTime(agora.year, agora.month, agora.day);
    final corte = hoje0.isBefore(mesInicio)
        ? mesInicio
        : (hoje0.isBefore(mesFim) ? hoje0 : mesFim);

    final jornadasRecentes = calcularJornadas(recente, agora);
    final aTrabalhar = [
      for (final j in jornadasRecentes)
        if (j.aTrabalhar) j,
    ];
    // a minha última marcação
    final minhas = [
      for (final r in recente)
        if (r.pessoa == 'u:$uid') r,
    ]..sort((a, b) => a.dataHora.compareTo(b.dataHora));
    var minha = minhas.isEmpty ? null : minhas.last;
    if (minha != null && agora.difference(minha.dataHora) > jornadaMaxima) {
      minha = null;
    }
    final opcoes = proximosPontos(minha?.tipo);

    return AsyncValueView<List<RegistoPonto>>(
      value: ref.watch(pontoMesProvider(_mes)),
      onRetry: () => ref.invalidate(pontoMesProvider),
      data: (registos) {
        final jornadas = calcularJornadas(registos, agora);
        final totais = totaisPorPessoa(jornadas, agora);
        final totalGeral = totais.fold(
          Duration.zero,
          (s, t) => s + t.trabalhado,
        );
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            if (podeMarcar)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('O meu ponto', style: tt.titleSmall),
                      const SizedBox(height: 4),
                      Text(
                        minha == null
                            ? 'Ainda sem entrada hoje.'
                            : '${minha.tipo.label} às ${_hora(minha.dataHora)}.',
                        style: tt.bodyMedium,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (var i = 0; i < opcoes.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 48),
                                ),
                                onPressed: _ocupado
                                    ? null
                                    : () => _marcar(opcoes[i]),
                                child: Text(opcoes[i].label),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (saidas.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                color: cs.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Saída por marcar', style: tt.titleSmall),
                      const SizedBox(height: 4),
                      for (final s in saidas) ...[
                        Text(s.texto(agora), style: tt.bodyMedium),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (s.fimPrevisto != null)
                              Expanded(
                                child: FilledButton(
                                  onPressed: () => _registarSaida(s),
                                  child: Text(
                                    'Saída às ${_hora(s.fimPrevisto!)}',
                                  ),
                                ),
                              ),
                            if (s.fimPrevisto != null) const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    _registarSaida(s, escolher: true),
                                child: const Text('Outra hora…'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            if (admin && aTrabalhar.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('A trabalhar agora', style: tt.titleSmall),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final j in aTrabalhar)
                    Chip(
                      avatar: const Icon(Icons.circle, size: 10),
                      label: Text('${j.nome} · desde ${_hora(j.entrada)}'),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton(
                  tooltip: 'Mês anterior',
                  onPressed: () => setState(
                    () => _mes = DateTime(_mes.year, _mes.month - 1),
                  ),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${_meses[_mes.month - 1]} ${_mes.year}',
                    textAlign: TextAlign.center,
                    style: tt.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Mês seguinte',
                  onPressed: () => setState(
                    () => _mes = DateTime(_mes.year, _mes.month + 1),
                  ),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            if (totais.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  admin
                      ? 'Sem marcações neste mês. As pessoas marcam no quiosque ou aqui.'
                      : 'Sem marcações tuas neste mês.',
                  textAlign: TextAlign.center,
                ),
              ),
            for (final t in totais)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(t.nome.isEmpty ? 'Sem nome' : t.nome),
                  subtitle: Builder(
                    builder: (_) {
                      // conta-se desde o primeiro dia em que a pessoa marcou ponto
                      // neste mês (antes disso ainda não usava o ponto)
                      final dias = [
                        for (final j in jornadas)
                          if (j.pessoa == t.pessoa) j.dia,
                      ]..sort();
                      final previsto = horasPrevistas(
                        pessoa: t.pessoa,
                        de: dias.isEmpty ? mesInicio : dias.first,
                        ate: corte,
                        modelo: modeloEscala,
                        excecoes: excecoesMes,
                        ausencias: ausenciasAno,
                        diasTrabalho: diasTrab,
                      );
                      final marcado = jornadas
                          .where(
                            (j) =>
                                j.pessoa == t.pessoa && j.dia.isBefore(corte),
                          )
                          .fold(
                            Duration.zero,
                            (s, j) => s + j.trabalhado(agora),
                          );
                      return Text(
                        '${t.dias} dia(s)'
                        '${previsto > Duration.zero ? ' · previsto ${formatarDuracao(previsto)} (${saldoTexto(marcado - previsto)})' : ''}'
                        '${t.aTrabalhar ? ' · a trabalhar' : ''}'
                        '${t.avisos > 0 ? ' · ${t.avisos} com aviso' : ''}',
                        style: t.avisos > 0 ? TextStyle(color: cs.error) : null,
                      );
                    },
                  ),
                  trailing: Text(
                    formatarDuracao(t.trabalhado),
                    style: tt.titleMedium,
                  ),
                  onTap: () => _abrirPessoa(
                    t,
                    jornadas.where((j) => j.pessoa == t.pessoa).toList(),
                  ),
                ),
              ),
            if (totais.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: Text(
                  'Total do mês: ${formatarDuracao(totalGeral)}',
                  textAlign: TextAlign.end,
                  style: tt.bodyMedium,
                ),
              ),
            if (jornadas.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    final msg = ScaffoldMessenger.of(context);
                    await Clipboard.setData(
                      ClipboardData(text: jornadasCsv(jornadas, agora)),
                    );
                    msg.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Folha copiada (CSV): cola numa folha de cálculo.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copiar a folha do mês (CSV)'),
                ),
              ),
            if (admin)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Toca numa pessoa para ver os dias e corrigir as marcações.',
                  style: tt.bodySmall?.copyWith(color: cs.outline),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _abrirPessoa(TotalPessoa t, List<Jornada> jornadas) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FolhaPessoa(total: t, jornadas: jornadas, admin: _admin),
    );
  }
}

/// Os dias de uma pessoa no mês, com as marcações (e correções, para o
/// administrador).
class _FolhaPessoa extends ConsumerWidget {
  const _FolhaPessoa({
    required this.total,
    required this.jornadas,
    required this.admin,
  });

  final TotalPessoa total;
  final List<Jornada> jornadas;
  final bool admin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final agora = DateTime.now();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(total.nome, style: tt.titleLarge),
            Text(
              'Total: ${formatarDuracao(total.trabalhado)} em ${total.dias} dia(s)',
              style: tt.bodyMedium,
            ),
            const SizedBox(height: 8),
            for (final j in jornadas)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_data(j.dia)} · ${_hora(j.entrada)}'
                              '${j.saida == null ? '' : '–${_hora(j.saida!)}'}',
                              style: tt.titleSmall,
                            ),
                          ),
                          Text(formatarDuracao(j.trabalhado(agora))),
                        ],
                      ),
                      if (j.pausa > Duration.zero)
                        Text(
                          'Pausa ${formatarDuracao(j.pausa)}',
                          style: tt.bodySmall,
                        ),
                      for (final a in j.avisos)
                        Text(a, style: tt.bodySmall?.copyWith(color: cs.error)),
                      const SizedBox(height: 4),
                      for (final r in j.registos)
                        InkWell(
                          onTap: admin
                              ? () async {
                                  Navigator.pop(context);
                                  await showDialog<void>(
                                    context: context,
                                    builder: (_) => _EditarMarcacao(registo: r),
                                  );
                                }
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${r.tipo.label} ${_hora(r.dataHora)}'
                                    ' · ${r.origem.label}'
                                    '${r.corrigido ? ' · corrigida (era ${_hora(r.dataHoraOriginal ?? r.dataHora)})' : ''}'
                                    '${r.notas.isEmpty ? '' : ' · ${r.notas}'}',
                                    style: tt.bodySmall,
                                  ),
                                ),
                                if (admin)
                                  Icon(
                                    Icons.edit_outlined,
                                    size: 16,
                                    color: cs.outline,
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Corrigir ou apagar uma marcação (administrador).
class _EditarMarcacao extends ConsumerStatefulWidget {
  const _EditarMarcacao({required this.registo});

  final RegistoPonto registo;

  @override
  ConsumerState<_EditarMarcacao> createState() => _EditarMarcacaoState();
}

class _EditarMarcacaoState extends ConsumerState<_EditarMarcacao> {
  late DateTime _quando = widget.registo.dataHora;
  late TipoPonto _tipo = widget.registo.tipo;
  late final _motivo = TextEditingController(text: widget.registo.notas);
  bool _ocupado = false;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _escolherHora() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _quando,
      firstDate: DateTime(_quando.year - 1),
      lastDate: DateTime(_quando.year + 1),
    );
    if (d == null || !mounted) return;
    final h = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_quando),
    );
    if (h == null) return;
    setState(
      () => _quando = DateTime(d.year, d.month, d.day, h.hour, h.minute),
    );
  }

  Future<void> _guardar() async {
    setState(() => _ocupado = true);
    try {
      await ref
          .read(pontoRepositoryProvider)
          .corrigir(
            widget.registo,
            dataHora: _quando,
            tipo: _tipo,
            notas: _motivo.text,
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

  Future<void> _apagar() async {
    final ok = await confirmDialog(
      context,
      titulo: 'Apagar esta marcação?',
      mensagem:
          '${_tipo.label} de ${widget.registo.nome} às ${_hora(widget.registo.dataHora)}. '
          'Não se pode desfazer.',
      confirmar: 'Apagar',
      destrutivo: true,
    );
    if (!ok) return;
    setState(() => _ocupado = true);
    try {
      await ref.read(pontoRepositoryProvider).apagar(widget.registo.id);
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
    return AlertDialog(
      title: Text('Marcação de ${widget.registo.nome}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<TipoPonto>(
              initialValue: _tipo,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: [
                for (final t in TipoPonto.values)
                  DropdownMenuItem(value: t, child: Text(t.label)),
              ],
              onChanged: (v) => setState(() => _tipo = v ?? _tipo),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _escolherHora,
              icon: const Icon(Icons.edit_calendar_outlined),
              label: Text('${_data(_quando)} às ${_hora(_quando)}'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _motivo,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'Motivo da correção',
                helperText: 'Fica registado junto da marcação.',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _ocupado ? null : _apagar,
          child: Text(
            'Apagar',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
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

/// Acrescentar uma marcação que ficou por fazer (administrador).
Future<void> novaMarcacaoManual(BuildContext context, WidgetRef ref) async {
  final pessoas = await ref.read(todosColaboradoresProvider.future);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) =>
        _NovaMarcacao(pessoas: pessoas.where((p) => p.ativo).toList()),
  );
}

class _NovaMarcacao extends ConsumerStatefulWidget {
  const _NovaMarcacao({required this.pessoas});

  final List<Colaborador> pessoas;

  @override
  ConsumerState<_NovaMarcacao> createState() => _NovaMarcacaoState();
}

class _NovaMarcacaoState extends ConsumerState<_NovaMarcacao> {
  Colaborador? _pessoa;
  TipoPonto _tipo = TipoPonto.entrada;
  DateTime _quando = DateTime.now();
  final _motivo = TextEditingController();
  bool _ocupado = false;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _escolherHora() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _quando,
      firstDate: DateTime(_quando.year - 1),
      lastDate: DateTime.now(),
    );
    if (d == null || !mounted) return;
    final h = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_quando),
    );
    if (h == null) return;
    setState(
      () => _quando = DateTime(d.year, d.month, d.day, h.hour, h.minute),
    );
  }

  Future<void> _guardar() async {
    final p = _pessoa;
    if (p == null) return;
    setState(() => _ocupado = true);
    try {
      await ref
          .read(pontoRepositoryProvider)
          .registar(
            pessoa: chavePessoa(p),
            nome: p.nome,
            userId: p.userId,
            tipo: _tipo,
            dataHora: _quando,
            origem: OrigemPonto.manual,
            notas: _motivo.text,
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
    return AlertDialog(
      title: const Text('Nova marcação'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<Colaborador>(
              initialValue: _pessoa,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Pessoa'),
              items: [
                for (final p in widget.pessoas)
                  DropdownMenuItem(value: p, child: Text(p.nome)),
              ],
              onChanged: (v) => setState(() => _pessoa = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<TipoPonto>(
              initialValue: _tipo,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: [
                for (final t in TipoPonto.values)
                  DropdownMenuItem(value: t, child: Text(t.label)),
              ],
              onChanged: (v) => setState(() => _tipo = v ?? _tipo),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _escolherHora,
              icon: const Icon(Icons.edit_calendar_outlined),
              label: Text('${_data(_quando)} às ${_hora(_quando)}'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _motivo,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'Motivo (ex.: esqueceu-se de marcar)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _ocupado ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _ocupado || _pessoa == null ? null : _guardar,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
