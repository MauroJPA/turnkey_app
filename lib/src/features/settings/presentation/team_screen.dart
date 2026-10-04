import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/errors/mensagem_amigavel.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/help_actions.dart';
import '../application/settings_providers.dart';
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
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
      () => ref.read(settingsActionsProvider).addMember(
            nome: result.nome,
            email: result.email,
            password: result.password,
            papel: result.papel,
          ),
    );
  }

  Future<void> _changeRole(TeamMember m) async {
    final novo = await showDialog<Papel>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Papel de ${m.nome.isEmpty ? m.email : m.nome}'),
        children: [
          RadioGroup<Papel>(
            groupValue: m.papel,
            onChanged: (v) => Navigator.pop(ctx, v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final p in Papel.values)
                  RadioListTile<Papel>(
                    value: p,
                    title: Text(p.label),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (novo == null || novo == m.papel) return;
    await _run(
      () => ref.read(settingsActionsProvider).changeRole(m.id, novo),
    );
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(teamMembersProvider);

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
                        (m.nome.isEmpty ? m.email : m.nome)
                            .characters
                            .first
                            .toUpperCase(),
                      ),
                    ),
                    title: Text(m.nome.isEmpty ? m.email : m.nome),
                    subtitle: Text(m.email),
                    trailing: Chip(label: Text(m.papel.label)),
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
  _NewMember(this.nome, this.email, this.password, this.papel);
  final String nome;
  final String email;
  final String password;
  final Papel papel;
}

class _AddMemberSheet extends StatefulWidget {
  const _AddMemberSheet();

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  Papel _papel = Papel.editor;

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
      _NewMember(
        _nome.text.trim(),
        _email.text.trim(),
        _password.text,
        _papel,
      ),
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
            Text(
              'Novo membro',
              style: Theme.of(context).textTheme.titleLarge,
            ),
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
            DropdownButtonFormField<Papel>(
              initialValue: _papel,
              decoration: const InputDecoration(labelText: 'Papel'),
              items: [
                for (final p in [Papel.admin, Papel.editor, Papel.viewer])
                  DropdownMenuItem(value: p, child: Text(p.label)),
              ],
              onChanged: (v) => setState(() => _papel = v ?? Papel.editor),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _submit, child: const Text('Adicionar')),
          ],
        ),
      ),
    );
  }
}
