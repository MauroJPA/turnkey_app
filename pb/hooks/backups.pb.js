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

  return e.json(200, out);
});
