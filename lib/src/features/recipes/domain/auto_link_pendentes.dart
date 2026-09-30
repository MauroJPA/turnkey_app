import '../../ingredients/domain/ingredient.dart';
import '../../invoices/domain/match_ingrediente.dart';
import 'recipe_item.dart';

/// Resultado de tentar ligar um item pendente a um ingrediente pelo nome.
class SugestaoLigacao {
  SugestaoLigacao({required this.item, this.exato, this.sugestao});

  final ItemReceita item;

  /// Ingrediente com o mesmo nome (ignorando acentos/maiúsculas/característica)
  /// — liga-se sozinho, sem precisar de revisão.
  final Ingrediente? exato;

  /// Ingrediente parecido (quando não há nome exatamente igual) — fica só
  /// como sugestão pré-preenchida, a confirmar.
  final Ingrediente? sugestao;

  bool get temExato => exato != null;
}

/// Para cada item pendente (sem ingrediente nem sub-receita), tenta encontrar
/// o ingrediente certo pelo [ItemReceita.nomeProvisorio]: primeiro por
/// igualdade exata de nome (não precisa de revisão), senão por semelhança
/// (fica como sugestão a confirmar manualmente).
List<SugestaoLigacao> sugerirLigacoes(
  List<ItemReceita> pendentes,
  List<Ingrediente> ingredientes,
) => [for (final item in pendentes) _sugerir(item, ingredientes)];

SugestaoLigacao _sugerir(ItemReceita item, List<Ingrediente> ingredientes) {
  final alvo = normalizarNome(item.nomeProvisorio);
  if (alvo.isEmpty) return SugestaoLigacao(item: item);
  for (final ing in ingredientes) {
    if (normalizarNome(ing.nome) == alvo ||
        normalizarNome(ing.nomeComCaracteristica) == alvo) {
      return SugestaoLigacao(item: item, exato: ing);
    }
  }
  return SugestaoLigacao(
    item: item,
    sugestao: melhorMatch(item.nomeProvisorio, ingredientes),
  );
}
