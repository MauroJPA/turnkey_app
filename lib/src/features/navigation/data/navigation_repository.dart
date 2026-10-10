import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../domain/nav_config.dart';
import '../domain/nav_prefs.dart';
import '../domain/papel_personalizado.dart';

final navigationRepositoryProvider = Provider<NavigationRepository>((ref) {
  return NavigationRepository(ref.watch(pbProvider), requireEmpresaId(ref));
});

class NavigationRepository {
  NavigationRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  RecordService get _config => _pb.collection('configuracoes_navegacao');
  RecordService get _prefs => _pb.collection('preferencias_utilizador');

  String get _userId => _pb.authStore.record?.id ?? '';

  /// Sem linha ainda (empresa nova), devolve [NavConfig.vazia].
  Future<NavConfig> getConfig() async {
    try {
      final rec = await _config.getFirstListItem('empresa = "$_empresaId"');
      return NavConfig.fromRecord(rec);
    } on ClientException {
      return NavConfig.vazia;
    }
  }

  Future<NavConfig> salvarRodape(NavConfig atual, List<String> rodape) async {
    final rec = atual.id.isEmpty
        ? await _config.create(body: {'empresa': _empresaId, 'rodape': rodape})
        : await _config.update(atual.id, body: {'rodape': rodape});
    return NavConfig.fromRecord(rec);
  }

  /// Só o proprietário consegue (a regra do servidor recusa o resto).
  Future<NavConfig> salvarAcesso(
    NavConfig atual,
    Map<String, dynamic> acesso,
  ) async {
    final rec = atual.id.isEmpty
        ? await _config.create(body: {'empresa': _empresaId, 'acesso': acesso})
        : await _config.update(atual.id, body: {'acesso': acesso});
    return NavConfig.fromRecord(rec);
  }

  RecordService get _papeis => _pb.collection('papeis_personalizados');

  Future<List<PapelPersonalizado>> listarPapeis() async {
    final recs = await _papeis.getFullList(
      filter: _pb.filter('empresa = {:e}', {'e': _empresaId}),
      sort: 'nome',
    );
    return recs.map(PapelPersonalizado.fromRecord).toList();
  }

  /// Só o proprietário consegue (a regra do servidor recusa o resto).
  Future<PapelPersonalizado> criarPapel(String nome, Papel base) async {
    final r = await _papeis.create(
      body: {
        'empresa': _empresaId,
        'nome': nome.trim(),
        'base': base.name,
        'acesso': <String, String>{},
      },
    );
    return PapelPersonalizado.fromRecord(r);
  }

  Future<void> guardarPapel(PapelPersonalizado p) => _papeis.update(
    p.id,
    body: {
      'nome': p.nome.trim(),
      'base': p.base.name,
      'acesso': p.acessoJson(),
    },
  );

  Future<void> apagarPapel(String id) => _papeis.delete(id);

  Future<NavPrefs> getPrefs() async {
    try {
      final rec = await _prefs.getFirstListItem(
        'empresa = "$_empresaId" && utilizador = "$_userId"',
      );
      return NavPrefs.fromRecord(rec);
    } on ClientException {
      return NavPrefs.vazia;
    }
  }

  Future<NavPrefs> salvarPrefs(NavPrefs p) async {
    final rec = p.id.isEmpty
        ? await _prefs.create(body: {
            ...p.toBody(),
            'empresa': _empresaId,
            'utilizador': _userId,
          })
        : await _prefs.update(p.id, body: p.toBody());
    return NavPrefs.fromRecord(rec);
  }
}
