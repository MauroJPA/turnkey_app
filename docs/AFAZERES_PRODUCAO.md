# Afazeres para a entrada em produção

Criado em 2026-09-24. Meta: **entrar em produção esta semana**. Este ficheiro é a
lista viva; marcar `[x]` à medida que se conclui. Só se avança para os itens
novos depois de fechar os testes de Ingredientes, Receitas e Fichas técnicas
(ver `docs/CHECKLIST_TESTES.md`).

## Ordem sugerida

1. **Fechar os testes** de Ingredientes, Receitas e Fichas (bloco 0).
2. **Branches e fluxo de trabalho** (bloco 1) — rápido, faz-se antes de mexer em mais código.
3. **Backups automáticos** (bloco 2) e **segurança** (bloco 3) — obrigatórios antes de haver dados reais.
4. **Produtos Gookie + etiqueta** (blocos 4 e 5) — o que falta de funcionalidade.
5. **Go-live** (bloco 6).

Se o tempo apertar: o bloco 4 e a etiqueta *resumida* do bloco 5 são o mínimo
útil; a etiqueta completa pode sair logo a seguir ao arranque.

---

## 0. Fechar os testes em curso

- [ ] Percorrer as secções 4 (Ingredientes), 5 (Receitas) e 6 (Fichas) do checklist e marcar/anotar ajustes.
- [ ] Testes que só se fazem à mão (o browser automático não consegue): escolher ficheiros (importar CSV, imagens do procedimento, foto do rótulo) e impressão do talão.
- [ ] Teste real da **leitura de rótulo por IA** com a `GEMINI_API_KEY` no servidor.
- [ ] Resto do checklist (Faturas, Vendas, Encomendas, Financeiro, Navegação e permissões).

## 1. Branches (Git)

Fluxo em `docs/FLUXO_GIT.md`. Script de verificação em `scripts/verificar.sh`.

- [x] Definir o modelo: `main` (produção, só recebe merges testados) · `develop` (integração) · `feature/*` (uma por funcionalidade) · `hotfix/*` (correções urgentes em produção).
- [x] Criar `develop` (feito 2026-09-24; `master` renomeado para `main`, etiqueta `v1.5.0` mantida) e passar a trabalhar em `feature/*` → `develop` → `main`.
- [ ] Etiquetar versões (`v1.0.0` na entrada em produção) e manter o `CHANGELOG.md` (está parado na 1.5.0 antiga).
- [ ] Proteger `main`/`develop` no remoto (merge só por pull request, verificações a passar).
- [x] Verificação mínima local: `bash scripts/verificar.sh` (analyze + testes + `node --check` dos hooks + migrations numa BD vazia).
- [ ] Correr essa verificação automaticamente (CI) — precisa de um repositório remoto (ver `docs/FLUXO_GIT.md`).
- [x] Documentar o fluxo e como se faz um hotfix (`docs/FLUXO_GIT.md`).
- [ ] Criar repositório remoto **privado** (cópia de segurança do código) e enviar `main`, `develop` e etiquetas.

## 2. Backups automáticos da base de dados

A BD é o PocketBase (SQLite em `pb_data/` + ficheiros enviados). **Decidido: Google Drive + rclone crypt + USB semanal. Plano em `docs/BACKUPS.md`, instalação em `pb/backup/LEIA-ME.md`.** Scripts e migration prontos e testados com rclone simulado.

- [x] Backups automáticos do próprio PocketBase por migration (03:00, guarda 7). Aplica-se ao reiniciar o servidor em produção.
- [ ] **Cópia fora da máquina** (outro disco/nuvem/S3): um backup só no mesmo PC não protege contra falha do disco.
- [x] Scripts `pb/backup/copia-externa.ps1` e `instalar-tarefas.ps1` (escritos e testados com rclone simulado).
- [ ] **No Mini PC:** instalar o rclone, ligar ao Google Drive, criar o remoto cifrado, guardar a chave e instalar a tarefa (`pb/backup/LEIA-ME.md`).
- [x] Cifra definida: rclone crypt (chave com o Mauro). Falta gerar a chave no Mini PC.
- [x] Script `teste-restauro.ps1` pronto (testado a partir de um backup real).
- [ ] Fazer o **primeiro restauro** a sério a partir da nuvem e registar o tempo. Repetir todos os meses.
- [x] Alerta por email se falhar (opcional, variáveis `BACKUP_*` em `pb\.env`).
- [ ] Configurar essas variáveis e o USB semanal (BitLocker + `copia-usb.ps1`).
- [x] Documentado em `docs/BACKUPS.md` e `pb/backup/LEIA-ME.md`.

## 3. Testes de segurança (só no nosso sistema, com autorização)

Ambiente: uma cópia descartável (nunca a produção). Objetivo: encontrar falhas antes de outros.

- [ ] **Isolamento entre empresas (multi-tenant)**: com dois utilizadores de empresas diferentes, tentar ler/alterar/apagar registos um do outro por API em *todas* as coleções e endpoints `/api/turnkey/*` (IDOR).
- [ ] **Papéis**: Leitura/Editor/Administrador a tentar o que não podem (escrever, apagar, mudar papéis, gravar a matriz de permissões, ver dados financeiros).
- [ ] **Endpoints próprios** (hooks): todos exigem autenticação? validam a empresa? o que acontece com dados inválidos/enormes?
- [ ] **Autenticação**: limite de tentativas de login, palavras-passe fracas, expiração de sessão, recuperação de conta.
- [ ] **Uploads** (imagens, PDFs, fontes, rótulos): tipos, tamanho máximo, nomes de ficheiro maliciosos.
- [ ] **HTML de impressão** (talão, DRE, futuras etiquetas): garantir que texto de clientes/produtos é escapado (XSS).
- [ ] **Segredos**: nenhuma chave no repositório nem nos logs/erros mostrados; `.env` fora do git; **rodar a chave do Vendus** (foi exposta antes) e confirmar as chaves de IA.
- [ ] **Painel de administração** do PocketBase: não exposto à internet (ou protegido); superutilizador com palavra-passe forte.
- [ ] **HTTPS**, cabeçalhos de segurança, CORS restrito ao domínio da app.
- [ ] **Dependências**: verificar versões do PocketBase, pacotes Flutter e npm em busca de vulnerabilidades conhecidas.
- [ ] Guardar os testes em `test/security/` (scripts repetíveis) e correr antes de cada versão.
- [ ] Relatório curto: o que se encontrou, o que se corrigiu, o que fica em risco aceite.

## 4. Página "Produtos Gookie" (nova)

Uma página com **tudo o que a Gookie produz** (produtos finais das fichas técnicas
e, se fizer sentido, intermédios), para ver de forma simples e clara a
**declaração nutricional** e a **lista de ingredientes** e imprimir etiquetas.

- [x] Nova página no menu (`paginasApp`, permissões por nível e cor na grelha) — branch `feature/produtos-gookie`.
- [x] Lista com pesquisa e estado de cada produto: nutrição **completa / incompleta** e alergénios (+ filtro "só os que faltam completar").
- [x] Detalhe do produto: nome, descrição, formato/peso, **declaração nutricional** (por 100 g e por unidade), **lista de ingredientes**, alergénios, conservação.
- [x] **Lista de ingredientes** conforme o Regulamento (UE) 1169/2011: por ordem decrescente de peso, alergénios destacados (negrito), ingredientes compostos com o seu detalhe; gerada a partir da ficha → receitas → ingredientes (a nutrição por 100 g já existe).
- [x] Campos novos na ficha/produto (migration `1707696000_ficha_rotulo.js`; falta ainda o texto "consumir até / de preferência antes de", que se decide na etiqueta): **descrição** (curta, para a etiqueta), **prazo de validade em dias**, **modo de conservação**, texto "consumir até / de preferência antes de".
- [x] Avisar quando faltar informação obrigatória (ex.: ingrediente sem nutrição, sem alergénios definidos).
- [x] Testes de unidade da lista de ingredientes (ordem, somas, alergénios) e das pendências.
- [ ] Nome de ingrediente **para o rótulo** (hoje usa o nome interno, ex. "Chocolate Negro 50% METRO Chef"): campo opcional "nome no rótulo".
- [ ] Ingredientes compostos comprados (ex. chocolate, com a sua própria composição): hoje entram como um só ingrediente.
- [ ] Incluir os **intermédios** (massas, recheios) na página, se se quiser.

## 5. Impressão de etiquetas

Primeira impressora: **papel térmico autocolante**. Dois modelos, escolhidos na hora de imprimir:

> **Antes de fechar o layout: confirmar a lei** — ver `docs/ROTULAGEM_LEGAL.md` (perguntas prontas para a ASAE/DGAV: isenção da declaração nutricional, lista resumida, tamanho de letra, lote, ℮). Não assumir nada como legal até haver resposta.

- **Completo** — nome, descrição, declaração nutricional em tabela, lista de ingredientes, alergénios, conservação, lote, fabrico e validade, dados do produtor (o que a norma da UE pede).
- **Resumido** — só o mínimo exigido pela norma da UE, para caber no papel mais pequeno.

Layout definido (etiqueta 50 × 80 mm: **25 mm** da 1.ª parte + **55 mm** depois da dobra):

```
Nome do produto            ┐ 1.ª parte: no máximo 25 mm
Descrição                  ┘
------------------------- (dobra)
Tabela nutricional, ingredientes, alergénios, etc.
Data de fabrico e validade
```

- [ ] Escolher o modelo (completo/resumido) e o **número de etiquetas** a imprimir.
- [ ] Campos **data de fabrico** (por omissão, hoje) e **data de validade** (por omissão, fabrico + prazo em dias do produto), editáveis; opcionalmente **lote**.
- [ ] Gerar a etiqueta em HTML/CSS com `@page { size: 50mm 80mm }` e reaproveitar o mecanismo de impressão já usado no talão/DRE (`core/printing/print_html.dart`).
- [ ] Ajustar os tamanhos de letra ao espaço (a norma tem tamanho mínimo de letra; em embalagens pequenas há regras próprias) e testar com a impressora real.
- [ ] Pré-visualização na app antes de imprimir.
- [ ] **Enviar as perguntas à ASAE/DGAV** (`docs/ROTULAGEM_LEGAL.md`) e registar as respostas.
- [ ] Guardar os **dados do produtor** (nome, morada) e incluí-los na etiqueta; **℮** como opção por produto, só se houver controlo de peso.
- [ ] Verificar com a norma (Reg. UE 1169/2011) e, se possível, com a ASAE/consultor: conteúdo mínimo obrigatório, isenções para embalagens pequenas, expressão da data.
- [ ] Mais tarde: outros tamanhos de papel e impressoras (guardar o formato como configuração).

### Dúvidas a resolver antes de desenhar a etiqueta

1. ~~Medidas~~ **Resolvido:** 50 mm de largura × 80 mm de altura = 25 mm (nome + descrição) + 55 mm (depois da dobra). Falta confirmar que a dobra fica no sentido do comprimento (80 mm).
2. Qual é a **impressora** (marca/modelo, resolução) e como liga (USB, rede, Bluetooth)? Se for necessário imprimir sem a janela do browser, teremos de usar outra via (ex.: comandos da própria impressora).
3. Os **dados do produtor** (nome, morada, NIF/contacto) entram na etiqueta completa? Onde ficam guardados?
4. Data de validade: "consumir até" ou "consumir de preferência antes de"? Varia por produto?
5. Os produtos vendidos ao balcão sem embalagem também precisam de etiqueta/informação de alergénios?

## 6. Ida para produção (go-live)

- [ ] Servidor definitivo (Mini PC): PocketBase como serviço, arranque automático, reinício em caso de falha.
- [ ] Domínio + **HTTPS** + acesso externo seguro (túnel/reverse proxy).
- [ ] Variáveis de ambiente de produção (`pb/.env`): IA, Vendus, SMTP, contabilidade (ver `pb/DEPLOY.md`); **chaves novas**.
- [ ] **`TURNKEY_DEV=0` no `pb/.env` de produção** — o `serve.ps1` liga-o por omissão (contas novas ficam “verificadas” sem email). Confirmar que está desligado.
- [ ] Criar a empresa real, utilizadores e papéis; carregar os dados iniciais (ingredientes, receitas, fichas, formatos).
- [ ] Definir a navegação e as permissões por nível (Configurações → Navegação e permissões).
- [ ] Ensaio geral do ciclo completo (comprar → produzir → stock → vender) com dados reais.
- [ ] Monitorização básica (espaço em disco, serviço ativo, erros) e quem é avisado.
- [ ] Plano de retrocesso: como voltar à versão anterior + restaurar backup.
- [ ] Congelar o código (`v1.0.0` em `main`) antes da data.

## 7. Pequenos ajustes já identificados

- [ ] Menu ⋮ da encomenda oferece "Cancelar" mesmo se já cancelada/entregue (esconder).
- [ ] `CHANGELOG.md` desatualizado.
- [ ] Impressão do talão nunca foi testada numa impressora real.
