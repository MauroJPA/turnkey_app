/// <reference path="../pb_data/types.d.ts" />

// Alergénios na tabela de referência (INSA): a BDCA não traz os 14 alergénios
// da UE, por isso inferimo-los do NOME e do GRUPO do alimento por palavras-
// chave (sem acentos, minúsculas). É uma sugestão — quem preenche um
// ingrediente confirma sempre na folha de nutrição.
//
// Palavras de uma só palavra são comparadas contra TOKENS do nome (evita
// "chocolate"→"choco", "compota"→"pota"); expressões com espaço são
// comparadas como substring do nome inteiro.

migrate(
  (app) => {
    const ALERGENIOS = [
      'Glúten', 'Crustáceos', 'Ovos', 'Peixe', 'Amendoins', 'Soja', 'Leite',
      'Frutos de casca rija', 'Aipo', 'Mostarda', 'Sésamo', 'Sulfitos',
      'Tremoço', 'Moluscos',
    ];

    const ref = app.findCollectionByNameOrId('ingredientes_referencia');
    if (!ref.fields.getByName('alergenios')) {
      ref.fields.add(
        new Field({
          type: 'select',
          name: 'alergenios',
          required: false,
          maxSelect: ALERGENIOS.length,
          values: ALERGENIOS,
        }),
      );
      app.save(ref);
    }

    const semAcentos = (s) => {
      const m = {
        'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a', 'ä': 'a',
        'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
        'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
        'ó': 'o', 'ò': 'o', 'õ': 'o', 'ô': 'o', 'ö': 'o',
        'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ç': 'c',
      };
      let o = String(s).toLowerCase();
      for (const k in m) o = o.split(k).join(m[k]);
      return o;
    };

    // palavra única -> comparação por token (com plurais -s/-es/-is)
    const KW = {
      'Glúten': [
        'trigo', 'semola', 'semolina', 'cuscuz', 'bulgur', 'centeio', 'cevada',
        'malte', 'cerveja', 'pao', 'tosta', 'bolacha', 'bolachas', 'biscoito',
        'biscoitos', 'bolo', 'bolos', 'croissant', 'esparguete', 'macarrao',
        'lasanha', 'penne', 'seitan', 'aveia', 'espelta', 'kamut', 'pastel',
        'pasteis', 'empada', 'rissol', 'rissois', 'croquete', 'croquetes',
        'panado', 'panados', 'pizza', 'waffle', 'panqueca', 'panquecas',
        'acorda', 'farinha',
      ],
      'Leite': [
        'leite', 'queijo', 'requeijao', 'iogurte', 'manteiga', 'nata', 'natas',
        'bechamel', 'caseina', 'coalhada', 'kefir', 'chantilly', 'ricota',
        'mozzarella', 'mascarpone', 'lacteo', 'lacteos',
      ],
      'Ovos': [
        'ovo', 'ovos', 'gema', 'gemas', 'maionese', 'omeleta', 'merengue',
        'suspiro', 'suspiros', 'ovoproduto',
      ],
      'Frutos de casca rija': [
        'amendoa', 'amendoas', 'avela', 'avelas', 'noz', 'nozes', 'pecan',
        'caju', 'pistacio', 'pistacios', 'pinhao', 'pinhoes', 'castanha',
        'castanhas', 'macadamia', 'marzipa',
      ],
      'Amendoins': ['amendoim', 'amendoins'],
      'Soja': ['soja', 'tofu', 'edamame', 'miso', 'tempeh'],
      'Peixe': [
        'peixe', 'bacalhau', 'atum', 'sardinha', 'sardinhas', 'pescada',
        'salmao', 'truta', 'cavala', 'carapau', 'robalo', 'dourada', 'linguado',
        'corvina', 'faneca', 'arenque', 'anchova', 'anchovas', 'garoupa',
        'sarda', 'espadarte', 'pargo', 'cherne', 'tamboril', 'raia', 'congro',
        'savel', 'lampreia', 'enguia', 'abrotea', 'caviar', 'ovas', 'chicharro',
        'bonito', 'maruca', 'goraz', 'safio', 'solha', 'pescadinha',
      ],
      'Crustáceos': [
        'camarao', 'camaroes', 'gamba', 'gambas', 'lagosta', 'lagostim',
        'lagostins', 'caranguejo', 'sapateira', 'santola', 'navalheira',
        'percebe', 'percebes', 'lavagante',
      ],
      'Moluscos': [
        'ameijoa', 'ameijoas', 'amijoa', 'mexilhao', 'mexilhoes', 'berbigao',
        'lula', 'lulas', 'pota', 'polvo', 'choco', 'chocos', 'ostra', 'ostras',
        'vieira', 'vieiras', 'lapa', 'lapas', 'caracol', 'caracois', 'buzio',
        'buzios', 'canilha', 'longueiron', 'navalha', 'navalhas',
      ],
      'Sésamo': ['sesamo', 'tahini', 'gergelim', 'halva'],
      'Mostarda': ['mostarda'],
      'Aipo': ['aipo'],
      'Tremoço': ['tremoco', 'tremocos'],
      'Sulfitos': ['sulfito', 'sulfitos', 'passas'],
    };
    // expressões (substring no nome inteiro)
    const FRASES = {
      'Glúten': [
        'farinha de trigo', 'massa folhada', 'massa quebrada',
        'massa alimenticia', 'farinha de espelta', 'pao de', 'pao ralado',
      ],
      'Leite': [
        'soro de leite', 'creme de leite', 'doce de leite', 'leite condensado',
        'leite em po', 'gelado de leite', 'gelado de nata',
      ],
      'Ovos': ['clara de ovo', 'ovo mexido'],
      'Frutos de casca rija': ['casca rija', 'noz-pecan', 'castanha de caju'],
      'Amendoins': ['manteiga de amendoim'],
      'Soja': ['molho de soja', 'proteina de soja', 'lecitina de soja'],
      'Sésamo': ['oleo de sesamo'],
      'Sulfitos': [
        'vinho tinto', 'vinho branco', 'vinho do porto', 'vinho verde',
        'vinagre de vinho', 'fruta desidratada', 'damasco seco',
      ],
    };
    const MARISCO = ['Crustáceos', 'Moluscos']; // "marisco" genérico

    const GRUPO_REGRAS = [
      { chave: 'leite e produtos', al: 'Leite' },
      { chave: 'ovos e ovoprodutos', al: 'Ovos' },
    ];

    const plural = (tok, kw) =>
      tok === kw || tok === kw + 's' || tok === kw + 'es' ||
      tok === kw + 'is';

    const inferir = (nome, grupo) => {
      const nn = semAcentos(nome);
      const toks = nn.replace(/[^a-z0-9 ]/g, ' ').split(/\s+/).filter(Boolean);
      const g = semAcentos(grupo);
      const set = {};

      for (const al in KW) {
        for (const kw of KW[al]) {
          let hit = false;
          for (const t of toks) {
            if (plural(t, kw)) { hit = true; break; }
          }
          if (hit) { set[al] = true; break; }
        }
      }
      for (const al in FRASES) {
        if (set[al]) continue;
        for (const f of FRASES[al]) {
          if (nn.indexOf(f) >= 0) { set[al] = true; break; }
        }
      }
      if (toks.indexOf('marisco') >= 0 || toks.indexOf('mariscos') >= 0) {
        for (const al of MARISCO) set[al] = true;
      }
      for (const r of GRUPO_REGRAS) {
        if (g.indexOf(r.chave) >= 0) set[r.al] = true;
      }
      // cogumelo "ostra"/"pleurotus" não é molusco
      if (toks.indexOf('cogumelo') >= 0 || toks.indexOf('cogumelos') >= 0 ||
          nn.indexOf('pleurotus') >= 0) {
        delete set['Moluscos'];
      }
      // "farinha de milho/arroz/mandioca/..." não é glúten
      if (set['Glúten'] && toks.indexOf('farinha') >= 0) {
        const semGluten = ['milho', 'arroz', 'mandioca', 'alfarroba', 'grao',
          'castanha', 'coco', 'amendoa', 'trigo sarraceno'];
        let outroCereal = false;
        for (const kw of ['trigo', 'centeio', 'cevada', 'aveia', 'espelta',
          'semola', 'malte']) {
          if (toks.indexOf(kw) >= 0) outroCereal = true;
        }
        if (!outroCereal) {
          for (const s of semGluten) {
            if (nn.indexOf('farinha de ' + s) >= 0 ||
                nn.indexOf('farinha ' + s) >= 0) {
              // só remove se a única razão do glúten era "farinha"
              let soFarinha = true;
              for (const kw of KW['Glúten']) {
                if (kw === 'farinha') continue;
                for (const t of toks) if (plural(t, kw)) soFarinha = false;
              }
              for (const f of FRASES['Glúten']) {
                if (nn.indexOf(f) >= 0) soFarinha = false;
              }
              if (soFarinha) delete set['Glúten'];
              break;
            }
          }
        }
      }

      const out = [];
      for (const al of ALERGENIOS) if (set[al]) out.push(al);
      return out;
    };

    const todos = app.findRecordsByFilter(
      'ingredientes_referencia', "id != ''", 'nome', 0, 0, {},
    );
    for (const r of todos) {
      const al = inferir(r.getString('nome'), r.getString('grupo'));
      const atual = r.get('alergenios');
      const igual =
        Array.isArray(atual) &&
        atual.length === al.length &&
        al.every((x) => atual.indexOf(x) >= 0);
      if (!igual) {
        r.set('alergenios', al);
        app.save(r);
      }
    }
  },
  (app) => {
    const ref = app.findCollectionByNameOrId('ingredientes_referencia');
    if (ref.fields.getByName('alergenios')) {
      ref.fields.removeByName('alergenios');
      app.save(ref);
    }
  },
);
