# Checklist de testes — gc_turnkey

Percorre esta lista na app (login `ana@teste.local`). Para cada ponto marca
`[x]` se está OK, ou escreve a seguir o que queres ajustar. Reinicia o
PocketBase (`pb\serve.ps1`) e faz hot-restart do `flutter run` (tecla **R**)
antes de começar, para carregar as últimas migrations (há **43**; a última é
`1707696000_ficha_rotulo.js`).

**Índice de páginas** (uma secção por página): 0 Arranque · 1 Início ·
2 Aparência · 3 Formatos · 4 Ingredientes · 5 Receitas · 6 Fichas · 7 Produzir ·
8 Agenda · 9 Compras · 10 Inventário · 11 Ciclo completo · 12 Mise en place ·
13 Faturas · 14 Nutrição · 15 Embalagens · **16 Vendas · 17 Análise de vendas ·
18 Encomendas · 19 Custos fixos · 20 Equipamentos · 21 Números mágicos ·
22 Painel financeiro · 23 DRE · 24 Configurações (empresa/percentuais) ·
25 Equipa · 26 Navegação e permissões · 27 Produtos · 28 Segurança · 29 Faturas em lote**.

**Limites conhecidos do teste automático** (verifica sempre à mão): tudo o que
abre o **seletor de ficheiros** (importar CSV por ficheiro, escolher imagem) e a
**impressão do talão** (janela de impressão do browser).

---

## 0. Arranque e navegação

- [ ] Login com email/palavra-passe entra no **Início**.
- [ ] O ecrã de login **não** mostra "Continuar com Apple" (só Google).
- [ ] O **rodapé** (Início · Mise · Produzir · Agenda · Compras · Inventário)
      aparece em **todas** as páginas, incluindo detalhes (receita, ficha,
      produção, encomenda, venda, configurações).
- [ ] Tocar em cada aba do rodapé abre a secção certa.
- [ ] **Todas as páginas** têm a **seta ←** no canto superior esquerdo (as abas do
      rodapé voltam ao Início; os detalhes voltam à lista respetiva).
- [ ] O botão **?** (canto superior direito) existe em todas as páginas e abre
      uma explicação clara.
- [ ] Ao lado do **?** há o ícone de **sugestão/erro**: abre um campo de nota,
      "Enviar" grava (mensagem "Obrigado! Sugestão enviada.").

## 1. Início (painel)

- [ ] Cartão **Stock baixo** mostra um número e abre o Inventário.
- [ ] Cartão **Produções por fazer** mostra um número e abre a Agenda.
- [ ] Cartão **A comprar** mostra nº + € estimado e abre a Lista de compras.
- [ ] Aparecem, só quando há algo a mostrar: **Faturas por rever**, **Pagamentos
      por vir** (custo fixo com dia de pagamento a ≤ 7 dias) e **Encomendas por
      vir** (vermelho a menos de 1 h). Cada um abre a página certa.
- [ ] Grelha "Tudo" abre, uma a uma: Ingredientes · Receitas · Fichas Técnicas ·
      Faturas · Vendas · Encomendas · Painel financeiro · Custos fixos ·
      Equipamentos · Números mágicos · Embalagens · Formatos de cookie ·
      Configurações · Equipa.
- [ ] Logótipo da empresa e nome aparecem no topo (depois de o carregares no
      ponto 2).
- [ ] Menu do utilizador → **Terminar sessão** volta ao login.

## 2. Configurações → Aparência

- [ ] Trocar **Modo** para Escuro muda a app toda; Claro volta; Automático
      segue o sistema.
- [ ] As **5 cores** aplicam a cor da app ao tocar.
- [ ] "Avançado" mostra o campo de cor `#RRGGBB` e aceita uma cor à mão.
- [ ] **Logótipo**: "Escolher imagem" carrega; a pré-visualização aparece;
      "Remover" apaga.
- [ ] "Guardar aparência" grava; ao recarregar a app o tema/cor/logo mantêm-se.
- [ ] Estas definições aplicam-se a toda a equipa (não são por dispositivo).

## 3. Configurações → Formatos de cookie

> Onde se usam: escolhem-se em cada **Ficha técnica** (campo Formato), em
> **Produzir** (define unidades e recheio por unidade) e ao **concluir a
> produção** (o stock do produto sobe em unidades).

- [ ] Aparecem **Mini** (20 g), **Recheado** (120 g + 30 g), **Simples** (150 g).
- [ ] "+" cria um formato novo (nome, massa g, recheio g).
- [ ] Tocar edita; o **ícone do caixote do lixo** remove (com confirmação).
- [ ] Um formato marcado como inativo deixa de aparecer nos seletores.

## 4. Ingredientes

- [ ] A lista mostra os ~166 ingredientes com preço/fornecedor.
- [ ] "+" adiciona; tocar edita; importar .csv funciona.
- [ ] **Novo ingrediente com nutrição**: no formulário, "Informação nutricional
      (opcional)" abre os campos (por 100 g / 100 ml): energia, lípidos,
      saturados, hidratos, açúcares, fibra, proteína, sal, e os alergénios
      ("Contém"). Ao adicionar, o ícone de nutrição da lista fica "à mão" e os
      alergénios aparecem. Sem preencher nada, o ingrediente cria-se como antes.
      A caixa "Abrir a folha completa depois" abre a folha de nutrição (INSA,
      foto do rótulo) logo a seguir.
  - [ ] **Escolher da tabela INSA** (dentro dessa secção): abre a pesquisa já com
        o nome escrito; ao escolher, preenche os valores e os alergénios (a
        confirmar) e o ingrediente fica com a nutrição "da tabela INSA".
  - [ ] **Foto do rótulo (preencher com IA)**: escolhe a foto/PDF → "Rótulo
        lido" preenche os campos (conferir!) e a foto fica anexada ao
        ingrediente. Sem chave da IA no servidor mostra "IA não configurada"
        (só à mão — seletor de ficheiros; precisa de `GEMINI_API_KEY`).
- [ ] **Deslizar para a esquerda** num ingrediente pede confirmação e o item
      **desaparece logo**, sem ecrã de erro vermelho (o mesmo em Receitas,
      Fichas técnicas e nas linhas de uma receita).
- [ ] Mudar o preço de um ingrediente recalcula o custo nas receitas e fichas.

## 5. Receitas

- [ ] Lista com pesquisa e filtro por categoria; lixeira acessível.
- [ ] **Nova receita** ("+"): em "Procedimento e imagens (opcional)" escreve-se o
      procedimento (um passo por linha) e "**Anexar imagens**" junta fotos (com
      miniaturas e ✕ para tirar) — tudo opcional. Depois de criar, a receita
      abre já com o procedimento e as imagens (ícone do livro). Na edição
      (lápis) só o procedimento; as imagens gerem-se no ícone do livro.
- [ ] Abrir uma receita mostra as linhas e o custo.
- [ ] Botão 📖 **Procedimento e imagens**: aparece a folha com os passos e as
      fotos.
  - [ ] "**Editar**" ao lado do título "Procedimento" abre o campo de texto (um
        passo por linha) → **Guardar** grava e a folha mostra os passos; sem
        passos aparece "Sem passos.". Não é preciso editar a receita.
  - [ ] Tocar numa **foto** abre o menu **Ver em grande / Substituir / Remover**
        (Remover pede confirmação; Substituir escolhe outra imagem).
  - [ ] "Adicionar imagem" junta fotos novas.
  - [ ] Com o papel **Leitura**: sem "Editar", e a foto só amplia.
- [ ] Botão 📅 **Agendar produção** abre a folha de adicionar à agenda para
      essa receita.
- [ ] **Importar receitas** (ícone de upload no topo da lista):
  - [ ] Colar (Ctrl+V) uma tabela do Excel/Sheets com colunas
        `nome ⇥ categoria ⇥ ingrediente ⇥ quantidade(g)` — **uma linha por
        ingrediente**; ex.: `Massa_Normandia ⇥ Massas ⇥ Manteiga ⇥ 191` →
        "Importar" cria a receita com todas as linhas.
  - [ ] Também aceita `;` e `,` como separador, cabeçalho opcional
        (`nome;categoria;ingredientes;quantidade`), "4 g" e "200,5".
  - [ ] Ingrediente com nome parecido é ligado sozinho (ignora acentos e
        maiúsculas); sem correspondência **fica pendente** (a receita mostra a
        linha para ligares) e o resumo avisa.
  - [ ] Receita com nome que já existe é **ignorada** e o resumo diz porquê.
  - [ ] Linhas inválidas (poucas colunas, quantidade ≤ 0) aparecem nos erros sem
        travar as outras.
  - [ ] **Escolher ficheiro CSV** preenche a caixa de texto (só à mão).
  - [ ] O ícone **não aparece** na lixeira nem com papel Leitura.

## 6. Fichas técnicas

- [ ] Lista de fichas; abrir mostra as partes (massa/recheio/cobertura) e o
      preço sugerido.
- [ ] **Preço de venda editável**: na lista, cada ficha mostra "sugerido €X" e
      "**venda €Y** ✎"; tocar no "venda" abre "Preço de venda — nome" → Guardar.
      No detalhe, o cartão "Preço de venda" mostra a **margem %** sobre o custo.
      O preço fica como sugestão nas Vendas e Encomendas. Com papel Leitura o
      "venda" não é editável (sem ✎).
- [ ] **CMV** no detalhe da ficha: dois valores — **CMV esperado** (o que sobra
      para a matéria-prima nos Percentuais de custo; ex. 25,0 %) e **CMV real**
      (custo ÷ preço de venda praticado; ex. custo 0,63 € e venda 2,00 € =
      31,1 %). O real fica **a vermelho** quando passa o esperado e mostra
      "defina o preço" sem preço de venda.
- [ ] **Quebra do preço** (abrir): tabela com as colunas **Esperado** e **Real**;
      cada linha (Matéria-prima, Salário, Aluguel, Impostos, Serviços, Despesas
      fixas, Taxas, Margem de lucro) mostra o **valor e a %**. Esperado = preço
      sugerido pelos percentuais; Real = preço de venda praticado (matéria-prima
      = custo verdadeiro, rubricas com o mesmo %, **margem = o que sobra**; fica a
      vermelho se negativa). Última linha PREÇO FINAL (sugerido / venda). Sem
      preço de venda a coluna Real mostra "—".
- [ ] **Dados do produto** na ficha (editar/criar): **Descrição** (curta, para a
      etiqueta), **Validade (dias)** e **Conservação** — ficam gravados e
      aparecem na página Produtos.
- [ ] Campo **Formato do cookie** (ao criar/editar a ficha, lista Mini/Recheado/
      Simples… ou "Sem formato") → aparece na lista e no detalhe ("Formato: …").
      Serve para a produção encontrar a ficha certa: massa + recheio + formato.
- [ ] Para o ponto 8 funcionar, confirma que a ficha do produto (ex. "Gookie -
      Rio") tem: slot massa = a massa, slot recheio = o recheio, e o formato.

## 7. Produzir → carrinho → Agenda

- [ ] O seletor "O que vais produzir?" mostra primeiro os **produtos finais** das
      fichas técnicas (ex. Boston, Boston Gigante, Provença) e, por baixo, o
      atalho **Receitas**.
- [ ] **Produto final**: indicar as **unidades** (não kg) → aparece "N un · X kg de
      massa", **Produzir primeiro** (a **massa** primeiro, depois recheios e
      coberturas com as gramas de cada um; "Abrir" abre a receita) e
      **Ingredientes** (com o stock). Conferir à mão: massa por unidade da ficha ×
      unidades, recheio/topo por unidade × unidades.
- [ ] "Adicionar à agenda" (produto final) só pede prioridade e hora limite; no
      carrinho aparece o nome do produto e "Produto final"; a produção mostra
      o produto (não a massa) e o mise en place "por receita" correto.
- [ ] Ao **concluir** a produção, o stock do **produto** sobe pelas unidades certas
      (ex. Boston Gigante: 1 kg de massa ÷ 200 g = 5 un).
- [ ] O seletor **Receitas** continua a funcionar como antes (kg → árvore de
      ingredientes; "Adicionar à agenda" com formato/recheio).
- [ ] Escolher receita + kg mostra a árvore com as quantidades escaladas.
- [ ] **Verificar a escala**: pedir 4 kg de uma massa → a **soma dos
      ingredientes dá 4 kg** (proporção de cada um mantida).
- [ ] "Adicionar à agenda" → folha com:
  - [ ] Toggle **Produto final / Intermédio**.
  - [ ] **Produto final**: escolher formato; se houver ficha técnica para essa
        massa, mostra a composição (recheios/coberturas) e **esconde** o
        seletor de recheio manual; mostra "≈ N unidades".
  - [ ] **Intermédio**: só kg; texto "entra em stock a granel (g)".
  - [ ] Prioridade (Alta/Média/Baixa) e hora limite.
- [ ] Ao adicionar, o aviso no fundo tem o botão **"Ver produção"** que abre
      "Rever e agendar".
- [ ] Adicionar **2+ receitas** → barra inferior "N receitas para agendar".
- [ ] "Rever e agendar":
  - [ ] Campo de título mostra a **pré-visão** do título por omissão.
  - [ ] Deixar o título vazio → a produção fica **"Produção de hoje - Nome1,
        Nome2"** (ou "Produção DD/MM/AAAA - …").
  - [ ] "Criar produção" abre o detalhe da produção.

## 8. Agenda / Detalhe da produção

- [ ] A lista agrupa por dia; cada cartão resume nº receitas / hora / custo e
      marca prioridade alta.
- [ ] No detalhe: data e título **editáveis** (o título muda e fica guardado).
- [ ] Cada linha mostra formato · recheio · kg · ~un · prioridade · hora.
- [ ] Tocar no **nome da receita** abre a receita; "voltar" regressa ao plano.
- [ ] Secção **"Mise en place — por receita"**: para cada receita mostra
  - [ ] "Produzir primeiro" (intermédios: recheios/bases + gramas), quando os há;
  - [ ] "Ingredientes" com as quantidades **daquela** receita.
- [ ] Secção **"Ingredientes necessários (total)"**: soma de todas as receitas,
      com stock, "N sacos" e custo.
- [ ] **Copiar relatório**: o texto tem o mise en place por receita **e** os
      totais.
- [ ] **Adicionar à lista de compras**: se já foi adicionado, aparece o pop-up
      "Já foi adicionado… adicionar de novo?".
- [ ] **Concluir produção**: pré-visão (produzir / consumir) → confirmar →
      resumo (consumos, saídas, avisos).

## 9. Lista de compras

- [ ] Agrupada por fornecedor.
- [ ] Cada linha: **"N nome"** + "(Embalagem de X — Precisamos de Y)" + preço.
- [ ] Unidades automáticas: `< 1000 g` em gramas, `≥ 1000 g` em kg (`1,2 kg`).
- [ ] Cabeçalho: **Total esperado / Já comprado / Em falta**.
- [ ] **Só ingredientes** — os produtos/intermédios (Gookie, Massa, Brigadeiro)
      **não** aparecem aqui.
- [ ] Marcar a caixa de um ingrediente: entra no Inventário (ver ponto 10).
- [ ] Botão **"+"** → primeiro o seletor **Ingrediente / Material da loja**:
  - [ ] **Ingrediente**: pesquisa e escolhe da lista, quantidade em **g ou kg**;
        ao dar o visto entra no stock de **ingredientes**;
  - [ ] **Material da loja**: nome + **Categoria** (Consumível / Limpeza /
        Equipamento / Mobiliário / Ferramenta / Outro) + quantidade + unidade +
        fornecedor + nota. A linha mostra "categoria · …"; ao dar o visto entra
        no inventário **"Outros"** com essa categoria (ver ponto 10).
- [ ] Menu **⋮**: "Reorganizar lista" (remove comprados + recalcula) e
      "Limpar lista" (apaga tudo) — ambos pedem confirmação.

## 10. Inventário

- [ ] Chips: Tudo / Ingredientes / Produtos / **Outros**.
- [ ] Ingredientes em g/kg, produtos em unidades.
- [ ] No chip "Outros" cada item mostra a **categoria** no subtítulo; pesquisar
      por "equipamento", "faca", etc. encontra-os.
- [ ] Ícone de aviso quando abaixo do mínimo.
- [ ] Tocar num item → folha de ajuste: Entrada/Saída, **motivo por omissão**
      (Entrada→Compra, Saída→Venda), notas, mínimo.
- [ ] Toque longo (ou toque, se leitura) → histórico de movimentos.
- [ ] Botão **"Item livre"**: nome + **categoria** + quantidade + unidade +
      mínimo + localização → aparece com o chip "Outros".
- [ ] Um "Material da loja" comprado na lista de compras aparece aqui em
      "Outros" com a categoria certa e um movimento de **Compra** no histórico.

## 11. Fim a fim (o ciclo todo)

- [ ] Produzir "Gookie - Rio" (final, formato Recheado) + a sua massa como
      **intermédio** → agendar.
- [ ] No detalhe: mise en place mostra a massa e o recheio a produzir primeiro,
      e os ingredientes por receita.
- [ ] Lista de compras só tem ingredientes crus; marcar alguns como comprados.
- [ ] Inventário sobe nesses ingredientes.
- [ ] Concluir a produção → Inventário: ingredientes descem, o produto final
      sobe em unidades (ou aviso se faltar a ficha).

## 12. Mise en place (produzir agora)

- [ ] Aba **Mise** no rodapé e botão "Mise en place — produzir agora" no Início.
- [ ] Escolher **produto final** (ficha técnica) + **unidades** mostra as caixas:
      "Produzir primeiro" com a **massa**, os **recheios** e as **coberturas**, e
      os ingredientes; o campo Formato desaparece (vem da ficha).
- [ ] "Produção feita" num produto final regista a produção com o nome do produto
      e credita as unidades no stock.
- [ ] Escolher receita + kg (+ formato p/ produto final) mostra as caixas.
- [ ] Seção **"Produzir primeiro"** lista os intermédios (recheios/bases);
      botão **"Abrir"** abre o mise en place desse intermédio (com o seu
      procedimento e imagens).
- [ ] Seção **"Ingredientes"**: caixas grandes, a vermelho quando falta stock.
- [ ] **"Procedimento e imagens desta receita"** abre o passo-a-passo.
- [ ] **"Produção feita"** → pop-ups: (1) itens por marcar? (2) registar na
      agenda + baixa no stock? (3) faltou stock → adicionar à lista de compras?
- [ ] No fim: resumo (consumos/entradas/avisos) + "Ver na agenda" abre o plano
      conclído.

## 13. Faturas (foto → preços e stock)

> Pré-requisito no servidor: `GC_TURNKEY_AI_PROVIDER` (por omissão `gemini`) e a
> chave desse provider — `GEMINI_API_KEY` (grátis, <https://aistudio.google.com/app/apikey>)
> ou `ANTHROPIC_API_KEY` — em `pb/.env` (ver `pb/DEPLOY.md`). Sem a chave, o
> passo "analisar" mostra **"IA não configurada"** — o resto da página funciona.

- [ ] Cartão **Faturas** na grelha "Tudo" do Início abre a página.
- [ ] A aba tem o **?** e o ícone de sugestão; o rodapé aparece.
- [ ] Sem faturas: aparece o estado vazio a explicar "Nova fatura".
- [ ] Botão **"Nova fatura"**:
  - [ ] pergunta o **tipo** (Fatura / Lista de preços);
  - [ ] pede o **fornecedor** (ex. "Makro");
  - [ ] abre o seletor de ficheiro (**foto do telemóvel JPG/PNG ou PDF**); ao
        escolher, mostra "A analisar a fatura…".
- [ ] Testar com um **PDF** e com uma **foto** — ambos analisam; no ecrã de
      revisão o PDF mostra o ícone "Abrir PDF" e a foto mostra a miniatura.
- [ ] Depois da análise a fatura abre no **ecrã de revisão** com o estado
      **"Analisada"** (ou **"Erro"** com a mensagem, se a IA falhar).
- [ ] No ecrã de revisão:
  - [ ] a **imagem da fatura fica visível** enquanto conferes: ao **lado** das
        linhas em ecrã largo (janela ≥ 820 px), **por cima** no telemóvel
        (toca para ampliar; "Ocultar fatura" recolhe). PDF → botão "Abrir PDF";
  - [ ] cada **linha** mostra a descrição lida pela IA;
  - [ ] o **ingrediente** vem pré-escolhido pelo nome mais parecido; tocar
        abre a pesquisa para corrigir;
  - [ ] no cimo da pesquisa há **"Criar ingrediente novo «…»"** → a linha passa
        a mostrar um campo de nome editável e cria o ingrediente ao aplicar
        (com o fornecedor da fatura, o preço e a embalagem da linha);
  - [ ] quando o ingrediente ligado tem nome diferente da fatura, aparece
        **"Passar «X» a chamar-se «Y»"** → ao aplicar renomeia o ingrediente
        (e as receitas/fichas que o usam passam a mostrar o nome novo);
  - [ ] campos **Comprado (g)**, **Preço embalagem**, **Embalagem (g)** editáveis;
  - [ ] **Ação** por linha: Preço / Stock / Preço + Stock / Ignorar
        (numa *lista de preços* só há Preço / Ignorar e não há quantidade).
- [ ] **"Aplicar aos ingredientes"**: pede confirmação (diz quantos novos /
      renomeados), depois mostra o resumo e volta à lista.
- [ ] **Renomear**: exemplo — fatura "Limão cal 3/4", ingrediente guardado
      "Limão siciliano", marca a caixa, aplica → abre uma receita que usava
      "Limão siciliano" e confirma que agora diz "Limão cal 3/4".
- [ ] A fatura fica com o estado **"Confirmada"** e agrupada pelo **mês**.
- [ ] **Duplicada**: carrega a **mesma** fatura outra vez → depois da análise fica
      em **"Erro"** a dizer "Fatura duplicada", com botões **"Abrir a original"**
      e **"Apagar fatura"**.
- [ ] **Nome do ficheiro**: no `/export` (ou no armazenamento) o ficheiro segue
      `FT-FORNECEDOR-DDMMAAAA` com a **data da fatura** (não a data de hoje).
- [ ] **Apagar**: toca e mantém numa fatura na lista → confirma → desaparece.
- [ ] **Verificar o efeito**:
  - [ ] Ingredientes: o preço das linhas com Preço/Ambos mudou (e o custo das
        receitas/fichas recalculou em cascata);
  - [ ] Inventário: as linhas com Stock/Ambos deram **entrada** (motivo
        "Compra", nota "Fatura nº…").
- [ ] **Fatura antiga**: carrega uma fatura com **data anterior** à última
      atualização de preço de um ingrediente → ao aplicar, o diálogo avisa
      "X preço(s) NÃO vão mudar"; depois de aplicar, o **preço mantém-se** mas a
      **entrada de stock é feita** (a mensagem final diz "X preço(s) mantidos").
- [ ] Re-analisar uma fatura já analisada volta a chamar a IA (repete o custo).
- [ ] **Scanner (se configurado)**: pôr um PDF na pasta `GC_TURNKEY_SCAN_DIR` →
      em ≤ 5 min aparece uma fatura "Nova" com nota "Scanner: …" e o original
      passa para `processadas/`. O painel inicial mostra "Faturas por rever".
- [ ] **Contabilidade**: em Faturas, o ícone da pasta abre o resumo do mês
      anterior (lista + total + "Copiar resumo (CSV)"); cada linha abre o
      ficheiro. Com `GC_TURNKEY_CONTAB_EMAIL` + SMTP, o dia 1 envia o pacote por
      email.

## 14. Nutrição e alergénios

- [ ] Na lista de **Ingredientes**, cada linha tem um ícone de prato (cheio se
      já tem valores). Abre a folha "Nutrição e alergénios".
- [ ] **Tabela INSA**: pesquisar (ex.: "açúcar", "farinha de trigo") mostra
      resultados da INSA BDCA; escolher preenche os 8 valores.
- [ ] **Foto do rótulo**: escolher uma foto da tabela nutricional → preenche
      (precisa da `GEMINI_API_KEY` no servidor; sem ela dá "IA não configurada").
- [ ] Editar valores + marcar alergénios (Contém / Pode conter) → **Guardar**.
      Os alergénios aparecem no subtítulo da lista.
- [ ] Numa **receita** que use esse ingrediente: ícone do prato → painel
      "Informação nutricional (por 100 g)" com os valores somados e os
      alergénios agregados. Se algum ingrediente não tiver dados, avisa
      "valores incompletos — sem dados de: …".
- [ ] Na receita, definir **perda de peso na cozedura** (ex.: 12 %) → a coluna
      "cozido" aparece com os valores concentrados.
- [ ] Numa **ficha técnica**: ícone do prato → **Declaração Nutricional** por
      100 g e por unidade + "Contém: …" / "Pode conter: …". Botão **"Copiar"**.
- [ ] Mudar a nutrição de um ingrediente recalcula receitas e fichas em cascata
      (como o custo).

## 15. Embalagens

- [ ] Início → **Embalagens**. "+" cria: nome, tipo, **preço da compra**,
      **peças na compra**, **"1 peça embala N unidades"**, fornecedor. A prévia
      mostra o **custo por unidade de produto**.
- [ ] Ex.: Caixa de 6, pacote de 100 caixas a 120 € → 1,20 €/caixa →
      **0,20 €/unidade**. A lista mostra esse valor.
- [ ] Numa **ficha técnica**: a secção **"Embalagem"** tem "Adicionar" → só
      mostra embalagens → pergunta **"Peças por unidade de produto"** (normal 1).
- [ ] A linha aparece como "N pç · €X" (sem gramas nem %). O **custo da ficha
      sobe** por esse valor; o **peso do produto NÃO muda**.
- [ ] Mudar o preço da embalagem → o custo de todas as fichas que a usam
      recalcula sozinho.
- [ ] Toque e segure numa embalagem apaga (com confirmação).
- [ ] Separador **Kits**: criar um kit (ex.: "Take-away" = saqueta + caixa + saco
      + 2 adesivos) mostra o custo somado; mudar o preço de uma embalagem
      atualiza o custo do kit; na ficha técnica dá para escolher o **kit**.

## 16. Vendas

- [ ] Início → **Vendas** abre a lista (rodapé, **?** e sugestão presentes).
- [ ] Sem vendas: estado vazio; com vendas: lista por dia com total.
- [ ] **Registar venda**: escolher a **data**; adicionar linhas —
  - [ ] **Produto (ficha técnica)**: o preço vem **sugerido** do preço de venda
        da ficha;
  - [ ] **Item livre**: texto + quantidade + preço;
  - [ ] o botão remover tira uma linha; sem linhas dá "Ainda sem produtos.
        Adiciona pelo menos um."
- [ ] Guardar → a venda aparece na lista; tocar abre o **detalhe** com as linhas
      (ficha/descrição, quantidade, preço) e o total.
- [ ] **Apagar** (ícone no detalhe) pede confirmação e a venda desaparece.
- [ ] **Importar CSV** (colunas `data, produto, quantidade, preço`): cada linha
      liga à ficha de nome mais parecido; sem correspondência fica só com a
      descrição e mostra aviso (só à mão — seletor de ficheiros).
- [ ] **Sincronizar com o Vendus** (nuvem): traz as vendas novas, emparelhadas
      com as fichas pelo nome; o resumo avisa das linhas sem correspondência.
      Sem chave no servidor mostra uma mensagem clara (nunca um erro de rede
      em bruto nem a chave/URL).
- [ ] Nuvem → **Reimportar histórico (escolher data)**: pede desde/até e traz as
      vendas desse intervalo sem duplicar as que já existem.
- [ ] Ícone **Análise de vendas** abre a secção 17.
- [ ] Com papel **Leitura**: sem "Registar venda", sem apagar, sem importar.

## 17. Análise de vendas

- [ ] Escolher período (semana / mês / …) atualiza a tabela.
- [ ] Cada linha: sabor/produto, **quantidade**, **receita** e **margem real**
      (custo guardado na venda, não o custo atual).
- [ ] Destaques **Mais vendido** e **Maior margem** (podem ser produtos
      diferentes).
- [ ] A **seta** compara a quantidade com o período anterior de igual duração.
- [ ] "**Sem produto identificado**" junta linhas sem ficha (sem margem).
- [ ] Sem vendas no período: estado vazio, sem erro.

## 18. Encomendas

- [ ] Início → **Encomendas** abre a lista (rodapé, **?**, sugestão).
- [ ] **Nova encomenda**: cliente, data **e hora**, produtos (fichas) com
      quantidade, valor total **sugerido** (soma dos preços de venda; editável
      ou vazio) e notas → aparece na lista ordenada por data/hora.
- [ ] Cartão da lista mostra estado (Nova/Em produção/Pronta/Entregue/Cancelada)
      e estado de **pagamento** (Por pagar / Pago parcialmente / Pago) só se o
      valor foi informado.
- [ ] **Detalhe**: cliente, data/hora, produtos, cartão **Pagamento** (sem o
      ecrã ficar em branco).
  - [ ] "**Registar pagamento**" guarda quanto foi pago; o estado passa a
        Pago parcialmente → Pago; com pagamento total o botão desaparece.
  - [ ] Avançar estado: Nova → Em produção → Pronta → Entregue.
  - [ ] Menu **⋮**: Editar · Registar pagamento · Cancelar · Apagar (Apagar e
        Cancelar pedem confirmação).
        *(Nota: "Cancelar encomenda" continua a aparecer mesmo em encomendas já
        canceladas/entregues — inofensivo; diz-me se queres que esconda.)*
- [ ] **Talão** (impressora): abre o talão com **data/hora grandes**, produtos,
      valor e estado de pagamento (só à mão — janela de impressão).
- [ ] Engrenagem **Configurar talão e avisos**: tamanho do talão (80 mm / A4),
      imprimir ao criar, e horas de antecedência para "Encomendas por vir".
- [ ] Início: "Encomendas por vir" conta as que faltam menos horas do que o
      configurado e fica **vermelho** a menos de 1 h.
- [ ] Papel **Leitura**: só consulta.

## 19. Custos fixos

- [ ] Início → **Custos fixos** (rodapé, **?**, sugestão).
- [ ] "+" cria: nome, **valor mensal**, **Fixo/Variável**, **dia de pagamento**
      (opcional); o total mensal no topo soma só os ativos.
- [ ] Tocar edita; **Arquivar** tira do total mas mantém o histórico; Apagar
      remove por completo (com confirmação).
- [ ] Custo com dia de pagamento a ≤ 7 dias aparece em **"Pagamentos por vir"**
      no Início.
- [ ] Ícone de **importar CSV** (`nome, valor mensal, dia de pagamento`
      opcional) cria vários de uma vez e mostra o resumo (só à mão).
- [ ] Ícone da **panela** abre Equipamentos (secção 20).

## 20. Equipamentos

- [ ] Início → **Equipamentos** (rodapé, **?**, sugestão).
- [ ] "+" cria: nome, **custo de compra**, **vida útil (anos)**; a
      **depreciação mensal** = custo ÷ (anos × 12) aparece na linha
      (ex.: 2400 € a 5 anos → 40 €/mês).
- [ ] Editar recalcula; **Arquivar** deixa de contar.
- [ ] A depreciação **soma-se sozinha** nos Números mágicos, Painel financeiro e
      DRE (não é preciso criar um custo fixo à parte).
- [ ] **Importar CSV** (`nome, custo, vida útil (anos)`) (só à mão).

## 21. Números mágicos

- [ ] Mostra **venda mínima mensal** e **por dia** que cobre custos fixos,
      variáveis, depreciação, imposto e CMV.
- [ ] Conferir à mão: mudar um custo fixo ou um equipamento altera o número.
- [ ] Imposto e CMV vêm de Configurações → Percentuais de custo; mudar lá
      altera aqui.
- [ ] Cartão de baixo compara com o vendido no período (semana/mês).
- [ ] Se Imposto + CMV ≥ 100 % aparece o **aviso de percentuais** em vez de um
      número absurdo.

## 22. Painel financeiro

- [ ] Início → **Painel financeiro** (rodapé, **?**, sugestão).
- [ ] Alternar **semana / mês** muda entradas, saídas e lucro.
- [ ] **Entradas** = vendas do período; **saídas** = custos fixos +
      depreciação; **Custo dos produtos vendidos** = custo guardado nas vendas.
- [ ] As **setas** comparam com o período anterior de igual duração.
- [ ] "**Distribuição teórica**" segue os percentuais de Configurações.
- [ ] Aviso quando há vendas **sem produto identificado** (lucro sobrestimado).
- [ ] Ícone **Ver DRE** abre a secção 23.

## 23. DRE

- [ ] Períodos: esta semana / este mês / mês passado.
- [ ] Estrutura: receita → custo → lucro bruto → despesas → resultado; os
      valores batem certo com o Painel financeiro para o mesmo período.
- [ ] Ícone de **impressão** abre a versão simples (só à mão — janela de
      impressão/PDF).
- [ ] Aviso de vendas sem produto identificado.

## 24. Configurações (empresa e percentuais)

- [ ] **Empresa**: nome, **moeda** e regra de arredondamento ("Para cima" /
      "Normal") → "Guardar empresa"; os preços em toda a app passam a seguir.
- [ ] **Percentuais de custo** (salário, aluguer, impostos, CMV…) →
      "Guardar percentuais"; o preço **sugerido** das fichas muda.
- [ ] Aparência e Formatos: ver secções 2 e 3.
- [ ] Com papel que não é admin aparece "Só administradores podem alterar estas
      definições." e os campos ficam bloqueados.

## 25. Equipa

- [ ] Início → **Equipa** (ou Configurações → Equipa): lista de membros com
      papel.
- [ ] **Adicionar**: email/nome/papel → o membro aparece na lista.
- [ ] Tocar num membro abre "Papel de …" e permite mudar o papel
      (Proprietário/Administrador/Editor/Leitura).
- [ ] Entrar com um utilizador **Leitura**: só vê — sem botões de criar/editar/
      apagar nas restantes páginas (Receitas, Fichas, Vendas, Encomendas…).

## 26. Navegação e permissões (Configurações → Navegação e permissões)

- [ ] Configurações mostra a linha **Navegação e permissões** (só Proprietário e
      Administrador).
- [ ] Aba **Rodapé**: tirar (−) e juntar (+) páginas, **arrastar** para mudar a
      ordem (máx. 5 além do Início; cheio desativa o +), **Guardar rodapé** →
      a barra de baixo muda logo. "Repor o rodapé original" repõe as 5 de origem.
- [ ] Aba **Permissões** (só Proprietário; o Administrador vê o aviso): escolher
      **Administrador / Editor / Leitura** e, por página, **Oculto / Só ver /
      Editar** (Leitura não tem "Editar"). Grava logo.
- [ ] Entrar com o **Editor**: página **Oculta** some do rodapé, da grelha e da
      lista "Todas as páginas"; abrir o link direto mostra "Não tens acesso a
      esta página." com botão para o Início. Cartões do Início dessas páginas
      (ex. "A comprar") também desaparecem.
- [ ] Página em **Só ver**: abre, mas sem botões de criar/editar/apagar/importar
      (mesmo para o Editor).
- [ ] O **Proprietário** nunca perde acesso, seja qual for a matriz.
- [ ] No **Início**, "**Todas as páginas**": lista tudo o que a pessoa pode abrir
      (inclusive o escondido); o **olho** esconde/mostra o botão na grelha (só
      para a própria pessoa) e a **paleta** muda a cor do botão (10 cores +
      "Cor padrão"). Depois de esconder, a página continua na lista.
- [ ] As preferências (escondidos e cores) ficam guardadas ao sair e voltar a
      entrar, e não afetam outras pessoas.
- [ ] Um utilizador não consegue alterar as permissões por API (só o Proprietário;
      o Administrador só o rodapé).

## 27. Produtos

- [ ] Início → **Produtos** (cartão na grelha; também na lista "Todas as
      páginas") abre a lista (seta ←, **?**, rodapé).
- [ ] Cada produto (ficha técnica) mostra: ícone **visto** se a nutrição está
      completa ou **aviso** se falta; categoria, formato, peso por unidade,
      validade, alergénios ("Contém: …") e o que **falta** ("Sem descrição · Sem
      prazo de validade · …").
- [ ] Pesquisa por nome e o filtro **"Só os que faltam completar"**.
- [ ] Abrir um produto: **descrição**, chips (formato, g por unidade, validade),
      **conservação**, **Declaração nutricional** (por 100 g e por unidade,
      energia em kJ/kcal), **Ingredientes** e **Alergénios**.
- [ ] **Ingredientes: Completa / Resumida**. Completa = nome de cada ingrediente tal
      como está (marca, %, "congelado"). Resumida = nomes curtos e genéricos, com
      variantes juntas (ex. `Açucar amarelo e branco`, `Limão`, `Ovos`); o campo
      **"Nome na etiqueta resumida"** do ingrediente manda sobre o nome deduzido.
- [ ] **Descrição é opcional**: sem descrição não aparece como falta. **Conservação**
      é uma **seleção** (Local fresco e seco · Refrigerado · Fresco e seco ou
      refrigerado · Congelado · Outro…).
- [ ] Aviso "Valores médios de referência, aproximados" por baixo da tabela.
- [ ] **Lista de ingredientes** por **ordem decrescente de peso**, ingredientes
      compostos "desmontados" até aos ingredientes base, e os **alergénios a
      negrito em MAIÚSCULAS** entre parênteses (ex. `Manteiga (LEITE)`).
      Conferir à mão com a receita: o de maior peso vem primeiro.
- [ ] Cartão **"Falta completar"** só aparece se houver pendências; **Corrigir a
      nutrição** abre a declaração e leva ao ingrediente em falta;
      **Preencher os dados** abre a ficha (descrição, validade, conservação).
      Depois de guardar, o cartão some.
- [ ] Ícone **copiar**: copia nome, descrição, ingredientes, alergénios,
      conservação, validade e a declaração nutricional em texto.
- [ ] Ícone do lápis (só quem pode editar) abre a ficha.
- [ ] Com o papel **Leitura**: vê tudo mas não edita. Uma página oculta em
      Navegação e permissões desaparece.
- [ ] Ícone da **impressora** no produto abre **Etiqueta**. Aviso vermelho enquanto faltar
      o **produtor** (e o que faltar na ficha).
- [ ] Alternar **Completa/Resumida** e **Tabela/Linear/Nenhuma**; alterar data de fabrico
      (o lote acompanha), expressão da data, nº de etiquetas, altura, ℮.
- [ ] Escrever o produtor e **Guardar como predefinição** (só o proprietário): abrir outra
      vez e vem preenchido.
- [ ] **Pré-visualizar e imprimir** abre um separador (permitir pop-ups): etiqueta ampliada,
      aviso a vermelho se não couber, botão Imprimir. No diálogo: papel **50 × 80 mm**,
      margens nenhumas, escala 100 %. Uma etiqueta por página.
- [ ] Alterar **Largura / Frente / Parte de baixo**: o cartão mostra o **mínimo recomendado** para o
      produto; a vermelho se o tamanho escolhido for pequeno; **Usar o mínimo** preenche os campos.
- [ ] Ingrediente cujo nome já tem o alergénio (ex.: "Leite condensado", "Ovo líquido"): aparece
      **LEITE** condensado / **OVO** líquido a negrito, sem "(LEITE)" a seguir.
- [ ] Desligar **Imprimir as datas**: "Fabrico" sai com uma **linha em branco** para escrever à
      caneta e por baixo "Validade: X dias após a data de fabrico" (sem "consumir de preferência").
- [ ] **Definições guardadas por produto:** escolher Resumida/Linear/datas em branco/tamanhos e
      carregar em **Pré-visualizar e imprimir**; fechar e abrir outra vez a Etiqueta **do mesmo
      produto**: vem com as mesmas definições. Outro produto continua com as suas (ou os
      predefinidos). Data, lote e nº de etiquetas **não** ficam guardados. (Papel Leitura
      imprime, mas não guarda.)
- [ ] **Lote** vem vazio (não imprime); se escreveres um, aparece na etiqueta.
- [ ] Peso líquido aparece **na frente**; datas, lote e produtor na parte de baixo; sem ℮ se
      o interruptor estiver desligado.

## 28. Segurança: aprovação de registos e integrações

- [ ] Criar uma conta nova (Registar): ao entrar aparece **"A tua conta aguarda aprovação"**
      (não o ecrã de criar empresa). "Verificar novamente" mantém-se nesse ecrã; "Sair" volta ao login.
- [ ] No painel `/_/` (superutilizador) → **users** → marcar **aprovado** nessa conta →
      "Verificar novamente" leva ao ecrã **A tua empresa**.
- [ ] Configurações → **Integrações**: guardar um token; aparece "Token guardado (termina em …)"
      e o token **não** volta a aparecer. Substituir e Remover funcionam. O papel Editor não vê
      esta opção.
- [ ] Vendas → **Sincronizar com o Vendus** usa o token guardado (com token real). Sem token dá a
      mensagem "indica o token em Configurações → Integrações".
- [ ] Abrir uma **fatura** (imagem e PDF): abre normalmente (o ficheiro agora pede um token).

## 29. Faturas: vários documentos no mesmo PDF

- [ ] Carregar Fatura **sem preencher o fornecedor**: a IA lê-o; a fatura fica com o fornecedor certo.
- [ ] Digitalizar num só **PDF várias faturas** (de fornecedores diferentes e também duas do mesmo fornecedor com
      datas/números diferentes): no fim aparece "N faturas detetadas neste ficheiro" e a lista mostra **uma por
      documento**, cada uma com as **suas páginas** (abrir o PDF de cada uma e confirmar).
- [ ] Uma fatura de 2 páginas seguidas continua a ser **uma só** fatura (2 páginas no mesmo ficheiro).
- [ ] Carregar outra vez o mesmo PDF: as faturas já existentes ficam como **duplicadas** (não se criam repetidas).
- [ ] Se a IA responder "sobrecarregada", o ecrã de erro tem **Tentar de novo**; passados uns minutos funciona.

## 30. Ingredientes genéricos e produtos de compra

- [ ] Abrir um ingrediente comprado: aparece **Produtos de compra** com um produto (criado da migração) e o
      chip "custo atual". O preço/embalagem do ingrediente são só de leitura.
- [ ] **Adicionar produto** (outra marca, outra embalagem, preço diferente): o custo do ingrediente passa a ser
      o do produto com a data mais recente. Editar o preço do outro produto (data de hoje) inverte.
- [ ] Apagar o produto mais recente: o custo volta ao anterior.
- [ ] Carregar uma fatura com "Açúcar Sidul BCO granulado KG": a linha vem ligada a "Açúcar branco" (ou
      propõe **criar ingrediente genérico** com esse nome) e mostra a **Marca** lida.
- [ ] Aplicar: o preço fica num **produto** (novo, se a marca/embalagem for nova) e o ingrediente assume o custo.
- [ ] Fatura com "2 un" de uma embalagem de 15 g: o campo **Comprado** mostra 2 **un** ("= 30 g"); trocar para
      **g** mostra 30. Ao aplicar, o stock sobe 30 g. Uma linha em kg ou g continua em **g**.
- [ ] Carregar outra fatura com o **mesmo texto**: liga sozinha ao mesmo produto ("Produto já conhecido").
- [ ] Fatura com data **anterior** à última compra: aparece o aviso e o custo não muda.
- [ ] Criar ingrediente novo pela revisão de uma fatura só com "Preço": fica **um só** produto (sem duplicado).
- [ ] Criar/editar um ingrediente comprado com preço e embalagem (sem produtos): cria-se logo o 1.º produto.
- [ ] Importar ingredientes por CSV: continuam a aparecer com custo e ficam com um produto.

## 31. Limpeza e insumos e fichas de segurança

- [ ] Início → **Limpeza e insumos** abre a página (aparece também em Configurações → Navegação, com permissões).
- [ ] **+ Produto**: criar "Desengordurante" (Limpeza). Guardar; passa a mostrar **Documentos** e "Falta FDS".
- [ ] **+ Produto** e, ainda antes de guardar, **Anexar documento** (FDS em PDF): fica na lista do produto novo;
      ao **Guardar** o documento segue e aparece em Documentos, com "FDS ok".
- [ ] Na lista, o ícone do **caixote** apaga o produto (pede confirmação) e ele desaparece.
- [ ] **Anexar documento** → tipo FDS, ficheiro PDF, data e versão: aparece na lista; o estado passa a "FDS ok".
      Tocar no documento abre o PDF. Anexar também uma imagem (ficha técnica) e um ficheiro `.html` (tem de ser recusado).
- [ ] Anexar uma FDS com data de há mais de 3 anos: estado "FDS antiga" com o aviso.
- [ ] Um produto "Luvas" (Insumo, sem FDS exigida) mostra "Sem FDS" e nunca fica pendente.
- [ ] Filtros: pesquisa, categoria e **A precisar de FDS**. O ícone de copiar o registo cola um CSV completo.
- [ ] Apagar um documento (pede confirmação); apagar um produto (some da lista).
- [ ] Papel Leitura: vê e abre os documentos, mas não vê "+ Produto", "Anexar" nem apagar.
- [ ] **Fatura** com um produto de limpeza (ex.: detergente da loiça): a IA marca a linha como "Limpeza / insumo".
      Se já existir o produto, liga-se e mostra os documentos já anexados; se não, propõe "Criar produto novo".
- [ ] Trocar uma linha entre "Ingrediente" e "Limpeza / insumo": volta a procurar a correspondência do outro tipo.
- [ ] Aplicar: o preço fica no produto; se falta a FDS, aparece o aviso com **Anexar**.
- [ ] Carregar outra fatura com a mesma descrição: liga sozinha ao mesmo produto.

## 32. Produto de compra nas receitas

- [ ] Ingrediente com 2 produtos (ex.: farinha 1 kg a 2 € e 5 kg a 5 €): numa receita, **+ Item** com essa farinha
      pergunta **qual produto** (Automático ou um dos dois). Cancelar deixa em automático.
- [ ] Na linha da receita aparece o alfinete; tocar abre a escolha com o marcador "mais recente".
- [ ] Fixar o produto de 1 kg: o custo da linha e o custo da receita passam a usar 2 €/kg (não o do mais recente).
- [ ] Mudar o preço desse produto (Ingredientes → produto): a receita acompanha.
- [ ] Voltar a "Automático": o custo volta à compra mais recente.
- [ ] Apagar o produto fixado: a linha volta ao custo automático, sem erro.
- [ ] Duplicar a receita: a cópia mantém o produto fixado.
- [ ] Ingrediente com um só produto: não mostra o alfinete nem pergunta nada.

## 33. Juntar ingredientes

- [ ] Criar dois ingredientes parecidos (ex.: "Açúcar branco" e "Açúcar Makro"), cada um com um produto, stock,
      e o segundo numa receita e numa ficha.
- [ ] No ⋮ de "Açúcar Makro" → **Juntar com outro ingrediente…** → escolher "Açúcar branco" → confirmar.
- [ ] "Açúcar Makro" desaparece da lista e está na lixeira; "Açúcar branco" tem agora **os dois produtos**.
- [ ] O stock do que ficou é a soma; a receita e a ficha passam a usar "Açúcar branco" e o custo é refeito
      (compra mais recente).
- [ ] Se o juntado tinha um alergénio que o outro não tinha, aparece no que ficou (e a mensagem avisa).
- [ ] Ingredientes de fabrico próprio não têm a opção; o papel Leitura não vê o menu.
- [ ] Fatura com o nome antigo ("Açúcar Makro…"): liga sozinha a "Açúcar branco" (nome já aprendido).

## 34. Lista de compras com produto escolhido

- [ ] Ingrediente com 2 produtos (ex.: farinha 1 kg e 5 kg, o de 5 kg é a compra mais recente). Receita A com o
      produto de 1 kg fixado e receita B em automático, ambas com 1 kg desse ingrediente.
- [ ] Produção com as duas receitas → **gerar lista de compras**: aparecem **duas linhas** da farinha, uma com
      a marca do produto de 1 kg (1 embalagem de 1 kg) e outra em automático (1 embalagem de 5 kg).
- [ ] Com stock do ingrediente, o total a comprar desce (o stock desconta-se do total, uma vez só).
- [ ] Tirar o produto fixado na receita A e gerar de novo: fica uma só linha (2 kg → 1 embalagem de 5 kg).
- [ ] Marcar uma linha como comprada continua a dar entrada no stock do ingrediente.
- [ ] Produções sem produtos fixados: a lista fica igual à de antes.

## 35. Alergénios por produto

- [ ] Ingrediente "Chocolate" com dois produtos. Editar o produto X: em **Alergénios a mais** marcar "Leite" e em
      **Pode conter** "Frutos de casca rija". Guardar: a lista de produtos mostra "Contém também / Pode conter".
- [ ] Receita A fixa o produto X; receita B fixa o produto Y; receita C fica em automático (todas com 500 g).
      Na informação nutricional/alergénios: só a **A** tem Leite e o vestígio; B e C não.
- [ ] Na escolha do produto de uma linha aparecem os alergénios do produto; "Automático" avisa que usa só os do ingrediente.
- [ ] Acrescentar um alergénio ao produto Y: a receita B passa a mostrá-lo (sem mexer na receita).
- [ ] Tirar o produto fixado da receita A: deixa de ter os alergénios do produto X.
- [ ] Ficha técnica que usa a receita A: a declaração e o **negrito da lista de ingredientes do rótulo** incluem
      o Leite; numa ficha que usa a receita C, não.
- [ ] Os alergénios do ingrediente (ex.: Glúten) contam sempre, com ou sem produto fixado.

## 36. Nutrição própria por produto

- [ ] Ingrediente com dois produtos. No produto X: **Nutrição própria do produto** → ligar "Usar estes valores" e
      preencher (ex.: 400 kcal); guardar. A lista mostra "Nutrição própria (400 kcal)".
- [ ] Ligar "Usar estes valores" sem preencher nada: pede para preencher ou desligar.
- [ ] **Foto do rótulo (IA)** no produto: preenche os valores (com o Gemini configurado) e acrescenta os alergénios
      lidos; conferir os valores antes de guardar.
- [ ] Receita A fixa o produto X; receita B em automático (mesma quantidade): a informação nutricional da A usa
      os valores do X; a da B usa os do ingrediente.
- [ ] Alterar os valores do produto X: a nutrição da receita A acompanha (e a ficha técnica e o rótulo que a usam).
- [ ] Desligar "Usar estes valores": a receita A volta a usar a nutrição do ingrediente.
- [ ] Produto por 100 ml com densidade: o valor converte-se para 100 g (confere um caso simples à mão).

## 37. Unidades (g, ml, un) e características

- [ ] Ingrediente novo "Leite": **Unidade de medida = Mililitros**; embalagem 1000 (ml), preço 1,20 €. A lista
      mostra "em ml" e o preço por **L**. Ingrediente "Ovos": **Unidades**, embalagem 12, peso de cada unidade 55 g.
- [ ] Receita com 250 ml de leite, 2 un de ovos e 200 g de farinha: as linhas mostram "250 ml", "2 un", "200 g"; o
      peso da receita soma gramas (ml × densidade, un × 55 g) e o custo usa o preço por ml/un.
- [ ] Nutrição da receita e do produto: coerente com os pesos em gramas (confere um caso simples à mão).
- [ ] Fatura com "Leite UHT 1L" (6 un): a IA lê embalagem **1000 ml**; **Comprado** aparece em **un** (6) = 6000 ml.
      Criar o ingrediente novo: nasce em **ml**.
- [ ] Fatura com "Cravinho 14 g" (1 un) e "Noz-moscada 15 g" (2 un): Comprado 14 g e 30 g (secção 30).
- [ ] Trocar o seletor do Comprado entre g, ml e un converte o número (quando dá).
- [ ] Um ingrediente em g com embalagem lida em ml: converte com a densidade; se for "un", avisa que não dá para converter.
- [ ] Fatura com "Farinha de trigo T55" e "Farinha de trigo T65": ligam-se a ingredientes diferentes; ao criar novo, o
      campo **Característica** vem preenchido (T55). A lista mostra "Farinha de trigo T55".
- [ ] Stock, lista de compras, mise en place e plano de produção mostram ml e un nos ingredientes que os usam.
- [ ] A lista de ingredientes do rótulo continua por ordem decrescente de peso (ovos em un contam pelo peso em g).

## 38. Faturas grandes e progresso

- [ ] Nova fatura → escolher o PDF digitalizado grande (dezenas de páginas, 80 MB): **não** dá "Request entity too large".
- [ ] Aparece um cartão nas Faturas com "A enviar o ficheiro… (79,7 MB)" e depois "A IA está a ler as páginas: N de 93…"
      com a barra a avançar.
- [ ] Mudar para outro ecrã (ex.: Compras): aparece a **faixa** por cima da barra de navegação com o progresso; tocar leva às Faturas.
- [ ] No fim: "Pronto: N faturas". Cada fatura tem o seu ficheiro só com as suas páginas; as guias de remessa e
      talões sem preços ficam sem linhas (podes ignorá-las ou apagá-las).
- [ ] Faturas do mesmo fornecedor com datas diferentes ficam separadas; um documento de 2 páginas seguidas fica **uma só**.
- [ ] Fechar a app a meio: ao reabrir, a fatura aparece com **Continuar (N/93)** e retoma sem repetir o que já foi lido.
- [ ] Se a IA estiver sobrecarregada: aparece um erro em português e "Continuar / tentar de novo" (sem `ClientException`).
- [ ] Confere as quantidades de um grossista: Makro/Recheio "Qt.Total" (2 vol. × 6 = 12) e produtos vendidos ao kg (1,150 kg).
- [ ] Depois de atualizar o servidor, abrir a app (que ainda tem a versão antiga): aparece "Há uma versão nova da
      app" e **Atualizar** recarrega já com a versão nova (o número aparece no aviso).
- [ ] Uma fatura pequena (foto/PDF de 1 página) continua a funcionar e abre a revisão pelo botão "Rever a fatura".

## 39. Faturas: repetição, resumo, corrigir e apagar

- [ ] Enviar o PDF grande: se a IA falhar numa janela, a barra mostra "Páginas X–Y: … Nova tentativa em Ns (2 de 6)…"
      e continua sozinha, sem carregares em nada.
- [ ] No fim, o cartão mostra "Pronto: N novas · N duplicadas · págs. sem fatura: …" e **Ver o que entrou** lista cada
      documento com fornecedor, nº, data, páginas e estado (duplicada / sem linhas / com linhas).
- [ ] Na lista de faturas, uma duplicada mostra o chip **Duplicada** (não "Erro").
- [ ] Como **proprietário**: no ecrã de revisão, o lápis corrige fornecedor, número, data e total; o relógio mostra o
      histórico com a alteração (antes → depois, por quem).
- [ ] Toque longo numa fatura da lista: Corrigir / Ver histórico / Apagar (só o proprietário vê estas opções).
- [ ] Apagar uma fatura: desaparece da lista; em ⋮ → **Faturas apagadas** aparece com quem/quando e **Restaurar** traz-a de volta.
- [ ] Como **editor**: não aparecem o lápis nem "Apagar"; consegue carregar e analisar faturas e aplicar preços.
- [ ] Uma fatura apagada não aparece na contabilidade e não bloqueia carregar outra vez a mesma fatura.

## 40. Aplicar por partes e embalagens nas faturas

- [ ] Fatura com 3+ linhas: decide só uma (Preço, com ingrediente ligado) e deixa as outras em **"Por rever depois"**
      (é a ação por omissão quando a IA não encontra correspondência). Carregar em **Aplicar** não pede para decidir
      as outras — só a decidida é gravada.
- [ ] Na lista de faturas, essa fatura mostra o chip **"N por rever"** (não "Analisada").
- [ ] Reabrir a fatura: a linha já aplicada não aparece como cartão — só o aviso "1 linha já aplicada antes"; as
      outras continuam por decidir. Decide mais uma e aplica: o chip passa a "N-1 por rever".
- [ ] Decidir a última linha (ou marcá-la "Ignorar"): a fatura passa a **Confirmada**.
- [ ] Aplicar duas vezes seguidas sem mudar nada: o preço e o stock não duplicam (confere o histórico do ingrediente
      e o movimento de inventário).
- [ ] Uma linha de **"Fita adesiva"** ou **"Caixa take-away"**: o terceiro botão **Embalagem** liga a uma embalagem
      existente ou cria uma nova (nome + tipo); aplicar atualiza o preço por peça em **Embalagens** e, numa fatura
      seguinte com o mesmo texto, liga sozinha.
- [ ] Uma embalagem "por rever depois" não bloqueia aplicar as restantes linhas da mesma fatura.

---

## 41. Embalagens: característica, uso e formatos de cookie

- [ ] Em **Embalagens**, editar uma peça existente: adicionar uma **característica** (ex.: "kraft com janela"),
      escolher um **uso** (Individual / Múltiplo / A granel / Outro) e marcar um ou mais **formatos de cookie**
      (chips). Guardar e reabrir: os três valores voltam a aparecer certos.
- [ ] Deixar formatos de cookie em branco: a embalagem grava sem nenhum (serve para qualquer formato) — não dá erro.
- [ ] Na lista de Embalagens, a peça editada mostra a característica e o uso na segunda linha (subtítulo).
- [ ] Numa fatura, uma linha de embalagem nova (**"criar nova embalagem"**): aparecem os mesmos três campos
      (característica, uso, formatos de cookie) já na revisão da fatura, sem ter de ir a Embalagens depois.
      Aplicar a linha cria a embalagem já com esses valores.
- [ ] A IA continua a sugerir a **característica** quando o texto da fatura tem uma variante clara (ex.: "Saco
      kraft com janela" → característica "kraft com janela"); uso e formatos ficam sempre por escolher à mão.
- [ ] (Segurança, já cobertos pela suite automática — não repetir à mão salvo dúvida) uma embalagem não pode
      ficar com uma lista de formatos de cookie que misture o próprio com o de outra empresa; a app nunca deixa
      escolher formatos que não sejam os da empresa.
- [ ] Escolher **uso = Múltiplo**: aparecem chips de quantidade (2, 3, 4, 5, 6, 8, 10, 12). Escolher "6" e
      guardar: reabrir mostra "rende 6 un" e o custo por unidade já divide por 6.
- [ ] Escolher **uso = Individual**: a quantidade fica em 1 automaticamente (chips desaparecem).
- [ ] Precisar de uma quantidade fora da lista rápida (ex.: 24): continua a dar para escrever no campo "Uma peça
      embala quantas unidades?" mais abaixo — os chips são só um atalho, não travam valores maiores.
- [ ] O mesmo seletor de quantidade aparece ao criar uma embalagem nova (uso = Múltiplo) diretamente na revisão
      de uma fatura; aplicar a linha cria a embalagem já com essa quantidade em `rende_unidades`.

---

## 42. Faturas: corrigir marca de linhas já aplicadas; fornecedor no cabeçalho

- [ ] Aplicar uma linha de ingrediente com marca (ex.: "Sidul") indicada e o ingrediente **reconhecido
      automaticamente** (já existia, emparelhado pela IA): reabrir Ingredientes → produto de compra mostra a
      marca e o **fornecedor** da fatura — antes deste arranjo, o fornecedor ficava em branco quando o produto
      já existia.
- [ ] Na revisão de uma fatura, abrir o resumo "N linha(s) já aplicada(s) antes": expande e mostra cada linha,
      com a marca/fornecedor gravados (quando os há).
- [ ] Com sessão de **editor**: as linhas já aplicadas não têm lápis de corrigir.
- [ ] Com sessão de **proprietário** ou **administrador**: cada linha ligada a um **ingrediente** ou
      **consumível** (não a uma embalagem — essa não tem marca) tem um lápis "Corrigir marca". Mudar e guardar
      substitui mesmo o que já lá estava (ao contrário de aplicar de novo a fatura, que só preenche o que
      estiver em branco).
- [ ] O **fornecedor não se corrige linha a linha**: corrige-se uma vez no lápis do cabeçalho da fatura (só
      proprietário). Ao guardar, o fornecedor novo aparece logo nos produtos/consumíveis/embalagens que essa
      fatura já tinha tocado — sem precisar de corrigir cada linha.
- [ ] A correção (marca por linha ou fornecedor no cabeçalho) fica no histórico da fatura (ícone de
      relógio/histórico no ecrã), com os valores antes/depois.

---

## 43. Sincronização de marca/fornecedor, sugestões e maiúscula inicial

- [ ] Aplicar uma fatura para um ingrediente **já existente** (reconhecido automaticamente), com marca e a
      fatura com fornecedor preenchido: abrir a lista de **Ingredientes** — a marca e o fornecedor aparecem
      no subtítulo/pesquisa/filtro por fornecedor (antes ficavam em branco mesmo com o produto de compra
      certo).
- [ ] Um ingrediente com **vários produtos de compra** (marcas/fornecedores diferentes): dentro do ingrediente,
      "Produtos de compra" lista todos, cada um com marca/fornecedor/preço/data; o mais recente tem o chip
      "custo atual" — é esse que aparece resumido na lista de Ingredientes.
- [ ] Editar a marca de um produto de compra mais antigo (não o mais recente): a lista de Ingredientes **não**
      muda (continua a mostrar o mais recente). Editar a marca do produto **mais recente**: a lista atualiza.
- [ ] Nos campos de **Marca** e **Fornecedor** (Ingredientes, Produtos de compra, Embalagens, Consumíveis,
      revisão de faturas, cabeçalho da fatura): ao tocar/escrever aparecem sugestões dos valores já usados na
      empresa; tocar numa sugestão preenche o campo; continua a dar para escrever um nome novo à vontade.
- [ ] Criar um ingrediente/produto/consumível/embalagem/receita/ficha técnica com o **nome em minúsculas**
      (ex.: "farinha de trigo"): ao guardar, fica com a primeira letra maiúscula ("Farinha de trigo"), sem
      mexer no resto do texto.

---

## 44. Juntar marcas/fornecedores repetidos

- [ ] Ter (ou criar) um fornecedor com nomes ligeiramente diferentes em produtos diferentes (ex.: "Recheio",
      "Recheio Cash & Carry, S.A.", "Recheio Cash & Carry, SA"). Em Ingredientes, tocar no ícone "Juntar
      marcas/fornecedores repetidos" (topo do ecrã) ou no chip "Juntar repetidos" junto ao filtro de
      fornecedor.
- [ ] Escolher **Fornecedor**, selecionar os nomes que são o mesmo (chips), escrever o nome final (ou tocar
      num dos escolhidos para o preencher automaticamente) e tocar em **Juntar**. Aparece quantos registos
      foram atualizados.
- [ ] Confirmar: os produtos de compra, consumíveis e embalagens que tinham esses nomes ficam todos com o
      nome final; a lista de Ingredientes (fornecedor sincronizado) também atualiza.
- [ ] Repetir com **Marca**: só mexe em produtos de compra e consumíveis (embalagens não têm marca).
- [ ] Com sessão de **editor** ou **viewer**: o ícone/chip não aparece (só proprietário/administrador).
- [ ] Escrever o nome final com espaços a mais (ex.: "Recheio   Cash  & Carry"): grava com um só espaço entre
      palavras.

---

## 45. Ignorar faturas em lote, corrigir linhas e administrador nas faturas

- [ ] Qualquer página com o ícone de sugestão (balão de fala no topo): escrever uma nota e confirmar que o
      botão **Enviar** fica ativo (antes ficava sempre cinzento, mesmo com texto escrito).
- [ ] Em **Faturas**, tocar no ícone "Selecionar" (lista com marcas): aparecem caixas de seleção. Marcar
      várias (ex.: faturas antigas já "Confirmada" ou "Analisada") e tocar em **"Marcar como ignorada"**.
      Confirmar: ficam com o chip "Ignorada", os ficheiros continuam acessíveis, e já não pedem revisão.
- [ ] Reabrir uma fatura "Ignorada" e decidir qualquer linha (aplicar um preço, ou até só "Ignorar" essa
      linha): a fatura sai sozinha do estado "Ignorada".
- [ ] Na revisão de uma fatura, uma linha que a IA leu a mais (duplicada): tocar no **X** no canto da linha —
      desaparece da lista. Aplicar: confirma que não mudou preço/stock por causa dela.
- [ ] Na mesma revisão, tocar em **"Adicionar item em falta"**: aparece uma linha nova em branco para
      preencher à mão (nome, quantidade, preço). Aplicar com ela por decidir: a fatura continua "1 por rever"
      (não fica logo "Confirmada"). Decidir essa linha: passa a "Confirmada".
- [ ] Com uma conta **administrador** (não proprietário): já consegue tocar no lápis de "Corrigir fornecedor,
      data, número…" de uma fatura e em "Apagar fatura" — antes só o proprietário conseguia.

---

## 46. Notas por página

- [ ] Em qualquer página com o ícone de ajuda (nota adesiva + balão de fala + "?"), tocar na **nota adesiva**:
      abre "Notas desta página". Escrever uma nota e enviar — aparece na lista, com o teu nome e a data.
- [ ] Com sessão de **Leitura (viewer)**: consegue escrever uma nota nova, mas não tem caixa de confirmação
      (só um círculo) — não marca como resolvida.
- [ ] Com sessão de **editor** ou superior: já tem caixa de confirmação — marcar como resolvida risca o texto e
      mostra quem e quando resolveu; desmarcar volta ao normal.
- [ ] O ícone mostra um **selo com o número de notas por resolver** desta página; sobe/desce ao criar/resolver.
- [ ] Abrir a mesma página com **outra conta da mesma empresa**: vê a nota que a primeira conta escreveu (é
      para a equipa toda, ao contrário do botão de sugestão/erro).
- [ ] Só **proprietário/administrador** conseguem apagar uma nota (ícone de lixo).

---

## 47. Categorias de receitas editáveis

- [ ] Confirmar que as receitas que já existiam continuam com a categoria certa (Massa/Recheio/Cobertura/
      Outra) — nada deve ter mudado visualmente na lista de Receitas.
- [ ] Ir a **Configurações → Categorias de receitas**: aparecem as 4 categorias por omissão. Criar uma nova
      (ex.: "Decoração"), editar o nome de uma, e desativar outra.
- [ ] Em **Receitas → Nova receita**: o seletor de categoria mostra as categorias ativas (incluindo a que
      acabaste de criar); a que desativaste não aparece.
- [ ] Criar uma receita com a categoria nova — grava e aparece corretamente na lista e no filtro de Receitas.
- [ ] Apagar uma categoria que já tem receitas: as receitas mantêm o nome da categoria guardado (não desligam
      nem ficam sem categoria); só deixa de aparecer para escolher numa receita nova.
- [ ] Com sessão de **editor**: não consegue chegar a "Categorias de receitas" (só proprietário/administrador).

## 48. Ordenar e filtrar nas listas

- [ ] **Ingredientes**: botão de ordenar (seta) no topo — Nome, Preço, Fornecedor. Tocar troca o critério;
      tocar outra vez no mesmo inverte a seta e a ordem.
- [ ] **Receitas**: ordenar por Nome, Categoria, Custo — os chips de categoria continuam a filtrar como antes.
- [ ] **Produtos**: ordenar por Nome, Categoria.
- [ ] **Fichas Técnicas**: ordenar por Nome, Custo, Preço de venda; chips novos por **categoria** (só aparecem
      se houver mais do que uma categoria em uso).
- [ ] **Vendas**: ordenar por Data, Valor; chips novos por **origem** (Manual/CSV/Vendus, só aparecem se houver
      mais do que uma origem nas vendas dos últimos 90 dias).
- [ ] **Encomendas**: ordenar por Data/hora, Cliente; chip novo **Urgentes** (só aparece na vista "ativas",
      quando há pelo menos uma urgente).
- [ ] **Faturas**: ordenar por Data, Fornecedor, Valor — a ordenação aplica-se dentro de cada grupo de mês
      (os meses continuam do mais recente); chips novos por **estado** (nova/analisada/confirmada/erro/
      ignorada, só aparecem se houver mais do que um estado presente).
- [ ] **Limpeza e insumos**: ordenar por Nome, Estado FDS.
- [ ] **Embalagens** (separador Peças): ordenar por Nome, Custo por unidade.
- [ ] Em todos os ecrãs acima: sair e voltar à página **mantém o critério e a ordem escolhidos** enquanto a
      app não é reiniciada (é estado do ecrã, não é guardado no servidor).

## 49. Barra de topo redesenhada + comparação de fornecedores

- [ ] Em **qualquer página**, o botão "?" é sempre o último ícone à direita da barra de topo (antes a ordem
      variava). Toca nele: abre uma folha com a explicação da página e, mais abaixo, "Notas desta página"
      (com a bolinha de contagem se houver notas por resolver) e "Sugestão ou reportar erro" — ambos
      continuam a funcionar exatamente como antes, só mudou onde se chega a eles.
- [ ] Em **Ingredientes**, o menu (⋮) junta "Juntar marcas/fornecedores repetidos", "Preencher nutrição pela
      tabela INSA" e "Importar CSV" — testa cada uma a partir do menu.
- [ ] O conteúdo do "?" nas páginas que mudaram recentemente (Ingredientes, Receitas, Produtos, Fichas
      Técnicas, Vendas, Encomendas, Faturas, Rever fatura, Limpeza e insumos, Embalagens, Lista de compras)
      menciona as funcionalidades novas (ordenar/filtrar, marcas/fornecedores, notas por página, etc.).
- [ ] **Lista de compras**: adiciona um ingrediente que já compras a mais do que um fornecedor (precisa de
      ter 2+ "produtos de compra" em Ingredientes → abrir o ingrediente) — aparece o aviso "X é o mais barato"
      com a poupança em %. O ícone (ⓘ) abre a lista completa de fornecedores, do mais barato ao mais caro.
      Um ingrediente com um só fornecedor (ou preços iguais) não mostra o aviso.

## 50. Selecionar vários ingredientes para juntar

- [ ] Ingredientes → menu (⋮) → "Selecionar ingredientes para juntar": entra num modo de seleção (título muda
      para "N selecionado(s)", X para cancelar).
- [ ] Ingredientes de **fabrico próprio** aparecem com a caixa desativada (não podem juntar-se).
- [ ] Seleciona 3 ingredientes comprados parecidos (ex. duplicados por engano) e toca "Juntar".
- [ ] Escolhe qual fica — a mensagem de confirmação lista corretamente os outros que vão desaparecer.
- [ ] Depois de confirmar: só o escolhido fica na lista; os outros aparecem na Lixeira (podem ser restaurados
      se for engano). Receitas/fichas que usavam os ingredientes juntados continuam a funcionar.
- [ ] Cancelar a seleção (X) não altera nada.

## 51. Procurar ingrediente sem acentos e pela característica

- [ ] Ingredientes: escreve "acucar" (sem acento) na pesquisa — encontra "Açúcar".
- [ ] Escreve uma característica (ex. "T55") em vez do nome — encontra o ingrediente certo.
- [ ] O mesmo testa em: escolher ingrediente numa receita (Item), na Lista de compras (+ Item →
      Ingrediente), em "Juntar com outro ingrediente…" e ao ligar uma linha de fatura a um ingrediente.

## 52. Bebidas/Revenda, tipos livres e peças compradas nas faturas

- [ ] Rever fatura: uma linha mostra 5 chips — **Ingrediente, Embalagem, Limpeza / insumo, Bebida, Revenda**.
- [ ] Escolher **Bebida** (ou Revenda) numa linha sem correspondência: "Criar produto novo" já vem com a
      **Categoria** pré-preenchida ("Bebida"/"Revenda") e "Não pede ficha de dados de segurança".
- [ ] Em **Limpeza e insumos**, abrir esse produto: tem um campo **Preço de venda** (opcional) — preenche e
      grava; a lista passa a mostrar "venda € X" nesse item.
- [ ] Em **Limpeza e insumos** → Novo produto → campo Categoria: escreve uma categoria que não existe (ex.
      "Sobremesas") — grava sem erro e passa a sugerir-se da próxima vez.
- [ ] Numa linha de **Embalagem** nova: o campo **Tipo** aceita escrever um valor novo (ex. "Frasco") além das
      sugestões (Caixa, Saco, Saqueta, Adesivo, Fita, Cartão, Outro).
- [ ] A mesma coisa em **Embalagens → Nova embalagem**: o campo Tipo é texto livre com sugestões.
- [ ] Linha de embalagem: o campo **"Peças compradas"** aparece só para Embalagem, normalmente já vem
      preenchido com a quantidade que a IA leu (ex. "500" num rolo de adesivos). Aplicar e confirmar em
      Embalagens que "peças na compra" ficou com esse número (não com 1).
- [ ] Em "Formatos de cookie (opcional)" de uma embalagem nova: toca "+ Novo formato", escreve só um nome,
      "Criar" — o formato fica criado e já selecionado nessa linha; confirma depois em Configurações →
      Formatos de cookie que apareceu (com o peso a zero/1 g, por preencher).

## 53. Falha ao aplicar faturas, trocar ingrediente na receita, prévia do logótipo

- [ ] Rever fatura: numa linha "Criar novo" (ingrediente/embalagem), escreve um nome com mais de 200
      caracteres (cola um texto grande) e toca "Aplicar" — a app avisa antes de tentar gravar, sem deixar
      chegar ao servidor ("O nome … é longo demais…").
- [ ] Com várias linhas prontas e uma delas a falhar (nome longo, ou qualquer outro erro do servidor):
      confirma que **as outras linhas aplicam-se na mesma** (preços/stock atualizados) e só a linha com
      problema fica por rever — o texto que já tinhas escrito nela continua lá, não se perde.
- [ ] O aviso de erro nomeia o campo problemático (ex. `"nome": Must be no more than 200 character(s).`), não
      só "Failed to create record.".
- [ ] Abrir uma receita: cada linha de ingrediente/sub-receita tem um ícone "⇄" — toca, escolhe outro
      ingrediente, confirma no diálogo ("Troca X por Y…") — a linha muda de ingrediente mantendo a
      quantidade e o custo recalcula.
- [ ] Com um utilizador **Editor** (não admin/owner): o ícone "⇄" não aparece nas linhas da receita (só
      consegue ajustar a quantidade, tocando na linha).
- [ ] Configurações → Aparência: mexe no slider "Tamanho" do logótipo (ou da posição/visibilidade) — a barra
      de "Pré-visualização" no topo da secção atualiza imediatamente, com o logótipo/nome reais, antes de
      tocar em "Guardar aparência".
- [ ] Com um logótipo **largo** (tipo nome escrito, não quadrado): aparece **completo** na barra superior e
      na Pré-visualização, sem cortar as pontas (nem na app real nem na prévia).
- [ ] Numa receita com várias linhas (a última perto do fundo do ecrã): os botões "⇄"/📌 da última linha
      ficam visíveis e tocáveis — não ficam escondidos atrás do botão "+ Item".

## 54. Característica em todo o lado, stock para Bebida/Revenda/Limpeza, buscas sem acentos

- [ ] Rever fatura: numa linha de ingrediente ou de embalagem, ao ligar a um existente, a lista mostra a
      característica junto ao nome (ex.: "Café em grão gold" e "Café em grão bio" aparecem distintos, não os
      dois só como "Rioba · 1 kg"). Escreve sem acento/maiúsculas na busca — encontra à mesma.
- [ ] Limpeza e insumos → Novo produto: ganhou o campo "Característica (opcional)". Preenche, grava, e a lista
      mostra "Nome Característica" no título. A pesquisa do ecrã também ignora acentos.
- [ ] Rever fatura, numa linha de Bebida/Revenda/Limpeza a criar um produto novo: também tem o campo
      "Característica"; o seletor de produto existente mostra a característica e a busca ignora acentos.
- [ ] Rever fatura, linha de Bebida: escolhe ação "Stock" ou "Preço + Stock" (antes só havia Preço/Por rever/
      Ignorar) — aparece o campo "Comprado" (unidades). Aplica com, por exemplo, 24 unidades e €12 de preço.
- [ ] Depois de aplicar: em Inventário → aba "Material da loja", a Bebida aparece com 24 un e valor €12 (ou
      seja, €0,50/unidade — o preço gravado no produto é o total ÷ quantidade, não os €12 inteiros).
- [ ] O campo de preço nessas linhas chama-se "Preço da compra" com a nota "o total pago, não o preço de 1
      unidade".

## 55. Preço a vermelho quando a receita tem linhas por ligar

- [ ] Numa receita com pelo menos uma linha "por ligar" (importada sem correspondência, ou "Trocar" cancelado
      a meio): na lista de **Receitas**, o preço dessa receita aparece a vermelho com um "⚠" a seguir.
- [ ] Toca (ou, no rato, passa por cima) no "⚠" — aparece a explicação ("Este preço não é definitivo…") e o
      diálogo fecha bem com "Entendi" (a lista continua lá, não fecha a página).
- [ ] Abre essa receita: "Custo (prev.)" e "Custo/kg" também aparecem a vermelho com "⚠", com a mesma
      explicação ao tocar. Liga a linha pendente a um ingrediente — os valores voltam à cor normal (na
      receita e, ao voltar atrás, na lista).
- [ ] Uma receita sem linhas pendentes mostra o preço na cor normal, sem "⚠", em ambos os sítios.

## 56. Email configurável e ZIP para a contabilidade

- [ ] Faturas → ícone de pasta (canto superior): abre sem erro (mesmo em modo de desenvolvimento/debug).
- [ ] Alternador "Um mês" / "Todas": "Um mês" mostra a navegação ‹ mês/ano › como antes; "Todas" some com a
      navegação e mostra todas as faturas confirmadas (de sempre).
- [ ] Campo "Email da contabilidade": a primeira vez fica vazio; escreve um email, toca "Enviar por email" —
      mesmo que o SMTP não esteja configurado no servidor (erro amigável esperado), o email fica guardado.
      Fecha e reabre a folha (ou a app): o email continua preenchido.
- [ ] Com SMTP configurado no servidor (ver `docs/DEPLOY.md`) e pelo menos uma fatura confirmada no período:
      "Enviar por email" manda um email com os PDFs/imagens em anexo + `resumo.csv`, e mostra quantas faturas
      e o total numa mensagem de confirmação.
- [ ] "Baixar ZIP": com faturas no período, descarrega `faturas-AAAA-MM.zip` (ou `faturas-todas.zip` em
      "Todas") com os ficheiros dentro, nomeados `FT-FORNECEDOR-DDMMAAAA.ext`. Sem faturas no período, mostra
      "Nenhuma fatura confirmada neste período" em vez de descarregar um ZIP vazio.
- [ ] "Copiar resumo (CSV)" continua a funcionar como antes, em ambos os modos de período.
- [ ] O envio mensal automático (dia 1, cron do servidor) continua a funcionar — usa o email guardado na app
      se existir, senão a variável de ambiente antiga (`GC_TURNKEY_CONTAB_EMAIL`), documentado em `pb/README.md`.

## 57. Erro de nutrição do produto sempre visível

- [ ] Ingredientes → abre um ingrediente → "Produtos de compra" → toca num produto para editar.
- [ ] Expande "Nutrição própria do produto", liga "Usar estes valores", deixa todos os campos vazios (0) e
      toca "Guardar" — o diálogo desce sozinho e mostra "Preenche a nutrição do produto, ou desliga
      'Nutrição própria'." bem visível (não fica escondido no fundo).
- [ ] Apaga o nome, ou a embalagem/preço, e toca "Guardar" — o mesmo acontece: erro visível, sem precisar de
      arrastar o scroll à mão.
- [ ] Preenche pelo menos um valor de nutrição (ex.: açúcares) e toca "Guardar" — grava normalmente, o
      diálogo fecha e o produto aparece com "Nutrição própria (… kcal)" na lista.

## 58. Ligar automaticamente ingredientes por ligar, pelo nome

- [ ] Numa receita com pelo menos uma linha "por ligar" cujo nome bate **exatamente** (ignorando
      acentos/maiúsculas) com o nome de um ingrediente existente: na lista de Receitas, aparece um ícone de
      varinha (🪄) ao lado dessa receita. Toca nele — a linha liga-se sozinha, sem pedir nada, e a lista
      atualiza (preço deixa de estar a vermelho, se não houver mais pendências).
- [ ] O mesmo botão, dentro do ecrã da receita, aparece como "Ligar automaticamente" no aviso "Há linhas por
      ligar a um ingrediente" — faz o mesmo.
- [ ] Numa receita com uma linha pendente **parecida mas não igual** a um ingrediente (ex.: "Farinha T55
      Makro 25kg" vs. "Farinha de trigo T55"): ao tocar em "Ligar automaticamente" abre uma lista "Rever
      ligações" com essa linha já marcada e a sugestão pré-preenchida ("Vai ligar a…"). Desmarca a caixa —
      fica de fora. Toca "Trocar" — abre o seletor normal de ingrediente/receita para escolheres outro.
- [ ] Uma linha pendente sem nenhuma correspondência (nome totalmente diferente de qualquer ingrediente)
      aparece na lista de revisão com "Sem sugestão — escolhe manualmente" a vermelho e a caixa desmarcada e
      desabilitada, até tocares "Escolher" e escolheres uma manualmente.
- [ ] Toca "Ligar selecionados" com pelo menos uma linha marcada — liga só essas; as desmarcadas continuam
      pendentes (preço a vermelho se ainda houver alguma). Fecha a lista sem tocar no botão — nada é ligado.
- [ ] Numa receita sem nenhuma linha pendente, o ícone de varinha não aparece na lista de Receitas.
- [ ] O "Ligar" manual de sempre (por linha, dentro da receita) continua a funcionar como antes.

## 59. Importar uma receita por foto/print (IA) ou lista simples

- [ ] Receitas → ícone de importar → abre com o modo **"Uma receita"** já selecionado (ao lado de "Várias
      (CSV avançado)"). Escreve um nome, escolhe uma categoria (chips), escreve a lista de ingredientes no
      formato simples (`ingrediente` + tab/`;`/`,` + `quantidade`, uma linha por ingrediente, sem cabeçalho) e
      toca "Importar" — cria a receita, liga os ingredientes que já existem pelo nome e deixa pendentes os que
      não existem (como no CSV).
- [ ] Sem nome, ou sem categoria escolhida, ou sem nenhum ingrediente válido na lista: "Importar" mostra o
      erro certo (nome/categoria em falta, ou "sem nenhum ingrediente válido") sem criar nada.
- [ ] "Escolher imagem" (ou tocar na área "Toca aqui e cola uma imagem" e colar com **Ctrl+V** um print/foto)
      com a chave de IA configurada no servidor: pré-preenche o nome, a categoria (se corresponder a uma
      categoria ativa) e a lista de ingredientes — revê/corrige antes de "Importar" como sempre.
- [ ] Sem a chave de IA configurada no servidor: "Escolher imagem"/colar mostra "IA não configurada" (não
      rebenta, não apaga o que já tinhas escrito).
- [ ] Colar **texto** normal (Ctrl+V) dentro do campo "Nome da receita" ou da caixa de ingredientes continua a
      funcionar normalmente — só a área "Toca aqui e cola uma imagem", quando tem o foco, intercepta o Ctrl+V.
- [ ] O modo **"Várias (CSV avançado)"** continua igual: colar/escolher ficheiro CSV com 4 colunas
      (nome, categoria, ingrediente, quantidade) por linha, várias receitas de uma vez.

---

## Notas / ajustes pedidos

_(escreve aqui, por número, o que queres mudar)_
