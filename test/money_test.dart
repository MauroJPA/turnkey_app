import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/core/formatting/money.dart';

void main() {
  test('roundMoney arredonda sempre para cima a 2 casas', () {
    expect(roundMoney(1.231), 1.24);
    expect(roundMoney(1.230), 1.23);
    expect(roundMoney(0), 0);
  });

  test('formatMoney usa vírgula decimal e símbolo do euro', () {
    expect(formatMoney(1.2), '€1,20');
    expect(formatMoney(1.231), '€1,24');
  });
}
