import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/errors/mensagem_amigavel.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/help_actions.dart';
import '../data/avisos_repository.dart';

/// Avisos e resumo diário: o que pede atenção hoje, enviado todos os dias à
/// hora que escolheres, por email e/ou Telegram.
class AvisosScreen extends ConsumerWidget {
  const AvisosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(avisosConfigProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.settings),
        ),
        title: const Text('Avisos e resumo diário'),
        actions: const [HelpActions(topic: HelpTopic.avisos)],
      ),
      body: AsyncValueView<AvisosConfig>(
        value: async,
        onRetry: () => ref.invalidate(avisosConfigProvider),
        data: (c) => _Formulario(inicial: c),
      ),
    );
  }
}

class _Formulario extends ConsumerStatefulWidget {
  const _Formulario({required this.inicial});
  final AvisosConfig inicial;

  @override
  ConsumerState<_Formulario> createState() => _FormularioState();
}

class _FormularioState extends ConsumerState<_Formulario> {
  late AvisosConfig _c = widget.inicial;
  late final _emails = TextEditingController(text: widget.inicial.emailPara);
  late final _chat = TextEditingController(text: widget.inicial.telegramChat);
  final _token = TextEditingController();
  bool _busy = false;
  String? _erro;
  List<ChatTelegram> _chats = const [];

  @override
  void dispose() {
    _emails.dispose();
    _chat.dispose();
    _token.dispose();
    super.dispose();
  }

  AvisosConfig get _atual =>
      _c.copyWith(emailPara: _emails.text, telegramChat: _chat.text);

  Future<void> _run(Future<void> Function() acao, {String? ok}) async {
    setState(() {
      _busy = true;
      _erro = null;
    });
    try {
      await acao();
      if (ok != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok)));
      }
    } on Object catch (e) {
      if (mounted) setState(() => _erro = mensagemAmigavel(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _guardar() => _run(() async {
    final novo = await ref.read(avisosRepositoryProvider).guardar(_atual);
    ref.invalidate(avisosConfigProvider);
    if (mounted) setState(() => _c = novo);
  }, ok: 'Avisos guardados.');

  Future<void> _testar() async {
    await _guardar();
    if (_erro != null || !mounted) return;
    setState(() {
      _busy = true;
      _erro = null;
    });
    try {
      final r = await ref
          .read(avisosRepositoryProvider)
          .testar(enviar: _atual.emailAtivo || _atual.telegramAtivo);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            r.resultados.isEmpty ? 'Pré-visualização' : 'Teste enviado',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final e in r.resultados.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '${e.key == 'email' ? 'Email' : 'Telegram'}: '
                      '${e.value.isEmpty ? 'enviado ✓' : e.value}',
                      style: TextStyle(
                        color: e.value.isEmpty
                            ? null
                            : Theme.of(ctx).colorScheme.error,
                      ),
                    ),
                  ),
                if (r.resultados.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Liga o email ou o Telegram para receberes isto.',
                    ),
                  ),
                const Divider(),
                Text(r.texto),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } on Object catch (e) {
      if (mounted) setState(() => _erro = mensagemAmigavel(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _escolherHora() async {
    final p = _c.hora.split(':');
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(p.first) ?? 8,
        minute: int.tryParse(p.last) ?? 0,
      ),
    );
    if (t == null) return;
    String dois(int n) => n.toString().padLeft(2, '0');
    setState(() => _c = _c.copyWith(hora: '${dois(t.hour)}:${dois(t.minute)}'));
  }

  Future<void> _guardarToken() => _run(() async {
    await ref.read(avisosRepositoryProvider).guardarTokenTelegram(_token.text);
    _token.clear();
    ref.invalidate(estadoTelegramProvider);
  }, ok: 'Token do Telegram guardado (cifrado).');

  Future<void> _detetar() => _run(() async {
    final chats = await ref.read(avisosRepositoryProvider).detetarChats();
    if (!mounted) return;
    setState(() => _chats = chats);
    if (chats.isEmpty) {
      throw Exception(
        'Ainda não vi nenhuma conversa. Abre o teu bot no Telegram e envia /start.',
      );
    }
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final tg = ref.watch(estadoTelegramProvider).valueOrNull;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(
          'Recebe todos os dias, à hora que quiseres, o que pede atenção: '
          'HACCP por fazer, stock baixo, pagamentos, faturas e preços que '
          'subiram, e quem está ausente. Não envia nos dias de folga da empresa '
          '(Configurações → Dias de trabalho).',
          style: tt.bodyMedium,
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Enviar o resumo todos os dias'),
          value: _c.ativo,
          onChanged: (v) => setState(() => _c = _c.copyWith(ativo: v)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule),
          title: const Text('Hora do envio'),
          subtitle: const Text('Hora de Lisboa'),
          trailing: Text(_c.hora, style: tt.titleLarge),
          onTap: _escolherHora,
        ),
        const Divider(),
        Text('O que incluir', style: tt.titleSmall),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('HACCP por fazer'),
          value: _c.incHaccp,
          onChanged: (v) => setState(() => _c = _c.copyWith(incHaccp: v)),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Stock baixo'),
          value: _c.incStock,
          onChanged: (v) => setState(() => _c = _c.copyWith(incStock: v)),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Pagamentos próximos'),
          value: _c.incPagamentos,
          onChanged: (v) => setState(() => _c = _c.copyWith(incPagamentos: v)),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Faturas por rever'),
          value: _c.incFaturas,
          onChanged: (v) => setState(() => _c = _c.copyWith(incFaturas: v)),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Preços que subiram'),
          value: _c.incPrecos,
          onChanged: (v) => setState(() => _c = _c.copyWith(incPrecos: v)),
        ),
        const Divider(),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Por Telegram'),
          subtitle: const Text('Grátis e instantâneo'),
          value: _c.telegramAtivo,
          onChanged: (v) => setState(() => _c = _c.copyWith(telegramAtivo: v)),
        ),
        if (_c.telegramAtivo) ...[
          Text(
            '1) No Telegram, fala com @BotFather → /newbot e copia o token.\n'
            '2) Cola-o aqui e guarda.\n'
            '3) Abre o teu bot e envia /start.\n'
            '4) Toca em "Detetar o meu chat".',
            style: tt.bodySmall,
          ),
          const SizedBox(height: 8),
          if (tg != null && tg.cifraOk == false)
            Text(
              'O servidor ainda não tem a chave de cifra (ver Integrações).',
              style: tt.bodySmall?.copyWith(color: cs.error),
            ),
          if (tg?.configurada ?? false)
            Row(
              children: [
                const Icon(Icons.lock_outline, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Token guardado'
                    '${tg!.sufixo.isEmpty ? '' : ' (termina em ${tg.sufixo})'}',
                  ),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          await ref
                              .read(avisosRepositoryProvider)
                              .removerTokenTelegram();
                          ref.invalidate(estadoTelegramProvider);
                        }),
                  child: const Text('Remover'),
                ),
              ],
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _token,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Token do bot',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: _busy || _token.text.trim().length < 8
                    ? null
                    : _guardarToken,
                child: const Text('Guardar'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chat,
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(
                    labelText: 'Chat',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: _busy ? null : _detetar,
                child: const Text('Detetar o meu chat'),
              ),
            ],
          ),
          if (_chats.isNotEmpty)
            Wrap(
              spacing: 8,
              children: [
                for (final c in _chats)
                  ActionChip(
                    label: Text(c.nome),
                    onPressed: () => setState(() => _chat.text = c.id),
                  ),
              ],
            ),
        ],
        const Divider(height: 28),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Por email'),
          subtitle: const Text('Precisa do email do servidor configurado'),
          value: _c.emailAtivo,
          onChanged: (v) => setState(() => _c = _c.copyWith(emailAtivo: v)),
        ),
        if (_c.emailAtivo)
          TextField(
            controller: _emails,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Enviar para (separa vários com vírgula)',
              isDense: true,
            ),
          ),
        if (_c.ultimoEnvio.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Último envio: ${_c.ultimoEnvio}'
              '${_c.ultimoResultado.isEmpty ? '' : ' — ${_c.ultimoResultado}'}',
              style: tt.bodySmall,
            ),
          ),
        if (_erro != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_erro!, style: TextStyle(color: cs.error)),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: _busy ? null : _testar,
                child: Text(
                  _c.telegramAtivo || _c.emailAtivo
                      ? 'Enviar um teste'
                      : 'Ver pré-visualização',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: _busy ? null : _guardar,
                child: Text(_busy ? 'A guardar…' : 'Guardar'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
