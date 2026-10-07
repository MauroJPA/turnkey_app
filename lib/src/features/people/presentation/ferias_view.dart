import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/errors/mensagem_amigavel.dart';
import '../../../core/printing/print_html.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/desfazer.dart';
import '../../quiosque/application/colaboradores_providers.dart';
import '../../quiosque/domain/colaborador.dart';
import '../../settings/application/empresa_providers.dart';
import '../application/ferias_providers.dart';
import '../data/ferias_repository.dart';
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

void _atualizar(WidgetRef ref) {
  ref.invalidate(feriasAnoProvider);
  ref.invalidate(feriasDireitosProvider);
}

Color _corDe(Ausencia a, ColorScheme cs) {
  final base = switch (a.tipo) {
    TipoAusencia.ferias => Colors.green,
    TipoAusencia.baixa => Colors.orange,
    TipoAusencia.falta => cs.error,
    TipoAusencia.outro => cs.outline,
  };
  return a.estado == EstadoAusencia.pedido
      ? base.withValues(alpha: 0.35)
      : base;
}

/// Mapa de férias e ausências: pedir férias, aprovar (administração), ver quem
/// está fora em cada dia, o saldo de dias e imprimir o mapa do ano.
class FeriasView extends ConsumerStatefulWidget {
  const FeriasView({super.key});

  @override
  ConsumerState<FeriasView> createState() => _FeriasViewState();
}

class _FeriasViewState extends ConsumerState<FeriasView> {
  late int _ano = DateTime.now().year;
  late int _mes = DateTime.now().month;

  Future<void> _decidir(Ausencia a, EstadoAusencia estado) async {
    try {
      await ref.read(feriasRepositoryProvider).decidir(a.id, estado);
      _atualizar(ref);
    } on Object catch (e) {
      _erro(e);
    }
  }

  void _erro(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
  }

  Future<void> _apagar(Ausencia a) => apagarComDesfazer(
    context,
    id: a.id,
    mensagem: '${a.tipo.label} apagada: ${a.nome}, ${periodoTexto(a)}',
    apagar: () => ref.read(feriasRepositoryProvider).apagar(a.id),
    depois: () => _atualizar(ref),
    aoFalhar: _erro,
  );

  Future<void> _pedir(List<Ausencia> existentes) async {
    final pessoas = ref.read(currentPapelProvider).canEditConfig
        ? await ref.read(todosColaboradoresProvider.future)
        : const <Colaborador>[];
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _PedirDialog(
        existentes: existentes,
        pessoas: pessoas.where((p) => p.ativo).toList(),
        anoInicial: _ano,
      ),
    );
  }

  Future<void> _direitos(List<Colaborador> pessoas) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _DireitosDialog(pessoas: pessoas, ano: _ano),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(currentPapelProvider).canEditConfig;
    final uid = ref.watch(feriasRepositoryProvider).utilizadorId;
    final empresa = ref.watch(currentEmpresaProvider).valueOrNull?.nome ?? '';
    final direitos = ref.watch(feriasDireitosProvider(_ano)).valueOrNull;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return AsyncValueView<List<Ausencia>>(
      value: ref.watch(feriasAnoProvider(_ano)),
      onRetry: () => ref.invalidate(feriasAnoProvider),
      data: (todasBrutas) {
        final ocultos = ref.watch(ocultosProvider);
        final todas = [
          for (final a in todasBrutas)
            if (!ocultos.contains(a.id)) a,
        ];
        final minhas = [
          for (final a in todas)
            if (a.pessoa == 'u:$uid') a,
        ];
        final direito = direitos?['u:$uid'] ?? direitoFeriasPadrao;
        final saldo = calcularSaldo(
          direito: direito,
          ausencias: minhas,
          ano: _ano,
        );
        final pendentes = [
          for (final a in todas)
            if (a.estado == EstadoAusencia.pedido) a,
        ];
        final pessoas = <String, String>{}; // chave → nome
        for (final a in todas) {
          if (a.conta) pessoas[a.pessoa] = a.nome;
        }
        final nomesOrdenados = pessoas.entries.toList()
          ..sort(
            (a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()),
          );

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Ano anterior',
                  onPressed: () => setState(() => _ano--),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '$_ano',
                    textAlign: TextAlign.center,
                    style: tt.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Ano seguinte',
                  onPressed: () => setState(() => _ano++),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('As minhas férias em $_ano', style: tt.titleSmall),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _Numero('Direito', '${saldo.direito}'),
                        _Numero('Gozados', '${saldo.gozados}'),
                        _Numero('Pedidos', '${saldo.pedidos}'),
                        _Numero(
                          'Restam',
                          '${saldo.restam}',
                          cor: saldo.restam < 0 ? cs.error : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dias úteis: segunda a sexta, sem feriados nacionais.',
                      style: tt.bodySmall?.copyWith(color: cs.outline),
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () => _pedir(todas),
                      child: Text(
                        admin ? 'Registar férias / ausência' : 'Pedir férias',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (admin && pendentes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Por aprovar (${pendentes.length})', style: tt.titleSmall),
              for (final a in pendentes)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${a.nome} · ${a.tipo.label}',
                          style: tt.titleSmall,
                        ),
                        Text(
                          '${periodoTexto(a)} · ${a.diasUteis} dia(s) útil(eis)'
                          '${a.notas.isEmpty ? '' : '\n${a.notas}'}',
                          style: tt.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: () =>
                                    _decidir(a, EstadoAusencia.aprovado),
                                child: const Text('Aprovar'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    _decidir(a, EstadoAusencia.recusado),
                                child: const Text('Recusar'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton(
                  tooltip: 'Mês anterior',
                  onPressed: () =>
                      setState(() => _mes = _mes == 1 ? 12 : _mes - 1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${_meses[_mes - 1]} $_ano',
                    textAlign: TextAlign.center,
                    style: tt.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Mês seguinte',
                  onPressed: () =>
                      setState(() => _mes = _mes == 12 ? 1 : _mes + 1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            if (nomesOrdenados.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Ainda não há férias registadas neste ano.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              _MapaMes(
                ano: _ano,
                mes: _mes,
                pessoas: nomesOrdenados,
                ausencias: todas,
              ),
            if (nomesOrdenados.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                children: [
                  for (final (cor, texto) in [
                    (Colors.green, 'Férias'),
                    (Colors.green.withValues(alpha: 0.35), 'Por aprovar'),
                    (Colors.orange, 'Baixa'),
                    (cs.error, 'Falta'),
                  ])
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.square_rounded, size: 14, color: cor),
                        const SizedBox(width: 4),
                        Text(texto, style: tt.bodySmall),
                      ],
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            if (todas.isNotEmpty)
              Text('Marcações de $_ano', style: tt.titleSmall),
            for (final a in todas.where((a) => a.conta || admin))
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(Icons.square_rounded, color: _corDe(a, cs)),
                title: Text('${a.nome} · ${periodoTexto(a)}'),
                subtitle: Text(
                  '${a.tipo.label} · ${a.diasUteis} dia(s) útil(eis) · ${a.estado.label}'
                  '${a.notas.isEmpty ? '' : ' · ${a.notas}'}',
                ),
                trailing:
                    (admin ||
                        (a.pessoa == 'u:$uid' &&
                            a.estado == EstadoAusencia.pedido))
                    ? IconButton(
                        tooltip: 'Apagar',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _apagar(a),
                      )
                    : null,
              ),
            if (admin) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final pessoas = await ref.read(
                        todosColaboradoresProvider.future,
                      );
                      if (!mounted) return;
                      await _direitos(pessoas.where((p) => p.ativo).toList());
                    },
                    icon: const Icon(Icons.rule),
                    label: const Text('Direito a férias'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => abrirImpressao(
                      'Mapa de férias $_ano',
                      mapaFeriasHtml(
                        ano: _ano,
                        empresa: empresa,
                        ausencias: todas,
                      ),
                      estiloExtra: mapaFeriasEstilo,
                    ),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Imprimir o mapa'),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Numero extends StatelessWidget {
  const _Numero(this.rotulo, this.valor, {this.cor});

  final String rotulo;
  final String valor;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          Text(
            valor,
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: cor,
            ),
          ),
          Text(rotulo, style: tt.bodySmall),
        ],
      ),
    );
  }
}

/// A grelha do mês: uma linha por pessoa e uma coluna por dia (rola na horizontal).
class _MapaMes extends StatelessWidget {
  const _MapaMes({
    required this.ano,
    required this.mes,
    required this.pessoas,
    required this.ausencias,
  });

  final int ano;
  final int mes;
  final List<MapEntry<String, String>> pessoas;
  final List<Ausencia> ausencias;

  static const _largura = 26.0;
  static const _altura = 30.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final nDias = DateTime(ano, mes + 1, 0).day;
    final feriados = feriadosNacionais(ano);
    final hoje = DateTime.now();
    Ausencia? deUm(String pessoa, DateTime dia) {
      for (final a in ausencias) {
        if (a.pessoa == pessoa && a.conta && a.cobre(dia)) return a;
      }
      return null;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 86,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: _altura),
              for (final p in pessoas)
                SizedBox(
                  height: _altura,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      p.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              children: [
                Row(
                  children: [
                    for (var d = 1; d <= nDias; d++)
                      SizedBox(
                        width: _largura,
                        height: _altura,
                        child: Center(
                          child: Text(
                            '$d',
                            style: tt.labelSmall?.copyWith(
                              fontWeight:
                                  hoje.year == ano &&
                                      hoje.month == mes &&
                                      hoje.day == d
                                  ? FontWeight.bold
                                  : null,
                              color: DateTime(ano, mes, d).weekday >= 6
                                  ? cs.outline
                                  : null,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                for (final p in pessoas)
                  Row(
                    children: [
                      for (var d = 1; d <= nDias; d++)
                        Builder(
                          builder: (_) {
                            final dia = DateTime(ano, mes, d);
                            final a = deUm(p.key, dia);
                            final folga =
                                dia.weekday >= 6 || feriados.contains(dia);
                            return Container(
                              width: _largura,
                              height: _altura,
                              margin: const EdgeInsets.all(0.5),
                              decoration: BoxDecoration(
                                color: a != null
                                    ? _corDe(a, cs)
                                    : (folga
                                          ? cs.surfaceContainerHighest
                                          : cs.surfaceContainerLow),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Pedir férias (ou, para a administração, registar qualquer ausência).
class _PedirDialog extends ConsumerStatefulWidget {
  const _PedirDialog({
    required this.existentes,
    required this.pessoas,
    required this.anoInicial,
  });

  final List<Ausencia> existentes;
  final List<Colaborador> pessoas;
  final int anoInicial;

  @override
  ConsumerState<_PedirDialog> createState() => _PedirDialogState();
}

class _PedirDialogState extends ConsumerState<_PedirDialog> {
  TipoAusencia _tipo = TipoAusencia.ferias;
  Colaborador? _pessoa; // só a administração escolhe
  DateTimeRange? _intervalo;
  bool _aprovarJa = true;
  final _notas = TextEditingController();
  bool _ocupado = false;
  String? _erro;

  bool get _admin => ref.read(currentPapelProvider).canEditConfig;

  @override
  void dispose() {
    _notas.dispose();
    super.dispose();
  }

  Future<void> _escolher() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(widget.anoInicial - 1),
      lastDate: DateTime(widget.anoInicial + 2, 12, 31),
      initialDateRange: _intervalo,
    );
    if (r != null) setState(() => _intervalo = r);
  }

  Future<void> _guardar() async {
    final i = _intervalo;
    if (i == null) return;
    final repo = ref.read(feriasRepositoryProvider);
    final uid = repo.utilizadorId;
    final String pessoa;
    final String nome;
    final String userId;
    if (_admin && _pessoa != null) {
      pessoa = chavePessoa(_pessoa!);
      nome = _pessoa!.nome;
      userId = _pessoa!.userId;
    } else {
      pessoa = 'u:$uid';
      nome = ref.read(currentUserNameProvider) ?? '';
      userId = uid ?? '';
    }
    final choca = ausenciaSobreposta(
      widget.existentes,
      pessoa: pessoa,
      de: i.start,
      ate: i.end,
    );
    if (choca != null) {
      setState(
        () => _erro =
            'Já há ${choca.tipo.label.toLowerCase()} de ${choca.nome} em '
            '${periodoTexto(choca)} (${choca.estado.label.toLowerCase()}).',
      );
      return;
    }
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      await repo.criar(
        pessoa: pessoa,
        nome: nome,
        userId: userId,
        tipo: _tipo,
        de: i.start,
        ate: i.end,
        estado: _admin && _aprovarJa
            ? EstadoAusencia.aprovado
            : EstadoAusencia.pedido,
        notas: _notas.text,
      );
      _atualizar(ref);
      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _ocupado = false;
          _erro = mensagemAmigavel(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = _intervalo;
    final dias = i == null ? 0 : diasUteisEntre(i.start, i.end);
    String d(DateTime x) => '${x.day}/${x.month}/${x.year}';
    return AlertDialog(
      title: Text(_admin ? 'Registar ausência' : 'Pedir férias'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_admin)
              DropdownButtonFormField<Colaborador>(
                initialValue: _pessoa,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Pessoa',
                  helperText: 'Vazio = eu',
                ),
                items: [
                  for (final p in widget.pessoas)
                    DropdownMenuItem(value: p, child: Text(p.nome)),
                ],
                onChanged: (v) => setState(() => _pessoa = v),
              ),
            if (_admin) const SizedBox(height: 12),
            DropdownButtonFormField<TipoAusencia>(
              initialValue: _tipo,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: [
                for (final t in TipoAusencia.values)
                  DropdownMenuItem(value: t, child: Text(t.label)),
              ],
              onChanged: (v) => setState(() => _tipo = v ?? _tipo),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _escolher,
              icon: const Icon(Icons.date_range),
              label: Text(
                i == null ? 'Escolher as datas' : '${d(i.start)} a ${d(i.end)}',
              ),
            ),
            if (i != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '$dias dia(s) útil(eis) (segunda a sexta, sem feriados).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _notas,
              maxLength: 300,
              decoration: const InputDecoration(labelText: 'Notas (opcional)'),
            ),
            if (_admin)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Aprovar já'),
                value: _aprovarJa,
                onChanged: (v) => setState(() => _aprovarJa = v),
              ),
            if (_erro != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _erro!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
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
          onPressed: _ocupado || i == null ? null : _guardar,
          child: Text(_admin && _aprovarJa ? 'Guardar' : 'Enviar pedido'),
        ),
      ],
    );
  }
}

/// O direito a férias (dias úteis) de cada pessoa neste ano.
class _DireitosDialog extends ConsumerStatefulWidget {
  const _DireitosDialog({required this.pessoas, required this.ano});

  final List<Colaborador> pessoas;
  final int ano;

  @override
  ConsumerState<_DireitosDialog> createState() => _DireitosDialogState();
}

class _DireitosDialogState extends ConsumerState<_DireitosDialog> {
  final _ctrl = <String, TextEditingController>{};
  bool _ocupado = false;
  bool _iniciado = false;

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar(Map<String, int> atuais) async {
    setState(() => _ocupado = true);
    try {
      final repo = ref.read(feriasRepositoryProvider);
      for (final p in widget.pessoas) {
        final k = chavePessoa(p);
        final v = int.tryParse(_ctrl[k]?.text.trim() ?? '');
        if (v == null || v < 0 || v > 100) continue;
        if ((atuais[k] ?? direitoFeriasPadrao) == v) continue; // sem mudança
        await repo.definirDireito(
          pessoa: k,
          userId: p.userId,
          ano: widget.ano,
          dias: v,
        );
      }
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
    final atuais =
        ref.watch(feriasDireitosProvider(widget.ano)).valueOrNull ?? const {};
    if (!_iniciado) {
      _iniciado = true;
      for (final p in widget.pessoas) {
        final k = chavePessoa(p);
        _ctrl[k] = TextEditingController(
          text: '${atuais[k] ?? direitoFeriasPadrao}',
        );
      }
    }
    return AlertDialog(
      title: Text('Direito a férias ${widget.ano}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Dias úteis de cada pessoa. A lei dá 22 por ano; no ano de entrada '
              'e em outros casos pode ser menos.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final p in widget.pessoas)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: _ctrl[chavePessoa(p)],
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: p.nome,
                    suffixText: 'dias',
                    isDense: true,
                  ),
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
          onPressed: _ocupado ? null : () => _guardar(atuais),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
