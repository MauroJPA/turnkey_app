import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/device/instalacao.dart';
import '../../../core/device/instalar_app.dart';
import '../../../core/storage/prefs_locais.dart';

const _chaveDispensado = 'instalar_dispensado';

/// "Instala a app": abre mais depressa, sem a barra do navegador, e fica no
/// ecrã principal. No Chrome/Edge basta um toque; no iPhone/iPad mostram-se os
/// passos do Safari. Só aparece se ainda não está instalada e se o navegador
/// o permite; o "x" esconde-o neste aparelho.
class InstalarAppCard extends StatefulWidget {
  const InstalarAppCard({super.key});

  @override
  State<InstalarAppCard> createState() => _InstalarAppCardState();
}

class _InstalarAppCardState extends State<InstalarAppCard> {
  late bool _dispensado = lerPref(_chaveDispensado) == '1';
  EstadoInstalacao _estado = estadoInstalacao();
  final _timers = <Timer>[];

  @override
  void initState() {
    super.initState();
    // o navegador só avisa que se pode instalar uns instantes depois de abrir
    for (final s in [1, 3, 8]) {
      _timers.add(Timer(Duration(seconds: s), _reler));
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  void _reler() {
    if (!mounted) return;
    final novo = estadoInstalacao();
    if (novo.instalada != _estado.instalada ||
        novo.podeInstalar != _estado.podeInstalar ||
        novo.ios != _estado.ios) {
      setState(() => _estado = novo);
    }
  }

  Future<void> _instalar() async {
    final ok = await instalarApp();
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('App instalada. Procura o ícone no ecrã principal.'),
        ),
      );
    }
    _reler();
  }

  @override
  Widget build(BuildContext context) {
    if (_dispensado || !_estado.oferecer) return const SizedBox.shrink();
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.install_mobile, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(child: Text('Instalar a app', style: tt.titleSmall)),
                IconButton(
                  tooltip: 'Esconder',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    guardarPref(_chaveDispensado, '1');
                    setState(() => _dispensado = true);
                  },
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                _estado.podeInstalar
                    ? 'Abre mais depressa, em ecrã inteiro e fica no ecrã principal, como qualquer outra app.'
                    : instrucoesInstalarIos,
                style: tt.bodyMedium,
              ),
            ),
            if (_estado.podeInstalar)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: FilledButton.icon(
                  onPressed: _instalar,
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Instalar'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
