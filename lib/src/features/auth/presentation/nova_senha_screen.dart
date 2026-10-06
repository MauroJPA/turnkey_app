import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/errors/mensagem_amigavel.dart';
import '../../settings/domain/acesso_equipa.dart';

/// Depois de entrar com uma palavra-passe provisória (reposta pelo
/// proprietário/administrador), a pessoa tem de escolher uma nova antes de
/// usar a app. No fim volta ao início de sessão para entrar com a nova.
class NovaSenhaScreen extends ConsumerStatefulWidget {
  const NovaSenhaScreen({super.key});

  @override
  ConsumerState<NovaSenhaScreen> createState() => _NovaSenhaScreenState();
}

class _NovaSenhaScreenState extends ConsumerState<NovaSenhaScreen> {
  final _nova = TextEditingController();
  final _confirmar = TextEditingController();
  bool _busy = false;
  bool _ver = false;
  String? _erro;

  @override
  void dispose() {
    _nova.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final problema = validarSenhaNova(_nova.text, _confirmar.text);
    if (problema != null) {
      setState(() => _erro = problema);
      return;
    }
    setState(() {
      _busy = true;
      _erro = null;
    });
    try {
      await ref.read(authRepositoryProvider).definirSenhaNova(_nova.text);
      // a palavra-passe mudou: as sessões fecham-se, entra-se de novo
      ref
          .read(authControllerProvider.notifier)
          .signOut(message: 'Palavra-passe alterada. Entra com a nova.');
    } on Object catch (e) {
      if (mounted) setState(() => _erro = mensagemAmigavel(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escolhe a tua palavra-passe'),
        actions: [
          TextButton(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            child: const Text('Sair'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.lock_reset,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Entraste com uma palavra-passe provisória. Escolhe agora a '
                  'tua, só tua, antes de continuar.',
                  textAlign: TextAlign.center,
                  style: tt.bodyMedium,
                ),
                const SizedBox(height: 20),
                TextField(
                  key: const ValueKey('senha-nova'),
                  controller: _nova,
                  obscureText: !_ver,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Palavra-passe nova',
                    helperText: 'Pelo menos 8 caracteres',
                    suffixIcon: IconButton(
                      tooltip: _ver ? 'Esconder' : 'Mostrar',
                      icon: Icon(
                        _ver ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(() => _ver = !_ver),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('senha-confirmar'),
                  controller: _confirmar,
                  obscureText: !_ver,
                  autofillHints: const [AutofillHints.newPassword],
                  onSubmitted: (_) => _guardar(),
                  decoration: const InputDecoration(
                    labelText: 'Repete a palavra-passe nova',
                  ),
                ),
                if (_erro != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _erro!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _guardar,
                  child: _busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar palavra-passe'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
