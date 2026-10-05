import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/mise_en_place/domain/mep_plano.dart';
import 'package:gc_turnkey/src/features/schedule/domain/production_plan.dart';
import 'package:gc_turnkey/src/features/tech_sheets/domain/assar_texto.dart';
import 'package:gc_turnkey/src/features/tech_sheets/domain/tech_sheet.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  test('FichaInput envia a temperatura do forno', () {
    final b = FichaInput(nome: 'Cookie', temperaturaFornoC: 170).toBody();
    expect(b['temperatura_forno_c'], 170);
    expect(FichaInput(nome: 'x').toBody()['temperatura_forno_c'], 0);
  });

  test('FichaTecnica lê a temperatura do registo', () {
    final f = FichaTecnica.fromRecord(
      RecordModel({'id': 'x', 'nome': 'Cookie', 'temperatura_forno_c': 180}),
    );
    expect(f.temperaturaFornoC, 180);
    expect(f.copyWith(temperaturaFornoC: 165).temperaturaFornoC, 165);
    expect(
      FichaTecnica.fromRecord(RecordModel({'id': 'x'})).temperaturaFornoC,
      0,
    );
  });

  test('os planos trazem a temperatura', () {
    expect(
      MepPlano.fromJson({'temperaturaFornoC': 170}).temperaturaFornoC,
      170,
    );
    expect(MepPlano.fromJson({}).temperaturaFornoC, 0);
    expect(
      PlanoPorReceita.fromJson({'temperaturaFornoC': 175}).temperaturaFornoC,
      175,
    );
  });

  test('texto de forno', () {
    expect(textoAssar(11, 170), 'Assar a 170 °C durante 11 min');
    expect(textoAssar(11, 0), 'Assar 11 min');
    expect(textoAssar(0, 170), 'Forno a 170 °C');
    expect(textoAssar(0, 0), '');
    expect(textoAssarCurto(11, 170), '170 °C · 11 min');
    expect(textoAssarCurto(0, 170), '170 °C');
    expect(textoAssarCurto(11, 0), '11 min');
  });
}
