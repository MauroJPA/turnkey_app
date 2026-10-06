import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/auth/current_user.dart';
import '../../ingredients/application/ingredients_providers.dart';
import '../../recipes/application/recipes_providers.dart';
import '../../tech_sheets/application/tech_sheets_providers.dart';
import '../application/navigation_providers.dart';
import '../domain/destinos_app.dart';
import '../domain/nav_prefs.dart';
import '../domain/pagina_app.dart';

/// O menu "Mais": todas as páginas a que a pessoa tem acesso, agrupadas por
/// tarefa, e uma pesquisa que encontra páginas, secções, fichas, receitas e
/// ingredientes. Com [procurar], o teclado abre logo na pesquisa.
Future<void> showMaisSheet(BuildContext context, {bool procurar = false}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => _MaisSheet(procurar: procurar),
  );
}

class _MaisSheet extends ConsumerStatefulWidget {
  const _MaisSheet({required this.procurar});
  final bool procurar;

  @override
  ConsumerState<_MaisSheet> createState() => _MaisSheetState();
}

class _MaisSheetState extends ConsumerState<_MaisSheet> {
  final _campo = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  /// Fecha o menu e vai para [rota].
  void _abrir(String rota) {
    final router = GoRouter.of(context);
    Navigator.pop(context);
    router.go(rota);
  }

  bool _acessivel(String pagina) => ref
      .read(navConfigAtualProvider)
      .acessivel(ref.read(currentPapelProvider), pagina);

  Future<void> _escolherCor(PaginaApp p, NavPrefs prefs) async {
    final escolha = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cor de «${p.label}»'),
        content: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final hex in coresBotoes)
              InkWell(
                key: ValueKey('cor-$hex'),
                borderRadius: BorderRadius.circular(20),
                onTap: () => Navigator.pop(ctx, hex),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: corDeHex(hex),
                  child: prefs.cores[p.chave] == hex
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('Cor padrão'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    if (escolha == null) return;
    try {
      await ref
          .read(navigationActionsProvider)
          .salvarPrefs(prefs.comCor(p.chave, escolha));
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível guardar.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final altura = MediaQuery.of(context).size.height;
    final teclado = MediaQuery.of(context).viewInsets.bottom;
    final procura = _q.trim().isNotEmpty;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: teclado),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: altura * 0.85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  key: const ValueKey('mais-pesquisa'),
                  controller: _campo,
                  autofocus: widget.procurar,
                  textInputAction: TextInputAction.search,
                  onChanged: (v) => setState(() => _q = v),
                  onSubmitted: (v) {
                    final r = procurarDestinos(v, _acessivel, maximo: 1);
                    if (r.isNotEmpty) _abrir(r.first.rota);
                  },
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Procurar página, ficha, receita, ingrediente…',
                    isDense: true,
                    suffixIcon: _q.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpar',
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _campo.clear();
                              setState(() => _q = '');
                            },
                          ),
                  ),
                ),
              ),
              Flexible(
                child: procura
                    ? _Resultados(consulta: _q.trim(), aoAbrir: _abrir)
                    : _Grupos(aoAbrir: _abrir, aoEscolherCor: _escolherCor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Grupos extends ConsumerWidget {
  const _Grupos({required this.aoAbrir, required this.aoEscolherCor});

  final void Function(String rota) aoAbrir;
  final Future<void> Function(PaginaApp, NavPrefs) aoEscolherCor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final papel = ref.watch(currentPapelProvider);
    final config = ref.watch(navConfigAtualProvider);
    final prefs = ref.watch(navPrefsAtualProvider);
    final tt = Theme.of(context).textTheme;

    final grupos = <({String titulo, List<PaginaApp> paginas})>[
      for (final g in gruposMais)
        (
          titulo: g.titulo,
          paginas: [
            for (final k in g.paginas)
              if (paginaPorChave(k) case final p?
                  when config.acessivel(papel, k))
                p,
          ],
        ),
      (
        titulo: 'Outras',
        paginas: [
          for (final p in paginasSemGrupo())
            if (config.acessivel(papel, p.chave)) p,
        ],
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        const folga = 8.0;
        final largura = (c.maxWidth - 32 - 2 * folga) / 3;
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            for (final g in grupos)
              if (g.paginas.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 8, 0, 6),
                  child: Text(g.titulo, style: tt.titleSmall),
                ),
                Wrap(
                  spacing: folga,
                  runSpacing: folga,
                  children: [
                    for (final p in g.paginas)
                      SizedBox(
                        width: largura,
                        child: _PaginaTile(
                          pagina: p,
                          cor: prefs.cor(p.chave),
                          aoAbrir: () => aoAbrir(p.rota),
                          aoEscolherCor: () => aoEscolherCor(p, prefs),
                        ),
                      ),
                  ],
                ),
              ],
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Dica: mantém o dedo num ícone para mudar a cor.',
                textAlign: TextAlign.center,
                style: tt.bodySmall,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PaginaTile extends StatelessWidget {
  const _PaginaTile({
    required this.pagina,
    required this.cor,
    required this.aoAbrir,
    required this.aoEscolherCor,
  });

  final PaginaApp pagina;
  final Color? cor;
  final VoidCallback aoAbrir;
  final VoidCallback aoEscolherCor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = cor ?? cs.primary;
    return Card(
      margin: EdgeInsets.zero,
      color: c.withValues(alpha: 0.14),
      child: InkWell(
        key: ValueKey('mais-${pagina.chave}'),
        borderRadius: BorderRadius.circular(12),
        onTap: aoAbrir,
        onLongPress: aoEscolherCor,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(pagina.icon, size: 26, color: c),
              const SizedBox(height: 6),
              Text(
                pagina.rotuloRodape,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Resultados extends ConsumerWidget {
  const _Resultados({required this.consulta, required this.aoAbrir});

  final String consulta;
  final void Function(String rota) aoAbrir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final papel = ref.watch(currentPapelProvider);
    final config = ref.watch(navConfigAtualProvider);
    bool acessivel(String p) => config.acessivel(papel, p);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final q = normalizarBusca(consulta);

    final destinos = procurarDestinos(consulta, acessivel);

    // dados só se carregam a partir de 2 letras (e só a quem tem a página)
    final cedo = q.length < 2;
    bool bate(String nome) => normalizarBusca(nome).contains(q);

    final fichas = cedo || !acessivel('fichas')
        ? const <({String id, String nome})>[]
        : [
            for (final f
                in ref.watch(fichasListProvider(false)).valueOrNull ?? const [])
              if (bate(f.nome)) (id: f.id, nome: f.nome),
          ].take(5).toList();
    final receitas = cedo || !acessivel('receitas')
        ? const <({String id, String nome})>[]
        : [
            for (final r
                in ref.watch(recipesListProvider(false)).valueOrNull ??
                    const [])
              if (bate(r.nome)) (id: r.id, nome: r.nome),
          ].take(5).toList();
    final ingredientes = cedo || !acessivel('inventario')
        ? const <String>[]
        : [
            for (final i
                in ref.watch(ingredientsListProvider(false)).valueOrNull ??
                    const [])
              if (i.correspondeABusca(consulta)) i.nomeComCaracteristica,
          ].take(5).toList();

    final nada =
        destinos.isEmpty &&
        fichas.isEmpty &&
        receitas.isEmpty &&
        ingredientes.isEmpty;

    Widget titulo(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 16, 2),
      child: Text(t, style: tt.titleSmall),
    );

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 12),
      children: [
        if (nada)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Nada encontrado para «$consulta».',
              textAlign: TextAlign.center,
              style: tt.bodyMedium,
            ),
          ),
        if (destinos.isNotEmpty) ...[
          titulo('Páginas'),
          for (final d in destinos)
            ListTile(
              key: ValueKey('achado-${d.rota}'),
              dense: true,
              leading: Icon(d.icon, color: cs.primary),
              title: Text(d.label),
              subtitle: d.dentroDe.isEmpty ? null : Text(d.dentroDe),
              onTap: () => aoAbrir(d.rota),
            ),
        ],
        if (fichas.isNotEmpty) ...[
          titulo('Fichas técnicas'),
          for (final f in fichas)
            ListTile(
              dense: true,
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(f.nome),
              onTap: () => aoAbrir('${Routes.techSheets}/${f.id}'),
            ),
        ],
        if (receitas.isNotEmpty) ...[
          titulo('Receitas'),
          for (final r in receitas)
            ListTile(
              dense: true,
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(r.nome),
              onTap: () => aoAbrir('${Routes.recipes}/${r.id}'),
            ),
        ],
        if (ingredientes.isNotEmpty) ...[
          titulo('Ingredientes'),
          for (final n in ingredientes)
            ListTile(
              dense: true,
              leading: const Icon(Icons.egg_alt_outlined),
              title: Text(n),
              onTap: () => aoAbrir(
                '${Routes.inventory}?q=${Uri.encodeQueryComponent(n)}',
              ),
            ),
        ],
      ],
    );
  }
}
