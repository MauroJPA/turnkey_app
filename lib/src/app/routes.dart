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
  static const productionLotes = '/produzir/lotes';
  static const productionPrevisao = '/produzir/previsao';
  static const loteBase = '/lote';
  static String lote(String codigo) => '/lote/${Uri.encodeComponent(codigo)}';
  static const schedule = '/agenda';
  static const shopping = '/compras';
  static const comprasRelatorio = '/compras/relatorio';

  /// Inventário (secção Ingredientes) e as outras secções.
  static const inventory = '/inventario';
  static const inventoryLimpeza = '/inventario/limpeza';
  static const inventoryMaterial = '/inventario/material';
  static const inventoryEmbalagens = '/inventario/embalagens';
  static const inventoryPrecos = '/inventario/precos';
  static const invoices = '/faturas';
  static const sales = '/vendas';
  static const encomendas = '/encomendas';
  static const pessoas = '/pessoas';
  static const pessoasPonto = '/pessoas/ponto';
  static const pessoasFerias = '/pessoas/ferias';
  static const pessoasEscala = '/pessoas/escala';
  static const pessoasNotas = '/pessoas/notas';
  static const pessoasFormacoes = '/pessoas/formacoes';
  static const contagem = '/contagem';
  static const contagemRelatorios = '/contagem/relatorios';
  static const haccp = '/haccp';
  static const quiosque = '/quiosque';
  static const colaboradores = '/colaboradores';
  static const analiseVendas = '/vendas/analise';
  static const vendasNaoIdentificadas = '/vendas/nao-identificados';
  static const painelFinanceiro = '/financeiro';
  static const dre = '/financeiro/dre';
  static const custosFixos = '/financeiro/custos-fixos';
  static const equipamentos = '/financeiro/equipamentos';
  static const numerosMagicos = '/financeiro/numeros-magicos';
  static const relatorios = '/financeiro/relatorios';
  static const rentabilidade = '/financeiro/rentabilidade';
  static const tabelaRevendedores = '/financeiro/revendedores';
  static const embalagens = '/embalagens';
  static const consumiveis = '/consumiveis';
  static const settings = '/opcoes';
  static const team = '/opcoes/equipa';
  static const aprovacoes = '/opcoes/aprovacoes';
  static const avisos = '/opcoes/avisos';
  static const saudeDados = '/opcoes/dados';
  static const navegacao = '/opcoes/navegacao';
  static const opcoesEmpresa = '/opcoes/empresa';
  static const opcoesCustos = '/opcoes/custos';
  static const opcoesSeguranca = '/opcoes/seguranca';

  /// Antiga página "Produtos" (hoje: a informação do produto dentro da ficha).
  static const produtos = '/produtos';
  static String fichaInformacao(String id) => '/fichas-tecnicas/$id/informacao';
}
