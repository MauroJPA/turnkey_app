import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/errors/mensagem_amigavel.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/help_actions.dart';
import '../data/aprovacoes_repository.dart';

/// Aprovação de contas novas (só o operador da plataforma): quem se registou
/// só entra depois de ser aprovado aqui.
class AprovacoesScreen extends ConsumerStatefulWidget {
  const AprovacoesScreen({super.key});

  @override
  ConsumerState<AprovacoesScreen> createState() => _AprovacoesScreenState();
}

class _AprovacoesScreenState extends ConsumerState<AprovacoesScreen> {
  String? _ocupada;

  Future<void> _decidir(ContaPendente c, {required bool aprovar}) async {
    if (!aprovar) {
      final ok = await confirmDialog(
        context,
        titulo: 'Recusar esta conta?',
        mensagem:
            'Apaga o pedido de ${c.email}. Se a pessoa quiser entrar, tem de '
            'se registar de novo.',
        confirmar: 'Recusar',
        destrutivo: true,
      );
      if (!ok) return;
    }
    setState(() => _ocupada = c.id);
    try {
      final repo = ref.read(aprovacoesRepositoryProvider);
      if (aprovar) {
        await repo.aprovar(c.id);
      } else {
        await repo.recusar(c.id);
      }
      ref.invalidate(aprovacoesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              aprovar
                  ? '${c.email} aprovada.'
                  : 'Pedido de ${c.email} recusado.',
            ),
          ),
        );
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
      }
    } finally {
      if (mounted) setState(() => _ocupada = null);
    }
  }

  static String _data(DateTime? d) {
    if (d == null) return '';
    final l = d.toLocal();
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(l.day)}/${dois(l.month)}/${l.year} ${dois(l.hour)}:${dois(l.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(aprovacoesProvider);
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.settings),
        ),
        title: const Text('Aprovações de contas'),
        actions: const [HelpActions(topic: HelpTopic.aprovacoes)],
      ),
      body: AsyncValueView<Aprovacoes>(
        value: async,
        onRetry: () => ref.invalidate(aprovacoesProvider),
        data: (a) {
          if (!a.operador) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Só o operador da plataforma aprova contas novas.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (a.pendentes.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhuma conta por aprovar.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  'Estas pessoas criaram conta e esperam. Só entram depois de '
                  'aprovares.',
                  style: tt.bodySmall,
                ),
              ),
              for (final c in a.pendentes)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.nome.isEmpty ? c.email : c.nome,
                          style: tt.titleSmall,
                        ),
                        if (c.nome.isNotEmpty) Text(c.email),
                        if (c.criada != null)
                          Text(
                            'pediu em ${_data(c.criada)}',
                            style: tt.bodySmall,
                          ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 44),
                                ),
                                onPressed: _ocupada == null
                                    ? () => _decidir(c, aprovar: false)
                                    : null,
                                child: const Text('Recusar'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 44),
                                ),
                                onPressed: _ocupada == null
                                    ? () => _decidir(c, aprovar: true)
                                    : null,
                                child: Text(
                                  _ocupada == c.id ? 'A aprovar…' : 'Aprovar',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
