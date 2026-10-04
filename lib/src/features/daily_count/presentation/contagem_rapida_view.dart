import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/prefs_locais.dart';
import '../../../core/widgets/quantidade_stepper.dart';
import '../../invoices/domain/invoice_erros.dart';
import '../../tech_sheets/domain/tech_sheet.dart';
import '../application/contagem_providers.dart';
import '../domain/contagem_dia.dart';
import '../domain/fornada.dart';
import '../domain/local.dart';
import '../domain/movimento_produto.dart';
import 'enviar_sheet.dart';
import 'forno_widgets.dart';

const _chaveModo = 'contagem_modo';

String _n(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

enum _Passo { abertura, dia, fecho }

/// Passo a mostrar quando o ecrã é reconstruído (ex.: ao ir a "ontem").
_Passo? _proximoPasso;

/// O modo de trabalho da contagem rápida (escolhe-se por aparelho):
/// 1 = abertura + vendas (do Vendus) + fecho; 2 = o mesmo e ainda os assados
/// de cada fornada, com cronómetro.
enum ModoContagem { vendas, fornadas }

/// Contagem do dia com botões grandes (menos / número / mais) por sabor:
/// abrir a loja, registar o dia (fornadas, perdas, consumo próprio) e fechar.
class ContagemRapidaView extends ConsumerStatefulWidget {
  const ContagemRapidaView({
    super.key,
    required this.local,
    required this.locais,
    required this.dia,
    required this.fichas,
    required this.contagem,
    required this.onMudarDia,
  });

  final Local local;
  final List<Local> locais;
  final DateTime dia;
  final List<FichaTecnica> fichas;
  final ContagemDoDia contagem;

  /// Muda o dia mostrado (−1 = ontem).
  final void Function(int delta) onMudarDia;

  @override
  ConsumerState<ContagemRapidaView> createState() => _ContagemRapidaViewState();
}

class _ContagemRapidaViewState extends ConsumerState<ContagemRapidaView> {
  late ModoContagem _modo = lerPref(_chaveModo) == 'fornadas'
      ? ModoContagem.fornadas
      : ModoContagem.vendas;
  late _Passo _passo;

  // o que a pessoa já mexeu em cada passo (por ficha)
  final _abertura = <String, double>{};
  final _fecho = <String, double>{};
  final _forno = <String, double>{};
  final _perdas = <String, double>{};
  MotivoDesperdicio _motivo = MotivoDesperdicio.queimado;

  bool _aGuardar = false;
  Timer? _tick;
  int _segundos = 0;
  final _avisos = AvisosForno();

  _Passo _passoInicial() {
    final linhas = widget.contagem.linhas;
    final aberta = linhas.any((l) => l.aberturaContada);
    if (!aberta) return _Passo.abertura;
    return _Passo.dia;
  }

  @override
  void initState() {
    super.initState();
    _passo = _proximoPasso ?? _passoInicial();
    _proximoPasso = null;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _segundos++;
      // vai buscar as fornadas de vez em quando (outros aparelhos também as criam)
      if (_segundos % 30 == 0) {
        ref.invalidate(fornadasNoFornoProvider(widget.local.id));
      }
      _verificarAvisos();
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant ContagemRapidaView old) {
    super.didUpdateWidget(old);
    if (old.local.id != widget.local.id || old.dia != widget.dia) {
      _abertura.clear();
      _fecho.clear();
      _forno.clear();
      _perdas.clear();
      _passo = _proximoPasso ?? _passoInicial();
      _proximoPasso = null;
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  bool get _ehHoje {
    final n = DateTime.now();
    return widget.dia == DateTime(n.year, n.month, n.day);
  }

  void _verificarAvisos() {
    final fornadas =
        ref.read(fornadasNoFornoProvider(widget.local.id)).valueOrNull ??
        const <Fornada>[];
    _avisos.verificar(fornadas, DateTime.now());
  }

  void _msg(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _correr(Future<void> Function() acao, String ok) async {
    setState(() => _aGuardar = true);
    try {
      await acao();
      _msg(ok);
    } on Object catch (e) {
      _msg(mensagemAmigavel(e));
    } finally {
      if (mounted) setState(() => _aGuardar = false);
    }
  }

  Map<String, LinhaContagem> get _linhas => {
    for (final l in widget.contagem.linhas) l.fichaId: l,
  };

  // --- ações -----------------------------------------------------------------

  Future<void> _guardarAbertura() async {
    final valores = <String, double>{};
    for (final f in widget.fichas) {
      final l = _linhas[f.id];
      final v = _abertura[f.id] ?? l?.abertura ?? 0;
      final mexeu = _abertura.containsKey(f.id);
      if (v > 0 || mexeu || (l?.aberturaContada ?? false)) valores[f.id] = v;
    }
    if (valores.isEmpty) {
      _msg('Não há nada para guardar: todos os sabores estão a zero.');
      return;
    }
    await _correr(() async {
      await ref
          .read(contagemActionsProvider)
          .guardarContagens(
            tipo: TipoMovimento.contagemAbertura,
            data: widget.dia,
            localId: widget.local.id,
            porFicha: valores,
          );
      if (mounted) setState(() => _passo = _Passo.dia);
    }, 'Abertura guardada.');
  }

  Future<void> _guardarFecho({bool comoEsperado = false}) async {
    final valores = <String, double>{};
    for (final f in widget.fichas) {
      final l = _linhas[f.id];
      final esperado = (l?.esperado ?? 0) < 0 ? 0.0 : (l?.esperado ?? 0);
      final v = comoEsperado
          ? esperado
          : (_fecho[f.id] ?? l?.fecho ?? esperado);
      if (v > 0 || _fecho.containsKey(f.id) || l?.fecho != null) {
        valores[f.id] = v;
      }
    }
    if (valores.isEmpty) {
      _msg('Não há nada para guardar: todos os sabores estão a zero.');
      return;
    }
    await _correr(() async {
      await ref
          .read(contagemActionsProvider)
          .guardarContagens(
            tipo: TipoMovimento.contagemFecho,
            data: widget.dia,
            localId: widget.local.id,
            porFicha: valores,
          );
      if (mounted) setState(_fecho.clear);
    }, 'Fecho guardado.');
  }

  Future<void> _registarPerdas() async {
    final lista = {
      for (final e in _perdas.entries)
        if (e.value > 0) e.key: e.value,
    };
    if (lista.isEmpty) {
      _msg('Põe a quantidade em algum sabor.');
      return;
    }
    await _correr(() async {
      final acoes = ref.read(contagemActionsProvider);
      for (final e in lista.entries) {
        await acoes.adicionar(
          data: widget.dia,
          localId: widget.local.id,
          fichaId: e.key,
          tipo: TipoMovimento.desperdicio,
          quantidade: e.value,
          motivo: _motivo,
        );
      }
      if (mounted) setState(_perdas.clear);
    }, '${_motivo.label}: registado.');
  }

  Future<void> _assar() async {
    final lista = {
      for (final e in _forno.entries)
        if (e.value > 0) e.key: e.value,
    };
    if (lista.isEmpty) {
      _msg('Põe a quantidade dos sabores que vão ao forno.');
      return;
    }
    final tempos = {for (final f in widget.fichas) f.id: f.tempoAssaduraMin};
    final nomes = {for (final f in widget.fichas) f.id: f.nome};
    // sabores sem tempo na ficha: pergunta os minutos (uma vez para todos)
    final semTempo = [
      for (final k in lista.keys)
        if ((tempos[k] ?? 0) <= 0) nomes[k] ?? 'Produto',
    ];
    var padrao = 0;
    if (semTempo.isNotEmpty) {
      final m = await showDialog<int>(
        context: context,
        builder: (_) => _MinutosDialog(sabores: semTempo),
      );
      if (m == null) return;
      padrao = m;
    }
    final itens = [
      for (final e in lista.entries)
        ItemFornada(
          fichaId: e.key,
          quantidade: e.value,
          duracaoMin: (tempos[e.key] ?? 0) > 0 ? tempos[e.key]! : padrao,
        ),
    ];
    final minutos = (itens.map((i) => i.duracaoMin).toSet().toList()..sort());
    final resumo = minutos.length == 1
        ? 'Cronómetro de ${minutos.first} min a andar.'
        : 'Cronómetros de ${minutos.join(', ')} min a andar.';
    await _correr(() async {
      await ref
          .read(contagemActionsProvider)
          .assar(data: widget.dia, localId: widget.local.id, itens: itens);
      if (mounted) setState(_forno.clear);
    }, 'No forno! $resumo');
  }

  Future<void> _tirarItem(Fornada f, ItemFornada i) => _correr(
    () => ref.read(contagemActionsProvider).tirarItem(f, i.fichaId),
    'Tirado do forno.',
  );

  Future<void> _tirar(Fornada f) => _correr(
    () => ref.read(contagemActionsProvider).tirarDoForno(f.id),
    'Tirada do forno.',
  );

  Future<void> _cancelar(Fornada f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar fornada'),
        content: const Text(
          'Foi engano? Cancela a fornada e apaga os assados que ela registou.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar fornada'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _correr(
      () => ref.read(contagemActionsProvider).cancelarFornada(f),
      'Fornada cancelada.',
    );
  }

  void _escolherModo(ModoContagem m) {
    guardarPref(_chaveModo, m == ModoContagem.fornadas ? 'fornadas' : 'vendas');
    setState(() => _modo = m);
  }

  // --- interface ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ChoiceChip(
              label: const Text('Opção 1 · vendas'),
              selected: _modo == ModoContagem.vendas,
              onSelected: (_) => _escolherModo(ModoContagem.vendas),
            ),
            ChoiceChip(
              label: const Text('Opção 2 · fornadas'),
              selected: _modo == ModoContagem.fornadas,
              onSelected: (_) => _escolherModo(ModoContagem.fornadas),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            _modo == ModoContagem.vendas
                ? 'Contas o que há ao abrir e ao fechar; as vendas vêm do Vendus.'
                : 'Como a opção 1, mais os cookies que vão ao forno (com cronómetro).',
            style: tt.bodySmall,
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<_Passo>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: _Passo.abertura,
                label: Text('Abrir'),
                icon: Icon(Icons.wb_sunny_outlined),
              ),
              ButtonSegment(
                value: _Passo.dia,
                label: Text('Dia'),
                icon: Icon(Icons.local_fire_department_outlined),
              ),
              ButtonSegment(
                value: _Passo.fecho,
                label: Text('Fechar'),
                icon: Icon(Icons.nights_stay_outlined),
              ),
            ],
            selected: {_passo},
            onSelectionChanged: (s) => setState(() => _passo = s.first),
          ),
        ),
        const SizedBox(height: 8),
        switch (_passo) {
          _Passo.abertura => _abrir(context),
          _Passo.dia => _doDia(context),
          _Passo.fecho => _fechar(context),
        },
      ],
    );
  }

  Widget _linha(
    FichaTecnica f, {
    required double valor,
    required ValueChanged<double> onChanged,
    String? sub,
    Color? corSub,
    bool destaque = false,
  }) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.nome,
                  style: tt.bodyLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (sub != null)
                  Text(sub, style: tt.bodySmall?.copyWith(color: corSub)),
              ],
            ),
          ),
          QuantidadeStepper(
            valor: valor,
            onChanged: onChanged,
            destaque: destaque,
          ),
        ],
      ),
    );
  }

  // --- passo: abrir ----------------------------------------------------------

  Widget _abrir(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final linhas = _linhas;
    final estimadas = widget.contagem.linhas.where(
      (l) =>
          !l.aberturaContada &&
          l.fechoAnterior != null &&
          l.fechoAnteriorEstimado,
    );
    final temFechoOntem = widget.contagem.linhas.any(
      (l) => l.fechoAnterior != null && !l.fechoAnteriorEstimado,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('O que tens ao abrir?', style: tt.titleMedium),
        Text(
          'Toca no − e no + ou escreve o número. Os sabores vêm preenchidos com '
          'o que ficou de ontem.',
          style: tt.bodySmall,
        ),
        if (estimadas.isNotEmpty)
          Card(
            color: cs.tertiaryContainer,
            margin: const EdgeInsets.only(top: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    temFechoOntem
                        ? 'Alguns sabores não foram contados ao fechar.'
                        : 'Ontem não foi contado o fecho.',
                    style: tt.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'A app calculou o que devia ter ficado (assados − vendas − '
                    'perdas). Confirma ou corrige o que tens agora. Se houve '
                    'perdas ou consumo próprio ontem, regista-os.',
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: _registarOntem,
                    icon: const Icon(Icons.history),
                    label: const Text('Registar perdas de ontem'),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 6),
        for (final f in widget.fichas)
          _linha(
            f,
            valor: _abertura[f.id] ?? linhas[f.id]?.abertura ?? 0,
            destaque: _abertura.containsKey(f.id),
            sub: _subAbertura(linhas[f.id]),
            onChanged: (v) => setState(() => _abertura[f.id] = v),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _aGuardar ? null : _guardarAbertura,
          icon: const Icon(Icons.check),
          label: Text(_aGuardar ? 'A guardar…' : 'Guardar abertura'),
        ),
      ],
    );
  }

  String? _subAbertura(LinhaContagem? l) {
    if (l == null || l.fechoAnterior == null) return null;
    return l.fechoAnteriorEstimado
        ? 'ontem devia ter ficado ${_n(l.fechoAnterior!)}'
        : 'ontem ficou ${_n(l.fechoAnterior!)}';
  }

  void _registarOntem() {
    // vai a ontem, no passo "Dia", para registar o que se perdeu
    _proximoPasso = _Passo.dia;
    setState(() => _passo = _Passo.dia);
    widget.onMudarDia(-1);
  }

  // --- passo: dia -------------------------------------------------------------

  Widget _doDia(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final vendidos = [
      for (final l in widget.contagem.linhas)
        if (l.vendido > 0) l,
    ];
    final nomes = {for (final f in widget.fichas) f.id: f.nome};
    final fornadas =
        ref.watch(fornadasNoFornoProvider(widget.local.id)).valueOrNull ??
        const <Fornada>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.point_of_sale_outlined, size: 18),
                    const SizedBox(width: 6),
                    Text('Vendidos hoje (Vendus)', style: tt.titleSmall),
                  ],
                ),
                const SizedBox(height: 6),
                if (vendidos.isEmpty)
                  Text('Ainda sem vendas neste dia.', style: tt.bodySmall)
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final l in vendidos)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            '${nomes[l.fichaId] ?? 'Produto'}  ${_n(l.vendido)}',
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        if (_modo == ModoContagem.fornadas)
          ..._forno_(context, fornadas, cs, tt),
        const SizedBox(height: 4),
        Card(
          child: ExpansionTile(
            initiallyExpanded: false,
            leading: const Icon(Icons.delete_outline),
            title: const Text('Perdas e consumo próprio'),
            subtitle: const Text('Queimados, quebras, colaboradores…'),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final m in MotivoDesperdicio.values)
                    ChoiceChip(
                      label: Text(m.label),
                      selected: _motivo == m,
                      onSelected: (_) => setState(() => _motivo = m),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              for (final f in widget.fichas)
                _linha(
                  f,
                  valor: _perdas[f.id] ?? 0,
                  destaque: (_perdas[f.id] ?? 0) > 0,
                  onChanged: (v) => setState(() => _perdas[f.id] = v),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _aGuardar ? null : _registarPerdas,
                icon: const Icon(Icons.check),
                label: Text('Registar: ${_motivo.label.toLowerCase()}'),
              ),
            ],
          ),
        ),
        if (widget.locais.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: () => showEnviarSheet(
                context,
                local: widget.local,
                locais: widget.locais,
                dia: widget.dia,
              ),
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Enviar / devolver para outro local'),
            ),
          ),
      ],
    );
  }

  // ignore: non_constant_identifier_names
  List<Widget> _forno_(
    BuildContext context,
    List<Fornada> fornadas,
    ColorScheme cs,
    TextTheme tt,
  ) {
    final nomes = {for (final f in widget.fichas) f.id: f.nome};
    final agora = DateTime.now();
    return [
      for (final f in fornadas)
        CartaoFornada(
          fornada: f,
          nomes: nomes,
          agora: agora,
          ocupado: _aGuardar,
          onTirarItem: (i) => _tirarItem(f, i),
          onTirarTudo: () => _tirar(f),
          onCancelar: () => _cancelar(f),
        ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_fire_department_outlined),
                  const SizedBox(width: 6),
                  Text('Pôr no forno', style: tt.titleMedium),
                ],
              ),
              if (!_ehHoje)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'O cronómetro só arranca no dia de hoje.',
                    style: tt.bodySmall,
                  ),
                ),
              const SizedBox(height: 6),
              for (final f in widget.fichas)
                _linha(
                  f,
                  valor: _forno[f.id] ?? 0,
                  destaque: (_forno[f.id] ?? 0) > 0,
                  sub: f.tempoAssaduraMin > 0
                      ? '${f.tempoAssaduraMin} min'
                      : 'sem tempo na ficha',
                  corSub: f.tempoAssaduraMin > 0 ? null : cs.outline,
                  onChanged: (v) => setState(() => _forno[f.id] = v),
                ),
              const SizedBox(height: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                onPressed: _aGuardar || !_ehHoje ? null : _assar,
                icon: const Icon(Icons.local_fire_department),
                label: Text(_aGuardar ? 'A guardar…' : 'ASSAR'),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  // --- passo: fechar -----------------------------------------------------------

  Widget _fechar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final linhas = _linhas;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('O que sobrou ao fechar?', style: tt.titleMedium),
        Text(
          'Conta o que ficou. O número pequeno é o que devia haver pelas contas '
          '(abertura + assados − vendas − perdas). Se não contares hoje, amanhã '
          'a abertura vem com o que devia ter ficado.',
          style: tt.bodySmall,
        ),
        const SizedBox(height: 6),
        for (final f in widget.fichas)
          Builder(
            builder: (_) {
              final l = linhas[f.id];
              final esperado = (l?.esperado ?? 0) < 0
                  ? 0.0
                  : (l?.esperado ?? 0);
              final valor = _fecho[f.id] ?? l?.fecho ?? esperado;
              final dif = valor - esperado;
              return _linha(
                f,
                valor: valor,
                destaque: _fecho.containsKey(f.id) || l?.fecho != null,
                sub: dif == 0
                    ? 'devia haver ${_n(esperado)}'
                    : 'devia haver ${_n(esperado)} · '
                          '${dif < 0 ? 'faltam ${_n(-dif)}' : 'sobram ${_n(dif)}'}',
                corSub: dif < 0
                    ? cs.error
                    : dif > 0
                    ? cs.tertiary
                    : null,
                onChanged: (v) => setState(() => _fecho[f.id] = v),
              );
            },
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _aGuardar ? null : _guardarFecho,
          icon: const Icon(Icons.check),
          label: Text(_aGuardar ? 'A guardar…' : 'Guardar fecho'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _aGuardar ? null : () => _guardarFecho(comoEsperado: true),
          icon: const Icon(Icons.done_all),
          label: const Text('Está tudo como devia haver'),
        ),
      ],
    );
  }
}

class _MinutosDialog extends StatefulWidget {
  const _MinutosDialog({required this.sabores});

  /// Os sabores que não têm o tempo de assadura na ficha.
  final List<String> sabores;

  @override
  State<_MinutosDialog> createState() => _MinutosDialogState();
}

class _MinutosDialogState extends State<_MinutosDialog> {
  final _ctrl = TextEditingController(text: '12');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Quantos minutos no forno?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Minutos'),
          ),
          const SizedBox(height: 8),
          Text(
            'Sem tempo na ficha: ${widget.sabores.join(', ')}. Dica: define o '
            '"Tempo de assadura" na ficha técnica e a app usa-o sozinha.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final m = int.tryParse(_ctrl.text.trim());
            if (m != null && m >= 1 && m <= 600) Navigator.pop(context, m);
          },
          child: const Text('Assar'),
        ),
      ],
    );
  }
}
