import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/help/help_content.dart';
import '../../../core/storage/prefs_locais.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/help_actions.dart';
import '../../tech_sheets/application/tech_sheets_providers.dart';
import '../../tech_sheets/domain/tech_sheet.dart';
import '../application/contagem_providers.dart';
import '../domain/contagem_dia.dart';
import '../domain/local.dart';
import '../domain/movimento_produto.dart';
import 'contagem_rapida_sheet.dart';
import 'contagem_rapida_view.dart';
import 'locais_sheet.dart';
import 'movimento_sheet.dart';

/// O tema da app põe os botões a toda a largura; num `Wrap` tem de ser
/// compacto para ficarem lado a lado.
final _estiloCompacto = FilledButton.styleFrom(minimumSize: const Size(0, 44));
final _estiloCompactoContorno = OutlinedButton.styleFrom(
  minimumSize: const Size(0, 44),
);

String _n(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';
String _sinal(double v) => v > 0 ? '+${_n(v)}' : _n(v);

String _dmy(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

const _diasSemana = [
  'segunda',
  'terça',
  'quarta',
  'quinta',
  'sexta',
  'sábado',
  'domingo',
];

/// Contagem diária dos cookies por local: assados, enviados/devolvidos,
/// vendidos (das vendas), desperdício e a contagem de abertura/fecho.
class ContagemScreen extends ConsumerStatefulWidget {
  const ContagemScreen({super.key});

  @override
  ConsumerState<ContagemScreen> createState() => _ContagemScreenState();
}

class _ContagemScreenState extends ConsumerState<ContagemScreen> {
  late DateTime _dia = () {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }();
  String? _localId;
  bool _soComMovimento = true;

  /// `true` = botões grandes (−/+); `false` = o detalhe com todas as contas.
  late bool _rapido = lerPref('contagem_vista') != 'detalhe';

  static DateTime get _hoje {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool get _podeEditar => ref.read(currentPapelProvider).canEditBusiness;

  void _mudarDia(int delta) {
    final novo = DateTime(_dia.year, _dia.month, _dia.day + delta);
    if (novo.isAfter(_hoje)) return;
    setState(() => _dia = novo);
  }

  Future<void> _escolherDia() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dia,
      firstDate: DateTime(2020),
      lastDate: _hoje,
    );
    if (d != null) setState(() => _dia = DateTime(d.year, d.month, d.day));
  }

  Future<void> _remover(MovimentoProduto m) async {
    final ok = await confirmDialog(
      context,
      titulo: 'Apagar registo',
      mensagem: 'Apagar este registo?',
      destrutivo: true,
      confirmar: 'Apagar',
    );
    if (!ok) return;
    await ref.read(contagemActionsProvider).remover(m.id);
  }

  @override
  Widget build(BuildContext context) {
    final locaisAsync = ref.watch(locaisProvider);
    final locais = locaisAsync.valueOrNull ?? const <Local>[];
    final local = locais.isEmpty
        ? null
        : locais.firstWhere(
            (l) => l.id == _localId,
            orElse: () => locais.first,
          );
    final fichas = ref.watch(fichasListProvider(false)).valueOrNull ?? const [];
    final nomes = {for (final f in fichas) f.id: f.nome};
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
        title: const Text('Contagem diária'),
        actions: [
          IconButton(
            tooltip: 'Desperdício e balanço por local',
            icon: const Icon(Icons.bar_chart_outlined),
            onPressed: () => context.push(Routes.contagemRelatorios),
          ),
          if (_podeEditar)
            IconButton(
              tooltip: 'Locais',
              icon: const Icon(Icons.place_outlined),
              onPressed: () => showLocaisSheet(context),
            ),
          const HelpActions(topic: HelpTopic.contagem),
        ],
      ),
      body: locaisAsync.isLoading && locais.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : local == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Ainda não há locais. Pede a quem pode editar para abrir '
                  'esta página (cria a Loja, Alvalade e as Plataformas).',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: [
                // --- local -------------------------------------------------
                if (locais.length > 1)
                  SizedBox(
                    height: 52,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      children: [
                        for (final l in locais)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(l.nome),
                              selected: l.id == local.id,
                              onSelected: (_) =>
                                  setState(() => _localId = l.id),
                            ),
                          ),
                      ],
                    ),
                  ),
                // --- dia ---------------------------------------------------
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Dia anterior',
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => _mudarDia(-1),
                      ),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: _escolherDia,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              children: [
                                Text(
                                  _dia == _hoje
                                      ? 'Hoje'
                                      : _diasSemana[_dia.weekday - 1],
                                  style: tt.titleMedium,
                                ),
                                Text(
                                  _dmy(_dia),
                                  style: tt.bodyMedium?.copyWith(
                                    color: cs.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_dia != _hoje)
                        IconButton(
                          tooltip: 'Voltar a hoje',
                          icon: const Icon(Icons.today_outlined),
                          onPressed: () => setState(() => _dia = _hoje),
                        ),
                      IconButton(
                        tooltip: 'Dia seguinte',
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _dia == _hoje ? null : () => _mudarDia(1),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: true,
                          label: Text('Rápido'),
                          icon: Icon(Icons.touch_app_outlined),
                        ),
                        ButtonSegment(
                          value: false,
                          label: Text('Detalhe'),
                          icon: Icon(Icons.list_alt_outlined),
                        ),
                      ],
                      selected: {_rapido},
                      onSelectionChanged: (s) {
                        guardarPref(
                          'contagem_vista',
                          s.first ? 'rapido' : 'detalhe',
                        );
                        setState(() => _rapido = s.first);
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final async = ref.watch(
                        contagemDoDiaProvider((localId: local.id, dia: _dia)),
                      );
                      // ao recarregar (depois de guardar) mantém o que se vê:
                      // só mostra o círculo quando ainda não há nada
                      final c = async.valueOrNull;
                      if (c == null) {
                        if (async.hasError) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${async.error}', textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                OutlinedButton(
                                  onPressed: () =>
                                      ref.invalidate(contagemDoDiaProvider),
                                  child: const Text('Tentar de novo'),
                                ),
                              ],
                            ),
                          );
                        }
                        return const Center(child: CircularProgressIndicator());
                      }
                      return _rapido && _podeEditar
                          ? ContagemRapidaView(
                              key: ValueKey('rapida-${local.id}'),
                              local: local,
                              locais: locais,
                              dia: _dia,
                              fichas: fichas,
                              contagem: c,
                              onMudarDia: _mudarDia,
                            )
                          : _corpo(context, local, locais, fichas, nomes, c);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _corpo(
    BuildContext context,
    Local local,
    List<Local> locais,
    List<FichaTecnica> fichas,
    Map<String, String> nomes,
    ContagemDoDia c,
  ) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final linhas = _soComMovimento
        ? [
            for (final l in c.linhas)
              if (l.temMovimento) l,
          ]
        : c.linhas;

    double total(double Function(LinhaContagem) f) =>
        c.linhas.fold<double>(0, (s, l) => s + f(l));
    final contadas = c.linhas.where((l) => l.fecho != null).toList();
    final difTotal = contadas.fold<double>(0, (s, l) => s + (l.diferenca ?? 0));

    void registar(TipoMovimento tipo, {String? fichaId}) => showMovimentoSheet(
      context,
      local: local,
      locais: locais,
      dia: _dia,
      tipo: tipo,
      fichaId: fichaId,
    );

    void contar(TipoMovimento tipo) => showContagemRapidaSheet(
      context,
      local: local,
      dia: _dia,
      tipo: tipo,
      fichas: fichas,
      linhas: c.linhas,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                _total('Assados', _n(total((l) => l.assados)), tt),
                _total('Vendidos', _n(total((l) => l.vendido)), tt),
                _total('Desperdício', _n(total((l) => l.desperdicio)), tt),
                if (total((l) => l.recebido) > 0)
                  _total('Recebidos', _n(total((l) => l.recebido)), tt),
                if (total((l) => l.enviado) > 0)
                  _total('Enviados', _n(total((l) => l.enviado)), tt),
                _total('Devia haver', _n(total((l) => l.esperado)), tt),
                if (contadas.isNotEmpty)
                  _total(
                    'Contado',
                    _n(contadas.fold<double>(0, (s, l) => s + l.fecho!)),
                    tt,
                  ),
                if (contadas.isNotEmpty)
                  _total(
                    'Diferença',
                    _sinal(difTotal),
                    tt,
                    cor: difTotal < 0
                        ? cs.error
                        : difTotal > 0
                        ? cs.tertiary
                        : null,
                  ),
              ],
            ),
          ),
        ),
        if (_podeEditar) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                style: _estiloCompacto,
                onPressed: () => registar(TipoMovimento.producao),
                icon: const Icon(Icons.local_fire_department_outlined),
                label: const Text('Assados'),
              ),
              if (locais.length > 1)
                FilledButton.tonalIcon(
                style: _estiloCompacto,
                  onPressed: () => registar(TipoMovimento.transferencia),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Enviar / devolver'),
                ),
              FilledButton.tonalIcon(
                style: _estiloCompacto,
                onPressed: () => registar(TipoMovimento.desperdicio),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Desperdício'),
              ),
              OutlinedButton.icon(
                style: _estiloCompactoContorno,
                onPressed: () => contar(TipoMovimento.contagemAbertura),
                icon: const Icon(Icons.wb_sunny_outlined),
                label: const Text('Contar abertura'),
              ),
              OutlinedButton.icon(
                style: _estiloCompactoContorno,
                onPressed: () => contar(TipoMovimento.contagemFecho),
                icon: const Icon(Icons.nights_stay_outlined),
                label: const Text('Contar fecho'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: _soComMovimento,
          onChanged: (v) => setState(() => _soComMovimento = v),
          title: const Text('Mostrar só os sabores com movimento'),
        ),
        if (linhas.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Sem registos neste dia. Usa "Assados", "Desperdício" ou '
              '"Contar" para começar.',
              textAlign: TextAlign.center,
              style: tt.bodyMedium,
            ),
          ),
        for (final l in linhas)
          _CartaoSabor(
            nome: nomes[l.fichaId] ?? 'Produto',
            linha: l,
            onTap: _podeEditar
                ? () => registar(TipoMovimento.producao, fichaId: l.fichaId)
                : null,
          ),
        if (c.registos.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Registos do dia', style: tt.titleSmall),
          for (final m in c.registos)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(_icone(m, local)),
              title: Text(
                '${_titulo(m, local, locais)} · ${nomes[m.fichaId] ?? 'Produto'}',
              ),
              subtitle: m.notas.isEmpty ? null : Text(m.notas),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _n(m.quantidade),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (_podeEditar)
                    IconButton(
                      tooltip: 'Apagar',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _remover(m),
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  IconData _icone(MovimentoProduto m, Local local) => switch (m.tipo) {
    TipoMovimento.producao => Icons.local_fire_department_outlined,
    TipoMovimento.transferencia =>
      m.localId == local.id ? Icons.north_east : Icons.south_west,
    TipoMovimento.desperdicio => Icons.delete_outline,
    TipoMovimento.contagemAbertura => Icons.wb_sunny_outlined,
    TipoMovimento.contagemFecho => Icons.nights_stay_outlined,
  };

  String _titulo(MovimentoProduto m, Local local, List<Local> locais) {
    String nomeLocal(String id) => locais
        .firstWhere(
          (l) => l.id == id,
          orElse: () => const Local(id: '', nome: '?'),
        )
        .nome;
    return switch (m.tipo) {
      TipoMovimento.producao => 'Assados',
      TipoMovimento.transferencia =>
        m.localId == local.id
            ? 'Enviados para ${nomeLocal(m.destinoId)}'
            : 'Recebidos de ${nomeLocal(m.localId)}',
      TipoMovimento.desperdicio =>
        'Desperdício${m.motivo == null ? '' : ' (${m.motivo!.label.toLowerCase()})'}',
      TipoMovimento.contagemAbertura => 'Contagem de abertura',
      TipoMovimento.contagemFecho => 'Contagem de fecho',
    };
  }

  Widget _total(String label, String valor, TextTheme tt, {Color? cor}) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: tt.bodySmall),
          Text(valor, style: tt.titleLarge?.copyWith(color: cor)),
        ],
      );
}

/// A conta do dia de um sabor.
class _CartaoSabor extends StatelessWidget {
  const _CartaoSabor({required this.nome, required this.linha, this.onTap});

  final String nome;
  final LinhaContagem linha;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = linha;
    final dif = l.diferenca;

    Widget kv(String k, String v, {Color? cor}) => Padding(
      padding: const EdgeInsets.only(right: 14, top: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$k ', style: tt.bodySmall),
            TextSpan(
              text: v,
              style: tt.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: cor,
              ),
            ),
          ],
        ),
      ),
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(nome, style: tt.titleSmall)),
                  if (dif != null)
                    Icon(
                      dif == 0
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      size: 18,
                      color: dif == 0
                          ? cs.primary
                          : dif < 0
                          ? cs.error
                          : cs.tertiary,
                    ),
                ],
              ),
              Wrap(
                children: [
                  kv('Abertura', _n(l.abertura)),
                  if (l.assados != 0) kv('Assados', _sinal(l.assados)),
                  if (l.recebido != 0) kv('Recebidos', _sinal(l.recebido)),
                  if (l.enviado != 0) kv('Enviados', _sinal(-l.enviado)),
                  if (l.vendido != 0) kv('Vendidos', _sinal(-l.vendido)),
                  if (l.desperdicio != 0)
                    kv('Desperdício', _sinal(-l.desperdicio)),
                ],
              ),
              Wrap(
                children: [
                  kv('Devia haver', _n(l.esperado)),
                  if (l.fecho != null) kv('Contado', _n(l.fecho!)),
                  if (dif != null && dif != 0)
                    kv(
                      dif < 0 ? 'Faltam' : 'Sobram',
                      _n(dif.abs()),
                      cor: dif < 0 ? cs.error : cs.tertiary,
                    ),
                  if (l.diferencaAbertura != null && l.diferencaAbertura != 0)
                    kv(
                      'De ontem para hoje',
                      _sinal(l.diferencaAbertura!),
                      cor: cs.error,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
