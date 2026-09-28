/// <reference path="../pb_data/types.d.ts" />

// Análise de imagens por IA — camada com FORNECEDOR selecionável.
//
//   analisarImagemIA({ imagemBase64, mime, tarefa, isLista })
//     tarefa: 'fatura' (por omissão) | 'rotulo'
//     -> { ok: true,  dados, lista, provider }       (JSON já parseado; para faturas,
//                                                    `lista` tem uma entrada por fatura do ficheiro)
//     -> { ok: false, code, message, raw? }          (503 sem chave; 502 rede/IA/JSON)
//
// Escolha do fornecedor por variável de ambiente (sem alterar código):
//   GC_TURNKEY_AI_PROVIDER   gemini | anthropic          (por omissão: gemini)
//   GEMINI_API_KEY        chave do Google AI Studio   (provider = gemini)
//   ANTHROPIC_API_KEY     chave da Anthropic          (provider = anthropic)
//   GC_TURNKEY_AI_MODEL      modelo a usar               (por omissão, por fornecedor)
//   GC_TURNKEY_AI_MODEL_FALLBACK  modelos de reserva (separados por vírgula) se o principal
//                            estiver sobrecarregado ou já não existir (Gemini)
//   GC_TURNKEY_AI_ESPERAS    pausas (ms) entre tentativas, ex.: 3000,8000 (por omissão)
//   GC_TURNKEY_GEMINI_URL    endereço base da API (só para testes)
//
// Tudo numa função exportada, com auxiliares como closures — o require() do
// PocketBase não mantém de forma fiável a visibilidade entre funções de topo.

function analisarImagemIA(opts) {
  var imagem = (opts && opts.imagemBase64) || '';
  var mime = (opts && opts.mime) || 'image/jpeg';
  var tarefa = (opts && opts.tarefa) || 'fatura';
  var isLista = !!(opts && opts.isLista);

  if (!imagem) return { ok: false, code: 400, message: 'Falta a imagem (base64).' };

  var provider = ($os.getenv('GC_TURNKEY_AI_PROVIDER') || 'gemini').toLowerCase().trim();

  // ---- prompt por tarefa -----------------------------------------------
  var sistema, instrucao;
  if (tarefa === 'rotulo') {
    sistema =
      'És um extrator da informação de um RÓTULO de produto alimentar em ' +
      'Portugal. Responde APENAS com JSON válido, sem texto à volta e sem ' +
      'cercas de código. Formato: {"nome": string|null, "base": "100g"|"100ml", ' +
      '"densidade": number|null, "nutri": {"energia_kcal": number|null, ' +
      '"lipidos_g": number|null, "saturados_g": number|null, "hidratos_g": ' +
      'number|null, "acucares_g": number|null, "fibra_g": number|null, ' +
      '"proteina_g": number|null, "sal_g": number|null}, "ingredientes_texto": ' +
      'string|null, "alergenios": string[], "alergenios_tracos": string[]}. ' +
      'Regras: os valores nutricionais são SEMPRE por 100 g (indica "100ml" em ' +
      '"base" se o rótulo for por 100 ml); se só houver por porção, converte ' +
      'para 100 g. Se o rótulo só indicar "sódio", sal = sódio × 2,5. Os ' +
      'alergénios têm de ser EXATAMENTE destes: Glúten, Crustáceos, Ovos, ' +
      'Peixe, Amendoins, Soja, Leite, Frutos de casca rija, Aipo, Mostarda, ' +
      'Sésamo, Sulfitos, Tremoço, Moluscos. Em "alergenios" põe os que a lista ' +
      'de ingredientes contém (costumam vir a NEGRITO); em "alergenios_tracos" ' +
      'os de "pode conter". null quando um valor não aparece.';
    instrucao = 'Lê o rótulo. Só JSON.';
  } else {
    sistema =
      'És um extrator de dados de ' +
      (isLista ? 'listas de preços' : 'faturas de compra') +
      ' de uma padaria em Portugal. Responde APENAS com JSON válido, sem texto ' +
      'à volta e sem cercas de código. O ficheiro pode conter VÁRIAS ' +
      (isLista ? 'listas' : 'faturas') +
      ' (de fornecedores diferentes ou do mesmo, com datas diferentes), cada uma ' +
      'numa ou mais páginas seguidas: devolve uma entrada por documento, pela ' +
      'ordem do ficheiro. Começa um documento novo sempre que mudar o número ' +
      'do documento, a data OU o fornecedor: duas faturas do mesmo fornecedor ' +
      'com números ou datas diferentes são dois documentos. ' +
      'Formato: {"faturas": [{"fornecedor": string, "data": ' +
      '"YYYY-MM-DD"|null, "numero": string|null, "total": number|null, "iva": ' +
      'number|null, "moeda": string|null, "paginas": [number], "linhas": ' +
      '[{"descricao": string, "nome_generico": string, "marca": string|null, ' +
      '"quantidade": number|null, "unidade": string|null, "preco_unitario": ' +
      'number|null, "total": number|null, "embalagem_g": number|null, "embalagem_unidade": "g"|"ml"|"un", ' +
      '"caracteristica": string|null, ' +
      '"tipo_item": "ingrediente"|"consumivel"|"embalagem", "categoria_consumivel": ' +
      '"limpeza"|"desinfecao"|"higiene"|"insumo"|"outro"|null, "tipo_embalagem": ' +
      '"Caixa"|"Saco"|"Saqueta"|"Adesivo"|"Fita"|"Cartão"|"Outro"|null}]}]}. ' +
      '"paginas" são os números (a começar em 1) das páginas do ficheiro onde ' +
      'aparece esse documento; numa imagem, [1]. Uma página pertence a um só ' +
      'documento. Uma continuação ("página 2 de 2", "continua") pertence ao ' +
      'mesmo documento. ' +
      'nome_generico é o ingrediente em termos genéricos, SEM marca, embalagem, ' +
      'peso nem termos comerciais: "Açúcar Sidul BCO granulado KG" -> "Açúcar ' +
      'branco"; "Cravinho moído Margão pac 14gr" -> "Cravinho em pó"; "Manteiga ' +
      'Président 250g" -> "Manteiga". Mantém as variedades que mudam o produto ' +
      '(açúcar branco, amarelo, demerara e mascavado são diferentes). "marca" é ' +
      'a marca comercial (ex.: Sidul, Margão) ou null. ' +
      'embalagem_unidade é a unidade em que está embalagem_g: "g" por omissão ' +
      '(sólidos e em kg/g), "ml" para líquidos e bebidas (L, cl, dl e ml -> ml: ' +
      '"Leite 1L" -> embalagem_g 1000, "ml"; "Coca-Cola 33cl" -> 330, "ml"), ' +
      '"un" só quando a embalagem conta unidades ("Ovos cx 12" -> 12, "un"). ' +
      'Na dúvida usa "g". caracteristica é o que distingue variedades do mesmo ' +
      'ingrediente e NÃO faz parte do nome_generico: "Farinha de trigo T55" -> ' +
      'nome_generico "Farinha de trigo", caracteristica "T55"; "Chocolate negro ' +
      '70%" -> "Chocolate negro", "70% cacau"; "Farinha integral" -> "Farinha de ' +
      'trigo", "integral". null se não houver. ' +
      'tipo_item: "ingrediente" para o que se come ou entra numa receita ' +
      '(farinha, açúcar, chocolate, ovos, especiarias); "consumivel" para ' +
      'produtos de limpeza, detergentes, desinfetantes, lixívia, esponjas, ' +
      'luvas, papel, sacos do lixo e outros insumos que não se comem. Para ' +
      'consumíveis, nome_generico é o tipo de produto sem marca ("Detergente ' +
      'loiça", "Desinfetante superfícies") e categoria_consumivel: limpeza ' +
      '(detergentes, desengordurantes, lixívia), desinfecao (desinfetantes, ' +
      'álcool), higiene (sabonete, luvas, toucas, papel de mãos), insumo ' +
      '(outros materiais), outro; para ingredientes é null. ' +
      '"embalagem" é para material de EMBALAR o produto final, não para comer nem ' +
      'para limpar: caixas, sacos, saquetas, sacos take-away, adesivos/etiquetas, ' +
      'fita-cola, cartão, rótulos. Para embalagens, nome_generico é o tipo sem ' +
      'marca/medida ("Caixa take-away", "Adesivo redondo") e tipo_embalagem é o ' +
      'que mais se aproxima da lista dada; para as outras linhas é null. ' +
      'quantidade é o número que aparece na coluna da quantidade, na unidade ' +
      'que a fatura indica (un, kg, g, L, cx…), sem multiplicar: "2 un" de ' +
      '"Noz moscada 15g" -> quantidade 2, unidade "un", embalagem_g 15; ' +
      '"1 un" de "Cravinho 14g" -> quantidade 1, unidade "un", embalagem_g 14. ' +
      'Se a coluna estiver em kg/g/L, usa essa unidade. ' +
      'Nas faturas de grossistas (Makro, Recheio…) com colunas "Vol.", "Qt./Vol." ' +
      'e "Qt.Total", a quantidade é a Qt.Total (ex.: 2 volumes de 6 = 12 un) e ' +
      'preco_unitario é o "Preço Uni." (por unidade ou por kg, sem IVA). Se a ' +
      'quantidade tem decimais (ex.: 1,150) ou a descrição termina em KG e o ' +
      'preço é por kg, usa unidade "kg", quantidade = o peso (1,15) e ' +
      'preco_unitario = preço por kg, embalagem_g = 1000 (o preço é de 1 kg). Ignora guias de remessa sem preços: ' +
      'devolve-as só com fornecedor/data/número e "linhas": []. ' +
      'Regras: preco_unitario é o preço por unidade/embalagem, NÃO o total da ' +
      'linha. Não incluas descontos, portes ou totais como linhas de produto. ' +
      'embalagem_g só quando o tamanho da embalagem aparecer (converte kg->g, ' +
      'L->ml, cl->ml), com a unidade em embalagem_unidade. ' +
      (isLista ? 'Numa lista de preços, quantidade e total são null.' : '');
    instrucao = 'Extrai os dados. Só JSON.';
  }

  var http = function (req) {
    try {
      return { resp: $http.send(req) };
    } catch (err) {
      return { erro: 'Falha de rede: ' + err };
    }
  };
  var httpErro = function (resp) {
    if (resp.statusCode >= 200 && resp.statusCode < 300) return null;
    if (resp.json && resp.json.error && resp.json.error.message) {
      return resp.json.error.message;
    }
    return 'HTTP ' + resp.statusCode;
  };

  // ---- Google Gemini ----------------------------------------------
  var pedirGemini = function () {
    var key = $os.getenv('GEMINI_API_KEY') || $os.getenv('GOOGLE_API_KEY');
    if (!key) return { code: 503, message: 'IA não configurada (falta GEMINI_API_KEY).' };
    // A Google descontinua os modelos ~a cada 6-12 meses e, nas horas de
    // ponta, responde 503 "muita procura". Por isso: o modelo principal
    // (GC_TURNKEY_AI_MODEL) é tentado 3 vezes com pausas e, se continuar
    // indisponível (ou já não existir), passa-se aos de reserva.
    var base =
      $os.getenv('GC_TURNKEY_GEMINI_URL') ||
      'https://generativelanguage.googleapis.com/v1beta/models/';
    var modelos = [$os.getenv('GC_TURNKEY_AI_MODEL') || 'gemini-3.6-flash'];
    var reserva = ($os.getenv('GC_TURNKEY_AI_MODEL_FALLBACK') || 'gemini-3.5-flash,gemini-3.5-flash-lite').split(',');
    for (var k = 0; k < reserva.length; k++) {
      var nome = reserva[k].trim();
      if (nome && modelos.indexOf(nome) === -1) modelos.push(nome);
    }
    var esperas = [3000, 8000];
    var cfg = $os.getenv('GC_TURNKEY_AI_ESPERAS');
    if (cfg) {
      esperas = cfg.split(',').map(function (x) { return parseInt(x, 10) || 0; });
    }
    var transitorio = function (c) {
      return c === 429 || c === 500 || c === 502 || c === 503 || c === 504;
    };
    var corpo = JSON.stringify({
      system_instruction: { parts: [{ text: sistema }] },
      contents: [
        {
          role: 'user',
          parts: [
            { inline_data: { mime_type: mime, data: imagem } },
            { text: instrucao },
          ],
        },
      ],
      generationConfig: { temperature: 0, response_mime_type: 'application/json' },
    });
    var out;
    for (var m = 0; m < modelos.length; m++) {
      for (var t = 0; t <= esperas.length; t++) {
        out = http({
          url: base + modelos[m] + ':generateContent',
          method: 'POST',
          headers: { 'content-type': 'application/json', 'x-goog-api-key': key },
          body: corpo,
          timeout: 120,
        });
        if (out.erro) {
          if (t < esperas.length) sleep(esperas[t]);
          continue;
        }
        var c = out.resp.statusCode;
        if (c === 404) break; // modelo já não existe: passa ao seguinte
        if (!transitorio(c)) break; // sucesso ou erro definitivo
        if (t < esperas.length) sleep(esperas[t]);
      }
      if (!out.erro) {
        var cs = out.resp.statusCode;
        if (cs !== 404 && !transitorio(cs)) break;
      }
    }
    if (out.erro) return { code: 502, message: out.erro };
    var msg = httpErro(out.resp);
    if (msg) {
      if (transitorio(out.resp.statusCode)) {
        return {
          code: 502,
          message:
            'A IA (Google Gemini) está sobrecarregada neste momento. Tenta de novo daqui a uns minutos.',
        };
      }
      return { code: 502, message: 'A IA respondeu com erro: ' + msg };
    }
    var texto = '';
    try {
      var cands = (out.resp.json && out.resp.json.candidates) || [];
      var parts = (cands[0] && cands[0].content && cands[0].content.parts) || [];
      for (var i = 0; i < parts.length; i++) if (parts[i].text) texto += parts[i].text;
    } catch (_) {}
    return { texto: texto };
  };

  // ---- Anthropic Claude -----------------------------------------
  var pedirAnthropic = function () {
    var key = $os.getenv('ANTHROPIC_API_KEY');
    if (!key) return { code: 503, message: 'IA não configurada (falta ANTHROPIC_API_KEY).' };
    var model = $os.getenv('GC_TURNKEY_AI_MODEL') || 'claude-sonnet-5';
    var bloco =
      mime === 'application/pdf'
        ? { type: 'document', source: { type: 'base64', media_type: mime, data: imagem } }
        : { type: 'image', source: { type: 'base64', media_type: mime, data: imagem } };
    var out = http({
      url: 'https://api.anthropic.com/v1/messages',
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-api-key': key,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: model,
        max_tokens: 8000,
        system: sistema,
        messages: [
          { role: 'user', content: [bloco, { type: 'text', text: instrucao }] },
        ],
      }),
      timeout: 120,
    });
    if (out.erro) return { code: 502, message: out.erro };
    var msg = httpErro(out.resp);
    if (msg) return { code: 502, message: 'A IA respondeu com erro: ' + msg };
    var texto = '';
    try {
      var parts = (out.resp.json && out.resp.json.content) || [];
      for (var i = 0; i < parts.length; i++) {
        if (parts[i].type === 'text') texto += parts[i].text;
      }
    } catch (_) {}
    return { texto: texto };
  };

  var r;
  switch (provider) {
    case 'gemini':
    case 'google':
      r = pedirGemini();
      break;
    case 'anthropic':
    case 'claude':
      r = pedirAnthropic();
      break;
    default:
      return {
        ok: false,
        code: 503,
        message: 'GC_TURNKEY_AI_PROVIDER desconhecido: "' + provider + '".',
      };
  }
  if (r.code) return { ok: false, code: r.code, message: r.message };

  var texto = (r.texto || '').trim();
  var m = texto.match(/```(?:json)?\s*([\s\S]*?)```/); // tolerar cercas ```json
  if (m) texto = m[1].trim();

  var dados;
  try {
    dados = JSON.parse(texto);
  } catch (_) {
    return {
      ok: false,
      code: 502,
      message: 'A IA não devolveu JSON válido.',
      raw: texto,
    };
  }
  if (tarefa === 'fatura') {
    var lista = Array.isArray(dados)
      ? dados
      : dados && Array.isArray(dados.faturas)
      ? dados.faturas
      : [dados];
    lista = lista.filter(function (f) {
      return f && typeof f === 'object';
    });
    if (!lista.length) {
      return { ok: false, code: 502, message: 'A IA não encontrou nenhuma fatura no ficheiro.', raw: texto };
    }
    return { ok: true, dados: lista[0], lista: lista, provider: provider };
  }
  return { ok: true, dados: dados, provider: provider };
}

module.exports = { analisarImagemIA };
