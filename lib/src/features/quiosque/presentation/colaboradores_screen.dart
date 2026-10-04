import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/device/nfc_leitor.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/help_actions.dart';
import '../../invoices/domain/invoice_erros.dart';
import '../application/colaboradores_providers.dart';
import '../domain/colaborador.dart';

/// Colaboradores do quiosque e os seus cartões NFC.
class ColaboradoresScreen extends ConsumerWidget {
  const ColaboradoresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final podeGerir = ref.watch(currentPapelProvider).canEditConfig;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
        title: const Text('Equipa e cartões'),
        actions: [
          IconButton(
            tooltip: 'Abrir o quiosque de tarefas',
            icon: const Icon(Icons.touch_app_outlined),
            onPressed: () => context.go(Routes.quiosque),
          ),
          const HelpActions(topic: HelpTopic.colaboradores),
        ],
      ),
      floatingActionButton: podeGerir
          ? FloatingActionButton.extended(
              onPressed: () => _novo(context, ref),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Pessoa sem conta'),
            )
          : null,
      body: AsyncValueView<List<Colaborador>>(
        value: ref.watch(todosColaboradoresProvider),
        onRetry: () => ref.invalidate(todosColaboradoresProvider),
        data: (lista) {
          if (lista.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Ainda não há ninguém. A Equipa aparece aqui sozinha; para '
                  'quem não tem conta, usa "Pessoa sem conta".',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
            children: [
              if (!NfcLeitor.suporta)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Este navegador não lê cartões NFC (precisa de Chrome no '
                    'Android e de HTTPS). Podes escrever o número de série à '
                    'mão.',
                  ),
                ),
              for (final c in lista)
                ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      c.nome.isEmpty ? '?' : c.nome.characters.first.toUpperCase(),
                    ),
                  ),
                  title: Text(
                    c.nome,
                    style: c.arquivado
                        ? TextStyle(color: Theme.of(context).disabledColor)
                        : null,
                  ),
                  subtitle: Text(
                    [
                      c.daEquipa ? 'Equipa' : 'Sem conta',
                      if (c.arquivado)
                        'escondido do quiosque'
                      else if (c.temCartao)
                        'cartão associado'
                      else
                        'sem cartão',
                    ].join(' · '),
                  ),
                  trailing: podeGerir
                      ? PopupMenuButton<String>(
                          onSelected: (v) => _acao(context, ref, c, v),
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'cartao',
                              child: Text(
                                c.temCartao ? 'Trocar cartão' : 'Associar cartão',
                              ),
                            ),
                            if (c.temCartao)
                              const PopupMenuItem(
                                value: 'tirar',
                                child: Text('Tirar o cartão'),
                              ),
                            // o nome da Equipa vem da conta (Equipa → Utilizadores)
                            if (!c.daEquipa)
                              const PopupMenuItem(
                                value: 'nome',
                                child: Text('Mudar o nome'),
                              ),
                            PopupMenuItem(
                              value: 'arquivar',
                              child: Text(
                                c.arquivado
                                    ? 'Mostrar no quiosque'
                                    : 'Esconder do quiosque',
                              ),
                            ),
                          ],
                        )
                      : null,
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _novo(BuildContext context, WidgetRef ref) async {
    final nome = await showDialog<String>(
      context: context,
      builder: (_) => const _NomeDialog(titulo: 'Novo colaborador'),
    );
    if (nome == null) return;
    if (!context.mounted) return;
    await _tentar(context, () => ref.read(colaboradoresActionsProvider).criar(nome));
  }

  Future<void> _acao(
    BuildContext context,
    WidgetRef ref,
    Colaborador c,
    String acao,
  ) async {
    final acoes = ref.read(colaboradoresActionsProvider);
    switch (acao) {
      case 'nome':
        final n = await showDialog<String>(
          context: context,
          builder: (_) =>
              _NomeDialog(titulo: 'Mudar o nome', inicial: c.nome),
        );
        if (n == null || !context.mounted) return;
        await _tentar(context, () => acoes.renomear(c, n));
      case 'cartao':
        final uid = await showDialog<String>(
          context: context,
          builder: (_) => _CartaoDialog(nome: c.nome),
        );
        if (uid == null || !context.mounted) return;
        await _tentar(context, () => acoes.definirCartao(c, uid));
      case 'tirar':
        final ok = await confirmDialog(
          context,
          titulo: 'Tirar o cartão',
          mensagem: '${c.nome} deixa de poder usar este cartão no quiosque.',
          confirmar: 'Tirar',
        );
        if (!ok || !context.mounted) return;
        await _tentar(context, () => acoes.definirCartao(c, ''));
      case 'arquivar':
        await _tentar(
          context,
          () => acoes.arquivar(c, arquivado: !c.arquivado),
        );
    }
  }

  Future<void> _tentar(BuildContext context, Future<void> Function() f) async {
    try {
      await f();
    } on Object catch (e) {
      if (!context.mounted) return;
      final texto = '$e'.contains('nfc_uid') || '$e'.contains('unique')
          ? 'Esse cartão já está associado a outra pessoa.'
          : mensagemAmigavel(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
    }
  }
}

class _NomeDialog extends StatefulWidget {
  const _NomeDialog({required this.titulo, this.inicial = ''});
  final String titulo;
  final String inicial;

  @override
  State<_NomeDialog> createState() => _NomeDialogState();
}

class _NomeDialogState extends State<_NomeDialog> {
  late final _ctrl = TextEditingController(text: widget.inicial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        maxLength: 80,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Nome'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final n = _ctrl.text.trim();
            if (n.isNotEmpty) Navigator.pop(context, n);
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

/// Lê o cartão (encostado ao telemóvel) ou aceita o número de série escrito.
class _CartaoDialog extends StatefulWidget {
  const _CartaoDialog({required this.nome});
  final String nome;

  @override
  State<_CartaoDialog> createState() => _CartaoDialogState();
}

class _CartaoDialogState extends State<_CartaoDialog> {
  final _manual = TextEditingController();
  String? _aviso;
  bool _aLer = false;

  @override
  void initState() {
    super.initState();
    if (NfcLeitor.suporta) {
      _aLer = true;
      NfcLeitor.iniciar(
        aoLer: (serie) {
          final uid = normalizarUid(serie);
          if (uid.isNotEmpty && mounted) Navigator.pop(context, uid);
        },
        aoErro: (m) {
          if (mounted) {
            setState(() {
              _aLer = false;
              _aviso = m;
            });
          }
        },
      );
    }
  }

  @override
  void dispose() {
    NfcLeitor.parar();
    _manual.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text('Cartão de ${widget.nome}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_aLer) ...[
              Icon(Icons.nfc, size: 72, color: cs.primary),
              const SizedBox(height: 8),
              const Text(
                'Encosta o cartão à parte de trás do telemóvel…',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
            if (_aviso != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_aviso!, style: TextStyle(color: cs.error)),
              ),
            TextField(
              controller: _manual,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Ou escreve o número de série',
                helperText: 'Ex.: 04:A1:B2:C3:D4:E5:F6',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final uid = normalizarUid(_manual.text);
            if (uid.length < 4) {
              setState(() => _aviso = 'Número de série inválido.');
              return;
            }
            Navigator.pop(context, uid);
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
