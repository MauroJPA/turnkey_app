/// Texto de ajuda por página. Linguagem simples, sem jargão — o público-alvo
/// tem dificuldade com tecnologia.
library;

enum HelpTopic {
  dashboard,
  ingredientes,
  receitas,
  receitaDetalhe,
  fichas,
  fichaDetalhe,
  produzir,
  agendar,
  agenda,
  planoDetalhe,
  compras,
  inventario,
  formatos,
  configuracoes,
  equipa,
}

typedef HelpEntry = ({String titulo, List<String> paragrafos});

const Map<HelpTopic, HelpEntry> helpContent = {
  HelpTopic.dashboard: (
    titulo: 'Início',
    paragrafos: [
      'Esta é a página principal. Mostra o que precisa da sua atenção hoje.',
      'Stock baixo: quantos ingredientes ou produtos estão abaixo do mínimo. Toque para abrir o Inventário.',
      'Produções: quantas produções tem planeadas. Toque para abrir a Agenda.',
      'A comprar: quanto falta comprar e o valor estimado. Toque para abrir a Lista de compras.',
      'Em baixo tem os atalhos para todas as secções.',
    ],
  ),
  HelpTopic.ingredientes: (
    titulo: 'Ingredientes',
    paragrafos: [
      'Lista de tudo o que compra: farinha, manteiga, chocolate, etc.',
      'Cada ingrediente tem o preço, o peso da embalagem e o fornecedor.',
      'Use "+" para adicionar um ingrediente novo. Toque num ingrediente para editar.',
      'Pode importar muitos ingredientes de uma vez a partir de um ficheiro .csv.',
      'Quando muda o preço de um ingrediente, o custo das receitas e das fichas é recalculado sozinho.',
    ],
  ),
  HelpTopic.receitas: (
    titulo: 'Receitas',
    paragrafos: [
      'As suas massas, recheios e coberturas.',
      'Cada receita é feita de ingredientes (e pode usar outras receitas lá dentro).',
      'Use "+" para criar uma receita. Toque numa receita para ver os detalhes e o custo.',
      'O ícone do caixote do lixo mostra as receitas apagadas, que pode recuperar.',
    ],
  ),
  HelpTopic.receitaDetalhe: (
    titulo: 'Detalhe da receita',
    paragrafos: [
      'Aqui vê as linhas da receita (ingredientes e quantidades) e o custo total.',
      'Botão "Item": adiciona um ingrediente ou uma sub-receita.',
      'Toque numa linha para mudar a quantidade. Deslize para a esquerda para remover.',
      'Ícone do livro: escrever o passo-a-passo e juntar fotos.',
      'Ícone da agenda: enviar esta receita para produzir (vai para o carrinho da agenda).',
    ],
  ),
  HelpTopic.fichas: (
    titulo: 'Fichas técnicas',
    paragrafos: [
      'Uma ficha técnica é o produto final que vende — por exemplo "Cookie Boston".',
      'Junta uma massa, um recheio e/ou uma cobertura, e diz o peso de cada parte.',
      'Serve para saber o custo e o preço de venda sugerido, e para o stock de produto acabado.',
    ],
  ),
  HelpTopic.fichaDetalhe: (
    titulo: 'Detalhe da ficha técnica',
    paragrafos: [
      'Cada linha é uma parte do produto (massa, recheio, cobertura) com o peso.',
      'Em baixo vê o custo e o preço sugerido, calculado com os percentuais de Configurações.',
      'Ligue a ficha a um "Formato de cookie" para o stock de produto acabado ser calculado ao concluir uma produção.',
    ],
  ),
  HelpTopic.produzir: (
    titulo: 'Produzir',
    paragrafos: [
      'Escolha uma receita e a quantidade em kg para ver quanto precisa de cada ingrediente.',
      'Botão "Adicionar à agenda": escolhe o formato do cookie, o recheio (se levar), a prioridade e a hora limite, e junta ao carrinho.',
      'Quando tiver as receitas todas no carrinho, toque na barra em baixo para "Rever e agendar".',
    ],
  ),
  HelpTopic.agendar: (
    titulo: 'Rever e agendar',
    paragrafos: [
      'Confirme as receitas que vai produzir.',
      'Escolha o dia e (opcional) um título para esta produção.',
      'Toque em "Criar produção" para a guardar na Agenda.',
    ],
  ),
  HelpTopic.agenda: (
    titulo: 'Agenda de produção',
    paragrafos: [
      'As suas produções, agrupadas por dia.',
      'Cada cartão mostra quantas receitas tem, a hora mais cedo e o custo.',
      'Toque para abrir. Use "Nova produção" para começar uma do zero.',
    ],
  ),
  HelpTopic.planoDetalhe: (
    titulo: 'Detalhe da produção',
    paragrafos: [
      'Em cima: a data e o título (pode mudar).',
      'Receitas a produzir: cada linha com o formato, recheio, kg e unidades. Toque no nome para abrir a receita.',
      'Ingredientes necessários: o total já com o recheio incluído, e quantos sacos comprar.',
      '"Copiar relatório": copia um resumo em texto para colar onde quiser.',
      '"Adicionar à lista de compras": envia o que falta comprar para a Lista de compras.',
      '"Concluir produção": dá baixa dos ingredientes no stock e dá entrada dos produtos acabados. Pede confirmação.',
    ],
  ),
  HelpTopic.compras: (
    titulo: 'Lista de compras',
    paragrafos: [
      'O que precisa de comprar, agrupado por fornecedor.',
      'Cada linha mostra quantos sacos comprar, o peso da embalagem, quanto precisa e o preço estimado.',
      'Em cima vê o total esperado, o que já foi comprado e o que ainda falta.',
      'Marque a caixa quando comprar — se for um ingrediente, a quantidade entra logo no inventário.',
      'Botão "+": adicionar qualquer coisa (sacos de lixo, sabão, uma tesoura…) — escolhe a quantidade e a unidade (un, kg, caixa…) e pode deixar uma nota a explicar.',
      'Menu (⋮): "Reorganizar lista" apaga os comprados e recalcula; "Limpar lista" apaga tudo. Ambos pedem confirmação.',
    ],
  ),
  HelpTopic.inventario: (
    titulo: 'Inventário',
    paragrafos: [
      'O stock de tudo: ingredientes (em gramas) e produtos acabados (em unidades).',
      'O triângulo de aviso aparece quando algo está abaixo do stock mínimo.',
      'Toque num item para dar entrada ou saída de stock e definir o mínimo.',
      'Toque e segure (ou toque, se não puder editar) para ver o histórico de movimentos.',
    ],
  ),
  HelpTopic.formatos: (
    titulo: 'Formatos de cookie',
    paragrafos: [
      'Os tamanhos de cookie que faz — por exemplo Mini (20 g), Recheado (120 g de massa + 30 g de recheio) e Simples (150 g).',
      'São usados para calcular quantas unidades saem de X kg de massa e quanto recheio é preciso.',
      'Use "+" para criar. Toque para editar. O caixote do lixo remove (as produções antigas mantêm o valor guardado).',
    ],
  ),
  HelpTopic.configuracoes: (
    titulo: 'Configurações',
    paragrafos: [
      'Empresa: nome, moeda e regra de arredondamento.',
      'Aparência: modo claro/escuro, cor da app e logótipo. Aplica-se a toda a equipa.',
      'Percentuais de custo: salário, aluguer, impostos, etc. — usados para sugerir o preço de venda nas fichas técnicas.',
      'Formatos de cookie e Equipa têm páginas próprias, acessíveis aqui.',
    ],
  ),
  HelpTopic.equipa: (
    titulo: 'Equipa',
    paragrafos: [
      'As pessoas que podem entrar na app desta empresa.',
      'Cada uma tem um papel: Proprietário e Administrador podem mudar tudo; Editor cria e edita; Leitura só vê.',
      'Use "+" para convidar alguém. Toque num membro para mudar o papel.',
    ],
  ),
};
