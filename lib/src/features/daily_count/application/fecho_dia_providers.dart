import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_user.dart';
import '../../haccp/application/haccp_providers.dart';
import '../../navigation/application/navigation_providers.dart';
import '../../people/application/ponto_providers.dart';
import '../../people/application/saidas_providers.dart';
import '../../people/domain/ponto.dart';
import '../../sales/data/sales_repository.dart';
import '../../schedule/application/schedule_providers.dart';
import '../../schedule/domain/production_plan.dart';
import '../../shopping/application/shopping_providers.dart';
import '../domain/fecho_dia.dart';
import 'contagem_providers.dart';

/// O que se sabe do dia de hoje para o "Fecho do dia". Cada parte só se vai
/// buscar se a pessoa tem acesso à página respetiva; se falhar, a parte fica
/// de fora (o fecho nunca parte por causa de uma delas).
final fechoDiaProvider = FutureProvider.autoDispose<DadosFecho>((ref) async {
  final papel = ref.watch(currentPapelProvider);
  final nav = ref.watch(navConfigAtualProvider);
  bool acessivel(String chave) => nav.acessivel(papel, chave);
  final n = DateTime.now();
  final hoje = DateTime(n.year, n.month, n.day);
  final amanha = DateTime(n.year, n.month, n.day + 1);

  Future<T?> tentar<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on Object {
      return null;
    }
  }

  Map<String, int>? semFecho;
  var comFecho = 0;
  double? desperdicio;
  if (acessivel('contagem')) {
    final locais = await tentar(() => ref.watch(locaisProvider.future));
    if (locais != null) {
      semFecho = {};
      desperdicio = 0;
      for (final l in locais) {
        final c = await tentar(
          () => ref.watch(
            contagemDoDiaProvider((localId: l.id, dia: hoje)).future,
          ),
        );
        if (c == null) continue;
        var falta = 0;
        for (final linha in c.linhas) {
          if (linha.fecho != null) {
            comFecho++;
          } else if (linha.temMovimento) {
            falta++;
          }
          desperdicio = (desperdicio ?? 0) + linha.desperdicio;
        }
        if (falta > 0) semFecho[l.nome] = falta;
      }
    }
  }

  int? vendasN;
  var vendasTotal = 0.0;
  if (acessivel('vendas')) {
    final vs = await tentar(
      () => ref.watch(salesRepositoryProvider).list(desde: hoje, ate: hoje),
    );
    if (vs != null) {
      vendasN = vs.length;
      vendasTotal = vs.fold<double>(0, (s, v) => s + v.total);
    }
  }

  int? haccp;
  var nc = 0;
  if (acessivel('haccp')) {
    final estado = await tentar(() => ref.watch(haccpEstadoProvider.future));
    if (estado != null) {
      haccp = estado.where((s) => s.precisaAcaoHoje).length;
      nc =
          (await tentar(
            () => ref.watch(haccpNaoConformidadesProvider.future),
          ))?.length ??
          0;
    }
  }

  List<String>? saidas;
  var aTrabalhar = <String>[];
  if (acessivel('pessoas') && papel.canEditConfig) {
    saidas = [
      for (final s in ref.watch(saidasPorMarcarProvider))
        if (s.nome.isNotEmpty) s.nome,
    ];
    final regs = await tentar(() => ref.watch(pontoRecenteProvider.future));
    if (regs != null) {
      aTrabalhar = {
        for (final j in calcularJornadas(regs, n))
          if (j.aTrabalhar && !saidas.contains(j.nome)) j.nome,
      }.toList();
    }
  }

  bool? planoAmanha;
  if (acessivel('producao')) {
    final planos = await tentar(() => ref.watch(plansListProvider.future));
    if (planos != null) {
      planoAmanha = planos.any(
        (p) =>
            p.estado != EstadoProducao.cancelada &&
            DateTime(p.data.year, p.data.month, p.data.day) == amanha,
      );
    }
  }

  int? porComprar;
  if (acessivel('compras')) {
    final lista = await tentar(() => ref.watch(shoppingListProvider.future));
    if (lista != null) porComprar = lista.where((c) => !c.comprado).length;
  }

  return DadosFecho(
    semFechoPorLocal: semFecho,
    comFecho: comFecho,
    desperdicioUn: desperdicio,
    vendasN: vendasN,
    vendasTotal: vendasTotal,
    haccpPorFazer: haccp,
    naoConformidades: nc,
    saidasPorMarcar: saidas,
    aTrabalhar: aTrabalhar,
    planoAmanha: planoAmanha,
    porComprar: porComprar,
  );
});
