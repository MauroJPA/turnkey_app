import 'dart:convert';

/// O que o navegador diz sobre instalar a app (ver `web/gc_instalar.js`).
class EstadoInstalacao {
  const EstadoInstalacao({
    this.instalada = false,
    this.podeInstalar = false,
    this.ios = false,
  });

  /// Já está a correr como app instalada (ou acabou de ser instalada).
  final bool instalada;

  /// O navegador deixa mostrar já o pedido "Instalar" (Chrome/Edge).
  final bool podeInstalar;

  /// iPhone/iPad: não há pedido; instala-se à mão pelo Safari.
  final bool ios;

  /// Vale a pena oferecer a instalação: ainda não está instalada e há maneira
  /// de o fazer (o pedido do navegador, ou as instruções do Safari).
  bool get oferecer => !instalada && (podeInstalar || ios);

  factory EstadoInstalacao.fromJson(String? texto) {
    try {
      final j = jsonDecode(texto ?? '');
      if (j is! Map) return const EstadoInstalacao();
      return EstadoInstalacao(
        instalada: j['instalada'] == true,
        podeInstalar: j['podeInstalar'] == true,
        ios: j['ios'] == true,
      );
    } on Object {
      return const EstadoInstalacao();
    }
  }
}

/// As instruções para instalar no Safari (iPhone/iPad).
const instrucoesInstalarIos =
    'No Safari, toca em Partilhar (o quadrado com a seta para cima) e '
    'depois em "Adicionar ao ecrã principal".';
