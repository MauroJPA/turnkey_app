import 'dart:convert';

import 'package:pocketbase/pocketbase.dart';

/// Tipo de local onde há cookies.
enum TipoLocal {
  loja('Loja'),
  parceiro('Parceiro / outra loja'),
  plataforma('Plataformas de entrega');

  const TipoLocal(this.label);
  final String label;

  static TipoLocal fromApi(String? v) => TipoLocal.values.firstWhere(
    (t) => t.name == v,
    orElse: () => TipoLocal.loja,
  );

  String get api => name;
}

/// Um local onde há cookies para contar: a loja, Alvalade, as plataformas…
/// Os [canais] são os canais de venda que saem deste local — é assim que o
/// "vendido" de cada local vem das vendas, sem registar duas vezes.
class Local {
  const Local({
    required this.id,
    required this.nome,
    this.tipo = TipoLocal.loja,
    this.canais = const [],
    this.ordem = 0,
    this.arquivado = false,
  });

  final String id;
  final String nome;
  final TipoLocal tipo;
  final List<String> canais;
  final int ordem;
  final bool arquivado;

  bool get ativo => !arquivado;

  factory Local.fromRecord(RecordModel r) => Local(
    id: r.id,
    nome: r.getStringValue('nome'),
    tipo: TipoLocal.fromApi(r.getStringValue('tipo')),
    canais: _lerCanais(r.data['canais']),
    ordem: r.getIntValue('ordem'),
    arquivado: r.getBoolValue('arquivado'),
  );
}

List<String> _lerCanais(Object? raw) {
  Object? v = raw;
  if (v is String && v.trim().isNotEmpty) {
    try {
      v = jsonDecode(v);
    } on FormatException {
      return const [];
    }
  }
  if (v is! List) return const [];
  return [
    for (final c in v)
      if ('$c'.trim().isNotEmpty) '$c'.trim(),
  ];
}

/// Dados de um local a criar/editar.
class LocalInput {
  LocalInput({
    required this.nome,
    this.tipo = TipoLocal.loja,
    this.canais = const [],
    this.ordem = 0,
  });

  final String nome;
  final TipoLocal tipo;
  final List<String> canais;
  final int ordem;

  Map<String, dynamic> toBody() => {
    'nome': nome.trim(),
    'tipo': tipo.api,
    'canais': canais,
    'ordem': ordem,
  };
}

String _norm(String s) => s.trim().toLowerCase();

/// O local a que pertence um canal de venda. Canal vazio ou desconhecido
/// (ex.: "Revenda", "Eventos", vendas antigas sem canal) conta para o local
/// por omissão: a primeira loja ativa (ou o primeiro local ativo).
Local? localDoCanal(String canal, List<Local> locais) {
  final ativos = [
    for (final l in locais)
      if (l.ativo) l,
  ];
  if (ativos.isEmpty) return null;
  final c = _norm(canal);
  if (c.isNotEmpty) {
    for (final l in ativos) {
      if (l.canais.any((x) => _norm(x) == c)) return l;
    }
  }
  return ativos.firstWhere(
    (l) => l.tipo == TipoLocal.loja,
    orElse: () => ativos.first,
  );
}
