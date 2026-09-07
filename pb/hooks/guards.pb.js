/// <reference path="../pb_data/types.d.ts" />

// Impede que um utilizador altere a sua própria `empresa` ou `papel` por uma
// chamada normal à API. Estes campos só mudam via:
//   - hook de onboarding (POST /api/turnkey/onboarding), ou
//   - gestão de equipa por admin/owner (endpoint próprio, M6),
// ambos com privilégios de servidor (não passam por onRecordUpdateRequest).
onRecordUpdateRequest((e) => {
  const original = e.record.original();
  const mudouEmpresa =
    e.record.getString('empresa') !== original.getString('empresa');
  const mudouPapel =
    e.record.getString('papel') !== original.getString('papel');

  if (mudouEmpresa || mudouPapel) {
    throw new ForbiddenError(
      "Os campos 'empresa' e 'papel' não podem ser alterados por esta via.",
    );
  }

  e.next();
}, 'users');
