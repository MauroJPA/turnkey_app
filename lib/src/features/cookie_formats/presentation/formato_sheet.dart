import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/mensagem_amigavel.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../application/cookie_format_providers.dart';
import '../data/cookie_format_repository.dart';
import '../domain/cookie_format.dart';

/// O que aconteceu na folha do formato.
class ResultadoFormato {
  const ResultadoFormato({this.formato, this.apagado = false});

  /// O formato criado/editado (para ficar escolhido).
  final FormatoCookie? formato;
  final bool apagado;
}

/// Cria ou edita um formato de cookie (tamanho: massa e recheio por
/// unidade) **na hora**, a partir da ficha técnica — já não há uma página só
/// para isto. Ao editar, também se pode apagar (se nenhuma ficha o usa).
Future<ResultadoFormato?> showFormatoSheet(
  BuildContext context, {
  FormatoCookie? existente,
}) {
  return showModalBottomSheet<ResultadoFormato>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => _FormatoSheet(existente: existente),
  );
}

class _FormatoSheet extends ConsumerStatefulWidget {
  const _FormatoSheet({this.existente});
  final FormatoCookie? existente;

  @override
  ConsumerState<_FormatoSheet> createState() => _FormatoSheetState();
}

class _FormatoSheetState extends ConsumerState<_FormatoSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.existente?.nome ?? '');
  late final _massa = TextEditingController(
    text: widget.existente == null
        ? ''
        : widget.existente!.massaG.toStringAsFixed(0),
  );
  late final _recheio = TextEditingController(
    text: (widget.existente?.recheioG ?? 0) > 0
        ? widget.existente!.recheioG.toStringAsFixed(0)
        : '',
  );
  bool _aGuardar = false;
  String? _erro;

  @override
  void dispose() {
    _nome.dispose();
    _massa.dispose();
    _recheio.dispose();
    super.dispose();
  }

  double _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.').trim()) ?? 0;

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _aGuardar = true;
      _erro = null;
    });
    final input = FormatoInput(
      nome: _nome.text,
      massaG: _num(_massa),
      recheioG: _num(_recheio),
      ordem: widget.existente?.ordem ?? 0,
      ativo: true,
    );
    try {
      final repo = ref.read(cookieFormatRepositoryProvider);
      final f = widget.existente == null
          ? await repo.create(input)
          : await repo.update(widget.existente!.id, input);
      ref.invalidate(formatosProvider);
      ref.invalidate(formatosAtivosProvider);
      if (mounted) Navigator.pop(context, ResultadoFormato(formato: f));
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _aGuardar = false;
        _erro = mensagemAmigavel(e);
      });
    }
  }

  Future<void> _apagar() async {
    final f = widget.existente!;
    final repo = ref.read(cookieFormatRepositoryProvider);
    setState(() => _erro = null);
    try {
      final usos = await repo.fichasQueUsam(f.id);
      if (usos > 0) {
        setState(
          () => _erro =
              'Este formato está em $usos ${usos == 1 ? 'ficha' : 'fichas'}. '
              'Troca o formato dessas fichas primeiro.',
        );
        return;
      }
      if (!mounted) return;
      final ok = await confirmDialog(
        context,
        titulo: 'Apagar formato?',
        mensagem: 'Remove "${f.nome}". Nenhuma ficha o usa.',
        confirmar: 'Apagar',
        destrutivo: true,
      );
      if (!ok) return;
      await repo.delete(f.id);
      ref.invalidate(formatosProvider);
      ref.invalidate(formatosAtivosProvider);
      if (mounted) {
        Navigator.pop(context, const ResultadoFormato(apagado: true));
      }
    } on Object catch (e) {
      if (mounted) setState(() => _erro = mensagemAmigavel(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final editar = widget.existente != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              editar ? 'Editar formato' : 'Novo formato',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'O tamanho do cookie: serve para saber quantas unidades saem '
              'de X kg de massa e quanto recheio é preciso.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nome,
              autofocus: !editar,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nome *',
                hintText: 'Ex.: Mini, Recheado, Simples',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _massa,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Massa (g) *',
                      suffixText: 'g',
                    ),
                    validator: (v) {
                      final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                      return (n == null || n <= 0) ? 'Maior que 0' : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _recheio,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Recheio (g)',
                      suffixText: 'g',
                    ),
                  ),
                ),
              ],
            ),
            if (_erro != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_erro!, style: TextStyle(color: cs.error)),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _aGuardar ? null : _guardar,
              child: Text(_aGuardar ? 'A guardar…' : 'Guardar'),
            ),
            if (editar)
              TextButton.icon(
                onPressed: _aGuardar ? null : _apagar,
                icon: Icon(Icons.delete_outline, color: cs.error),
                label: Text(
                  'Apagar formato',
                  style: TextStyle(color: cs.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
