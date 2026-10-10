import '../../tech_sheets/domain/tech_sheet.dart';

/// Modos de conservação para escolher (o mais comum é o primeiro).
const conservacoesPadrao = <String>[
  'Local fresco e seco',
  'Refrigerado (0 a 5 °C)',
  'Local fresco e seco ou refrigerado',
  'Congelado (-18 °C)',
];

/// O que ainda falta preencher num produto para a informação (e a etiqueta)
/// ficar completa. Lista vazia = tudo em ordem. A **descrição é opcional**,
/// por isso nunca conta como falta.
List<String> pendenciasProduto(FichaTecnica f) {
  final n = f.nutri;
  return [
    if (n.vazio)
      'Sem informação nutricional'
    else if (!n.completo)
      'Nutrição incompleta (${n.semDados.length} '
          '${n.semDados.length == 1 ? 'ingrediente' : 'ingredientes'} sem dados)',
    // a revenda já traz rótulo próprio: só interessa a nutrição
    if (!f.revenda && f.validadeDias <= 0) 'Sem prazo de validade',
    if (!f.revenda && f.conservacao.trim().isEmpty) 'Sem modo de conservação',
  ];
}

/// A nutrição está completa e utilizável (independentemente dos outros dados).
bool nutricaoCompleta(FichaTecnica f) => !f.nutri.vazio && f.nutri.completo;
