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
  miseEnPlace,
  agendar,
  agenda,
  planoDetalhe,
  compras,
  inventario,
  faturas,
  faturaRevisao,
  vendas,
  custosFixos,
  painelFinanceiro,
  dre,
  embalagens,
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
      'Faturas por rever: aparece quando há faturas (do scanner ou carregadas) à espera de confirmação. Toque para abrir.',
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
      'O ícone de nutrição em cada linha abre "Nutrição e alergénios": preenche à mão, escolhe da tabela INSA, ou envia uma foto do rótulo para a IA preencher. Depois a informação nutricional das receitas e fichas é calculada sozinha.',
      'Esse ícone diz logo o estado da nutrição (legenda em cima da lista): prato aberto/cinzento = sem nutrição; ⚖ (por rever) = a INSA automática ficou em dúvida; livro = valores da tabela INSA; lápis = preenchido à mão; máquina fotográfica = à mão com a foto da tabela nutricional anexada. Na folha de nutrição podes "Anexar foto (sem IA)" a qualquer momento como prova/referência.',
      'Nos produtos feitos pela Gookie, esse ícone abre a lista de ingredientes/subprodutos da receita — não se preenche à mão. Vais tocando em cada um até estar tudo com nutrição: os ingredientes comprados por INSA/foto/manual; os subprodutos Gookie abrem os seus próprios ingredientes, em cascata. O total do produto é calculado no fim.',
      'O botão ✨ no topo ("Preencher nutrição pela tabela INSA") percorre os ingredientes SEM nutrição e, quando encontra na tabela INSA um alimento claramente igual, preenche os valores e os alergénios. Os que ficam em dúvida ficam marcados "por rever" (ícone diferente) — abre cada um e escolhe da lista de alimentos parecidos. Confirma sempre: os alergénios da INSA são uma sugestão pelo nome.',
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
      'Ícone do prato: informação nutricional calculada (por 100 g), alergénios agregados, e a % de perda de peso na cozedura (concentra os valores por 100 g de produto).',
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
      'Ícone do prato: a Declaração Nutricional calculada (por 100 g e por unidade) + alergénios. Botão "Copiar" para colar num rótulo.',
    ],
  ),
  HelpTopic.produzir: (
    titulo: 'Produzir',
    paragrafos: [
      'Escolha uma receita e a quantidade em kg para ver quanto precisa de cada ingrediente. As quantidades são escaladas pela percentagem de cada ingrediente para dar exatamente os kg pedidos.',
      'Botão "Adicionar à agenda": escolhe se é um "Produto final" (cookie pronto, com formato/ficha técnica → conta unidades) ou um "Intermédio" (recheio, massa, base → entra em stock a granel em gramas). Depois a prioridade e a hora limite, e junta ao carrinho.',
      'Se já existir uma ficha técnica para essa massa, o recheio e as coberturas são preenchidos automaticamente.',
      'Quando tiver as receitas todas no carrinho, toque na barra em baixo para "Rever e agendar".',
    ],
  ),
  HelpTopic.miseEnPlace: (
    titulo: 'Mise en place',
    paragrafos: [
      'Página para produzir agora, sem agendar antes.',
      'Escolhe a receita e a quantidade em kg. Se for um produto final, escolhe o formato.',
      'Aparece a lista em caixas: "Produzir primeiro" (recheios/bases — carrega em "Abrir" para ver a receita, procedimento e imagens de cada um) e "Ingredientes" (com o que tens em stock; a vermelho quando falta).',
      'Botão "Procedimento e imagens" mostra o passo-a-passo da receita escolhida.',
      'Vai marcando as caixas à medida que preparas.',
      '"Produção feita" → pergunta se registas na Agenda (como concluída, dá baixa no stock) e se adicionas o que faltou à lista de compras.',
    ],
  ),
  HelpTopic.agendar: (
    titulo: 'Rever e agendar',
    paragrafos: [
      'Confirme as receitas que vai produzir.',
      'Escolha o dia e, se quiser, um título. Se deixar vazio, fica "Produção de hoje" (ou "Produção DD/MM/AAAA") com os nomes das receitas — e pode sempre editar depois.',
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
      'Marque a caixa quando comprar — a quantidade entra logo no inventário certo.',
      'Botão "+": primeiro escolhe se é um "Ingrediente" (escolhe da lista, quantidade em g/kg → entra no stock de ingredientes) ou "Material da loja" (equipamento, consumível, mobiliário, ferramenta, limpeza… — dá-lhe um nome, categoria, quantidade e unidade → entra no inventário "Outros"). Pode deixar uma nota.',
      'Menu (⋮): "Reorganizar lista" apaga os comprados e recalcula; "Limpar lista" apaga tudo. Ambos pedem confirmação.',
    ],
  ),
  HelpTopic.inventario: (
    titulo: 'Inventário',
    paragrafos: [
      'O stock de tudo: ingredientes (gramas), produtos acabados (unidades) e material da loja (na unidade que escolher).',
      'Dois separadores: "Cozinha" (ingredientes + produtos) e "Material da loja" — o inventário geral da loja: equipamentos, consumíveis, mobiliário, ferramentas… agrupado por categoria. O material que marca como comprado na lista de compras aparece aqui automaticamente.',
      'Botão "Material": adicionar qualquer coisa da empresa que não seja ingrediente nem produto — sabão, sacos de lixo, uma tesoura…',
      'Chips de vista: "Tudo", "Favoritos" (a estrela em cada linha fixa os itens que quer ver primeiro) e "Mais usados" (os que mais entram em produções ou na lista de compras).',
      'O triângulo de aviso aparece quando algo está abaixo do stock mínimo.',
      'Toque num item para dar entrada ou saída de stock e definir o mínimo.',
      'Toque e segure (ou toque, se não puder editar) para ver o histórico de movimentos.',
    ],
  ),
  HelpTopic.faturas: (
    titulo: 'Faturas',
    paragrafos: [
      'Guarda aqui as faturas de compra e as listas de preços dos fornecedores.',
      'Botão "Nova fatura": escolhes se é uma fatura ou uma lista de preços, o fornecedor, e o ficheiro — uma foto tirada com o telemóvel (JPG/PNG) ou um PDF.',
      'A seguir uma IA lê as linhas (produtos, quantidades, preços). Podes sempre corrigir antes de aplicar.',
      'Cada fatura é única: se carregares a mesma outra vez (mesmo fornecedor e número, ou mesma data e total), fica marcada como duplicada e não é aplicada.',
      'O ficheiro é guardado com o nome FT-FORNECEDOR-DDMMAAAA (a data da fatura), para organização e futura exportação para a contabilidade.',
      'As faturas ficam agrupadas por mês. Toca e mantém numa fatura para a apagar.',
      'O estado mostra: Nova, Analisada (IA leu), Confirmada (já aplicada) ou Erro.',
      'Ícone da pasta (canto superior): resumo do mês para a contabilidade — lista, total e "Copiar resumo (CSV)". O envio mensal por email é automático se estiver configurado no servidor.',
      'Se ligares um scanner à pasta configurada no servidor, as faturas entram sozinhas (aparecem como "Nova" com a nota "Scanner: …").',
    ],
  ),
  HelpTopic.faturaRevisao: (
    titulo: 'Rever fatura',
    paragrafos: [
      'Confere cada linha que a IA leu. A imagem da fatura fica visível (ao lado, em ecrã grande; por cima, no telemóvel — toca para ampliar; "Ocultar fatura" dá mais espaço às linhas). PDF abre à parte.',
      'Toca em "Ingrediente" para ligar a linha ao ingrediente certo (já vem pré-escolhido pelo nome mais parecido) ou escolhe "Criar ingrediente novo".',
      'Se o ingrediente da fatura é o mesmo que já tens com outro nome (ex.: a fatura diz "Limão cal 3/4" e tu tens "Limão siciliano"), marca "Passar a chamar-se…": o ingrediente é renomeado e a mudança aplica-se a todas as receitas e fichas que o usam.',
      '"Comprado" é a quantidade que entra no stock; "Preço embalagem" e "Embalagem" atualizam o preço por grama do ingrediente.',
      'Ação por linha: Preço (só atualiza o preço), Stock (só dá entrada), Preço + Stock, ou Ignorar.',
      'O preço só muda se esta fatura for igual ou mais recente do que a última atualização de preço desse ingrediente. Se carregares uma fatura antiga, a entrada de stock é feita à mesma, mas o preço mantém-se (fica sempre o do documento mais recente).',
      '"Aplicar aos ingredientes" grava tudo: os preços recalculam os custos das receitas e fichas em cascata.',
    ],
  ),
  HelpTopic.vendas: (
    titulo: 'Vendas',
    paragrafos: [
      'Regista aqui o que foi vendido — a base do painel financeiro, do DRE e da análise de sabores mais vendidos.',
      '"Registar venda": escolhe a data e adiciona linhas — um produto (ficha técnica, com o preço já sugerido) ou um item livre (texto), quantidade e preço.',
      'Ícone de importar (canto superior): carrega um ficheiro .csv com colunas data, produto, quantidade, preço. Cada linha é ligada automaticamente à ficha técnica com o nome mais parecido; sem correspondência clara, fica só com a descrição (aparece com um aviso na venda).',
      'Define o "Preço de venda" de cada produto na sua Ficha Técnica — fica disponível como sugestão ao registar vendas e mostra a margem sobre o custo.',
      'Toca numa venda para ver as linhas e, se precisares, apagá-la.',
    ],
  ),
  HelpTopic.custosFixos: (
    titulo: 'Custos fixos',
    paragrafos: [
      'Regista aqui os custos reais que saem todos os meses: aluguel, salários, seguros, subscrições, etc.',
      'Isto é diferente dos percentuais em Configurações → Percentuais de custo: aqueles só servem para sugerir o preço de venda a partir do custo de matéria-prima. Aqui é o valor real, para o painel financeiro e o DRE.',
      '"Fixo" ou "Variável": marca se o custo é sempre o mesmo (aluguel) ou varia com o volume (ex.: comissões).',
      'Arquivar mantém o histórico sem contar no total atual; só apagar remove por completo.',
    ],
  ),
  HelpTopic.painelFinanceiro: (
    titulo: 'Painel financeiro',
    paragrafos: [
      'Junta as Vendas e os Custos fixos num só sítio: quanto entrou, quanto saiu e o lucro, por semana ou mês.',
      '"Custo dos produtos vendidos" é o custo real da matéria-prima do que foi vendido (guardado em cada venda no momento em que foi registada).',
      '"Distribuição teórica" mostra, com as percentagens atuais de Configurações → Percentuais de custo, para onde o valor vendido deveria ir (matéria-prima, salário, aluguel...). É um modelo, não o dinheiro que saiu de verdade — isso são os Custos fixos, mostrados por cima.',
      'A seta ao lado de cada número compara com o período anterior de igual duração (ex.: esta semana vs. a semana passada).',
      'Se houver vendas sem produto identificado (ex.: de uma importação de CSV), o custo delas não é conhecido — aparece um aviso e o lucro fica sobrestimado nessa medida.',
    ],
  ),
  HelpTopic.dre: (
    titulo: 'DRE',
    paragrafos: [
      'DRE = Demonstração de Resultados do Exercício: o mesmo cálculo do painel financeiro, mas no formato de relatório clássico de contabilidade (receita → custo → lucro bruto → despesas → resultado).',
      'Escolhe o período (esta semana, este mês, mês passado) e toca no ícone de impressão para abrir uma versão simples para imprimir ou guardar como PDF.',
      'Se houver vendas sem produto identificado, o custo delas não entra no cálculo e aparece um aviso — o resultado fica sobrestimado nessa medida.',
    ],
  ),
  HelpTopic.embalagens: (
    titulo: 'Embalagens',
    paragrafos: [
      'Caixas, sacos, saquetas, adesivos, fita… — tudo o que embala o produto.',
      'Preço da compra + quantas peças vêm nessa compra → custo por peça.',
      '"Uma peça embala quantas unidades?": um saco embala 1; uma caixa de 6 embala 6. O custo por unidade de produto divide-se por esse número.',
      'Na ficha técnica, adiciona a embalagem como uma linha (tipo "Embalagem") e o custo entra no total do produto — sem afetar o peso nem a informação nutricional.',
      '"+" cria; toque edita; toque e segure apaga.',
      'Separador "Kits": junta várias embalagens numa combinação com nome (ex.: "Take-away" = 1 saqueta + 1 caixa + 1 saco + 2 adesivos). Na ficha técnica escolhes o kit para precificar tudo de uma vez. O custo do kit atualiza-se sozinho quando muda o preço de qualquer embalagem que o compõe.',
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
