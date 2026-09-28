/// <reference path="../pb_data/types.d.ts" />

// `embalagens.formatos_cookie` é uma relação de VÁRIOS (multi-select): a regra
// declarativa da coleção só garante que pelo menos um formato é da mesma
// empresa (é como o PocketBase avalia relações "field.subfield = valor" em
// listas). Este hook confirma que TODOS os formatos escolhidos são da mesma
// empresa — sem isto, dava para misturar um formato de outra empresa dentro
// da lista.
//
// NOTA: cada handler é autocontido (os handlers correm isolados).

function validarFormatos(e) {
  const auth = e.auth;
  const isSuper = auth && auth.collection() && auth.collection().name === '_superusers';
  if (isSuper) {
    e.next();
    return;
  }
  const ids = e.record.get('formatos_cookie');
  const lista = Array.isArray(ids) ? ids : ids ? [ids] : [];
  const empresaId = e.record.getString('empresa');
  for (let i = 0; i < lista.length; i++) {
    let formato;
    try {
      formato = e.app.findRecordById('formatos_cookie', String(lista[i]));
    } catch (_) {
      throw new BadRequestError('Formato de cookie não encontrado.');
    }
    if (formato.getString('empresa') !== empresaId) {
      throw new BadRequestError('Um dos formatos de cookie é de outra empresa.');
    }
  }
  e.next();
}

onRecordCreateRequest(validarFormatos, 'embalagens');
onRecordUpdateRequest(validarFormatos, 'embalagens');
