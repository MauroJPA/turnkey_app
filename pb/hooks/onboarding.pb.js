/// <reference path="../pb_data/types.d.ts" />

// Onboarding atómico: cria a empresa, promove o utilizador autenticado a
// `owner` e cria a linha de configuracoes_custo — tudo numa transação e com
// privilégios de servidor (as regras de API não permitem estes passos ao
// utilizador diretamente, de propósito).
//
// POST /api/gc_turnkey/onboarding
//   body: { nome: string, moeda: "EUR"|..., regra: "cima"|"normal" }
//   -> 200 { empresaId }

routerAdd(
  'POST',
  '/api/gc_turnkey/onboarding',
  (e) => {
    const user = e.auth;
    if (!user || user.collection().name !== 'users') {
      throw new ForbiddenError('Autenticação necessária.');
    }
    if (user.getString('empresa')) {
      throw new BadRequestError('Este utilizador já pertence a uma empresa.');
    }
    if (!user.getBool('aprovado')) {
      throw new ForbiddenError('A tua conta ainda aguarda aprovação.');
    }

    const body = e.requestInfo().body || {};
    const nome = (body.nome || '').toString().trim();
    if (!nome) throw new BadRequestError('Nome da empresa em falta.');

    const moeda = ['EUR', 'BRL', 'USD', 'GBP'].includes(body.moeda)
      ? body.moeda
      : 'EUR';
    const regra = body.regra === 'normal' ? 'normal' : 'cima';

    let empresaId = '';

    e.app.runInTransaction((tx) => {
      const empresas = tx.findCollectionByNameOrId('empresas');
      const empresa = new Record(empresas);
      empresa.set('nome', nome);
      empresa.set(
        'slug',
        nome
          .toLowerCase()
          .replace(/[^a-z0-9]+/g, '-')
          .replace(/(^-+|-+$)/g, '') +
          '-' +
          Date.now().toString(36),
      );
      empresa.set('moeda', moeda);
      empresa.set('regra_arredondamento', regra);
      empresa.set('plano', 'free');
      tx.save(empresa);
      empresaId = empresa.id;

      const fresh = tx.findRecordById('users', user.id);
      if (fresh.getString('empresa')) {
        throw new BadRequestError('Este utilizador já pertence a uma empresa.');
      }
      fresh.set('empresa', empresaId);
      fresh.set('papel', 'owner');
      tx.save(fresh);

      const configs = tx.findCollectionByNameOrId('configuracoes_custo');
      const cfg = new Record(configs);
      cfg.set('empresa', empresaId);
      for (const campo of [
        'salario',
        'aluguel',
        'impostos',
        'servicos_e_gastos_intangiveis',
        'despesas_fixas',
        'taxas_financeiras',
        'margem_de_lucro',
      ]) {
        cfg.set(campo, 0);
      }
      tx.save(cfg);

      // Formatos de cookie por omissão (ver 1705104000_formatos_cookie.js).
      const formatos = tx.findCollectionByNameOrId('formatos_cookie');
      const seedFormatos = [
        { nome: 'Mini', massa_g: 20, recheio_g: 0, ordem: 1 },
        { nome: 'Recheado', massa_g: 120, recheio_g: 30, ordem: 2 },
        { nome: 'Simples', massa_g: 150, recheio_g: 0, ordem: 3 },
      ];
      for (const f of seedFormatos) {
        const fr = new Record(formatos);
        fr.set('empresa', empresaId);
        fr.set('nome', f.nome);
        fr.set('massa_g', f.massa_g);
        fr.set('recheio_g', f.recheio_g);
        fr.set('ordem', f.ordem);
        fr.set('ativo', true);
        tx.save(fr);
      }

      // Categorias de receitas por omissão (ver 1707955220_categorias_receita.js).
      const categorias = tx.findCollectionByNameOrId('categorias_receita');
      const seedCategorias = [
        { nome: 'Massa', ordem: 1 },
        { nome: 'Recheio', ordem: 2 },
        { nome: 'Cobertura', ordem: 3 },
        { nome: 'Outra', ordem: 4 },
      ];
      for (const cat of seedCategorias) {
        const cr = new Record(categorias);
        cr.set('empresa', empresaId);
        cr.set('nome', cat.nome);
        cr.set('ordem', cat.ordem);
        cr.set('ativo', true);
        tx.save(cr);
      }
    });

    return e.json(200, { empresaId: empresaId });
  },
  $apis.requireAuth('users'),
);
