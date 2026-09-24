import 'package:flutter/material.dart';

import '../../../app/routes.dart';

/// Uma página (ou grupo de páginas) da app que pode ir no rodapé, na grelha
/// do Início e ter permissões próprias por papel.
class PaginaApp {
  const PaginaApp(this.chave, this.rota, this.label, this.icon, this.descricao);

  /// Identificador estável, guardado na configuração (nunca muda).
  final String chave;
  final String rota;
  final String label;
  final IconData icon;
  final String descricao;
}

/// Chave do Início: está sempre disponível e sempre primeiro no rodapé.
const chaveInicio = 'inicio';

const paginasApp = <PaginaApp>[
  PaginaApp('mise', Routes.miseEnPlace, 'Mise en place', Icons.checklist_rtl,
      'Produzir agora, passo a passo'),
  PaginaApp('producao', Routes.production, 'Produzir', Icons.blender_outlined,
      'Carrinho de produção'),
  PaginaApp('agenda', Routes.schedule, 'Agenda', Icons.event_note_outlined,
      'Plano de produções'),
  PaginaApp('compras', Routes.shopping, 'Compras',
      Icons.shopping_cart_outlined, 'Lista de compras por fornecedor'),
  PaginaApp('inventario', Routes.inventory, 'Inventário',
      Icons.warehouse_outlined, 'Stock e movimentos'),
  PaginaApp('ingredientes', Routes.ingredients, 'Ingredientes',
      Icons.egg_alt_outlined, 'Preços e fornecedores'),
  PaginaApp('receitas', Routes.recipes, 'Receitas', Icons.menu_book_outlined,
      'Massas, recheios, coberturas'),
  PaginaApp('fichas', Routes.techSheets, 'Fichas Técnicas',
      Icons.receipt_long_outlined, 'Produtos e preço de venda'),
  PaginaApp('faturas', Routes.invoices, 'Faturas',
      Icons.document_scanner_outlined, 'Foto da fatura → preços e stock'),
  PaginaApp('vendas', Routes.sales, 'Vendas', Icons.point_of_sale_outlined,
      'Registo de vendas e sabores mais vendidos'),
  PaginaApp('encomendas', Routes.encomendas, 'Encomendas',
      Icons.assignment_outlined, 'Pedidos dos clientes por data/hora'),
  PaginaApp('financeiro', Routes.painelFinanceiro, 'Painel financeiro',
      Icons.insights_outlined, 'Entradas, saídas e lucro por semana/mês'),
  PaginaApp('custosFixos', Routes.custosFixos, 'Custos fixos',
      Icons.request_quote_outlined, 'Aluguel, salários e outras despesas'),
  PaginaApp('equipamentos', Routes.equipamentos, 'Equipamentos',
      Icons.kitchen_outlined, 'Custo e depreciação mensal'),
  PaginaApp('numerosMagicos', Routes.numerosMagicos, 'Números mágicos',
      Icons.calculate_outlined, 'Venda mínima para cobrir tudo'),
  PaginaApp('embalagens', Routes.embalagens, 'Embalagens',
      Icons.inventory_2_outlined, 'Caixas, sacos, adesivos e o seu custo'),
  PaginaApp('formatos', Routes.cookieFormats, 'Formatos de cookie',
      Icons.cookie_outlined, 'Tamanhos e recheio por unidade'),
  PaginaApp('configuracoes', Routes.settings, 'Configurações',
      Icons.settings_outlined, 'Empresa, aparência, custos'),
  PaginaApp('equipa', Routes.team, 'Equipa', Icons.group_outlined,
      'Utilizadores e permissões'),
];

/// Rodapé por omissão (o Início vem sempre à frente, não entra aqui).
const rodapePorOmissao = <String>[
  'mise',
  'producao',
  'agenda',
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
  for (final p in paginasApp) {
    final bate = location == p.rota || location.startsWith('${p.rota}/');
    if (bate && (melhor == null || p.rota.length > melhor.rota.length)) {
      melhor = p;
    }
  }
  return melhor;
}
