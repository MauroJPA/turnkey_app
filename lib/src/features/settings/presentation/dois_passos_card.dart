import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/mensagem_amigavel.dart';
import '../data/dois_passos_repository.dart';

/// "Verificação em 2 passos": só o proprietário liga ou desliga; os outros
/// administradores veem o estado.
class DoisPassosCard extends ConsumerStatefulWidget {
  const DoisPassosCard({super.key});

  @override
  ConsumerState<DoisPassosCard> createState() => _DoisPassosCardState();
}

class _DoisPassosCardState extends ConsumerState<DoisPassosCard> {
  bool _a = false;

  Future<void> _alterar(bool ativar) async {
    if (ativar) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Ligar a verificação em 2 passos?'),
          content: const Text(
            'Passas a precisar do código de 6 dígitos que enviamos por email '
            'sempre que entrares como proprietário ou administrador. A equipa '
            'e o quiosque entram como antes.\n\n'
            'Confirma que consegues abrir o teu email antes de continuar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Ligar'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _a = true);
    final msg = ScaffoldMessenger.of(context);
    try {
      await ref.read(doisPassosRepositoryProvider).definir(ativar);
      ref.invalidate(estadoDoisPassosProvider);
      msg.showSnackBar(
        SnackBar(
          content: Text(
            ativar
                ? 'Verificação em 2 passos ligada.'
                : 'Verificação em 2 passos desligada.',
          ),
        ),
      );
    } catch (e) {
      msg.showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
    } finally {
      if (mounted) setState(() => _a = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(estadoDoisPassosProvider).valueOrNull;
    if (s == null) return const SizedBox.shrink();
    final tt = Theme.of(context).textTheme;
    final podeLigar = s.podeAlterar && (s.ativo || s.smtp) && !_a;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.shield_outlined),
          title: const Text('Verificação em 2 passos'),
          subtitle: Text(
            s.ativo
                ? 'Ligada: proprietário e administradores entram com a '
                      'palavra-passe e um código enviado por email.'
                : 'Desligada. Ao ligar, quem administra precisa também de um '
                      'código enviado por email para entrar.',
          ),
          value: s.ativo,
          onChanged: podeLigar ? _alterar : null,
        ),
        if (!s.smtp && !s.ativo)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              'Falta configurar o envio de emails no servidor (SMTP) para os '
              'códigos poderem chegar.',
              style: tt.bodySmall,
            ),
          ),
        if (!s.podeAlterar)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              'Só o proprietário liga ou desliga.',
              style: tt.bodySmall,
            ),
          ),
      ],
    );
  }
}
