import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/quadro.dart';

/// Abre um endereço (http/https) fora da app; `false` se não foi possível.
Future<bool> abrirEndereco(String url) async {
  final seguro = normalizarUrl(url);
  if (seguro == null) return false;
  try {
    return await launchUrl(
      Uri.parse(seguro),
      mode: LaunchMode.externalApplication,
    );
  } on Object {
    return false;
  }
}

/// A descrição de uma tarefa. Enquanto não se está a escrever e o texto tem
/// endereços (http://, https://, www.), mostra-os clicáveis; tocar no texto
/// (ou no lápis) volta ao campo para editar. Sem endereços é só o campo normal.
class DescricaoComLinks extends StatefulWidget {
  const DescricaoComLinks({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onChanged,
    this.hint = '',
    this.abrir,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onChanged;
  final String hint;

  /// Para os testes; por defeito abre no navegador.
  final Future<bool> Function(String url)? abrir;

  @override
  State<DescricaoComLinks> createState() => _DescricaoComLinksState();
}

class _DescricaoComLinksState extends State<DescricaoComLinks> {
  final _foco = FocusNode();
  final _gestos = <TapGestureRecognizer>[];
  bool _editar = false;

  @override
  void initState() {
    super.initState();
    _foco.addListener(() {
      if (!_foco.hasFocus && _editar && mounted) {
        setState(() => _editar = false);
      }
    });
  }

  @override
  void dispose() {
    _soltarGestos();
    _foco.dispose();
    super.dispose();
  }

  void _soltarGestos() {
    for (final g in _gestos) {
      g.dispose();
    }
    _gestos.clear();
  }

  Future<void> _abrir(String url) async {
    final ok = await (widget.abrir ?? abrirEndereco)(url);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final trechos = trechosComLinks(widget.controller.text);
        final temLinks = trechos.any((t) => t.url != null);
        final ver = temLinks && (!_editar || !widget.enabled);
        if (!ver) {
          return TextField(
            controller: widget.controller,
            focusNode: _foco,
            autofocus: _editar,
            enabled: widget.enabled,
            minLines: 2,
            maxLines: 12,
            maxLength: 5000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: widget.hint, counterText: ''),
            onChanged: (_) => widget.onChanged(),
          );
        }

        _soltarGestos();
        final cs = Theme.of(context).colorScheme;
        final estilo = Theme.of(context).textTheme.bodyLarge;
        final spans = <InlineSpan>[
          for (final t in trechos)
            if (t.url == null)
              TextSpan(text: t.texto)
            else
              TextSpan(
                text: t.texto,
                mouseCursor: SystemMouseCursors.click,
                style: TextStyle(
                  color: cs.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: cs.primary,
                ),
                recognizer: (TapGestureRecognizer()
                  ..onTap = () => _abrir(t.url!)),
              ),
        ];
        // os reconhecedores têm de ser libertados quando a vista muda
        for (final s in spans) {
          if (s is TextSpan && s.recognizer is TapGestureRecognizer) {
            _gestos.add(s.recognizer! as TapGestureRecognizer);
          }
        }

        final texto = Text.rich(TextSpan(style: estilo, children: spans));
        return InputDecorator(
          isEmpty: false,
          decoration: InputDecoration(
            suffixIcon: widget.enabled
                ? IconButton(
                    tooltip: 'Editar a descrição',
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => setState(() => _editar = true),
                  )
                : null,
          ),
          child: widget.enabled
              ? InkWell(
                  onTap: () => setState(() => _editar = true),
                  child: texto,
                )
              : texto,
        );
      },
    );
  }
}
