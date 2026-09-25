import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/application/empresa_providers.dart';
import '../features/settings/application/font_providers.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class GcTurnkeyApp extends ConsumerWidget {
  const GcTurnkeyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final empresa = ref.watch(currentEmpresaProvider).valueOrNull;
    final fonteFamilia = ref.watch(fonteCarregadaProvider).valueOrNull;

    // Distribuição de cores e modo de tema da empresa ativa (com fallback
    // para a cor de marca sozinha, como antes).
    final brand =
        empresa == null ? null : AppTheme.parseHex(empresa.corMarca);
    final secundaria = empresa == null || empresa.corSecundaria.isEmpty
        ? null
        : AppTheme.parseHex(empresa.corSecundaria);
    final fundo = empresa == null || empresa.corFundo.isEmpty
        ? null
        : AppTheme.parseHex(empresa.corFundo);
    final texto = empresa == null || empresa.corTexto.isEmpty
        ? null
        : AppTheme.parseHex(empresa.corTexto);
    final modo = empresa?.tema.modo ?? ThemeMode.system;

    return MaterialApp.router(
      title: 'gc_turnkey',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(
        brand,
        secundaria: secundaria,
        fundo: fundo,
        texto: texto,
        fontFamily: fonteFamilia,
      ),
      darkTheme: AppTheme.dark(
        brand,
        secundaria: secundaria,
        fundo: fundo,
        texto: texto,
        fontFamily: fonteFamilia,
      ),
      themeMode: modo,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
