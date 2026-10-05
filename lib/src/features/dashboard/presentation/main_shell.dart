import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/auth/permissions.dart';
import '../../invoices/presentation/analise_faturas_widgets.dart';
import '../../navigation/application/navigation_providers.dart';
import '../../navigation/domain/nav_config.dart';
import '../../navigation/domain/pagina_app.dart';
import 'aviso_versao_nova.dart';

/// Largura máxima do conteúdo em ecrãs largos (computador).
const double _larguraMaxima = 960;

/// Casca das secções principais: mostra a barra de navegação inferior (as
/// páginas e a ordem escolhidas em Configurações → Navegação) e aplica as
/// permissões por página: sem acesso mostra um aviso; "só ver" trata a
/// pessoa como Leitura dentro dessa página.
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final papel = ref.watch(currentPapelProvider);
    final config = ref.watch(navConfigAtualProvider);

    final abas = <({String rota, IconData icon, String label})>[
      (rota: Routes.home, icon: Icons.home_outlined, label: 'Início'),
      for (final p in config.rodapePara(papel))
        (rota: p.rota, icon: p.icon, label: p.rotuloRodape),
    ];

    var selecionada = 0;
    for (var i = abas.length - 1; i >= 0; i--) {
      final r = abas[i].rota;
      if (r == Routes.home ? location == r : location.startsWith(r)) {
        selecionada = i;
        break;
      }
    }

    final pagina = paginaDaRota(location);
    final nivel = pagina == null
        ? NivelAcesso.editar
        : config.nivel(papel, pagina.chave);

    final Widget corpo;
    if (nivel == NivelAcesso.oculto) {
      corpo = _SemAcesso(nome: pagina?.label ?? '');
    } else if (nivel == NivelAcesso.ver && papel != Papel.viewer) {
      corpo = ProviderScope(
        overrides: [currentPapelProvider.overrideWithValue(Papel.viewer)],
        child: child,
      );
    } else {
      corpo = child;
    }

    // ecrãs largos (computador): a app fica numa coluna centrada, como no
    // telemóvel — em vez de linhas e botões esticados por 1500 px
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _larguraMaxima),
          child: corpo,
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AvisoVersaoNova(),
          // ficheiro de faturas a ser enviado/analisado (fora do ecrã das Faturas)
          if (!location.startsWith(Routes.invoices))
            const AnaliseFaturasFaixa(),
          if (abas.length >= 2)
            ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainer,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _larguraMaxima),
                  child: NavigationBar(
                    backgroundColor: Colors.transparent,
                    selectedIndex: selecionada,
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysShow,
                    onDestinationSelected: (i) => context.go(abas[i].rota),
                    destinations: [
                      for (final a in abas)
                        NavigationDestination(
                          icon: Icon(a.icon),
                          label: a.label,
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SemAcesso extends StatelessWidget {
  const _SemAcesso({required this.nome});
  final String nome;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
        title: Text(nome.isEmpty ? 'Sem acesso' : nome),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Não tens acesso a esta página.\n'
                'Pede ao proprietário para a ativar em Configurações → Navegação.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => context.go(Routes.home),
                child: const Text('Ir para o Início'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
