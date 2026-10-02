/// <reference path="../pb_data/types.d.ts" />

// Prompts e validação das respostas da IA para o Financeiro:
//   - organizar custos em fixos / variáveis
//   - dicas mensais a partir dos números do painel financeiro
//
// Cada função exportada é autocontida (auxiliares como closures) porque o
// require() do PocketBase não mantém de forma fiável a visibilidade entre
// funções de topo — mesmo padrão de ai.js.

// custos: [{ id, nome, tipo: 'fixo'|'variavel', valor_mensal, notas }]
function pedidoClassificar(custos) {
  var sistema =
    'És um consultor financeiro de uma pequena empresa de pastelaria/cookies ' +
    'em Portugal. Classifica cada custo mensal como "fixo" ou "variavel" ' +
    'segundo ESTA definição da empresa:\n' +
    '- FIXO: custo que NÃO conseguimos eliminar sem fechar ou mudar a ' +
    'estrutura do negócio e que se paga mesmo que se venda zero (renda, ' +
    'salários da equipa, seguros, contabilista, licenças e taxas obrigatórias, ' +
    'empréstimos/leasing, água/luz/gás de base, internet e telefone ' +
    'essenciais, software indispensável).\n' +
    '- VARIÁVEL: custo que podemos REDUZIR ou CORTAR (por um período ou para ' +
    'sempre) para a empresa não quebrar, ou que sobe/desce com a produção e ' +
    'as vendas (marketing e publicidade, subscrições e apps não essenciais, ' +
    'comissões de plataformas, entregas e portes, consumíveis e embalagens ' +
    'comprados conforme as vendas, manutenção discricionária, formações, ' +
    'consumo de eletricidade/gás do forno, horas extra, trabalho temporário).\n' +
    'Critério de desempate: "se for preciso, consigo cortá-lo ou reduzi-lo de ' +
    'forma relevante sem fechar?" — sim = variavel, não = fixo. ' +
    'Em "motivo" explica numa frase curta (máx. 120 caracteres). ' +
    'Em "acao" diz o que fazer se o dinheiro apertar: "manter" (essencial), ' +
    '"reduzir" (negociar ou gastar menos), "pausar" (cortar temporariamente) ' +
    'ou "cortar" (prescindível). Os custos fixos levam quase sempre "manter". ' +
    'Em "dica" (opcional, máx. 140 caracteres) uma ideia concreta para ' +
    'reduzir ou renegociar, ou null. ' +
    'Responde APENAS com JSON válido, sem texto à volta nem cercas de código. ' +
    'Formato: {"sugestoes":[{"id":string,"tipo":"fixo"|"variavel",' +
    '"motivo":string,"acao":"manter"|"reduzir"|"pausar"|"cortar",' +
    '"dica":string|null}]}. Uma entrada por custo, com exatamente os ids dados.';
  var lista = [];
  for (var i = 0; i < custos.length; i++) {
    var c = custos[i];
    lista.push({
      id: c.id,
      nome: c.nome,
      tipo_atual: c.tipo,
      valor_mensal: c.valor_mensal,
      notas: c.notas || '',
    });
  }
  return {
    sistema: sistema,
    instrucao: 'Custos da empresa (JSON): ' + JSON.stringify(lista) + '. Só JSON.',
  };
}

// dados: o JSON devolvido pela IA; custos: os mesmos da função acima.
// Devolve só entradas válidas (ids conhecidos, valores dentro dos enums).
function limparSugestoes(dados, custos) {
  var lista = [];
  if (dados && Array.isArray(dados.sugestoes)) lista = dados.sugestoes;
  else if (Array.isArray(dados)) lista = dados;
  var porId = {};
  for (var i = 0; i < custos.length; i++) porId[custos[i].id] = custos[i];
  var acoes = ['manter', 'reduzir', 'pausar', 'cortar'];
  var corta = function (v, max) {
    var t = (v === null || v === undefined ? '' : String(v)).trim();
    return t.length > max ? t.substring(0, max - 1) + '…' : t;
  };
  var vistos = {};
  var out = [];
  for (var j = 0; j < lista.length; j++) {
    var s = lista[j];
    if (!s || typeof s !== 'object') continue;
    var id = String(s.id || '');
    var c = porId[id];
    if (!c || vistos[id]) continue;
    vistos[id] = true;
    var tipo = s.tipo === 'variavel' ? 'variavel' : s.tipo === 'fixo' ? 'fixo' : c.tipo;
    var acao = acoes.indexOf(s.acao) >= 0 ? s.acao : 'manter';
    out.push({
      id: id,
      nome: c.nome,
      valorMensal: c.valor_mensal,
      tipoAtual: c.tipo,
      tipoSugerido: tipo,
      motivo: corta(s.motivo, 160),
      acao: acao,
      dica: corta(s.dica, 180),
    });
  }
  return out;
}

// resumo: { periodo:{label,desde,ate}, atual:{...}, anterior:{...}|null,
//           custos:[{nome,tipo,valorMensal}], percentuais:{imposto,cmv} }
// Já saneado (números) por quem chama.
function pedidoDicas(resumo) {
  var sistema =
    'És um consultor financeiro prático de uma pequena empresa de ' +
    'pastelaria/cookies em Portugal. Recebes os números de um período e do ' +
    'período anterior e geras entre 4 e 6 dicas concretas para melhorar a ' +
    'cada mês, por ordem de prioridade. Usa SÓ os números dados: não ' +
    'inventes valores, clientes nem produtos. Cada dica diz o que fazer e ' +
    'porquê, apoiada em números (ex.: "os custos fixos pesam X % da receita"). ' +
    'Considera: evolução face ao período anterior, margem líquida, peso dos ' +
    'custos fixos e variáveis (os variáveis podem ser reduzidos ou cortados, ' +
    'os fixos não), CMV e imposto face aos percentuais, e problemas nos ' +
    'dados (vendas sem produto identificado deixam o lucro sobrestimado; ' +
    'sem vendas não há o que analisar — nesse caso a dica deve dizer o que ' +
    'registar). Tom direto, em português de Portugal, sem jargão. Não dês ' +
    'aconselhamento fiscal, legal ou de investimento. ' +
    'Responde APENAS com JSON válido, sem texto à volta nem cercas de código. ' +
    'Formato: {"resumo":string (máx. 200 caracteres, a leitura geral do ' +
    'período),"dicas":[{"titulo":string (máx. 60),"texto":string (máx. 260),' +
    '"prioridade":"alta"|"media"|"baixa","area":"vendas"|"custos"|"margem"|' +
    '"produtos"|"precos"|"dados"}]}.';
  return {
    sistema: sistema,
    instrucao: 'Números (JSON, valores em euros): ' + JSON.stringify(resumo) + '. Só JSON.',
  };
}

function limparDicas(dados) {
  var lista = dados && Array.isArray(dados.dicas) ? dados.dicas : [];
  var prioridades = ['alta', 'media', 'baixa'];
  var areas = ['vendas', 'custos', 'margem', 'produtos', 'precos', 'dados'];
  var corta = function (v, max) {
    var t = (v === null || v === undefined ? '' : String(v)).trim();
    return t.length > max ? t.substring(0, max - 1) + '…' : t;
  };
  var out = [];
  for (var i = 0; i < lista.length && out.length < 8; i++) {
    var d = lista[i];
    if (!d || typeof d !== 'object') continue;
    var titulo = corta(d.titulo, 80);
    var texto = corta(d.texto, 320);
    if (!titulo || !texto) continue;
    out.push({
      titulo: titulo,
      texto: texto,
      prioridade: prioridades.indexOf(d.prioridade) >= 0 ? d.prioridade : 'media',
      area: areas.indexOf(d.area) >= 0 ? d.area : 'custos',
    });
  }
  return {
    resumo: corta(dados && dados.resumo, 260),
    dicas: out,
  };
}

module.exports = { pedidoClassificar, limparSugestoes, pedidoDicas, limparDicas };
