import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/formatting/money_provider.dart';
import '../../../core/widgets/async_value_view.dart';
import '../application/fecho_dia_providers.dart';
import '../domain/fecho_dia.dart';

/// "Fecho do dia": numa lista, tudo o que convém ver antes de fechar — a
/// contagem, o desperdício, as vendas, o HACCP, o ponto e o dia de amanhã —
/// com o que falta a vermelho e um toque para ir tratar.
class FechoDiaScreen extends ConsumerWidget {
  const FechoDiaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dinheiro = ref.watch(moneyFormatProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fecho do dia'),
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.home),
        ),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(fechoDiaProvider),
          ),
        ],
      ),
      body: AsyncValueView<DadosFecho>(
        value: ref.watch(fechoDiaProvider),
        onRetry: () => ref.invalidate(fechoDiaProvider),
        data: (dados) {
          final passos = passosFecho(dados, dinheiro: dinheiro);
          final faltam = passos
              .where((p) => p.estado == EstadoPasso.falta)
              .length;
          final cs = Theme.of(context).colorScheme;
          final tt = Theme.of(context).textTheme;
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(fechoDiaProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              children: [
                Card(
                  margin: EdgeInsets.zero,
                  color: faltam == 0
                      ? cs.primaryContainer
                      : cs.errorContainer.withValues(alpha: 0.6),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          faltam == 0
                              ? Icons.check_circle_outline
                              : Icons.pending_actions_outlined,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            resumoFecho(passos),
                            style: tt.titleMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < passos.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _LinhaPasso(passo: passos[i]),
                      ],
                    ],
                  ),
                ),
                if (passos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Não tens acesso a nenhuma das partes do fecho.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  'Hoje, sem guardar nada à parte: isto é só um resumo do que '
                  'já está registado. Depois de tratares um passo, volta aqui '
                  'e puxa para atualizar.',
                  style: tt.bodySmall?.copyWith(color: cs.outline),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LinhaPasso extends StatelessWidget {
  const _LinhaPasso({required this.passo});

  final PassoFecho passo;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (icone, cor) = switch (passo.estado) {
      EstadoPasso.ok => (Icons.check_circle, cs.primary),
      EstadoPasso.falta => (Icons.error_outline, cs.error),
      EstadoPasso.info => (Icons.info_outline, cs.outline),
    };
    return ListTile(
      key: ValueKey('fecho-${passo.chave}'),
      leading: Icon(passo.icon),
      title: Text(passo.titulo),
      subtitle: Text(passo.texto),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, color: cor, size: 22),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: cs.outline),
        ],
      ),
      onTap: () => context.go(passo.rota),
    );
  }
}
