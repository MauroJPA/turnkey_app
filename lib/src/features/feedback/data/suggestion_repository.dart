import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';

final suggestionRepositoryProvider = Provider<SuggestionRepository>((ref) {
  return SuggestionRepository(
    ref.watch(pbProvider),
    ref.watch(currentEmpresaIdProvider),
  );
});

class SuggestionRepository {
  SuggestionRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String? _empresaId;

  /// Envia uma sugestão/erro. [pagina] é a chave do tópico de ajuda.
  Future<void> enviar({
    required String pagina,
    required String texto,
    String contexto = '',
  }) async {
    await _pb.collection('sugestoes').create(body: {
      if (_empresaId != null) 'empresa': _empresaId,
      if (_pb.authStore.record != null) 'autor': _pb.authStore.record!.id,
      'pagina': pagina,
      'texto': texto.trim(),
      'contexto': contexto,
    });
  }
}
