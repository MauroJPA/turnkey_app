import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/mensagem_amigavel.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../data/vigia_repository.dart';
import '../domain/vigia.dart';

/// O comando que se corre uma vez no servidor.
const comandoInstalarVigia =
    'cd /opt/gc_turnkey && sudo bash seguranca/instalar-vigia.sh';

/// "Vigia do servidor": um alarme que procura sinais de invasão de 10 em 10
/// minutos e diz, em português, o que viu e o que fazer. Só o dono do
/// servidor o vê (para os outros o cartão nem aparece).
class VigiaCard extends ConsumerWidget {
  const VigiaCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(vigiaProvider);
    final estado = async.valueOrNull;
    if (estado == null) {
      // a carregar, sem permissão ou sem ligação: não ocupa espaço
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _Conteudo(estado: estado),
    );
  }
}

Color _cor(GravidadeVigia g, ColorScheme cs) => switch (g) {
  GravidadeVigia.critico => cs.error,
  GravidadeVigia.atencao => const Color(0xFFE08A00),
  GravidadeVigia.info => cs.primary,
};

class _Conteudo extends ConsumerStatefulWidget {
  const _Conteudo({required this.estado});
  final EstadoVigia estado;

  @override
  ConsumerState<_Conteudo> createState() => _ConteudoState();
}

class _ConteudoState extends ConsumerState<_Conteudo> {
  String? _ocupado;

  Future<void> _aceitar(AchadoVigia a) async {
    final ok = await confirmDialog(
      context,
      titulo: 'Já verificaste isto?',
      mensagem:
          '"${a.titulo}"\n\nSe foste tu (ou é normal), o vigia aprende e deixa '
          'de avisar disto. Se não tens a certeza, não carregues: segue o '
          '"O que fazer".',
      confirmar: 'Já verifiquei',
    );
    if (!ok || !mounted) return;
    setState(() => _ocupado = a.id);
    try {
      await ref.read(vigiaRepositoryProvider).aceitar(a.id);
      ref.invalidate(vigiaProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Anotado. O vigia aprende na próxima ronda (≤ 10 min).',
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
      if (mounted) setState(() => _ocupado = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.estado;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final nivel = e.nivel;
    final cor = e.instalado ? _cor(nivel, cs) : cs.outline;
    final agora = DateTime.now();

    return Card(
      key: const ValueKey('vigia-card'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  !e.instalado
                      ? Icons.shield_outlined
                      : nivel == GravidadeVigia.info
                      ? Icons.verified_user_outlined
                      : Icons.gpp_maybe_outlined,
                  color: cor,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Vigia do servidor', style: tt.titleMedium),
                      Text(
                        e.resumo,
                        key: const ValueKey('vigia-resumo'),
                        style: tt.bodyMedium?.copyWith(
                          color: cor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Atualizar',
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.invalidate(vigiaProvider),
                ),
              ],
            ),
            if (!e.instalado) ...[
              const SizedBox(height: 8),
              Text(
                'Um alarme que procura sinais de invasão no servidor de 10 em 10 '
                'minutos (entradas SSH estranhas, chaves e tarefas novas, '
                'mineradores, aparelhos novos no Tailscale, ficheiros da app '
                'alterados…) e avisa-te aqui e por Telegram/email. Só lê: não '
                'altera nada. Instala-se uma vez, no servidor:',
                style: tt.bodySmall,
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  comandoInstalarVigia,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      const ClipboardData(text: comandoInstalarVigia),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Comando copiado.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copiar comando'),
                ),
              ),
            ] else ...[
              const SizedBox(height: 2),
              Text(
                [
                  'Última verificação ${textoHa(e.quando, agora)}',
                  if (e.verificacoes > 0)
                    '${e.verificacoes - e.verificacoesComErro} verificações a correr',
                  if (e.verificacoesComErro > 0)
                    '${e.verificacoesComErro} com erro',
                ].join(' · '),
                style: tt.bodySmall,
              ),
              if (e.parado)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _Faixa(
                    texto:
                        'O vigia não corre há mais de 40 minutos. Se não foste '
                        'tu a desligá-lo, confirma o servidor: sudo systemctl '
                        'status gc_turnkey-vigia.timer',
                    cor: _cor(GravidadeVigia.atencao, cs),
                  ),
                ),
              const SizedBox(height: 8),
              if (e.ativos.isEmpty && !e.parado)
                Text(
                  'Nada fora do normal nas últimas verificações.',
                  style: tt.bodySmall,
                ),
              for (final a in e.ativos)
                _LinhaAchado(
                  a: a,
                  agora: agora,
                  ocupado: _ocupado == a.id,
                  aoAceitar: () => _aceitar(a),
                ),
              if (e.aAprender.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${e.aAprender.length} alerta(s) marcado(s) "já verifiquei": '
                    'o vigia aprende na próxima ronda.',
                    style: tt.bodySmall,
                  ),
                ),
              if (e.paraSaber.isNotEmpty)
                Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    key: const ValueKey('vigia-para-saber'),
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      'Para saber · ${e.paraSaber.length}',
                      style: tt.titleSmall,
                    ),
                    children: [
                      for (final a in e.paraSaber)
                        _LinhaAchado(
                          a: a,
                          agora: agora,
                          ocupado: _ocupado == a.id,
                          aoAceitar: () => _aceitar(a),
                        ),
                    ],
                  ),
                ),
              for (final n in e.notas)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(n, style: tt.bodySmall),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Faixa extends StatelessWidget {
  const _Faixa({required this.texto, required this.cor});
  final String texto;
  final Color cor;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: cor.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(texto, style: Theme.of(context).textTheme.bodySmall),
  );
}

class _LinhaAchado extends StatelessWidget {
  const _LinhaAchado({
    required this.a,
    required this.agora,
    required this.ocupado,
    required this.aoAceitar,
  });

  final AchadoVigia a;
  final DateTime agora;
  final bool ocupado;
  final VoidCallback aoAceitar;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final cor = _cor(a.gravidade, cs);
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: cor, width: 4)),
        color: cor.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey('achado-${a.id}'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          initiallyExpanded: a.gravidade == GravidadeVigia.critico,
          title: Text(
            a.titulo,
            style: tt.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: a.gravidade == GravidadeVigia.critico ? cor : null,
            ),
          ),
          subtitle: Text(
            [
              if (a.detalhe.isNotEmpty) a.detalhe,
              if (a.desde != null) 'visto ${textoHa(a.desde, agora)}',
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: tt.bodySmall,
          ),
          children: [
            // o detalhe curto já está no subtítulo; só repete se for comprido
            if (a.detalhe.length > 100) Text(a.detalhe, style: tt.bodyMedium),
            for (final i in a.itens)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('• $i', style: tt.bodySmall),
              ),
            if (a.fazer.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('O que fazer', style: tt.labelLarge),
              const SizedBox(height: 2),
              Text(a.fazer, style: tt.bodyMedium),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                key: ValueKey('aceitar-${a.id}'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: ocupado ? null : aoAceitar,
                child: Text(ocupado ? 'A anotar…' : 'Já verifiquei'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
