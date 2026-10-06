import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/formatting/money_provider.dart';
import '../domain/plano_pronto.dart';

/// Depois de agendar a produção: um só ecrã com o que ficou agendado e o que
/// falta comprar, cada um com o botão que leva lá — em vez de uma mensagem
/// que desaparece ao fim de uns segundos. [preparar] (re)faz a lista de
/// compras quando ficou desligada ou falhou.
Future<void> mostrarPlanoPronto(
  BuildContext context, {
  required String planoId,
  required ResumoPlanoPronto resumo,
  required Future<ResumoPlanoPronto> Function() preparar,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) =>
        _PlanoPronto(planoId: planoId, resumo: resumo, preparar: preparar),
  );
}

class _PlanoPronto extends ConsumerStatefulWidget {
  const _PlanoPronto({
    required this.planoId,
    required this.resumo,
    required this.preparar,
  });

  final String planoId;
  final ResumoPlanoPronto resumo;
  final Future<ResumoPlanoPronto> Function() preparar;

  @override
  ConsumerState<_PlanoPronto> createState() => _PlanoProntoState();
}

class _PlanoProntoState extends ConsumerState<_PlanoPronto> {
  late ResumoPlanoPronto _resumo = widget.resumo;
  bool _ocupado = false;

  void _ir(String rota) {
    final router = GoRouter.of(context);
    Navigator.pop(context);
    router.go(rota);
  }

  Future<void> _preparar() async {
    setState(() => _ocupado = true);
    try {
      final novo = await widget.preparar();
      if (mounted) setState(() => _resumo = novo);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final fmt = ref.watch(moneyFormatProvider);
    final faltam = _resumo.compras == EstadoCompras.faltam;
    final porPreparar =
        _resumo.compras == EstadoCompras.naoPreparadas ||
        _resumo.compras == EstadoCompras.erro;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_ocupado) const LinearProgressIndicator(),
            Text('Plano de ${_resumo.rotulo} pronto', style: tt.titleLarge),
            const SizedBox(height: 12),
            _Passo(
              chave: 'passo-agendado',
              feito: true,
              titulo: 'Produção agendada',
              texto: _resumo.linhaProducao,
              botao: 'Ver produção',
              aoTocar: () => _ir('${Routes.schedule}/${widget.planoId}'),
            ),
            const SizedBox(height: 8),
            _Passo(
              chave: 'passo-compras',
              feito: _resumo.comprasEmDia,
              alerta: faltam || _resumo.compras == EstadoCompras.erro,
              titulo: 'Compras',
              texto: _resumo.linhaCompras(fmt),
              detalhe: faltam ? _resumo.nomesResumidos() : '',
              botao: porPreparar
                  ? (_ocupado ? 'A preparar…' : 'Preparar agora')
                  : faltam
                  ? 'Abrir compras'
                  : null,
              aoTocar: _ocupado
                  ? null
                  : porPreparar
                  ? _preparar
                  : faltam
                  ? () => _ir(Routes.shopping)
                  : null,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: cs.onSurface),
                child: const Text('Fechar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Passo extends StatelessWidget {
  const _Passo({
    required this.chave,
    required this.feito,
    required this.titulo,
    required this.texto,
    this.detalhe = '',
    this.alerta = false,
    this.botao,
    this.aoTocar,
  });

  final String chave;
  final bool feito;
  final bool alerta;
  final String titulo;
  final String texto;
  final String detalhe;
  final String? botao;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final cor = feito
        ? cs.primary
        : alerta
        ? cs.error
        : cs.outline;
    return Card(
      key: ValueKey(chave),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              feito ? Icons.check_circle : Icons.radio_button_unchecked,
              color: cor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: tt.titleSmall),
                  Text(texto, style: tt.bodyMedium),
                  if (detalhe.isNotEmpty)
                    Text(
                      detalhe,
                      style: tt.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (botao != null) ...[
              const SizedBox(width: 8),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: aoTocar,
                child: Text(botao!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
