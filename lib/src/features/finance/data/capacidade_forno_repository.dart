import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../../../core/storage/prefs_locais.dart';
import '../domain/rentabilidade.dart';

/// Onde se guarda (neste aparelho) a capacidade do forno escrita à mão.
const chaveCapacidadeForno = 'forno_capacidade';

/// A média das fornadas só serve se for credível: abaixo disto avisa-se que
/// provavelmente são fornadas de teste ou parciais.
const capacidadeAutoSuspeita = 6;

/// A capacidade do forno a usar: a escrita à mão (se houver) ou a média [auto].
double capacidadeFornoEscolhida(double auto) {
  final manual = double.tryParse(
    (lerPref(chaveCapacidadeForno) ?? '').replaceAll(',', '.').trim(),
  );
  return (manual != null && manual > 0) ? manual : auto;
}

/// Quantas unidades cabem numa fornada, estimado pelas fornadas dos últimos
/// 60 dias (a média do total de cada uma). 0 se ainda não há fornadas.
final capacidadeFornoProvider = FutureProvider.autoDispose<double>((ref) async {
  final pb = ref.watch(pbProvider);
  final empresa = requireEmpresaId(ref);
  final desde = DateTime.now()
      .toUtc()
      .subtract(const Duration(days: 60))
      .toIso8601String()
      .replaceFirst('T', ' ');
  final recs = await pb
      .collection('fornadas')
      .getFullList(
        filter:
            'empresa = "$empresa" && estado != "cancelada" && inicio >= "$desde"',
      );
  final totais = <double>[];
  for (final r in recs) {
    Object? raw = r.data['itens'];
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        raw = jsonDecode(raw);
      } on FormatException {
        raw = null;
      }
    }
    if (raw is! List) continue;
    var soma = 0.0;
    for (final i in raw) {
      if (i is Map && i['quantidade'] is num) {
        soma += (i['quantidade'] as num).toDouble();
      }
    }
    totais.add(soma);
  }
  return capacidadeMediaFornadas(totais);
});
