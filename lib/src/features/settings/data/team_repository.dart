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

  Future<List<TeamMember>> listMembers() async {
    final recs = await _pb.collection('users').getFullList(
          filter: 'empresa = "$_empresaId"',
          sort: 'nome',
        );
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
      '/api/turnkey/team/members',
      method: 'POST',
      body: {
        'nome': nome,
        'email': email,
        'password': password,
        'papel': papel.name,
      },
    );
  }

  Future<void> changeRole(String memberId, Papel papel) {
    return _pb.send(
      '/api/turnkey/team/members/$memberId',
      method: 'PATCH',
      body: {'papel': papel.name},
    );
  }
}
