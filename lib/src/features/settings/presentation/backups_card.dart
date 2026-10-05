import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/mensagem_amigavel.dart';
import '../data/backups_repository.dart';

/// "Estado dos backups" para administradores: o último backup automático e a
/// cópia para fora do servidor, com aviso se algo falhou ou está atrasado.
class BackupsCard extends ConsumerWidget {
  const BackupsCard({super.key});

  static String _idade(Duration? d) {
    if (d == null) return 'nunca';
    if (d.inMinutes < 2) return 'agora mesmo';
    if (d.inHours < 1) return 'há ${d.inMinutes} min';
    if (d.inHours < 48) return 'há ${d.inHours} h';
    return 'há ${d.inDays} dias';
  }

  static String _tamanho(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(estadoBackupsProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.error_outline, color: cs.error),
        title: const Text('Estado dos backups'),
        subtitle: Text(mensagemAmigavel(e)),
        trailing: IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => ref.invalidate(estadoBackupsProvider),
        ),
      ),
      data: (s) {
        if (s == null) return const SizedBox.shrink();
        final agora = DateTime.now().toUtc();
        final problema = s.problema(agora);
        final cor = problema ? cs.error : Colors.green;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: problema
                ? cs.errorContainer.withValues(alpha: 0.5)
                : cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    problema
                        ? Icons.warning_amber_rounded
                        : Icons.verified_outlined,
                    color: cor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      problema
                          ? 'Backups: precisa de atenção'
                          : 'Backups em dia',
                      style: tt.titleSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Atualizar',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.refresh),
                    onPressed: () => ref.invalidate(estadoBackupsProvider),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _Linha(
                'Último backup automático',
                s.ultimoQuando == null
                    ? 'nenhum'
                    : '${_idade(s.idadeLocal(agora))}'
                          '${s.ultimoTamanho > 0 ? ' · ${_tamanho(s.ultimoTamanho)}' : ''}',
                ok: !s.localAtrasado(agora),
              ),
              _Linha(
                'Backups guardados no servidor',
                '${s.localTotal}',
                ok: s.localTotal > 0,
              ),
              _Linha(
                'Cópia para fora do servidor',
                switch (s.externoEstado) {
                  'ok' => 'ok · ${_idade(s.idadeExterno(agora))}',
                  'falha' => 'FALHOU · ${_idade(s.idadeExterno(agora))}',
                  _ => 'sem informação (o script de cópia externa não correu)',
                },
                ok: s.externoEstado == 'ok' && !s.externoAtrasado(agora),
                neutro: s.externoEstado == 'desconhecido',
              ),
              if (problema)
                for (final a in s.avisos(agora))
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      a,
                      style: tt.bodySmall?.copyWith(color: cs.error),
                    ),
                  ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Os backups guardam-se todas as noites; confirma de vez em '
                  'quando que consegues restaurar um (docs/BACKUPS.md).',
                  style: tt.bodySmall,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha(this.nome, this.valor, {required this.ok, this.neutro = false});

  final String nome;
  final String valor;
  final bool ok;
  final bool neutro;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cor = neutro ? cs.outline : (ok ? Colors.green : cs.error);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 5, child: Text(nome)),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Text(
              valor,
              textAlign: TextAlign.end,
              style: TextStyle(color: cor, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
