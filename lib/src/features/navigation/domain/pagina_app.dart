import 'package:flutter/material.dart';

import '../../../app/routes.dart';

/// Uma página (ou grupo de páginas) da app que pode ir no rodapé, na grelha
/// do Início e ter permissões próprias por papel.
class PaginaApp {
  const PaginaApp(
    this.chave,
    this.rota,
    this.label,
    this.icon,
    this.descricao, {
    this.rotasExtra = const [],
  });

  /// Identificador estável, guardado na configuração (nunca muda).
  final String chave;
  final String rota;
  final String label;
  final IconData icon;
  final String descricao;

  /// Outras rotas que também pertencem a esta página (ex.: a Agenda faz parte
  /// da Produção).
  final List<String> rotasExtra;
}

/// Chave do Início: está sempre disponível e sempre primeiro no rodapé.
const chaveInicio = 'inicio';

const paginasApp = <PaginaApp>[
  PaginaApp(
    'producao',
    Routes.production,
    'Produção',
    Icons.blender_outlined,
    'Produzir agora (mise en place), agendar e ver a agenda',
    rotasExtra: [Routes.schedule],
  ),
  PaginaApp(
    'compras',
    Routes.shopping,
    'Compras',
    Icons.shopping_cart_outlined,
    'Lista de compras por fornecedor',
  ),
  PaginaApp(
    'inventario',
    Routes.inventory,
    'Inventário',
    Icons.warehouse_outlined,
    'Ingredientes, limpeza, material e embalagens',
  ),
  PaginaApp(
    'receitas',
    Routes.recipes,
    'Receitas',
    Icons.menu_book_outlined,
    'Massas, recheios, coberturas',
  ),
  PaginaApp(
    'fichas',
    Routes.techSheets,
    'Fichas Técnicas',
    Icons.receipt_long_outlined,
    'Custo, preço de venda e informação do produto',
  ),
  PaginaApp(
    'faturas',
    Routes.invoices,
    'Faturas',
    Icons.document_scanner_outlined,
    'Foto da fatura → preços e stock',
  ),
  PaginaApp(
    'vendas',
    Routes.sales,
    'Vendas',
    Icons.point_of_sale_outlined,
    'Registo de vendas e sabores mais vendidos',
  ),
  PaginaApp(
    'contagem',
    Routes.contagem,
    'Contagem diária',
    Icons.fact_check_outlined,
    'Assados, sobras e desperdício por local',
  ),
  PaginaApp(
    'haccp',
    Routes.haccp,
    'HACCP',
    Icons.health_and_safety_outlined,
    'Temperaturas, limpezas, pragas e extintor',
  ),
  PaginaApp(
    'quiosque',
    Routes.quiosque,
    'Quiosque de tarefas',
    Icons.touch_app_outlined,
    'Cartão NFC e um botão por tarefa diária',
  ),
  PaginaApp(
    'encomendas',
    Routes.encomendas,
    'Encomendas',
    Icons.assignment_outlined,
    'Pedidos dos clientes por data/hora',
  ),
  PaginaApp(
    'financeiro',
    Routes.painelFinanceiro,
    'Painel financeiro',
    Icons.insights_outlined,
    'Entradas, saídas e lucro por semana/mês',
  ),
  PaginaApp(
    'custosFixos',
    Routes.custosFixos,
    'Custos fixos',
    Icons.request_quote_outlined,
    'Aluguel, salários e outras despesas',
  ),
  PaginaApp(
    'equipamentos',
    Routes.equipamentos,
    'Equipamentos',
    Icons.kitchen_outlined,
    'Custo e depreciação mensal',
  ),
  PaginaApp(
    'numerosMagicos',
    Routes.numerosMagicos,
    'Números mágicos',
    Icons.calculate_outlined,
    'Venda mínima para cobrir tudo',
  ),
  PaginaApp(
    'configuracoes',
    Routes.settings,
    'Configurações',
    Icons.settings_outlined,
    'Empresa, aparência, custos',
  ),
  PaginaApp(
    'equipa',
    Routes.team,
    'Equipa',
    Icons.group_outlined,
    'Utilizadores e permissões',
  ),
];

/// Rodapé por omissão (o Início vem sempre à frente, não entra aqui).
const rodapePorOmissao = <String>[
  'producao',
  'contagem',
  'compras',
  'inventario',
];

/// Máximo de páginas no rodapé, sem contar o Início.
const rodapeMaximo = 5;

PaginaApp? paginaPorChave(String chave) {
  for (final p in paginasApp) {
    if (p.chave == chave) return p;
  }
  return null;
}

/// A página a que pertence um caminho (o mais específico ganha:
/// `/opcoes/equipa` é "Equipa", `/opcoes` é "Configurações"). `null` para o
/// Início e rotas fora do catálogo.
PaginaApp? paginaDaRota(String location) {
  PaginaApp? melhor;
  var melhorRota = '';
  for (final p in paginasApp) {
    for (final rota in [p.rota, ...p.rotasExtra]) {
      final bate = location == rota || location.startsWith('$rota/');
      if (bate && (melhor == null || rota.length > melhorRota.length)) {
        melhor = p;
        melhorRota = rota;
      }
    }
  }
  return melhor;
}
