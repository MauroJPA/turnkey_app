import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../domain/team_member.dart';

final teamRepositoryProvider = Provider<TeamRepository>((ref) {
  return TeamRepository(ref.watch(pbProvider), requireEmpresaId(ref));
});

class TeamRepository {
  TeamRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  /// A conta com a sessão aberta.
  String? get utilizadorId => _pb.authStore.record?.id;

  Future<List<TeamMember>> listMembers() async {
    final recs = await _pb
        .collection('users')
        .getFullList(filter: 'empresa = "$_empresaId"', sort: 'nome');
    return recs.map(TeamMember.fromRecord).toList();
  }

  /// Cria um membro na empresa (endpoint privilegiado — ver pb/hooks/team.pb.js).
  Future<void> addMember({
    required String nome,
    required String email,
    required String password,
    required Papel papel,
  }) {
    return _pb.send(
      '/api/gc_turnkey/team/members',
      method: 'POST',
      body: {
        'nome': nome,
        'email': email,
        'password': password,
        'papel': papel.name,
      },
    );
  }

  /// Repõe a palavra-passe de [memberId]: o servidor gera uma provisória
  /// (devolvida uma só vez), fecha as sessões dessa conta e obriga a pessoa
  /// a escolher uma nova ao entrar.
  Future<String> resetPassword(String memberId) async {
    final res = await _pb.send(
      '/api/gc_turnkey/team/members/$memberId/senha',
      method: 'POST',
      body: {},
    );
    return (res is Map ? res['senha'] : null)?.toString() ?? '';
  }

  /// Remove a conta de [memberId] (deixa de poder entrar).
  Future<void> removeMember(String memberId) =>
      _pb.send('/api/gc_turnkey/team/members/$memberId', method: 'DELETE');

  Future<void> changeRole(String memberId, Papel papel) {
    return _pb.send(
      '/api/gc_turnkey/team/members/$memberId',
      method: 'PATCH',
      body: {'papel': papel.name},
    );
  }
}
