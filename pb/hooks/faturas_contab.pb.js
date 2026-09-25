/// <reference path="../pb_data/types.d.ts" />

// Envio mensal das faturas confirmadas para o contabilista.
//
// No dia 1 de cada mês (08:00) junta as faturas `confirmada` do mês anterior,
// gera um resumo CSV e envia-o por email com os ficheiros em anexo (nomeados
// FT-FORNECEDOR-DDMMAAAA.ext).
//
//   GC_TURNKEY_CONTAB_EMAIL    email do contabilista (sem isto o cron não envia)
//   GC_TURNKEY_SCAN_EMPRESA    id da empresa (reutilizado do scanner)
//
// Requer SMTP configurado nas definições do PocketBase (Admin UI → Mail).

cronAdd('faturas_contabilidade', '0 8 1 * *', () => {
  const email = $os.getenv('GC_TURNKEY_CONTAB_EMAIL');
  const empId = $os.getenv('GC_TURNKEY_SCAN_EMPRESA');
  if (!email || !empId) return;

  let emp;
  try {
    emp = $app.findRecordById('empresas', empId);
  } catch (_) {
    console.log('[contab] empresa inválida: ' + empId);
    return;
  }

  // mês anterior
  const agora = new Date();
  const fimMes = new Date(Date.UTC(agora.getUTCFullYear(), agora.getUTCMonth(), 1));
  const iniMes = new Date(Date.UTC(agora.getUTCFullYear(), agora.getUTCMonth() - 1, 1));
  const iso = (d) => d.toISOString().substring(0, 10);
  const de = iso(iniMes);
  const ate = iso(new Date(fimMes.getTime() - 86400000));
  const rotuloMes = de.substring(0, 7);

  const recs = $app.findRecordsByFilter(
    'faturas',
    "empresa = {:e} && estado = 'confirmada' && data_fatura >= {:de} && data_fatura <= {:ate}",
    '-data_fatura',
    0,
    0,
    { e: empId, de: de, ate: ate + ' 23:59:59' },
  );
  if (recs.length === 0) {
    console.log('[contab] ' + rotuloMes + ': sem faturas confirmadas.');
    return;
  }

  const ACC = {
    Á: 'A', À: 'A', Ã: 'A', Â: 'A', É: 'E', Ê: 'E', Í: 'I', Ó: 'O', Õ: 'O',
    Ô: 'O', Ú: 'U', Ç: 'C',
  };
  const slug = (s) => {
    let o = String(s || '').toUpperCase();
    for (const k in ACC) o = o.split(k).join(ACC[k]);
    return o.replace(/[^A-Z0-9]/g, '').slice(0, 40) || 'FORNECEDOR';
  };
  const nomeFich = (f) => {
    const d = String(f.getString('data_fatura') || '').substring(0, 10);
    const dd =
      d.length === 10 ? d.slice(8, 10) + d.slice(5, 7) + d.slice(0, 4) : '';
    const fich = f.getString('ficheiro');
    const dot = fich.lastIndexOf('.');
    const ext = dot > -1 ? fich.slice(dot).toLowerCase() : '.pdf';
    return 'FT-' + slug(f.getString('fornecedor')) + '-' + dd + ext;
  };

  // Os ficheiros ficam em storage/<collectionId>/<recordId>/<ficheiro>
  // (armazenamento local; num setup S3 usar $app.newFilesystem()).
  const colId = $app.findCollectionByNameOrId('faturas').id;
  const storage = $app.dataDir() + '/storage/' + colId + '/';
  const csv = ['ficheiro;fornecedor;data;numero;total;iva'];
  const anexos = {};
  let totalGeral = 0;

  for (const f of recs) {
    const nf = nomeFich(f);
    const tot = f.getFloat('total');
    totalGeral += tot;
    csv.push(
      [
        nf,
        String(f.getString('fornecedor')).replace(/;/g, ','),
        f.getString('data_fatura').substring(0, 10),
        String(f.getString('numero')).replace(/;/g, ','),
        tot.toFixed(2),
        f.getFloat('iva').toFixed(2),
      ].join(';'),
    );
    try {
      const bytes = $os.readFile(storage + f.id + '/' + f.getString('ficheiro'));
      anexos[nf] = $filesystem.fileFromBytes(bytes, nf);
    } catch (err) {
      console.log('[contab] sem ficheiro de ' + f.id + ': ' + err);
    }
  }

  const csvTexto = csv.join('\r\n');
  anexos['resumo-' + rotuloMes + '.csv'] = $filesystem.fileFromBytes(
    Array.from(csvTexto).map((c) => c.charCodeAt(0)),
    'resumo-' + rotuloMes + '.csv',
  );

  const meta = $app.settings().meta;
  const msg = new MailerMessage({
    from: {
      address: meta.senderAddress,
      name: meta.senderName || emp.getString('nome'),
    },
    to: [{ address: email }],
    subject:
      'Faturas ' + rotuloMes + ' — ' + emp.getString('nome') +
      ' (' + recs.length + ', total ' + totalGeral.toFixed(2) + ')',
    html:
      '<p>Segue o resumo das <b>' + recs.length + '</b> faturas confirmadas de ' +
      rotuloMes + ' (total ' + totalGeral.toFixed(2) + ').</p>' +
      '<p>Resumo em <code>resumo-' + rotuloMes + '.csv</code>; ficheiros em anexo.</p>',
    attachments: anexos,
  });

  try {
    $app.newMailClient().send(msg);
    console.log(
      '[contab] ' + rotuloMes + ': enviado a ' + email + ' (' + recs.length + ' faturas).',
    );
  } catch (err) {
    console.log('[contab] falha no envio (SMTP configurado?): ' + err);
  }
});
