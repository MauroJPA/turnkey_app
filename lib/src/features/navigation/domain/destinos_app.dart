import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import 'pagina_app.dart';

/// Um sítio a que se chega pelo menu "Mais" ou pela pesquisa: uma página do
/// catálogo ou uma secção dentro de uma (ex.: Pessoas → Férias).
class DestinoApp {
  const DestinoApp({
    required this.rota,
    required this.label,
    required this.icon,
    required this.pagina,
    this.dentroDe = '',
    this.palavras = '',
  });

  final String rota;
  final String label;
  final IconData icon;

  /// Chave da página de que depende o acesso.
  final String pagina;

  /// Nome da página onde fica ("Pessoas"); vazio nas próprias páginas.
  final String dentroDe;

  /// Outras palavras que também o encontram ("ferias" → "folga").
  final String palavras;
}

/// As secções que valem a pena abrir diretamente (são o que as pessoas
/// procuram: "férias", "preços", "DRE"…).
const seccoesApp = <DestinoApp>[
  DestinoApp(
    rota: Routes.productionPrevisao,
    label: 'Quantos assar',
    icon: Icons.local_fire_department_outlined,
    pagina: 'producao',
    dentroDe: 'Produção',
    palavras: 'previsao sugestao amanha forno',
  ),
  DestinoApp(
    rota: Routes.schedule,
    label: 'Agenda de produção',
    icon: Icons.event_note_outlined,
    pagina: 'producao',
    dentroDe: 'Produção',
    palavras: 'agendar planear',
  ),
  DestinoApp(
    rota: Routes.productionLotes,
    label: 'Lotes e validades',
    icon: Icons.event_busy_outlined,
    pagina: 'producao',
    dentroDe: 'Produção',
    palavras: 'rastreabilidade qr etiqueta',
  ),
  DestinoApp(
    rota: Routes.comprasRelatorio,
    label: 'Relatório de compras',
    icon: Icons.summarize_outlined,
    pagina: 'compras',
    dentroDe: 'Compras',
  ),
  DestinoApp(
    rota: Routes.inventoryLimpeza,
    label: 'Limpeza e insumos',
    icon: Icons.cleaning_services_outlined,
    pagina: 'inventario',
    dentroDe: 'Inventário',
    palavras: 'consumiveis',
  ),
  DestinoApp(
    rota: Routes.inventoryMaterial,
    label: 'Material da loja',
    icon: Icons.chair_alt_outlined,
    pagina: 'inventario',
    dentroDe: 'Inventário',
  ),
  DestinoApp(
    rota: Routes.inventoryEmbalagens,
    label: 'Embalagens',
    icon: Icons.inventory_2_outlined,
    pagina: 'inventario',
    dentroDe: 'Inventário',
    palavras: 'caixas',
  ),
  DestinoApp(
    rota: Routes.inventoryPrecos,
    label: 'Preços dos ingredientes',
    icon: Icons.trending_up,
    pagina: 'inventario',
    dentroDe: 'Inventário',
    palavras: 'variacao subida comparar barato',
  ),
  DestinoApp(
    rota: Routes.analiseVendas,
    label: 'Análise de vendas',
    icon: Icons.insights_outlined,
    pagina: 'vendas',
    dentroDe: 'Vendas',
    palavras: 'sabores mais vendidos',
  ),
  DestinoApp(
    rota: Routes.fecho,
    label: 'Fecho do dia',
    icon: Icons.nights_stay_outlined,
    pagina: 'contagem',
    dentroDe: 'Contagem diária',
    palavras: 'fechar dia fim turno encerrar noite resumo',
  ),
  DestinoApp(
    rota: Routes.contagemRelatorios,
    label: 'Relatórios da contagem',
    icon: Icons.bar_chart,
    pagina: 'contagem',
    dentroDe: 'Contagem diária',
    palavras: 'desperdicio sobras',
  ),
  DestinoApp(
    rota: Routes.pessoasPonto,
    label: 'Ponto',
    icon: Icons.fingerprint,
    pagina: 'pessoas',
    dentroDe: 'Pessoas',
    palavras: 'entrada saida horas marcar',
  ),
  DestinoApp(
    rota: Routes.pessoasFerias,
    label: 'Férias e ausências',
    icon: Icons.beach_access_outlined,
    pagina: 'pessoas',
    dentroDe: 'Pessoas',
    palavras: 'ferias folga baixa falta',
  ),
  DestinoApp(
    rota: Routes.pessoasEscala,
    label: 'Escala da equipa',
    icon: Icons.calendar_view_week_outlined,
    pagina: 'pessoas',
    dentroDe: 'Pessoas',
    palavras: 'horario turnos',
  ),
  DestinoApp(
    rota: Routes.pessoasNotas,
    label: 'Notas da equipa',
    icon: Icons.sticky_note_2_outlined,
    pagina: 'pessoas',
    dentroDe: 'Pessoas',
    palavras: 'recados ocorrencias',
  ),
  DestinoApp(
    rota: Routes.pessoasFormacoes,
    label: 'Formações e certificados',
    icon: Icons.workspace_premium_outlined,
    pagina: 'pessoas',
    dentroDe: 'Pessoas',
    palavras: 'formacao certificado manipulador validade',
  ),
  DestinoApp(
    rota: Routes.dre,
    label: 'DRE',
    icon: Icons.account_balance_outlined,
    pagina: 'financeiro',
    dentroDe: 'Contabilidade',
    palavras: 'demonstracao resultados lucro',
  ),
  DestinoApp(
    rota: Routes.custosFixos,
    label: 'Custos fixos',
    icon: Icons.event_available_outlined,
    pagina: 'financeiro',
    dentroDe: 'Contabilidade',
    palavras: 'renda pagamentos despesas',
  ),
  DestinoApp(
    rota: Routes.equipamentos,
    label: 'Equipamentos',
    icon: Icons.blender_outlined,
    pagina: 'inventario',
    dentroDe: 'Inventário',
    palavras: 'amortizacao maquinas',
  ),
  DestinoApp(
    rota: Routes.relatorios,
    label: 'Relatórios',
    icon: Icons.description_outlined,
    pagina: 'financeiro',
    dentroDe: 'Contabilidade',
    palavras: 'iva exportar contabilista',
  ),
  DestinoApp(
    rota: Routes.numerosMagicos,
    label: 'Números mágicos',
    icon: Icons.calculate_outlined,
    pagina: 'financeiro',
    dentroDe: 'Contabilidade',
    palavras: 'ponto de equilibrio preco minimo',
  ),
  DestinoApp(
    rota: Routes.rentabilidade,
    label: 'Rentabilidade por sabor',
    icon: Icons.leaderboard_outlined,
    pagina: 'financeiro',
    dentroDe: 'Contabilidade',
    palavras: 'margem lucro canais',
  ),
  DestinoApp(
    rota: Routes.tabelaRevendedores,
    label: 'Tabela de revendedores',
    icon: Icons.price_change_outlined,
    pagina: 'financeiro',
    dentroDe: 'Contabilidade',
    palavras: 'precos revenda desconto',
  ),
  DestinoApp(
    rota: Routes.opcoesEmpresa,
    label: 'Empresa e aparência',
    icon: Icons.storefront_outlined,
    pagina: 'configuracoes',
    dentroDe: 'Configurações',
    palavras: 'nome moeda logotipo cores tema letra',
  ),
  DestinoApp(
    rota: Routes.opcoesCustos,
    label: 'Custos e IVA',
    icon: Icons.percent_outlined,
    pagina: 'configuracoes',
    dentroDe: 'Configurações',
    palavras: 'cmv margem percentuais dias de trabalho alerta preco',
  ),
  DestinoApp(
    rota: Routes.opcoesSeguranca,
    label: 'Segurança e backups',
    icon: Icons.shield_outlined,
    pagina: 'configuracoes',
    dentroDe: 'Configurações',
    palavras: 'copias 2 passos codigo email restauro disco',
  ),
  DestinoApp(
    rota: Routes.avisos,
    label: 'Avisos por email e Telegram',
    icon: Icons.notifications_outlined,
    pagina: 'configuracoes',
    dentroDe: 'Configurações',
    palavras: 'resumo diario semanal telegram',
  ),
  DestinoApp(
    rota: Routes.saudeDados,
    label: 'Saúde dos dados',
    icon: Icons.health_and_safety_outlined,
    pagina: 'configuracoes',
    dentroDe: 'Configurações',
    palavras: 'erros em falta duplicados',
  ),
  DestinoApp(
    rota: Routes.navegacao,
    label: 'Navegação e permissões',
    icon: Icons.admin_panel_settings_outlined,
    pagina: 'configuracoes',
    dentroDe: 'Configurações',
    palavras: 'rodape papeis acessos',
  ),
];

/// Páginas com várias secções onde faz sentido voltar à última vista (quem
/// vai e volta entre o Ponto e as Férias, ou fica nos Relatórios). Fora a
/// Produção, que abre sempre em "Produzir".
const paginasComMemoria = {'financeiro', 'pessoas', 'inventario'};

/// As rotas (a da página e as das secções) que pertencem à página [chave].
Set<String> rotasDaPagina(String chave) => {
  for (final d in todosDestinos())
    if (d.pagina == chave) d.rota,
};

/// A rota onde guardar a "última secção vista" quando se está em [location].
bool deveLembrar(String chave, String location) =>
    paginasComMemoria.contains(chave) &&
    rotasDaPagina(chave).contains(location);

/// Onde abre a página [p]: na última secção vista, se a há e é válida; senão
/// na própria página.
String rotaAoAbrir(PaginaApp p, String? guardada) {
  if (guardada != null &&
      paginasComMemoria.contains(p.chave) &&
      rotasDaPagina(p.chave).contains(guardada)) {
    return guardada;
  }
  return p.rota;
}

/// Chave da preferência (neste aparelho) com a última secção vista de [chave].
String chaveUltimaSeccao(String chave) => 'ultima_seccao_$chave';

/// Como o menu "Mais" agrupa as páginas, por tarefa (não por tipo de ecrã).
/// Uma página só aparece num grupo.
const gruposMais = <({String titulo, List<String> paginas})>[
  (
    titulo: 'Fazer hoje',
    paginas: [
      'producao',
      'contagem',
      'compras',
      'encomendas',
      'haccp',
      'quiosque',
    ],
  ),
  (
    titulo: 'Receitas e custos',
    paginas: ['receitas', 'fichas', 'inventario', 'faturas'],
  ),
  (titulo: 'Equipa', paginas: ['pessoas', 'equipa']),
  (titulo: 'Dinheiro', paginas: ['vendas', 'financeiro']),
  (titulo: 'Casa', paginas: ['configuracoes']),
];

/// Páginas que não estão em nenhum grupo (rede de segurança: uma página nova
/// nunca fica fora do menu).
List<PaginaApp> paginasSemGrupo() {
  final agrupadas = {for (final g in gruposMais) ...g.paginas};
  return [
    for (final p in paginasApp)
      if (!agrupadas.contains(p.chave)) p,
  ];
}

const _acentos = {
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ç': 'c',
  'ñ': 'n',
};

/// Minúsculas e sem acentos, para "ferias" encontrar "Férias".
String normalizarBusca(String s) {
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    b.write(_acentos[c] ?? c);
  }
  return b.toString().trim();
}

/// Todos os destinos pesquisáveis: as páginas e as suas secções.
List<DestinoApp> todosDestinos() => [
  for (final p in paginasApp)
    DestinoApp(
      rota: p.rota,
      label: p.label,
      icon: p.icon,
      pagina: p.chave,
      palavras: p.descricao,
    ),
  ...seccoesApp,
];

/// Quão bem [d] responde a [consulta] (0 = não responde). Todas as palavras
/// da consulta têm de aparecer; o nome conta mais do que as outras palavras,
/// e começar pela palavra conta mais do que tê-la a meio.
int pontuarDestino(String consulta, DestinoApp d) {
  final palavras = normalizarBusca(
    consulta,
  ).split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (palavras.isEmpty) return 0;
  final nome = normalizarBusca(d.label);
  final resto = normalizarBusca('${d.dentroDe} ${d.palavras}');
  var total = 0;
  for (final p in palavras) {
    if (nome.startsWith(p)) {
      total += 100;
    } else if (nome.contains(' $p')) {
      total += 80;
    } else if (nome.contains(p)) {
      total += 50;
    } else if (resto.contains(p)) {
      total += 20;
    } else {
      return 0;
    }
  }
  return total;
}

/// Os destinos que respondem à [consulta] e que a pessoa pode abrir, os
/// melhores primeiro (e, a igual pontuação, as páginas antes das secções).
List<DestinoApp> procurarDestinos(
  String consulta,
  bool Function(String pagina) acessivel, {
  int maximo = 8,
}) {
  final todos = todosDestinos();
  final achados = <({DestinoApp d, int pontos, int ordem})>[];
  for (var i = 0; i < todos.length; i++) {
    final d = todos[i];
    if (!acessivel(d.pagina)) continue;
    final p = pontuarDestino(consulta, d);
    if (p > 0) achados.add((d: d, pontos: p, ordem: i));
  }
  achados.sort((a, b) {
    final c = b.pontos.compareTo(a.pontos);
    return c != 0 ? c : a.ordem.compareTo(b.ordem);
  });
  return [for (final a in achados.take(maximo)) a.d];
}
