import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/permissions.dart';

part 'team_member.freezed.dart';

@freezed
class TeamMember with _$TeamMember {
  const factory TeamMember({
    required String id,
    required String nome,
    required String email,
    required Papel papel,
  }) = _TeamMember;

  const TeamMember._();

  factory TeamMember.fromRecord(RecordModel r) => TeamMember(
        id: r.id,
        nome: r.getStringValue('nome'),
        email: r.getStringValue('email'),
        papel: Papel.fromName(r.getStringValue('papel')),
      );
}
