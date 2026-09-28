import 'package:pocketbase/pocketbase.dart';

import '../../../core/formatting/capitalizar.dart';

/// Uma categoria de receitas da empresa (ex.: Massa, Recheio, Cobertura) —
/// gerível por empresa, ao contrário do que era antes (lista fixa no
/// código). Guardada em `receitas.categoria` pelo NOME (texto livre), não
/// por id — apagar/renomear uma categoria não quebra receitas antigas.
class CategoriaReceita {
  const CategoriaReceita({
    required this.id,
    required this.nome,
    this.ordem = 0,
    this.ativo = true,
  });

  final String id;
  final String nome;
  final double ordem;
  final bool ativo;

  factory CategoriaReceita.fromRecord(RecordModel r) => CategoriaReceita(
    id: r.id,
    nome: r.getStringValue('nome'),
    ordem: r.getDoubleValue('ordem'),
    ativo: r.getBoolValue('ativo'),
  );
}

class CategoriaReceitaInput {
  CategoriaReceitaInput({
    required this.nome,
    this.ordem = 0,
    this.ativo = true,
  });

  final String nome;
  final double ordem;
  final bool ativo;

  Map<String, dynamic> toBody() => {
    'nome': capitalizarInicial(nome.trim()),
    'ordem': ordem,
    'ativo': ativo,
  };
}
