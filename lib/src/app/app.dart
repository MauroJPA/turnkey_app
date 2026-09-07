import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/application/empresa_providers.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class TurnkeyApp extends ConsumerWidget {
  const TurnkeyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Cor de marca da empresa ativa (se definida e válida).
    final brand = ref.watch(currentEmpresaProvider).maybeWhen(
          data: (e) =>
              e == null ? null : AppTheme.parseHex(e.corMarca),
          orElse: () => null,
        );

    return MaterialApp.router(
      title: 'Turnkey',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(brand),
      darkTheme: AppTheme.dark(brand),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
