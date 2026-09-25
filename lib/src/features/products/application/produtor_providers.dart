import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';

/// Nome e morada do produtor impressos nas etiquetas (`empresas.rotulo_produtor`).
final produtorRotuloProvider = FutureProvider.autoDispose<String>((ref) async {
  final empresaId = ref.watch(currentEmpresaIdProvider);
  if (empresaId == null) return '';
  final r = await ref
      .watch(pbProvider)
      .collection('empresas')
      .getOne(empresaId);
  return r.getStringValue('rotulo_produtor');
});

/// Guarda o produtor da empresa (só o owner tem permissão no servidor).
Future<void> guardarProdutorRotulo(WidgetRef ref, String texto) async {
  final empresaId = ref.read(currentEmpresaIdProvider);
  if (empresaId == null) return;
  await ref
      .read(pbProvider)
      .collection('empresas')
      .update(empresaId, body: {'rotulo_produtor': texto.trim()});
  ref.invalidate(produtorRotuloProvider);
}
