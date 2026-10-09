import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/help_actions.dart';
import '../application/haccp_providers.dart';
import '../domain/haccp.dart';
import 'haccp_controlo_dialog.dart';
import 'haccp_icones.dart';
import 'haccp_registo_sheet.dart';
import 'haccp_relatorio_acao.dart';
import '../../../app/theme/cores_estado.dart';

String _dmy(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
String _hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
String _n(double v) =>
    (v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1)).replaceAll(
      '.',
      ',',
    );

/// Segurança alimentar (HACCP): o que há para fazer hoje, os registos e os
/// controlos (frigoríficos, limpezas, pragas, extintor…).
class HaccpScreen extends ConsumerWidget {
  const HaccpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final podeEditar = ref.watch(currentPapelProvider).canEditBusiness;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(Routes.home),
          ),
          title: const Text('HACCP'),
          actions: [
            if (podeEditar)
              IconButton(
                tooltip: 'Quiosque de tarefas (cartão NFC)',
                icon: const Icon(Icons.touch_app_outlined),
                onPressed: () => context.go(Routes.quiosque),
              ),
            if (ref.watch(currentPapelProvider).canEditConfig)
              IconButton(
                tooltip: 'Equipa e cartões do quiosque',
                icon: const Icon(Icons.badge_outlined),
                onPressed: () => context.go(Routes.colaboradores),
              ),
            const HelpActions(topic: HelpTopic.haccp),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Hoje'),
              Tab(text: 'Registos'),
              Tab(text: 'Controlos'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const _HojeTab(),
            const _RegistosTab(),
            _ControlosTab(podeEditar: podeEditar),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hoje
// ---------------------------------------------------------------------------

class _HojeTab extends ConsumerWidget {
  const _HojeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final podeEscrever = ref.watch(currentPapelProvider).canEditBusiness;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final ncs = ref.watch(haccpNaoConformidadesProvider).valueOrNull ?? [];
    final controlos = ref.watch(haccpControlosProvider).valueOrNull ?? [];

    return AsyncValueView<List<StatusControlo>>(
      value: ref.watch(haccpEstadoProvider),
      onRetry: () => ref.invalidate(haccpEstadoProvider),
      data: (estados) {
        if (estados.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                controlos.isEmpty
                    ? 'Ainda não há controlos. Vai ao separador "Controlos" '
                          'para adicionar os habituais (frigorífico, limpezas, '
                          'pragas, extintor…).'
                    : 'Sem controlos ativos.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final porFazer = estados.where((s) => s.precisaAcaoHoje).length;
        final nomes = {for (final c in controlos) c.id: c};
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            Card(
              color: porFazer == 0
                  ? cs.primaryContainer
                  : cs.errorContainer.withValues(alpha: 0.6),
              child: ListTile(
                leading: Icon(
                  porFazer == 0
                      ? Icons.check_circle_outline
                      : Icons.notifications_active_outlined,
                ),
                title: Text(
                  porFazer == 0
                      ? 'Tudo em dia'
                      : '$porFazer ${porFazer == 1 ? 'controlo' : 'controlos'} '
                            'por fazer',
                  style: tt.titleMedium,
                ),
                subtitle: Text(_dmy(DateTime.now())),
              ),
            ),
            if (ncs.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Não conformidades por resolver (${ncs.length})',
                style: tt.titleSmall?.copyWith(color: cs.error),
              ),
              for (final r in ncs)
                Card(
                  child: ListTile(
                    leading: Icon(Icons.report_problem_outlined, color: cs.error),
                    title: Text(nomes[r.controloId]?.nome ?? 'Controlo'),
                    subtitle: Text(
                      '${_dmy(r.dataHora)} ${_hm(r.dataHora)}'
                      '${r.valor != null && (nomes[r.controloId]?.medeValor ?? false) ? ' · ${_n(r.valor!)} °C' : ''}'
                      '${r.acaoCorretiva.isEmpty ? '' : '\nAção: ${r.acaoCorretiva}'}'
                      '${r.notas.isEmpty ? '' : '\n${r.notas}'}',
                    ),
                    isThreeLine: r.acaoCorretiva.isNotEmpty || r.notas.isNotEmpty,
                    trailing: podeEscrever
                        ? TextButton(
                            onPressed: () =>
                                resolverNaoConformidade(context, ref, r),
                            child: const Text('Resolver'),
                          )
                        : null,
                  ),
                ),
            ],
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  final n = DateTime.now();
                  final hoje = DateTime(n.year, n.month, n.day);
                  gerarRelatorioHaccp(
                    context,
                    ref,
                    tipo: null,
                    desde: hoje,
                    ate: hoje,
                  );
                },
                icon: const Icon(Icons.description_outlined),
                label: const Text('Relatório de hoje'),
              ),
            ),
            for (final s in estados)
              _CartaoControlo(status: s, podeRegistar: podeEscrever),
          ],
        );
      },
    );
  }
}

class _CartaoControlo extends StatelessWidget {
  const _CartaoControlo({required this.status, required this.podeRegistar});
  final StatusControlo status;
  final bool podeRegistar;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = status.controlo;
    final (cor, texto) = switch (status.estado) {
      EstadoControlo.emDia => (cs.primary, 'Em dia'),
      EstadoControlo.pendenteHoje => (
        cs.aviso,
        c.esperadosPorDia > 1
            ? 'Hoje: ${status.feitosHoje} de ${status.esperadosHoje}'
            : 'Fazer hoje',
      ),
      EstadoControlo.atrasado => (
        cs.error,
        status.diasAtraso == 1
            ? 'Atrasado 1 dia'
            : 'Atrasado ${status.diasAtraso} dias',
      ),
      EstadoControlo.semRegisto => (cs.error, 'Ainda sem registo'),
      EstadoControlo.ocasional => (cs.outline, 'Quando for preciso'),
    };
    final ultimo = status.ultimo;
    final detalhes = [
      c.periodicidadeTexto,
      if (c.limitesTexto.isNotEmpty) c.limitesTexto,
      if (c.local.isNotEmpty) c.local,
    ].join(' · ');
    final proximo = status.proximo;

    return Card(
      child: ListTile(
        leading: Icon(iconeDoControlo(c.tipo), color: cor),
        title: Text(c.nome),
        subtitle: Text(
          '$detalhes\n'
          '${ultimo == null ? 'Nunca registado' : 'Último: ${_dmy(ultimo.dataHora)} ${_hm(ultimo.dataHora)}'
                '${c.medeValor && ultimo.valor != null ? ' · ${_n(ultimo.valor!)} °C' : ''}'}'
          '${status.estado == EstadoControlo.emDia && proximo != null && c.periodicidadeDias > 1 ? ' · próximo ${_dmy(proximo)}' : ''}',
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              texto,
              style: TextStyle(
                color: cor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            if (podeRegistar)
              SizedBox(
                height: 32,
                child: TextButton(
                  onPressed: () => showHaccpRegistoSheet(context, c),
                  child: const Text('Registar'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Registos
// ---------------------------------------------------------------------------

enum _Intervalo {
  hoje('Hoje'),
  semana('Últimos 7 dias'),
  esteMes('Este mês'),
  mesPassado('Mês passado'),
  trimestre('Últimos 90 dias'),
  ano('Último ano');

  const _Intervalo(this.label);
  final String label;

  /// Primeiro e último dia do período.
  ({DateTime desde, DateTime ate}) get datas {
    final n = DateTime.now();
    final hoje = DateTime(n.year, n.month, n.day);
    return switch (this) {
      _Intervalo.hoje => (desde: hoje, ate: hoje),
      _Intervalo.semana => (
        desde: DateTime(hoje.year, hoje.month, hoje.day - 6),
        ate: hoje,
      ),
      _Intervalo.esteMes => (
        desde: DateTime(hoje.year, hoje.month),
        ate: hoje,
      ),
      _Intervalo.mesPassado => (
        desde: DateTime(hoje.year, hoje.month - 1),
        ate: DateTime(hoje.year, hoje.month, 0),
      ),
      _Intervalo.trimestre => (
        desde: DateTime(hoje.year, hoje.month, hoje.day - 89),
        ate: hoje,
      ),
      _Intervalo.ano => (
        desde: DateTime(hoje.year, hoje.month, hoje.day - 364),
        ate: hoje,
      ),
    };
  }
}

class _RegistosTab extends ConsumerStatefulWidget {
  const _RegistosTab();

  @override
  ConsumerState<_RegistosTab> createState() => _RegistosTabState();
}

class _RegistosTabState extends ConsumerState<_RegistosTab> {
  _Intervalo _intervalo = _Intervalo.esteMes;
  TipoControlo? _tipo;
  bool _aGerar = false;

  IntervaloHaccp get _periodo => _intervalo.datas;

  Future<void> _gerar() async {
    final p = _periodo;
    setState(() => _aGerar = true);
    try {
      await gerarRelatorioHaccp(
        context,
        ref,
        tipo: _tipo,
        desde: p.desde,
        ate: p.ate,
      );
    } finally {
      if (mounted) setState(() => _aGerar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controlos = ref.watch(haccpTodosControlosProvider).valueOrNull ?? [];
    final p = _periodo;
    final async = ref.watch(haccpRegistosProvider(p));
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final porId = {for (final c in controlos) c.id: c};

    return Column(
      children: [
        // período
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (final i in _Intervalo.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(i.label),
                    selected: _intervalo == i,
                    onSelected: (_) => setState(() => _intervalo = i),
                  ),
                ),
            ],
          ),
        ),
        // tipo de controlo
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('Todos os tipos'),
                  selected: _tipo == null,
                  onSelected: (_) => setState(() => _tipo = null),
                ),
              ),
              for (final t in TipoControlo.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: Icon(iconeDoControlo(t), size: 16),
                    label: Text(t.label),
                    selected: _tipo == t,
                    onSelected: (_) => setState(() => _tipo = t),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: FilledButton.icon(
            onPressed: _aGerar ? null : _gerar,
            icon: const Icon(Icons.description_outlined),
            label: Text(
              _aGerar
                  ? 'A gerar…'
                  : 'Gerar relatório (${_dmy(p.desde)}'
                        '${p.desde == p.ate ? '' : ' a ${_dmy(p.ate)}'})',
            ),
          ),
        ),
        Expanded(
          child: AsyncValueView<List<RegistoHaccp>>(
            value: async,
            onRetry: () => ref.invalidate(haccpRegistosProvider),
            data: (todos) {
              final regs = [
                for (final r in todos)
                  if (_tipo == null || porId[r.controloId]?.tipo == _tipo) r,
              ];
              if (regs.isEmpty) {
                return const Center(child: Text('Sem registos neste período.'));
              }
              final nc = regs.where((r) => !r.conforme).length;
              return ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '${regs.length} registo(s)'
                      '${nc == 0 ? '' : ' · $nc não conformidade(s)'}',
                      style: tt.bodySmall,
                    ),
                  ),
                  for (final r in regs)
                    Card(
                      child: ListTile(
                        leading: Icon(
                          r.conforme
                              ? Icons.check_circle_outline
                              : Icons.report_problem_outlined,
                          color: r.conforme ? cs.primary : cs.error,
                        ),
                        title: Text(porId[r.controloId]?.nome ?? 'Controlo'),
                        subtitle: Text(
                          [
                            '${_dmy(r.dataHora)} ${_hm(r.dataHora)}',
                            if (r.valor != null &&
                                (porId[r.controloId]?.medeValor ?? false))
                              '${_n(r.valor!)} °C',
                            if (r.responsavel.isNotEmpty) r.responsavel,
                            if (r.proximoVencimento != null)
                              'próximo ${_dmy(r.proximoVencimento!)}',
                            if (!r.conforme)
                              r.resolvido ? 'resolvida' : 'por resolver',
                          ].join(' · ') +
                              (r.acaoCorretiva.isEmpty
                                  ? ''
                                  : '\nAção: ${r.acaoCorretiva}') +
                              (r.notas.isEmpty ? '' : '\n${r.notas}'),
                        ),
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

// ---------------------------------------------------------------------------
// Controlos
// ---------------------------------------------------------------------------

class _ControlosTab extends ConsumerWidget {
  const _ControlosTab({required this.podeEditar});
  final bool podeEditar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    return AsyncValueView<List<ControloHaccp>>(
      value: ref.watch(haccpTodosControlosProvider),
      onRetry: () => ref.invalidate(haccpTodosControlosProvider),
      data: (controlos) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            if (podeEditar)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    onPressed: () => showHaccpControloDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Novo controlo'),
                  ),
                  if (controlos.isEmpty)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                      ),
                      onPressed: () =>
                          ref.read(haccpActionsProvider).criarHabituais(),
                      icon: const Icon(Icons.playlist_add),
                      label: const Text('Adicionar os controlos habituais'),
                    ),
                ],
              ),
            if (controlos.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(
                  'Os habituais são: temperatura do frigorífico e da arca, '
                  'limpezas, inspeção de pragas, visita da empresa de pragas '
                  'e o extintor. Depois ajustas ou apagas o que não precisas.',
                  style: tt.bodyMedium,
                ),
              ),
            for (final c in controlos)
              Card(
                child: ListTile(
                  leading: Icon(
                    iconeDoControlo(c.tipo),
                    color: c.arquivado ? Theme.of(context).disabledColor : null,
                  ),
                  title: Text(
                    c.nome,
                    style: c.arquivado
                        ? TextStyle(color: Theme.of(context).disabledColor)
                        : null,
                  ),
                  subtitle: Text(
                    [
                      c.tipo.label,
                      c.periodicidadeTexto,
                      if (c.limitesTexto.isNotEmpty) c.limitesTexto,
                      if (c.local.isNotEmpty) c.local,
                      if (c.arquivado) 'arquivado',
                    ].join(' · '),
                  ),
                  trailing: podeEditar
                      ? PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'editar') {
                              await showHaccpControloDialog(
                                context,
                                existente: c,
                              );
                            } else {
                              final arquivar = !c.arquivado;
                              if (arquivar) {
                                final ok = await confirmDialog(
                                  context,
                                  titulo: 'Arquivar controlo',
                                  mensagem:
                                      'Deixa de aparecer em "Hoje" e de gerar '
                                      'lembretes. Os registos antigos ficam '
                                      'guardados.',
                                  confirmar: 'Arquivar',
                                );
                                if (!ok) return;
                              }
                              await ref
                                  .read(haccpActionsProvider)
                                  .arquivarControlo(c.id, arquivado: arquivar);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'editar',
                              child: Text('Editar'),
                            ),
                            PopupMenuItem(
                              value: 'arquivar',
                              child: Text(
                                c.arquivado ? 'Reativar' : 'Arquivar',
                              ),
                            ),
                          ],
                        )
                      : null,
                ),
              ),
          ],
        );
      },
    );
  }
}
