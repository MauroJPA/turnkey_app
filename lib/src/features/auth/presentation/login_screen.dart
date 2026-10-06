import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/errors/mensagem_amigavel.dart';

/// Provedores OAuth2 ativos no servidor (ex.: `['google']`).
final _oauthProvidersProvider = FutureProvider.autoDispose<List<String>>(
  (ref) => ref.read(authRepositoryProvider).enabledOAuthProviders(),
);

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
  final _codigo = TextEditingController();

  /// Verificação em 2 passos: passos do código enviado por email.
  String? _mfaId;
  String? _otpId;

  bool _registing = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _password.dispose();
    _codigo.dispose();
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
        final mfaId = await auth.signIn(
          email: _email.text.trim(),
          password: _password.text,
        );
        if (mfaId != null) {
          // Administradores: falta o código de 6 dígitos que vai por email.
          _mfaId = mfaId;
          await _enviarCodigo();
        }
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

  Future<void> _enviarCodigo() async {
    _otpId = await ref
        .read(authControllerProvider.notifier)
        .pedirCodigo(_email.text.trim());
    _codigo.clear();
  }

  Future<void> _reenviar() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _enviarCodigo();
    } on Object catch (e) {
      _error = mensagemAmigavel(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmarCodigo() async {
    final codigo = _codigo.text.trim();
    if (codigo.length < 6 || _otpId == null || _mfaId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .entrarComCodigo(otpId: _otpId!, codigo: codigo, mfaId: _mfaId!);
    } on ClientException catch (e) {
      _error = e.statusCode == 400
          ? 'Código errado ou expirado. Confirma o email mais recente ou pede outro.'
          : _friendlyError(e);
    } on Object catch (e) {
      _error = mensagemAmigavel(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _voltar() => setState(() {
    _mfaId = null;
    _otpId = null;
    _error = null;
    _password.clear();
  });

  List<Widget> _passoCodigo(BuildContext context) {
    return [
      Text(
        'Verificação em 2 passos',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      Text(
        'Enviámos um código de 6 dígitos para ${_email.text.trim()}. '
        'Demora uns segundos (vê também o lixo eletrónico).',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _codigo,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall,
        autofillHints: const [AutofillHints.oneTimeCode],
        onChanged: (v) {
          if (v.length == 6 && !_busy) _confirmarCodigo();
        },
        onSubmitted: (_) => _confirmarCodigo(),
        decoration: const InputDecoration(labelText: 'Código'),
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      const SizedBox(height: 20),
      FilledButton(
        onPressed: _busy ? null : _confirmarCodigo,
        child: _busy
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Confirmar'),
      ),
      TextButton(
        onPressed: _busy ? null : _reenviar,
        child: const Text('Enviar outro código'),
      ),
      TextButton(
        onPressed: _busy ? null : _voltar,
        child: const Text('Voltar'),
      ),
    ];
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
                    'gc_turnkey',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  if (_mfaId != null) ...[
                    const SizedBox(height: 16),
                    ..._passoCodigo(context),
                  ] else ...[
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
                      decoration: const InputDecoration(
                        labelText: 'Palavra-passe',
                      ),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botões de login social. Ficam ativos automaticamente quando o provedor
/// respetivo for configurado no PocketBase (ver `pb/OAUTH.md`).
class _SocialButtons extends ConsumerStatefulWidget {
  const _SocialButtons();

  @override
  ConsumerState<_SocialButtons> createState() => _SocialButtonsState();
}

class _SocialButtonsState extends ConsumerState<_SocialButtons> {
  String? _busy;

  Future<void> _oauth(String provider) async {
    setState(() => _busy = provider);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .signInWithProvider(provider);
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ativos = ref.watch(_oauthProvidersProvider).valueOrNull ?? const [];

    Widget botao(String provider, IconData icon, String label) {
      final disponivel = ativos.contains(provider);
      final btn = OutlinedButton.icon(
        onPressed: (disponivel && _busy == null)
            ? () => _oauth(provider)
            : null,
        icon: _busy == provider
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
        label: Text(label),
      );
      return disponivel
          ? btn
          : Tooltip(message: 'Configurar no servidor primeiro', child: btn);
    }

    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('ou', style: Theme.of(context).textTheme.bodySmall),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 8),
        botao('google', Icons.g_mobiledata, 'Continuar com Google'),
        // "Continuar com Apple" desativado por agora.
      ],
    );
  }
}
