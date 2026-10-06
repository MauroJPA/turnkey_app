import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/marcas_fornecedores_providers.dart';
import '../../../core/errors/mensagem_amigavel.dart';
import '../../../core/formatting/capitalizar.dart';
import '../../../core/widgets/autocomplete_text_field.dart';

/// Junta variantes do mesmo nome de marca/fornecedor (ex.: "Recheio Cash &
/// Carry, S.A." e "Recheio Cash & Carry, SA") num só — para quando a mesma
/// entidade real acaba com vários nomes ligeiramente diferentes (escritos à
/// mão ou lidos de faturas diferentes por IA). Só proprietário/administrador.
Future<void> mostrarJuntarMarcasFornecedores(
  BuildContext context, {
  TipoCatalogo tipoInicial = TipoCatalogo.fornecedor,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _JuntarSheet(tipoInicial: tipoInicial),
  );
}

class _JuntarSheet extends ConsumerStatefulWidget {
  const _JuntarSheet({required this.tipoInicial});
  final TipoCatalogo tipoInicial;

  @override
  ConsumerState<_JuntarSheet> createState() => _JuntarSheetState();
}

class _JuntarSheetState extends ConsumerState<_JuntarSheet> {
  late TipoCatalogo _tipo = widget.tipoInicial;
  final Set<String> _selecionados = {};
  final _destino = TextEditingController();
  bool _busy = false;
  String? _erro;

  @override
  void dispose() {
    _destino.dispose();
    super.dispose();
  }

  void _mudarTipo(TipoCatalogo t) {
    if (t == _tipo) return;
    setState(() {
      _tipo = t;
      _selecionados.clear();
      _destino.clear();
      _erro = null;
    });
  }

  void _alternar(String v) {
    setState(() {
      if (_selecionados.contains(v)) {
        _selecionados.remove(v);
      } else {
        _selecionados.add(v);
        // sugere o primeiro escolhido como ponto de partida; a pessoa ajusta.
        if (_selecionados.length == 1 && _destino.text.trim().isEmpty) {
          _destino.text = v;
        }
      }
    });
  }

  Future<void> _juntar() async {
    final destino = capitalizarInicial(_destino.text.trim());
    if (destino.isEmpty) {
      setState(() => _erro = 'Escreve o nome final.');
      return;
    }
    final valores = _selecionados.where((v) => v != destino).toList();
    if (valores.isEmpty) {
      setState(
        () => _erro = 'Escolhe pelo menos um valor diferente do nome final.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _erro = null;
    });
    try {
      final n = await ref
          .read(marcasFornecedoresActionsProvider)
          .juntar(tipo: _tipo, valores: valores, destino: destino);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            n == 0
                ? 'Nada para atualizar (talvez já estivesse tudo igual).'
                : '$n registo(s) atualizados para "$destino".',
          ),
        ),
      );
    } on Object catch (e) {
      setState(() {
        _busy = false;
        _erro = 'Não foi possível juntar: ${mensagemAmigavel(e)}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final opcoes = _tipo == TipoCatalogo.marca
        ? ref.watch(marcasConhecidasProvider)
        : ref.watch(fornecedoresConhecidosProvider);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Juntar marcas/fornecedores', style: tt.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Quando o mesmo fornecedor ou marca aparece com nomes '
              'ligeiramente diferentes (ex.: com ou sem "S.A."), escolhe aqui '
              'os que são o mesmo e junta-os num só nome, em todos os sítios '
              'onde aparecem.',
              style: tt.bodySmall,
            ),
            const SizedBox(height: 12),
            SegmentedButton<TipoCatalogo>(
              segments: [
                for (final t in TipoCatalogo.values)
                  ButtonSegment(value: t, label: Text(t.label)),
              ],
              selected: {_tipo},
              onSelectionChanged: (s) => _mudarTipo(s.first),
            ),
            const SizedBox(height: 12),
            if (opcoes.length < 2)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Ainda não há ${_tipo.label.toLowerCase()}s suficientes '
                  'para juntar.',
                  style: tt.bodySmall,
                ),
              )
            else ...[
              Text('Escolhe os que são o mesmo', style: tt.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final o in opcoes)
                    FilterChip(
                      label: Text(o),
                      selected: _selecionados.contains(o),
                      onSelected: (_) => _alternar(o),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              AutocompleteTextField(
                controller: _destino,
                options: opcoes,
                labelText: 'Nome final',
                hintText: 'Como deve ficar (um dos escolhidos, ou outro)',
              ),
            ],
            if (_erro != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _erro!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy || _selecionados.isEmpty ? null : _juntar,
              child: _busy
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Juntar'),
            ),
          ],
        ),
      ),
    );
  }
}
