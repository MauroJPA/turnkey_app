import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

/// Instância única do cliente PocketBase.
///
/// É construída no arranque da app (`main`) — depois de ler o token de sessão
/// persistido — e injetada aqui via `overrideWithValue`. Nenhum widget deve
/// criar o seu próprio `PocketBase`; o acesso a dados passa sempre pelos
/// repositórios, que dependem deste provider.
final pbProvider = Provider<PocketBase>(
  (ref) => throw StateError(
    'pbProvider tem de ser sobreposto no arranque da app (ver lib/main.dart).',
  ),
);
