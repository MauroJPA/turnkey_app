import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../pocketbase/pb_client.dart';

class HistoryEntry {
  HistoryEntry({required this.descricao, required this.created});
  final String descricao;
  final String created;

  factory HistoryEntry.fromRecord(RecordModel r) => HistoryEntry(
        descricao: r.getStringValue('descricao'),
        created: r.getStringValue('created'),
      );
}

final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => HistoryRepository(ref.watch(pbProvider)),
);

class HistoryRepository {
  HistoryRepository(this._pb);
  final PocketBase _pb;

  /// [tipo] é 'ingrediente' | 'receita' | 'ficha'.
  Future<List<HistoryEntry>> forEntity(String tipo, String id) async {
    final res = await _pb.collection('historico').getList(
          page: 1,
          perPage: 60,
          filter: 'entidade_tipo = "$tipo" && entidade_id = "$id"',
          sort: '-created',
        );
    return res.items.map(HistoryEntry.fromRecord).toList();
  }
}

/// (tipo, id) -> entradas de histórico.
final historyProvider = FutureProvider.autoDispose
    .family<List<HistoryEntry>, ({String tipo, String id})>((ref, key) {
  return ref.watch(historyRepositoryProvider).forEntity(key.tipo, key.id);
});
