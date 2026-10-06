import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router.dart';
import '../../../core/data/marcas_fornecedores_providers.dart';
import '../../../core/formatting/busca.dart';
import '../../../core/formatting/dates.dart';
import '../../../core/formatting/money_provider.dart';
import '../../../core/formatting/quantities.dart';
import '../../../core/help/help_content.dart';
import '../../../core/storage/prefs_locais.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/autocomplete_text_field.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/help_actions.dart';
import '../../../core/widgets/history_sheet.dart';
import '../../consumables/application/consumivel_providers.dart';
import '../../consumables/domain/consumivel.dart';
import '../../consumables/presentation/consumiveis_screen.dart'
    show apresentaEstadoFds;
import '../../consumables/presentation/consumivel_sheet.dart';
import '../../cookie_formats/application/cookie_format_providers.dart';
import '../../cookie_formats/domain/cookie_format.dart';
import '../../finance/application/equipamentos_providers.dart';
import '../../ingredients/application/ingredients_providers.dart';
import '../../ingredients/data/ingredient_product_repository.dart';
import '../../ingredients/data/ingredient_repository.dart';
import '../../ingredients/domain/ingredient.dart';
import '../../ingredients/domain/produto_ingrediente.dart';
import '../../inventory/data/variacao_preco_repository.dart';
import '../../packaging/application/embalagem_providers.dart';
import '../../packaging/domain/embalagem.dart';
import '../application/analise_faturas_controller.dart';
import '../application/invoice_providers.dart';
import '../data/invoice_repository.dart';
import '../domain/fatura.dart';
import '../domain/invoice_erros.dart';
import '../domain/match_ingrediente.dart';
import 'fatura_pdf_view.dart';
import 'fatura_zoom_view.dart';
import 'invoice_owner_widgets.dart';

class InvoiceReviewScreen extends ConsumerWidget {
  const InvoiceReviewScreen({super.key, required this.faturaId});
  final String faturaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faturaAsync = ref.watch(faturaProvider(faturaId));
    final ingsAsync = ref.watch(ingredientsListProvider(false));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.invoices),
        ),
        title: const Text('Rever fatura'),
        actions: [
          IconButton(
            tooltip: 'Histórico desta fatura',
            icon: const Icon(Icons.history),
            onPressed: () => showHistorySheet(
              context,
              tipo: 'fatura',
              id: faturaId,
              titulo: faturaAsync.valueOrNull?.fornecedor.isNotEmpty ?? false
                  ? faturaAsync.value!.fornecedor
                  : 'Fatura',
            ),
          ),
          if (ehProprietarioOuAdmin(ref) && faturaAsync.hasValue)
            IconButton(
              tooltip: 'Corrigir fornecedor, data, número…',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                if (await mostrarEditarFatura(
                  context,
                  ref,
                  faturaAsync.requireValue,
                )) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Guardado. Fica no histórico.'),
                    ),
                  );
                }
              },
            ),
          const HelpActions(topic: HelpTopic.faturaRevisao),
        ],
      ),
      body: AsyncValueView<Fatura>(
        value: faturaAsync,
        onRetry: () => ref.invalidate(faturaProvider(faturaId)),
        data: (fatura) {
          if (fatura.estado == FaturaEstado.erro) {
            return _Erro(fatura: fatura);
          }
          if (fatura.linhasIa.isEmpty) {
            return _SemLinhas(fatura: fatura);
          }
          return ingsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(mensagemAmigavel(e))),
            data: (ings) => ref
                .watch(produtosIngredienteProvider)
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _Revisao(
                    fatura: fatura,
                    ingredientes: ings,
                    produtos: const [],
                    consumiveis: const [],
                    embalagens: const [],
                    anteriores: const [],
                  ),
                  data: (prods) => ref
                      .watch(consumiveisListProvider)
                      .when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => _Revisao(
                          fatura: fatura,
                          ingredientes: ings,
                          produtos: prods,
                          consumiveis: const [],
                          embalagens: const [],
                          anteriores: const [],
                        ),
                        data: (cons) => ref
                            .watch(embalagensListProvider)
                            .when(
                              loading: () => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              error: (e, _) => _Revisao(
                                fatura: fatura,
                                ingredientes: ings,
                                produtos: prods,
                                consumiveis: cons,
                                embalagens: const [],
                                anteriores: const [],
                              ),
                              data: (embs) => ref
                                  .watch(itensFaturaProvider(fatura.id))
                                  .when(
                                    loading: () => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                    error: (e, _) => _Revisao(
                                      fatura: fatura,
                                      ingredientes: ings,
                                      produtos: prods,
                                      consumiveis: cons,
                                      embalagens: embs,
                                      anteriores: const [],
                                    ),
                                    data: (anteriores) => _Revisao(
                                      fatura: fatura,
                                      ingredientes: ings,
                                      produtos: prods,
                                      consumiveis: cons,
                                      embalagens: embs,
                                      anteriores: anteriores,
                                    ),
                                  ),
                            ),
                      ),
                ),
          );
        },
      ),
    );
  }
}

class _Erro extends ConsumerStatefulWidget {
  const _Erro({required this.fatura});
  final Fatura fatura;

  @override
  ConsumerState<_Erro> createState() => _ErroState();
}

class _ErroState extends ConsumerState<_Erro> {
  bool _busy = false;

  Future<void> _tentarDeNovo() async {
    setState(() => _busy = true);
    // volta a analisar no servidor (retoma o que já foi lido) e mostra o progresso na lista
    ref
        .read(analiseFaturasProvider.notifier)
        .retomar(widget.fatura.id, titulo: widget.fatura.ficheiro);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'A analisar de novo. Acompanha o progresso na lista de faturas.',
        ),
      ),
    );
    if (mounted && context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final fatura = widget.fatura;
    final duplicada = fatura.duplicadaDe.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            duplicada ? Icons.copy_all_outlined : Icons.error_outline,
            size: 40,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(
            duplicada ? fatura.erroIa : 'A análise falhou: ${fatura.erroIa}',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            duplicada
                ? 'Esta fatura já tinha sido carregada. Podes apagá-la.'
                : 'Se a IA estava sobrecarregada, tenta de novo daqui a uns '
                      'minutos. Se persistir, verifica a configuração da IA no '
                      'servidor (fornecedor e chave) ou usa uma foto mais nítida.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (duplicada)
                OutlinedButton.icon(
                  onPressed: () => context.pushReplacement(
                    '${Routes.invoices}/${fatura.duplicadaDe}',
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Abrir a original'),
                ),
              if (!duplicada)
                FilledButton.icon(
                  onPressed: _busy ? null : _tentarDeNovo,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: const Text('Tentar de novo'),
                ),
              if (ehProprietarioOuAdmin(ref))
                OutlinedButton.icon(
                  onPressed: () async {
                    if (await apagarFaturaComConfirmacao(
                          context,
                          ref,
                          fatura,
                        ) &&
                        context.mounted &&
                        context.canPop()) {
                      context.pop();
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Apagar fatura'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SemLinhas extends ConsumerWidget {
  const _SemLinhas({required this.fatura});
  final Fatura fatura;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 40,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          const Text(
            'A IA não devolveu nenhuma linha desta fatura. Se acabaste de a '
            'criar, aguarda uns segundos e recarrega; se a foto está tremida '
            'ou cortada, pede ao proprietário para a apagar e carrega uma melhor.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (ehProprietarioOuAdmin(ref))
            FilledButton.icon(
              onPressed: () async {
                if (await apagarFaturaComConfirmacao(context, ref, fatura) &&
                    context.mounted &&
                    context.canPop()) {
                  context.pop();
                }
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Apagar fatura'),
            ),
        ],
      ),
    );
  }
}

/// 250 -> "250"; 2,5 -> "2.5" (sem zeros a mais).
String _fmtNum(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}

/// Converte entre g e ml (com a densidade em g/ml). `null` = sem conversão
/// conhecida (por exemplo, unidades para gramas).
double? _converter(double v, String de, String para, {double densidade = 1}) {
  if (de == para) return v;
  final d = densidade > 0 ? densidade : 1;
  if (de == 'g' && para == 'ml') return v / d;
  if (de == 'ml' && para == 'g') return v * d;
  return null;
}

String _normNome(String s) =>
    s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

/// A que ficha se liga uma linha de fatura. Limpeza/insumo, bebida e revenda
/// gravam-se todas em `consumiveis` (só muda a categoria sugerida) — dá para
/// mudar de uma para outra sem perder o que já estava escrito.
enum TipoLinha {
  ingrediente,
  embalagem,
  limpezaInsumo,
  bebida,
  revenda,

  /// Um bem duradouro (forno, batedeira, balcão…): vai para a lista de
  /// equipamentos e entra na depreciação e nos custos da empresa.
  equipamento;

  bool get ehConsumivel =>
      this == limpezaInsumo || this == bebida || this == revenda;

  /// Categoria sugerida ao mudar para este tipo (só para os consumíveis).
  String get categoriaPreset => switch (this) {
    limpezaInsumo => 'Limpeza',
    bebida => 'Bebida',
    revenda => 'Revenda',
    _ => '',
  };

  String get label => switch (this) {
    ingrediente => 'Ingrediente',
    embalagem => 'Embalagem',
    limpezaInsumo => 'Limpeza / insumo',
    bebida => 'Bebida',
    revenda => 'Revenda',
    equipamento => 'Equipamento',
  };

  /// Rótulo do seletor "escolher produto…" para este tipo.
  String get pickerLabel => switch (this) {
    bebida => 'Bebida',
    revenda => 'Produto de revenda',
    _ => 'Produto de limpeza / insumo',
  };
}

/// A qual dos 3 segmentos "consumível" pertence uma categoria já gravada —
/// para saber qual realçar ao reabrir uma linha já ligada a um produto.
/// A IA ainda sugere a categoria em chaves antigas (limpeza/desinfecao/…);
/// converte para o rótulo que a app mostra.
String _rotuloCategoriaIa(String v) {
  const rotulos = {
    'limpeza': 'Limpeza',
    'desinfecao': 'Desinfeção',
    'higiene': 'Higiene',
    'insumo': 'Insumo',
    'outro': 'Outro',
  };
  final chave = v.trim().toLowerCase();
  return rotulos[chave] ?? (v.trim().isEmpty ? 'Limpeza' : v.trim());
}

TipoLinha _tipoConsumivelDe(String categoria) {
  final c = normalizarNome(categoria);
  if (c == 'bebida') return TipoLinha.bebida;
  if (c == 'revenda') return TipoLinha.revenda;
  return TipoLinha.limpezaInsumo;
}

/// Tipo inicial de uma linha: o que já estava decidido numa ronda anterior
/// (se houver) manda; senão, o que a IA sugeriu.
TipoLinha _tipoInicial(
  FaturaLinhaIa ia,
  ItemFaturaAnterior? anterior, {
  bool podeEquipamento = false,
}) {
  if (anterior != null) {
    if (anterior.equipamentoId != null) return TipoLinha.equipamento;
    if (anterior.embalagemId != null) return TipoLinha.embalagem;
    if (anterior.consumivelId != null) {
      return TipoLinha.limpezaInsumo; // a categoria real vem do `cons` ligado
    }
    if (anterior.ingredienteId != null) return TipoLinha.ingrediente;
  }
  if (ia.equipamento && podeEquipamento) return TipoLinha.equipamento;
  if (ia.embalagem) return TipoLinha.embalagem;
  if (ia.consumivel) return TipoLinha.limpezaInsumo;
  return TipoLinha.ingrediente;
}

/// Ação inicial de uma linha: a de uma ronda anterior (se houver — inclui
/// "pendente" e "ignorar", decisões que se mantêm), senão o que dá para
/// decidir já a partir do emparelhamento automático. Sem nada para ligar,
/// fica "por rever depois" em vez de silenciosamente ignorada.
AcaoFatura _acaoInicial({
  required FaturaLinhaIa ia,
  required ItemFaturaAnterior? anterior,
  required MatchLinha? match,
  required Consumivel? consMatch,
  required Embalagem? embMatch,
  required bool isLista,
  bool podeEquipamento = false,
}) {
  if (anterior != null) return anterior.acao;
  // equipamento lido pela IA: já vem para registar (a pessoa confirma o
  // custo e a vida útil antes de aplicar)
  if (ia.equipamento && podeEquipamento && !isLista) return AcaoFatura.preco;
  if (ia.embalagem) {
    return embMatch != null ? AcaoFatura.preco : AcaoFatura.pendente;
  }
  if (match == null && consMatch == null) return AcaoFatura.pendente;
  return isLista ? AcaoFatura.preco : AcaoFatura.ambos;
}

class _LinhaState {
  _LinhaState(
    this.ia,
    this.index, {
    MatchLinha? match,
    Consumivel? consMatch,
    Embalagem? embMatch,
    required bool isLista,
    this.anterior,
    bool podeEquipamento = false,
  }) : aplicadaAnterior = anterior?.aplicado ?? false,
       tipo =
           consMatch != null &&
               _tipoInicial(
                 ia,
                 anterior,
                 podeEquipamento: podeEquipamento,
               ).ehConsumivel
           ? _tipoConsumivelDe(consMatch.categoria)
           : _tipoInicial(ia, anterior, podeEquipamento: podeEquipamento),
       cons = consMatch,
       embalagemSel = embMatch,
       categoria = TextEditingController(
         text: consMatch != null
             ? consMatch.categoria
             : _rotuloCategoriaIa(ia.categoriaConsumivel),
       ),
       tipoEmbalagemSel = TextEditingController(
         text: ia.tipoEmbalagem.trim().isNotEmpty
             ? ia.tipoEmbalagem.trim()
             : 'Caixa',
       ),
       pecas = TextEditingController(
         text: (ia.quantidade ?? 0) > 0 && ia.embalagem
             ? _fmtNum(ia.quantidade!)
             : '',
       ),
       ingrediente = match?.ingrediente,
       produto = match?.produto,
       marca = TextEditingController(
         text: ia.marca.isNotEmpty ? ia.marca : (match?.produto?.marca ?? ''),
       ),
       // "2 un" de 15 g: mostra 2 unidades (=30 g); "200 g": mostra 200 g; "1 L": 1000 ml
       unidadeQtd = ia.contaEmbalagens
           ? 'un'
           : (ia.unidadeEVolume ? 'ml' : 'g'),
       qtd = TextEditingController(
         text: ia.contaEmbalagens
             ? ((ia.quantidade ?? 0) > 0 ? _fmtNum(ia.quantidade!) : '')
             : (ia.quantidadeG > 0 ? ia.quantidadeG.toStringAsFixed(0) : ''),
       ),
       // a embalagem lida vem na unidade da IA; a do ingrediente/produto ligado, na dele
       unidadeEmb = (ia.embalagemG ?? 0) > 0
           ? ia.embalagemUnidade
           : (match?.ingrediente.un ?? 'g'),
       unidadeIng = (ia.embalagemG ?? 0) > 0
           ? ia.embalagemUnidade
           : (ia.contaEmbalagens ? 'g' : (ia.unidadeEVolume ? 'ml' : 'g')),
       caracteristica = TextEditingController(text: ia.caracteristica),
       preco = TextEditingController(
         text: (ia.precoUnitario ?? 0) > 0
             ? ia.precoUnitario!.toStringAsFixed(2)
             : '',
       ),
       emb = TextEditingController(
         text: (ia.embalagemG ?? 0) > 0
             ? ia.embalagemG!.toStringAsFixed(0)
             : (match?.produto != null && match!.produto!.embalagemG > 0
                   ? match.produto!.embalagemG.toStringAsFixed(0)
                   : (match != null && match.ingrediente.gramasEmbalagem > 0
                         ? match.ingrediente.gramasEmbalagem.toStringAsFixed(0)
                         : '')),
       ),
       nome = TextEditingController(text: ia.descricao),
       // equipamento: o total pago (se a fatura o diz) e 5 anos de vida útil
       custoEquip = TextEditingController(
         text: (ia.total ?? 0) > 0
             ? ia.total!.toStringAsFixed(2)
             : ((ia.precoUnitario ?? 0) > 0
                   ? ((ia.precoUnitario!) *
                             ((ia.quantidade ?? 1) > 0
                                 ? (ia.quantidade ?? 1)
                                 : 1))
                         .toStringAsFixed(2)
                   : ''),
       ),
       vidaUtil = TextEditingController(text: '5'),
       acao = _acaoInicial(
         ia: ia,
         anterior: anterior,
         match: match,
         consMatch: consMatch,
         embMatch: embMatch,
         isLista: isLista,
         podeEquipamento: podeEquipamento,
       );

  final FaturaLinhaIa ia;

  /// Posição desta linha em `fatura.linhasIa` — identifica-a no servidor,
  /// mesmo quando só se aplicam algumas linhas de cada vez.
  final int index;

  /// Já foi aplicada numa ronda anterior (preço/stock já atualizados) — fica
  /// só para consulta, sem precisar de ser revista outra vez.
  final bool aplicadaAnterior;

  /// O registo gravado (índice, marca/fornecedor, a que ficou ligada…) numa
  /// ronda anterior — para mostrar e, sendo proprietário/administrador, dar
  /// para corrigir marca/fornecedor mesmo com a linha já aplicada. Atualizado
  /// localmente depois de corrigir (sem recriar a linha toda).
  ItemFaturaAnterior? anterior;

  /// Removida da revisão pela pessoa (duplicada, lida a mais pela IA…) — fica
  /// fora da lista e é enviada como "Ignorar" ao aplicar (nunca mexe em
  /// preço/stock), sem precisar de continuar visível.
  bool removida = false;

  /// A que se liga esta linha: um ingrediente, um consumível (limpeza/insumo)
  /// ou uma embalagem (caixa, saco, adesivo…).
  TipoLinha tipo;

  /// Produto de limpeza/insumo/bebida/revenda ligado (null se vai criar um novo).
  Consumivel? cons;

  /// Categoria do consumível a criar/atualizar — texto livre (sugestões em
  /// `kCategoriasConsumivelPadrao`), preenchida com o preset do [tipo]
  /// escolhido mas editável.
  final TextEditingController categoria;

  /// Embalagem ligada (null se vai criar uma nova).
  Embalagem? embalagemSel;

  /// Tipo da embalagem nova a criar — texto livre (sugestões em
  /// `kTiposEmbalagem`).
  final TextEditingController tipoEmbalagemSel;

  /// Peças compradas nesta linha (só embalagens) — ex.: "500" num rolo de
  /// 500 adesivos. Fica em `embalagens.unidades_compra` ao aplicar.
  final TextEditingController pecas;

  /// Para que serve a embalagem nova (opcional).
  UsoEmbalagem? usoEmbalagemSel;

  /// Formatos de cookie a que se destina a embalagem nova (opcional; vazio =
  /// qualquer formato).
  final Set<String> formatosCookieSel = {};

  /// Quantas peças formam o múltiplo (só relevante quando
  /// `usoEmbalagemSel == UsoEmbalagem.multiplo`, ex.: caixa de 6 → 6).
  int quantidadeMultiplo = 2;

  /// Ingrediente genérico ligado a esta linha (null se vai criar um novo).
  Ingrediente? ingrediente;

  /// Produto de compra já conhecido (null = vai criar um produto novo com esta marca).
  ProdutoIngrediente? produto;

  /// Marca do produto (lida pela IA; editável).
  final TextEditingController marca;

  /// Criar um registo novo (ingrediente, consumível ou embalagem, consoante
  /// [tipo]) com o nome do campo [nome].
  bool criarNovo = false;

  /// Renomear o [ingrediente] ligado para [nome] — propaga a todas as receitas
  /// e fichas (que referenciam o ingrediente por id).
  bool renomear = false;

  /// Unidade da quantidade comprada: `g`, `ml` ou `un` (embalagens, cada uma
  /// com o tamanho do campo [emb]).
  String unidadeQtd;

  /// Unidade em que está escrito o campo [emb] (`g`, `ml` ou `un`).
  String unidadeEmb;

  /// Unidade do ingrediente NOVO a criar (`g`, `ml` ou `un`).
  String unidadeIng;

  /// Característica do registo novo (ingrediente: T55, T65, integral…;
  /// embalagem: kraft com janela, transparente…).
  final TextEditingController caracteristica;

  final TextEditingController qtd;
  final TextEditingController preco;
  final TextEditingController emb;

  /// Nome para o registo novo / para o renomear.
  final TextEditingController nome;

  /// Equipamento: custo total pago (€) e vida útil em anos — a depreciação
  /// mensal é custo ÷ (anos × 12).
  final TextEditingController custoEquip;
  final TextEditingController vidaUtil;

  double get custoEquipV => _n(custoEquip);
  double get vidaUtilV => _n(vidaUtil);

  /// Depreciação por mês (para mostrar à pessoa); 0 se faltar custo ou vida.
  double get depreciacaoMensal =>
      custoEquipV > 0 && vidaUtilV > 0 ? custoEquipV / (vidaUtilV * 12) : 0;

  AcaoFatura acao;

  double _n(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.').trim()) ?? 0;

  /// Unidade do ingrediente desta linha: a do ingrediente ligado, ou a escolhida
  /// para o novo; sem ingrediente, a da embalagem. Só faz sentido para [tipo]
  /// ingrediente.
  String get ingUn => criarNovo
      ? unidadeIng
      : (ingrediente?.un ?? (unidadeEmb == 'un' ? 'un' : unidadeEmb));

  double get _densidade => ingrediente?.nutriDensidade ?? 1;

  /// Embalagem convertida para a unidade do ingrediente (`null` se não dá).
  double? get embNaUnidade =>
      embV > 0 ? _converter(embV, unidadeEmb, ingUn, densidade: _densidade) : 0;

  /// Quantidade realmente comprada, na unidade do ingrediente (o que dá entrada
  /// no stock): unidades = nº de embalagens x tamanho da embalagem.
  double get gramasComprados {
    if (unidadeQtd == 'un') {
      final e = embNaUnidade;
      return (e == null || e <= 0) ? 0 : _n(qtd) * e;
    }
    return _converter(_n(qtd), unidadeQtd, ingUn, densidade: _densidade) ?? 0;
  }

  /// Aviso se as unidades não se entendem (ex.: embalagem em un, ingrediente em g).
  /// Só se aplica a linhas de ingrediente (as outras não pesam nem têm stock).
  String? get problemaUnidade {
    if (tipo != TipoLinha.ingrediente) return null;
    if (embV > 0 && embNaUnidade == null) {
      return 'A embalagem está em $unidadeEmb e o ingrediente em $ingUn: '
          'não dá para converter. Muda uma das unidades.';
    }
    if (unidadeQtd != 'un' &&
        _n(qtd) > 0 &&
        _converter(_n(qtd), unidadeQtd, ingUn, densidade: _densidade) == null) {
      return 'O comprado está em $unidadeQtd e o ingrediente em $ingUn.';
    }
    return null;
  }

  double get precoV => _n(preco);
  double get embV => _n(emb);

  /// A descrição da fatura difere do nome do ingrediente ligado?
  bool get nomeDiferente =>
      ingrediente != null &&
      _normNome(ingrediente!.nome) != _normNome(ia.descricao);

  bool get temAlvo =>
      criarNovo ||
      (tipo.ehConsumivel
          ? cons != null
          : switch (tipo) {
              TipoLinha.embalagem => embalagemSel != null,
              TipoLinha.ingrediente => ingrediente != null,
              // o equipamento cria-se com o que está escrito (validado ao aplicar)
              TipoLinha.equipamento => true,
              _ => false,
            });

  LinhaAAplicar toAplicar(
    String? ingredienteId, {
    String? consumivelId,
    String? embalagemId,
  }) => (
    index: index,
    ingredienteId: ingredienteId,
    consumivelId: consumivelId,
    embalagemId: embalagemId,
    equipamento: tipo == TipoLinha.equipamento
        ? (nome: nome.text.trim(), custo: custoEquipV, vidaUtilAnos: vidaUtilV)
        : null,
    descricaoFatura: ia.descricao,
    quantidadeG: tipo.ehConsumivel ? _n(pecas) : gramasComprados,
    precoUnitario: _n(preco),
    totalLinha: ia.total ?? 0,
    embalagemG: embNaUnidade ?? 0,
    pecasCompradas: tipo == TipoLinha.embalagem ? _n(pecas) : 0,
    // removida pela pessoa (duplicada…): manda sempre como "Ignorar", nunca
    // o que estivesse escolhido antes de a remover.
    acao: removida ? AcaoFatura.ignorar : acao,
    produtoId: produto?.id,
    marca: marca.text.trim(),
    produtoNome: ia.descricao,
  );
}

/// Preferência (neste aparelho) com o tamanho da fatura no telemóvel.
const _chaveFracFatura = 'fatura_fixa_fracao';

class _Revisao extends ConsumerStatefulWidget {
  const _Revisao({
    required this.fatura,
    required this.ingredientes,
    required this.produtos,
    required this.consumiveis,
    required this.embalagens,
    required this.anteriores,
  });
  final Fatura fatura;
  final List<Ingrediente> ingredientes;
  final List<ProdutoIngrediente> produtos;
  final List<Consumivel> consumiveis;
  final List<Embalagem> embalagens;

  /// Decisões já gravadas nesta fatura (rondas anteriores de "Aplicar"), por
  /// índice de linha.
  final List<ItemFaturaAnterior> anteriores;

  @override
  ConsumerState<_Revisao> createState() => _RevisaoState();
}

class _RevisaoState extends ConsumerState<_Revisao> {
  late final List<_LinhaState> _linhas;
  bool _busy = false;
  bool _verFatura = true;

  bool get _isLista => widget.fatura.tipo == FaturaTipo.listaPrecos;

  /// Só o proprietário e o administrador registam equipamentos (como na lista
  /// de equipamentos); numa lista de preços não faz sentido.
  bool get _podeEquipamento => ehProprietarioOuAdmin(ref) && !_isLista;

  @override
  void initState() {
    super.initState();
    final anterioresPorIndice = {for (final a in widget.anteriores) a.index: a};
    final ias = widget.fatura.linhasIa;
    _linhas = [
      for (var i = 0; i < ias.length; i++)
        _linhaPara(i, ias[i], anterioresPorIndice[i]),
    ];
  }

  _LinhaState _linhaPara(int i, FaturaLinhaIa ia, ItemFaturaAnterior? ant) {
    MatchLinha? match;
    Consumivel? consMatch;
    Embalagem? embMatch;
    if (ant?.ingredienteId != null) {
      final ing = widget.ingredientes.firstWhereOrNull(
        (x) => x.id == ant!.ingredienteId,
      );
      if (ing != null) match = (ingrediente: ing, produto: null);
    } else if (ant?.consumivelId != null) {
      consMatch = widget.consumiveis.firstWhereOrNull(
        (c) => c.id == ant!.consumivelId,
      );
    } else if (ant?.embalagemId != null) {
      embMatch = widget.embalagens.firstWhereOrNull(
        (e) => e.id == ant!.embalagemId,
      );
    } else if (ant == null) {
      // sem decisão anterior: usa o emparelhamento automático
      if (ia.embalagem) {
        embMatch = _matchEmbalagem(ia);
      } else if (ia.consumivel) {
        consMatch = _matchConsumivel(ia);
      } else {
        match = _matchIngrediente(ia);
      }
    }
    return _LinhaState(
      ia,
      i,
      match: match,
      consMatch: consMatch,
      embMatch: embMatch,
      isLista: _isLista,
      anterior: ant,
      podeEquipamento: _podeEquipamento,
    );
  }

  MatchLinha? _matchIngrediente(FaturaLinhaIa ia) => emparelharLinha(
    descricao: ia.descricao,
    nomeGenerico: ia.nomeGenerico,
    marca: ia.marca,
    caracteristica: ia.caracteristica,
    embalagemG: ia.embalagemG ?? 0,
    ingredientes: widget.ingredientes,
    produtos: widget.produtos,
  );

  Consumivel? _matchConsumivel(FaturaLinhaIa ia) => emparelharConsumivel(
    descricao: ia.descricao,
    nomeGenerico: ia.nomeGenerico,
    marca: ia.marca,
    consumiveis: widget.consumiveis,
  );

  Embalagem? _matchEmbalagem(FaturaLinhaIa ia) => emparelharEmbalagem(
    descricao: ia.descricao,
    nomeGenerico: ia.nomeGenerico,
    embalagens: widget.embalagens,
  );

  /// Muda a linha entre ingrediente, limpeza/insumo e embalagem, e volta a
  /// procurar a correspondência do novo tipo.
  void _mudarTipo(_LinhaState l, TipoLinha tipo) {
    if (l.tipo == tipo) return;
    setState(() {
      l.tipo = tipo;
      l.criarNovo = false;
      l.renomear = false;
      l.ingrediente = null;
      l.produto = null;
      l.cons = null;
      l.embalagemSel = null;
      if (tipo.ehConsumivel) {
        final m = _matchConsumivel(l.ia);
        l.cons = m;
        l.categoria.text = m?.categoria ?? tipo.categoriaPreset;
      } else {
        switch (tipo) {
          case TipoLinha.embalagem:
            l.embalagemSel = _matchEmbalagem(l.ia);
          case TipoLinha.ingrediente:
            final m = _matchIngrediente(l.ia);
            l.ingrediente = m?.ingrediente;
            l.produto = m?.produto;
          case TipoLinha.equipamento:
            if (l.nome.text.trim().isEmpty) l.nome.text = l.ia.descricao;
          case TipoLinha.limpezaInsumo:
          case TipoLinha.bebida:
          case TipoLinha.revenda:
            break; // tratado acima (ehConsumivel)
        }
      }
      if (l.temAlvo &&
          (l.acao == AcaoFatura.ignorar || l.acao == AcaoFatura.pendente)) {
        l.acao = (_isLista || tipo != TipoLinha.ingrediente)
            ? AcaoFatura.preco
            : AcaoFatura.ambos;
      }
      if (tipo != TipoLinha.ingrediente &&
          (l.acao == AcaoFatura.stock || l.acao == AcaoFatura.ambos)) {
        l.acao = AcaoFatura.preco;
      }
    });
  }

  /// Cria um formato de cookie novo (só o nome) e liga-o logo à embalagem
  /// desta linha — para quando ainda não existe ou não se conhece o peso
  /// exato; o peso completa-se depois em Formatos de cookie.
  Future<void> _criarFormatoRapido(_LinhaState l) async {
    final ctrl = TextEditingController();
    final nome = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Novo formato de cookie'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nome'),
              onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
            ),
            const SizedBox(height: 8),
            Text(
              'Fica criado só com o nome — completa o peso depois em '
              'Configurações → Formatos de cookie.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    if (nome == null || nome.isEmpty || !mounted) return;
    try {
      await ref
          .read(cookieFormatActionsProvider)
          // massa_g exige >= 1 no esquema — 1 é só um marcador até a pessoa
          // preencher o peso real em Formatos de cookie.
          .criar(FormatoInput(nome: nome, massaG: 1));
      final formatos = await ref.read(formatosAtivosProvider.future);
      final criado = formatos.where((f) => f.nome == nome).lastOrNull;
      if (criado != null) setState(() => l.formatosCookieSel.add(criado.id));
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
      }
    }
  }

  /// Remove uma linha da revisão (duplicada, lida a mais pela IA…): some da
  /// lista e vai como "Ignorar" ao aplicar — nunca cria/atualiza nada com ela.
  void _removerLinha(_LinhaState l) {
    setState(() {
      l.removida = true;
      l.acao = AcaoFatura.ignorar;
    });
  }

  /// Acrescenta uma linha em branco para um item que a IA não leu na fatura —
  /// a pessoa preenche à mão (nome, quantidade, preço…), como uma linha normal.
  void _adicionarLinhaManual() {
    final proximo = _linhas.isEmpty
        ? 0
        : _linhas.map((l) => l.index).reduce((a, b) => a > b ? a : b) + 1;
    setState(() {
      _linhas.add(
        _LinhaState(
          const FaturaLinhaIa(descricao: ''),
          proximo,
          isLista: _isLista,
        )..criarNovo = true,
      );
    });
  }

  Future<void> _escolherConsumivel(_LinhaState l) async {
    final r = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ConsumivelPicker(
        consumiveis: widget.consumiveis,
        sugestaoNome: l.ia.nomeGenerico.isNotEmpty
            ? l.ia.nomeGenerico
            : l.ia.descricao,
      ),
    );
    if (r == null) return;
    setState(() {
      if (l.acao == AcaoFatura.ignorar || l.acao == AcaoFatura.pendente) {
        l.acao = AcaoFatura.preco;
      }
      if (r is Consumivel) {
        l.cons = r;
        l.criarNovo = false;
      } else {
        l.cons = null;
        l.criarNovo = true;
        l.nome.text = l.ia.nomeGenerico.isNotEmpty
            ? l.ia.nomeGenerico
            : l.ia.descricao;
      }
    });
  }

  Future<void> _escolherEmbalagem(_LinhaState l) async {
    final r = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EmbalagemPicker(
        embalagens: widget.embalagens,
        sugestaoNome: l.ia.nomeGenerico.isNotEmpty
            ? l.ia.nomeGenerico
            : l.ia.descricao,
      ),
    );
    if (r == null) return;
    setState(() {
      if (l.acao == AcaoFatura.ignorar || l.acao == AcaoFatura.pendente) {
        l.acao = AcaoFatura.preco;
      }
      if (r is Embalagem) {
        l.embalagemSel = r;
        l.criarNovo = false;
      } else {
        l.embalagemSel = null;
        l.criarNovo = true;
        l.nome.text = l.ia.nomeGenerico.isNotEmpty
            ? l.ia.nomeGenerico
            : l.ia.descricao;
      }
    });
  }

  Future<void> _escolherIngrediente(_LinhaState l) async {
    final r = await showModalBottomSheet<_EscolhaIngrediente>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _IngredientePicker(
        ingredientes: widget.ingredientes,
        descricaoFatura: l.ia.descricao,
        sugestaoNome: l.ia.nomeGenerico.isNotEmpty
            ? l.ia.nomeGenerico
            : l.ia.descricao,
      ),
    );
    if (r == null) return;
    setState(() {
      if (l.acao == AcaoFatura.ignorar || l.acao == AcaoFatura.pendente) {
        l.acao = _isLista ? AcaoFatura.preco : AcaoFatura.ambos;
      }
      switch (r) {
        case _EscolhaExistente(:final ing):
          l.ingrediente = ing;
          l.criarNovo = false;
          l.renomear = false;
          l.produto = produtoDaMarca(
            ing,
            widget.produtos,
            marca: l.marca.text,
            embalagemG: l.embV,
          );
          if (l.emb.text.trim().isEmpty && ing.gramasEmbalagem > 0) {
            l.emb.text = ing.gramasEmbalagem.toStringAsFixed(0);
          }
        case _EscolhaNovo():
          l.ingrediente = null;
          l.produto = null;
          l.criarNovo = true;
          l.renomear = false;
          l.nome.text = l.ia.nomeGenerico.isNotEmpty
              ? l.ia.nomeGenerico
              : l.ia.descricao;
      }
    });
  }

  Future<void> _aplicar() async {
    final aAplicar = _linhas
        .where((l) => !l.aplicadaAnterior && l.acao.aplicaAgora)
        .toList();
    if (aAplicar.any((l) => !l.temAlvo)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Há linhas sem ingrediente, produto ou embalagem. Liga, cria um '
            'novo, põe em "Por rever depois" ou "Ignorar".',
          ),
        ),
      );
      return;
    }
    if (aAplicar.any(
      (l) => (l.criarNovo || l.renomear) && l.nome.text.trim().isEmpty,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dá um nome ao que vais criar/renomear.')),
      );
      return;
    }
    // A descrição lida da fatura pode vir muito longa (código, lote,
    // validade…) — maior do que o campo `nome`/`caracteristica` aceita, o que
    // faz o "Aplicar" falhar com um erro genérico do servidor. Avisa antes.
    final nomeLongo = aAplicar.firstWhereOrNull(
      (l) =>
          (l.criarNovo || l.renomear) &&
          l.nome.text.trim().length > (l.tipo.ehConsumivel ? 250 : 200),
    );
    if (nomeLongo != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'O nome "${nomeLongo.nome.text.trim()}" é longo demais '
            '(máximo ${nomeLongo.tipo.ehConsumivel ? 250 : 200} caracteres). '
            'Encurta-o antes de aplicar.',
          ),
        ),
      );
      return;
    }
    final caracteristicaLonga = aAplicar.firstWhereOrNull(
      (l) => l.criarNovo && l.caracteristica.text.trim().length > 200,
    );
    if (caracteristicaLonga != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'A característica de "${caracteristicaLonga.nome.text.trim()}" é '
            'longa demais (máximo 200 caracteres). Encurta-a antes de aplicar.',
          ),
        ),
      );
      return;
    }
    final equipInvalido = aAplicar.firstWhereOrNull(
      (l) =>
          l.tipo == TipoLinha.equipamento &&
          (l.nome.text.trim().isEmpty ||
              l.custoEquipV <= 0 ||
              l.vidaUtilV <= 0),
    );
    if (equipInvalido != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Equipamento "${equipInvalido.ia.descricao}": falta o nome, o custo '
            'total ou a vida útil (anos).',
          ),
        ),
      );
      return;
    }
    final semUnidade = aAplicar.where(
      (l) => l.tipo == TipoLinha.ingrediente && l.problemaUnidade != null,
    );
    if (semUnidade.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(semUnidade.first.problemaUnidade!)),
      );
      return;
    }
    final novos = aAplicar
        .where((l) => l.criarNovo && l.tipo == TipoLinha.ingrediente)
        .length;
    final novosCons = aAplicar
        .where((l) => l.criarNovo && l.tipo.ehConsumivel)
        .length;
    final novosEmb = aAplicar
        .where((l) => l.criarNovo && l.tipo == TipoLinha.embalagem)
        .length;
    final equipamentos = aAplicar
        .where((l) => l.tipo == TipoLinha.equipamento)
        .length;
    final renomes = aAplicar.where((l) => l.renomear).length;
    final pendentesFicam = _linhas
        .where((l) => !l.aplicadaAnterior && l.acao == AcaoFatura.pendente)
        .length;

    // Aviso: preços que não vão mudar porque a fatura é mais antiga do que a
    // última atualização de preço do ingrediente (o servidor também garante).
    final dFatura = DateTime.tryParse(
      widget.fatura.dataFatura.isNotEmpty
          ? widget.fatura.dataFatura
          : widget.fatura.created,
    );
    var maisAntigos = 0;
    if (dFatura != null) {
      final diaFatura = DateTime(dFatura.year, dFatura.month, dFatura.day);
      for (final l in aAplicar) {
        if (l.acao != AcaoFatura.preco && l.acao != AcaoFatura.ambos) continue;
        final at = l.produto?.precoAtualizadoEm;
        if (at != null &&
            diaFatura.isBefore(DateTime(at.year, at.month, at.day))) {
          maisAntigos++;
        }
      }
    }

    final ok = await confirmDialog(
      context,
      titulo: 'Aplicar ${aAplicar.length} linha(s)?',
      mensagem: [
        'Atualiza os preços escolhidos e dá entrada no inventário das '
            'quantidades marcadas.',
        if (maisAntigos > 0)
          'Atenção: $maisAntigos preço(s) NÃO vão mudar — esta fatura é mais '
              'antiga do que a última atualização desse ingrediente.',
        if (novos > 0) 'Cria $novos ingrediente(s) novo(s).',
        if (novosCons > 0)
          'Cria $novosCons produto(s) de limpeza/insumos/revenda novo(s).',
        if (novosEmb > 0) 'Cria $novosEmb embalagem(ns) nova(s).',
        if (equipamentos > 0)
          'Regista $equipamentos equipamento(s): entram na lista de '
              'equipamentos, na depreciação mensal e nos custos.',
        if (renomes > 0)
          'Renomeia $renomes ingrediente(s) — muda em todas as receitas e '
              'fichas que o usam.',
        if (pendentesFicam > 0)
          '$pendentesFicam linha(s) ficam por rever depois — nada muda '
              'nelas; a fatura fica na lista para voltares quando tiveres a '
              'informação.',
        pendentesFicam > 0
            ? 'As restantes ficam confirmadas.'
            : 'A fatura fica confirmada.',
      ].join(' '),
      confirmar: 'Aplicar',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(ingredientRepositoryProvider);
      final forn = widget.fatura.fornecedor.trim();
      final ids = <_LinhaState, String?>{};
      final consIds = <_LinhaState, String?>{};
      final embIds = <_LinhaState, String?>{};
      // Uma linha que falhe a criar (ex.: nome longo demais) não pode travar
      // as restantes — fica por rever (os dados já escritos na linha não se
      // perdem) e as outras linhas prontas aplicam-se na mesma.
      final falhas = <String>[];
      for (final l in aAplicar) {
        if (l.tipo.ehConsumivel) {
          if (l.criarNovo) {
            try {
              // o preço e o nome da fatura ficam ao aplicar (no servidor)
              final novo = await ref
                  .read(consumivelActionsProvider)
                  .criar(
                    ConsumivelInput(
                      nome: l.nome.text.trim(),
                      categoria: l.categoria.text,
                      caracteristica: l.caracteristica.text.trim(),
                      marca: l.marca.text.trim(),
                      fornecedor: forn,
                      exigeFds: exigeFdsPorOmissaoPara(l.categoria.text),
                    ),
                  );
              consIds[l] = novo.id;
            } on Object catch (e) {
              falhas.add('"${l.nome.text.trim()}": ${mensagemAmigavel(e)}');
            }
          } else {
            consIds[l] = l.cons?.id;
          }
          continue;
        }
        switch (l.tipo) {
          case TipoLinha.embalagem:
            if (l.criarNovo) {
              try {
                // o preço e o nome da fatura ficam ao aplicar (no servidor)
                final novo = await ref
                    .read(embalagemActionsProvider)
                    .criar(
                      EmbalagemInput(
                        nome: l.nome.text.trim(),
                        tipo: l.tipoEmbalagemSel.text.trim().isEmpty
                            ? 'Outro'
                            : l.tipoEmbalagemSel.text.trim(),
                        caracteristica: l.caracteristica.text.trim(),
                        uso: l.usoEmbalagemSel,
                        formatosCookieIds: l.formatosCookieSel.toList(),
                        rendeUnidades:
                            l.usoEmbalagemSel == UsoEmbalagem.multiplo
                            ? l.quantidadeMultiplo.toDouble()
                            : 1,
                        fornecedor: forn,
                      ),
                    );
                embIds[l] = novo.id;
              } on Object catch (e) {
                falhas.add('"${l.nome.text.trim()}": ${mensagemAmigavel(e)}');
              }
            } else {
              embIds[l] = l.embalagemSel?.id;
            }
          case TipoLinha.equipamento:
            break; // criado no servidor, ao aplicar
          case TipoLinha.limpezaInsumo:
          case TipoLinha.bebida:
          case TipoLinha.revenda:
            break; // tratado acima (ehConsumivel)
          case TipoLinha.ingrediente:
            if (l.criarNovo) {
              try {
                final novo = await repo.create(
                  IngredienteInput(
                    nome: l.nome.text.trim(),
                    caracteristica: l.caracteristica.text.trim(),
                    unidade: l.unidadeIng,
                    // o preço e a marca ficam no produto de compra, criado ao
                    // aplicar (só numa linha "só stock" é que o preço vai já
                    // no ingrediente)
                    preco: l.acao == AcaoFatura.stock ? l.precoV : 0,
                    gramasEmbalagem: l.acao == AcaoFatura.stock
                        ? (l.embNaUnidade ?? 0)
                        : 0,
                    origem: OrigemIngrediente.comprado,
                  ),
                );
                ids[l] = novo.id;
              } on Object catch (e) {
                falhas.add('"${l.nome.text.trim()}": ${mensagemAmigavel(e)}');
              }
            } else if (l.renomear && l.ingrediente != null) {
              final ing = l.ingrediente!;
              try {
                await repo.update(
                  ing.id,
                  IngredienteInput(
                    nome: l.nome.text.trim(),
                    caracteristica: ing.caracteristica,
                    marca: ing.marca,
                    fornecedor: forn.isNotEmpty ? forn : ing.fornecedor,
                    preco: ing.preco,
                    gramasEmbalagem: ing.gramasEmbalagem,
                    disponivel: ing.disponivel,
                    origem: ing.origem,
                    unidade: ing.un,
                    gramasUnidade: ing.gramasUnidade,
                  ),
                );
                ids[l] = ing.id;
              } on Object catch (e) {
                falhas.add('"${l.nome.text.trim()}": ${mensagemAmigavel(e)}');
              }
            } else {
              ids[l] = l.ingrediente?.id;
            }
        }
      }

      // Reenvia todas as linhas (mesmo as já aplicadas antes ou por rever): o
      // servidor identifica pelo índice e só mexe nas que ainda faltam.
      final linhasEnviar = _linhas
          .map(
            (l) => l.toAplicar(
              ids[l],
              consumivelId: consIds[l],
              embalagemId: embIds[l],
            ),
          )
          .toList();
      final res = await ref
          .read(invoiceActionsProvider)
          .aplicar(widget.fatura.id, linhasEnviar);
      ref.invalidate(ingredientsListProvider);
      ref.invalidate(produtosIngredienteProvider);
      ref.invalidate(consumiveisListProvider);
      ref.invalidate(consumivelDocumentosProvider);
      ref.invalidate(embalagensListProvider);
      ref.invalidate(equipamentosListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            [
              '${res.precos} preço(s), ${res.movimentos} entrada(s) de stock',
              if (res.precosIgnorados > 0)
                '${res.precosIgnorados} preço(s) mantidos (fatura mais antiga)',
              if (novos > 0) '$novos novo(s)',
              if (novosCons > 0)
                '$novosCons produto(s) de limpeza/insumos/revenda',
              if (novosEmb > 0) '$novosEmb embalagem(ns)',
              if (res.equipamentos > 0)
                '${res.equipamentos} equipamento(s) registado(s)',
              if (renomes > 0) '$renomes renomeado(s)',
              if (res.pendentes > 0) '${res.pendentes} por rever',
            ].join(' · '),
          ),
        ),
      );
      // alerta de variação de preço: preços que subiram acima do limiar
      ref.invalidate(variacoesPrecoProvider);
      try {
        await ref.read(variacoesPrecoProvider.future);
      } on Object {
        // sem alerta se não conseguir ler
      }
      final recentes = ref
          .read(subidasPorVerProvider)
          .where((v) => DateTime.now().difference(v.criada).inMinutes < 5)
          .toList();
      if (mounted && recentes.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 12),
            content: Text(
              '${recentes.length} preço(s) subiram: '
              '${recentes.take(3).map((v) => '${v.ingredienteNome} +${v.pct.toStringAsFixed(0)}%').join(', ')}',
            ),
            action: SnackBarAction(
              label: 'Ver impacto',
              onPressed: () => context.go(Routes.inventoryPrecos),
            ),
          ),
        );
      }
      if (falhas.isNotEmpty && mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Algumas linhas não aplicaram'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'As restantes linhas prontas já foram aplicadas. Estas '
                    'ficam por rever — o que já preenchiste continua aqui, '
                    'corrige e tenta aplicar de novo:',
                  ),
                  const SizedBox(height: 8),
                  for (final f in falhas) Text('• $f'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Entendi'),
              ),
            ],
          ),
        );
      }
      final usados = {
        for (final id in consIds.values)
          if (id != null) id,
      };
      if (usados.isNotEmpty) await _avisarFdsEmFalta(usados);
      if (falhas.isEmpty && mounted && context.canPop()) context.pop();
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Depois de aplicar: lista os produtos desta fatura a que falta a ficha de
  /// dados de segurança (ou que a têm desatualizada), com atalho para anexar.
  Future<void> _avisarFdsEmFalta(Set<String> ids) async {
    try {
      final lista = await ref.read(consumiveisListProvider.future);
      final docs = await ref.read(consumivelDocumentosProvider.future);
      final pendentes = [
        for (final c in lista)
          if (ids.contains(c.id) &&
              const {EstadoFds.falta, EstadoFds.antiga}.contains(
                estadoFds(c, docs.where((d) => d.consumivelId == c.id)),
              ))
            c,
      ];
      if (pendentes.isEmpty || !mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Falta a ficha de segurança'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Estes produtos não têm a ficha de dados de segurança '
                  '(ou é antiga). Pede-a ao fornecedor e anexa-a:',
                ),
                for (final c in pendentes)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(c.nome),
                    trailing: TextButton(
                      onPressed: () => abrirConsumivelSheet(ctx, existente: c),
                      child: const Text('Anexar'),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Depois'),
            ),
          ],
        ),
      );
    } on Object {
      // o aviso é só um extra: nunca impede de concluir a fatura
    }
  }

  /// A fatura em ecrã inteiro. O botão de fechar usa o contexto do próprio
  /// diálogo (com o do ecrã fechava a página errada e a foto não saía).
  void _abrirTelaCheia(String url, {bool pdf = false}) {
    showDialog<void>(
      context: context,
      useSafeArea: false,
      builder: (ctx) => Dialog.fullscreen(
        child: Stack(
          children: [
            Positioned.fill(
              child: pdf
                  ? FaturaPdfView(
                      chave: widget.fatura.id,
                      url: url,
                      alternativa: const Center(
                        child: Text('Não foi possível abrir o PDF.'),
                      ),
                    )
                  : FaturaZoomView(url: url),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: const CircleBorder(),
                    child: IconButton(
                      key: const ValueKey('fatura-fechar'),
                      tooltip: 'Fechar',
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Pré-visualização grande da fatura, para conferir os dados ao lado (ecrã
  /// largo) ou por cima (telemóvel) das linhas.
  Widget _previewFatura(Fatura f, {required bool wide}) {
    _urlFuture ??= ref.read(invoiceRepositoryProvider).ficheiroUrlSeguro(f);
    return FutureBuilder<String>(
      future: _urlFuture,
      builder: (ctx, snap) {
        if (snap.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Não foi possível abrir o ficheiro da fatura.'),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }
        return _previewComUrl(f, snap.data!, wide: wide);
      },
    );
  }

  Future<String>? _urlFuture;

  Widget _previewComUrl(Fatura f, String url, {required bool wide}) {
    final cs = Theme.of(context).colorScheme;

    final cartaoPdf = Container(
      width: double.infinity,
      color: cs.surfaceContainerHighest,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.picture_as_pdf_outlined, size: 40, color: cs.primary),
          const SizedBox(height: 8),
          const Text('Fatura em PDF'),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () async {
              final u = await ref
                  .read(invoiceRepositoryProvider)
                  .ficheiroUrlSeguro(f);
              await launchUrl(
                Uri.parse(u),
                mode: LaunchMode.externalApplication,
              );
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Abrir PDF'),
          ),
        ],
      ),
    );

    Future<void> abrirFora() async {
      final u = await ref.read(invoiceRepositoryProvider).ficheiroUrlSeguro(f);
      await launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
    }

    if (f.ficheiroEhPdf) {
      return FaturaPdfView(
        chave: f.id,
        url: url,
        alternativa: cartaoPdf,
        aoTelaCheia: () => _abrirTelaCheia(url, pdf: true),
        aoAbrirFora: abrirFora,
      );
    }

    return FaturaZoomView(url: url, aoTelaCheia: () => _abrirTelaCheia(url));
  }

  /// Fração do ecrã (sem a barra de cima) ocupada pela fatura no telemóvel.
  double _fracFatura = (double.tryParse(lerPref(_chaveFracFatura) ?? '') ?? 0.5)
      .clamp(0.25, 0.75);

  /// Barra entre a fatura (fixa em cima) e as linhas: arrasta para dar mais
  /// espaço a uma ou às outras; toca para ocultar/mostrar a fatura.
  Widget _barraFatura(Fatura f, double alturaTotal) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: GestureDetector(
      key: const ValueKey('fatura-barra'),
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: alturaTotal <= 0
          ? null
          : (d) => setState(() {
              _verFatura = true;
              _fracFatura = (_fracFatura + d.delta.dy / alturaTotal).clamp(
                0.25,
                0.75,
              );
            }),
      onVerticalDragEnd: (_) =>
          guardarPref(_chaveFracFatura, _fracFatura.toStringAsFixed(2)),
      child: InkWell(
        onTap: () => setState(() => _verFatura = !_verFatura),
        child: SizedBox(
          height: 40,
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(
                _verFatura ? Icons.expand_less : Icons.expand_more,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(_verFatura ? 'Ocultar fatura' : 'Ver fatura'),
              const Spacer(),
              if (_verFatura) ...[
                Icon(
                  Icons.drag_handle,
                  size: 22,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Text(
                  'arrasta · 2 dedos para ampliar',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _cabecalho(Fatura f) => Card(
    child: ListTile(
      leading: Icon(
        f.ficheiroEhPdf
            ? Icons.picture_as_pdf_outlined
            : Icons.receipt_long_outlined,
      ),
      title: Text(f.fornecedor.isEmpty ? 'Fornecedor?' : f.fornecedor),
      subtitle: Text(
        [
          f.tipo.label,
          if (f.numero.isNotEmpty) 'nº ${f.numero}',
          if (f.dataFatura.isNotEmpty) formatDateShort(f.dataFatura),
          if (f.total > 0) 'total ${f.total.toStringAsFixed(2)}',
        ].join(' · '),
      ),
    ),
  );

  Widget _dropUnidade(String valor, void Function(String) onChanged) =>
      DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: valor,
          isDense: true,
          items: const [
            DropdownMenuItem(value: 'g', child: Text('g')),
            DropdownMenuItem(value: 'ml', child: Text('ml')),
            DropdownMenuItem(value: 'un', child: Text('un')),
          ],
          onChanged: (u) {
            if (u != null) onChanged(u);
          },
        ),
      );

  /// "Comprado": em g, ml ou un (nº de embalagens). Mudar a unidade converte o
  /// número já escrito, se a embalagem se conhece.
  Widget _campoComprado(_LinhaState l) => TextField(
    controller: l.qtd,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    onChanged: (_) => setState(() {}),
    decoration: InputDecoration(
      labelText: 'Comprado',
      isDense: true,
      helperText: l.unidadeQtd == 'un'
          ? (l.gramasComprados > 0
                ? '= ${_fmtNum(l.gramasComprados)} ${l.ingUn}'
                : 'Indica a embalagem')
          : null,
      suffix: _dropUnidade(l.unidadeQtd, (u) {
        setState(() {
          if (u == l.unidadeQtd) return;
          final atual = l.gramasComprados; // na unidade do ingrediente
          if (atual > 0) {
            if (u == 'un') {
              final e = l.embNaUnidade;
              if (e != null && e > 0) l.qtd.text = _fmtNum(atual / e);
            } else {
              final v = _converter(
                atual,
                l.ingUn,
                u,
                densidade: l.ingrediente?.nutriDensidade ?? 1,
              );
              if (v != null) l.qtd.text = _fmtNum(v);
            }
          }
          l.unidadeQtd = u;
        });
      }),
    ),
  );

  /// "Embalagem": tamanho de cada embalagem, em g, ml ou un.
  Widget _campoEmbalagem(_LinhaState l) => TextField(
    controller: l.emb,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    onChanged: (_) => setState(() {}),
    decoration: InputDecoration(
      labelText: 'Embalagem (tamanho)',
      isDense: true,
      helperText:
          l.embV > 0 && l.embNaUnidade != null && l.unidadeEmb != l.ingUn
          ? '= ${_fmtNum(l.embNaUnidade!)} ${l.ingUn} (o ingrediente está em ${l.ingUn})'
          : null,
      suffix: _dropUnidade(
        l.unidadeEmb,
        (u) => setState(() => l.unidadeEmb = u),
      ),
    ),
  );

  /// Campos de uma linha que é limpeza/insumo: produto, marca e documentos.
  List<Widget> _blocoConsumivel(_LinhaState l) {
    final docs =
        ref.watch(consumivelDocumentosProvider).valueOrNull ?? const [];
    final cs = Theme.of(context).colorScheme;
    final meus = l.cons == null
        ? const <DocumentoConsumivel>[]
        : docs.where((d) => d.consumivelId == l.cons!.id).toList();
    final estado = l.cons == null ? null : estadoFds(l.cons!, meus);
    final ap = estado == null ? null : apresentaEstadoFds(estado, cs);
    return [
      InkWell(
        onTap: () => _escolherConsumivel(l),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: l.tipo.pickerLabel,
            isDense: true,
            suffixIcon: const Icon(Icons.arrow_drop_down),
            helperText: l.criarNovo ? 'Vai criar um produto novo' : null,
          ),
          child: Text(
            l.criarNovo
                ? 'Novo produto'
                : (l.cons?.nome ?? 'Escolher produto…'),
            style: TextStyle(color: !l.temAlvo ? cs.error : null),
          ),
        ),
      ),
      if (l.criarNovo) ...[
        const SizedBox(height: 8),
        TextField(
          controller: l.nome,
          decoration: const InputDecoration(
            labelText: 'Nome do produto novo',
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: l.caracteristica,
          decoration: const InputDecoration(
            labelText: 'Característica (opcional)',
            hintText: 'lata 33cl, garrafa 1L, sabor limão…',
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        AutocompleteTextField(
          controller: l.categoria,
          options: ref.watch(categoriasConsumivelConhecidasProvider),
          labelText: 'Categoria',
          isDense: true,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 4),
        Text(
          exigeFdsPorOmissaoPara(l.categoria.text)
              ? 'Vai ficar a pedir a ficha de dados de segurança.'
              : 'Não pede ficha de dados de segurança (podes mudar depois).',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
      if (l.cons != null && ap != null) ...[
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(ap.icone, size: 18, color: ap.cor),
            Text(
              meus.isEmpty
                  ? ap.texto
                  : '${ap.texto} · ${meus.length} documento(s) já anexado(s)',
              style: TextStyle(color: ap.cor),
            ),
            TextButton(
              onPressed: () => abrirConsumivelSheet(context, existente: l.cons),
              child: const Text('Documentos'),
            ),
          ],
        ),
      ],
      const SizedBox(height: 8),
      AutocompleteTextField(
        controller: l.marca,
        options: ref.watch(marcasConhecidasProvider),
        labelText: 'Marca',
        isDense: true,
      ),
    ];
  }

  /// Campos de uma linha que é um equipamento (forno, batedeira, balcão…):
  /// nome, custo total e vida útil. A depreciação mensal vê-se logo.
  List<Widget> _blocoEquipamento(_LinhaState l) {
    final fmt = ref.watch(moneyFormatProvider);
    return [
      TextField(
        key: ValueKey('equip-nome-${l.index}'),
        controller: l.nome,
        decoration: const InputDecoration(
          labelText: 'Nome do equipamento',
          isDense: true,
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 8),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              key: ValueKey('equip-custo-${l.index}'),
              controller: l.custoEquip,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Custo total',
                prefixText: '€ ',
                helperText: 'O total pago (com todas as unidades)',
                helperMaxLines: 2,
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: ValueKey('equip-vida-${l.index}'),
              controller: l.vidaUtil,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Vida útil',
                suffixText: 'anos',
                helperText: 'Em quantos anos se paga',
                helperMaxLines: 2,
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        l.depreciacaoMensal > 0
            ? 'Depreciação: ${fmt(l.depreciacaoMensal)} por mês — entra na '
                  'lista de equipamentos e nos custos da empresa.'
            : 'Indica o custo e a vida útil para calcular a depreciação '
                  'mensal (Inventário → Equipamentos).',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ];
  }

  /// Campos de uma linha de embalagem (caixa, saco, saqueta, adesivo…).
  List<Widget> _blocoEmbalagem(_LinhaState l) {
    final cs = Theme.of(context).colorScheme;
    return [
      InkWell(
        onTap: () => _escolherEmbalagem(l),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Embalagem (caixa, saco, adesivo…)',
            isDense: true,
            suffixIcon: const Icon(Icons.arrow_drop_down),
            helperText: l.criarNovo ? 'Vai criar uma embalagem nova' : null,
          ),
          child: Text(
            l.criarNovo
                ? 'Nova embalagem'
                : (l.embalagemSel?.nome ?? 'Escolher embalagem…'),
            style: TextStyle(color: !l.temAlvo ? cs.error : null),
          ),
        ),
      ),
      if (l.criarNovo) ...[
        const SizedBox(height: 8),
        TextField(
          controller: l.nome,
          decoration: const InputDecoration(
            labelText: 'Nome da embalagem nova',
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        AutocompleteTextField(
          controller: l.tipoEmbalagemSel,
          options: ref.watch(tiposEmbalagemConhecidosProvider),
          labelText: 'Tipo',
          isDense: true,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: l.caracteristica,
          decoration: const InputDecoration(
            labelText: 'Característica (opcional)',
            hintText: 'Kraft com janela, transparente, 250 ml…',
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<UsoEmbalagem?>(
          key: ValueKey('${identityHashCode(l)}_${l.usoEmbalagemSel}'),
          initialValue: l.usoEmbalagemSel,
          decoration: const InputDecoration(
            labelText: 'Uso (opcional)',
            isDense: true,
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('Não definido')),
            for (final u in UsoEmbalagem.values)
              DropdownMenuItem(value: u, child: Text(u.label)),
          ],
          onChanged: (u) => setState(() => l.usoEmbalagemSel = u),
        ),
        if (l.usoEmbalagemSel == UsoEmbalagem.multiplo) ...[
          const SizedBox(height: 8),
          Text(
            'Quantidade do múltiplo',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final n in const [2, 3, 4, 5, 6, 8, 10, 12])
                ChoiceChip(
                  label: Text('$n'),
                  visualDensity: VisualDensity.compact,
                  selected: l.quantidadeMultiplo == n,
                  onSelected: (_) => setState(() => l.quantidadeMultiplo = n),
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Formatos de cookie (opcional)',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 4),
        ref
            .watch(formatosAtivosProvider)
            .maybeWhen(
              data: (formatos) => Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final fmt in formatos)
                    FilterChip(
                      label: Text(fmt.nome),
                      visualDensity: VisualDensity.compact,
                      selected: l.formatosCookieSel.contains(fmt.id),
                      onSelected: (v) => setState(() {
                        if (v) {
                          l.formatosCookieSel.add(fmt.id);
                        } else {
                          l.formatosCookieSel.remove(fmt.id);
                        }
                      }),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: const Text('Novo formato'),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _criarFormatoRapido(l),
                  ),
                ],
              ),
              orElse: () => const SizedBox.shrink(),
            ),
        const SizedBox(height: 4),
        Text(
          'Em branco serve para qualquer formato.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ];
  }

  /// Nome do ingrediente/consumível/embalagem a que uma linha (já aplicada
  /// ou não) ficou ligada, para mostrar no resumo.
  String? _destinoNome(_LinhaState l) => l.tipo.ehConsumivel
      ? l.cons?.nome
      : switch (l.tipo) {
          TipoLinha.ingrediente => l.ingrediente?.nome,
          TipoLinha.embalagem => l.embalagemSel?.nome,
          TipoLinha.equipamento => 'Equipamento registado',
          _ => null,
        };

  Future<void> _corrigirLinha(_LinhaState l) async {
    final ant = l.anterior;
    // só produto/consumível têm marca; embalagens não (ver mostrarCorrigirItem)
    if (ant == null || (ant.produtoId == null && ant.consumivelId == null)) {
      return;
    }
    final ok = await mostrarCorrigirItem(
      context,
      ref,
      faturaId: widget.fatura.id,
      index: l.index,
      descricao: ant.descricaoFatura.isNotEmpty
          ? ant.descricaoFatura
          : l.ia.descricao,
      marcaAtual: ant.marca,
    );
    if (!ok || !mounted) return;
    final itens = await ref.read(itensFaturaProvider(widget.fatura.id).future);
    final novo = itens.firstWhereOrNull((i) => i.index == l.index);
    if (novo != null) setState(() => l.anterior = novo);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Corrigido.')));
    }
  }

  Widget _linhaAplicadaTile(_LinhaState l) {
    final ant = l.anterior;
    final destino = _destinoNome(l);
    final subPartes = [
      if (destino != null) destino,
      if ((ant?.marca ?? '').isNotEmpty) 'marca ${ant!.marca}',
      if ((ant?.fornecedor ?? '').isNotEmpty) ant!.fornecedor,
    ];
    final temMarcaParaCorrigir =
        ant != null && (ant.produtoId != null || ant.consumivelId != null);
    final podeCorrigir = temMarcaParaCorrigir && ehProprietarioOuAdmin(ref);
    return ListTile(
      dense: true,
      title: Text(l.ia.descricao, style: const TextStyle(fontSize: 13)),
      subtitle: subPartes.isEmpty
          ? null
          : Text(subPartes.join(' · '), style: const TextStyle(fontSize: 12)),
      trailing: podeCorrigir
          ? IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'Corrigir marca',
              onPressed: () => _corrigirLinha(l),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.fatura;
    final naoAplicadas = _linhas.where((l) => !l.aplicadaAnterior).toList();
    final visiveis = naoAplicadas.where((l) => !l.removida).toList();
    final aplicadasCount = _linhas.length - naoAplicadas.length;
    final cs = Theme.of(context).colorScheme;
    final lista = ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: [
        _cabecalho(f),
        const SizedBox(height: 8),
        if (aplicadasCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                initiallyExpanded: false,
                leading: Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: cs.primary,
                ),
                title: Text(
                  '$aplicadasCount linha(s) já aplicada(s) antes — não '
                  'precisas de as rever.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                children: [
                  for (final l in _linhas.where((l) => l.aplicadaAnterior))
                    _linhaAplicadaTile(l),
                ],
              ),
            ),
          ),
        Text(
          'Linhas lidas pela IA — confirma cada uma',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        for (final l in visiveis)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 3),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          l.ia.descricao.isEmpty
                              ? 'Item novo (não veio da fatura)'
                              : l.ia.descricao,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Remover esta linha (duplicada, a mais…)',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _removerLinha(l),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final t in TipoLinha.values)
                        if (t != TipoLinha.equipamento ||
                            _podeEquipamento ||
                            l.tipo == TipoLinha.equipamento)
                          ChoiceChip(
                            label: Text(t.label),
                            visualDensity: VisualDensity.compact,
                            selected: l.tipo == t,
                            onSelected: (_) => _mudarTipo(l, t),
                          ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (l.tipo.ehConsumivel)
                    ..._blocoConsumivel(l)
                  else if (l.tipo == TipoLinha.embalagem)
                    ..._blocoEmbalagem(l)
                  else if (l.tipo == TipoLinha.equipamento)
                    ..._blocoEquipamento(l)
                  else
                    InkWell(
                      onTap: () => _escolherIngrediente(l),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Ingrediente',
                          isDense: true,
                          suffixIcon: const Icon(Icons.arrow_drop_down),
                          helperText: l.criarNovo
                              ? 'Vai criar um ingrediente novo'
                              : (l.renomear
                                    ? 'Vai renomear o ingrediente ligado'
                                    : null),
                        ),
                        child: Text(
                          l.criarNovo
                              ? 'Novo ingrediente'
                              : (l.ingrediente?.nomeComCaracteristica ??
                                    'Escolher ingrediente…'),
                          style: TextStyle(
                            color: !l.temAlvo
                                ? Theme.of(context).colorScheme.error
                                : null,
                          ),
                        ),
                      ),
                    ),
                  if (l.tipo == TipoLinha.ingrediente &&
                      (l.ingrediente != null || l.criarNovo)) ...[
                    const SizedBox(height: 8),
                    AutocompleteTextField(
                      controller: l.marca,
                      options: ref.watch(marcasConhecidasProvider),
                      labelText: 'Marca',
                      isDense: true,
                      helperText: l.produto != null
                          ? 'Produto já conhecido: ${l.produto!.resumo}'
                          : 'Vai criar um produto novo (marca e embalagem) '
                                'neste ingrediente',
                      helperMaxLines: 2,
                      onChanged: (v) => setState(() {
                        if (l.ingrediente != null) {
                          l.produto = produtoDaMarca(
                            l.ingrediente!,
                            widget.produtos,
                            marca: v,
                            embalagemG: l.embV,
                          );
                        }
                      }),
                    ),
                  ],
                  if (l.tipo == TipoLinha.ingrediente &&
                      (l.criarNovo || l.renomear)) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: l.nome,
                      decoration: InputDecoration(
                        labelText: l.criarNovo
                            ? 'Nome do ingrediente novo'
                            : 'Novo nome do ingrediente',
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (l.criarNovo) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: l.caracteristica,
                        decoration: const InputDecoration(
                          labelText: 'Característica (opcional)',
                          hintText: 'T55, T65, integral, 70% cacau…',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Unidade do ingrediente',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      SegmentedButton<String>(
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                        ),
                        segments: const [
                          ButtonSegment(value: 'g', label: Text('g')),
                          ButtonSegment(value: 'ml', label: Text('ml')),
                          ButtonSegment(value: 'un', label: Text('un')),
                        ],
                        selected: {l.unidadeIng},
                        onSelectionChanged: (v) =>
                            setState(() => l.unidadeIng = v.first),
                      ),
                    ],
                  ],
                  if (l.tipo == TipoLinha.ingrediente &&
                      l.ingrediente != null &&
                      l.nomeDiferente)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: CheckboxListTile(
                        value: l.renomear,
                        onChanged: (v) => setState(() {
                          l.renomear = v ?? false;
                          if (l.renomear) l.nome.text = l.ia.descricao;
                        }),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          'Passar «${l.ingrediente!.nome}» a '
                          'chamar-se «${l.ia.descricao}»',
                        ),
                        subtitle: const Text(
                          'muda em todas as receitas e fichas que o usam',
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (l.tipo != TipoLinha.equipamento)
                    Row(
                      children: [
                        if (!_isLista && l.tipo == TipoLinha.ingrediente) ...[
                          Expanded(child: _campoComprado(l)),
                          const SizedBox(width: 8),
                        ],
                        if (l.tipo == TipoLinha.embalagem) ...[
                          Expanded(
                            child: TextField(
                              controller: l.pecas,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Peças compradas',
                                isDense: true,
                                helperText: 'ex.: 500 (rolo de 500 adesivos)',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (!_isLista && l.tipo.ehConsumivel) ...[
                          Expanded(
                            child: TextField(
                              controller: l.pecas,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Comprado',
                                isDense: true,
                                helperText: 'unidades (ex.: 24 latas)',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: TextField(
                            controller: l.preco,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: l.tipo == TipoLinha.ingrediente
                                  ? 'Preço embalagem'
                                  // O total pago nesta compra, não o preço de
                                  // 1 peça/unidade — o app divide pelo que foi
                                  // comprado sozinho (embalagens.custoPeca /
                                  // consumiveis.preco por unidade).
                                  : (l.tipo == TipoLinha.embalagem ||
                                            l.tipo.ehConsumivel
                                        ? 'Preço da compra'
                                        : 'Preço'),
                              helperText:
                                  l.tipo == TipoLinha.embalagem ||
                                      l.tipo.ehConsumivel
                                  ? 'O total pago, não o preço de 1 unidade'
                                  : null,
                              prefixText: '€ ',
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (l.tipo == TipoLinha.ingrediente) ...[
                    const SizedBox(height: 8),
                    _campoEmbalagem(l),
                    if (l.problemaUnidade != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          l.problemaUnidade!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 8),
                  DropdownButtonFormField<AcaoFatura>(
                    // `l.acao` também muda por fora (ex.: ao escolher
                    // ingrediente numa linha "por rever" — `_escolherIngrediente`);
                    // a key força um remount para o `initialValue` refletir
                    // essa mudança (deixou de ser um campo controlado).
                    key: ValueKey('${identityHashCode(l)}_${l.acao.name}'),
                    initialValue: l.acao,
                    decoration: const InputDecoration(
                      labelText: 'Ação',
                      isDense: true,
                    ),
                    items: [
                      for (final a in AcaoFatura.values)
                        if ((!_isLista &&
                                (l.tipo == TipoLinha.ingrediente ||
                                    l.tipo.ehConsumivel)) ||
                            a == AcaoFatura.preco ||
                            a == AcaoFatura.pendente ||
                            a == AcaoFatura.ignorar)
                          DropdownMenuItem(
                            value: a,
                            child: Text(
                              l.tipo == TipoLinha.equipamento &&
                                      a == AcaoFatura.preco
                                  ? 'Registar equipamento'
                                  : a.label,
                            ),
                          ),
                    ],
                    onChanged: (a) =>
                        setState(() => l.acao = a ?? AcaoFatura.pendente),
                  ),
                ],
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _adicionarLinhaManual,
            icon: const Icon(Icons.add),
            label: const Text('Adicionar item em falta'),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _aplicar,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: const Text('Aplicar'),
        ),
      ],
    );

    if (!f.temFicheiro) return lista;

    final wide = MediaQuery.of(context).size.width >= 820;
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 380, child: _previewFatura(f, wide: true)),
          const VerticalDivider(width: 1),
          Expanded(child: lista),
        ],
      );
    }
    // telemóvel: a fatura fica FIXA em cima (≈ metade do ecrã, ajustável) e só
    // as linhas rolam por baixo; com o teclado aberto encolhe para dar lugar
    return LayoutBuilder(
      builder: (context, c) {
        final tecladoAberto = MediaQuery.of(context).viewInsets.bottom > 0;
        final frac = tecladoAberto ? _fracFatura * 0.6 : _fracFatura;
        final altura = c.maxHeight * frac;
        return Column(
          children: [
            if (_verFatura)
              SizedBox(
                key: const ValueKey('fatura-fixa'),
                height: altura,
                child: _previewFatura(f, wide: false),
              ),
            _barraFatura(f, c.maxHeight),
            Expanded(child: lista),
          ],
        );
      },
    );
  }
}

/// Resultado do `_IngredientePicker`: ligar a um existente ou criar um novo.
sealed class _EscolhaIngrediente {
  const _EscolhaIngrediente();
}

class _EscolhaExistente extends _EscolhaIngrediente {
  const _EscolhaExistente(this.ing);
  final Ingrediente ing;
}

class _EscolhaNovo extends _EscolhaIngrediente {
  const _EscolhaNovo();
}

class _IngredientePicker extends StatefulWidget {
  const _IngredientePicker({
    required this.ingredientes,
    required this.descricaoFatura,
    required this.sugestaoNome,
  });
  final List<Ingrediente> ingredientes;
  final String descricaoFatura;
  final String sugestaoNome;

  @override
  State<_IngredientePicker> createState() => _IngredientePickerState();
}

class _IngredientePickerState extends State<_IngredientePicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final itens = widget.ingredientes
        .where((i) => i.correspondeABusca(_q))
        .toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Procurar ingrediente',
                isDense: true,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Criar ingrediente novo (genérico)'),
            subtitle: Text('«${widget.sugestaoNome}»'),
            onTap: () => Navigator.pop(context, const _EscolhaNovo()),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: itens.length,
              itemBuilder: (_, i) => ListTile(
                // O nome sozinho não chega para distinguir variantes do
                // mesmo produto (ex.: "Café em grão" gold vs. bio) — a
                // característica tem de aparecer sempre.
                title: Text(itens[i].nomeComCaracteristica),
                subtitle: Text(
                  [
                    if (itens[i].marca.isNotEmpty) itens[i].marca,
                    if (itens[i].gramasEmbalagem > 0)
                      gramasParaTexto(itens[i].gramasEmbalagem),
                  ].join(' · '),
                ),
                onTap: () =>
                    Navigator.pop(context, _EscolhaExistente(itens[i])),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsumivelPicker extends StatefulWidget {
  const _ConsumivelPicker({
    required this.consumiveis,
    required this.sugestaoNome,
  });
  final List<Consumivel> consumiveis;
  final String sugestaoNome;

  @override
  State<_ConsumivelPicker> createState() => _ConsumivelPickerState();
}

class _ConsumivelPickerState extends State<_ConsumivelPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final itens = widget.consumiveis
        .where((c) => correspondeABusca('${c.nome} ${c.marca}', _q))
        .toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Procurar produto',
                isDense: true,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Criar produto novo'),
            subtitle: Text('«${widget.sugestaoNome}»'),
            onTap: () => Navigator.pop(context, const _EscolhaNovo()),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: itens.length,
              itemBuilder: (_, i) => ListTile(
                title: Text(itens[i].nome),
                subtitle: Text(
                  [
                    itens[i].categoria,
                    if (itens[i].marca.isNotEmpty) itens[i].marca,
                  ].join(' · '),
                ),
                onTap: () => Navigator.pop(context, itens[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmbalagemPicker extends StatefulWidget {
  const _EmbalagemPicker({
    required this.embalagens,
    required this.sugestaoNome,
  });
  final List<Embalagem> embalagens;
  final String sugestaoNome;

  @override
  State<_EmbalagemPicker> createState() => _EmbalagemPickerState();
}

class _EmbalagemPickerState extends State<_EmbalagemPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final itens = widget.embalagens
        .where(
          (e) => correspondeABusca(
            '${e.nome} ${e.caracteristica} ${e.tipo} ${e.fornecedor}',
            _q,
          ),
        )
        .toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Procurar embalagem',
                isDense: true,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Criar embalagem nova'),
            subtitle: Text('«${widget.sugestaoNome}»'),
            onTap: () => Navigator.pop(context, const _EscolhaNovo()),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: itens.length,
              itemBuilder: (_, i) => ListTile(
                // Sem a característica, duas variantes com o mesmo nome
                // (ex.: caixa "com janela" vs. "sem janela") ficam
                // indistinguíveis nesta lista.
                title: Text(
                  itens[i].caracteristica.isEmpty
                      ? itens[i].nome
                      : '${itens[i].nome} ${itens[i].caracteristica}',
                ),
                subtitle: Text(
                  [
                    if (itens[i].tipo.isNotEmpty) itens[i].tipo else 'Sem tipo',
                    if (itens[i].fornecedor.isNotEmpty) itens[i].fornecedor,
                  ].join(' · '),
                ),
                onTap: () => Navigator.pop(context, itens[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
