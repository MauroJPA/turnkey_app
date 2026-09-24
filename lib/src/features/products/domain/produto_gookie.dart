import '../../tech_sheets/domain/tech_sheet.dart';

/// O que ainda falta preencher num produto para a informação (e a etiqueta)
/// ficar completa. Lista vazia = tudo em ordem.
List<String> pendenciasProduto(FichaTecnica f) {
  final n = f.nutri;
  return [
    if (n.vazio)
      'Sem informação nutricional'
    else if (!n.completo)
      'Nutrição incompleta (${n.semDados.length} '
          '${n.semDados.length == 1 ? 'ingrediente' : 'ingredientes'} sem dados)',
    if (f.descricao.trim().isEmpty) 'Sem descrição',
    if (f.validadeDias <= 0) 'Sem prazo de validade',
    if (f.conservacao.trim().isEmpty) 'Sem modo de conservação',
  ];
}

/// A nutrição está completa e utilizável (independentemente dos outros dados).
bool nutricaoCompleta(FichaTecnica f) => !f.nutri.vazio && f.nutri.completo;
