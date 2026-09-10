import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/nutrition/nutrition.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../domain/auto_insa.dart';
import '../domain/ingredient.dart';
import '../domain/ingrediente_referencia.dart';

final ingredientRepositoryProvider = Provider<IngredientRepository>((ref) {
  return IngredientRepository(
    ref.watch(pbProvider),
    requireEmpresaId(ref),
  );
});

/// Subconjunto de escrita usado pelo import de CSV (facilita testar).
abstract interface class IngredientWriter {
  Future<Ingrediente?> findByName(String nome);
  Future<Ingrediente> create(IngredienteInput input);
  Future<Ingrediente> update(String id, IngredienteInput input);
}

class IngredientRepository implements IngredientWriter {
  IngredientRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  RecordService get _c => _pb.collection('ingredientes');

  Future<List<Ingrediente>> list({bool trash = false}) async {
    final recs = await _c.getFullList(
      filter: 'empresa = "$_empresaId" && deletado = $trash',
      sort: 'nome',
    );
    return recs.map(Ingrediente.fromRecord).toList();
  }

  Future<Ingrediente> getById(String id) async =>
      Ingrediente.fromRecord(await _c.getOne(id));

  @override
  Future<Ingrediente> create(IngredienteInput input) async {
    final rec = await _c.create(
      body: {...input.toBody(), 'empresa': _empresaId, 'deletado': false},
    );
    return Ingrediente.fromRecord(rec);
  }

  @override
  Future<Ingrediente> update(String id, IngredienteInput input) async {
    final rec = await _c.update(id, body: input.toBody());
    return Ingrediente.fromRecord(rec);
  }

  Future<Ingrediente> duplicate(Ingrediente src) =>
      create(IngredienteInput.fromModel(src, nome: '${src.nome} (cópia)'));

  // --- nutrição -------------------------------------------------------

  String _mimeRotulo(String nome) {
    final n = nome.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.pdf')) return 'application/pdf';
    return 'image/jpeg';
  }

  /// Lê um rótulo (foto/PDF) por IA e preenche os campos nutricionais +
  /// alergénios do ingrediente. Devolve o ingrediente atualizado.
  Future<Ingrediente> analisarRotulo(
    String id, {
    required List<int> bytes,
    required String nome,
  }) async {
    await _pb.send(
      '/api/turnkey/ingredientes/$id/rotulo',
      method: 'POST',
      body: {'imagem': base64Encode(bytes), 'mime': _mimeRotulo(nome)},
    );
    return getById(id);
  }

  /// Grava a nutrição/alergénios editados à mão (origem = manual).
  Future<Ingrediente> definirNutricao(
    String id, {
    required Nutrientes nutri,
    String base = '100g',
    double densidade = 1,
    required List<String> alergenios,
    required List<String> alergeniosTracos,
    String origem = 'manual',
  }) async {
    final rec = await _c.update(id, body: {
      ...nutri.toCampos(),
      'nutri_base': base,
      'nutri_densidade': densidade,
      'nutri_origem': origem,
      'nutri_atualizado_em': DateTime.now().toUtc().toIso8601String(),
      'alergenios': alergenios,
      'alergenios_tracos': alergeniosTracos,
    });
    return Ingrediente.fromRecord(rec);
  }

  /// Emparelha ingredientes com a tabela INSA no servidor. Sem [ids], processa
  /// os que ainda não têm nutrição. Com [dryRun] só devolve os candidatos
  /// (não grava nada) — usado para mostrar sugestões na folha de nutrição.
  Future<ResumoAutoInsa> autoInsa({
    List<String>? ids,
    bool dryRun = false,
  }) async {
    final res = await _pb.send(
      '/api/turnkey/ingredientes/auto-insa',
      method: 'POST',
      body: {
        if (ids != null) 'ids': ids,
        'dryRun': dryRun,
      },
    );
    return ResumoAutoInsa.fromJson(Map<String, dynamic>.from(res as Map));
  }

  static String _semAcentos(String s) {
    const m = {
      'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a', 'ä': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
      'ó': 'o', 'ò': 'o', 'õ': 'o', 'ô': 'o', 'ö': 'o',
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ç': 'c',
    };
    var out = s.toLowerCase();
    m.forEach((k, v) => out = out.replaceAll(k, v));
    return out;
  }

  /// Pesquisa na tabela partilhada de referência (ex.: INSA BDCA). Procura no
  /// nome e no nome normalizado (sem acentos) guardado em `sinonimos`.
  Future<List<IngredienteReferencia>> referencias({
    String q = '',
    int limite = 40,
  }) async {
    final termo = q.trim().replaceAll("'", ' ');
    final norm = _semAcentos(termo);
    final res = await _pb.collection('ingredientes_referencia').getList(
          page: 1,
          perPage: limite,
          filter: termo.isEmpty
              ? ''
              : "nome ~ '$termo' || sinonimos ~ '$norm'",
          sort: 'nome',
        );
    return res.items.map(IngredienteReferencia.fromRecord).toList();
  }

  Future<void> setDeleted(String id, {required bool deletado}) =>
      _c.update(id, body: {'deletado': deletado});

  Future<void> hardDelete(String id) => _c.delete(id);

  /// Procura pelo nome exato (para o import de CSV decidir criar vs. atualizar).
  @override
  Future<Ingrediente?> findByName(String nome) async {
    final safe = nome.replaceAll('"', '');
    final res = await _c.getList(
      page: 1,
      perPage: 1,
      filter: 'empresa = "$_empresaId" && nome = "$safe"',
    );
    return res.items.isEmpty
        ? null
        : Ingrediente.fromRecord(res.items.first);
  }
}
