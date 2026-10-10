import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/errors/mensagem_amigavel.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/help_actions.dart';
import '../application/navigation_providers.dart';
import '../domain/nav_config.dart';
import '../domain/pagina_app.dart';
import '../domain/papel_personalizado.dart';

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Rodapé guardado.')));
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
                        onPressed: () => setState(() => _rodape.removeAt(i)),
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
  /// O papel normal escolhido (quando [_personalizado] é `null`).
  Papel _papel = Papel.editor;

  /// O id do papel personalizado escolhido.
  String? _personalizado;
  bool _busy = false;

  Future<void> _guardar(Future<void> Function() f) async {
    setState(() => _busy = true);
    try {
      await f();
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

  Future<void> _mudar(String chave, NivelAcesso n) => _guardar(() async {
    final novo = ref
        .read(navConfigProvider)
        .valueOrNull!
        .comNivel(_papel, chave, n);
    await ref.read(navigationActionsProvider).salvarAcesso(novo);
  });

  Future<void> _mudarPersonalizado(
    PapelPersonalizado p,
    String chave,
    NivelAcesso n,
  ) => _guardar(() async {
    final config = ref.read(navConfigProvider).valueOrNull ?? NavConfig.vazia;
    await ref
        .read(navigationActionsProvider)
        .guardarPapel(p.comNivel(chave, n, config));
  });

  /// Pede nome e papel base. Devolve `null` se cancelou.
  Future<({String nome, Papel base})?> _pedirPapel({
    String nome = '',
    Papel base = Papel.editor,
    required String titulo,
  }) async {
    final ctrl = TextEditingController(text: nome);
    var escolhida = base;
    final r = await showDialog<({String nome, Papel base})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(titulo),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLength: 40,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  hintText: 'Ex.: Balcão, Cozinha, Contabilista',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Parte de (o que pode fazer no servidor):',
                style: Theme.of(ctx).textTheme.labelLarge,
              ),
              RadioGroup<Papel>(
                groupValue: escolhida,
                onChanged: (v) => setS(() => escolhida = v ?? escolhida),
                child: Column(
                  children: [
                    for (final b in PapelPersonalizado.bases)
                      RadioListTile<Papel>(
                        value: b,
                        contentPadding: EdgeInsets.zero,
                        title: Text(b.label),
                        subtitle: Text(switch (b) {
                          Papel.admin =>
                            'Tudo, incluindo configurações e equipa',
                          Papel.editor => 'Cria e altera o dia a dia',
                          _ => 'Só consulta, nunca altera',
                        }),
                      ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, (nome: ctrl.text.trim(), base: escolhida)),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    if (r == null || r.nome.isEmpty) return null;
    return r;
  }

  Future<void> _novoPapel() async {
    final r = await _pedirPapel(titulo: 'Novo papel');
    if (r == null) return;
    await _guardar(() async {
      final p = await ref
          .read(navigationActionsProvider)
          .criarPapel(r.nome, r.base);
      if (mounted) setState(() => _personalizado = p.id);
    });
  }

  Future<void> _editarPapel(PapelPersonalizado p) async {
    final r = await _pedirPapel(
      titulo: 'Papel "${p.nome}"',
      nome: p.nome,
      base: p.base,
    );
    if (r == null) return;
    await _guardar(
      () => ref
          .read(navigationActionsProvider)
          .guardarPapel(
            PapelPersonalizado(
              id: p.id,
              nome: r.nome,
              base: r.base,
              acesso: p.acesso,
            ),
          ),
    );
  }

  Future<void> _apagarPapel(PapelPersonalizado p) async {
    final ok = await confirmDialog(
      context,
      titulo: 'Apagar o papel "${p.nome}"?',
      mensagem:
          'Quem o tem fica só com o papel base (${p.base.label}), com as '
          'permissões normais desse papel.',
      confirmar: 'Apagar',
      destrutivo: true,
    );
    if (!ok) return;
    await _guardar(() async {
      await ref.read(navigationActionsProvider).apagarPapel(p.id);
      if (mounted) setState(() => _personalizado = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(navConfigProvider).valueOrNull ?? NavConfig.vazia;
    final papeis =
        ref.watch(papeisPersonalizadosProvider).valueOrNull ??
        const <PapelPersonalizado>[];
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final perso = papeis.where((p) => p.id == _personalizado).firstOrNull;
    final papelDasOpcoes = perso?.base ?? _papel;
    // Leitura nunca edita, por isso não se oferece "Editar".
    final opcoes = papelDasOpcoes == Papel.viewer
        ? const [NivelAcesso.oculto, NivelAcesso.ver]
        : NivelAcesso.values;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Para cada papel, escolha o que pode fazer em cada página. Oculto '
          'esconde a página (não aparece nem abre); Só ver deixa consultar '
          'sem alterar. O Proprietário tem sempre acesso total. Crie papéis '
          'seus (ex.: Balcão, Cozinha) e dê-os às pessoas em Equipa.',
          style: tt.bodyMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final b in PapelPersonalizado.bases)
              ChoiceChip(
                label: Text(b.label),
                selected: perso == null && _papel == b,
                onSelected: (_) => setState(() {
                  _papel = b;
                  _personalizado = null;
                }),
              ),
            for (final p in papeis)
              ChoiceChip(
                avatar: const Icon(Icons.badge_outlined, size: 16),
                label: Text(p.nome),
                selected: perso?.id == p.id,
                onSelected: (_) => setState(() => _personalizado = p.id),
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: const Text('Novo papel'),
              onPressed: _busy ? null : _novoPapel,
            ),
          ],
        ),
        if (perso != null)
          Card(
            margin: const EdgeInsets.only(top: 12),
            child: ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: Text(perso.nome),
              subtitle: Text(
                'Parte de ${perso.base.label} · '
                '${perso.nAjustes == 0 ? 'ainda igual ao ${perso.base.label}' : '${perso.nAjustes} ${perso.nAjustes == 1 ? 'página diferente' : 'páginas diferentes'}'}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Nome e papel base',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: _busy ? null : () => _editarPapel(perso),
                  ),
                  IconButton(
                    tooltip: 'Apagar o papel',
                    icon: Icon(Icons.delete_outline, color: cs.error),
                    onPressed: _busy ? null : () => _apagarPapel(perso),
                  ),
                ],
              ),
            ),
          ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(),
          ),
        const SizedBox(height: 8),
        for (final p in paginasApp)
          Builder(
            builder: (_) {
              final herdado = perso == null
                  ? null
                  : config.nivelBase(perso.base, p.chave);
              final atual = perso == null
                  ? config.nivelBase(_papel, p.chave)
                  : perso.nivel(p.chave, config.nivelBase);
              final valor = opcoes.contains(atual) ? atual : NivelAcesso.ver;
              final ajustado =
                  perso != null && perso.acesso.containsKey(p.chave);
              return ListTile(
                key: ValueKey('perm-${perso?.id ?? _papel.name}-${p.chave}'),
                leading: Icon(p.icon),
                title: Text(p.label),
                subtitle: perso == null
                    ? null
                    : Text(
                        ajustado
                            ? 'Ajustado (no ${perso.base.label}: ${herdado!.label})'
                            : 'Como o ${perso.base.label}',
                        style: tt.bodySmall?.copyWith(
                          color: ajustado ? cs.primary : null,
                          fontWeight: ajustado ? FontWeight.w600 : null,
                        ),
                      ),
                trailing: DropdownButton<NivelAcesso>(
                  value: valor,
                  onChanged: _busy
                      ? null
                      : (n) => perso == null
                            ? _mudar(p.chave, n!)
                            : _mudarPersonalizado(perso, p.chave, n!),
                  items: [
                    for (final n in opcoes)
                      DropdownMenuItem(value: n, child: Text(n.label)),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
