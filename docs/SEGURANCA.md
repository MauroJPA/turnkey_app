# Segurança — testes, relatório e lista para a produção

Testes feitos **só no nosso sistema**, num PocketBase descartável (nunca na produção).
Repetíveis: correm no `scripts/verificar.sh` antes de juntar código.

```bash
python test/security/seguranca.py   # isolamento, papéis, endpoints, uploads, login (servidor descartável)
python test/security/estatico.py    # segredos no repositório/histórico, .env, hooks, versões
flutter test test/security          # XSS nas páginas de impressão (talão, DRE, nutrição, etiqueta)
```

Nível de cada resultado: **FALHA** (corrigir antes de juntar), **AVISO** (risco de configuração
do servidor), **OK**.

## O que se encontrou e corrigiu (2026-09-24)

| # | Gravidade | Problema | Correção |
|---|---|---|---|
| 1 | **Crítica** | O registo público deixava escolher `empresa` e `papel`: qualquer pessoa que conhecesse o id de uma empresa registava-se como **proprietária** dela. | Migration `1707955201_seguranca.js`: a regra de criação recusa `empresa`/`papel`. |
| 2 | Alta | **XSS no talão:** o nome do cliente ia sem escape para o `<title>` da página de impressão (`</title><script>…`). A página corre na origem da app e pode ler a sessão. | `abrirImpressao` escapa o título (`core/printing/html_escape.dart`) + teste com texto malicioso em todos os construtores de HTML. |
| 3 | Média | Um administrador conseguia **rebaixar um proprietário** ou outro administrador. | `pb/hooks/team.pb.js`: o admin só altera editores e leitores. |
| 4 | Média | Faturas (ficheiros) abriam **sem sessão** com o URL. | Campo `faturas.ficheiro` protegido; a app pede um token de ficheiro (2 min) antes de abrir. |
| 5 | Média | Um utilizador da empresa B conseguia criar registos seus a **apontar para registos da empresa A** (ex.: linha de receita com um ingrediente de outra empresa → misturava preços/custos). 26 relações. | Migration `1707955202_relacoes_mesma_empresa.js`: cláusula "o registo relacionado tem de ser da mesma empresa" nas regras de criar/atualizar. |
| 6 | Média | **Sem limite de tentativas de login** (força bruta). | Limite de pedidos ligado (15 logins/min por IP, 600 pedidos/10 s). |
| 7 | Baixa | Logótipo da empresa aceitava qualquer tipo de ficheiro (ex.: HTML). | Só JPEG/PNG/WebP, máx. 3 MB. |
| 8 | Baixa | Sugestões podiam ser enviadas em nome de outra empresa/utilizador. | Regra de criação exige a própria empresa/autor. |

Confirmado **sem falhas**: isolamento entre empresas em todas as coleções (listar, ler, alterar,
apagar, criar, filtros); o papel Leitura não escreve em lado nenhum; configuração de custos só
para admin/owner e a matriz de acesso só para o owner; todos os `/api/gc_turnkey/*` exigem sessão e
recusam ids de outra empresa; dados inválidos/enormes não dão erro 500 nem revelam caminhos
internos; uploads (tamanho, tipo, nome malicioso); nada de segredos no repositório nem no histórico.

## Aprovação de registos (2026-09-24)

Qualquer pessoa pode criar conta, mas **só entra depois de tu a aprovares**.

- Uma conta nova fica com `aprovado = falso`: ao entrar vê o ecrã **"A tua conta aguarda
  aprovação"**, não consegue criar empresa nem ver dados de ninguém.
- **Como aprovar (só tu podes):** abre o painel de administração do PocketBase
  (`http://127.0.0.1:8090/_/`, com a conta de **superutilizador**) → coleção **users** →
  filtro `aprovado = false` → abre o utilizador → marca **aprovado** → Guardar. Podes também
  fazê-lo direto na base de dados (`UPDATE users SET aprovado = 1 WHERE email = '...'`).
  Nenhum utilizador da app (nem proprietários) consegue mudar este campo.
- O utilizador carrega em **"Verificar novamente"** (ou volta a entrar) e segue para criar a
  empresa.
- Contas que já existiam ficaram aprovadas. Membros criados por um proprietário (Equipa)
  nascem aprovados.
- **Desde a 1.83.0 aprovas dentro da app** (Configurações → Aprovações de contas, e cartão "Contas por aprovar" no Início), sem
  abrir o `/_/`. Só o *operador da plataforma* vê e decide: os emails em `GC_TURNKEY_OPERADORES` (`.env` do servidor) ou, se a variável
  não existir, o proprietário aprovado mais antigo. Os endpoints (`/api/gc_turnkey/aprovacoes…`) estão cobertos pelos testes de segurança.

## Segredos cifrados (token do Vendus e futuros)

- Cada empresa introduz o **seu** token em **Configurações → Integrações** (proprietário/admin).
  Fica em `segredos_empresa`, cifrado com **AES-256-GCM**; a coleção não tem acesso por REST,
  a resposta da app só diz "guardado (termina em …)" — o token **nunca volta a sair** do servidor.
- A chave que cifra é a `GC_TURNKEY_ENC_KEY` (32 caracteres, só no `.env` do servidor), **fora da base de
  dados e dos backups**: quem roubar um backup só leva texto cifrado. Gerar:
  `bash gc_turnkey.sh instalar` (no servidor Linux; gera-a sem a mostrar) ou `pb\gerar-chave-cifra.ps1 -Gravar` (PC de desenvolvimento). **Guarda uma cópia no gestor de palavras-passe** e
  nunca a mudes depois de haver tokens (ficam ilegíveis; teria de os reintroduzir).
- A sincronização do Vendus usa o token da própria empresa. A variável `VENDUS_API_KEY` do
  ambiente passa a ser só um recurso para a empresa de `VENDUS_SYNC_EMPRESA` e **já não serve a
  outras empresas** (antes, qualquer empresa podia importar vendas com a chave de outra empresa).
- Para juntar outro serviço no futuro (ex.: outro software de vendas): acrescentar o nome em
  `pb/hooks/integracoes.pb.js` e usar `segredos.ler(app, empresaId, 'servico')`.
- Testes: `test/security/seguranca.py`, secção 7b (o ficheiro da BD e os logs não contêm o token).

## Atualização do PocketBase

Feita em 2026-09-24: **0.35.0 → 0.40.4** (traz as correções de OAuth2 e da queda do servidor).
Testada com os testes de segurança, com uma cópia dos dados reais e sem alterações necessárias
nos hooks. No PC de desenvolvimento: `pb\atualizar-pocketbase.ps1`; no servidor a versão vem do `Dockerfile`/`PB_VERSION` (descarrega, confere o SHA-256, faz cópia de
`pb_data` para `pb_data_antes_*`, guarda o binário antigo como `pocketbase.exe.antiga`).
Um servidor já a correr só passa à nova versão quando o reiniciares.

## Revisão de 2026-10-06 (v1.80.0)

Auditoria ao código e ao servidor em produção (só leitura). **Confirmado OK:** o servidor só se vê dentro da tailnet (o nome
`…ts.net` não existe no DNS público: não há *Funnel*); sem sessão a API devolve listas vazias/401; os hooks só falam com sítios
fixos (Vendus, Gemini, Anthropic) e o `qpdf` recebe só números validados (sem shell); filtros sempre parametrizados; ficheiros
de faturas protegidos; contentor em `127.0.0.1`, sem root, `GC_TURNKEY_DEV=0`, descarga do PocketBase com SHA-256 conferido.

**Corrigido nesta versão:** faltavam *Content-Security-Policy*, *Strict-Transport-Security*, *Referrer-Policy* e
*Permissions-Policy* (agora no hook `web_cabecalhos.pb.js`, com teste), cache da app sem `no-cache` (versões novas ficavam presas
no navegador) e o contentor tinha capacidades a mais (`cap_drop: ALL`, `no-new-privileges`).

**Continua por fazer (por ti, no servidor):**
1. **Painel `/_/` acessível na tailnet** (responde 200 a qualquer máquina da tailnet; só a palavra-passe o protege). Limitar por ACL
   do Tailscale (só o teu PC/telemóvel) ou mudar a porta; superutilizador com palavra-passe forte e única e **MFA** ligado.
2. **Proxy fiável**: em *Definições → Application → Trusted proxy headers* pôr `X-Forwarded-For` — sem isso o limite de pedidos trata
   toda a gente como um só IP (e um abuso bloqueia o login a todos).
3. ~~**MFA/OTP** nas contas dos proprietários~~ — feito na 1.103.0 (ver abaixo): configurar o SMTP e ligar em Configurações → "Verificação em 2 passos". Palavras-passe com mínimo de 12 continua por decidir.
4. **Quiosque**: usar uma conta própria de papel *Editor* (nunca a do proprietário) no aparelho da loja; o cartão NFC identifica a
   pessoa, mas a sessão do aparelho é a da conta.
5. **Backups**: confirmar cópia **fora do servidor e cifrada** (ver `docs/BACKUPS.md`) e testar uma restauração por trimestre.
6. Manter o PocketBase e o Debian atualizados; `flutter pub outdated` antes de cada ciclo.
7. Dados pessoais (nomes e cartões da equipa): são dados pessoais (RGPD) — só o necessário, apagar quando a pessoa sai.

## Verificação em 2 passos e testes dos backups (1.103.0)

- **2 passos para quem administra**: usa o MFA do PocketBase com **palavra-passe + código de 6 dígitos por email** (OTP, 5 minutos).
  A regra `papel = 'owner' || papel = 'admin'` aplica-se só a estas contas; equipa e **quiosque não pedem código** (o tablet da loja
  tem de continuar a abrir sozinho). Só o proprietário liga/desliga (`POST /api/gc_turnkey/seguranca/2fa`) e **só liga se o SMTP estiver
  ativo**, para não deixar ninguém de fora. Quem tem sessão aberta não é afetado até a sessão terminar (5 dias).
- **Contas sem 2 passos podem entrar só com um código por email** (o PocketBase trata o OTP como um método de entrada); é o mesmo risco que
  a recuperação de palavra-passe por email, por isso o email da conta é o ponto a proteger.
- **Trancado fora?** Entrar em `/_/` como superutilizador → Collections → *users* → Options → desligar *Multi-factor authentication* (e *One-time password*).
  Ou, no servidor, repor a regra com o superutilizador e `pocketbase superuser upsert`.
- **Backups**: o servidor testa todos os domingos o último `.zip` (`unzip -t` + existência de `data.db`), o script `teste-restauro.sh`
  arranca-o num contentor descartável todos os meses e o espaço livre é medido com `df` (aviso abaixo de 15 % ou 2 GB). Os resultados
  são escritos em `pb_data/backup_integridade.json` e `backup_restauro.json` (sem caminhos nem segredos) e chegam à app e ao resumo diário.
- Testes automáticos: `7a3` (backups) e `7a3b` (2 passos, com um servidor SMTP falso) em `test/security/seguranca.py`.

## Formações e certificados (1.106.0)

- `formacoes` guarda dados pessoais (certificados, ficha de aptidão): cada pessoa só vê/edita os seus registos (`user = @request.auth.id`); a administração
  vê e regista os de toda a equipa; a Leitura não vê nada. Quem não é administração não consegue passar um registo para outra pessoa.
- O ficheiro é `protected` (precisa de token de ficheiro curto), só PDF/imagem e até 10 MB. O resumo diário só diz "Nome: título — caduca em N dias" (nada de conteúdo do documento).
- Testes: `7a10. Formações e certificados das pessoas` em `test/security/seguranca.py`.

## Avisos por Telegram/email (1.85.0)

O token do bot do Telegram guarda-se **cifrado** como o do Vendus (`segredos_empresa`, serviço `telegram`) e nunca sai do servidor;
as mensagens de erro não o incluem. Os endpoints de teste e de deteção do chat são só para owner/admin e só usam o token da própria
empresa. O WhatsApp está no código mas **desligado** por omissão (precisa de variáveis de ambiente). Os avisos só enviam resumos
(nomes de controlos, ingredientes, custos a pagar) — nenhum dado de clientes.

## O que **fica por fazer** (depende de ti / do servidor)

1. **Reiniciar o PocketBase** depois de gerar a chave de cifra (ver acima) — as migrations novas
   (aprovação, segredos, relações, limites) só se aplicam ao reiniciar.
2. **Rodar a chave do Vendus** (foi exposta antes): gerar uma nova no Vendus, guardá-la em
   Configurações → Integrações e **apagar `VENDUS_API_KEY` do `.env`**. Confirmar as chaves de
   IA só no `.env`.
3. **Servidor definitivo:**
   - **HTTPS** obrigatório e cabeçalhos de segurança no proxy: `Strict-Transport-Security`,
     `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Content-Security-Policy`.
   - **Bloquear `/_/`** (painel de administração) fora da rede local/VPN; superutilizador com
     palavra-passe forte e única.
   - **CORS** restrito ao domínio da app (por omissão é `*`; risco baixo porque a sessão vai em
     cabeçalho, não em cookie).
   - **Proxy fiável:** se houver proxy/túnel à frente, configurar em *Definições → Trusted proxy
     headers* (ex.: `X-Forwarded-For`), senão o limite de pedidos trata todos os utilizadores
     como um só IP.
   - **`GC_TURNKEY_DEV` não pode estar ligado** (o `pb/serve.ps1` liga-o só no PC de desenvolvimento; o contentor força `GC_TURNKEY_DEV=0`).
   - Manter o Debian atualizado (`unattended-upgrades`) e o PocketBase na versão mais recente segura.
4. ~~Registo público~~ **Decidido:** fica aberto, mas cada conta nova tem de ser aprovada por ti.
5. **Novas coleções/relações** têm de levar a cláusula "mesma empresa" (o teste avisa se faltar).
6. Sessão dura 7 dias; palavras-passe: mínimo 8 (o PocketBase não bloqueia palavras-passe fracas
   comuns).

## Quiosque sem ligação (1.90.0)

- Os registos tocados sem ligação ficam no `localStorage` do aparelho (`quiosque_fila`) até chegarem ao servidor; o mesmo aparelho
  guarda também a última lista de tarefas e de pessoas (nomes e números de série dos cartões) para o ecrã de espera.
  Convém que o telemóvel do quiosque tenha bloqueio de ecrã e seja só da empresa.
- Cada registo leva um id próprio (15 caracteres): reenviar não duplica (o servidor recusa o id repetido e a app dá-o por enviado)
  e uma empresa não consegue ver nem alterar o registo de outra por reutilizar o id (testado em `teste_quiosque_offline`).
- Sem endpoints novos nem alterações de regras no servidor.

## Ponto e dados das pessoas (1.92.0)

- `ponto_registos` (horas de entrada/saída) são dados pessoais dos colaboradores (RGPD): o proprietário/administrador lê todos; cada
  conta lê só os seus (campo `user`); quem marca no quiosque (papel Editor) cria mas não lê os dos outros. Só o proprietário/administrador
  corrige ou apaga, e a correção guarda a hora original.
- `GET /api/gc_turnkey/ponto/estado` devolve apenas a última marcação (chave da pessoa, tipo, hora) das últimas 36 horas; sem nomes.
- A página "Pessoas" vem oculta para o papel Leitura. A hora vem do relógio do aparelho que marca (no quiosque offline é a hora real da
  marcação); o servidor guarda também a data de criação.

## Férias e ausências (1.93.0)

- `ferias`: quem não é administrador só consegue criar pedidos (`estado = pedido`) para a sua própria conta; só o proprietário/administrador
  aprova, recusa ou regista por outros. Todos veem as férias aprovadas; baixas, faltas e pedidos só o próprio e a administração (dados de
  saúde e pessoais). Cada um apaga só os seus pedidos ainda por decidir.
- `ferias_direito` (dias de férias por pessoa e ano): só a administração escreve; cada um lê o seu.

## App sem ligação (1.102.0)

- `web/gc_sw.js` (service worker) guarda só os **ficheiros da app** (código, CanvasKit, tipos de letra) neste aparelho; nunca guarda
  pedidos à API nem respostas de dados, nem o `version.json`. Rede primeiro: com ligação a app é sempre a versão do servidor.
- A sessão deixa de terminar por falta de rede (só quando o servidor a recusa: 400/401/403/404). O token continua no armazenamento
  seguro do navegador; um telemóvel do quiosque deve ter bloqueio de ecrã.
- A app já não pede o CanvasKit nem tipos de letra a `gstatic.com` (`--no-web-resources-cdn`): menos dependência externa; a CSP
  continua a permitir só a própria origem para o essencial.

## Equipamentos nas faturas (2.5.0)

- `POST /faturas/{id}/aplicar` aceita, por linha, um objeto `equipamento` (`nome`, `custo`, `vidaUtilAnos`) e cria o registo em
  `equipamentos` (empresa da própria fatura, nunca a do pedido). **Só proprietário/administrador** — como a lista de equipamentos
  (`createRule`); o Editor recebe 403 e a transação desfaz-se por inteiro. Custo e vida útil têm de ser > 0 (senão a linha fica por decidir).
- `faturas_itens.equipamento` liga a linha ao registo criado: reaplicar a fatura salta as linhas já aplicadas (não duplica).
- Testado em `teste_faturas_equipamento` (403 do Editor, ligação, reaplicar, valores inválidos, isolamento entre empresas).

## PDF dentro da app (2.6.0)

- O PDF das faturas é convertido em imagens **no próprio aparelho**, com o PDF.js (Mozilla, Apache-2.0, `pdfjs-dist` 4.10.38, build
  *legacy*) que vai **dentro da app** (`web/pdfjs/`, SHA-256 do pacote em `web/pdfjs/LEIA-ME.txt`). Não se carrega nada de CDN e o PDF
  não sai do aparelho; o endereço do ficheiro continua a ser o URL assinado de curta duração.
- A CSP não mudou: `script-src 'self'`, `worker-src 'self' blob:`. O PDF.js corre com `isEvalSupported: false` (sem `eval`/`new Function`).
- PDFs com scripts embebidos (JavaScript do PDF) não são executados: só se desenham as páginas.

## Repor palavras-passe e remover membros (2.7.0)

- `POST /team/members/{id}/senha` (só proprietário/administrador da mesma empresa): gera uma palavra-passe **provisória** aleatória
  (`$security.randomStringWithAlphabet`, 10 caracteres sem ambíguos), devolve-a **uma só vez**, fecha as sessões da conta
  (`refreshTokenKey`) e marca `users.senha_provisoria`. O proprietário repõe a de qualquer pessoa menos a própria; o administrador só a de
  Editor/Leitura. Fica um registo no log do servidor (quem repôs, para quem) — nunca a palavra-passe.
- `users.senha_provisoria` só muda pelos endpoints do servidor (`guards.pb.js` recusa alterações pela API normal). Com a marca, a app
  só deixa a pessoa chegar ao ecrã "Escolhe a tua palavra-passe" (`POST /conta/senha`: mínimo 8, diferente da provisória, fecha as sessões).
- `DELETE /team/members/{id}`: apaga a conta; não se apaga a própria nem o último proprietário; o administrador só remove Editor/Leitura.
  Os registos que ela criou ficam (guardam o nome); desaparecem só as preferências do menu e o cartão do quiosque (relações em cascata).
- Testado em `teste_equipa_acessos` (permissões, outra empresa, sessão antiga a fechar, provisória → nova, remoção) e nas rotas de `ROTAS`.

## Vigia de segurança do servidor (2.8.0)

- `deploy/seguranca/vigia.py` (Python, só biblioteca padrão) corre como root de 10 em 10 minutos (timer systemd, com `ProtectSystem=strict`
  e escrita só na pasta de estado e em `data/`). **Só lê**: SSH (journal), contas, chaves, cron/systemd, rede (`ss`, Docker, Tailscale),
  processos, ficheiros da app (hashes) e a base de dados do PocketBase **em modo só de leitura** (superutilizadores, proprietários,
  registos de pedidos). Nunca altera o sistema, nunca guarda chaves, palavras-passe nem conteúdo de ficheiros (só hashes e nomes).
- Aprende uma *baseline* na 1.ª ronda (`/var/lib/gc_turnkey-vigia`, só root) e alerta do que muda; regras duras para o que nunca é normal
  (mineradores, programas a correr de /tmp, 2.º uid 0, contas sem palavra-passe, `ld.so.preload`, padrões `curl|sh`/`base64 -d`/`/dev/tcp`);
  liga sinais ("possível intrusão"). Limite honesto: se o servidor já estava comprometido ao instalar, só as regras duras avisam.
- Resultado: `data/seguranca_vigia.json` (sem segredos). A app (`seguranca_vigia.pb.js`) só o mostra ao **operador da plataforma** (o dono
  do servidor, ver `operador.js`); os outros utilizadores não veem nem aceitam alertas. "Já verifiquei" escreve `data/seguranca_acks.json`
  (o vigia lê só os `id`, que tem de existir nos alertas atuais).
- Avisos: a app avisa **uma vez** por alerta novo (Telegram/email do dono) e se o vigia parar (sem dados há 40 min); o `/etc/gc_turnkey-vigia.conf`
  (modo 600) aceita um Telegram direto opcional.
- Testado em `test/seguranca/test_vigia.py` (cenários de invasão simulados) e `teste_vigia` (app ↔ vigia, permissões, ficheiro estragado).

### "Explicar com IA" nos alertas do vigia (2.9.0)

- **Só com o teu clique**, alerta a alerta: nada é enviado sozinho. Antes de enviar, a app mostra o **texto exato** (pré-visualização, `previa: true`, que não sai do servidor) e para onde vai (Gemini ou Claude, o mesmo das faturas).
- O **servidor** monta o pedido (`vigia_ia.js`), não a app: só o tipo de alerta, o texto genérico e o "o que fazer", mais os títulos dos outros alertas ativos (para dar contexto). **Nunca saem**: IPs (trocados por "IP-público-1", "IP-Tailscale-1"…), emails, nomes de utilizadores e de aparelhos, caminhos com utilizadores, hashes, chaves e palavras-passe.
- A resposta é **limpa** antes de chegar à app: comandos só de leitura são mantidos; qualquer comando que apague, escreva, reinicie, instale ou faça `curl|sh` é **descartado**. A app nunca corre nada sozinha: só mostra o comando para copiares.
- Limites: 20 explicações por dia; as últimas 30 ficam guardadas (`data/seguranca_ia.json`) e reabrem sem voltar a enviar. Só o dono do servidor (operador) pode pedir. Sem chave de IA configurada, o botão não aparece.
- Testado em `test/seguranca/test_vigia_ia.js` e `teste_vigia_ia` (servidor Gemini falso: texto enviado sem IPs/emails, comando perigoso removido, limite, cache, outras contas recusadas).

### Telegram com botões (2.15.0)

- Mensagens com botões (aprovar/recusar férias, "Saída às HH:MM", "Já verifiquei" do vigia) **só vão para conversas privadas** (chat com id positivo): num grupo qualquer membro os poderia carregar.
- O servidor não tem endereço público: de minuto a minuto (`telegram_botoes.pb.js`) pergunta ao Telegram (`getUpdates`, só `callback_query`) o que foi carregado. O `offset` fica em `pb_data/telegram_offset_<empresa>.json`; os avisos de saída já feitos em `telegram_avisados.json`.
- Cada carregamento só é tratado se: vem do chat configurado da empresa (privado) e do próprio utilizador desse chat; a assinatura (HMAC-SHA256 com o token do bot sobre `tipo|alvo|empresa`) bate certo; e o estado atual o permite (só se aprova o que está "por aprovar", só se marca a saída de quem ainda está dentro, etc.). Alertas **críticos** do vigia nunca se aceitam por aqui.
- O token do bot continua cifrado em `segredos_empresa`; não vai em mensagens, respostas, nem registos (os erros do cron tiram `bot<token>`).
- Testado em `teste_telegram_botoes` (Telegram falso): assinatura falsa, outro chat, grupo, outra pessoa, formato errado, tipo desconhecido, repetição, outra empresa.

## Tarefas da equipa (2.19.0)

- Quatro coleções novas (`quadros`, `quadro_colunas`, `tarefas`, `tarefa_comentarios`), todas presas à empresa: só a própria empresa as vê; a **Leitura vê mas não escreve** (a única exceção: marcar como lida uma menção a si própria, só o campo `lida_por`).
- Ninguém escreve em nome de outro (`autor` = quem está autenticado) e nada muda de empresa, de quadro ou de autor depois de criado. A fase de uma tarefa tem de ser do mesmo quadro (também ao mover).
- Responsáveis, menções e `lida_por` só aceitam pessoas da mesma empresa.
- Apagar tarefas, comentários e quadros: o autor ou a administração. Uma fase com tarefas não se apaga (`tarefas.coluna` sem cascata); apagar um quadro apaga as tarefas primeiro (`tarefas.pb.js`, na mesma transação) e com elas os comentários.
- Sem endpoints novos: tudo pelas regras do PocketBase; o tempo real (subscrições) respeita as mesmas regras de leitura.
- Testado em `teste_tarefas` (50 verificações) e na matriz "Leitura não escreve".

### Menções no Telegram de cada pessoa (2.20.0)

- Cada pessoa liga o **seu** Telegram ao bot da empresa (`telegram_pessoas`): a app pede um código (`POST /api/gc_turnkey/telegram/pessoal/ligar`) e abre `t.me/<bot>?start=<código>`; a sondagem de minuto a minuto apanha o "/start <código>" e grava o chat. O código tem 24 caracteres ao acaso, é de **uso único**, vale **30 minutos**, está **escondido da API** (campo `hidden`) e só vale em **conversa privada** vinda da própria pessoa (nem grupos, nem outra pessoa no mesmo chat).
- Só o servidor grava ligações (create/update sem regra). Cada pessoa vê e desliga a sua; a administração vê e desliga as da empresa; outra empresa não vê nada.
- As menções só vão para quem foi mencionado (nunca para quem escreve), só se o Telegram da empresa estiver ligado e só para quem ainda é da empresa. Editar um comentário só avisa quem passou a estar mencionado.
- A sondagem passa a ler também as mensagens que chegam ao bot (não só os botões) e corre em qualquer empresa com o Telegram ligado; os botões continuam a valer só na conversa privada configurada. Os chats que falaram com o bot ficam em `pb_data/telegram_chats_<empresa>.json` para o "Detetar o meu chat" (que já não os veria no Telegram).
- Endpoints novos (qualquer pessoa da empresa, só sobre o próprio Telegram): `.../pessoal/ligar`, `.../pessoal/verificar` (corre a sondagem da sua empresa), `.../pessoal/testar`. O token nunca vai em respostas nem em mensagens; os erros tiram `bot<token>`.
- Testado em `teste_telegram_pessoal` (Telegram falso): códigos errado, expirado e reutilizado, grupo, outra pessoa, isolamento entre empresas, escrita à mão recusada, menções (autor excluído, sem repetir ao editar, Telegram desligado), teste, desligar.

## Papéis personalizados (2.21.0)

- `papeis_personalizados` (nome, papel **base** admin/editor/viewer, ajustes por página): só o **proprietário** cria, muda e apaga; a equipa só lê (para a app aplicar o seu); outra empresa não vê. Nunca há base de proprietário.
- `users.papel_personalizado` só muda pelos endpoints da equipa (`PATCH/POST /api/gc_turnkey/team/members`), que põem também `users.papel` = papel base; o `guards.pb.js` recusa mudá-lo pela API normal (ninguém se dá um papel a si próprio). As regras de sempre: o administrador só dá papéis de base Editor/Leitura e só a Editores/Leitores; o proprietário nunca leva papel personalizado; um papel de outra empresa é recusado.
- Mudar o papel base de um papel personalizado muda o `papel` das pessoas que o têm (`papeis_personalizados.pb.js`); apagar o papel deixa-as só com o papel base.
- **O que o servidor garante é o papel base.** Os ajustes por página (Oculto/Só ver) são da interface, como a matriz de acesso: escondem e bloqueiam páginas na app, mas não mudam as regras dos dados (ex.: um "Balcão" de base Editor com a Contabilidade oculta não a vê na app, mas o servidor deixar-lhe-ia ler esses dados por API, como a qualquer Editor). Para restringir dados de verdade, escolha uma base mais restrita (ex.: Leitura).
- Testado em `teste_papeis_personalizados` (23 verificações).

## Riscos aceites / notas

- O administrador pode editar o perfil da empresa (desenho) e, tecnicamente, o campo `plano`
  (irrelevante enquanto não houver planos pagos).
- Papéis e "matriz de acesso" por página são **só da interface**; no servidor valem as regras
  base por papel (Leitura/Editor/Admin/Owner) testadas acima.
- Dependências Flutter estão várias versões atrás (mudanças de versão maior); não se conhecem
  falhas nelas, mas convém rever antes do próximo ciclo. `flutter pub outdated` para ver.
