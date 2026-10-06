import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/help_actions.dart';
import '../application/navigation_providers.dart';
import '../domain/nav_config.dart';
import '../domain/pagina_app.dart';

/// Configurações → Navegação e permissões: o rodapé (Proprietário e
/// Administrador) e o que cada nível pode ver/editar (só o Proprietário).
class NavegacaoScreen extends ConsumerWidget {
  const NavegacaoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final papel = ref.watch(currentPapelProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(Routes.settings),
          ),
          title: const Text('Navegação e permissões'),
          actions: const [HelpActions(topic: HelpTopic.navegacao)],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Rodapé'),
              Tab(text: 'Permissões'),
            ],
          ),
        ),
        body: !papel.canEditConfig
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Só o Proprietário e os Administradores podem alterar a '
                    'navegação.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : TabBarView(
                children: [
                  const _RodapeTab(),
                  papel.isOwner
                      ? const _PermissoesTab()
                      : const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Só o Proprietário pode alterar as permissões '
                              'de cada nível.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                ],
              ),
      ),
    );
  }
}

class _RodapeTab extends ConsumerStatefulWidget {
  const _RodapeTab();

  @override
  ConsumerState<_RodapeTab> createState() => _RodapeTabState();
}

class _RodapeTabState extends ConsumerState<_RodapeTab> {
  late List<String> _rodape = [...ref.read(navConfigAtualProvider).rodape];
  bool _busy = false;

  bool get _alterado {
    final atual = ref.read(navConfigAtualProvider).rodape;
    if (atual.length != _rodape.length) return true;
    for (var i = 0; i < atual.length; i++) {
      if (atual[i] != _rodape[i]) return true;
    }
    return false;
  }

  Future<void> _guardar() async {
    setState(() => _busy = true);
    try {
      await ref.read(navigationActionsProvider).salvarRodape(_rodape);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Rodapé guardado.')));
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível guardar.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final disponiveis = [
      for (final p in paginasApp)
        if (!_rodape.contains(p.chave)) p,
    ];
    final cheio = _rodape.length >= rodapeMaximo;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Escolha as páginas da barra de baixo e a ordem (arraste). O Início '
          'está sempre lá. Cada pessoa só vê as que tem permissão para abrir.',
          style: tt.bodyMedium,
        ),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.home_outlined),
            title: Text('Início'),
            subtitle: Text('Sempre presente'),
          ),
        ),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorderItem: (a, b) => setState(() {
            _rodape.insert(b, _rodape.removeAt(a));
          }),
          children: [
            for (var i = 0; i < _rodape.length; i++)
              Card(
                key: ValueKey('rodape-${_rodape[i]}'),
                child: ListTile(
                  leading: Icon(paginaPorChave(_rodape[i])?.icon),
                  title: Text(paginaPorChave(_rodape[i])?.label ?? _rodape[i]),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Tirar do rodapé',
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () =>
                            setState(() => _rodape.removeAt(i)),
                      ),
                      ReorderableDragStartListener(
                        index: i,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.drag_handle),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          cheio
              ? 'O rodapé está cheio (máximo $rodapeMaximo além do Início; as outras páginas ficam no "Mais"). '
                  'Tire uma página para juntar outra.'
              : 'Juntar ao rodapé',
          style: tt.titleSmall,
        ),
        for (final p in disponiveis)
          ListTile(
            key: ValueKey('disponivel-${p.chave}'),
            dense: true,
            leading: Icon(p.icon),
            title: Text(p.label),
            trailing: IconButton(
              tooltip: 'Juntar ao rodapé',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: cheio
                  ? null
                  : () => setState(() => _rodape.add(p.chave)),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: (_busy || !_alterado) ? null : _guardar,
          child: const Text('Guardar rodapé'),
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() => _rodape = [...rodapePorOmissao]),
          child: const Text('Repor o rodapé original'),
        ),
      ],
    );
  }
}

class _PermissoesTab extends ConsumerStatefulWidget {
  const _PermissoesTab();

  @override
  ConsumerState<_PermissoesTab> createState() => _PermissoesTabState();
}

class _PermissoesTabState extends ConsumerState<_PermissoesTab> {
  Papel _papel = Papel.editor;
  bool _busy = false;

  Future<void> _mudar(String chave, NivelAcesso n) async {
    setState(() => _busy = true);
    try {
      final novo =
          ref.read(navConfigAtualProvider).comNivel(_papel, chave, n);
      await ref.read(navigationActionsProvider).salvarAcesso(novo);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível guardar.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(navConfigAtualProvider);
    final tt = Theme.of(context).textTheme;
    // Leitura nunca edita, por isso não se oferece "Editar".
    final opcoes = _papel == Papel.viewer
        ? const [NivelAcesso.oculto, NivelAcesso.ver]
        : NivelAcesso.values;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Para cada nível, escolha o que pode fazer em cada página. Oculto '
          'esconde a página (não aparece nem abre); Só ver deixa consultar '
          'sem alterar. O Proprietário tem sempre acesso total.',
          style: tt.bodyMedium,
        ),
        const SizedBox(height: 12),
        SegmentedButton<Papel>(
          segments: const [
            ButtonSegment(value: Papel.admin, label: Text('Administrador')),
            ButtonSegment(value: Papel.editor, label: Text('Editor')),
            ButtonSegment(value: Papel.viewer, label: Text('Leitura')),
          ],
          selected: {_papel},
          onSelectionChanged: (s) => setState(() => _papel = s.first),
        ),
        if (_busy) const Padding(
          padding: EdgeInsets.only(top: 8),
          child: LinearProgressIndicator(),
        ),
        const SizedBox(height: 8),
        for (final p in paginasApp)
          Builder(builder: (_) {
            final atual = config.nivel(_papel, p.chave);
            final valor = opcoes.contains(atual) ? atual : NivelAcesso.ver;
            return ListTile(
              key: ValueKey('perm-${_papel.name}-${p.chave}'),
              leading: Icon(p.icon),
              title: Text(p.label),
              trailing: DropdownButton<NivelAcesso>(
                value: valor,
                onChanged: _busy ? null : (n) => _mudar(p.chave, n!),
                items: [
                  for (final n in opcoes)
                    DropdownMenuItem(value: n, child: Text(n.label)),
                ],
              ),
            );
          }),
      ],
    );
  }
}
