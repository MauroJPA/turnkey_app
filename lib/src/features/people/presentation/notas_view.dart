import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/errors/mensagem_amigavel.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/desfazer.dart';
import '../application/notas_providers.dart';
import '../data/notas_repository.dart';
import '../domain/nota.dart';

void _atualizar(WidgetRef ref) => ref.invalidate(notasProvider);

IconData _icone(CategoriaNota c) => switch (c) {
  CategoriaNota.recado => Icons.chat_bubble_outline,
  CategoriaNota.ocorrencia => Icons.report_gmailerrorred_outlined,
  CategoriaNota.lembrete => Icons.notifications_active_outlined,
};

/// Anotações da equipa: recados, ocorrências e lembretes partilhados.
class NotasView extends ConsumerStatefulWidget {
  const NotasView({super.key});

  @override
  ConsumerState<NotasView> createState() => _NotasViewState();
}

class _NotasViewState extends ConsumerState<NotasView> {
  CategoriaNota? _categoria;
  bool _arquivadas = false;
  final _busca = TextEditingController();

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  void _erro(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
  }

  Future<void> _fazer(Future<void> Function() acao) async {
    try {
      await acao();
      _atualizar(ref);
    } on Object catch (e) {
      _erro(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(notasRepositoryProvider).utilizadorId;
    final admin = ref.watch(currentPapelProvider).canEditConfig;
    final repo = ref.read(notasRepositoryProvider);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final agora = DateTime.now();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: TextField(
            controller: _busca,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Procurar nas notas',
              isDense: true,
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('Todas'),
                  selected: _categoria == null && !_arquivadas,
                  onSelected: (_) => setState(() {
                    _categoria = null;
                    _arquivadas = false;
                  }),
                ),
              ),
              for (final c in CategoriaNota.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: Icon(_icone(c), size: 16),
                    label: Text(c.label),
                    selected: _categoria == c && !_arquivadas,
                    onSelected: (_) => setState(() {
                      _categoria = c;
                      _arquivadas = false;
                    }),
                  ),
                ),
              ChoiceChip(
                avatar: const Icon(Icons.inventory_2_outlined, size: 16),
                label: const Text('Arquivadas'),
                selected: _arquivadas,
                onSelected: (_) => setState(() => _arquivadas = !_arquivadas),
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncValueView<List<Nota>>(
            value: ref.watch(notasProvider(_arquivadas)),
            onRetry: () => ref.invalidate(notasProvider),
            data: (todasBrutas) {
              final ocultos = ref.watch(ocultosProvider);
              final todas = [
                for (final n in todasBrutas)
                  if (!ocultos.contains(n.id)) n,
              ];
              final lista = filtrarNotas(
                todas,
                categoria: _categoria,
                busca: _busca.text,
              );
              if (lista.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      _arquivadas
                          ? 'Nenhuma nota arquivada.'
                          : 'Sem notas. Toca em "Nova nota" para deixar um recado, '
                                'registar uma ocorrência ou criar um lembrete.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                itemCount: lista.length,
                itemBuilder: (_, i) {
                  final n = lista[i];
                  final minha = n.autorId == uid;
                  final podeEditar = minha || admin;
                  final hoje = n.paraHoje(agora);
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: hoje ? cs.tertiaryContainer : null,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2, right: 10),
                            child: Icon(_icone(n.categoria), size: 20),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (n.titulo.isNotEmpty)
                                  Text(n.titulo, style: tt.titleSmall),
                                Text(n.texto, style: tt.bodyMedium),
                                const SizedBox(height: 4),
                                Text(
                                  [
                                    n.categoria.label,
                                    if (n.autorNome.isNotEmpty) n.autorNome,
                                    quandoTexto(n.criada, agora),
                                    if (n.lembrarEm != null)
                                      'lembrar ${n.lembrarEm!.day}/${n.lembrarEm!.month}',
                                  ].join(' · '),
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (n.fixada)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.push_pin,
                                size: 16,
                                color: cs.primary,
                              ),
                            ),
                          PopupMenuButton<String>(
                            tooltip: 'Opções',
                            onSelected: (v) async {
                              switch (v) {
                                case 'fixar':
                                  await _fazer(
                                    () => repo.fixar(n.id, fixada: !n.fixada),
                                  );
                                case 'arquivar':
                                  await _fazer(
                                    () => repo.arquivar(
                                      n.id,
                                      arquivada: !n.arquivada,
                                    ),
                                  );
                                case 'editar':
                                  await mostrarNota(context, existente: n);
                                case 'apagar':
                                  await apagarComDesfazer(
                                    context,
                                    id: n.id,
                                    mensagem: 'Nota apagada',
                                    apagar: () => repo.apagar(n.id),
                                    depois: () => _atualizar(ref),
                                    aoFalhar: _erro,
                                  );
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'fixar',
                                child: Text(n.fixada ? 'Desafixar' : 'Fixar'),
                              ),
                              PopupMenuItem(
                                value: 'arquivar',
                                child: Text(
                                  n.arquivada
                                      ? 'Voltar às notas'
                                      : 'Arquivar (já tratada)',
                                ),
                              ),
                              if (podeEditar)
                                const PopupMenuItem(
                                  value: 'editar',
                                  child: Text('Editar'),
                                ),
                              if (podeEditar)
                                const PopupMenuItem(
                                  value: 'apagar',
                                  child: Text('Apagar'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Criar (ou editar) uma nota.
Future<void> mostrarNota(BuildContext context, {Nota? existente}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _NotaSheet(existente: existente),
  );
}

class _NotaSheet extends ConsumerStatefulWidget {
  const _NotaSheet({this.existente});

  final Nota? existente;

  @override
  ConsumerState<_NotaSheet> createState() => _NotaSheetState();
}

class _NotaSheetState extends ConsumerState<_NotaSheet> {
  late final _titulo = TextEditingController(text: widget.existente?.titulo);
  late final _texto = TextEditingController(text: widget.existente?.texto);
  late CategoriaNota _categoria =
      widget.existente?.categoria ?? CategoriaNota.recado;
  late DateTime? _lembrar = widget.existente?.lembrarEm;
  late bool _fixar = widget.existente?.fixada ?? false;
  bool _ocupado = false;

  @override
  void dispose() {
    _titulo.dispose();
    _texto.dispose();
    super.dispose();
  }

  Future<void> _escolherDia() async {
    final hoje = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _lembrar ?? hoje,
      firstDate: DateTime(hoje.year - 1),
      lastDate: DateTime(hoje.year + 3),
    );
    if (d != null) setState(() => _lembrar = d);
  }

  Future<void> _guardar() async {
    if (_texto.text.trim().isEmpty) return;
    setState(() => _ocupado = true);
    try {
      final repo = ref.read(notasRepositoryProvider);
      final lembrar = _categoria == CategoriaNota.lembrete ? _lembrar : null;
      final e = widget.existente;
      if (e == null) {
        await repo.criar(
          titulo: _titulo.text,
          texto: _texto.text,
          categoria: _categoria,
          autorNome: ref.read(currentUserNameProvider) ?? '',
          fixada: _fixar,
          lembrarEm: lembrar,
        );
      } else {
        await repo.editar(
          e.id,
          titulo: _titulo.text,
          texto: _texto.text,
          categoria: _categoria,
          lembrarEm: lembrar,
        );
      }
      _atualizar(ref);
      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      if (mounted) {
        setState(() => _ocupado = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editar = widget.existente != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    editar ? 'Editar nota' : 'Nova nota',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final c in CategoriaNota.values)
                        ChoiceChip(
                          avatar: Icon(_icone(c), size: 16),
                          label: Text(c.label),
                          selected: _categoria == c,
                          onSelected: (_) => setState(() => _categoria = c),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titulo,
                    maxLength: 120,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Título (opcional)',
                    ),
                  ),
                  TextField(
                    controller: _texto,
                    autofocus: !editar,
                    maxLength: 2000,
                    minLines: 3,
                    maxLines: 8,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Nota *'),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_categoria == CategoriaNota.lembrete)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton.icon(
                        onPressed: _escolherDia,
                        icon: const Icon(Icons.event),
                        label: Text(
                          _lembrar == null
                              ? 'Lembrar em… (aparece no Início nesse dia)'
                              : 'Lembrar a ${_lembrar!.day}/${_lembrar!.month}/${_lembrar!.year}',
                        ),
                      ),
                    ),
                  if (!editar)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Fixar no topo'),
                      value: _fixar,
                      onChanged: (v) => setState(() => _fixar = v),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _ocupado || _texto.text.trim().isEmpty ? null : _guardar,
            child: Text(editar ? 'Guardar' : 'Criar'),
          ),
        ],
      ),
    );
  }
}
