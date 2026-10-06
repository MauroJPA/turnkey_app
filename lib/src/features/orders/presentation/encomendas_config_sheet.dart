import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/mensagem_amigavel.dart';
import '../application/configuracoes_encomendas_providers.dart';
import '../data/configuracoes_encomendas_repository.dart';
import '../domain/configuracao_encomendas.dart';

/// Abre a folha de configuração de encomendas: tamanho do talão, impressão
/// automática ao criar, e antecedência do aviso "Encomendas por vir".
Future<void> showEncomendasConfigSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _EncomendasConfigSheet(),
  );
}

class _EncomendasConfigSheet extends ConsumerStatefulWidget {
  const _EncomendasConfigSheet();

  @override
  ConsumerState<_EncomendasConfigSheet> createState() =>
      _EncomendasConfigSheetState();
}

class _EncomendasConfigSheetState
    extends ConsumerState<_EncomendasConfigSheet> {
  TalaoTamanho? _tamanho;
  bool? _imprimirAuto;
  late final _lembreteHoras = TextEditingController();
  String _existingId = '';
  bool _carregado = false;
  bool _busy = false;

  @override
  void dispose() {
    _lembreteHoras.dispose();
    super.dispose();
  }

  void _carregarSeNecessario(ConfiguracaoEncomendas config) {
    if (_carregado) return;
    _carregado = true;
    _existingId = config.id;
    _tamanho = config.talaoTamanho;
    _imprimirAuto = config.imprimirAuto;
    _lembreteHoras.text = config.lembreteHoras.toStringAsFixed(0);
  }

  Future<void> _guardar() async {
    final horas = double.tryParse(_lembreteHoras.text.replaceAll(',', '.'));
    if (horas == null || horas < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Antecedência inválida.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(configuracoesEncomendasActionsProvider).salvar(
            _existingId,
            ConfiguracaoEncomendasInput(
              talaoTamanho: _tamanho!,
              imprimirAuto: _imprimirAuto!,
              lembreteHoras: horas,
            ),
          );
      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(configuracaoEncomendasProvider);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: async.when(
        loading: () => const SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => SizedBox(
          height: 100,
          child: Center(child: Text(mensagemAmigavel(e))),
        ),
        data: (config) {
          _carregarSeNecessario(config);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Configurar encomendas',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Text('Tamanho do talão',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<TalaoTamanho>(
                segments: [
                  for (final t in TalaoTamanho.values)
                    ButtonSegment(value: t, label: Text(t.label)),
                ],
                selected: {_tamanho!},
                onSelectionChanged: (s) => setState(() => _tamanho = s.first),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Imprimir automaticamente'),
                subtitle: const Text('Abre o talão ao criar uma encomenda nova'),
                value: _imprimirAuto!,
                onChanged: (v) => setState(() => _imprimirAuto = v),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _lembreteHoras,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Avisar com quantas horas de antecedência',
                  suffixText: 'horas',
                  helperText:
                      'O aviso "Encomendas por vir" no Início destaca as encomendas que faltam menos do que isto.',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _guardar,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }
}
