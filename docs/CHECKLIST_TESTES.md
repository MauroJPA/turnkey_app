# Checklist de testes — turnkey_app

Percorre esta lista na app (login `ana@teste.local`). Para cada ponto marca
`[x]` se está OK, ou escreve a seguir o que queres ajustar. Reinicia o
PocketBase (`pb\serve.ps1`) e faz hot-restart do `flutter run` (tecla **R**)
antes de começar, para carregar as últimas migrations.

---

## 0. Arranque e navegação

- [ ] Login com email/palavra-passe entra no **Início**.
- [ ] O ecrã de login **não** mostra "Continuar com Apple" (só Google).
- [ ] O **rodapé** (Início · Produzir · Agenda · Compras · Inventário) aparece
      em **todas** as páginas, incluindo detalhes (receita, ficha, produção,
      configurações).
- [ ] Tocar em cada aba do rodapé abre a secção certa.
- [ ] O botão **?** (canto superior direito) existe em todas as páginas e abre
      uma explicação clara.
- [ ] Ao lado do **?** há o ícone de **sugestão/erro**: abre um campo de nota,
      "Enviar" grava (mensagem "Obrigado! Sugestão enviada.").

## 1. Início (painel)

- [ ] Cartão **Stock baixo** mostra um número e abre o Inventário.
- [ ] Cartão **Produções por fazer** mostra um número e abre a Agenda.
- [ ] Cartão **A comprar** mostra nº + € estimado e abre a Lista de compras.
- [ ] Grelha "Tudo" abre Ingredientes / Receitas / Fichas / Formatos /
      Configurações / Equipa.
- [ ] Logótipo da empresa e nome aparecem no topo (depois de o carregares no
      ponto 2).

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

- [ ] Aparecem **Mini** (20 g), **Recheado** (120 g + 30 g), **Simples** (150 g).
- [ ] "+" cria um formato novo (nome, massa g, recheio g).
- [ ] Tocar edita; o **ícone do caixote do lixo** remove (com confirmação).
- [ ] Um formato marcado como inativo deixa de aparecer nos seletores.

## 4. Ingredientes

- [ ] A lista mostra os ~166 ingredientes com preço/fornecedor.
- [ ] "+" adiciona; tocar edita; importar .csv funciona.
- [ ] Mudar o preço de um ingrediente recalcula o custo nas receitas e fichas.

## 5. Receitas

- [ ] Lista com pesquisa e filtro por categoria; lixeira acessível.
- [ ] Abrir uma receita mostra as linhas e o custo.
- [ ] Botão 📖 **Procedimento e imagens**: escrever passos (um por linha) e
      juntar 1 foto → aparecem na folha.
- [ ] Botão 📅 **Agendar produção** abre a folha de adicionar à agenda para
      essa receita.

## 6. Fichas técnicas

- [ ] Lista de fichas; abrir mostra as partes (massa/recheio/cobertura) e o
      preço sugerido.
- [ ] Campo **Formato** liga a ficha a um formato de cookie.
- [ ] Para o ponto 8 funcionar, confirma que a ficha do produto (ex. "Gookie -
      Rio") tem: slot massa = a massa, slot recheio = o recheio, e o formato.

## 7. Produzir → carrinho → Agenda

- [ ] O seletor mostra **todas** as receitas de fabrico próprio.
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

> Pré-requisito no servidor: `TURNKEY_AI_PROVIDER` (por omissão `gemini`) e a
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

---

## Notas / ajustes pedidos

_(escreve aqui, por número, o que queres mudar)_
