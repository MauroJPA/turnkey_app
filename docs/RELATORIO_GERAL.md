# Relatório geral (Painel financeiro)

Painel financeiro → ícone do relatório (só administradores). Gera um ficheiro com **uma folha por relatório**,
seguindo a especificação de relatórios da estratégia (`Gookie-Estrategia/financeiro/especificacao-relatorios.md`).

- Formatos: Excel `.xlsx` ou `.zip` com um `.csv` por folha (UTF-8, vírgula).
- Datas `AAAA-MM-DD`; euros com ponto decimal; margens sem IVA.
- Período: últimos 12 meses (por omissão), 6 meses, este ano ou o período do painel.
- Código: `lib/src/features/finance/domain/relatorio_geral.dart` (monta as folhas — função pura, com testes em
  `test/relatorio_geral_test.dart`), `relatorio_exportar.dart` (escreve xlsx/csv), `application/relatorio_geral_service.dart`
  (carrega os dados) e `presentation/relatorio_geral_sheet.dart` (diálogo).

## Folhas e origem dos dados

| Folha | Conteúdo | Estado |
|---|---|---|
| Leia-me | período, IVA assumido e, por relatório, o que está completo / em falta | — |
| Resumo mensal | vendas (com/sem IVA), custo da matéria-prima vendida, despesas fixas/variáveis, depreciação, compras e resultado estimado, por mês | completo |
| 1 Vendas | uma linha por produto vendido: data, hora, canal, sabor, quantidade, preço c/ IVA, desconto, valor sem IVA, comissão, pagamento, tipo de cliente | parcial (ver abaixo) |
| 1 Equivalencia nomes | descrição na venda (nomes antigos, abreviaturas do POS) → sabor oficial | completo |
| 2 Producao | linhas da agenda de produção + unidades vendidas no dia | parcial |
| 2 Contagem diaria | por dia, local e sabor: abertura, assados, recebidos, enviados, vendidos, desperdício (com motivo), devia haver, sobra contada e diferença (da página Contagem diária) | completo se a contagem for usada |
| 3 Custo por sabor | custo por unidade (ingredientes + embalagem), preço, margem; `3 Componentes`, `3 Ingredientes` (preço de compra e data), `3 Historico precos` (faturas) | completo |
| 4 Despesas | faturas confirmadas por categoria + custos fixos/variáveis registados + depreciação | completo* |
| 5 Plataformas, 6 Pessoal, 8 Eventos, 9 Origem clientes | modelos por preencher (só cabeçalhos) | por preencher |
| 7 Tesouraria | entradas e saídas por mês | parcial |

\* Os custos registados são o valor **atual** repetido em cada mês (a app não guarda histórico de custos); a
categoria é deduzida do nome. O valor sem IVA só existe nas faturas.

## Dados que a app ainda não regista (ficam em branco)

- Vendas: **comissão do canal**, **tipo de cliente**. O **canal** só existe nas vendas onde foi definido
  (vendas novas do Vendus ficam "Loja física"; "Reimportar histórico" completa as antigas). Hora, método de
  pagamento e valor sem IVA dependem do que o Vendus devolve.
- Produção: **horas de trabalho** (sobras e desperdício já vêm da Contagem diária).
- **Extratos das plataformas de entrega**, **horas de pessoal**, **saldo bancário/dívidas**, **registo de
  eventos** e **origem dos clientes**.

## Como o resultado é calculado

`resultado = margem bruta sem IVA (vendas sem IVA − custo da matéria-prima VENDIDA) − despesas fixas − despesas
variáveis − depreciação`. As compras de ingredientes/embalagem aparecem numa coluna à parte para **não contar
o mesmo custo duas vezes**.
