/// <reference path="../pb_data/types.d.ts" />

// Estado dos backups para os administradores (só leitura).
//
//   GET /api/gc_turnkey/backups/estado  -> {
//     local:   { total, ultimo: { nome, tamanho, quando } | null },
//     externo: { estado: 'ok' | 'falha' | 'desconhecido', quando, ficheiro, mensagem }
//   }
//
// - `local`: os .zip que o PocketBase cria todas as noites em pb_data/backups.
// - `externo`: escrito pelo script deploy/backup/copia-externa.sh em
//   pb_data/backup_externo.json (ok/falha + hora). Sem o ficheiro = desconhecido.
// Só owner/admin (ou superutilizador). Não devolve caminhos nem segredos.

routerAdd('GET', '/api/gc_turnkey/backups/estado', (e) => {
  const core = require(`${__hooks}/backups_core.js`);
  const auth = e.auth;
  if (!auth) throw new UnauthorizedError('Autenticação necessária.');
  const isSuper = auth.collection().name === '_superusers';
  if (!isSuper) {
    const papel = auth.getString('papel');
    if (papel !== 'owner' && papel !== 'admin') {
      throw new ForbiddenError('Só administradores veem o estado dos backups.');
    }
  }

  const dados = String(e.app.dataDir());
  const out = { local: { total: 0, ultimo: null }, externo: { estado: 'desconhecido', quando: '', ficheiro: '', mensagem: '' } };

  // --- backups locais (.zip do PocketBase)
  try {
    const entradas = $os.readDir(dados + '/backups');
    let ultimo = null;
    let total = 0;
    for (const ent of entradas) {
      const nome = String(ent.name());
      if (!/\.zip$/i.test(nome)) continue;
      total++;
      const info = $os.stat(dados + '/backups/' + nome);
      const quando = info.modTime().unix();
      if (!ultimo || quando > ultimo.unix) {
        ultimo = { nome: nome, tamanho: info.size(), unix: quando };
      }
    }
    out.local.total = total;
    if (ultimo) {
      out.local.ultimo = {
        nome: ultimo.nome,
        tamanho: ultimo.tamanho,
        quando: new Date(ultimo.unix * 1000).toISOString(),
      };
    }
  } catch (_) {
    // pasta inexistente: sem backups
  }

  // --- cópia externa (escrita pelo script do servidor)
  try {
    const txt = toString($os.readFile(dados + '/backup_externo.json'));
    const j = JSON.parse(txt);
    out.externo.estado = j.ok === true ? 'ok' : j.ok === false ? 'falha' : 'desconhecido';
    out.externo.quando = String(j.quando || '').substring(0, 40);
    out.externo.ficheiro = String(j.ficheiro || '').substring(0, 120);
    out.externo.mensagem = String(j.mensagem || '').substring(0, 300);
  } catch (_) {
    // sem ficheiro: o script externo nunca correu
  }

  // --- espaço em disco (onde estão os dados e, se for outro disco, os backups)
  out.disco = { dados: core.espacoLivre(dados), backups: null };
  try {
    const d2 = core.espacoLivre(dados + '/backups');
    if (d2 && out.disco.dados && d2.totalKb !== out.disco.dados.totalKb) out.disco.backups = d2;
  } catch (_) {}

  // --- teste de integridade (feito aqui, todos os domingos) e teste de restauro
  //     (feito no servidor Linux pelo script teste-restauro.sh)
  out.integridade = core.lerEstadoJson(dados + '/backup_integridade.json');
  out.restauro = core.lerEstadoJson(dados + '/backup_restauro.json');

  return e.json(200, out);
});

// Testa já a integridade do backup mais recente (owner/admin).
//   POST /api/gc_turnkey/backups/testar -> { ok, quando, ficheiro, segundos, mensagem }
routerAdd('POST', '/api/gc_turnkey/backups/testar', (e) => {
  const core = require(`${__hooks}/backups_core.js`);
  const auth = e.auth;
  if (!auth) throw new UnauthorizedError('Autenticação necessária.');
  if (auth.collection().name !== '_superusers') {
    const papel = auth.getString('papel');
    if (papel !== 'owner' && papel !== 'admin') throw new ForbiddenError('Só administradores testam os backups.');
  }
  return e.json(200, core.testarIntegridade(e.app));
});

// Todos os domingos às 04:10.
cronAdd('backups_integridade', '10 4 * * 0', () => {
  require(`${__hooks}/backups_core.js`).testarIntegridade($app);
});
