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
  analiseVendas,
  encomendas,
  custosFixos,
  equipamentos,
  numerosMagicos,
  painelFinanceiro,
  dre,
  embalagens,
  consumiveis,
  produtos,
  formatos,
  categoriasReceita,
  configuracoes,
  navegacao,
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
      'Pagamentos por vir: custos fixos com "dia de pagamento" marcado, quando faltar uma semana ou menos. Toque para abrir Custos fixos.',
      'Encomendas por vir: encomendas que faltam menos horas do que o configurado em Encomendas. Toque para abrir a lista.',
      'Em baixo tem os atalhos para as secções. "Todas as páginas" abre a lista completa: aí pode esconder um atalho da grelha (só para si), mudar a cor de cada botão e abrir qualquer página — mesmo as que escondeu.',
      'As páginas do rodapé e as que cada pessoa pode ver ou editar são definidas em Configurações → Navegação e permissões.',
    ],
  ),
  HelpTopic.ingredientes: (
    titulo: 'Ingredientes',
    paragrafos: [
      'Lista de tudo o que compra: farinha, manteiga, chocolate, etc.',
      'Cada ingrediente tem o preço, o peso da embalagem e o fornecedor.',
      'Use "+" para adicionar um ingrediente novo. Toque num ingrediente para editar.',
      'Pode importar muitos ingredientes de uma vez a partir de um ficheiro .csv.',
      'Ao criar um ingrediente pode já preencher a informação nutricional e os alergénios (opcional): à mão, escolhendo da tabela INSA, ou com a foto do rótulo (a IA lê e preenche — confira sempre). Deslize um ingrediente para a esquerda para o mover para a lixeira.',
      'O ícone de nutrição em cada linha abre "Nutrição e alergénios": preenche à mão, escolhe da tabela INSA, ou envia uma foto do rótulo para a IA preencher. Depois a informação nutricional das receitas e fichas é calculada sozinha.',
      'Esse ícone diz logo o estado da nutrição (legenda em cima da lista): prato aberto/cinzento = sem nutrição; ⚖ (por rever) = a INSA automática ficou em dúvida; livro = valores da tabela INSA; lápis = preenchido à mão; máquina fotográfica = à mão com a foto da tabela nutricional anexada. Na folha de nutrição podes "Anexar foto (sem IA)" a qualquer momento como prova/referência.',
      'Nos produtos de fabrico próprio, esse ícone abre a lista de ingredientes/subprodutos da receita — não se preenche à mão. Vais tocando em cada um até estar tudo com nutrição: os ingredientes comprados por INSA/foto/manual; os subprodutos Gookie abrem os seus próprios ingredientes, em cascata. O total do produto é calculado no fim.',
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
      'O ícone de carregar ficheiro importa receitas: cola o texto copiado da folha de cálculo (ou escolhe um CSV) com uma linha por ingrediente — nome da receita, categoria, ingrediente, quantidade em gramas. Os ingredientes sem correspondência ficam pendentes na receita, para ligares depois. Receitas com nome que já existe são ignoradas.',
      'Ao criar uma receita pode já escrever o procedimento e anexar imagens (opcional).',
      'Deslize uma receita para a esquerda para a mover para a lixeira. O ícone do caixote do lixo mostra as receitas apagadas, que pode recuperar.',
    ],
  ),
  HelpTopic.receitaDetalhe: (
    titulo: 'Detalhe da receita',
    paragrafos: [
      'Aqui vê as linhas da receita (ingredientes e quantidades) e o custo total.',
      'Botão "Item": adiciona um ingrediente ou uma sub-receita.',
      'Toque numa linha para mudar a quantidade. Deslize para a esquerda para remover.',
      'Ícone do livro: ver e editar o passo-a-passo ("Editar") e as fotos (toca numa foto para ver, substituir ou remover).',
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
      'Na lista, cada ficha mostra os dois preços: "sugerido" (calculado a partir do custo e dos Percentuais de custo) e "venda" (o preço real que praticas). Toca no preço de venda para o editar sem precisar de abrir a ficha.',
    ],
  ),
  HelpTopic.fichaDetalhe: (
    titulo: 'Detalhe da ficha técnica',
    paragrafos: [
      'Cada linha é uma parte do produto (massa, recheio, cobertura) com o peso.',
      'Em baixo vê o custo e o preço sugerido, calculado com os percentuais de Configurações.',
      'Ligue a ficha a um "Formato de cookie" para o stock de produto acabado ser calculado ao concluir uma produção.',
      'CMV esperado: a parte do preço que sobra para a matéria-prima, segundo os Percentuais de custo (ex. 25 %). CMV real: quanto o custo é do preço de venda que praticas (custo ÷ preço). Se o real for maior que o esperado, aparece a vermelho — o preço está baixo para o custo. Em "Quebra do preço" vê cada rubrica (matéria-prima, salário, aluguel, margem…) com valor e % no preço esperado e no real; no real a margem de lucro é o que sobra.',
      'Ícone do prato: a Declaração Nutricional calculada (por 100 g e por unidade) + alergénios. Botão "Copiar" para colar num rótulo.',
    ],
  ),
  HelpTopic.produzir: (
    titulo: 'Produzir',
    paragrafos: [
      'Escolha o que produzir: um PRODUTO FINAL das fichas técnicas (Boston, Provença…) ou uma receita (massa, recheio, base).',
      'Produto final: indique as unidades. Aparece o mise en place — "Produzir primeiro" (a massa, os recheios e as coberturas, com as gramas de cada um) e os ingredientes a pesar. "Abrir" mostra a receita de cada intermédio.',
      'Receita: indique os kg para ver quanto precisa de cada ingrediente. As quantidades são escaladas pela percentagem de cada ingrediente para dar exatamente os kg pedidos.',
      'Botão "Adicionar à agenda": num produto final só escolhe a prioridade e a hora limite (as unidades e a massa já estão calculadas). Numa receita escolhe se é "Produto final" (com formato/ficha técnica → conta unidades) ou "Intermédio" (recheio, massa, base → entra em stock a granel em gramas).',
      'Se já existir uma ficha técnica para essa massa, o recheio e as coberturas são preenchidos automaticamente.',
      'Quando tiver as receitas todas no carrinho, toque na barra em baixo para "Rever e agendar".',
    ],
  ),
  HelpTopic.miseEnPlace: (
    titulo: 'Mise en place',
    paragrafos: [
      'Página para produzir agora, sem agendar antes.',
      'Escolhe o produto: um produto final das fichas técnicas (indicas as unidades) ou uma receita (indicas os kg; se for produto final, escolhe o formato).',
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
      'Ícone da nuvem (canto superior): sincroniza com o Vendus — traz as vendas novas desde a última vez, emparelhadas automaticamente com as fichas técnicas pelo nome. Só funciona se a chave do Vendus estiver configurada no servidor; se houver linhas sem correspondência, aparece um aviso no resumo.',
      '"Reimportar histórico (escolher data)" (no mesmo ícone da nuvem): volta a pedir ao Vendus as vendas num intervalo de datas à escolha (desde/até), em vez de continuar de onde a última sincronização ficou — útil para trazer vendas mais antigas que ainda não estão na app.',
      '"Registar venda": escolhe a data e adiciona linhas — um produto (ficha técnica, com o preço já sugerido) ou um item livre (texto), quantidade e preço.',
      'Ícone de importar (canto superior): carrega um ficheiro .csv com colunas data, produto, quantidade, preço. Cada linha é ligada automaticamente à ficha técnica com o nome mais parecido; sem correspondência clara, fica só com a descrição (aparece com um aviso na venda).',
      'Define o "Preço de venda" de cada produto na sua Ficha Técnica — fica disponível como sugestão ao registar vendas e mostra a margem sobre o custo.',
      'Toca numa venda para ver as linhas e, se precisares, apagá-la.',
    ],
  ),
  HelpTopic.analiseVendas: (
    titulo: 'Análise de vendas',
    paragrafos: [
      'Mostra o que se vendeu por sabor/produto (ficha técnica) no período escolhido: quantidade, receita e a margem real (com base no custo guardado em cada venda, não no custo atual).',
      '"Mais vendido" é o que teve mais unidades; "Maior margem" é o que deu mais lucro por cada euro vendido — não são sempre o mesmo produto.',
      'A seta ao lado de cada linha compara a quantidade vendida com o período anterior de igual duração — sobe ou desce a dizer se aquele sabor está a vender mais ou menos.',
      '"Sem produto identificado" junta as linhas de venda que não foram ligadas a nenhuma ficha técnica (ex.: de uma importação de CSV sem correspondência) — não têm margem calculada.',
    ],
  ),
  HelpTopic.encomendas: (
    titulo: 'Encomendas',
    paragrafos: [
      'Regista aqui os pedidos dos clientes para uma data e hora específicas — diferente das Vendas, que é o registo do que já foi vendido/pago.',
      'Cada encomenda tem produtos (fichas técnicas) com quantidade, e passa pelos estados Nova → Em produção → Pronta → Entregue (ou Cancelada, em qualquer altura).',
      '"Encomendas por vir" no Início destaca as que faltam menos horas do que o configurado (ícone de engrenagem em Encomendas) — fica vermelho quando falta menos de 1 hora.',
      'Ícone de impressora no detalhe da encomenda: abre o talão para imprimir na fábrica, com a data/hora bem grande para não passar ao lado. O tamanho do talão (térmico 80mm ou A4) e se deve imprimir sozinho ao criar também se configuram ali.',
      'Sem impressora na fábrica? A lista de encomendas em si já serve — abre bem num tablet.',
      'O "Valor total" é sugerido automaticamente a partir do preço de venda das fichas técnicas escolhidas, mas pode ser editado ou deixado em branco. "Registar pagamento" guarda quanto já foi pago — a encomenda mostra Por pagar/Pago parcialmente/Pago, e isso também aparece no talão impresso (que acompanha a encomenda até ao cliente).',
      'Menu (⋮) no detalhe da encomenda: Editar (cliente, data/hora, produtos, valor), Registar pagamento, Cancelar ou Apagar.',
    ],
  ),
  HelpTopic.custosFixos: (
    titulo: 'Custos fixos',
    paragrafos: [
      'Regista aqui os custos reais que saem todos os meses: aluguel, salários, seguros, subscrições, etc.',
      'Isto é diferente dos percentuais em Configurações → Percentuais de custo: aqueles só servem para sugerir o preço de venda a partir do custo de matéria-prima. Aqui é o valor real, para o painel financeiro e o DRE.',
      '"Fixo" ou "Variável": marca se o custo é sempre o mesmo (aluguel) ou varia com o volume (ex.: comissões).',
      '"Dia de pagamento" (opcional): o dia do mês em que pagas este custo. Se estiver preenchido, aparece um aviso "Pagamentos por vir" no Início quando faltar uma semana ou menos.',
      'Ícone de nuvem/upload (canto superior): importa vários custos de uma vez a partir de um ficheiro .csv com as colunas nome, valor mensal e (opcional) dia de pagamento.',
      'Ícone da panela (canto superior): abre "Equipamentos", onde regista o forno, o balcão, os computadores… — a depreciação mensal deles entra automaticamente aqui como despesa, sem precisar de criar um custo fixo à parte.',
      'Arquivar mantém o histórico sem contar no total atual; só apagar remove por completo.',
    ],
  ),
  HelpTopic.equipamentos: (
    titulo: 'Equipamentos',
    paragrafos: [
      'Cada peça de equipamento da loja (forno, balcão, computador, vitrine…) com o preço de compra e a vida útil em anos.',
      'A "depreciação mensal" é o preço de compra dividido pela vida útil em meses — é o desgaste do equipamento, em euros por mês. Soma-se automaticamente ao painel financeiro, ao DRE e aos Números mágicos como despesa, sem precisar de a registar outra vez em Custos fixos.',
      'Ícone de upload (canto superior): importa vários equipamentos de uma vez a partir de um ficheiro .csv com as colunas nome, custo e vida útil (anos).',
      'Não é preciso substituir nada quando o equipamento acaba a vida útil — arquiva-o e cria o novo, se for o caso.',
    ],
  ),
  HelpTopic.numerosMagicos: (
    titulo: 'Números mágicos',
    paragrafos: [
      'Mostra a partir de quanto vendido, por mês (e por dia), tudo já está pago — custos fixos, variáveis, depreciação dos equipamentos, imposto e o custo da matéria-prima (CMV). Tudo o que vender a mais disso é lucro.',
      'Os percentuais de Imposto e CMV vêm de Configurações → Percentuais de custo — muda-os lá se precisares.',
      'A "venda mínima" é sempre um valor mensal cheio; o cartão de baixo compara com o que já vendeste no período escolhido (semana/mês), para veres se estás perto ou longe do objetivo.',
      'Se o aviso de percentuais aparecer, é porque Imposto + CMV somam 100% ou mais — nesse caso não há venda que cubra os custos só com esses dois; revê os valores em Configurações.',
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
  HelpTopic.produtos: (
    titulo: 'Produtos',
    paragrafos: [
      'Aqui está tudo o que a tua empresa produz (os produtos finais das fichas técnicas), com a informação pronta para o cliente: declaração nutricional, lista de ingredientes e alergénios.',
      'O ícone à esquerda diz se a nutrição está completa (visto) ou se falta alguma coisa (aviso). Toque num produto para ver os pormenores.',
      'A lista de ingredientes segue as regras da UE: por ordem decrescente de peso e com os alergénios a negrito. É calculada sozinha a partir da ficha técnica, das receitas e dos ingredientes.',
      '"Falta completar" mostra o que ainda não está preenchido: nutrição de algum ingrediente, descrição, prazo de validade e modo de conservação. "Corrigir a nutrição" leva-o ao ingrediente em falta; "Preencher os dados" abre a ficha.',
      'O ícone de copiar junta tudo num texto. A impressão de etiquetas (completa e resumida) vem a seguir.',
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
  HelpTopic.consumiveis: (
    titulo: 'Limpeza e insumos',
    paragrafos: [
      'Produtos de limpeza, desinfeção e outros insumos que não entram nas receitas mas exigem documentação.',
      'Em cada produto anexas a ficha de dados de segurança (FDS) que o fornecedor te dá, a ficha técnica e certificados. Ficam organizados e abrem com um toque, prontos para uma fiscalização.',
      'O estado mostra "Falta FDS" se o produto exige a ficha e não tem nenhuma, e "FDS antiga" quando a última tem mais de 3 anos (pede ao fornecedor a versão mais recente, se existir).',
      'O filtro "A precisar de FDS" lista só o que falta tratar. O ícone de copiar junta o registo de todos os produtos (CSV) para colar numa folha de cálculo.',
      'Nas faturas, as linhas de limpeza/insumos podem ser ligadas a estes produtos: o preço fica registado e, se já tiverem documentos, não é preciso pedi-los outra vez.',
    ],
  ),
  HelpTopic.formatos: (
    titulo: 'Formatos de cookie',
    paragrafos: [
      'Os tamanhos de cookie que faz — por exemplo Mini (20 g), Recheado (120 g de massa + 30 g de recheio) e Simples (150 g).',
      'São usados para calcular quantas unidades saem de X kg de massa e quanto recheio é preciso.',
      'Use "+" para criar. Toque para editar. O caixote do lixo remove (as produções antigas mantêm o valor guardado).',
      'Onde se usam: em cada Ficha Técnica escolhe-se o formato do produto (Mini, Recheado…); em Produzir escolhe-se o formato para calcular quantas unidades saem e quanto recheio é preciso; ao concluir a produção o stock do produto sobe em unidades.',
    ],
  ),
  HelpTopic.categoriasReceita: (
    titulo: 'Categorias de receitas',
    paragrafos: [
      'As categorias que agrupam as tuas receitas (ex.: Massa, Recheio, Cobertura) — servem para organizar e filtrar a lista de Receitas.',
      'Use "+" para criar uma categoria nova, toque para renomear ou desativar, e o caixote do lixo remove (as receitas que já a usavam mantêm o nome guardado, só deixa de aparecer para escolher em receitas novas).',
      'Uma categoria "Inativa" continua a aparecer nas receitas que já a têm, mas não entra na lista para escolher numa receita nova.',
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
  HelpTopic.navegacao: (
    titulo: 'Navegação e permissões',
    paragrafos: [
      'Rodapé: escolha que páginas aparecem na barra de baixo (até 5, além do Início) e a ordem. Proprietário e Administrador podem mudar.',
      'Permissões: só o Proprietário. Para cada nível (Administrador, Editor, Leitura) e cada página, escolha Oculto (a página desaparece e não abre), Só ver (vê mas não altera) ou Editar.',
      'O Proprietário tem sempre acesso a tudo. As permissões escondem e bloqueiam na app; os dados continuam protegidos pelo papel de cada pessoa.',
      'Cada pessoa pode ainda esconder atalhos e mudar as cores da grelha do Início, em "Todas as páginas" — isso é só para si.',
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
