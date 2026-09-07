// Migra os dados do PocketBase do `meu_app_ia` para o schema do turnkey_app.
//
// Uso:
//   dart run pb/seed/migrate_from_meu_app_ia.dart \
//     --src-url=http://100.x.x.x:8090 --src-email=admin@... --src-pass=... \
//     --dst-url=http://127.0.0.1:8090 --dst-email=dev@turnkey.local --dst-pass=... \
//     --empresa="Gookie" [--recompute] [--dry-run]
//
// Lê SÓ da origem. Cria uma empresa no destino e importa:
//   ingredientes, receitas_base, itens_receita, produtos_finais,
//   configuracoes_custo, historico_*.
// No fim (com --recompute) chama /api/turnkey/admin/recompute para recalcular
// custos em cascata e imprime um relatório de diferenças vs. os valores antigos.
//
// Nada de credenciais no repo — passa tudo por argumentos.

import 'dart:io';

import 'package:pocketbase/pocketbase.dart';
import 'package:turnkey_app/src/features/recipes/domain/recipe.dart';

Map<String, String> _args(List<String> argv) {
  final m = <String, String>{};
  for (final a in argv) {
    final i = a.indexOf('=');
    if (a.startsWith('--') && i > 2) {
      m[a.substring(2, i)] = a.substring(i + 1);
    } else if (a.startsWith('--')) {
      m[a.substring(2)] = 'true';
    }
  }
  return m;
}

double _num(dynamic v) =>
    v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);

Future<void> main(List<String> argv) async {
  final a = _args(argv);
  final srcUrl = a['src-url'];
  final dstUrl = a['dst-url'] ?? 'http://127.0.0.1:8090';
  final empresaNome = a['empresa'] ?? 'Gookie';
  final dryRun = a.containsKey('dry-run');
  final doRecompute = a.containsKey('recompute');

  if (srcUrl == null) {
    stderr.writeln('Falta --src-url.');
    exit(2);
  }

  final src = PocketBase(srcUrl);
  final dst = PocketBase(dstUrl);

  // A origem só é autenticada se derem credenciais; se as coleções tiverem
  // regras de leitura abertas, lê-se sem token.
  if (a['src-email'] != null && a['src-pass'] != null) {
    await src
        .collection('_superusers')
        .authWithPassword(a['src-email']!, a['src-pass']!);
    stdout.writeln('Autenticado na origem.');
  } else {
    stdout.writeln('Origem: leitura sem autenticação.');
  }
  await dst
      .collection('_superusers')
      .authWithPassword(
        a['dst-email'] ?? 'dev@turnkey.local',
        a['dst-pass'] ?? '',
      );
  stdout.writeln('Autenticado no destino.');

  Future<List<RecordModel>> all(PocketBase pb, String c) =>
      pb.collection(c).getFullList(batch: 500);

  Future<String> upsertEmpresa() async {
    final existentes = await dst
        .collection('empresas')
        .getList(filter: 'nome = "$empresaNome"', perPage: 1);
    if (existentes.items.isNotEmpty) return existentes.items.first.id;
    final rec = await dst.collection('empresas').create(
      body: {
        'nome': empresaNome,
        'slug':
            '${empresaNome.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '-')}-import',
        'moeda': 'EUR',
        'regra_arredondamento': 'cima',
        'plano': 'free',
      },
    );
    return rec.id;
  }

  final empresaId = dryRun ? 'DRY' : await upsertEmpresa();
  stdout.writeln('Empresa destino: $empresaId ($empresaNome)');

  // ---- configuracoes_custo ----
  final srcConfigs = await all(src, 'configuracoes_custo');
  if (srcConfigs.isNotEmpty && !dryRun) {
    final c = srcConfigs.first;
    final existing = await dst
        .collection('configuracoes_custo')
        .getList(filter: 'empresa = "$empresaId"', perPage: 1);
    final body = {
      'empresa': empresaId,
      'salario': _num(c.data['salario']),
      'aluguel': _num(c.data['aluguel']),
      'impostos': _num(c.data['impostos']),
      'servicos_e_gastos_intangiveis':
          _num(c.data['servicos_e_gastos_intangiveis']),
      'despesas_fixas': _num(c.data['despesas_fixas']),
      'taxas_financeiras': _num(c.data['taxas_financeiras']),
      'margem_de_lucro': _num(c.data['margem_de_lucro']),
    };
    if (existing.items.isEmpty) {
      await dst.collection('configuracoes_custo').create(body: body);
    } else {
      await dst
          .collection('configuracoes_custo')
          .update(existing.items.first.id, body: body);
    }
    stdout.writeln('configuracoes_custo importada.');
  }

  final ingMap = <String, String>{}; // src id -> dst id
  final recMap = <String, String>{};

  // ---- ingredientes ----
  final srcIngs = await all(src, 'ingredientes');
  for (final i in srcIngs) {
    final marca = '${i.data['marca'] ?? ''}';
    final dataAtual =
        '${i.data['data_atualizacao'] ?? i.data['data_criacao'] ?? ''}';
    final body = {
      'empresa': empresaId,
      'nome': '${i.data['nome'] ?? ''}',
      'caracteristica': '${i.data['caracteristica'] ?? ''}',
      'marca': marca,
      'fornecedor': '${i.data['fornecedor'] ?? ''}',
      'preco': _num(i.data['preco_sem_iva']),
      'gramas_embalagem': _num(i.data['gramas_embalagem']),
      if (dataAtual.isNotEmpty) 'preco_atualizado_em': dataAtual,
      'disponivel': true,
      'origem': marca.toLowerCase() == 'gookie' ? 'fabrico_proprio' : 'comprado',
      'deletado': i.data['deletado'] == true,
    };
    if (!dryRun) {
      final r = await dst.collection('ingredientes').create(body: body);
      ingMap[i.id] = r.id;
    }
  }
  stdout.writeln('ingredientes: ${srcIngs.length}');

  // ---- receitas_base -> receitas ----
  final srcRecs = await all(src, 'receitas_base');
  for (final r in srcRecs) {
    final body = {
      'empresa': empresaId,
      'nome': '${r.data['nome'] ?? ''}',
      'categoria':
          CategoriaReceita.fromLegacy('${r.data['categoria'] ?? ''}').api,
      'rendimento_esperado': _num(r.data['rendimento_esperado']),
      'custo_receita': _num(r.data['custo_receita']),
      'procedimento': '${r.data['procedimento'] ?? ''}',
      'deletado': r.data['deletado'] == true,
    };
    if (!dryRun) {
      final nr = await dst.collection('receitas').create(body: body);
      recMap[r.id] = nr.id;
    }
  }
  stdout.writeln('receitas: ${srcRecs.length}');

  // ---- itens_receita ----
  final srcItens = await all(src, 'itens_receita');
  var itensOk = 0;
  var itensPend = 0;
  for (final it in srcItens) {
    final recId = recMap['${it.data['receita_id']}'];
    if (recId == null) continue;
    final ingId = ingMap['${it.data['ingrediente_id']}'];
    final subId = recMap['${it.data['receita_vinculada_id']}'];
    final nome = '${it.data['nome'] ?? it.data['nome_provisorio'] ?? ''}';
    final body = {
      'empresa': empresaId,
      'receita': recId,
      'quantidade_g': _num(it.data['quantidade_g']),
      if (ingId != null) 'ingrediente': ingId,
      if (subId != null) 'sub_receita': subId,
      if (ingId == null && subId == null) 'nome_provisorio': nome,
    };
    if (ingId == null && subId == null) {
      itensPend++;
    } else {
      itensOk++;
    }
    if (!dryRun) await dst.collection('itens_receita').create(body: body);
  }
  stdout.writeln('itens_receita: $itensOk ligados, $itensPend pendentes');

  // ---- produtos_finais -> fichas_tecnicas + itens_ficha ----
  const slots = {
    'massa': 'massa',
    'recheio_base': 'recheio_base',
    'recheio_top': 'recheio_top',
    'cobertura_base': 'cobertura_base',
    'cobertura_top': 'cobertura_top',
    'extra': 'extra',
  };
  final srcProds = await all(src, 'produtos_finais');
  for (final p in srcProds) {
    if (dryRun) continue;
    final ficha = await dst.collection('fichas_tecnicas').create(
      body: {
        'empresa': empresaId,
        'nome': '${p.data['nome_produto'] ?? p.data['nome'] ?? ''}',
        'custo_produto': _num(p.data['custo_produto']),
        'peso_produto': _num(p.data['peso_produto']),
        'deletado': false,
      },
    );
    for (final slot in slots.keys) {
      final srcId = '${p.data['${slot}_id'] ?? ''}';
      final qtd = _num(p.data['peso_${slot}_g']);
      if (srcId.isEmpty || qtd <= 0) continue;
      final ingId = ingMap[srcId];
      final recId = recMap[srcId];
      if (ingId == null && recId == null) continue;
      await dst.collection('itens_ficha').create(
        body: {
          'empresa': empresaId,
          'ficha': ficha.id,
          'slot': slots[slot],
          'quantidade_g': qtd,
          if (ingId != null) 'ingrediente': ingId,
          if (ingId == null && recId != null) 'receita': recId,
        },
      );
    }
  }
  stdout.writeln('fichas_tecnicas: ${srcProds.length}');

  // ---- historico ----
  Future<void> importHist(String col, String tipo, String campoId) async {
    final rows = await all(src, col);
    for (final h in rows) {
      final srcRef = '${h.data[campoId] ?? ''}';
      final dstRef = tipo == 'receita' ? recMap[srcRef] : null;
      if (dryRun) continue;
      await dst.collection('historico').create(
        body: {
          'empresa': empresaId,
          'entidade_tipo': tipo,
          'entidade_id': dstRef ?? srcRef,
          'descricao': '${h.data['descricao'] ?? ''}',
        },
      );
    }
    stdout.writeln('$col: ${rows.length}');
  }

  try {
    await importHist('historico_receitas', 'receita', 'receita_id');
  } catch (_) {}
  try {
    await importHist('historico_produtos', 'ficha', 'produto_id');
  } catch (_) {}

  // ---- religar espelhos + recompute + relatório ----
  if (doRecompute && !dryRun) {
    final antes = <String, double>{
      for (final r in await all(dst, 'receitas'))
        '${r.data['nome']}': _num(r.data['custo_receita']),
    };
    // liga os ingredientes "Gookie" às respetivas receitas (por nome)
    final relink = await dst.send(
      '/api/turnkey/admin/relink-espelhos',
      method: 'POST',
      body: {'empresa': empresaId},
    );
    stdout.writeln('relink-espelhos: $relink');
    final res = await dst.send(
      '/api/turnkey/admin/recompute',
      method: 'POST',
      body: {'empresa': empresaId},
    );
    stdout.writeln('recompute: $res');
    var divergencias = 0;
    for (final r in await all(dst, 'receitas')) {
      final nome = '${r.data['nome']}';
      final novo = _num(r.data['custo_receita']);
      final velho = antes[nome] ?? 0;
      if ((novo - velho).abs() > 0.01) {
        divergencias++;
        stdout.writeln(
          '  ~ $nome: importado €${velho.toStringAsFixed(2)} '
          '-> recalculado €${novo.toStringAsFixed(2)}',
        );
      }
    }
    stdout.writeln(
      divergencias == 0
          ? 'Totais batem certo (tolerância 0,01).'
          : '$divergencias receita(s) com diferença — verificar acima.',
    );
  }

  // ---- ligar um utilizador existente a esta empresa (para poder explorar) ----
  final attach = a['attach-user'];
  if (attach != null && !dryRun) {
    final u = await dst
        .collection('users')
        .getList(filter: 'email = "$attach"', perPage: 1);
    if (u.items.isNotEmpty) {
      await dst.collection('users').update(
        u.items.first.id,
        body: {'empresa': empresaId, 'papel': 'owner'},
      );
      stdout.writeln('$attach ligado à empresa $empresaNome como owner.');
    } else {
      stdout.writeln('Aviso: utilizador $attach não encontrado no destino.');
    }
  }

  stdout.writeln(dryRun ? 'Dry-run concluído.' : 'Migração concluída.');
}
