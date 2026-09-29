import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../domain/stock_item.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(ref.watch(pbProvider), requireEmpresaId(ref));
});

class InventoryRepository {
  InventoryRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  /// Todos os ingredientes, fichas e consumíveis com stock (Bebida/Revenda/…)
  /// com o stock atual (0 se não houver linha).
  Future<List<StockItem>> list() async {
    final ings = await _pb.collection('ingredientes').getFullList(
          filter: 'empresa = "$_empresaId" && deletado != true',
          sort: 'nome',
        );
    final fichas = await _pb.collection('fichas_tecnicas').getFullList(
          filter: 'empresa = "$_empresaId" && deletado != true',
          sort: 'nome',
        );
    final cons = await _pb.collection('consumiveis').getFullList(
          filter: 'empresa = "$_empresaId" && deletado != true',
          sort: 'nome',
        );
    final inv = await _pb.collection('inventario').getFullList(
          filter: 'empresa = "$_empresaId"',
        );

    final invByIng = <String, RecordModel>{};
    final invByFicha = <String, RecordModel>{};
    final invByCons = <String, RecordModel>{};
    for (final r in inv) {
      final ing = r.getStringValue('ingrediente');
      final fic = r.getStringValue('ficha');
      final co = r.getStringValue('consumivel');
      if (ing.isNotEmpty) invByIng[ing] = r;
      if (fic.isNotEmpty) invByFicha[fic] = r;
      if (co.isNotEmpty) invByCons[co] = r;
    }

    final out = <StockItem>[];
    for (final i in ings) {
      final row = invByIng[i.id];
      final preco = i.getDoubleValue('preco');
      final g = i.getDoubleValue('gramas_embalagem');
      out.add(
        StockItem(
          tipo: StockTipo.ingrediente,
          id: i.id,
          nome: i.getStringValue('nome'),
          quantidade: row?.getDoubleValue('quantidade') ?? 0,
          custoUnitario: g > 0 ? preco / g : 0,
          minimo: row?.getDoubleValue('minimo') ?? 0,
          localizacao: row?.getStringValue('localizacao') ?? '',
          inventarioId: row?.id,
          favorito: row?.getBoolValue('favorito') ?? false,
          usos: row?.getDoubleValue('usos') ?? 0,
          ultimoUso: row?.getStringValue('ultimo_uso') ?? '',
          unidadeIng: i.getStringValue('unidade'),
        ),
      );
    }
    for (final f in fichas) {
      final row = invByFicha[f.id];
      out.add(
        StockItem(
          tipo: StockTipo.ficha,
          id: f.id,
          nome: f.getStringValue('nome'),
          quantidade: row?.getDoubleValue('quantidade') ?? 0,
          custoUnitario: f.getDoubleValue('custo_produto'),
          minimo: row?.getDoubleValue('minimo') ?? 0,
          localizacao: row?.getStringValue('localizacao') ?? '',
          inventarioId: row?.id,
          favorito: row?.getBoolValue('favorito') ?? false,
          usos: row?.getDoubleValue('usos') ?? 0,
          ultimoUso: row?.getStringValue('ultimo_uso') ?? '',
        ),
      );
    }
    for (final c in cons) {
      final row = invByCons[c.id];
      out.add(
        StockItem(
          tipo: StockTipo.consumivel,
          id: c.id,
          nome: c.getStringValue('nome'),
          quantidade: row?.getDoubleValue('quantidade') ?? 0,
          custoUnitario: c.getDoubleValue('preco'),
          minimo: row?.getDoubleValue('minimo') ?? 0,
          localizacao: row?.getStringValue('localizacao') ?? '',
          inventarioId: row?.id,
          categoria: c.getStringValue('categoria'),
          favorito: row?.getBoolValue('favorito') ?? false,
          usos: row?.getDoubleValue('usos') ?? 0,
          ultimoUso: row?.getStringValue('ultimo_uso') ?? '',
        ),
      );
    }
    // Itens livres: linhas de inventário sem ingrediente, ficha ou consumível.
    for (final r in inv) {
      if (r.getStringValue('ingrediente').isNotEmpty) continue;
      if (r.getStringValue('ficha').isNotEmpty) continue;
      if (r.getStringValue('consumivel').isNotEmpty) continue;
      final desc = r.getStringValue('descricao');
      if (desc.isEmpty) continue;
      out.add(
        StockItem(
          tipo: StockTipo.livre,
          id: desc,
          nome: desc,
          quantidade: r.getDoubleValue('quantidade'),
          custoUnitario: 0,
          minimo: r.getDoubleValue('minimo'),
          localizacao: r.getStringValue('localizacao'),
          inventarioId: r.id,
          unidadeLivre: r.getStringValue('unidade'),
          categoria: r.getStringValue('categoria'),
          favorito: r.getBoolValue('favorito'),
          usos: r.getDoubleValue('usos'),
          ultimoUso: r.getStringValue('ultimo_uso'),
        ),
      );
    }
    return out;
  }

  Future<double> ajustar({
    String? ingredienteId,
    String? fichaId,
    String? consumivelId,
    String? descricao,
    String? unidade,
    String? categoria,
    double delta = 0,
    MotivoMovimento motivo = MotivoMovimento.ajuste,
    String? notas,
    double? minimo,
    String? localizacao,
    bool? favorito,
  }) async {
    final res = await _pb.send(
      '/api/gc_turnkey/inventario/ajustar',
      method: 'POST',
      body: {
        if (ingredienteId != null) 'ingrediente': ingredienteId,
        if (fichaId != null) 'ficha': fichaId,
        if (consumivelId != null) 'consumivel': consumivelId,
        if (descricao != null) 'descricao': descricao,
        if (unidade != null) 'unidade': unidade,
        if (categoria != null) 'categoria': categoria,
        'delta': delta,
        'motivo': motivo.api,
        if (notas != null && notas.isNotEmpty) 'notas': notas,
        if (minimo != null) 'minimo': minimo,
        if (localizacao != null) 'localizacao': localizacao,
        if (favorito != null) 'favorito': favorito,
      },
    );
    return ((res as Map<String, dynamic>)['quantidade'] as num?)?.toDouble() ??
        0;
  }

  Future<List<MovimentoStock>> movimentos({
    String? ingredienteId,
    String? fichaId,
    String? consumivelId,
    String? descricao,
  }) async {
    final campo = ingredienteId != null
        ? 'ingrediente'
        : fichaId != null
            ? 'ficha'
            : consumivelId != null
                ? 'consumivel'
                : 'descricao';
    final id = ingredienteId ?? fichaId ?? consumivelId ?? descricao;
    final res = await _pb.collection('movimentos_inventario').getList(
          page: 1,
          perPage: 60,
          filter: '$campo = "$id"',
          sort: '-created',
        );
    return res.items.map(MovimentoStock.fromRecord).toList();
  }
}
