import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

/// Cores disponíveis para os botões da grelha (`#RRGGBB`).
const coresBotoes = <String>[
  '#E53935', // vermelho
  '#FB8C00', // laranja
  '#FDD835', // amarelo
  '#43A047', // verde
  '#00897B', // turquesa
  '#1E88E5', // azul
  '#5E35B1', // roxo
  '#D81B60', // rosa
  '#6D4C41', // castanho
  '#546E7A', // cinza-azul
];

/// `#RRGGBB` → [Color]; `null` se não for válido.
Color? corDeHex(String? hex) {
  if (hex == null) return null;
  final m = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(hex.trim());
  if (m == null) return null;
  return Color(0xFF000000 | int.parse(m.group(1)!, radix: 16));
}

/// Preferências pessoais: páginas escondidas na grelha e cor de cada botão.
class NavPrefs {
  const NavPrefs({
    this.id = '',
    this.oculto = const {},
    this.cores = const {},
  });

  static const vazia = NavPrefs();

  final String id;
  final Set<String> oculto;
  final Map<String, String> cores;

  bool escondida(String chave) => oculto.contains(chave);

  Color? cor(String chave) => corDeHex(cores[chave]);

  NavPrefs comOculto(String chave, bool esconder) {
    final novo = {...oculto};
    esconder ? novo.add(chave) : novo.remove(chave);
    return NavPrefs(id: id, oculto: novo, cores: cores);
  }

  /// `hex` vazio/`null` volta à cor por omissão.
  NavPrefs comCor(String chave, String? hex) {
    final novo = {...cores};
    if (hex == null || hex.isEmpty) {
      novo.remove(chave);
    } else {
      novo[chave] = hex;
    }
    return NavPrefs(id: id, oculto: oculto, cores: novo);
  }

  Map<String, dynamic> toBody() => {
        'oculto': oculto.toList()..sort(),
        'cores': cores,
      };

  factory NavPrefs.fromRecord(RecordModel r) {
    final rawOculto = r.data['oculto'];
    final rawCores = r.data['cores'];
    return NavPrefs(
      id: r.id,
      oculto: rawOculto is List
          ? {for (final k in rawOculto) if (k is String) k}
          : const {},
      cores: rawCores is Map
          ? {
              for (final e in rawCores.entries)
                if (e.value is String && corDeHex(e.value as String) != null)
                  '${e.key}': e.value as String,
            }
          : const {},
    );
  }
}
