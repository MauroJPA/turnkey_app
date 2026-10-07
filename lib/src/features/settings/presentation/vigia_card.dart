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

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  /// "Explicar com IA": mostra o texto EXATO que seria enviado (já sem IPs,
  /// emails nem nomes), pede confirmação e só então envia. Se já há uma
  /// explicação guardada, mostra-a logo (nada é enviado).
  Future<void> _explicar(AchadoVigia a, {bool refazer = false}) async {
    final repo = ref.read(vigiaRepositoryProvider);
    setState(() => _ocupado = a.id);
    try {
      final previa = await repo.previaExplicacao(a.id);
      if (!mounted) return;
      if (previa.cache != null && !refazer) {
        setState(() => _ocupado = null);
        await _mostrar(a, previa.cache!);
        return;
      }
      setState(() => _ocupado = null);
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => _ConfirmarEnvioIa(previa: previa),
      );
      if (ok != true || !mounted) return;
      setState(() => _ocupado = '${a.id}#ia');
      final ex = await repo.explicar(
        a.id,
        refazer: refazer || previa.cache != null,
      );
      if (!mounted) return;
      setState(() => _ocupado = null);
      await _mostrar(a, ex);
    } on Object catch (e) {
      _aviso(mensagemAmigavel(e));
    } finally {
      if (mounted) setState(() => _ocupado = null);
    }
  }

  Future<void> _mostrar(AchadoVigia a, ExplicacaoIa ex) async {
    final outra = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => _ExplicacaoIaSheet(achado: a, explicacao: ex),
    );
    if (outra == true && mounted) await _explicar(a, refazer: true);
  }

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
                  aExplicar: _ocupado == '${a.id}#ia',
                  aoExplicar: e.iaAtiva ? () => _explicar(a) : null,
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
                          aExplicar: _ocupado == '${a.id}#ia',
                          aoExplicar: e.iaAtiva ? () => _explicar(a) : null,
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
    this.aoExplicar,
    this.aExplicar = false,
  });

  final AchadoVigia a;
  final DateTime agora;
  final bool ocupado;
  final VoidCallback aoAceitar;

  /// "Explicar com IA" (null = não disponível neste servidor).
  final VoidCallback? aoExplicar;
  final bool aExplicar;

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
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 6,
              children: [
                if (aoExplicar != null)
                  OutlinedButton.icon(
                    key: ValueKey('explicar-${a.id}'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: (ocupado || aExplicar) ? null : aoExplicar,
                    icon: aExplicar
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome, size: 18),
                    label: Text(aExplicar ? 'A explicar…' : 'Explicar com IA'),
                  ),
                FilledButton.tonal(
                  key: ValueKey('aceitar-${a.id}'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: (ocupado || aExplicar) ? null : aoAceitar,
                  child: Text(ocupado ? 'A anotar…' : 'Já verifiquei'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// O que vai para a IA, antes de enviar: o texto exato, para onde vai e o que
/// já foi retirado.
class _ConfirmarEnvioIa extends StatelessWidget {
  const _ConfirmarEnvioIa({required this.previa});
  final PreviaIa previa;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      key: const ValueKey('confirmar-envio-ia'),
      title: const Text('Enviar este resumo à IA?'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vai para ${previa.provider}. É só isto (os endereços IP, '
                'emails, nomes de pessoas e aparelhos, hashes e chaves já foram '
                'trocados por rótulos como "IP-Tailscale-1"):',
                style: tt.bodyMedium,
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  previa.texto,
                  key: const ValueKey('texto-previa-ia'),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Hoje ainda podes pedir ${previa.restantes} '
                'explicaç${previa.restantes == 1 ? 'ão' : 'ões'}.',
                style: tt.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: previa.restantes > 0
              ? () => Navigator.pop(context, true)
              : null,
          child: const Text('Enviar e explicar'),
        ),
      ],
    );
  }
}

/// A explicação da IA: o que significa, se parece normal ou suspeito, e os
/// passos (com comandos só de leitura que se podem copiar).
class _ExplicacaoIaSheet extends StatelessWidget {
  const _ExplicacaoIaSheet({required this.achado, required this.explicacao});
  final AchadoVigia achado;
  final ExplicacaoIa explicacao;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final ex = explicacao;
    final cor = switch (ex.veredito) {
      VereditoIa.normal => cs.primary,
      VereditoIa.duvidoso => const Color(0xFFE08A00),
      VereditoIa.suspeito => cs.error,
    };
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: ListView(
          key: const ValueKey('explicacao-ia'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          shrinkWrap: true,
          children: [
            Text(achado.titulo, style: tt.titleMedium),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: cor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ex.veredito.label,
                      key: const ValueKey('veredito-ia'),
                      style: tt.titleSmall?.copyWith(color: cor),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(ex.resumo, style: tt.bodyLarge),
            if (ex.porque.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(ex.porque, style: tt.bodyMedium),
            ],
            const SizedBox(height: 14),
            Text('O que fazer, por ordem', style: tt.titleSmall),
            for (var i = 0; i < ex.passos.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: cs.primaryContainer,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ex.passos[i].texto, style: tt.bodyMedium),
                          if (ex.passos[i].comando != null)
                            _Comando(comando: ex.passos[i].comando!),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (ex.naoFazer.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Não faças', style: tt.titleSmall),
              for (final n in ex.naoFazer)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2, right: 6),
                        child: Icon(
                          Icons.block,
                          size: 16,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      Expanded(child: Text(n, style: tt.bodyMedium)),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 14),
            Text(
              'Gerado por IA (${ex.provider}${ex.doCache ? ', guardado de antes' : ''}). '
              'Pode errar: confere antes de correr qualquer comando e, se tiveres '
              'dúvidas sérias, pede ajuda a alguém de confiança. Os comandos só '
              'leem informação; nada se corre sozinho.',
              style: tt.bodySmall,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Explicar outra vez'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Fechar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Comando extends StatelessWidget {
  const _Comando({required this.comando});
  final String comando;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              comando,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          IconButton(
            tooltip: 'Copiar comando',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.copy, size: 16),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: comando));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Comando copiado.')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
