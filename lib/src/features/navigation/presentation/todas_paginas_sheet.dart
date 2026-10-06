import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/current_user.dart';
import '../application/navigation_providers.dart';
import '../domain/nav_prefs.dart';
import '../domain/pagina_app.dart';

/// Lista de TODAS as páginas a que a pessoa tem acesso. Daqui abre-se
/// qualquer página e escolhe-se a cor do ícone (preferência pessoal).
Future<void> showTodasPaginasSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => const _TodasPaginasSheet(),
  );
}

class _TodasPaginasSheet extends ConsumerStatefulWidget {
  const _TodasPaginasSheet();

  @override
  ConsumerState<_TodasPaginasSheet> createState() => _TodasPaginasSheetState();
}

class _TodasPaginasSheetState extends ConsumerState<_TodasPaginasSheet> {
  bool _busy = false;

  Future<void> _guardar(NavPrefs novo) async {
    setState(() => _busy = true);
    try {
      await ref.read(navigationActionsProvider).salvarPrefs(novo);
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
    await _guardar(prefs.comCor(p.chave, escolha));
  }

  @override
  Widget build(BuildContext context) {
    final papel = ref.watch(currentPapelProvider);
    final config = ref.watch(navConfigAtualProvider);
    final prefs = ref.watch(navPrefsAtualProvider);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final paginas = [
      for (final p in paginasApp)
        if (config.acessivel(papel, p.chave)) p,
    ];
    final noRodape = config.rodapePara(papel).map((p) => p.chave).toSet();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_busy) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Todas as páginas', style: tt.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Toca para abrir. A paleta muda a cor do ícone (só para ti).',
                    style: tt.bodySmall,
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in paginas)
                    Builder(
                      builder: (_) {
                        final cor = prefs.cor(p.chave) ?? cs.primary;
                        return ListTile(
                          key: ValueKey('pagina-${p.chave}'),
                          leading: CircleAvatar(
                            backgroundColor: cor.withValues(alpha: 0.18),
                            child: Icon(p.icon, color: cor),
                          ),
                          title: Text(p.label),
                          subtitle: Text(
                            [
                              p.descricao,
                              if (noRodape.contains(p.chave)) 'no rodapé',
                            ].join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            context.go(p.rota);
                          },
                          trailing: IconButton(
                            tooltip: 'Cor do ícone',
                            icon: const Icon(Icons.palette_outlined),
                            onPressed: _busy
                                ? null
                                : () => _escolherCor(p, prefs),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
