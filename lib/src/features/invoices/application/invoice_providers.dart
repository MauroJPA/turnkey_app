import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ingredients/application/ingredients_providers.dart';
import '../data/invoice_repository.dart';
import '../domain/fatura.dart';

final faturasListProvider = FutureProvider.autoDispose<List<Fatura>>((ref) {
  return ref.watch(invoiceRepositoryProvider).list();
});

final faturaProvider = FutureProvider.autoDispose.family<Fatura, String>((
  ref,
  id,
) {
  return ref.watch(invoiceRepositoryProvider).getById(id);
});

final invoiceActionsProvider = Provider<InvoiceActions>(InvoiceActions.new);

class InvoiceActions {
  InvoiceActions(this._ref);
  final Ref _ref;

  InvoiceRepository get _repo => _ref.read(invoiceRepositoryProvider);

  Future<({Fatura fatura, int total, int duplicadas})> criarEAnalisar({
    required FaturaTipo tipo,
    required String fornecedor,
    required List<int> bytes,
    required String nome,
  }) async {
    final f = await _repo.criar(
      tipo: tipo,
      fornecedor: fornecedor,
      bytes: bytes,
      nome: nome,
    );
    _ref.invalidate(faturasListProvider);

    // A análise pode falhar (503/502) ou marcar a fatura como duplicada (409) —
    // nesse caso o estado 'erro' já ficou gravado; devolvemos a fatura para o
    // ecrã de revisão mostrar o motivo, em vez de rebentar.
    var result = f;
    AnaliseFaturas? analise;
    try {
      analise = await _repo.analisar(f.id, bytes: bytes, nome: nome);
      result = analise.fatura;
    } on Object {
      result = await _repo.getById(f.id);
    }
    final total = analise?.ids.length ?? 1;

    // Renomear o ficheiro para FT-FORNECEDOR-DDMMAAAA com a data lida. Só numa
    // fatura única: se o ficheiro trazia várias, cada uma já tem o seu (cortado).
    if (total == 1 &&
        result.estado != FaturaEstado.erro &&
        result.dataFatura.isNotEmpty) {
      final data = DateTime.tryParse(result.dataFatura);
      if (data != null) {
        try {
          result = await _repo.renomearFicheiro(
            f.id,
            bytes: bytes,
            nomeOriginal: nome,
            fornecedor: result.fornecedor.isNotEmpty
                ? result.fornecedor
                : fornecedor,
            dataFatura: data,
          );
        } on Object {
          // fica com o nome provisório
        }
      }
    }

    _ref.invalidate(faturasListProvider);
    _ref.invalidate(faturaProvider(f.id));
    return (fatura: result, total: total, duplicadas: analise?.duplicadas ?? 0);
  }

  Future<AnaliseFaturas> reanalisar(
    String id, {
    required List<int> bytes,
    required String nome,
  }) async {
    final r = await _repo.analisar(id, bytes: bytes, nome: nome);
    _ref.invalidate(faturaProvider(id));
    _ref.invalidate(faturasListProvider);
    return r;
  }

  /// "Tentar de novo": descarrega o ficheiro já guardado e volta a analisá-lo.
  Future<AnaliseFaturas> tentarDeNovo(Fatura f) async {
    final bytes = await _repo.descarregarFicheiro(f);
    return reanalisar(f.id, bytes: bytes, nome: f.ficheiro);
  }

  Future<({int precos, int precosIgnorados, int movimentos})> aplicar(
    String id,
    List<LinhaAAplicar> linhas,
  ) async {
    final r = await _repo.aplicar(id, linhas);
    _ref.invalidate(faturaProvider(id));
    _ref.invalidate(faturasListProvider);
    _ref.invalidate(ingredientsListProvider);
    return r;
  }

  Future<void> apagar(String id) async {
    await _repo.apagar(id);
    _ref.invalidate(faturasListProvider);
  }

  Future<int> limparInvalidas() async {
    final n = await _repo.limparInvalidas();
    _ref.invalidate(faturasListProvider);
    return n;
  }
}
