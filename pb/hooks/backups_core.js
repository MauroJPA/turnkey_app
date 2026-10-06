// Backups: ajudas partilhadas (módulo carregado com require() pelos handlers de
// backups.pb.js; cada handler corre isolado e não vê funções de topo).

// Corre `df` sobre uma pasta (o servidor de produção é Linux/Alpine). Devolve
// { livreKb, totalKb } ou null se não for possível (ex.: Windows em desenvolvimento).
function espacoLivre(pasta) {
  try {
    const txt = toString($os.cmd('df', '-Pk', pasta).output());
    const linhas = txt.trim().split('\n');
    const c = linhas[linhas.length - 1].trim().split(/\s+/);
    const total = parseInt(c[1], 10);
    const livre = parseInt(c[3], 10);
    if (!isFinite(total) || !isFinite(livre) || total <= 0) return null;
    return { livreKb: livre, totalKb: total };
  } catch (_) {
    return null;
  }
}

// Lê um ficheiro de estado {ok, quando, ficheiro, segundos, mensagem} escrito
// por um script ou por testarIntegridade; null se não existe.
function lerEstadoJson(ficheiro) {
  try {
    const j = JSON.parse(toString($os.readFile(ficheiro)));
    return {
      ok: j.ok === true ? true : j.ok === false ? false : null,
      quando: String(j.quando || '').substring(0, 40),
      ficheiro: String(j.ficheiro || '').substring(0, 120),
      segundos: typeof j.segundos === 'number' ? j.segundos : null,
      mensagem: String(j.mensagem || '').substring(0, 300),
    };
  } catch (_) {
    return null;
  }
}

// Teste de integridade do backup mais recente: `unzip -t` confere o CRC de todos
// os ficheiros (apanha um .zip cortado ou estragado) e vê se tem a base de dados.
function testarIntegridade(app) {
  const dados = String(app.dataDir());
  const inicio = Date.now();
  let ok = false;
  let nome = '';
  let msg = '';
  try {
    const entradas = $os.readDir(dados + '/backups');
    let ultimo = null;
    for (const ent of entradas) {
      const n = String(ent.name());
      if (!/\.zip$/i.test(n)) continue;
      const m = $os.stat(dados + '/backups/' + n).modTime().unix();
      if (!ultimo || m > ultimo.m) ultimo = { n: n, m: m };
    }
    if (!ultimo) {
      msg = 'Não há nenhum backup para testar.';
    } else {
      nome = ultimo.n;
      const zip = dados + '/backups/' + nome;
      try {
        const lista = toString($os.cmd('unzip', '-l', zip).output());
        if (!/\bdata\.db\b/.test(lista)) {
          msg = 'O backup não contém a base de dados (data.db).';
        } else {
          $os.cmd('unzip', '-tqq', zip).run();
          ok = true;
          msg = 'Backup íntegro (todos os ficheiros conferem).';
        }
      } catch (err) {
        msg = 'O backup parece estar estragado ou incompleto (ou este servidor não tem "unzip").';
      }
    }
  } catch (err) {
    msg = 'Não consegui verificar os backups neste servidor.';
  }
  const estado = {
    ok: ok,
    quando: new Date().toISOString(),
    ficheiro: nome,
    segundos: Math.round((Date.now() - inicio) / 1000),
    mensagem: msg,
  };
  try {
    $os.writeFile(dados + '/backup_integridade.json', JSON.stringify(estado), 0o644);
  } catch (_) {}
  return estado;
}

module.exports = { espacoLivre, lerEstadoJson, testarIntegridade };
