/// <reference path="../pb_data/types.d.ts" />

// Conveniência de DESENVOLVIMENTO.
//
// Com a variável de ambiente TURNKEY_DEV=1, qualquer conta `users` criada
// fica logo marcada como `verified` — não é preciso email/SMTP para entrar
// enquanto se desenvolve. O `serve.ps1` local já põe TURNKEY_DEV=1.
//
// Em produção (sem a variável) este hook não faz nada.

onRecordCreate((e) => {
  try {
    if ($os.getenv('TURNKEY_DEV') === '1') {
      e.record.set('verified', true);
    }
  } catch (err) {
    console.log('[dev_autoverify] ' + err);
  }
  e.next();
}, 'users');
