import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/help/help_content.dart';
import '../../../core/printing/print_html.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/help_actions.dart';
import '../../settings/application/empresa_providers.dart';
import '../application/haccp_providers.dart';
import '../domain/haccp.dart';
import 'haccp_controlo_dialog.dart';
import 'haccp_icones.dart';
import 'haccp_registo_sheet.dart';

String _dmy(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
String _hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
String _n(double v) =>
    (v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1)).replaceAll(
      '.',
      ',',
    );

const _estiloEstadoImpressao = '''
  h2 { font-size: 15px; margin: 18px 0 2px; }
  table { max-width: none; }
  th { text-align: left; }
  tr.nc td { background: #fde8e8; }
  p.aviso { color: #a00; font-size: 13px; }
''';

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
          actions: const [HelpActions(topic: HelpTopic.haccp)],
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
            const SizedBox(height: 12),
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
        Colors.orange.shade800,
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
  semana('Últimos 7 dias'),
  mes('Últimos 30 dias'),
  trimestre('Últimos 90 dias'),
  ano('Último ano');

  const _Intervalo(this.label);
  final String label;

  int get dias => switch (this) {
    _Intervalo.semana => 6,
    _Intervalo.mes => 29,
    _Intervalo.trimestre => 89,
    _Intervalo.ano => 364,
  };
}

class _RegistosTab extends ConsumerStatefulWidget {
  const _RegistosTab();

  @override
  ConsumerState<_RegistosTab> createState() => _RegistosTabState();
}

class _RegistosTabState extends ConsumerState<_RegistosTab> {
  _Intervalo _intervalo = _Intervalo.mes;
  String? _controloId;

  IntervaloHaccp get _periodo {
    final n = DateTime.now();
    final hoje = DateTime(n.year, n.month, n.day);
    return (
      desde: DateTime(hoje.year, hoje.month, hoje.day - _intervalo.dias),
      ate: hoje,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controlos = ref.watch(haccpTodosControlosProvider).valueOrNull ?? [];
    final nomeEmpresa = ref.watch(currentEmpresaProvider).valueOrNull?.nome ?? '';
    final p = _periodo;
    final async = ref.watch(haccpRegistosProvider(p));
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final porId = {for (final c in controlos) c.id: c};

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<_Intervalo>(
                  initialValue: _intervalo,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Período'),
                  items: [
                    for (final i in _Intervalo.values)
                      DropdownMenuItem(value: i, child: Text(i.label)),
                  ],
                  onChanged: (v) =>
                      setState(() => _intervalo = v ?? _intervalo),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _controloId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Controlo'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todos')),
                    for (final c in controlos)
                      DropdownMenuItem(
                        value: c.id,
                        child: Text(c.nome, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => _controloId = v),
                ),
              ),
              IconButton(
                tooltip: 'Imprimir / guardar em PDF',
                icon: const Icon(Icons.print_outlined),
                onPressed: async.valueOrNull == null
                    ? null
                    : () {
                        final regs = [
                          for (final r in async.valueOrNull!)
                            if (_controloId == null ||
                                r.controloId == _controloId)
                              r,
                        ];
                        abrirImpressao(
                          'HACCP — ${_dmy(p.desde)} a ${_dmy(p.ate)}',
                          haccpRelatorioHtml(
                            empresa: nomeEmpresa,
                            periodo: '${_dmy(p.desde)} – ${_dmy(p.ate)}',
                            controlos: [
                              for (final c in controlos)
                                if (_controloId == null || c.id == _controloId)
                                  c,
                            ],
                            registos: regs,
                          ),
                          estiloExtra: _estiloEstadoImpressao,
                        );
                      },
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncValueView<List<RegistoHaccp>>(
            value: async,
            onRetry: () => ref.invalidate(haccpRegistosProvider),
            data: (todos) {
              final regs = [
                for (final r in todos)
                  if (_controloId == null || r.controloId == _controloId) r,
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
