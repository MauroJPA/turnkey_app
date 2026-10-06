/// <reference path="../pb_data/types.d.ts" />

// Impede que um utilizador altere a sua própria `empresa` ou `papel` por uma
// chamada normal à API. Estes campos só mudam via:
//   - hook de onboarding (POST /api/gc_turnkey/onboarding), ou
//   - gestão de equipa por admin/owner (endpoint próprio, M6),
// ambos com privilégios de servidor (não passam por onRecordUpdateRequest).
onRecordUpdateRequest((e) => {
  // Superusers (Admin UI, scripts de manutenção) não são bloqueados.
  const auth = e.auth;
  if (auth && auth.collection() && auth.collection().name === '_superusers') {
    e.next();
    return;
  }

  const original = e.record.original();
  const mudouEmpresa =
    e.record.getString('empresa') !== original.getString('empresa');
  const mudouPapel =
    e.record.getString('papel') !== original.getString('papel');

  if (e.record.getBool('aprovado') !== original.getBool('aprovado')) {
    throw new ForbiddenError(
      "O campo 'aprovado' só pode ser alterado pelo operador da plataforma.",
    );
  }

  if (e.record.getBool('senha_provisoria') !== original.getBool('senha_provisoria')) {
    throw new ForbiddenError(
      "O campo 'senha_provisoria' só muda pelos endpoints da equipa.",
    );
  }

  if (mudouEmpresa || mudouPapel) {
    throw new ForbiddenError(
      "Os campos 'empresa' e 'papel' não podem ser alterados por esta via.",
    );
  }

  e.next();
}, 'users');
