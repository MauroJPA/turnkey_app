import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pocketbase/pb_client.dart';
import '../domain/etiqueta.dart';

/// Definições de etiqueta guardadas para um produto (ficha técnica).
final etiquetaPrefsProvider = FutureProvider.autoDispose
    .family<EtiquetaPrefs, String>((ref, fichaId) async {
      final r = await ref
          .watch(pbProvider)
          .collection('fichas_tecnicas')
          .getOne(fichaId, fields: 'id,etiqueta_config');
      return EtiquetaPrefs.fromJson(r.data['etiqueta_config']);
    });

/// Guarda as definições usadas como predefinido deste produto. Falhas (por
/// exemplo, papel só de leitura) não interrompem a impressão.
Future<void> guardarEtiquetaPrefs(
  WidgetRef ref,
  String fichaId,
  EtiquetaPrefs prefs,
) async {
  try {
    await ref
        .read(pbProvider)
        .collection('fichas_tecnicas')
        .update(fichaId, body: {'etiqueta_config': prefs.toJson()});
    ref.invalidate(etiquetaPrefsProvider(fichaId));
  } on Object {
    // sem permissão ou sem rede: imprime na mesma
  }
}
