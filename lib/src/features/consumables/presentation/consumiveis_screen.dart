import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/formatting/busca.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/help_actions.dart';
import '../../../core/widgets/sort_menu_button.dart';
import '../../inventory/domain/stock_item.dart';
import '../../inventory/presentation/stock_badge.dart';
import '../application/consumivel_providers.dart';
import '../domain/consumivel.dart';
import 'consumivel_sheet.dart';
import '../../../app/theme/cores_estado.dart';

/// Cor/etiqueta do estado da ficha de dados de segurança.
({String texto, IconData icone, Color cor}) apresentaEstadoFds(
  EstadoFds e,
  ColorScheme cs,
) => switch (e) {
  EstadoFds.ok => (
    texto: 'FDS ok',
    icone: Icons.verified_outlined,
    cor: cs.sucesso,
  ),
  EstadoFds.antiga => (
    texto: 'FDS antiga',
    icone: Icons.history,
    cor: cs.aviso,
  ),
  EstadoFds.falta => (
    texto: 'Falta FDS',
    icone: Icons.warning_amber_rounded,
    cor: cs.error,
  ),
  EstadoFds.naoExige => (
    texto: 'Sem FDS',
    icone: Icons.remove_circle_outline,
    cor: cs.outline,
  ),
};

class ConsumiveisScreen extends ConsumerStatefulWidget {
  const ConsumiveisScreen({super.key, this.embedded = false});

  /// Dentro da página Inventário: sem seta de voltar, título nem ajuda.
  final bool embedded;

  @override
  ConsumerState<ConsumiveisScreen> createState() => _ConsumiveisScreenState();
}

class _ConsumiveisScreenState extends ConsumerState<ConsumiveisScreen> {
  String _pesquisa = '';
  String? _categoria;
  bool _soPendentes = false;

  static final List<SortOption<(Consumivel, EstadoFds)>> _sortOptions = [
    SortOption<(Consumivel, EstadoFds)>(
      'Nome',
      (a, b) => a.$1.nome.toLowerCase().compareTo(b.$1.nome.toLowerCase()),
    ),
    SortOption<(Consumivel, EstadoFds)>(
      'Estado FDS',
      (a, b) => a.$2.index.compareTo(b.$2.index),
    ),
  ];
  int _sortIndex = 0;
  bool _sortAsc = true;

  bool get _podeEditar => ref.read(currentPapelProvider).canEditBusiness;

  Future<void> _apagar(Consumivel c) async {
    final ok = await confirmDialog(
      context,
      titulo: 'Apagar produto?',
      mensagem:
          'Remove "${c.nome}" da lista, com os documentos anexados. Uma fatura '
          'já aplicada não muda.',
      confirmar: 'Apagar',
      destrutivo: true,
    );
    if (!ok) return;
    try {
      await ref.read(consumivelActionsProvider).apagar(c.id);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível apagar.')),
        );
      }
    }
  }

  /// Registo em texto (CSV) para a fiscalização: o que existe e o que falta.
  String _registoCsv(List<Consumivel> cs, List<DocumentoConsumivel> docs) {
    String c(String s) => '"${s.replaceAll('"', '""')}"';
    String d(DateTime? v) => v == null
        ? ''
        : '${v.day.toString().padLeft(2, '0')}/${v.month.toString().padLeft(2, '0')}/${v.year}';
    final linhas = <String>[
      'Produto;Categoria;Marca;Fornecedor;Exige FDS;Estado FDS;'
          'Versão FDS;Data FDS;Nº documentos',
    ];
    for (final x in cs) {
      final meus = docs.where((y) => y.consumivelId == x.id).toList();
      final fds = meus.where((y) => y.tipo == TipoDocumento.fds).toList()
        ..sort(
          (a, b) => (b.dataEfetiva ?? DateTime(0)).compareTo(
            a.dataEfetiva ?? DateTime(0),
          ),
        );
      final est = apresentaEstadoFds(
        estadoFds(x, meus),
        Theme.of(context).colorScheme,
      );
      linhas.add(
        [
          c(x.nome),
          c(x.categoria),
          c(x.marca),
          c(x.fornecedor),
          x.exigeFds ? 'Sim' : 'Não',
          c(est.texto),
          c(fds.isEmpty ? '' : fds.first.versao),
          d(fds.isEmpty ? null : fds.first.dataEfetiva),
          '${meus.length}',
        ].join(';'),
      );
    }
    return linhas.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(consumiveisListProvider);
    final docs =
        ref.watch(consumivelDocumentosProvider).valueOrNull ?? const [];
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: widget.embedded ? 48 : null,
        leading: widget.embedded
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go(Routes.home),
              ),
        title: widget.embedded ? null : const Text('Limpeza e insumos'),
        actions: [
          SortMenuButton<(Consumivel, EstadoFds)>(
            options: _sortOptions,
            selectedIndex: _sortIndex,
            ascending: _sortAsc,
            onChanged: (i, asc) => setState(() {
              _sortIndex = i;
              _sortAsc = asc;
            }),
          ),
          IconButton(
            tooltip: 'Copiar registo (CSV)',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: () {
              final lista = async.valueOrNull ?? const <Consumivel>[];
              Clipboard.setData(ClipboardData(text: _registoCsv(lista, docs)));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Registo copiado.')));
            },
          ),
          if (!widget.embedded)
            const HelpActions(topic: HelpTopic.consumiveis),
        ],
      ),
      floatingActionButton: _podeEditar
          ? FloatingActionButton.extended(
              onPressed: () => abrirConsumivelSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Produto'),
            )
          : null,
      body: AsyncValueView<List<Consumivel>>(
        value: async,
        onRetry: () => ref.invalidate(consumiveisListProvider),
        data: (todos) {
          if (todos.isEmpty) {
            return const EmptyState(
              icon: Icons.cleaning_services_outlined,
              titulo: 'Sem produtos',
              mensagem:
                  'Produtos de limpeza, desinfeção e insumos (com fichas de '
                  'dados de segurança) e também bebidas ou outra revenda '
                  '(com preço de venda) — tudo o que compras sem ser para as '
                  'receitas.',
            );
          }
          int pendentes = 0;
          final linhas = <(Consumivel, EstadoFds)>[];
          final categoriasEmUso =
              todos
                  .map((x) => x.categoria)
                  .where((c) => c.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();
          for (final x in todos) {
            final e = estadoFds(x, docs.where((d) => d.consumivelId == x.id));
            if (e == EstadoFds.falta || e == EstadoFds.antiga) pendentes++;
            if (!correspondeABusca(
              '${x.nome} ${x.caracteristica} ${x.marca} ${x.fornecedor}',
              _pesquisa,
            )) {
              continue;
            }
            if (_categoria != null && x.categoria != _categoria) continue;
            if (_soPendentes && e != EstadoFds.falta && e != EstadoFds.antiga) {
              continue;
            }
            linhas.add((x, e));
          }
          final linhasOrdenadas = ordenarPor(
            linhas,
            _sortOptions[_sortIndex],
            _sortAsc,
          );
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Pesquisar',
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _pesquisa = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  spacing: 6,
                  children: [
                    FilterChip(
                      label: Text('A precisar de FDS ($pendentes)'),
                      selected: _soPendentes,
                      onSelected: (v) => setState(() => _soPendentes = v),
                    ),
                    for (final c in categoriasEmUso)
                      FilterChip(
                        label: Text(c),
                        selected: _categoria == c,
                        onSelected: (v) =>
                            setState(() => _categoria = v ? c : null),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: linhasOrdenadas.isEmpty
                    ? const Center(child: Text('Nada com estes filtros.'))
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 88),
                        itemCount: linhasOrdenadas.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final (x, e) = linhasOrdenadas[i];
                          final ap = apresentaEstadoFds(e, cs);
                          final nDocs = docs
                              .where((d) => d.consumivelId == x.id)
                              .length;
                          return ListTile(
                            title: Text(x.nomeComCaracteristica),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  [
                                    x.categoria,
                                    if (x.marca.isNotEmpty) x.marca,
                                    if (x.fornecedor.isNotEmpty) x.fornecedor,
                                    if (x.temPrecoVenda)
                                      'venda € ${x.precoVenda.toStringAsFixed(2)}',
                                    '$nDocs doc.',
                                  ].join(' · '),
                                ),
                                StockBadge(
                                  tipo: StockTipo.consumivel,
                                  id: x.id,
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Chip(
                                  avatar: Icon(
                                    ap.icone,
                                    size: 16,
                                    color: ap.cor,
                                  ),
                                  label: Text(
                                    ap.texto,
                                    style: TextStyle(color: ap.cor),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                if (_podeEditar)
                                  IconButton(
                                    tooltip: 'Apagar produto',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _apagar(x),
                                  ),
                              ],
                            ),
                            onTap: () =>
                                abrirConsumivelSheet(context, existente: x),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
