import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../../sales/domain/venda.dart' show ymd;
import '../domain/compra_registada.dart';
import '../domain/stock_item.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(ref.watch(pbProvider), requireEmpresaId(ref));
});

class InventoryRepository {
  InventoryRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  /// Todos os ingredientes e consumíveis com stock (Bebida/Revenda/…) com o
  /// stock atual (0 se não houver linha). Os cookies prontos contam-se na
  /// Contagem diária, não aqui.
  Future<List<StockItem>> list() async {
    final ings = await _pb.collection('ingredientes').getFullList(
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
    final invByCons = <String, RecordModel>{};
    for (final r in inv) {
      final ing = r.getStringValue('ingrediente');
      final co = r.getStringValue('consumivel');
      if (ing.isNotEmpty) invByIng[ing] = r;
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

  /// As compras que deram entrada no stock entre [desde] e [ate] (inclusive,
  /// em dias locais): dar o visto na lista de compras ou aplicar uma fatura.
  Future<List<CompraRegistada>> compras({
    required DateTime desde,
    required DateTime ate,
  }) async {
    String utc(DateTime local) {
      final u = local.toUtc();
      return '${ymd(u)} '
          '${u.hour.toString().padLeft(2, '0')}:'
          '${u.minute.toString().padLeft(2, '0')}:00.000Z';
    }

    final inicio = DateTime(desde.year, desde.month, desde.day);
    final fim = DateTime(ate.year, ate.month, ate.day + 1);
    final recs = await _pb.collection('movimentos_inventario').getFullList(
          filter:
              'empresa = "$_empresaId" && motivo = "compra" && delta > 0 && '
              'created >= "${utc(inicio)}" && created < "${utc(fim)}"',
          sort: 'created',
          expand: 'ingrediente,consumivel',
        );
    return recs.map(CompraRegistada.fromRecord).toList();
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
