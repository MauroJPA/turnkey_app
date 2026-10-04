import 'package:flutter/material.dart';

/// Quantidade com botão de menos, o número (que também se pode escrever) e
/// botão de mais — grande o bastante para tocar depressa no telemóvel.
class QuantidadeStepper extends StatefulWidget {
  const QuantidadeStepper({
    super.key,
    required this.valor,
    required this.onChanged,
    this.passo = 1,
    this.min = 0,
    this.max = 100000,
    this.largura = 56,
    this.destaque = false,
  });

  final double valor;
  final ValueChanged<double> onChanged;
  final double passo;
  final double min;
  final double max;
  final double largura;

  /// Pinta o número (ex.: quando já foi alterado).
  final bool destaque;

  @override
  State<QuantidadeStepper> createState() => _QuantidadeStepperState();
}

String _txt(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

class _QuantidadeStepperState extends State<QuantidadeStepper> {
  late final TextEditingController _ctrl = TextEditingController(
    text: _txt(widget.valor),
  );
  final _foco = FocusNode();

  /// O valor atual aqui dentro: vários toques seguidos somam mesmo antes de o
  /// ecrã de cima se reconstruir.
  late double _v = widget.valor;

  @override
  void didUpdateWidget(covariant QuantidadeStepper old) {
    super.didUpdateWidget(old);
    // valor mudado de fora (ex.: "tudo como esperado", limpar depois de guardar)
    if (widget.valor != _v) {
      _v = widget.valor;
      if (!_foco.hasFocus) _ctrl.text = _txt(_v);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _foco.dispose();
    super.dispose();
  }

  void _mudar(double delta) {
    final novo = (_v + delta).clamp(widget.min, widget.max).toDouble();
    setState(() => _v = novo);
    _ctrl.text = _txt(novo);
    widget.onChanged(novo);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const botao = Size(44, 44);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          tooltip: 'Menos',
          constraints: BoxConstraints.tight(botao),
          padding: EdgeInsets.zero,
          onPressed: _v <= widget.min ? null : () => _mudar(-widget.passo),
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: widget.largura,
          child: TextField(
            controller: _ctrl,
            focusNode: _foco,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: widget.destaque ? cs.primary : null,
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
            onTap: () => _ctrl.selection = TextSelection(
              baseOffset: 0,
              extentOffset: _ctrl.text.length,
            ),
            onChanged: (t) {
              final v = double.tryParse(t.trim().replaceAll(',', '.'));
              if (v != null && v >= widget.min) {
                setState(() => _v = v.clamp(widget.min, widget.max).toDouble());
                widget.onChanged(_v);
              } else if (t.trim().isEmpty) {
                setState(() => _v = widget.min);
                widget.onChanged(widget.min);
              }
            },
          ),
        ),
        IconButton.filled(
          tooltip: 'Mais',
          constraints: BoxConstraints.tight(botao),
          padding: EdgeInsets.zero,
          onPressed: _v >= widget.max ? null : () => _mudar(widget.passo),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
