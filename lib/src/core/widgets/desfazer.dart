import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Os itens que o utilizador acabou de apagar e que ainda se podem recuperar
/// ("Desfazer"): as listas escondem-nos (`.where((x) => !ocultos.contains(x.id))`)
/// até o apagar acontecer a sério.
final ocultosProvider = StateProvider<Set<String>>((_) => const {});

const _espera = Duration(seconds: 6);

/// Mostra "[mensagem] · Desfazer" durante uns segundos. Devolve `true` se o
/// utilizador carregou em Desfazer (e já correu [desfazer]).
///
/// Para ações que já se fizeram e têm inverso (mover para a lixeira, arquivar).
Future<bool> mostrarDesfazer(
  BuildContext context, {
  required String mensagem,
  required Future<void> Function() desfazer,
}) => mostrarDesfazerEm(
  ScaffoldMessenger.of(context),
  mensagem: mensagem,
  desfazer: desfazer,
);

/// Como [mostrarDesfazer], para quando o ecrã que pediu já pode ter fechado
/// (guarda-se o `ScaffoldMessenger` antes de esperar).
Future<bool> mostrarDesfazerEm(
  ScaffoldMessengerState messenger, {
  required String mensagem,
  required Future<void> Function() desfazer,
}) async {
  messenger.clearSnackBars();
  final ctrl = messenger.showSnackBar(
    SnackBar(
      content: Text(mensagem),
      duration: _espera,
      persist: false, // com ação, o SnackBar não desaparecia sozinho
      action: SnackBarAction(label: 'Desfazer', onPressed: () {}),
    ),
  );
  final motivo = await ctrl.closed;
  if (motivo != SnackBarClosedReason.action) return false;
  try {
    await desfazer();
  } on Object {
    messenger.showSnackBar(
      const SnackBar(content: Text('Não foi possível desfazer.')),
    );
    return false;
  }
  return true;
}

/// Apaga com "Desfazer" em vez de pedir confirmação: o item some já das
/// listas (via [ocultosProvider]) e só se apaga a sério passados uns segundos,
/// se ninguém carregar em Desfazer. Se a app fechar nesse intervalo, nada se
/// apaga (o lado seguro).
///
/// [apagar] faz o apagar a sério; [depois] atualiza as listas. Erros do
/// [apagar] são entregues a [aoFalhar] (o item volta a aparecer).
Future<void> apagarComDesfazer(
  BuildContext context, {
  required String id,
  required String mensagem,
  required Future<void> Function() apagar,
  required VoidCallback depois,
  void Function(Object erro)? aoFalhar,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final container = ProviderScope.containerOf(context);
  void ocultar(bool sim) {
    final n = container.read(ocultosProvider.notifier);
    n.state = sim
        ? {...n.state, id}
        : {
            for (final x in n.state)
              if (x != id) x,
          };
  }

  ocultar(true);
  messenger.clearSnackBars();
  final ctrl = messenger.showSnackBar(
    SnackBar(
      content: Text(mensagem),
      duration: _espera,
      persist: false, // com ação, o SnackBar não desaparecia sozinho
      action: SnackBarAction(label: 'Desfazer', onPressed: () {}),
    ),
  );
  final motivo = await ctrl.closed;
  if (motivo == SnackBarClosedReason.action) {
    ocultar(false);
    return;
  }
  try {
    await apagar();
    depois();
  } on Object catch (e) {
    aoFalhar?.call(e);
  } finally {
    ocultar(false);
  }
}
