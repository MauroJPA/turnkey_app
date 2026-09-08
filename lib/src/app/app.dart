import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/application/empresa_providers.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class TurnkeyApp extends ConsumerWidget {
  const TurnkeyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final empresa = ref.watch(currentEmpresaProvider).valueOrNull;

    // Cor de marca e modo de tema da empresa ativa (com fallback).
    final brand =
        empresa == null ? null : AppTheme.parseHex(empresa.corMarca);
    final modo = empresa?.tema.modo ?? ThemeMode.system;

    return MaterialApp.router(
      title: 'Turnkey',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(brand),
      darkTheme: AppTheme.dark(brand),
      themeMode: modo,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
