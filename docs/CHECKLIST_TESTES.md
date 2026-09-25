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
- [ ] Carregar outra fatura com o **mesmo texto**: liga sozinha ao mesmo produto ("Produto já conhecido").
- [ ] Fatura com data **anterior** à última compra: aparece o aviso e o custo não muda.
- [ ] Criar ingrediente novo pela revisão de uma fatura só com "Preço": fica **um só** produto (sem duplicado).
- [ ] Criar/editar um ingrediente comprado com preço e embalagem (sem produtos): cria-se logo o 1.º produto.
- [ ] Importar ingredientes por CSV: continuam a aparecer com custo e ficam com um produto.

---

## Notas / ajustes pedidos

_(escreve aqui, por número, o que queres mudar)_
