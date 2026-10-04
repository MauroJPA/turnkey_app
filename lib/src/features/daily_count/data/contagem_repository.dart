import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/formatting/pb_data_hora.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../../sales/domain/venda.dart' show ymd;
import '../domain/fornada.dart';
import '../domain/local.dart';
import '../domain/movimento_produto.dart';

final contagemRepositoryProvider = Provider<ContagemRepository>((ref) {
  return ContagemRepository(ref.watch(pbProvider), requireEmpresaId(ref));
});

/// Locais e registos do dia a dia dos cookies (`locais`, `movimentos_produto`).
class ContagemRepository {
  ContagemRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  RecordService get _locais => _pb.collection('locais');
  RecordService get _mov => _pb.collection('movimentos_produto');

  // --- locais ---------------------------------------------------------------

  Future<List<Local>> listLocais({bool incluirArquivados = false}) async {
    final filtros = ['empresa = "$_empresaId"'];
    if (!incluirArquivados) filtros.add('arquivado != true');
    final recs = await _locais.getFullList(
      filter: filtros.join(' && '),
      sort: 'ordem,nome',
    );
    return recs.map(Local.fromRecord).toList();
  }

  Future<Local> criarLocal(LocalInput input) async => Local.fromRecord(
    await _locais.create(
      body: {...input.toBody(), 'empresa': _empresaId, 'arquivado': false},
    ),
  );

  Future<Local> atualizarLocal(String id, LocalInput input) async =>
      Local.fromRecord(await _locais.update(id, body: input.toBody()));

  Future<void> arquivarLocal(String id, {required bool arquivado}) =>
      _locais.update(id, body: {'arquivado': arquivado});

  /// Cria Loja / Alvalade / Plataformas numa empresa que ainda não tem locais
  /// (as empresas que já existiam recebem-nos na migration).
  Future<void> criarLocaisPadrao() async {
    const padrao = [
      ('Loja', TipoLocal.loja, ['Loja física']),
      ('Alvalade', TipoLocal.parceiro, ['Parceria Alvalade']),
      (
        'Plataformas',
        TipoLocal.plataforma,
        ['Uber Eats', 'Glovo', 'Bolt Food'],
      ),
    ];
    var ordem = 1;
    for (final (nome, tipo, canais) in padrao) {
      await criarLocal(
        LocalInput(nome: nome, tipo: tipo, canais: canais, ordem: ordem++),
      );
    }
  }

  // --- registos ----------------------------------------------------------------

  String _filtroDatas(DateTime desde, DateTime ate) =>
      'data >= "${ymd(desde)} 00:00:00.000Z" && '
      'data <= "${ymd(ate)} 23:59:59.999Z"';

  /// Todos os registos (de todos os locais) entre [desde] e [ate], inclusive.
  Future<List<MovimentoProduto>> movimentos({
    required DateTime desde,
    required DateTime ate,
  }) async {
    final recs = await _mov.getFullList(
      filter: 'empresa = "$_empresaId" && ${_filtroDatas(desde, ate)}',
      sort: 'data,created',
    );
    return recs.map(MovimentoProduto.fromRecord).toList();
  }

  /// Devolve o id do registo criado.
  Future<String> adicionar({
    required DateTime data,
    required String localId,
    required String fichaId,
    required TipoMovimento tipo,
    required double quantidade,
    String? destinoId,
    MotivoDesperdicio? motivo,
    String notas = '',
  }) async {
    final rec = await _mov.create(
      body: {
        'empresa': _empresaId,
        'data': ymd(data),
        'local': localId,
        'ficha': fichaId,
        'tipo': tipo.api,
        'quantidade': quantidade,
        if (destinoId != null && destinoId.isNotEmpty) 'destino': destinoId,
        if (motivo != null) 'motivo': motivo.api,
        'notas': notas.trim(),
        if (_pb.authStore.record != null) 'autor': _pb.authStore.record!.id,
      },
    );
    return rec.id;
  }

  Future<void> remover(String id) => _mov.delete(id);

  /// Grava uma contagem (abertura ou fecho): substitui a que já existir para
  /// o mesmo local, sabor e dia.
  Future<void> guardarContagem({
    required TipoMovimento tipo,
    required DateTime data,
    required String localId,
    required String fichaId,
    required double quantidade,
  }) async {
    assert(tipo.eContagem);
    final existente = await _mov.getList(
      perPage: 1,
      filter:
          'empresa = "$_empresaId" && local = "$localId" && '
          'ficha = "$fichaId" && tipo = "${tipo.api}" && '
          '${_filtroDatas(data, data)}',
    );
    if (existente.items.isNotEmpty) {
      await _mov.update(
        existente.items.first.id,
        body: {'quantidade': quantidade},
      );
    } else {
      await adicionar(
        data: data,
        localId: localId,
        fichaId: fichaId,
        tipo: tipo,
        quantidade: quantidade,
      );
    }
  }

  // --- forno ---------------------------------------------------------------------

  RecordService get _fornadas => _pb.collection('fornadas');

  /// As fornadas ainda no forno neste local.
  Future<List<Fornada>> fornadasNoForno(String localId) async {
    final recs = await _fornadas.getFullList(
      filter:
          'empresa = "$_empresaId" && local = "$localId" && estado = "no_forno"',
      sort: 'inicio',
    );
    return recs.map(Fornada.fromRecord).toList();
  }

  /// As fornadas ainda no forno, de todos os locais (para o Início).
  Future<List<Fornada>> fornadasNoFornoTodas() async {
    final recs = await _fornadas.getFullList(
      filter: 'empresa = "$_empresaId" && estado = "no_forno"',
      sort: 'inicio',
    );
    return recs.map(Fornada.fromRecord).toList();
  }

  /// Põe cookies no forno: regista os assados de cada sabor (do dia [data]) e
  /// a fornada, com o tempo de forno de cada sabor.
  Future<void> assar({
    required DateTime data,
    required String localId,
    required List<ItemFornada> itens,
  }) async {
    final validos = [
      for (final i in itens)
        if (i.quantidade > 0 && i.duracaoMin > 0) i,
    ];
    final ids = <String>[];
    for (final i in validos) {
      ids.add(
        await adicionar(
          data: data,
          localId: localId,
          fichaId: i.fichaId,
          tipo: TipoMovimento.producao,
          quantidade: i.quantidade,
          notas: 'Fornada',
        ),
      );
    }
    final maior = validos.fold<int>(
      0,
      (m, i) => i.duracaoMin > m ? i.duracaoMin : m,
    );
    await _fornadas.create(
      body: {
        'empresa': _empresaId,
        'local': localId,
        'inicio': pbDataHora(DateTime.now()),
        'duracao_min': maior,
        'itens': [for (final i in validos) i.toJson()],
        'movimentos': ids,
        'estado': EstadoFornada.noForno.api,
        if (_pb.authStore.record != null) 'autor': _pb.authStore.record!.id,
      },
    );
  }

  Future<void> tirarDoForno(String fornadaId) =>
      _fornadas.update(fornadaId, body: {'estado': EstadoFornada.tirada.api});

  /// Um sabor saiu do forno; quando saem todos, a fornada fica concluída.
  Future<void> tirarItem(Fornada f, String fichaId) async {
    final nova = f.comItemTirado(fichaId);
    await _fornadas.update(
      f.id,
      body: {
        'itens': [for (final i in nova.itens) i.toJson()],
        if (nova.todosTirados) 'estado': EstadoFornada.tirada.api,
      },
    );
  }

  /// Cancela a fornada e desfaz os assados que ela registou.
  Future<void> cancelarFornada(Fornada f) async {
    for (final id in f.movimentoIds) {
      try {
        await _mov.delete(id);
      } on ClientException catch (e) {
        if (e.statusCode != 404) rethrow;
      }
    }
    await _fornadas.update(
      f.id,
      body: {'estado': EstadoFornada.cancelada.api},
    );
  }
}
