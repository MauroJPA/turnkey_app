# Skills, conectores e ferramentas — o que foi usado no projeto

Objetivo: perceberes no futuro **o que foi usado, porquê, em que estado está
agora e se deves ligar ou desligar**. Atualizado em 2026-09-24.

> Como os números foram obtidos: contagem de chamadas no registo da sessão de
> trabalho longa da app (Encomendas, Financeiro, Faturas, Receitas, etc.).
> Cada definição de skill/conector ligado é enviada em **todas** as mensagens,
> por isso o que não se usa custa tokens sem dar nada em troca.

---

## 1. Conectores (serviços externos)

| Conector | Usado? | Estado agora | O que faz / para que serviria | Recomendação |
|---|---|---|---|---|
| **Canva** | Nunca (0 chamadas) | **Desligado** | Criar/editar designs gráficos (posts, etiquetas, cartazes). | Ligar só se pedires material de marketing/etiquetas da Gookie. |
| **Figma** | Nunca (0 chamadas) | **Desligado** | Ler desenhos do Figma para os converter em ecrãs Flutter. | Ligar só se tiveres um design no Figma para implementar. |
| **Claude Docs** | Nunca (0 chamadas) | **Desligado** | Documentos partilháveis/editáveis em equipa. | Ligar só se quiseres manuais/documentos partilhados fora do repositório. |
| **visualize** | Nunca | Ligado | Mostrar gráficos/diagramas na conversa. | Pode ficar; é pequeno (2 ferramentas). |
| **scheduled-tasks** | Nunca | Ligado | Tarefas agendadas (ex.: lembretes/rotinas). | Pode ficar. |
| **Claude in Chrome** | Nunca | Disponível | Controla o **teu** Chrome com as tuas sessões. | Não é preciso: os testes usaram o browser integrado. |

Como voltar a ligar: menu **+** do compositor → **Connectors** (ou pede-me
"liga o Figma"). Ficam também desligados por defeito nas conversas novas.

## 2. Ferramentas embutidas que realmente fizeram o trabalho

| Ferramenta | Chamadas | Para que serviu | Nota |
|---|---|---|---|
| **Browser integrado** (`Claude_Browser`: navegar, clicar, ler consola, `javascript_tool`…) | ~1 100 | **Verificar cada funcionalidade ao vivo** na app Flutter web (login, Encomendas, importação de receitas, editar procedimento…) antes de fazer commit; apanhou o ecrã em branco das Encomendas. | **Manter ligado.** É o que mais custa (capturas de ecrã) — ver dicas abaixo. |
| Bash / PowerShell | ~1 450 | `flutter analyze/test/build`, PocketBase descartável, git, curl. | Essencial. |
| Edit / Write / Read / Grep / Glob | ~2 100 | Editar e ler o código. | Essencial. |
| AskUserQuestion / EnterPlanMode / ExitPlanMode | 15 / 5 / 5 | Perguntar formato do CSV e regras de correspondência; planear funcionalidades grandes. | Manter. |
| WebSearch / WebFetch | 13 / 22 | Consultar documentação (PocketBase, APIs Vendus/IA). | Manter. |
| ScheduleWakeup, ToolSearch, mark_chapter, SendUserFile, ListSkills, SuggestSkills, mcp-registry | poucas | Apoio à sessão. | Sem impacto. |

## 3. Skills

| Skill | Origem | Usada? | Estado agora | O que ajudou / faria | Recomendação |
|---|---|---|---|---|---|
| **built-in-browser** | Claude (global) | Sim, como guia do browser integrado | Ligada | Regras de uso do painel do browser (tabs, aprovações, ler páginas como texto). | **Manter ligada** (testes da app). |
| **run** | Claude (global) | 1 vez | Ligada | Padrão para arrancar a app/servidor e interagir com ela em vez de só correr testes. | Manter (barata). |
| **artifact-design** | Claude (global) | 1 vez | Carrega a pedido | Regras para páginas/relatórios publicados como Artifact. | Sem ação (não fica sempre carregada). |
| **xlsx** | Claude (global) | Nunca | Ligada | Ler/criar folhas de cálculo e CSV (útil para exportar custos/vendas). | Manter se fores exportar dados; senão desligar. |
| **pdf** | Claude (global) | Nunca | Ligada | Ler/gerar PDFs (útil para faturas/DRE em PDF). | Manter se fores usar; senão desligar. |
| **docs, computer-use, chrome-browser, deep-research, import-memory, morning, skill-creator, pptx, docx** | Claude (global) | Nunca | Ligadas | Documentos partilháveis, controlar o ambiente de trabalho, o teu Chrome, pesquisas longas, importar memórias, "resumo da manhã", criar skills, PowerPoint, Word. | **Desligar** para este projeto (não fazem falta; poupam tokens). Desligar é feito nas definições da app — não consigo fazê-lo daqui. |
| **impeccable** (+ 4 agentes `impeccable-*`) | **Do projeto**, em `turnkey_app/.claude/` (não está no git) | Instalada; não a invoquei | Presente + **hooks ativos** | Revisão/polimento de design de interfaces. Os **hooks** em `settings.local.json` correm uma verificação depois de cada Edit/Write e ao terminar cada resposta, **se** o executável existir. O programa complementar não foi descarregado (recusado por segurança). | Como o executável não existe, os hooks não fazem nada. Se **não** a usas: apaga a pasta `.claude/skills/impeccable` + `.claude/agents/impeccable-*` (e os hooks) para reduzir contexto. Se queres polir o design da app, mantém e pede-me "usa o impeccable". |

## 4. O que fazer quando quiseres mudar

- **Voltar a ligar** um conector: pede-me ("liga o Canva") — aprovas na app — ou
  menu **+** → Connectors.
- **Ligar/desligar skills**: definições da app (secção Skills). Não é possível
  por comando meu.
- **Se eu precisar** de algo desligado, aviso-te em vez de improvisar (está
  registado na memória do projeto).

## 5. Dicas para gastar menos tokens (resumo)

1. Uma conversa nova por funcionalidade; tudo o essencial está na memória.
2. Capturas de ecrã pequenas e só quando preciso — preferir texto/consola.
3. Desligar skills e conectores sem uso (ver tabelas acima).
