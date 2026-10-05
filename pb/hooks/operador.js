// "Operador da plataforma": quem pode aprovar contas novas (e ver o estado dos
// backups). Módulo partilhado via require().
//
// Quem é: os emails de GC_TURNKEY_OPERADORES (separados por vírgula) ou, se a
// variável não existir, o proprietário aprovado mais antigo (o primeiro). Os
// superutilizadores do PocketBase também contam.

function ehOperador(app, auth) {
  if (!auth) return false;
  const colecao = auth.collection().name;
  if (colecao === '_superusers') return true;
  if (colecao !== 'users') return false;
  if (!auth.getBool('aprovado')) return false;

  const lista = String($os.getenv('GC_TURNKEY_OPERADORES') || '')
    .toLowerCase()
    .split(',')
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
  if (lista.length > 0) {
    return lista.indexOf(String(auth.getString('email') || '').toLowerCase()) !== -1;
  }
  // por omissão: o proprietário aprovado mais antigo
  try {
    const donos = app.findRecordsByFilter(
      'users',
      "papel = 'owner' && aprovado = true",
      'created',
      1,
      0,
    );
    return donos.length > 0 && donos[0].id === auth.id;
  } catch (_) {
    return false;
  }
}

module.exports = { ehOperador };
