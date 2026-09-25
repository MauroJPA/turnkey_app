import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/pocketbase/pb_client.dart';

/// Estado de uma integração: o token nunca sai do servidor, só se sabe se está
/// guardado e como termina.
typedef EstadoIntegracao = ({bool configurada, String sufixo, bool cifraOk});

final integracaoVendusProvider = FutureProvider.autoDispose<EstadoIntegracao>((
  ref,
) async {
  final r = await ref
      .watch(pbProvider)
      .send('/api/turnkey/integracoes/vendus', method: 'GET');
  final m = r as Map;
  return (
    configurada: m['configurada'] == true,
    sufixo: (m['sufixo'] ?? '').toString(),
    cifraOk: m['cifraDisponivel'] != false,
  );
});

/// Mensagem de um erro do servidor, sem detalhes de rede (podem conter URLs).
String _mensagem(Object e) {
  if (e is ClientException) {
    final m = e.response['message'];
    if (m is String && m.isNotEmpty) return m;
  }
  return 'Não foi possível concluir. Tenta outra vez.';
}

Future<void> showIntegracoesSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => const _Sheet(),
  );
}

class _Sheet extends ConsumerStatefulWidget {
  const _Sheet();

  @override
  ConsumerState<_Sheet> createState() => _SheetState();
}

class _SheetState extends ConsumerState<_Sheet> {
  final _token = TextEditingController();
  bool _busy = false;
  bool _ver = false;
  String? _erro;

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final valor = _token.text.trim();
    if (valor.length < 8) {
      setState(() => _erro = 'O token parece curto demais.');
      return;
    }
    setState(() {
      _busy = true;
      _erro = null;
    });
    try {
      await ref
          .read(pbProvider)
          .send(
            '/api/turnkey/integracoes/vendus',
            method: 'PUT',
            body: {'valor': valor},
          );
      _token.clear();
      ref.invalidate(integracaoVendusProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token do Vendus guardado (cifrado).')),
        );
      }
    } on Object catch (e) {
      if (mounted) setState(() => _erro = _mensagem(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remover() async {
    setState(() {
      _busy = true;
      _erro = null;
    });
    try {
      await ref
          .read(pbProvider)
          .send('/api/turnkey/integracoes/vendus', method: 'DELETE');
      ref.invalidate(integracaoVendusProvider);
    } on Object catch (e) {
      if (mounted) setState(() => _erro = _mensagem(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(integracaoVendusProvider);
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text('Integrações — Vendus', style: tt.titleLarge),
          const SizedBox(height: 8),
          Text(
            'O token do teu Vendus (Apps → API) fica guardado cifrado no servidor '
            'e serve para importar as vendas. Depois de guardado não volta a '
            'aparecer: só se pode substituir ou remover.',
            style: tt.bodyMedium,
          ),
          const SizedBox(height: 16),
          estado.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('Não foi possível ver o estado.'),
            data: (e) => Row(
              children: [
                Icon(
                  e.configurada ? Icons.lock_outline : Icons.lock_open_outlined,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    e.configurada
                        ? 'Token guardado${e.sufixo.isEmpty ? '' : ' (termina em ${e.sufixo})'}'
                        : 'Ainda sem token',
                  ),
                ),
                if (e.configurada)
                  TextButton(
                    onPressed: _busy ? null : _remover,
                    child: const Text('Remover'),
                  ),
              ],
            ),
          ),
          if (estado.valueOrNull?.cifraOk == false)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'O servidor ainda não tem a chave de cifra, por isso não pode '
                  'guardar tokens. Quem administra o servidor tem de a gerar '
                  '(bash gookie.sh instalar) e reiniciar.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _token,
            obscureText: !_ver,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'Novo token do Vendus',
              suffixIcon: IconButton(
                icon: Icon(_ver ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _ver = !_ver),
              ),
            ),
          ),
          if (_erro != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _erro!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy || estado.valueOrNull?.cifraOk == false
                ? null
                : _guardar,
            child: const Text('Guardar token'),
          ),
        ],
      ),
    );
  }
}
