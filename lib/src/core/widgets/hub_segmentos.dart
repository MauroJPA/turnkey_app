import 'package:flutter/material.dart';

/// Um pequeno aviso ao lado do nome de uma secção ("2", "↑3").
typedef EmblemaSegmento = ({String texto, bool alerta});

/// Os separadores de uma página com várias secções (Contabilidade, Pessoas,
/// Inventário, Produção): poucos, do mesmo tamanho e sempre todos à vista —
/// sem deslizar para os encontrar. O que sobra fica num "Mais ▾".
class HubSegmentos<T> extends StatelessWidget {
  const HubSegmentos({
    super.key,
    required this.principais,
    required this.atual,
    required this.rotulo,
    required this.icone,
    required this.aoEscolher,
    this.extras = const [],
    this.emblema,
  });

  /// As secções sempre à vista.
  final List<T> principais;

  /// As outras: abrem num menu "Mais ▾".
  final List<T> extras;
  final T atual;
  final String Function(T) rotulo;
  final IconData Function(T) icone;
  final void Function(T) aoEscolher;
  final EmblemaSegmento? Function(T)? emblema;

  @override
  Widget build(BuildContext context) {
    final extraAtual = extras.contains(atual) ? atual : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          for (var i = 0; i < principais.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                child: _Segmento(
                  key: ValueKey('seg-${rotulo(principais[i])}'),
                  texto: rotulo(principais[i]),
                  selecionado: principais[i] == atual,
                  emblema: emblema?.call(principais[i]),
                  aoTocar: () {
                    if (principais[i] != atual) aoEscolher(principais[i]);
                  },
                ),
              ),
            ),
          if (extras.isNotEmpty)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: PopupMenuButton<T>(
                  key: const ValueKey('seg-mais'),
                  tooltip: 'Mais secções',
                  position: PopupMenuPosition.under,
                  onSelected: (s) {
                    if (s != atual) aoEscolher(s);
                  },
                  itemBuilder: (_) => [
                    for (final s in extras)
                      PopupMenuItem<T>(
                        value: s,
                        child: Row(
                          children: [
                            Icon(icone(s), size: 20),
                            const SizedBox(width: 12),
                            Expanded(child: Text(rotulo(s))),
                            if (s == atual) const Icon(Icons.check, size: 18),
                          ],
                        ),
                      ),
                  ],
                  child: _Segmento(
                    texto: extraAtual == null ? 'Mais' : rotulo(extraAtual),
                    selecionado: extraAtual != null,
                    sufixo: Icons.arrow_drop_down,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segmento extends StatelessWidget {
  const _Segmento({
    super.key,
    required this.texto,
    required this.selecionado,
    this.aoTocar,
    this.emblema,
    this.sufixo,
  });

  final String texto;
  final bool selecionado;
  final VoidCallback? aoTocar;
  final EmblemaSegmento? emblema;
  final IconData? sufixo;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final corTexto = selecionado ? cs.onSecondaryContainer : cs.onSurface;
    final conteudo = Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              texto,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.1,
                color: corTexto,
                fontWeight: selecionado ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          if (emblema != null) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: emblema!.alerta ? cs.error : cs.outline,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                emblema!.texto,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: emblema!.alerta ? cs.onError : cs.surface,
                ),
              ),
            ),
          ],
          if (sufixo != null) Icon(sufixo, size: 18, color: corTexto),
        ],
      ),
    );
    return Material(
      color: selecionado ? cs.secondaryContainer : cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: aoTocar == null
          ? conteudo
          : InkWell(onTap: aoTocar, child: conteudo),
    );
  }
}
