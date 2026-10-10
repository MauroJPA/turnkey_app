import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/cores_estado.dart';
import '../../../core/errors/mensagem_amigavel.dart';
import '../data/telegram_pessoal_repository.dart';

/// Abre o ecrã "Menções no Telegram" (ligar/desligar o meu Telegram).
Future<void> abrirTelegramPessoal(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const TelegramPessoalSheet(),
    );

/// Liga o Telegram da própria pessoa: abre o bot com um código e espera que
/// ela carregue em "Iniciar". Depois disso, as menções chegam-lhe lá.
class TelegramPessoalSheet extends ConsumerStatefulWidget {
  const TelegramPessoalSheet({super.key});

  @override
  ConsumerState<TelegramPessoalSheet> createState() =>
      _TelegramPessoalSheetState();
}

class _TelegramPessoalSheetState extends ConsumerState<TelegramPessoalSheet> {
  bool _aEsperar = false;
  bool _ocupado = false;
  String? _erro;
  Timer? _sondagem;
  int _tentativas = 0;

  TelegramPessoalRepository get _repo =>
      ref.read(telegramPessoalRepositoryProvider);

  @override
  void dispose() {
    _sondagem?.cancel();
    super.dispose();
  }

  Future<void> _ligar() async {
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      final link = await _repo.pedirLink();
      if (link.isEmpty) throw StateError('sem link');
      await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
      if (!mounted) return;
      setState(() => _aEsperar = true);
      _tentativas = 0;
      _sondagem?.cancel();
      // de 4 em 4 s, durante 3 minutos, vê se já carregou em "Iniciar"
      _sondagem = Timer.periodic(const Duration(seconds: 4), (t) async {
        _tentativas++;
        if (_tentativas > 45) {
          t.cancel();
          if (mounted) setState(() => _aEsperar = false);
          return;
        }
        try {
          if (await _repo.verificar()) {
            t.cancel();
            ref.invalidate(telegramPessoalProvider);
            if (mounted) setState(() => _aEsperar = false);
          }
        } on Object {
          // tenta outra vez a seguir
        }
      });
    } on Object catch (e) {
      if (mounted) setState(() => _erro = mensagemAmigavel(e));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _fazer(Future<void> Function() f, String ok) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _ocupado = true);
    try {
      await f();
      messenger.showSnackBar(SnackBar(content: Text(ok)));
    } on Object catch (e) {
      if (mounted) setState(() => _erro = mensagemAmigavel(e));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final estado = ref.watch(telegramPessoalProvider);
    final e = estado.valueOrNull;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.send_outlined, color: cs.primary),
                const SizedBox(width: 8),
                Text('Menções no Telegram', style: tt.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Quando alguém te mencionar num comentário (@o teu nome), '
              'recebes logo uma mensagem no teu Telegram.',
              style: tt.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (e == null && estado.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (e != null && e.ligado) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.check_circle, color: cs.sucesso),
                title: const Text('O teu Telegram está ligado'),
                subtitle: e.nome.isEmpty ? null : Text('Conta: ${e.nome}'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('Enviar uma mensagem de teste'),
                onPressed: _ocupado
                    ? null
                    : () => _fazer(
                        _repo.testar,
                        'Mensagem enviada: vê o teu Telegram.',
                      ),
              ),
              TextButton(
                onPressed: _ocupado
                    ? null
                    : () => _fazer(() async {
                        await _repo.desligar(e.id);
                        ref.invalidate(telegramPessoalProvider);
                      }, 'Telegram desligado.'),
                child: const Text('Desligar'),
              ),
            ] else if (_aEsperar) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 12),
              Text(
                'No Telegram, carrega em "Iniciar" (ou "Start") na conversa '
                'com o bot. Esta janela fica à espera e confirma sozinha.',
                textAlign: TextAlign.center,
                style: tt.bodyMedium,
              ),
              TextButton(
                onPressed: _ocupado ? null : _ligar,
                child: const Text('Abrir o Telegram outra vez'),
              ),
            ] else ...[
              FilledButton.icon(
                icon: const Icon(Icons.link),
                label: const Text('Ligar o meu Telegram'),
                onPressed: _ocupado ? null : _ligar,
              ),
              const SizedBox(height: 8),
              Text(
                'Abre o bot da loja no Telegram; carrega em "Iniciar" e fica '
                'ligado. Só tens de fazer isto uma vez.',
                style: tt.bodySmall,
              ),
            ],
            if (_erro != null) ...[
              const SizedBox(height: 12),
              Text(_erro!, style: tt.bodyMedium?.copyWith(color: cs.error)),
            ],
          ],
        ),
      ),
    );
  }
}
