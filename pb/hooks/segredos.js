/// <reference path="../pb_data/types.d.ts" />

// Segredos por empresa, cifrados em repouso (AES-256-GCM via $security).
// Módulo partilhado: `const seg = require(`${__hooks}/segredos.js`)`.
//
//   TURNKEY_ENC_KEY   exatamente 32 caracteres, só no ambiente do servidor.
//                     Guardar uma cópia num gestor de palavras-passe, FORA dos
//                     backups da base de dados: sem ela os segredos guardados
//                     não se recuperam.

function chaveMestra() {
  var k = $os.getenv('TURNKEY_ENC_KEY') || '';
  if (k.length !== 32) {
    throw new Error(
      'Cifra não configurada no servidor (TURNKEY_ENC_KEY com 32 caracteres).',
    );
  }
  return k;
}

function procurar(app, empresaId, servico) {
  try {
    return app.findFirstRecordByFilter(
      'segredos_empresa',
      'empresa = {:e} && servico = {:s}',
      { e: empresaId, s: servico },
    );
  } catch (_) {
    return null;
  }
}

function guardar(app, empresaId, servico, valor, autorId) {
  var cifrado = $security.encrypt(valor, chaveMestra());
  var rec = procurar(app, empresaId, servico);
  if (!rec) {
    rec = new Record(app.findCollectionByNameOrId('segredos_empresa'));
    rec.set('empresa', empresaId);
    rec.set('servico', servico);
  }
  rec.set('valor_cifrado', cifrado);
  rec.set('sufixo', valor.length > 8 ? valor.substring(valor.length - 4) : '');
  rec.set('atualizado_por', autorId || '');
  app.save(rec);
}

// Devolve o valor em claro, ou null se não existir / não for possível decifrar.
function ler(app, empresaId, servico) {
  var rec = procurar(app, empresaId, servico);
  if (!rec) return null;
  try {
    return $security.decrypt(rec.getString('valor_cifrado'), chaveMestra());
  } catch (_) {
    return null;
  }
}

// Só metadados: nunca o valor.
function estado(app, empresaId, servico) {
  var rec = procurar(app, empresaId, servico);
  if (!rec) return { configurada: false, sufixo: '', atualizadoEm: '' };
  return {
    configurada: true,
    sufixo: rec.getString('sufixo'),
    atualizadoEm: rec.getString('updated'),
  };
}

function apagar(app, empresaId, servico) {
  var rec = procurar(app, empresaId, servico);
  if (rec) app.delete(rec);
}

module.exports = { guardar, ler, estado, apagar };
