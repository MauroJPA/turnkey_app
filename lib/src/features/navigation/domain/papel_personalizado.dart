import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/permissions.dart';
import 'nav_config.dart';
import 'pagina_app.dart';

/// Um papel com nome ("Balcão", "Cozinha", "Contabilista"…). Parte de um papel
/// [base] (Administrador, Editor ou Leitura) — que é o que o servidor deixa
/// fazer — e ajusta página a página o que se vê e edita. O que não muda herda
/// do papel base (com a matriz da empresa).
class PapelPersonalizado {
  const PapelPersonalizado({
    required this.id,
    required this.nome,
    required this.base,
    this.acesso = const {},
  });

  final String id;
  final String nome;

  /// Nunca é o proprietário (esse tem sempre acesso total).
  final Papel base;

  /// Só as páginas que diferem do papel base.
  final Map<String, NivelAcesso> acesso;

  /// Papéis base que se podem escolher.
  static const bases = [Papel.admin, Papel.editor, Papel.viewer];

  /// O nível nesta página: o ajustado, ou o do papel base. Com base Leitura
  /// nunca passa de "Só ver" (o servidor não deixaria gravar).
  NivelAcesso nivel(
    String chave,
    NivelAcesso Function(Papel papel, String chave) doBase,
  ) {
    final n = acesso[chave] ?? doBase(base, chave);
    return base == Papel.viewer && n == NivelAcesso.editar
        ? NivelAcesso.ver
        : n;
  }

  /// Muda o nível de uma página; se ficar igual ao do papel base, deixa de ser
  /// um ajuste (volta a herdar).
  PapelPersonalizado comNivel(String chave, NivelAcesso n, NavConfig config) {
    final novo = {...acesso};
    if (n == config.nivelBase(base, chave)) {
      novo.remove(chave);
    } else {
      novo[chave] = n;
    }
    return PapelPersonalizado(id: id, nome: nome, base: base, acesso: novo);
  }

  Map<String, String> acessoJson() => {
    for (final e in acesso.entries) e.key: e.value.name,
  };

  /// Quantas páginas mudam em relação ao papel base.
  int get nAjustes => acesso.length;

  factory PapelPersonalizado.fromRecord(RecordModel r) {
    final raw = r.data['acesso'];
    final m = <String, NivelAcesso>{};
    if (raw is Map) {
      raw.forEach((chave, nivel) {
        final n = NivelAcesso.fromName(nivel);
        if (n != null && paginaPorChave('$chave') != null) m['$chave'] = n;
      });
    }
    final base = Papel.fromName(r.getStringValue('base'));
    return PapelPersonalizado(
      id: r.id,
      nome: r.getStringValue('nome'),
      // dados estranhos nunca dão o proprietário
      base: base == Papel.owner ? Papel.viewer : base,
      acesso: m,
    );
  }
}

/// Um papel para escolher: um dos normais, ou um personalizado (id).
typedef EscolhaPapel = ({Papel papel, String personalizado});

/// Os papéis personalizados que [eu] pode dar (o administrador não dá os de
/// base Administrador — o servidor também recusa).
List<PapelPersonalizado> papeisQuePossoDar(
  Papel eu,
  List<PapelPersonalizado> todos,
) => [
  for (final p in todos)
    if (eu == Papel.owner || p.base != Papel.admin) p,
];
