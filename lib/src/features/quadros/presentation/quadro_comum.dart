import 'package:flutter/material.dart';

import '../domain/quadro.dart';

/// Cores das etiquetas (escuras o suficiente para letra branca, nos dois modos).
const coresEtiqueta = <Color>[
  Color(0xFF2E6B45), // verde
  Color(0xFF9A5B12), // âmbar
  Color(0xFFB3392F), // vermelho
  Color(0xFF1F5F8B), // azul
  Color(0xFF6B4C9A), // roxo
  Color(0xFF1E6F6A), // turquesa
  Color(0xFF8F5E36), // caramelo
  Color(0xFF4A5560), // ardósia
];

Color corDaEtiqueta(String nome) => coresEtiqueta[corEtiqueta(nome)];

/// Uma etiqueta colorida ("Urgente").
class EtiquetaPilula extends StatelessWidget {
  const EtiquetaPilula(
    this.nome, {
    super.key,
    this.pequena = false,
    this.onApagar,
  });

  final String nome;
  final bool pequena;
  final VoidCallback? onApagar;

  @override
  Widget build(BuildContext context) {
    final estilo =
        (pequena
                ? Theme.of(context).textTheme.labelSmall
                : Theme.of(context).textTheme.labelMedium)
            ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: pequena ? 6 : 10,
        vertical: pequena ? 1 : 4,
      ),
      decoration: BoxDecoration(
        color: corDaEtiqueta(nome),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(nome, style: estilo, overflow: TextOverflow.ellipsis),
          ),
          if (onApagar != null) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: onApagar,
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bolinha com as iniciais de uma pessoa.
class AvatarPessoa extends StatelessWidget {
  const AvatarPessoa(this.pessoa, {super.key, this.raio = 12});

  final PessoaEquipa pessoa;
  final double raio;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: pessoa.nome,
      child: CircleAvatar(
        radius: raio,
        backgroundColor: cs.primaryContainer,
        foregroundColor: cs.onPrimaryContainer,
        child: Text(
          pessoa.iniciais,
          style: TextStyle(fontSize: raio * 0.8, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Até 3 bolinhas sobrepostas (+N) dos responsáveis.
class AvataresResponsaveis extends StatelessWidget {
  const AvataresResponsaveis(this.pessoas, {super.key});

  final List<PessoaEquipa> pessoas;

  @override
  Widget build(BuildContext context) {
    if (pessoas.isEmpty) return const SizedBox.shrink();
    final mostrar = pessoas.take(3).toList();
    final extra = pessoas.length - mostrar.length;
    const passo = 16.0;
    return SizedBox(
      height: 24,
      width: passo * (mostrar.length - 1) + 24 + (extra > 0 ? 22 : 0),
      child: Stack(
        children: [
          for (var i = 0; i < mostrar.length; i++)
            Positioned(
              left: i * passo,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).cardColor,
                    width: 1.5,
                  ),
                ),
                child: AvatarPessoa(mostrar[i], raio: 11),
              ),
            ),
          if (extra > 0)
            Positioned(
              right: 0,
              top: 4,
              child: Text(
                '+$extra',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
        ],
      ),
    );
  }
}

/// Texto com as "@menções" a negrito, na cor de destaque.
class TextoComMencoes extends StatelessWidget {
  const TextoComMencoes(
    this.texto, {
    super.key,
    required this.pessoas,
    this.style,
  });

  final String texto;
  final List<PessoaEquipa> pessoas;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final nomes = [
      for (final p in pessoas)
        if (p.nome.trim().isNotEmpty) ...[p.nome.trim(), p.primeiroNome],
    ]..sort((a, b) => b.length.compareTo(a.length));
    final destaque = TextStyle(
      fontWeight: FontWeight.w700,
      color: Theme.of(context).colorScheme.primary,
    );
    final partes = <TextSpan>[];
    var i = 0;
    var inicio = 0;
    final baixo = semAcentos(texto.toLowerCase());
    while (i < texto.length) {
      final antesOk = i == 0 || !RegExp(r'[A-Za-z0-9_]').hasMatch(texto[i - 1]);
      if (texto[i] == '@' && antesOk) {
        String? achado;
        for (final n in nomes) {
          final k = semAcentos(n.toLowerCase());
          if (k.isEmpty || !baixo.startsWith(k, i + 1)) continue;
          final fim = i + 1 + k.length;
          if (fim < texto.length &&
              RegExp(r'[A-Za-z0-9_]').hasMatch(baixo[fim])) {
            continue;
          }
          achado = texto.substring(i, fim);
          break;
        }
        if (achado != null) {
          if (i > inicio) {
            partes.add(TextSpan(text: texto.substring(inicio, i)));
          }
          partes.add(TextSpan(text: achado, style: destaque));
          i += achado.length;
          inicio = i;
          continue;
        }
      }
      i++;
    }
    if (inicio < texto.length) {
      partes.add(TextSpan(text: texto.substring(inicio)));
    }
    return Text.rich(TextSpan(children: partes), style: style);
  }
}

/// Campo de texto que sugere pessoas ao escrever "@" (toca no nome para o
/// pôr). As menções ficam no próprio texto ("@Ana Silva").
class CampoMencoes extends StatefulWidget {
  const CampoMencoes({
    super.key,
    required this.controller,
    required this.pessoas,
    this.focusNode,
    this.hint,
    this.onSubmitted,
    this.minLines = 1,
    this.maxLines = 5,
    this.enabled = true,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final List<PessoaEquipa> pessoas;
  final FocusNode? focusNode;
  final String? hint;
  final VoidCallback? onSubmitted;
  final int minLines;
  final int maxLines;
  final bool enabled;
  final bool autofocus;

  @override
  State<CampoMencoes> createState() => _CampoMencoesState();
}

class _CampoMencoesState extends State<CampoMencoes> {
  List<PessoaEquipa> _sugestoes = const [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rever);
  }

  @override
  void didUpdateWidget(CampoMencoes old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_rever);
      widget.controller.addListener(_rever);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rever);
    super.dispose();
  }

  void _rever() {
    final c = widget.controller;
    final cursor = c.selection.baseOffset < 0
        ? c.text.length
        : c.selection.baseOffset;
    final parcial = mencaoAEscrever(c.text, cursor);
    final novas = parcial == null
        ? const <PessoaEquipa>[]
        : sugerirPessoas(widget.pessoas, parcial);
    if (novas.length != _sugestoes.length ||
        !Iterable.generate(
          novas.length,
        ).every((i) => novas[i].id == _sugestoes[i].id)) {
      setState(() => _sugestoes = novas);
    }
  }

  void _escolher(PessoaEquipa p) {
    final c = widget.controller;
    final cursor = c.selection.baseOffset < 0
        ? c.text.length
        : c.selection.baseOffset;
    final r = inserirMencao(c.text, cursor, p);
    c.value = TextEditingValue(
      text: r.texto,
      selection: TextSelection.collapsed(offset: r.cursor),
    );
    widget.focusNode?.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_sugestoes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in _sugestoes)
                  ActionChip(
                    avatar: AvatarPessoa(p, raio: 10),
                    label: Text(p.nome),
                    onPressed: () => _escolher(p),
                  ),
              ],
            ),
          ),
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: widget.hint, isDense: true),
          onSubmitted: widget.onSubmitted == null
              ? null
              : (_) => widget.onSubmitted!(),
        ),
      ],
    );
  }
}
