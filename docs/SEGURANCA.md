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
para admin/owner e a matriz de acesso só para o owner; todos os `/api/turnkey/*` exigem sessão e
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
- Ainda **não há aviso automático** de novos registos (não há email configurado): consulta o
  filtro de vez em quando. Se quiseres, o próximo passo é uma página "Aprovações" na app só para
  ti e/ou um email quando alguém se regista.

## Segredos cifrados (token do Vendus e futuros)

- Cada empresa introduz o **seu** token em **Configurações → Integrações** (proprietário/admin).
  Fica em `segredos_empresa`, cifrado com **AES-256-GCM**; a coleção não tem acesso por REST,
  a resposta da app só diz "guardado (termina em …)" — o token **nunca volta a sair** do servidor.
- A chave que cifra é a `TURNKEY_ENC_KEY` (32 caracteres, só em `pb\.env`), **fora da base de
  dados e dos backups**: quem roubar um backup só leva texto cifrado. Gerar:
  `cd pb ; .\gerar-chave-cifra.ps1 -Gravar`. **Guarda uma cópia no gestor de palavras-passe** e
  nunca a mudes depois de haver tokens (ficam ilegíveis; teria de os reintroduzir).
- A sincronização do Vendus usa o token da própria empresa. A variável `VENDUS_API_KEY` do
  ambiente passa a ser só um recurso para a empresa de `VENDUS_SYNC_EMPRESA` e **já não serve a
  outras empresas** (antes, qualquer empresa podia importar vendas com a chave da Gookie).
- Para juntar outro serviço no futuro (ex.: outro software de vendas): acrescentar o nome em
  `pb/hooks/integracoes.pb.js` e usar `segredos.ler(app, empresaId, 'servico')`.
- Testes: `test/security/seguranca.py`, secção 7b (o ficheiro da BD e os logs não contêm o token).

## Atualização do PocketBase

Feita em 2026-09-24: **0.35.0 → 0.40.4** (traz as correções de OAuth2 e da queda do servidor).
Testada com os testes de segurança, com uma cópia dos dados reais e sem alterações necessárias
nos hooks. Script: `pb\atualizar-pocketbase.ps1` (descarrega, confere o SHA-256, faz cópia de
`pb_data` para `pb_data_antes_*`, guarda o binário antigo como `pocketbase.exe.antiga`).
Um servidor já a correr só passa à nova versão quando o reiniciares.

## O que **fica por fazer** (depende de ti / do servidor)

1. **Reiniciar o PocketBase** depois de gerar a chave de cifra (ver acima) — as migrations novas
   (aprovação, segredos, relações, limites) só se aplicam ao reiniciar.
2. **Rodar a chave do Vendus** (foi exposta antes): gerar uma nova no Vendus, guardá-la em
   Configurações → Integrações e **apagar `VENDUS_API_KEY` do `pb\.env`**. Confirmar as chaves de
   IA só em `pb\.env`.
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
   - **`TURNKEY_DEV` não pode estar ligado** (`pb/serve.ps1` liga-o para desenvolvimento).
   - Manter o servidor e o Windows atualizados.
4. ~~Registo público~~ **Decidido:** fica aberto, mas cada conta nova tem de ser aprovada por ti.
5. **Novas coleções/relações** têm de levar a cláusula "mesma empresa" (o teste avisa se faltar).
6. Sessão dura 7 dias; palavras-passe: mínimo 8 (o PocketBase não bloqueia palavras-passe fracas
   comuns).

## Riscos aceites / notas

- O administrador pode editar o perfil da empresa (desenho) e, tecnicamente, o campo `plano`
  (irrelevante enquanto não houver planos pagos).
- Papéis e "matriz de acesso" por página são **só da interface**; no servidor valem as regras
  base por papel (Leitura/Editor/Admin/Owner) testadas acima.
- Dependências Flutter estão várias versões atrás (mudanças de versão maior); não se conhecem
  falhas nelas, mas convém rever antes do próximo ciclo. `flutter pub outdated` para ver.
