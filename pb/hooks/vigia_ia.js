// "Explicar com IA" para os alertas do vigia de segurança (módulo partilhado
// via require()). Funções PURAS (sem acesso a ficheiros nem à rede): montam o
// pedido a partir de um alerta já guardado, ANONIMIZADO, e limpam a resposta.
//
// Privacidade — o que NUNCA sai do servidor: endereços IP (trocam-se por
// "IP-público-1", "IP-Tailscale-1"…), emails, nomes de utilizadores, caminhos
// com nomes de utilizadores, hashes, chaves e palavras-passe, nomes dos
// aparelhos. O que sai: o tipo de alerta, o texto genérico e o que fazer.

var SEGUROS = ['root', 'admin', 'ubuntu', 'debian', 'pi', 'www-data', 'docker', 'sudo', 'postgres'];

// Devolve uma função que anonimiza texto mantendo os rótulos consistentes
// (o mesmo IP tem sempre o mesmo rótulo dentro do mesmo pedido).
function criarAnonimizador() {
  var ips = {};
  var contagem = { publico: 0, tailscale: 0, interno: 0, v6: 0 };
  var rotuloIp = function (ip) {
    if (ips[ip]) return ips[ip];
    var p = ip.split('.').map(function (x) { return parseInt(x, 10); });
    var tipo = 'publico';
    var nome = 'IP-público';
    if (p[0] === 127) return (ips[ip] = 'localhost');
    if (p[0] === 100 && p[1] >= 64 && p[1] <= 127) { tipo = 'tailscale'; nome = 'IP-Tailscale'; }
    else if (p[0] === 10 || (p[0] === 172 && p[1] >= 16 && p[1] <= 31) || (p[0] === 192 && p[1] === 168) || (p[0] === 169 && p[1] === 254)) {
      tipo = 'interno'; nome = 'IP-interno';
    }
    contagem[tipo] += 1;
    return (ips[ip] = nome + '-' + contagem[tipo]);
  };
  return function (texto) {
    var t = String(texto === undefined || texto === null ? '' : texto);
    // emails primeiro (podem conter números que pareçam IPs)
    t = t.replace(/[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}/g, '[email]');
    // chaves e tokens conhecidos
    t = t.replace(/\b(?:sk-|ghp_|gho_|AIza|xox[abp]-|AKIA)[A-Za-z0-9_\-]{8,}/g, '[segredo]');
    // hashes e blobs longos (hex ≥ 16, base64 ≥ 32 com números e letras)
    t = t.replace(/\b[0-9a-fA-F]{16,}\b/g, '[hash]');
    t = t.replace(/\b(?=[A-Za-z0-9+\/=_\-]*\d)(?=[A-Za-z0-9+\/=_\-]*[A-Za-z])[A-Za-z0-9+\/=_\-]{32,}\b/g, '[segredo]');
    // IPv4 e IPv6
    t = t.replace(/\b(?:\d{1,3}\.){3}\d{1,3}\b/g, function (m) {
      var ok = m.split('.').every(function (x) { return parseInt(x, 10) <= 255; });
      return ok ? rotuloIp(m) : m;
    });
    t = t.replace(/\b(?:[0-9a-fA-F]{1,4}:){2,7}[0-9a-fA-F]{1,4}\b/g, function (m) {
      if (ips[m]) return ips[m];
      contagem.v6 += 1;
      return (ips[m] = 'IP-v6-' + contagem.v6);
    });
    // pastas pessoais e nomes entre aspas (utilizadores, aparelhos)
    t = t.replace(/\/home\/[^\s\/"'|]+/g, '/home/[utilizador]');
    t = t.replace(/"([^"\n]{1,60})"/g, function (m, nome) {
      return SEGUROS.indexOf(nome.toLowerCase()) >= 0 ? m : '"[nome]"';
    });
    return t;
  };
}

function idade(desde, agora) {
  if (!desde) return '';
  var m = Math.max(0, Math.round((agora - desde) / 60));
  if (m < 2) return 'agora mesmo';
  if (m < 120) return 'há ' + m + ' minutos';
  var h = Math.round(m / 60);
  if (h < 48) return 'há ' + h + ' horas';
  return 'há ' + Math.round(h / 24) + ' dias';
}

// achado: um alerta como a app o vê; outros: os restantes alertas ativos.
// Devolve { texto, sistema, instrucao } — `texto` é EXATAMENTE o que a pessoa
// vê antes de enviar (e o que vai na instrução).
function montarPedido(achado, outros, agora) {
  var anon = criarAnonimizador();
  var linhas = [];
  linhas.push(
    'Alerta (gravidade: ' + achado.gravidade + ', área: ' + (achado.categoria || '?') +
      (achado.desde ? ', visto ' + idade(achado.desde, agora) : '') + ')',
  );
  var titulo = anon(achado.titulo);
  var detalhe = anon(achado.detalhe);
  // nome dos aparelhos do Tailscale: o sistema operativo basta
  if (String(achado.id).indexOf('tailscale:') === 0) {
    detalhe = detalhe.replace(/^[^(]*\(/, 'aparelho desconhecido (');
  }
  linhas.push('Título: ' + titulo);
  if (detalhe) linhas.push('Detalhe: ' + detalhe);
  var itens = (achado.itens || []).slice(0, 12);
  for (var i = 0; i < itens.length; i++) linhas.push('- ' + anon(itens[i]));
  if (achado.fazer) linhas.push('O que a app já sugere: ' + anon(achado.fazer));
  var out = (outros || []).slice(0, 6);
  if (out.length) {
    linhas.push('Outros alertas ativos neste momento:');
    for (var j = 0; j < out.length; j++) linhas.push('- ' + anon(out[j].titulo));
  }
  var texto = linhas.join('\n');

  var sistema =
    'És um assistente de segurança informática para o dono de uma pequena empresa em Portugal, ' +
    'que NÃO é técnico. O servidor é um Linux (Debian) com Docker e Tailscale (só acessível pela rede privada Tailscale), ' +
    'a correr uma app web. Recebes UM alerta de um sistema de vigilância automático (os dados foram anonimizados: ' +
    '"IP-Tailscale-1", "[nome]" etc. são rótulos). Explica o alerta em português de Portugal, simples e direto. ' +
    'Usa SÓ o que foi dado: não inventes factos, nem nomes, nem IPs. Se não dá para saber, diz que não dá. ' +
    'Diz se é PROVAVELMENTE NORMAL (acontece em manutenção legítima), DUVIDOSO ou SUSPEITO, e porquê. ' +
    'Dá passos concretos, cautelosos e por ordem: primeiro VERIFICAR, depois (só se confirmado) conter. ' +
    'Em cada passo podes dar um comando de verificação que NÃO altere nada (ex.: ss, journalctl, last, ls, cat, docker ps). ' +
    'Nunca sugiras comandos destrutivos ou de descarregar-e-executar; para apagar ou bloquear, descreve o passo em texto e avisa para confirmar antes. ' +
    'Se houver outros alertas que juntos indiquem intrusão, diz-o. Responde APENAS com JSON válido, sem cercas de código. ' +
    'Formato: {"veredito":"provavelmente_normal"|"duvidoso"|"suspeito","resumo":string (máx. 220 caracteres, o que significa),' +
    '"porque":string (máx. 280),"passos":[{"texto":string (máx. 200),"comando":string|null (máx. 160)}] (3 a 6 passos),' +
    '"nao_fazer":[string (máx. 140)] (0 a 3)}.';
  return {
    texto: texto,
    sistema: sistema,
    instrucao: 'Alerta de segurança a explicar:\n' + texto + '\nSó JSON.',
  };
}

// Comandos que nunca se mostram, venham de onde vierem.
var PERIGOSOS = [
  /\brm\s+(-[a-z]*\s+)*\/(\s|$)/i, /\brm\s+-[a-z]*r[a-z]*f?\s+\/\S*/i, /\bmkfs/i, /\bdd\s+if=/i,
  /:\(\)\s*\{/, />\s*\/dev\/(sd|nvme|vd)/i, /\bchmod\s+(-R\s+)?[0-7]*777\s+\//i,
  /(curl|wget)[^|\n]*\|\s*(ba|z)?sh/i, /base64\s+(-d|--decode)/i, /\bshutdown\b|\breboot\b|\bhalt\b|\bpoweroff\b/i,
  /\bpasswd\b\s+-?d/i, /\buserdel\b|\bdeluser\b/i, /\biptables\s+-F/i, /\bkill\s+-9\s+1\b/,
];

function limparResposta(dados) {
  var corta = function (v, max) {
    var t = (v === null || v === undefined ? '' : String(v)).replace(/\s+/g, ' ').trim();
    return t.length > max ? t.substring(0, max - 1) + '…' : t;
  };
  if (!dados || typeof dados !== 'object') return null;
  var vereditos = ['provavelmente_normal', 'duvidoso', 'suspeito'];
  var veredito = vereditos.indexOf(dados.veredito) >= 0 ? dados.veredito : 'duvidoso';
  var resumo = corta(dados.resumo, 260);
  var porque = corta(dados.porque, 320);
  var passos = [];
  var lista = Array.isArray(dados.passos) ? dados.passos : [];
  for (var i = 0; i < lista.length && passos.length < 6; i++) {
    var p = lista[i];
    if (!p || typeof p !== 'object') continue;
    var texto = corta(p.texto, 240);
    if (!texto) continue;
    var cmd = p.comando === null || p.comando === undefined ? '' : String(p.comando).replace(/[\r\n]+/g, ' ').trim();
    if (cmd.length > 200) cmd = '';
    for (var k = 0; k < PERIGOSOS.length && cmd; k++) {
      if (PERIGOSOS[k].test(cmd)) cmd = '';
    }
    passos.push({ texto: texto, comando: cmd || null });
  }
  var nao = [];
  var ln = Array.isArray(dados.nao_fazer) ? dados.nao_fazer : [];
  for (var n = 0; n < ln.length && nao.length < 3; n++) {
    var t = corta(ln[n], 160);
    if (t) nao.push(t);
  }
  if (!resumo || passos.length === 0) return null;
  return { veredito: veredito, resumo: resumo, porque: porque, passos: passos, naoFazer: nao };
}

module.exports = { criarAnonimizador, montarPedido, limparResposta };
