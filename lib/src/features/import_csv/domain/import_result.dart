/// Resultado de uma importação de CSV.
class ImportResult {
  ImportResult({
    this.criados = 0,
    this.atualizados = 0,
    List<String>? erros,
  }) : erros = erros ?? [];

  int criados;
  int atualizados;
  final List<String> erros;

  int get total => criados + atualizados;
  bool get semErros => erros.isEmpty;

  String get resumo {
    final partes = <String>[];
    if (criados > 0) partes.add('$criados criado(s)');
    if (atualizados > 0) partes.add('$atualizados atualizado(s)');
    if (partes.isEmpty) partes.add('nada importado');
    return partes.join(', ');
  }
}

/// Importação cancelada pelo utilizador (nenhum ficheiro escolhido).
class ImportCancelled implements Exception {
  const ImportCancelled();
}
