import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import 'src/app/app.dart';
import 'src/core/env/env.dart';
import 'src/core/pocketbase/pb_client.dart';
import 'src/core/pocketbase/session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Restaura a sessão persistida antes de construir a app.
  final sessionStore = SessionStore();
  final initialToken = await sessionStore.readInitial();
  final pb = PocketBase(
    Env.pbUrl,
    authStore: sessionStore.build(initialToken),
  );

  runApp(
    ProviderScope(
      overrides: [pbProvider.overrideWithValue(pb)],
      child: const TurnkeyApp(),
    ),
  );
}
