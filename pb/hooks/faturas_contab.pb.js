/// <reference path="../pb_data/types.d.ts" />

// Envio mensal das faturas confirmadas para o contabilista.
//
// No dia 1 de cada mês (08:00) junta as faturas `confirmada` do mês anterior,
// gera um resumo CSV e envia-o por email com os ficheiros em anexo (nomeados
// FT-FORNECEDOR-DDMMAAAA.ext). A lógica de montar/enviar é partilhada com o
// envio sob pedido (pb/hooks/faturas.pb.js) via faturas_export.js.
//
//   GC_TURNKEY_SCAN_EMPRESA    id da empresa (reutilizado do scanner)
//   GC_TURNKEY_CONTAB_EMAIL    email do contabilista — só usado se a empresa
//                              não tiver "email_contabilidade" configurado
//                              (Faturas → "Para a contabilidade", na app)
//
// Requer SMTP configurado nas definições do PocketBase (Admin UI → Mail).

cronAdd('faturas_contabilidade', '0 8 1 * *', () => {
  const empId = $os.getenv('GC_TURNKEY_SCAN_EMPRESA');
  if (!empId) return;

  let emp;
  try {
    emp = $app.findRecordById('empresas', empId);
  } catch (_) {
    console.log('[contab] empresa inválida: ' + empId);
    return;
  }

  const email =
    emp.getString('email_contabilidade') || $os.getenv('GC_TURNKEY_CONTAB_EMAIL');
  if (!email) return;

  // mês anterior
  const agora = new Date();
  const fimMes = new Date(Date.UTC(agora.getUTCFullYear(), agora.getUTCMonth(), 1));
  const iniMes = new Date(Date.UTC(agora.getUTCFullYear(), agora.getUTCMonth() - 1, 1));
  const iso = (d) => d.toISOString().substring(0, 10);
  const de = iso(iniMes);
  const ate = iso(new Date(fimMes.getTime() - 86400000));
  const rotuloMes = de.substring(0, 7);

  try {
    const r = require(`${__hooks}/faturas_export.js`).enviarEmailContabilidade(
      $app,
      empId,
      { de: de, ate: ate, email: email, rotulo: rotuloMes },
    );
    console.log(
      '[contab] ' + rotuloMes + ': enviado a ' + email + ' (' + r.quantidade + ' faturas).',
    );
  } catch (err) {
    // Inclui "sem faturas confirmadas" — normal nalguns meses, não é erro.
    console.log('[contab] ' + rotuloMes + ': ' + err);
  }
});
