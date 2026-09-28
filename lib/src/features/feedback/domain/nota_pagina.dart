import 'package:pocketbase/pocketbase.dart';

/// Uma nota de equipa numa página da app — diferente de "sugestões" (essas só
/// os programadores leem): qualquer pessoa da empresa vê e escreve, para
/// avisar colegas de um problema ou decisão sem precisar de falar por fora
/// da app. Marca-se como resolvida quando já não faz falta.
class NotaPagina {
  const NotaPagina({
    required this.id,
    required this.pagina,
    required this.texto,
    this.autorNome = '',
    this.resolvida = false,
    this.resolvidaEm = '',
    this.resolvidaPor = '',
    this.created = '',
  });

  final String id;
  final String pagina;
  final String texto;
  final String autorNome;
  final bool resolvida;
  final String resolvidaEm;
  final String resolvidaPor;
  final String created;

  factory NotaPagina.fromRecord(RecordModel r) => NotaPagina(
    id: r.id,
    pagina: r.getStringValue('pagina'),
    texto: r.getStringValue('texto'),
    autorNome: r.getStringValue('autor_nome'),
    resolvida: r.getBoolValue('resolvida'),
    resolvidaEm: r.getStringValue('resolvida_em'),
    resolvidaPor: r.getStringValue('resolvida_por'),
    created: r.getStringValue('created'),
  );
}
