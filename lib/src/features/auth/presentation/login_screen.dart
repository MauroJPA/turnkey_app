import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _registing = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = ref.read(authControllerProvider.notifier);
      if (_registing) {
        await auth.register(
          email: _email.text.trim(),
          password: _password.text,
          nome: _nome.text.trim(),
        );
      } else {
        await auth.signIn(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
      // A navegação é tratada pelo redirect do router ao mudar o AuthState.
    } on ClientException catch (e) {
      setState(() => _error = _friendlyError(e));
    } on Object catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(ClientException e) {
    final msg = e.response['message']?.toString() ?? e.toString();
    if (msg.contains('Failed to authenticate')) {
      return 'Email ou palavra-passe incorretos.';
    }
    if (e.statusCode == 0) {
      return 'Sem ligação ao servidor.';
    }
    return msg;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Turnkey',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _registing ? 'Criar conta' : 'Entrar',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  if (_registing) ...[
                    TextFormField(
                      controller: _nome,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Nome'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Indica o teu nome'
                          : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) => (v == null || !v.contains('@'))
                        ? 'Email inválido'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _submit(),
                    decoration:
                        const InputDecoration(labelText: 'Palavra-passe'),
                    validator: (v) => (v == null || v.length < 8)
                        ? 'Mínimo 8 caracteres'
                        : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_registing ? 'Criar conta' : 'Entrar'),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _registing = !_registing;
                              _error = null;
                            }),
                    child: Text(
                      _registing
                          ? 'Já tenho conta — entrar'
                          : 'Não tenho conta — criar',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const _SocialButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botões de login social — preparados, ativados numa fase posterior.
class _SocialButtons extends StatelessWidget {
  const _SocialButtons();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'ou',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 8),
        Tooltip(
          message: 'Disponível em breve',
          child: OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.g_mobiledata),
            label: const Text('Continuar com Google'),
          ),
        ),
        const SizedBox(height: 8),
        Tooltip(
          message: 'Disponível em breve',
          child: OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.apple),
            label: const Text('Continuar com Apple'),
          ),
        ),
      ],
    );
  }
}
