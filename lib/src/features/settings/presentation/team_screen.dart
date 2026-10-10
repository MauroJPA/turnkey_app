import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/errors/mensagem_amigavel.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/help_actions.dart';
import '../../navigation/application/navigation_providers.dart';
import '../../navigation/domain/papel_personalizado.dart';
import '../application/settings_providers.dart';
import '../data/team_repository.dart';
import '../domain/acesso_equipa.dart';
import '../domain/team_member.dart';

class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({super.key});

  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addMember() async {
    final result = await showModalBottomSheet<_NewMember>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _AddMemberSheet(),
    );
    if (result == null) return;
    await _run(
      () => ref
          .read(settingsActionsProvider)
          .addMember(
            nome: result.nome,
            email: result.email,
            password: result.password,
            papel: result.escolha.papel,
            papelPersonalizado: result.escolha.personalizado,
          ),
    );
  }

  Future<void> _changeRole(TeamMember m) async {
    final perso = ref.read(papeisDosMembrosProvider).valueOrNull ?? const {};
    final atual = (papel: m.papel, personalizado: perso[m.id] ?? '');
    final meus = papeisQuePossoDar(
      ref.read(currentPapelProvider),
      ref.read(papeisPersonalizadosProvider).valueOrNull ?? const [],
    );
    final novo = await showDialog<EscolhaPapel>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Papel de ${m.nome.isEmpty ? m.email : m.nome}'),
        children: [
          RadioGroup<EscolhaPapel>(
            groupValue: atual,
            onChanged: (v) => Navigator.pop(ctx, v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final p in Papel.values)
                  RadioListTile<EscolhaPapel>(
                    value: (papel: p, personalizado: ''),
                    title: Text(p.label),
                  ),
                // o proprietário tem sempre acesso total
                if (m.papel != Papel.owner && meus.isNotEmpty) ...[
                  const Divider(),
                  for (final p in meus)
                    RadioListTile<EscolhaPapel>(
                      value: (papel: p.base, personalizado: p.id),
                      secondary: const Icon(Icons.badge_outlined),
                      title: Text(p.nome),
                      subtitle: Text('Parte de ${p.base.label}'),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    if (novo == null || novo == atual) return;
    await _run(
      () => ref
          .read(settingsActionsProvider)
          .changeRole(m.id, novo.papel, personalizado: novo.personalizado),
    );
  }

  String _nomeDe(TeamMember m) => m.nome.isEmpty ? m.email : m.nome;

  /// Repõe a palavra-passe: o servidor gera uma provisória que se mostra uma
  /// só vez, para dar à pessoa (copiar ou mandar a mensagem pronta).
  Future<void> _reporSenha(TeamMember m) async {
    final ok = await confirmDialog(
      context,
      titulo: 'Repor a palavra-passe de ${_nomeDe(m)}?',
      mensagem:
          'É gerada uma palavra-passe provisória, que vais ver uma só vez. A '
          'sessão que ${_nomeDe(m)} tenha aberta fecha-se e, ao entrar com a '
          'provisória, escolhe logo uma nova.',
      confirmar: 'Repor',
    );
    if (!ok || !mounted) return;
    String? senha;
    await _run(() async {
      senha = await ref.read(settingsActionsProvider).resetPassword(m.id);
    });
    if (senha == null || senha!.isEmpty || !mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Palavra-passe provisória'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Para ${_nomeDe(m)} — só aparece agora:'),
            const SizedBox(height: 12),
            Center(
              child: SelectableText(
                senha!,
                key: const ValueKey('senha-provisoria'),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Ao entrar com ela, a pessoa escolhe uma palavra-passe nova.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: senha!));
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Palavra-passe copiada.')),
                );
              }
            },
            child: const Text('Copiar'),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: mensagemSenhaProvisoria(m.nome, senha!)),
              );
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Mensagem copiada.')),
                );
              }
            },
            child: const Text('Copiar mensagem'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Feito'),
          ),
        ],
      ),
    );
  }

  Future<void> _remover(TeamMember m) async {
    final ok = await confirmDialog(
      context,
      titulo: 'Remover ${_nomeDe(m)} da equipa?',
      mensagem:
          '${_nomeDe(m)} deixa de poder entrar na app e o cartão do quiosque '
          'desaparece. O que registou (ponto, férias, faturas…) mantém-se.',
      confirmar: 'Remover',
      destrutivo: true,
    );
    if (!ok) return;
    await _run(() async {
      await ref.read(settingsActionsProvider).removeMember(m.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_nomeDe(m)} saiu da equipa.')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(teamMembersProvider);
    final persoDosMembros =
        ref.watch(papeisDosMembrosProvider).valueOrNull ?? const {};
    final papeis =
        ref.watch(papeisPersonalizadosProvider).valueOrNull ??
        const <PapelPersonalizado>[];
    final meuPapel = ref.watch(currentPapelProvider);
    final meuId = ref.read(teamRepositoryProvider).utilizadorId;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.settings),
        ),
        title: const Text('Equipa'),
        actions: const [HelpActions(topic: HelpTopic.equipa)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _addMember,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Adicionar'),
      ),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            child: AsyncValueView<List<TeamMember>>(
              value: membersAsync,
              onRetry: () => ref.invalidate(teamMembersProvider),
              data: (members) => ListView.separated(
                itemCount: members.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final m = members[i];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        (m.nome.isEmpty ? m.email : m.nome).characters.first
                            .toUpperCase(),
                      ),
                    ),
                    title: Text(m.nome.isEmpty ? m.email : m.nome),
                    subtitle: Text(m.email),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Chip(
                          label: Text(
                            papeis
                                    .where((p) => p.id == persoDosMembros[m.id])
                                    .firstOrNull
                                    ?.nome ??
                                m.papel.label,
                          ),
                        ),
                        if (podeGerirAcesso(
                          eu: meuPapel,
                          alvo: m.papel,
                          souEu: m.id == meuId,
                        ))
                          PopupMenuButton<String>(
                            key: ValueKey('membro-menu-${m.id}'),
                            tooltip: 'Mais ações',
                            enabled: !_busy,
                            onSelected: (v) {
                              switch (v) {
                                case 'papel':
                                  _changeRole(m);
                                case 'senha':
                                  _reporSenha(m);
                                case 'remover':
                                  _remover(m);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'papel',
                                child: ListTile(
                                  leading: Icon(Icons.badge_outlined),
                                  title: Text('Mudar o papel'),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'senha',
                                child: ListTile(
                                  leading: Icon(Icons.lock_reset),
                                  title: Text('Repor a palavra-passe'),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'remover',
                                child: ListTile(
                                  leading: Icon(Icons.person_remove_outlined),
                                  title: Text('Remover da equipa'),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    onTap: () => _changeRole(m),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewMember {
  _NewMember(this.nome, this.email, this.password, this.escolha);
  final String nome;
  final String email;
  final String password;
  final EscolhaPapel escolha;
}

class _AddMemberSheet extends ConsumerStatefulWidget {
  const _AddMemberSheet();

  @override
  ConsumerState<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends ConsumerState<_AddMemberSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  EscolhaPapel _papel = (papel: Papel.editor, personalizado: '');

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _NewMember(_nome.text.trim(), _email.text.trim(), _password.text, _papel),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Novo membro', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nome,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email *'),
              validator: (v) =>
                  (v == null || !v.contains('@')) ? 'Email inválido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              decoration: const InputDecoration(
                labelText: 'Palavra-passe provisória *',
              ),
              validator: (v) =>
                  (v == null || v.length < 8) ? 'Mínimo 8 caracteres' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<EscolhaPapel>(
              initialValue: _papel,
              decoration: const InputDecoration(labelText: 'Papel'),
              items: [
                for (final p in [Papel.admin, Papel.editor, Papel.viewer])
                  DropdownMenuItem(
                    value: (papel: p, personalizado: ''),
                    child: Text(p.label),
                  ),
                for (final p in papeisQuePossoDar(
                  ref.watch(currentPapelProvider),
                  ref.watch(papeisPersonalizadosProvider).valueOrNull ??
                      const [],
                ))
                  DropdownMenuItem(
                    value: (papel: p.base, personalizado: p.id),
                    child: Text('${p.nome} (parte de ${p.base.label})'),
                  ),
              ],
              onChanged: (v) => setState(() => _papel = v ?? _papel),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _submit, child: const Text('Adicionar')),
          ],
        ),
      ),
    );
  }
}
