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

## O que **fica por fazer** (depende de ti / do servidor)

1. **Atualizar o PocketBase** (está na 0.35.0). Duas falhas publicadas em 2026: **CVE-2026-44166**
   (pré-sequestro de conta com login OAuth2/Google — **usamos "Continuar com Google"**; corrigida na
   0.37.4) e **GHSA-84vh-m24q-wjjx** (um erro interno pode **derrubar o servidor**; corrigida na
   0.39.7). *Resumo de pesquisa web, a confirmar nas páginas oficiais.* Atualizar exige descarregar o
   binário novo e voltar a correr `scripts/verificar.sh` + os testes de segurança antes de o pôr
   na produção.
2. **Rodar a chave do Vendus** (foi exposta antes) e confirmar as chaves de IA só em `pb\.env`.
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
4. **Decidir:** manter o **registo público aberto**? Qualquer pessoa pode criar conta (fica sem
   empresa, mas pode criar uma nova). Para uso só da Gookie, fechar o registo (regra de criação
   `null`) e criar as contas pela app (Equipa) é mais seguro.
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
