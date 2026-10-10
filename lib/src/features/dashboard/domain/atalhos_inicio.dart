import 'package:flutter/material.dart';

import '../../../app/routes.dart';

/// Um atalho grande do Início: leva direto a uma tarefa do dia a dia (não à
/// página inteira, que já está no rodapé).
class AtalhoInicio {
  const AtalhoInicio(this.chave, this.rota, this.label, this.icon, this.pagina);

  final String chave;
  final String rota;
  final String label;
  final IconData icon;

  /// Chave da página (para saber se a pessoa tem acesso).
  final String pagina;
}

const atalhosInicio = <AtalhoInicio>[
  AtalhoInicio(
    'produzir',
    Routes.production,
    'Produzir agora',
    Icons.checklist_rtl,
    'producao',
  ),
  AtalhoInicio(
    'assar',
    Routes.productionPrevisao,
    'Quantos assar',
    Icons.local_fire_department_outlined,
    'producao',
  ),
  AtalhoInicio(
    'contagem',
    Routes.contagem,
    'Contagem',
    Icons.fact_check_outlined,
    'contagem',
  ),
  AtalhoInicio(
    'ponto',
    Routes.pessoasPonto,
    'Marcar ponto',
    Icons.fingerprint,
    'pessoas',
  ),
  AtalhoInicio(
    'fatura',
    Routes.invoices,
    'Foto da fatura',
    Icons.document_scanner_outlined,
    'faturas',
  ),
  AtalhoInicio(
    'compras',
    Routes.shopping,
    'Lista de compras',
    Icons.shopping_cart_outlined,
    'compras',
  ),
  AtalhoInicio(
    'encomendas',
    Routes.encomendas,
    'Encomendas',
    Icons.assignment_outlined,
    'encomendas',
  ),
  AtalhoInicio(
    'haccp',
    Routes.haccp,
    'HACCP',
    Icons.health_and_safety_outlined,
    'haccp',
  ),
  AtalhoInicio(
    'vendas',
    Routes.sales,
    'Vendas',
    Icons.point_of_sale_outlined,
    'vendas',
  ),
  AtalhoInicio(
    'fecho',
    Routes.fecho,
    'Fecho do dia',
    Icons.nights_stay_outlined,
    'contagem',
  ),
  AtalhoInicio(
    'tarefas',
    Routes.tarefas,
    'Tarefas',
    Icons.view_kanban_outlined,
    'tarefas',
  ),
];

/// Quantos atalhos cabem no Início.
const atalhosMaximo = 3;

/// Os atalhos de quem não escolheu nenhuns.
const atalhosPorOmissao = ['produzir', 'assar', 'contagem'];

/// Chave da preferência deste aparelho.
const chaveAtalhosInicio = 'inicio_atalhos';

AtalhoInicio? atalhoPorChave(String chave) {
  for (final a in atalhosInicio) {
    if (a.chave == chave) return a;
  }
  return null;
}

/// Os atalhos a mostrar: os escolhidos ([guardado], chaves separadas por
/// vírgula) a que a pessoa tem acesso; se faltar, completa com os do costume
/// e, no fim, com o que houver. No máximo [atalhosMaximo].
List<AtalhoInicio> atalhosEscolhidos(
  String? guardado,
  bool Function(String pagina) acessivel,
) {
  final out = <AtalhoInicio>[];
  void juntar(Iterable<String> chaves) {
    for (final c in chaves) {
      final a = atalhoPorChave(c);
      if (a == null || out.contains(a) || !acessivel(a.pagina)) continue;
      if (out.length < atalhosMaximo) out.add(a);
    }
  }

  final escolhidos = (guardado ?? '')
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty);
  juntar(escolhidos);
  // só completa quando a pessoa nunca escolheu; quem escolheu menos de 3 fica
  // com os que quis
  if (guardado == null || guardado.trim().isEmpty) {
    juntar(atalhosPorOmissao);
    juntar(atalhosInicio.map((a) => a.chave));
  }
  return out;
}
