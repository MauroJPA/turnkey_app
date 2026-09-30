/// <reference path="../pb_data/types.d.ts" />

// Partilhado entre o endpoint de exportação/envio sob pedido
// (pb/hooks/faturas.pb.js) e o cron mensal (pb/hooks/faturas_contab.pb.js) —
// nome canónico do ficheiro para a contabilidade e o envio por email.

const ACC = {
  Á: 'A', À: 'A', Ã: 'A', Â: 'A', Ä: 'A',
  É: 'E', È: 'E', Ê: 'E', Ë: 'E',
  Í: 'I', Ì: 'I', Î: 'I', Ï: 'I',
  Ó: 'O', Ò: 'O', Õ: 'O', Ô: 'O', Ö: 'O',
  Ú: 'U', Ù: 'U', Û: 'U', Ü: 'U', Ç: 'C',
};

function slug(s) {
  let out = String(s || '').toUpperCase();
  for (const k in ACC) out = out.split(k).join(ACC[k]);
  out = out.replace(/[^A-Z0-9]/g, '').slice(0, 40);
  return out || 'FORNECEDOR';
}

// Escapa a nota (texto livre da pessoa) antes de a pôr no HTML do email —
// nunca confiar em texto livre dentro de HTML.
function escapeHtml(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/\n/g, '<br>');
}

// Nome canónico para a contabilidade: FT-NOMEFORNECEDOR-DDMMAAAA.ext
function nomeExport(f) {
  const d = String(f.getString('data_fatura') || '').substring(0, 10);
  const ddmmaaaa =
    d.length === 10 ? d.slice(8, 10) + d.slice(5, 7) + d.slice(0, 4) : '';
  const fich = f.getString('ficheiro');
  const dot = fich.lastIndexOf('.');
  const ext = dot > -1 ? fich.slice(dot).toLowerCase() : '.pdf';
  return 'FT-' + slug(f.getString('fornecedor')) + '-' + ddmmaaaa + ext;
}

// Faturas confirmadas de uma empresa num intervalo (de/ate em falta = todas).
function faturasConfirmadas(app, empresaId, de, ate) {
  return app.findRecordsByFilter(
    'faturas',
    "empresa = {:e} && estado = 'confirmada' && apagada != true && data_fatura >= {:de} && data_fatura <= {:ate}",
    '-data_fatura',
    0,
    0,
    { e: empresaId, de: de || '0001-01-01', ate: (ate || '9999-12-31') + ' 23:59:59' },
  );
}

// Monta e envia o email com o resumo CSV + ficheiros em anexo. Lança
// BadRequestError com uma mensagem amigável se não houver nada para enviar,
// email nenhum, ou o SMTP falhar. `opts.nota`, se vier, é uma nota livre da
// pessoa que se junta ao corpo do email (ex.: "falta a fatura da EDP").
// Devolve { quantidade, total }.
function enviarEmailContabilidade(app, empresaId, opts) {
  opts = opts || {};
  const email = String(opts.email || '').trim();
  const nota = String(opts.nota || '').trim();
  if (!email) {
    throw new BadRequestError('Configura o email da contabilidade primeiro.');
  }

  let emp;
  try {
    emp = app.findRecordById('empresas', empresaId);
  } catch (_) {
    throw new BadRequestError('Empresa inválida.');
  }

  const recs = faturasConfirmadas(app, empresaId, opts.de, opts.ate);
  if (recs.length === 0) {
    throw new BadRequestError('Sem faturas confirmadas neste período.');
  }

  const colId = app.findCollectionByNameOrId('faturas').id;
  const storage = app.dataDir() + '/storage/' + colId + '/';
  const csv = ['ficheiro;fornecedor;data;numero;total;iva'];
  const anexos = {};
  let totalGeral = 0;

  for (const f of recs) {
    const nf = nomeExport(f);
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

  const rotulo = opts.rotulo || (recs.length + ' fatura(s)');
  const csvTexto = csv.join('\r\n');
  anexos['resumo.csv'] = $filesystem.fileFromBytes(
    Array.from(csvTexto).map((c) => c.charCodeAt(0)),
    'resumo.csv',
  );

  const nomeEmpresa = emp.getString('nome');
  const meta = app.settings().meta;
  const msg = new MailerMessage({
    from: {
      address: meta.senderAddress,
      name: meta.senderName || nomeEmpresa,
    },
    to: [{ address: email }],
    // Assunto sempre gerado pela app: identifica-se (GC Turnkey) e diz de
    // que empresa são as faturas — a contabilidade pode ter várias empresas.
    subject:
      'GC Turnkey — Faturas de ' + nomeEmpresa + ' · ' + rotulo +
      ' (' + recs.length + ' fatura(s), total ' + totalGeral.toFixed(2) + ')',
    html:
      '<p>Envio automático da aplicação <b>GC Turnkey</b> — faturas ' +
      'confirmadas de <b>' + escapeHtml(nomeEmpresa) + '</b> (' + rotulo + ').</p>' +
      '<p>Seguem <b>' + recs.length + '</b> faturas, total ' +
      totalGeral.toFixed(2) + '.</p>' +
      (nota ? '<p><b>Nota:</b> ' + escapeHtml(nota) + '</p>' : '') +
      '<p>Resumo em <code>resumo.csv</code>; ficheiros em anexo.</p>',
    attachments: anexos,
  });

  try {
    app.newMailClient().send(msg);
  } catch (err) {
    console.log('[contab] falha ao enviar email: ' + err);
    throw new BadRequestError(
      'Não foi possível enviar o email (SMTP configurado no servidor?)',
    );
  }

  return { quantidade: recs.length, total: totalGeral };
}

module.exports = { nomeExport, faturasConfirmadas, enviarEmailContabilidade };
