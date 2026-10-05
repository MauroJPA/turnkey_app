import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pocketbase/pb_client.dart';
import '../../pricing/data/cost_config_repository.dart';
import '../../sales/domain/venda.dart';
import '../data/custos_fixos_repository.dart';
import '../domain/ia_financeira.dart';
import '../domain/resumo_financeiro.dart';

final iaFinanceiraServiceProvider = Provider<IaFinanceiraService>(
  IaFinanceiraService.new,
);

/// Chamadas à IA do Financeiro (via servidor — a chave nunca está na app).
/// Só sugerem: nada é gravado sem a pessoa confirmar.
class IaFinanceiraService {
  IaFinanceiraService(this._ref);
  final Ref _ref;

  /// Sugere, para cada custo ativo, se é fixo ou variável (e o que fazer).
  Future<List<SugestaoCusto>> classificarCustos() async {
    final res = await _ref
        .read(pbProvider)
        .send(
          '/api/gc_turnkey/financeiro/classificar-custos',
          method: 'POST',
          body: <String, dynamic>{},
        );
    return sugestoesDeJson(res);
  }

  Map<String, Object> _bloco(ResumoFinanceiro r) => {
    'receita': r.receita,
    'custoProdutos': r.custoProdutos,
    'custosFixos': r.custosFixos,
    'custosVariaveis': r.custosVariaveis,
    'depreciacao': r.depreciacaoMensal,
    'lucroLiquido': r.lucroLiquido,
    'margemLiquidaPercent': r.margemLiquidaPercent,
    'numVendas': r.numVendas,
    'linhasSemProduto': r.numLinhasSemFicha,
  };

  /// Dicas para melhorar, a partir dos números do painel (período atual vs.
  /// anterior, custos mensais e percentuais de imposto/CMV).
  Future<DicasFinanceiras> gerarDicas(ComparacaoFinanceira comp) async {
    final custos = await _ref.read(custosFixosRepositoryProvider).list();
    final config = await _ref.read(costConfigProvider.future);
    final p = comp.atual.periodo;
    final res = await _ref
        .read(pbProvider)
        .send(
          '/api/gc_turnkey/financeiro/dicas',
          method: 'POST',
          body: {
            'periodo': {
              'label': p.label,
              'desde': ymd(p.desde),
              'ate': ymd(p.ate),
            },
            'atual': _bloco(comp.atual),
            'anterior': _bloco(comp.anterior),
            'custos': [
              for (final c in custos)
                {
                  'nome': c.nome,
                  'tipo': c.tipo.api,
                  'valorMensal': c.valorMensal,
                },
            ],
            'percentuais': {'iva': config.ivaVendas, 'cmv': config.cmvPercent},
          },
        );
    return DicasFinanceiras.fromJson(res);
  }
}
