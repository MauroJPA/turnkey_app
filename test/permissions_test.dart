import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/core/auth/permissions.dart';

void main() {
  test('fromName é tolerante e cai em viewer', () {
    expect(Papel.fromName('owner'), Papel.owner);
    expect(Papel.fromName('desconhecido'), Papel.viewer);
    expect(Papel.fromName(null), Papel.viewer);
  });

  test('capacidades por papel', () {
    expect(Papel.viewer.canEditBusiness, isFalse);
    expect(Papel.editor.canEditBusiness, isTrue);
    expect(Papel.editor.canEditConfig, isFalse);
    expect(Papel.admin.canManageTeam, isTrue);
    expect(Papel.owner.isOwner, isTrue);
  });
}
