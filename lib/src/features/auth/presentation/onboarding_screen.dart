import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../settings/data/empresa_repository.dart';
import '../../settings/domain/empresa.dart';

/// Primeiro acesso: o utilizador cria a sua empresa.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nome = TextEditingController();
  Moeda _moeda = Moeda.eur;
  RegraArredondamento _regra = RegraArredondamento.cima;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(empresaRepositoryProvider).onboard(
            nome: _nome.text.trim(),
            moeda: _moeda,
            regra: _regra,
          );
      await ref.read(authControllerProvider.notifier).reload();
      // O redirect do router leva para a home assim que o AuthState muda.
    } on Object catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('A tua empresa'),
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
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Vamos configurar a tua empresa. Podes mudar tudo depois '
                    'em Configurações.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nome,
                    decoration:
                        const InputDecoration(labelText: 'Nome da empresa'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Indica o nome'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Moeda>(
                    value: _moeda,
                    decoration: const InputDecoration(labelText: 'Moeda'),
                    items: [
                      for (final m in Moeda.values)
                        DropdownMenuItem(
                          value: m,
                          child: Text('${m.code} (${m.symbol})'),
                        ),
                    ],
                    onChanged: (v) => setState(() => _moeda = v ?? Moeda.eur),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<RegraArredondamento>(
                    value: _regra,
                    decoration: const InputDecoration(
                      labelText: 'Arredondamento de preços',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: RegraArredondamento.cima,
                        child: Text('Sempre para cima'),
                      ),
                      DropdownMenuItem(
                        value: RegraArredondamento.normal,
                        child: Text('Normal'),
                      ),
                    ],
                    onChanged: (v) => setState(
                      () => _regra = v ?? RegraArredondamento.cima,
                    ),
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
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _create,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Criar empresa'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
