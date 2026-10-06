import 'package:flutter/material.dart';

/// A foto da fatura com zoom: pinça com dois dedos, arrastar para andar pela
/// imagem, duplo toque para ampliar/repor e botões + − (úteis no computador).
/// Com [aoTelaCheia], mostra também o botão de ecrã inteiro.
class FaturaZoomView extends StatefulWidget {
  const FaturaZoomView({super.key, required this.url, this.aoTelaCheia});

  final String url;
  final VoidCallback? aoTelaCheia;

  @override
  State<FaturaZoomView> createState() => _FaturaZoomViewState();
}

class _FaturaZoomViewState extends State<FaturaZoomView> {
  static const _maxEscala = 8.0;
  static const _escalaDuploToque = 2.5;

  final _ctrl = TransformationController();
  Offset _ultimoToque = Offset.zero;
  Size _area = Size.zero;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double get _escala => _ctrl.value.getMaxScaleOnAxis();

  /// Multiplica o zoom por [fator] à volta de [centro] (coordenadas do
  /// visualizador); abaixo de 1× repõe a imagem inteira.
  void _zoom(double fator, Offset centro) {
    final alvo = (_escala * fator).clamp(1.0, _maxEscala);
    if (alvo <= 1.01) {
      _ctrl.value = Matrix4.identity();
      return;
    }
    final f = alvo / _escala;
    final m = Matrix4.identity()
      ..translateByDouble(centro.dx, centro.dy, 0, 1)
      ..scaleByDouble(f, f, 1, 1)
      ..translateByDouble(-centro.dx, -centro.dy, 0, 1);
    _ctrl.value = m * _ctrl.value;
  }

  void _duploToque() {
    if (_escala > 1.05) {
      _ctrl.value = Matrix4.identity();
    } else {
      _zoom(_escalaDuploToque, _ultimoToque);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, c) {
        _area = Size(c.maxWidth, c.maxHeight);
        final centro = Offset(_area.width / 2, _area.height / 2);
        return Container(
          color: cs.surfaceContainerHighest,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onDoubleTapDown: (d) => _ultimoToque = d.localPosition,
                  onDoubleTap: _duploToque,
                  child: InteractiveViewer(
                    transformationController: _ctrl,
                    maxScale: _maxEscala,
                    child: SizedBox(
                      width: _area.width,
                      height: _area.height,
                      child: Image.network(
                        widget.url,
                        fit: BoxFit.contain,
                        loadingBuilder: (ctx, child, prog) => prog == null
                            ? child
                            : const Center(child: CircularProgressIndicator()),
                        errorBuilder: (ctx, e, s) => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Não foi possível carregar a imagem da fatura.',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 6,
                bottom: 6,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Botao(
                      chave: 'fatura-zoom-mais',
                      icon: Icons.add,
                      dica: 'Ampliar',
                      aoTocar: () => _zoom(1.6, centro),
                    ),
                    const SizedBox(height: 4),
                    _Botao(
                      chave: 'fatura-zoom-menos',
                      icon: Icons.remove,
                      dica: 'Reduzir',
                      aoTocar: () => _zoom(1 / 1.6, centro),
                    ),
                    if (widget.aoTelaCheia != null) ...[
                      const SizedBox(height: 4),
                      _Botao(
                        chave: 'fatura-tela-cheia',
                        icon: Icons.fullscreen,
                        dica: 'Ecrã inteiro',
                        aoTocar: widget.aoTelaCheia!,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Botao extends StatelessWidget {
  const _Botao({
    required this.chave,
    required this.icon,
    required this.dica,
    required this.aoTocar,
  });

  final String chave;
  final IconData icon;
  final String dica;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black.withValues(alpha: 0.55),
    shape: const CircleBorder(),
    child: IconButton(
      key: ValueKey(chave),
      tooltip: dica,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, color: Colors.white, size: 20),
      onPressed: aoTocar,
    ),
  );
}
