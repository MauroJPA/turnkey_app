import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../domain/rentabilidade.dart';

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
