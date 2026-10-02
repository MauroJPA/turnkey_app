import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ingredients/data/ingredient_repository.dart';
import '../../invoices/data/invoice_repository.dart';
import '../../mise_en_place/data/mep_repository.dart';
import '../../sales/data/sales_repository.dart';
import '../../schedule/data/schedule_repository.dart';
import '../../settings/application/empresa_providers.dart';
import '../../tech_sheets/data/tech_sheet_item_repository.dart';
import '../../tech_sheets/data/tech_sheet_repository.dart';
import '../data/custos_fixos_repository.dart';
import '../data/equipamentos_repository.dart';
import '../domain/relatorio_exportar.dart';
import '../domain/relatorio_geral.dart';

final relatorioGeralServiceProvider = Provider<RelatorioGeralService>(
  RelatorioGeralService.new,
);

/// Formato do ficheiro do Relatório geral.
enum FormatoRelatorio {
  xlsx('Excel (.xlsx)', 'xlsx'),
  csvZip('CSV (.zip, um ficheiro por relatório)', 'zip');

  const FormatoRelatorio(this.label, this.extensao);
  final String label;
  final String extensao;
}

/// Junta os dados da app e gera o Relatório geral do Financeiro (ver
/// `especificacao-relatorios.md`): vendas, produção, custo por sabor,
/// despesas, tesouraria… Tudo é lido com as permissões da pessoa.
class RelatorioGeralService {
  RelatorioGeralService(this._ref);
  final Ref _ref;

  Future<EntradaRelatorio> carregar({
    required DateTime desde,
    required DateTime ate,
    double? ivaAssumidoPercent,
  }) async {
    final sales = _ref.read(salesRepositoryProvider);
    final vendasRes = await sales.periodo(desde: desde, ate: ate);

    final fichas = await _ref.read(techSheetRepositoryProvider).list();
    final ingredientes = await _ref.read(ingredientRepositoryProvider).list();

    // composição e ingredientes crus por sabor (um pedido por ficha)
    final itemRepo = _ref.read(techSheetItemRepositoryProvider);
    final mep = _ref.read(mepRepositoryProvider);
    final componentes = <ComponenteSabor>[];
    final crus = <IngredienteDoSabor>[];
    for (final f in fichas) {
      try {
        final itens = await itemRepo.listForFicha(f.id);
        for (final i in itens) {
          final tipo = i.isKit
              ? 'kit'
              : i.embalagemId != null
              ? 'embalagem'
              : i.receitaId != null
              ? 'receita'
              : 'ingrediente';
          componentes.add(
            ComponenteSabor(
              fichaId: f.id,
              componente: i.slot.label,
              item: i.nome,
              tipo: tipo,
              quantidade: i.quantidadeG,
              unidade: i.isEmbalagem ? 'peças' : 'g',
              custoUnitario: i.custoPorGramaResolvido,
              custoLinha: i.custoLinha,
              eEmbalagem: i.isEmbalagem,
            ),
          );
        }
      } on Object {
        // uma ficha com problemas não impede o resto do relatório
      }
      try {
        final plano = await mep.planoFicha(f.id, 1);
        for (final c in plano.comprar) {
          crus.add(
            IngredienteDoSabor(
              fichaId: f.id,
              ingredienteId: c.ingredienteId,
              nome: c.nome,
              quantidade: c.gramas,
              unidade: c.unidade,
            ),
          );
        }
      } on Object {
        // idem
      }
    }

    final schedule = _ref.read(scheduleRepositoryProvider);
    final planos = await schedule.listPlans();
    final itensProd = await schedule.listTodosItens();

    return EntradaRelatorio(
      empresa: _ref.read(currentEmpresaProvider).valueOrNull?.nome ?? '',
      desde: desde,
      ate: ate,
      geradoEm: DateTime.now(),
      ivaAssumidoPercent: ivaAssumidoPercent,
      vendas: vendasRes.vendas,
      itens: vendasRes.itens,
      fichas: fichas,
      componentes: componentes,
      ingredientesDosSabores: crus,
      ingredientes: ingredientes,
      custosFixos: await _ref.read(custosFixosRepositoryProvider).list(),
      equipamentos: await _ref.read(equipamentosRepositoryProvider).list(),
      faturas: await _ref.read(invoiceRepositoryProvider).list(),
      producoes: planos,
      itensProducao: [
        for (final i in itensProd)
          ItemProducaoRelatorio(producaoId: i.producaoId, item: i.item),
      ],
    );
  }

  /// Gera o ficheiro: devolve os bytes e o nome sugerido.
  Future<({List<int> bytes, String nome})> gerar({
    required DateTime desde,
    required DateTime ate,
    required FormatoRelatorio formato,
    double? ivaAssumidoPercent,
  }) async {
    final entrada = await carregar(
      desde: desde,
      ate: ate,
      ivaAssumidoPercent: ivaAssumidoPercent,
    );
    final folhas = montarRelatorio(entrada);
    final bytes = switch (formato) {
      FormatoRelatorio.xlsx => relatorioXlsx(folhas),
      FormatoRelatorio.csvZip => relatorioCsvZip(folhas),
    };
    String d(DateTime x) =>
        '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
    return (
      bytes: bytes,
      nome: 'relatorio-geral-${d(desde)}_${d(ate)}.${formato.extensao}',
    );
  }
}
