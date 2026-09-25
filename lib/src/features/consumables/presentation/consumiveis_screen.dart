import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/help_actions.dart';
import '../application/consumivel_providers.dart';
import '../domain/consumivel.dart';
import 'consumivel_sheet.dart';

/// Cor/etiqueta do estado da ficha de dados de segurança.
({String texto, IconData icone, Color cor}) apresentaEstadoFds(
  EstadoFds e,
  ColorScheme cs,
) => switch (e) {
  EstadoFds.ok => (
    texto: 'FDS ok',
    icone: Icons.verified_outlined,
    cor: Colors.green.shade700,
  ),
  EstadoFds.antiga => (
    texto: 'FDS antiga',
    icone: Icons.history,
    cor: Colors.orange.shade800,
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
  const ConsumiveisScreen({super.key});

  @override
  ConsumerState<ConsumiveisScreen> createState() => _ConsumiveisScreenState();
}

class _ConsumiveisScreenState extends ConsumerState<ConsumiveisScreen> {
  String _pesquisa = '';
  CategoriaConsumivel? _categoria;
  bool _soPendentes = false;

  bool get _podeEditar => ref.read(currentPapelProvider).canEditBusiness;

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
          c(x.categoria.label),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
        title: const Text('Limpeza e insumos'),
        actions: [
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
                  'Produtos de limpeza, desinfeção e outros insumos, com as '
                  'fichas de dados de segurança e outros documentos '
                  'anexados, prontos para a fiscalização.',
            );
          }
          int pendentes = 0;
          final linhas = <(Consumivel, EstadoFds)>[];
          for (final x in todos) {
            final e = estadoFds(x, docs.where((d) => d.consumivelId == x.id));
            if (e == EstadoFds.falta || e == EstadoFds.antiga) pendentes++;
            final q = _pesquisa.trim().toLowerCase();
            if (q.isNotEmpty &&
                !'${x.nome} ${x.marca} ${x.fornecedor}'.toLowerCase().contains(
                  q,
                )) {
              continue;
            }
            if (_categoria != null && x.categoria != _categoria) continue;
            if (_soPendentes && e != EstadoFds.falta && e != EstadoFds.antiga) {
              continue;
            }
            linhas.add((x, e));
          }
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
                    for (final c in CategoriaConsumivel.values)
                      FilterChip(
                        label: Text(c.label),
                        selected: _categoria == c,
                        onSelected: (v) =>
                            setState(() => _categoria = v ? c : null),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: linhas.isEmpty
                    ? const Center(child: Text('Nada com estes filtros.'))
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 88),
                        itemCount: linhas.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final (x, e) = linhas[i];
                          final ap = apresentaEstadoFds(e, cs);
                          final nDocs = docs
                              .where((d) => d.consumivelId == x.id)
                              .length;
                          return ListTile(
                            title: Text(x.nome),
                            subtitle: Text(
                              [
                                x.categoria.label,
                                if (x.marca.isNotEmpty) x.marca,
                                if (x.fornecedor.isNotEmpty) x.fornecedor,
                                '$nDocs doc.',
                              ].join(' · '),
                            ),
                            trailing: Chip(
                              avatar: Icon(ap.icone, size: 16, color: ap.cor),
                              label: Text(
                                ap.texto,
                                style: TextStyle(color: ap.cor),
                              ),
                              visualDensity: VisualDensity.compact,
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
