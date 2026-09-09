/// <reference path="../pb_data/types.d.ts" />

// Regista no `historico` cada fatura apagada, para haver rasto.
// Fica indexado por (entidade_tipo='faturas_apagadas', entidade_id=<empresaId>)
// para se listar tudo de uma empresa.

onRecordAfterDeleteSuccess((e) => {
  try {
    const f = e.record;
    const empresaId = f.getString('empresa');
    if (!empresaId) {
      e.next();
      return;
    }
    const partes = [
      f.getString('fornecedor') || 'Fornecedor?',
      f.getString('numero') ? 'nº ' + f.getString('numero') : null,
      f.getString('data_fatura')
        ? String(f.getString('data_fatura')).substring(0, 10)
        : null,
      f.getString('estado') || 'nova',
      f.getString('notas') || null,
    ].filter(Boolean);

    const h = new Record(e.app.findCollectionByNameOrId('historico'));
    h.set('empresa', empresaId);
    h.set('entidade_tipo', 'faturas_apagadas');
    h.set('entidade_id', empresaId);
    h.set('descricao', 'Fatura apagada: ' + partes.join(' · '));
    e.app.save(h);
  } catch (err) {
    console.log('[faturas_hist] ' + err);
  }
  e.next();
}, 'faturas');
