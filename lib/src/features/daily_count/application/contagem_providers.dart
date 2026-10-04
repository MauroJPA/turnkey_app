import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_user.dart';
import '../../sales/data/sales_repository.dart';
import '../../tech_sheets/application/tech_sheets_providers.dart';
import '../data/contagem_repository.dart';
import '../domain/contagem_dia.dart';
import '../domain/local.dart';
import '../domain/movimento_produto.dart';

/// Os locais ativos. Se a empresa ainda não tem nenhum (empresa nova), cria
/// Loja / Alvalade / Plataformas — desde que a pessoa possa editar.
final locaisProvider = FutureProvider.autoDispose<List<Local>>((ref) async {
  final repo = ref.watch(contagemRepositoryProvider);
  var locais = await repo.listLocais();
  if (locais.isEmpty && ref.read(currentPapelProvider).canEditBusiness) {
    final todos = await repo.listLocais(incluirArquivados: true);
    if (todos.isEmpty) {
      await repo.criarLocaisPadrao();
      locais = await repo.listLocais();
    }
  }
  return locais;
});

/// Todos os locais, também os arquivados (para a gestão de locais).
final todosLocaisProvider = FutureProvider.autoDispose<List<Local>>(
  (ref) =>
      ref.watch(contagemRepositoryProvider).listLocais(incluirArquivados: true),
);

typedef IntervaloDias = ({DateTime desde, DateTime ate});

/// Registos de todos os locais entre duas datas.
final movimentosProvider = FutureProvider.autoDispose
    .family<List<MovimentoProduto>, IntervaloDias>(
      (ref, i) => ref
          .watch(contagemRepositoryProvider)
          .movimentos(desde: i.desde, ate: i.ate),
    );

/// Vendas do período, repartidas pelos locais (pelo canal).
final vendasPorLocalProvider = FutureProvider.autoDispose
    .family<List<VendaDoLocal>, IntervaloDias>((ref, i) async {
      final locais = await ref.watch(locaisProvider.future);
      final res = await ref
          .watch(salesRepositoryProvider)
          .periodo(desde: i.desde, ate: i.ate);
      return vendasPorLocal(
        vendas: res.vendas,
        itens: res.itens,
        locais: locais,
      );
    });

/// A contagem de um dia: uma linha por sabor + os registos desse dia.
class ContagemDoDia {
  const ContagemDoDia({required this.linhas, required this.registos});
  final List<LinhaContagem> linhas;

  /// Registos do dia deste local (assados, envios e receções, desperdício,
  /// contagens), do mais recente para o mais antigo.
  final List<MovimentoProduto> registos;
}

/// Quantos dias para trás se procura o último fecho (a abertura herda-o).
const diasDeHistoricoContagem = 60;

final contagemDoDiaProvider = FutureProvider.autoDispose
    .family<ContagemDoDia, ({String localId, DateTime dia})>((ref, k) async {
      final dia = DateTime(k.dia.year, k.dia.month, k.dia.day);
      final movs = await ref.watch(
        movimentosProvider((
          desde: dia.subtract(const Duration(days: diasDeHistoricoContagem)),
          ate: dia,
        )).future,
      );
      final vendas = await ref.watch(
        vendasPorLocalProvider((desde: dia, ate: dia)).future,
      );
      final fichas = await ref.watch(fichasListProvider(false).future);
      final linhas = calcularContagemDia(
        localId: k.localId,
        dia: dia,
        fichaIds: [for (final f in fichas) f.id],
        movimentos: movs,
        vendas: vendas,
      );
      final registos = [
        for (final m in movs)
          if (DateTime(m.data.year, m.data.month, m.data.day) == dia &&
              (m.localId == k.localId || m.destinoId == k.localId))
            m,
      ].reversed.toList();
      return ContagemDoDia(linhas: linhas, registos: registos);
    });

final contagemActionsProvider = Provider<ContagemActions>(ContagemActions.new);

class ContagemActions {
  ContagemActions(this._ref);
  final Ref _ref;

  ContagemRepository get _repo => _ref.read(contagemRepositoryProvider);

  void _refresh() {
    _ref.invalidate(contagemDoDiaProvider);
    _ref.invalidate(movimentosProvider);
  }

  void _refreshLocais() {
    _ref.invalidate(locaisProvider);
    _ref.invalidate(todosLocaisProvider);
    _ref.invalidate(contagemDoDiaProvider);
    _ref.invalidate(vendasPorLocalProvider);
  }

  Future<void> adicionar({
    required DateTime data,
    required String localId,
    required String fichaId,
    required TipoMovimento tipo,
    required double quantidade,
    String? destinoId,
    MotivoDesperdicio? motivo,
    String notas = '',
  }) async {
    await _repo.adicionar(
      data: data,
      localId: localId,
      fichaId: fichaId,
      tipo: tipo,
      quantidade: quantidade,
      destinoId: destinoId,
      motivo: motivo,
      notas: notas,
    );
    _refresh();
  }

  Future<void> remover(String id) async {
    await _repo.remover(id);
    _refresh();
  }

  /// Grava várias contagens de uma vez (contagem rápida de abertura/fecho).
  Future<void> guardarContagens({
    required TipoMovimento tipo,
    required DateTime data,
    required String localId,
    required Map<String, double> porFicha,
  }) async {
    for (final e in porFicha.entries) {
      await _repo.guardarContagem(
        tipo: tipo,
        data: data,
        localId: localId,
        fichaId: e.key,
        quantidade: e.value,
      );
    }
    _refresh();
  }

  Future<void> criarLocal(LocalInput input) async {
    await _repo.criarLocal(input);
    _refreshLocais();
  }

  Future<void> atualizarLocal(String id, LocalInput input) async {
    await _repo.atualizarLocal(id, input);
    _refreshLocais();
  }

  Future<void> arquivarLocal(String id, {required bool arquivado}) async {
    await _repo.arquivarLocal(id, arquivado: arquivado);
    _refreshLocais();
  }
}
