/// <reference path="../pb_data/types.d.ts" />

// Análise de imagens por IA — camada com FORNECEDOR selecionável.
//
//   analisarImagemIA({ imagemBase64, mime, tarefa, isLista })
//     tarefa: 'fatura' (por omissão) | 'rotulo'
//     -> { ok: true,  dados, provider }              (JSON já parseado)
//     -> { ok: false, code, message, raw? }          (503 sem chave; 502 rede/IA/JSON)
//
// Escolha do fornecedor por variável de ambiente (sem alterar código):
//   TURNKEY_AI_PROVIDER   gemini | anthropic          (por omissão: gemini)
//   GEMINI_API_KEY        chave do Google AI Studio   (provider = gemini)
//   ANTHROPIC_API_KEY     chave da Anthropic          (provider = anthropic)
//   TURNKEY_AI_MODEL      modelo a usar               (por omissão, por fornecedor)
//
// Tudo numa função exportada, com auxiliares como closures — o require() do
// PocketBase não mantém de forma fiável a visibilidade entre funções de topo.

function analisarImagemIA(opts) {
  var imagem = (opts && opts.imagemBase64) || '';
  var mime = (opts && opts.mime) || 'image/jpeg';
  var tarefa = (opts && opts.tarefa) || 'fatura';
  var isLista = !!(opts && opts.isLista);

  if (!imagem) return { ok: false, code: 400, message: 'Falta a imagem (base64).' };

  var provider = ($os.getenv('TURNKEY_AI_PROVIDER') || 'gemini').toLowerCase().trim();

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
      'à volta e sem cercas de código. Formato: {"fornecedor": string, "data": ' +
      '"YYYY-MM-DD"|null, "numero": string|null, "total": number|null, "iva": ' +
      'number|null, "moeda": string|null, "linhas": [{"descricao": string, ' +
      '"quantidade": number|null, "unidade": string|null, "preco_unitario": ' +
      'number|null, "total": number|null, "embalagem_g": number|null}]}. ' +
      'Regras: preco_unitario é o preço por unidade/embalagem, NÃO o total da ' +
      'linha. Não incluas descontos, portes ou totais como linhas de produto. ' +
      'embalagem_g só quando o peso/volume da embalagem aparecer (converte kg->g, ' +
      'L->ml tratado como g). ' +
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
    // A Google descontinua os modelos ~a cada 6-12 meses (ex.: gemini-2.0-flash
    // foi desligado). Se der 502 "model ... is no longer available", mete o
    // novo em TURNKEY_AI_MODEL (ex.: gemini-3.8-flash) sem tocar no código.
    var model = $os.getenv('TURNKEY_AI_MODEL') || 'gemini-3.6-flash';
    var out = http({
      url:
        'https://generativelanguage.googleapis.com/v1beta/models/' +
        model +
        ':generateContent',
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-goog-api-key': key },
      body: JSON.stringify({
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
      }),
      timeout: 120,
    });
    if (out.erro) return { code: 502, message: out.erro };
    var msg = httpErro(out.resp);
    if (msg) return { code: 502, message: 'A IA respondeu com erro: ' + msg };
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
    var model = $os.getenv('TURNKEY_AI_MODEL') || 'claude-sonnet-5';
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
        max_tokens: 2000,
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
        message: 'TURNKEY_AI_PROVIDER desconhecido: "' + provider + '".',
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
  return { ok: true, dados: dados, provider: provider };
}

module.exports = { analisarImagemIA };
