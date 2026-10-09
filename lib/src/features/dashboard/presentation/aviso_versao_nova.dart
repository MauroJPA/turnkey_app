// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
//
// A app só é construída para web; `dart:html` dá acesso ao service worker e às
// caches, que é o que impede o telemóvel de ver a versão nova depois de o
// servidor ser atualizado.
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/env/app_version.dart';

/// Versão desta compilação (vazia em desenvolvimento: o aviso não aparece).
const versaoCompilada = versaoApp;

/// Aviso "Há uma versão nova": compara a versão desta app com a do servidor
/// (`version.json`, lido sem cache) ao abrir, a cada 10 minutos e quando a
/// página volta a ficar visível. "Atualizar" limpa a cache da app, obriga o navegador a pedir os ficheiros
/// novos ao servidor e recarrega.
class AvisoVersaoNova extends StatefulWidget {
  const AvisoVersaoNova({super.key});

  @override
  State<AvisoVersaoNova> createState() => _AvisoVersaoNovaState();
}

class _AvisoVersaoNovaState extends State<AvisoVersaoNova> {
  String? _nova;

  /// O servidor não respondeu: o que se vê pode ser a última cópia guardada no
  /// telemóvel (sem Wi-Fi/Tailscale, por exemplo).
  bool _semLigacao = false;
  Timer? _timer;
  StreamSubscription<html.Event>? _visivel;
  bool _atualizando = false;

  @override
  void initState() {
    super.initState();
    if (versaoCompilada.isEmpty) return;
    _verificar();
    _timer = Timer.periodic(const Duration(minutes: 10), (_) => _verificar());
    _visivel = html.document.onVisibilityChange.listen((_) {
      if (html.document.visibilityState == 'visible') _verificar();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _visivel?.cancel();
    super.dispose();
  }

  Future<void> _verificar() async {
    try {
      final url = Uri.base.resolve(
        'version.json?nocache=${DateTime.now().millisecondsSinceEpoch}',
      );
      final r = await http.get(url).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) {
        // o servidor respondeu (ex.: a reiniciar numa atualização): sem aviso
        if (mounted && _semLigacao) setState(() => _semLigacao = false);
        return;
      }
      final v = (jsonDecode(r.body) as Map)['version']?.toString() ?? '';
      if (!mounted) return;
      setState(() {
        _semLigacao = false;
        _nova = (v.isNotEmpty && v != versaoCompilada) ? v : null;
      });
    } on Object {
      // sem rede ou o servidor não responde: avisa, para não parecer que a app
      // "não carrega nada" sem se perceber porquê
      if (mounted) setState(() => _semLigacao = true);
    }
  }

  Future<void> _atualizar() async {
    setState(() => _atualizando = true);
    try {
      final regs = await html.window.navigator.serviceWorker
          ?.getRegistrations();
      for (final r in regs ?? const []) {
        await (r as html.ServiceWorkerRegistration).unregister();
      }
      final caches = html.window.caches;
      if (caches != null) {
        for (final k in await caches.keys()) {
          await caches.delete(k);
        }
      }
    } on Object {
      // recarrega na mesma
    }
    // A cache de rede do Chrome pode ainda ter a app antiga (o servidor não
    // diz quando ela caduca): pede cada ficheiro principal com "no-cache", o
    // que obriga a validar com o servidor e atualiza a cache. Só depois recarrega.
    const ficheiros = [
      '',
      'index.html',
      'flutter_bootstrap.js',
      'flutter.js',
      'main.dart.js',
      'gc_dispositivo.js',
      'flutter_service_worker.js',
      'gc_sw.js',
      'version.json',
      'manifest.json',
    ];
    await Future.wait([
      for (final f in ficheiros)
        http
            .get(
              Uri.base.resolve(f),
              headers: const {
                'Cache-Control': 'no-cache',
                'Pragma': 'no-cache',
              },
            )
            .then<void>((_) {})
            .catchError((Object _) {}),
    ]);
    html.window.location.reload();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_semLigacao) {
      return Material(
        color: cs.errorContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Sem ligação ao servidor. O que vês pode ser a última cópia '
                  'guardada: confirma o Wi-Fi ou o Tailscale.',
                  style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: _verificar,
                child: const Text('Tentar de novo'),
              ),
            ],
          ),
        ),
      );
    }
    if (_nova == null) return const SizedBox.shrink();
    return Material(
      color: cs.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Há uma versão nova da app ($_nova). Atualiza para ver as novidades.',
                style: TextStyle(color: cs.onTertiaryContainer, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: _atualizando ? null : _atualizar,
              child: Text(_atualizando ? 'A atualizar…' : 'Atualizar'),
            ),
          ],
        ),
      ),
    );
  }
}
