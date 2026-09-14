import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../domain/venda.dart';

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return SalesRepository(ref.watch(pbProvider), requireEmpresaId(ref));
});

class SalesRepository {
  SalesRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  RecordService get _vendas => _pb.collection('vendas');
  RecordService get _itens => _pb.collection('vendas_itens');

  /// Vendas entre [desde] e [ate] (inclusive), mais recentes primeiro.
  ///
  /// O filtro de datas do PocketBase compara literais pelo formato completo
  /// guardado (`yyyy-MM-dd HH:mm:ss.SSSZ`) — uma data "nua" não é comparada
  /// semanticamente e falha silenciosamente para `<=` (ex.: "2026-09-14" não
  /// bate com "2026-09-14 00:00:00.000Z"). Por isso o início do dia leva
  /// sempre `00:00:00.000Z` e o fim `23:59:59.999Z`.
  Future<List<Venda>> list({DateTime? desde, DateTime? ate}) async {
    final filtros = ['empresa = "$_empresaId"'];
    if (desde != null) filtros.add('data >= "${ymd(desde)} 00:00:00.000Z"');
    if (ate != null) filtros.add('data <= "${ymd(ate)} 23:59:59.999Z"');
    final recs = await _vendas.getFullList(
      filter: filtros.join(' && '),
      sort: '-data,-created',
    );
    return recs.map(Venda.fromRecord).toList();
  }

  Future<Venda> getById(String id) async =>
      Venda.fromRecord(await _vendas.getOne(id));

  Future<List<VendaItem>> itensDe(String vendaId) async {
    final recs = await _itens.getFullList(filter: 'venda = "$vendaId"');
    return recs.map(VendaItem.fromRecord).toList();
  }

  /// Vendas e respetivas linhas entre [desde] e [ate] (inclusive) — para o
  /// painel financeiro. Filtra as linhas do lado do cliente (por id da
  /// venda) em vez de um filtro por relação (`venda.data`), que o PocketBase
  /// não garante comparar semanticamente; para uma empresa deste porte o
  /// volume de `vendas_itens` é pequeno, por isso é seguro trazer tudo.
  Future<({List<Venda> vendas, List<VendaItem> itens})> periodo({
    required DateTime desde,
    required DateTime ate,
  }) async {
    final vendas = await list(desde: desde, ate: ate);
    if (vendas.isEmpty) return (vendas: vendas, itens: <VendaItem>[]);
    final idsValidos = vendas.map((v) => v.id).toSet();
    final todosItens = await _itens.getFullList(filter: 'empresa = "$_empresaId"');
    final itens = todosItens
        .map(VendaItem.fromRecord)
        .where((it) => idsValidos.contains(it.vendaId))
        .toList();
    return (vendas: vendas, itens: itens);
  }

  /// Cria uma venda com as suas linhas (o total é a soma das linhas).
  Future<Venda> criar({
    required DateTime data,
    required OrigemVenda origem,
    String numeroDocumento = '',
    String notas = '',
    required List<VendaItemInput> linhas,
  }) async {
    final total = linhas.fold<double>(0, (s, l) => s + l.totalLinha);
    final rec = await _vendas.create(
      body: {
        'empresa': _empresaId,
        'data': ymd(data),
        'origem': origem.api,
        'total': total,
        'numero_documento': numeroDocumento.trim(),
        'notas': notas.trim(),
      },
    );
    for (final l in linhas) {
      await _itens.create(
        body: {
          'empresa': _empresaId,
          'venda': rec.id,
          if (l.fichaId != null) 'ficha': l.fichaId,
          'descricao': l.descricao.trim(),
          'quantidade': l.quantidade,
          'preco_unitario': l.precoUnitario,
          'total_linha': l.totalLinha,
          'custo_unitario_snapshot': l.custoUnitarioSnapshot,
        },
      );
    }
    return Venda.fromRecord(rec);
  }

  Future<void> remover(String id) => _vendas.delete(id);
}
