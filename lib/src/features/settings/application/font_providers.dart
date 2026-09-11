import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../data/empresa_repository.dart';
import 'empresa_providers.dart';

/// Nome da família de letra (para `ThemeData.fontFamily`) depois de carregado
/// o tipo de letra personalizado da empresa (Configurações → Aparência →
/// Tipo de letra). `null` enquanto não há tipo de letra personalizado — a
/// app usa a fonte do sistema.
final fonteCarregadaProvider = FutureProvider<String?>((ref) async {
  final empresa = await ref.watch(currentEmpresaProvider.future);
  if (empresa == null || !empresa.temFontePersonalizada) return null;

  final url = ref.watch(empresaRepositoryProvider).fonteUrl(empresa);
  if (url.isEmpty) return null;

  final familia =
      empresa.fonteFamilia.isNotEmpty ? empresa.fonteFamilia : 'EmpresaFonte';
  try {
    final resposta = await http.get(Uri.parse(url));
    if (resposta.statusCode != 200) return null;
    await ui.loadFontFromList(resposta.bodyBytes, fontFamily: familia);
    return familia;
  } on Object {
    return null;
  }
});
