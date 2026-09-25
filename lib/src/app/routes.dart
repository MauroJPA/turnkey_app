/// Nomes de rota centralizados (sem dependências de ecrãs, para poderem ser
/// usados em código puro e em testes).
abstract class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const onboarding = '/onboarding';
  static const pendente = '/pendente';
  static const home = '/';
  static const ingredients = '/ingredientes';
  static const recipes = '/receitas';
  static const techSheets = '/fichas-tecnicas';
  static const production = '/produzir';
  static const miseEnPlace = '/mise-en-place';
  static const schedule = '/agenda';
  static const shopping = '/compras';
  static const inventory = '/inventario';
  static const invoices = '/faturas';
  static const sales = '/vendas';
  static const encomendas = '/encomendas';
  static const analiseVendas = '/vendas/analise';
  static const painelFinanceiro = '/financeiro';
  static const dre = '/financeiro/dre';
  static const custosFixos = '/financeiro/custos-fixos';
  static const equipamentos = '/financeiro/equipamentos';
  static const numerosMagicos = '/financeiro/numeros-magicos';
  static const embalagens = '/embalagens';
  static const consumiveis = '/consumiveis';
  static const settings = '/opcoes';
  static const team = '/opcoes/equipa';
  static const cookieFormats = '/opcoes/formatos';
  static const navegacao = '/opcoes/navegacao';
  static const produtos = '/produtos';
}
