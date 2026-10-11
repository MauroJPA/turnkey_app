import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Os dispositivos que arrastam uma lista por defeito (o rato fica de fora).
const _semRato = <PointerDeviceKind>{
  PointerDeviceKind.touch,
  PointerDeviceKind.stylus,
  PointerDeviceKind.invertedStylus,
  PointerDeviceKind.trackpad,
  PointerDeviceKind.unknown,
};

/// Para listas verticais dentro de uma [RolagemHorizontal]: o rato não as
/// arrasta (ali arrasta-se o cartão, não a lista).
class SemArrastoDeRato extends StatelessWidget {
  const SemArrastoDeRato({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ScrollConfiguration(
    behavior: ScrollConfiguration.of(
      context,
    ).copyWith(dragDevices: _semRato, scrollbars: false),
    child: child,
  );
}

/// Faz uma lista horizontal (o quadro de fases) ser utilizável com o rato: no
/// telemóvel a lista já desliza com o dedo, mas no computador não havia como
/// ver o que ficava à direita.
///
///  - arrastar com o botão do rato nas zonas vazias;
///  - barra de rolagem sempre visível (também se arrasta);
///  - setas ‹ › nos lados, quando há mais para ver (só em ecrãs largos);
///  - Shift + roda do rato (do próprio Flutter).
///
/// O [child] tem de ser a lista horizontal que usa o mesmo [controller].
class RolagemHorizontal extends StatefulWidget {
  const RolagemHorizontal({
    super.key,
    required this.controller,
    required this.child,
    this.passo = 300,
    this.larguraMinimaSetas = 600,
  });

  final ScrollController controller;
  final Widget child;

  /// Quanto anda cada toque numa seta.
  final double passo;

  /// Abaixo desta largura (telemóvel) não há setas nem barra fixa.
  final double larguraMinimaSetas;

  @override
  State<RolagemHorizontal> createState() => _RolagemHorizontalState();
}

class _RolagemHorizontalState extends State<RolagemHorizontal> {
  bool _paraEsquerda = false;
  bool _paraDireita = false;

  bool _medir(ScrollMetrics m) {
    if (m.axis != Axis.horizontal) return false;
    final esq = m.pixels > m.minScrollExtent + 1;
    final dir = m.pixels < m.maxScrollExtent - 1;
    if (esq != _paraEsquerda || dir != _paraDireita) {
      setState(() {
        _paraEsquerda = esq;
        _paraDireita = dir;
      });
    }
    return false;
  }

  void _andar(double sentido) {
    final c = widget.controller;
    if (!c.hasClients) return;
    final p = c.position;
    c.animateTo(
      (p.pixels + sentido * widget.passo).clamp(
        p.minScrollExtent,
        p.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final largo = MediaQuery.sizeOf(context).width >= widget.larguraMinimaSetas;
    final base = ScrollConfiguration.of(context);

    Widget seta(bool esquerda) => Positioned(
      left: esquerda ? 6 : null,
      right: esquerda ? null : 6,
      top: 0,
      bottom: 0,
      child: Center(
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          elevation: 3,
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: esquerda ? 'Ver as fases à esquerda' : 'Ver mais fases',
            icon: Icon(esquerda ? Icons.chevron_left : Icons.chevron_right),
            onPressed: () => _andar(esquerda ? -1 : 1),
          ),
        ),
      ),
    );

    final lista = NotificationListener<Notification>(
      onNotification: (n) {
        if (n is ScrollNotification && n.depth == 0) return _medir(n.metrics);
        if (n is ScrollMetricsNotification && n.depth == 0) {
          return _medir(n.metrics);
        }
        return false;
      },
      child: ScrollConfiguration(
        behavior: base.copyWith(
          dragDevices: PointerDeviceKind.values.toSet(),
          scrollbars: false,
        ),
        child: largo
            ? Scrollbar(
                controller: widget.controller,
                thumbVisibility: true,
                interactive: true,
                child: widget.child,
              )
            : widget.child,
      ),
    );

    return Stack(
      children: [
        Positioned.fill(child: lista),
        if (largo && _paraEsquerda) seta(true),
        if (largo && _paraDireita) seta(false),
      ],
    );
  }
}
