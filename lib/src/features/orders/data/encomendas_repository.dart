import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../domain/encomenda.dart';

final encomendasRepositoryProvider = Provider<EncomendasRepository>((ref) {
  return EncomendasRepository(ref.watch(pbProvider), requireEmpresaId(ref));
});

class EncomendasRepository {
  EncomendasRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  RecordService get _e => _pb.collection('encomendas');
  RecordService get _itens => _pb.collection('encomendas_itens');

  /// Sem [incluirConcluidas], só mostra as que ainda precisam de atenção
  /// (nova/em produção/pronta) — entregues e canceladas ficam de fora.
  Future<List<Encomenda>> list({bool incluirConcluidas = false}) async {
    final filtros = ['empresa = "$_empresaId"'];
    if (!incluirConcluidas) {
      filtros.add("estado != 'entregue' && estado != 'cancelada'");
    }
    final recs = await _e.getFullList(
      filter: filtros.join(' && '),
      sort: 'data_hora',
    );
    return recs.map(Encomenda.fromRecord).toList();
  }

  Future<Encomenda> getById(String id) async =>
      Encomenda.fromRecord(await _e.getOne(id));

  Future<List<EncomendaItem>> itensDe(String encomendaId) async {
    final recs = await _itens.getFullList(
      filter: 'encomenda = "$encomendaId"',
    );
    return recs.map(EncomendaItem.fromRecord).toList();
  }

  Future<void> _criarItens(String encomendaId, List<EncomendaItemInput> itens) async {
    for (final item in itens) {
      await _itens.create(body: {
        'empresa': _empresaId,
        'encomenda': encomendaId,
        'ficha': item.fichaId,
        'quantidade': item.quantidade,
        'notas': item.notas.trim(),
      });
    }
  }

  Future<Encomenda> criar(EncomendaInput input) async {
    final body = {
      ...input.toBody(),
      'empresa': _empresaId,
      'estado': EstadoEncomenda.nova.api,
      if (_pb.authStore.record != null) 'criado_por': _pb.authStore.record!.id,
    };
    final rec = await _e.create(body: body);
    await _criarItens(rec.id, input.itens);
    return Encomenda.fromRecord(rec);
  }

  Future<void> atualizarEstado(String id, EstadoEncomenda estado) =>
      _e.update(id, body: {'estado': estado.api});

  /// Atualiza os campos da encomenda e volta a criar as linhas a partir de
  /// [input.itens] (apaga as antigas primeiro) — mais simples e seguro do
  /// que tentar casar linhas existentes com as novas uma a uma.
  Future<Encomenda> atualizar(String id, EncomendaInput input) async {
    final rec = await _e.update(id, body: input.toBody());

    final antigas = await _itens.getFullList(filter: 'encomenda = "$id"');
    for (final a in antigas) {
      await _itens.delete(a.id);
    }
    await _criarItens(id, input.itens);
    return Encomenda.fromRecord(rec);
  }

  Future<void> remover(String id) => _e.delete(id);
}
