import '../../../core/formatting/busca.dart';

/// Uma categoria de receitas (ex.: Massa, Recheio, Cobertura). Já não há uma
/// página nem uma tabela para as gerir: a categoria é o NOME guardado em
/// `receitas.categoria` — cria-se ao escolher/escrever uma na receita, muda-se
/// o nome mantendo premido o botão da categoria, e **desaparece sozinha
/// quando nenhuma receita a usa**.
class CategoriaReceita {
  const CategoriaReceita({required this.nome});

  final String nome;

  /// Compatibilidade: o nome é a identificação.
  String get id => nome;
}

/// As categorias sugeridas numa empresa nova (aparecem sempre para escolher).
const categoriasReceitaPadrao = <String>[
  'Massa',
  'Recheio',
  'Cobertura',
  'Outra',
];

/// As categorias para escolher: as sugeridas, mais as que as receitas usam,
/// mais as [extra] (ex.: a que acabou de ser escrita e ainda não foi
/// guardada). Sem repetidas (ignora maiúsculas); as sugeridas primeiro, as
/// outras por ordem alfabética.
List<String> categoriasDisponiveis(
  Iterable<String> emUso, {
  Iterable<String> extra = const [],
}) {
  final vistos = <String>{};
  final out = <String>[];
  for (final n in categoriasReceitaPadrao) {
    if (vistos.add(normalizarBusca(n))) out.add(n);
  }
  final outras = <String>[];
  for (final n in [...emUso, ...extra]) {
    final t = n.trim();
    if (t.isNotEmpty && vistos.add(normalizarBusca(t))) outras.add(t);
  }
  outras.sort((a, b) => normalizarBusca(a).compareTo(normalizarBusca(b)));
  return [...out, ...outras];
}
