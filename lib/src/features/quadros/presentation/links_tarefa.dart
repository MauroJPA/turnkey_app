import 'package:flutter/material.dart';

import '../../../core/widgets/desfazer.dart';
import '../domain/quadro.dart';
import 'descricao_com_links.dart';

/// O máximo de links por tarefa.
const maxLinksTarefa = 20;

/// Os links de uma tarefa: cada um é um botão com o título; toca para abrir.
/// "Link" junta um novo (título + endereço); manter o dedo/botão num link
/// edita-o; o × tira (com Desfazer).
class LinksTarefa extends StatelessWidget {
  const LinksTarefa({
    super.key,
    required this.links,
    required this.pode,
    required this.onMudou,
    this.abrir,
  });

  final List<LinkTarefa> links;
  final bool pode;
  final ValueChanged<List<LinkTarefa>> onMudou;

  /// Para os testes; por defeito abre no navegador.
  final Future<bool> Function(String url)? abrir;

  Future<void> _abrir(BuildContext context, LinkTarefa l) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await (abrir ?? abrirEndereco)(l.url);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o link.')),
      );
    }
  }

  Future<void> _editar(BuildContext context, {int? indice}) async {
    final atual = indice == null ? null : links[indice];
    final novo = await showDialog<LinkTarefa>(
      context: context,
      builder: (_) => _DialogoLink(inicial: atual),
    );
    if (novo == null) return;
    final l = [...links];
    if (indice == null) {
      l.add(novo);
    } else {
      l[indice] = novo;
    }
    onMudou(l);
  }

  void _tirar(BuildContext context, int i) {
    final antes = [...links];
    onMudou([
      for (var k = 0; k < links.length; k++)
        if (k != i) links[k],
    ]);
    mostrarDesfazer(
      context,
      mensagem: 'Link tirado.',
      desfazer: () async => onMudou(antes),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < links.length; i++)
          GestureDetector(
            onLongPress: pode ? () => _editar(context, indice: i) : null,
            child: InputChip(
              avatar: const Icon(Icons.link, size: 18),
              label: Text(links[i].titulo, overflow: TextOverflow.ellipsis),
              tooltip: links[i].url,
              onPressed: () => _abrir(context, links[i]),
              onDeleted: pode ? () => _tirar(context, i) : null,
            ),
          ),
        if (pode && links.length < maxLinksTarefa)
          ActionChip(
            avatar: const Icon(Icons.add, size: 16),
            label: const Text('Link'),
            onPressed: () => _editar(context),
          ),
        if (!pode && links.isEmpty)
          Text('Sem links', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Pede o título e o endereço de um link.
class _DialogoLink extends StatefulWidget {
  const _DialogoLink({this.inicial});

  final LinkTarefa? inicial;

  @override
  State<_DialogoLink> createState() => _DialogoLinkState();
}

class _DialogoLinkState extends State<_DialogoLink> {
  late final _titulo = TextEditingController(text: widget.inicial?.titulo);
  late final _url = TextEditingController(text: widget.inicial?.url);
  String? _erro;

  @override
  void dispose() {
    _titulo.dispose();
    _url.dispose();
    super.dispose();
  }

  void _guardar() {
    final url = normalizarUrl(_url.text);
    if (url == null) {
      setState(
        () =>
            _erro = 'Escreve um endereço válido, por exemplo exemplo.pt/pagina',
      );
      return;
    }
    final t = _titulo.text.trim();
    Navigator.pop(context, LinkTarefa(t.isEmpty ? nomeDoSitio(url) : t, url));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.inicial == null ? 'Novo link' : 'Editar o link'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titulo,
            autofocus: true,
            maxLength: 60,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'O que é',
              hintText: 'Ex.: Fatura do fornecedor',
              counterText: '',
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: 'Endereço',
              hintText: 'https://…',
              errorText: _erro,
            ),
            onChanged: (_) {
              if (_erro != null) setState(() => _erro = null);
            },
            onSubmitted: (_) => _guardar(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}
