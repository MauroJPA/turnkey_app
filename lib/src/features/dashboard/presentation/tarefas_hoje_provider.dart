import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/errors/mensagem_amigavel.dart';
import '../../../core/formatting/money_provider.dart';
import '../../finance/application/custos_fixos_providers.dart';
import '../../haccp/application/haccp_providers.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../inventory/data/variacao_preco_repository.dart';
import '../../inventory/domain/variacao_preco.dart';
import '../../invoices/application/invoice_providers.dart';
import '../../invoices/domain/fatura.dart';
import '../../navigation/application/navigation_providers.dart';
import '../../orders/application/encomendas_providers.dart';
import '../../orders/data/configuracoes_encomendas_repository.dart';
import '../../people/application/ferias_providers.dart';
import '../../people/application/formacoes_providers.dart';
import '../../people/application/notas_providers.dart';
import '../../people/application/ponto_providers.dart';
import '../../people/application/saidas_providers.dart';
import '../../people/data/ferias_repository.dart';
import '../../people/data/formacoes_repository.dart';
import '../../people/data/ponto_repository.dart';
import '../../people/domain/ferias.dart';
import '../../people/domain/formacao.dart';
import '../../people/domain/nota.dart';
import '../../people/domain/ponto.dart';
import '../../people/presentation/formacoes_view.dart';
import '../../sales/data/sales_repository.dart';
import '../../schedule/application/schedule_providers.dart';
import '../../schedule/domain/production_plan.dart';
import '../../settings/data/aprovacoes_repository.dart';
import '../../settings/data/backups_repository.dart';
import '../../settings/data/vigia_repository.dart';
import '../../settings/domain/vigia.dart';
import '../../shopping/application/shopping_providers.dart';
import '../../traceability/data/lotes_repository.dart';
import '../../traceability/domain/validades.dart';
import '../domain/tarefa_hoje.dart';

String _hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _dm(DateTime d) => '${d.day}/${d.month}';

void _aviso(ScaffoldMessengerState m, String texto, {SnackBarAction? acao}) {
  m
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto), action: acao));
}

/// Corre [f] e avisa se falhar, sem deixar a exceção subir. O avisador é
/// apanhado antes de esperar, para não usar o contexto depois do `await`.
Future<void> _tentar(
  BuildContext context,
  Future<void> Function(ScaffoldMessengerState m) f,
) async {
  final m = ScaffoldMessenger.of(context);
  try {
    await f(m);
  } on Object catch (e) {
    _aviso(m, mensagemAmigavel(e));
  }
}

/// Tudo o que pede atenção no Início, já ordenado por urgência e com a ação
/// que o resolve ali mesmo (aprovar, renovar, marcar saída…). Só entra o que
/// a pessoa pode ver e que existe: sem avisos, a lista fica vazia.
final tarefasHojeProvider = Provider.autoDispose<List<TarefaHoje>>((ref) {
  final papel = ref.watch(currentPapelProvider);
  final navConfig = ref.watch(navConfigAtualProvider);
  bool acessivel(String chave) => navConfig.acessivel(papel, chave);
  final fmt = ref.watch(moneyFormatProvider);
  final hoje = DateTime.now();
  final hojeDia = DateTime(hoje.year, hoje.month, hoje.day);
  final admin = papel.canEditConfig;
  final podeVerPessoas = acessivel('pessoas');

  final tarefas = <TarefaHoje>[];

  // ---- segurança, dinheiro e prazos
  final backups = ref.watch(estadoBackupsProvider).valueOrNull;
  if (backups != null && backups.problema()) {
    tarefas.add(
      TarefaHoje(
        chave: 'backup',
        icon: Icons.backup_outlined,
        titulo: 'Backup com problema',
        urgencia: Urgencia.urgente,
        rota: Routes.opcoesSeguranca,
        resumo: backups.avisos().take(2).join(' '),
        quantidade: 1,
      ),
    );
  }

  // vigia de segurança do servidor (só o dono do servidor o recebe)
  final vigia = ref.watch(vigiaProvider).valueOrNull;
  if (vigia != null && vigia.instalado && vigia.nivel != GravidadeVigia.info) {
    tarefas.add(
      TarefaHoje(
        chave: 'vigia',
        icon: Icons.gpp_maybe_outlined,
        titulo: vigia.haIncidente
            ? 'Possível intrusão no servidor'
            : 'Segurança do servidor',
        urgencia: vigia.nivel == GravidadeVigia.critico
            ? Urgencia.urgente
            : Urgencia.atencao,
        rota: Routes.opcoesSeguranca,
        quantidade: vigia.ativos.isEmpty ? 1 : vigia.ativos.length,
        resumo: vigia.ativos.isEmpty
            ? 'O vigia parou de correr'
            : vigia.ativos.take(2).map((a) => a.titulo).join(' · '),
      ),
    );
  }

  final vendus = acessivel('vendas')
      ? ref.watch(estadoVendusProvider).valueOrNull
      : null;
  if (vendus != null && vendus.desatualizado(hoje)) {
    tarefas.add(
      TarefaHoje(
        chave: 'vendus',
        icon: Icons.sync_problem,
        titulo: 'Vendus sem sincronizar',
        urgencia: Urgencia.urgente,
        rota: Routes.sales,
        quantidade: 1,
        resumo: vendus.okEm == null
            ? 'ainda não sincronizou${vendus.resultado.isEmpty ? '' : ': ${vendus.resultado}'}'
            : 'última vez ${vendus.quando(hoje)}${vendus.resultado.isEmpty ? '' : ': ${vendus.resultado}'}',
      ),
    );
  }

  if (acessivel('haccp')) {
    final porFazer = ref
        .watch(haccpEstadoProvider)
        .valueOrNull
        ?.where((s) => s.precisaAcaoHoje)
        .toList();
    final nc =
        ref.watch(haccpNaoConformidadesProvider).valueOrNull?.length ?? 0;
    if ((porFazer?.isNotEmpty ?? false) || nc > 0) {
      tarefas.add(
        TarefaHoje(
          chave: 'haccp',
          icon: Icons.health_and_safety_outlined,
          titulo: 'HACCP por fazer',
          urgencia: nc > 0 || (porFazer?.any((s) => s.emAtraso) ?? false)
              ? Urgencia.urgente
              : Urgencia.atencao,
          rota: Routes.haccp,
          quantidade: porFazer?.length ?? 0,
          resumo: [
            if (porFazer?.isNotEmpty ?? false)
              porFazer!.take(3).map((s) => s.controlo.nome).join(', '),
            if (nc > 0) '$nc não conformidade${nc == 1 ? '' : 's'}',
          ].join(' · '),
        ),
      );
    }
  }

  final validades = acessivel('producao')
      ? (ref.watch(alertasValidadeProvider).valueOrNull ??
            const <AlertaValidade>[])
      : const <AlertaValidade>[];
  if (validades.isNotEmpty) {
    tarefas.add(
      TarefaHoje(
        chave: 'validades',
        icon: Icons.event_busy_outlined,
        titulo: 'Validades a acabar',
        urgencia: validades.any((a) => a.dias <= 0)
            ? Urgencia.urgente
            : Urgencia.atencao,
        rota: Routes.productionLotes,
        itens: [
          for (final a in validades) ItemTarefa('${a.nome} (${a.quando})'),
        ],
      ),
    );
  }

  final formacoes = podeVerPessoas
      ? ref.watch(formacoesEmAlertaProvider)
      : const <Formacao>[];
  if (formacoes.isNotEmpty) {
    final uid = ref.read(formacoesRepositoryProvider).utilizadorId;
    bool podeRenovar(Formacao f) =>
        papel.canEditBusiness && (admin || (uid != null && f.userId == uid));
    tarefas.add(
      TarefaHoje(
        chave: 'formacoes',
        icon: Icons.workspace_premium_outlined,
        titulo: 'Formações a caducar',
        urgencia:
            formacoes.any((f) => f.estado(hoje) == EstadoValidade.caducada)
            ? Urgencia.urgente
            : Urgencia.atencao,
        rota: Routes.pessoasFormacoes,
        itens: [
          for (final f in formacoes)
            ItemTarefa(
              '${f.nome}: ${f.titulo} (${f.quando(hoje)})',
              rotuloAcao: podeRenovar(f) ? 'Renovar' : null,
              acao: podeRenovar(f)
                  ? (context, ref) => mostrarFormacao(context, ref, renovar: f)
                  : null,
            ),
        ],
      ),
    );
  }

  if (acessivel('encomendas')) {
    final lembre =
        ref.watch(configuracaoEncomendasProvider).valueOrNull?.lembreteHoras ??
        4;
    final proximas =
        (ref.watch(encomendasListProvider(false)).valueOrNull ?? [])
            .where((e) => e.estado.ativa && e.horasAte(hoje) <= lembre)
            .toList()
          ..sort((a, b) => a.dataHora.compareTo(b.dataHora));
    if (proximas.isNotEmpty) {
      tarefas.add(
        TarefaHoje(
          chave: 'encomendas',
          icon: Icons.assignment_outlined,
          titulo: 'Encomendas por vir',
          urgencia: proximas.any((e) => e.horasAte(hoje) <= 1)
              ? Urgencia.urgente
              : Urgencia.atencao,
          rota: Routes.encomendas,
          itens: [
            for (final e in proximas)
              ItemTarefa('${e.clienteNome} · ${_hm(e.dataHora)}'),
          ],
        ),
      );
    }
  }

  if (acessivel('financeiro')) {
    final pagamentos =
        (ref.watch(custosFixosListProvider(false)).valueOrNull ?? [])
            .where((c) => c.diaPagamento != null)
            .map(
              (c) => (custo: c, dias: diasAtePagamento(c.diaPagamento!, hoje)),
            )
            .where((p) => p.dias <= 7)
            .toList()
          ..sort((a, b) => a.dias.compareTo(b.dias));
    if (pagamentos.isNotEmpty) {
      String quando(int d) => d == 0 ? 'hoje' : 'em ${d}d';
      tarefas.add(
        TarefaHoje(
          chave: 'pagamentos',
          icon: Icons.event_available_outlined,
          titulo: 'Pagamentos por vir',
          urgencia: pagamentos.any((p) => p.dias <= 2)
              ? Urgencia.urgente
              : Urgencia.info,
          rota: Routes.custosFixos,
          itens: [
            for (final p in pagamentos)
              ItemTarefa('${p.custo.nome} (${quando(p.dias)})'),
          ],
        ),
      );
    }
  }

  // ---- para decidir ou tratar hoje
  final contas =
      ref.watch(aprovacoesProvider).valueOrNull?.pendentes ??
      const <ContaPendente>[];
  if (contas.isNotEmpty) {
    tarefas.add(
      TarefaHoje(
        chave: 'contas',
        icon: Icons.how_to_reg_outlined,
        titulo: 'Contas por aprovar',
        urgencia: Urgencia.atencao,
        rota: Routes.aprovacoes,
        itens: [
          for (final c in contas)
            ItemTarefa(
              c.email,
              rotuloAcao: 'Aprovar',
              acao: (context, ref) => _tentar(context, (m) async {
                await ref.read(aprovacoesRepositoryProvider).aprovar(c.id);
                ref.invalidate(aprovacoesProvider);
                _aviso(m, 'Conta de ${c.email} aprovada.');
              }),
            ),
        ],
      ),
    );
  }

  if (acessivel('faturas')) {
    final porRever = (ref.watch(faturasListProvider).valueOrNull ?? [])
        .where(
          (f) =>
              f.estado == FaturaEstado.nova ||
              f.estado == FaturaEstado.analisada,
        )
        .toList();
    if (porRever.isNotEmpty) {
      tarefas.add(
        TarefaHoje(
          chave: 'faturas',
          icon: Icons.rule_folder_outlined,
          titulo: 'Faturas por rever',
          urgencia: Urgencia.atencao,
          rota: Routes.invoices,
          itens: [
            for (final f in porRever)
              ItemTarefa(
                f.fornecedor.isEmpty ? 'Fatura sem fornecedor' : f.fornecedor,
                rotuloAcao: 'Rever',
                acao: (context, ref) async =>
                    context.go('${Routes.invoices}/${f.id}'),
              ),
          ],
        ),
      );
    }
  }

  final saidas = podeVerPessoas
      ? ref.watch(saidasPorMarcarProvider)
      : const <SaidaPorMarcar>[];
  if (saidas.isNotEmpty) {
    tarefas.add(
      TarefaHoje(
        chave: 'saidas',
        icon: Icons.logout,
        titulo: 'Saída por marcar',
        urgencia: Urgencia.atencao,
        rota: Routes.pessoasPonto,
        itens: [
          for (final s in saidas)
            ItemTarefa(
              '${s.nome} · entrou ${s.entrada.day == hoje.day && s.entrada.month == hoje.month ? 'às' : 'a ${_dm(s.entrada)} às'} ${_hm(s.entrada)}',
              // com o fim do turno conhecido é um toque; senão, escolhe-se a hora na página
              rotuloAcao: s.fimPrevisto == null
                  ? null
                  : 'Saída às ${_hm(s.fimPrevisto!)}',
              acao: s.fimPrevisto == null
                  ? null
                  : (context, ref) => _tentar(context, (m) async {
                      await ref
                          .read(pontoRepositoryProvider)
                          .registar(
                            pessoa: s.pessoa,
                            nome: s.nome,
                            userId: s.pessoa.startsWith('u:')
                                ? s.pessoa.substring(2)
                                : '',
                            tipo: TipoPonto.saida,
                            dataHora: s.fimPrevisto!,
                            origem: OrigemPonto.manual,
                            notas:
                                'Saída esquecida, registada pela administração',
                          );
                      ref.invalidate(pontoMesProvider);
                      ref.invalidate(pontoRecenteProvider);
                      ref.invalidate(pontoEstadoProvider);
                      _aviso(
                        m,
                        'Saída de ${s.nome} registada às ${_hm(s.fimPrevisto!)}.',
                      );
                    }),
            ),
        ],
      ),
    );
  }

  if (podeVerPessoas && admin) {
    final pedidos =
        ref
            .watch(feriasAnoProvider(hoje.year))
            .valueOrNull
            ?.where((a) => a.estado == EstadoAusencia.pedido)
            .toList() ??
        const <Ausencia>[];
    if (pedidos.isNotEmpty) {
      tarefas.add(
        TarefaHoje(
          chave: 'ferias',
          icon: Icons.beach_access_outlined,
          titulo: 'Férias por aprovar',
          urgencia: Urgencia.atencao,
          rota: Routes.pessoasFerias,
          itens: [
            for (final a in pedidos)
              ItemTarefa(
                '${a.nome} · ${_dm(a.de)} a ${_dm(a.ate)}'
                '${a.diasUteis > 0 ? ' (${a.diasUteis} d úteis)' : ''}',
                rotuloAcao: 'Aprovar',
                acao: (context, ref) => _tentar(context, (m) async {
                  final repo = ref.read(feriasRepositoryProvider);
                  // o contentor sobrevive à saída do Início (o "Desfazer" vive 4 s)
                  final c = ProviderScope.containerOf(context);
                  await repo.decidir(a.id, EstadoAusencia.aprovado);
                  c.invalidate(feriasAnoProvider);
                  c.invalidate(feriasDireitosProvider);
                  _aviso(
                    m,
                    'Férias de ${a.nome} aprovadas.',
                    acao: SnackBarAction(
                      label: 'Desfazer',
                      onPressed: () async {
                        await repo.decidir(a.id, EstadoAusencia.pedido);
                        c.invalidate(feriasAnoProvider);
                        c.invalidate(feriasDireitosProvider);
                      },
                    ),
                  );
                }),
              ),
          ],
        ),
      );
    }
  }

  final notas = podeVerPessoas
      ? ref.watch(notasParaHojeProvider)
      : const <Nota>[];
  if (notas.isNotEmpty) {
    tarefas.add(
      TarefaHoje(
        chave: 'notas',
        icon: Icons.sticky_note_2_outlined,
        titulo: 'Notas para hoje',
        urgencia: Urgencia.atencao,
        rota: Routes.pessoasNotas,
        itens: [
          for (final n in notas)
            ItemTarefa(n.titulo.isNotEmpty ? n.titulo : n.texto),
        ],
      ),
    );
  }

  // ---- produção e compras
  if (acessivel('producao')) {
    final planos = ref.watch(plansListProvider).valueOrNull ?? const [];
    final abertos = planos.where(
      (p) =>
          p.estado != EstadoProducao.concluida &&
          p.estado != EstadoProducao.cancelada &&
          !p.data.isBefore(hojeDia),
    );
    final deHoje = abertos
        .where(
          (p) =>
              p.data.year == hoje.year &&
              p.data.month == hoje.month &&
              p.data.day == hoje.day,
        )
        .toList();
    final futuras = abertos.length - deHoje.length;
    if (deHoje.isNotEmpty) {
      tarefas.add(
        TarefaHoje(
          chave: 'producao-hoje',
          icon: Icons.event_note_outlined,
          titulo: 'Produção de hoje',
          urgencia: Urgencia.atencao,
          rota: Routes.schedule,
          itens: [for (final p in deHoje) ItemTarefa(p.titulo)],
        ),
      );
    }
    if (futuras > 0) {
      tarefas.add(
        TarefaHoje(
          chave: 'producao-futura',
          icon: Icons.event_outlined,
          titulo: 'Produções agendadas',
          urgencia: Urgencia.info,
          rota: Routes.schedule,
          quantidade: futuras,
          resumo: futuras == 1 ? 'uma nos próximos dias' : 'nos próximos dias',
        ),
      );
    }
  }

  if (acessivel('compras')) {
    final porComprar = (ref.watch(shoppingListProvider).valueOrNull ?? [])
        .where((c) => !c.comprado)
        .toList();
    if (porComprar.isNotEmpty) {
      final valor = porComprar.fold<double>(0, (s, c) => s + c.custoEstimado);
      tarefas.add(
        TarefaHoje(
          chave: 'compras',
          icon: Icons.shopping_cart_outlined,
          titulo: 'A comprar',
          urgencia: Urgencia.atencao,
          rota: Routes.shopping,
          quantidade: porComprar.length,
          resumo: valor > 0 ? 'estimativa ${fmt(valor)}' : 'por comprar',
        ),
      );
    }
  }

  if (acessivel('inventario')) {
    final baixo =
        ref
            .watch(stockListProvider)
            .valueOrNull
            ?.where((s) => s.stockBaixo)
            .length ??
        0;
    if (baixo > 0) {
      tarefas.add(
        TarefaHoje(
          chave: 'stock',
          icon: Icons.warning_amber_rounded,
          titulo: 'Stock baixo',
          urgencia: Urgencia.atencao,
          rota: Routes.inventory,
          quantidade: baixo,
          resumo: '${baixo == 1 ? 'item abaixo' : 'itens abaixo'} do mínimo',
        ),
      );
    }

    final subidas = ref.watch(subidasPorVerProvider);
    if (subidas.isNotEmpty) {
      tarefas.add(
        TarefaHoje(
          chave: 'precos',
          icon: Icons.trending_up,
          titulo: 'Preços subiram',
          urgencia: Urgencia.info,
          rota: Routes.inventoryPrecos,
          itens: [
            for (final VariacaoPreco v in subidas)
              ItemTarefa('${v.ingredienteNome} +${v.pct.toStringAsFixed(0)}%'),
          ],
        ),
      );
    }
  }

  // ao fim do dia, lembra o fecho (só um empurrão: não faz contas pesadas aqui)
  if (acessivel('contagem') && hoje.hour >= 17) {
    tarefas.add(
      const TarefaHoje(
        chave: 'fecho',
        icon: Icons.nights_stay_outlined,
        titulo: 'Fecho do dia',
        urgencia: Urgencia.info,
        rota: Routes.fecho,
        resumo: 'Contagem, desperdício, vendas, HACCP, ponto e amanhã',
      ),
    );
  }

  return tarefas;
});
