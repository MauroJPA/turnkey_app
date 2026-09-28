/// Regra de escrita da app: nomes de ingredientes, produtos, consumíveis,
/// embalagens, receitas, etc. começam sempre por maiúscula.
library;

/// Põe a primeira letra de [texto] em maiúscula, sem mexer no resto (não
/// força maiúsculas/minúsculas nas outras letras — só a inicial). Espaços
/// (ou outros caracteres não-letra) no início são ignorados: a maiúscula
/// aplica-se à primeira letra de verdade. Texto vazio devolve-se como está.
///
/// Ex.: `capitalizarInicial('farinha de trigo T55')` → `'Farinha de trigo T55'`;
/// `capitalizarInicial('óleo de girassol')` → `'Óleo de girassol'`.
String capitalizarInicial(String texto) {
  if (texto.isEmpty) return texto;
  final i = texto.indexOf(RegExp(r'[^\s]'));
  if (i < 0) return texto;
  return texto.substring(0, i) +
      texto[i].toUpperCase() +
      texto.substring(i + 1);
}
