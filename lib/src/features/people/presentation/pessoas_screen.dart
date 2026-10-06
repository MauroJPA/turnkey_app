import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/help_actions.dart';
import 'ferias_view.dart';
import 'ponto_view.dart';

/// As secções de Pessoas.
enum SecaoPessoas {
  ponto('Ponto', Icons.access_time, Routes.pessoasPonto),
  ferias('Férias', Icons.beach_access_outlined, Routes.pessoasFerias);

  const SecaoPessoas(this.label, this.icon, this.rota);
  final String label;
  final IconData icon;
  final String rota;

  HelpTopic get ajuda => switch (this) {
    SecaoPessoas.ponto => HelpTopic.pessoasPonto,
    SecaoPessoas.ferias => HelpTopic.pessoasFerias,
  };
}

/// Pessoas: o ponto da equipa (e, a seguir, as férias e as notas) numa só
/// página, no mesmo estilo da Produção e da Contabilidade.
class PessoasScreen extends ConsumerWidget {
  const PessoasScreen({super.key, required this.secao});

  final SecaoPessoas secao;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(currentPapelProvider).canEditConfig;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
        title: const Text('Pessoas'),
        actions: [HelpActions(topic: secao.ajuda)],
      ),
      floatingActionButton: admin && secao == SecaoPessoas.ponto
          ? FloatingActionButton.extended(
              onPressed: () => novaMarcacaoManual(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Marcação manual'),
            )
          : null,
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final s in SecaoPessoas.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: Icon(s.icon, size: 18),
                      label: Text(s.label),
                      selected: secao == s,
                      onSelected: (_) {
                        if (secao != s) context.go(s.rota);
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: switch (secao) {
              SecaoPessoas.ponto => const PontoView(
                key: ValueKey('pessoas-ponto'),
              ),
              SecaoPessoas.ferias => const FeriasView(
                key: ValueKey('pessoas-ferias'),
              ),
            },
          ),
        ],
      ),
    );
  }
}
