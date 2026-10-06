import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/permissions.dart';
import 'pagina_app.dart';

/// O que um papel pode fazer numa página.
enum NivelAcesso {
  oculto,
  ver,
  editar;

  static NivelAcesso? fromName(Object? v) {
    for (final n in NivelAcesso.values) {
      if (n.name == v) return n;
    }
    return null;
  }

  String get label => switch (this) {
    NivelAcesso.oculto => 'Oculto',
    NivelAcesso.ver => 'Só ver',
    NivelAcesso.editar => 'Editar',
  };
}

/// Nível de acesso por omissão de um papel numa página (igual ao
/// comportamento antes de haver personalização).
NivelAcesso nivelPorOmissao(Papel papel, String chave) {
  switch (papel) {
    case Papel.owner:
      return NivelAcesso.editar;
    case Papel.admin:
      return NivelAcesso.editar;
    case Papel.editor:
      return chave == 'configuracoes' || chave == 'equipa'
          ? NivelAcesso.ver
          : NivelAcesso.editar;
    case Papel.viewer:
      // ponto e férias são dados das pessoas: a Leitura não os vê
      return chave == 'pessoas' ? NivelAcesso.oculto : NivelAcesso.ver;
  }
}

/// Configuração de navegação da empresa: rodapé e permissões por papel.
class NavConfig {
  const NavConfig({
    this.id = '',
    this.rodape = rodapePorOmissao,
    this.acesso = const {},
  });

  static const vazia = NavConfig();

  /// Id da linha (vazio = ainda não gravada).
  final String id;

  /// Chaves das páginas do rodapé, por ordem (sem o Início).
  final List<String> rodape;

  /// `papel.name` → chave da página → nível. Só guarda o que difere do
  /// nível por omissão.
  final Map<String, Map<String, NivelAcesso>> acesso;

  /// O proprietário nunca fica sem acesso, mesmo com dados mal formados.
  NivelAcesso nivel(Papel papel, String chave) {
    if (papel == Papel.owner) return NivelAcesso.editar;
    return acesso[papel.name]?[chave] ?? nivelPorOmissao(papel, chave);
  }

  bool acessivel(Papel papel, String chave) =>
      nivel(papel, chave) != NivelAcesso.oculto;

  /// Páginas do rodapé que este papel pode abrir (Início não incluído).
  List<PaginaApp> rodapePara(Papel papel) => [
    for (final k in rodape)
      if (paginaPorChave(k) case final p? when acessivel(papel, k)) p,
  ];

  NavConfig comRodape(List<String> novo) =>
      NavConfig(id: id, rodape: novo, acesso: acesso);

  NavConfig comNivel(Papel papel, String chave, NivelAcesso n) {
    final atual = {
      for (final e in acesso.entries) e.key: {...e.value},
    };
    final doPapel = atual.putIfAbsent(papel.name, () => {});
    if (n == nivelPorOmissao(papel, chave)) {
      doPapel.remove(chave);
    } else {
      doPapel[chave] = n;
    }
    return NavConfig(id: id, rodape: rodape, acesso: atual);
  }

  Map<String, dynamic> acessoJson() => {
    for (final e in acesso.entries)
      if (e.value.isNotEmpty)
        e.key: {for (final c in e.value.entries) c.key: c.value.name},
  };

  factory NavConfig.fromRecord(RecordModel r) {
    final rawRodape = r.data['rodape'];
    final rodape = rawRodape is List
        ? [
            for (final k in rawRodape)
              if (k is String && paginaPorChave(k) != null) k,
          ]
        : null;

    final rawAcesso = r.data['acesso'];
    final acesso = <String, Map<String, NivelAcesso>>{};
    if (rawAcesso is Map) {
      rawAcesso.forEach((papel, paginas) {
        if (paginas is! Map) return;
        final m = <String, NivelAcesso>{};
        paginas.forEach((chave, nivel) {
          final n = NivelAcesso.fromName(nivel);
          if (n != null && paginaPorChave('$chave') != null) m['$chave'] = n;
        });
        acesso['$papel'] = m;
      });
    }
    return NavConfig(
      id: r.id,
      rodape: (rodape == null || rodape.isEmpty) ? rodapePorOmissao : rodape,
      acesso: acesso,
    );
  }
}
