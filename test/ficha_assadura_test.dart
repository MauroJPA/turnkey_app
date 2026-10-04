import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/mise_en_place/domain/mep_plano.dart';
import 'package:gc_turnkey/src/features/schedule/domain/production_plan.dart';
import 'package:gc_turnkey/src/features/tech_sheets/domain/tech_sheet.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  test('FichaInput envia o tempo de assadura', () {
    final b = FichaInput(nome: 'Cookie', tempoAssaduraMin: 12).toBody();
    expect(b['tempo_assadura_min'], 12);
    expect(FichaInput(nome: 'x').toBody()['tempo_assadura_min'], 0);
  });

  test('FichaTecnica lê o tempo de assadura do registo', () {
    final r = RecordModel({
      'id': 'f1',
      'nome': 'Cookie',
      'tempo_assadura_min': 14,
    });
    final f = FichaTecnica.fromRecord(r);
    expect(f.tempoAssaduraMin, 14);
    expect(f.copyWith(tempoAssaduraMin: 9).tempoAssaduraMin, 9);
    expect(FichaTecnica.fromRecord(RecordModel({'id': 'x'})).tempoAssaduraMin, 0);
  });

  test('os planos de montagem trazem o tempo de assadura', () {
    expect(
      MepPlano.fromJson({'tempoAssaduraMin': 11}).tempoAssaduraMin,
      11,
    );
    expect(MepPlano.fromJson({}).tempoAssaduraMin, 0);
    expect(
      PlanoPorReceita.fromJson({'tempoAssaduraMin': 13}).tempoAssaduraMin,
      13,
    );
  });
}
