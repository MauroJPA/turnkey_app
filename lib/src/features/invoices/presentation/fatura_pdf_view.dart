import 'package:flutter/material.dart';

import '../data/pdf_para_imagens.dart';
import 'fatura_zoom_view.dart';

/// Guarda os PDFs já convertidos (por fatura) para não converter de novo ao
/// abrir o ecrã inteiro ou ao voltar à revisão. No máximo 3 em memória.
final _convertidos = <String, Future<PdfConvertido>>{};

Future<PdfConvertido> _converter(String chave, String url) {
  final existente = _convertidos[chave];
  if (existente != null) return existente;
  if (_convertidos.length >= 3) _convertidos.remove(_convertidos.keys.first);
  final f = converterPdfEmImagens(url);
  _convertidos[chave] = f;
  // uma falha não fica guardada: da próxima vez tenta de novo
  f.then<void>((_) {}, onError: (_) => _convertidos.remove(chave));
  return f;
}

/// A fatura em PDF mostrada dentro da app: cada página vira uma imagem com o
/// mesmo zoom das fotos (pinça, duplo toque, botões). Com várias páginas,
/// aparecem as setas para passar de uma à outra. Se o PDF não abrir, mostra
/// [alternativa] (o cartão "Abrir PDF").
class FaturaPdfView extends StatefulWidget {
  const FaturaPdfView({
    super.key,
    required this.chave,
    required this.url,
    required this.alternativa,
    this.aoTelaCheia,
    this.aoAbrirFora,
  });

  /// Identifica a fatura (o endereço muda de cada vez: leva um token).
  final String chave;
  final String url;
  final Widget alternativa;
  final VoidCallback? aoTelaCheia;

  /// Abrir o PDF no leitor do telemóvel (o original, em boa qualidade).
  final VoidCallback? aoAbrirFora;

  @override
  State<FaturaPdfView> createState() => _FaturaPdfViewState();
}

class _FaturaPdfViewState extends State<FaturaPdfView> {
  late final Future<PdfConvertido> _futuro = _converter(
    widget.chave,
    widget.url,
  );
  int _pagina = 0;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PdfConvertido>(
      future: _futuro,
      builder: (context, snap) {
        if (snap.hasError || (snap.hasData && snap.data!.imagens.isEmpty)) {
          return widget.alternativa;
        }
        if (!snap.hasData) {
          return Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('A preparar o PDF…'),
              ],
            ),
          );
        }
        final pdf = snap.data!;
        final n = pdf.imagens.length;
        final i = _pagina.clamp(0, n - 1);
        return Stack(
          children: [
            Positioned.fill(
              child: FaturaZoomView(
                // outra página = outro visualizador (zoom do zero)
                key: ValueKey('pdf-pagina-$i'),
                bytes: pdf.imagens[i],
                aoTelaCheia: widget.aoTelaCheia,
              ),
            ),
            if (n > 1 || widget.aoAbrirFora != null)
              Positioned(
                left: 6,
                bottom: 6,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (n > 1) ...[
                        IconButton(
                          key: const ValueKey('pdf-anterior'),
                          tooltip: 'Página anterior',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.chevron_left,
                            color: Colors.white,
                          ),
                          onPressed: i > 0
                              ? () => setState(() => _pagina = i - 1)
                              : null,
                        ),
                        Text(
                          'Pág. ${i + 1}/${pdf.paginas}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('pdf-seguinte'),
                          tooltip: 'Página seguinte',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                          ),
                          onPressed: i < n - 1
                              ? () => setState(() => _pagina = i + 1)
                              : null,
                        ),
                      ],
                      if (widget.aoAbrirFora != null)
                        IconButton(
                          key: const ValueKey('pdf-abrir-fora'),
                          tooltip: 'Abrir o PDF no leitor do telemóvel',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.open_in_new,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: widget.aoAbrirFora,
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
