import 'dart:convert';

import 'package:pocketbase/pocketbase.dart';

/// Um lote de ingrediente recebido (o código vem na embalagem do fornecedor).
class LoteIngrediente {
  const LoteIngrediente({
    required this.id,
    required this.ingredienteId,
    required this.lote,
    this.validade,
    this.fornecedor = '',
    this.esgotado = false,
  });

  final String id;
  final String ingredienteId;
  final String lote;
  final DateTime? validade;
  final String fornecedor;

  /// Já foi todo usado ou deitado fora: deixa de dar aviso de validade.
  final bool esgotado;

  bool passouValidade(DateTime hoje) =>
      validade != null &&
      validade!.isBefore(DateTime(hoje.year, hoje.month, hoje.day));

  factory LoteIngrediente.fromRecord(RecordModel r) => LoteIngrediente(
    id: r.id,
    ingredienteId: r.getStringValue('ingrediente'),
    lote: r.getStringValue('lote'),
    validade: _data(r.getStringValue('validade')),
    fornecedor: r.getStringValue('fornecedor'),
    esgotado: r.getBoolValue('esgotado'),
  );
}

/// Um ingrediente da ficha com os lotes que conhecemos dele (sugestão do
/// servidor: os que vencem primeiro vêm antes).
class IngredienteComLotes {
  const IngredienteComLotes({
    required this.id,
    required this.nome,
    this.lotes = const [],
  });

  final String id;
  final String nome;
  final List<LoteSugerido> lotes;

  static IngredienteComLotes fromJson(Map<String, dynamic> j) =>
      IngredienteComLotes(
        id: (j['id'] ?? '').toString(),
        nome: (j['nome'] ?? '').toString(),
        lotes: [
          for (final l in (j['lotes'] as List? ?? const []))
            if (l is Map) LoteSugerido.fromJson(Map<String, dynamic>.from(l)),
        ],
      );
}

class LoteSugerido {
  const LoteSugerido({
    required this.id,
    required this.lote,
    this.validade,
    this.fornecedor = '',
  });

  final String id;
  final String lote;
  final DateTime? validade;
  final String fornecedor;

  static LoteSugerido fromJson(Map<String, dynamic> j) => LoteSugerido(
    id: (j['id'] ?? '').toString(),
    lote: (j['lote'] ?? '').toString(),
    validade: _data((j['validade'] ?? '').toString()),
    fornecedor: (j['fornecedor'] ?? '').toString(),
  );
}

/// O lote de ingrediente usado num lote de produção (cópia: continua a
/// ler-se mesmo que o ingrediente seja apagado).
class LoteUsado {
  const LoteUsado({
    required this.ingredienteId,
    required this.nome,
    this.lote = '',
    this.validade,
    this.fornecedor = '',
  });

  final String ingredienteId;
  final String nome;

  /// Vazio = não se registou o lote desse ingrediente.
  final String lote;
  final DateTime? validade;
  final String fornecedor;

  Map<String, dynamic> toJson() => {
    'ingrediente': ingredienteId,
    'nome': nome,
    'lote': lote,
    'validade': validade == null ? '' : _iso(validade!),
    'fornecedor': fornecedor,
  };

  static LoteUsado fromJson(Map<String, dynamic> j) => LoteUsado(
    ingredienteId: (j['ingrediente'] ?? '').toString(),
    nome: (j['nome'] ?? '').toString(),
    lote: (j['lote'] ?? '').toString(),
    validade: _data((j['validade'] ?? '').toString()),
    fornecedor: (j['fornecedor'] ?? '').toString(),
  );
}

/// Um lote de produto acabado.
class LoteProducao {
  const LoteProducao({
    required this.id,
    required this.codigo,
    required this.fichaNome,
    required this.dataProducao,
    this.fichaId = '',
    this.quantidade = 0,
    this.validade,
    this.ingredientes = const [],
    this.responsavel = '',
    this.notas = '',
  });

  final String id;
  final String codigo;
  final String fichaId;
  final String fichaNome;
  final DateTime dataProducao;
  final double quantidade;
  final DateTime? validade;
  final List<LoteUsado> ingredientes;
  final String responsavel;
  final String notas;

  /// Quantos ingredientes ficaram sem lote registado.
  int get semLote => ingredientes.where((i) => i.lote.trim().isEmpty).length;

  factory LoteProducao.fromRecord(RecordModel r) {
    Object? raw = r.data['ingredientes'];
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        raw = jsonDecode(raw);
      } on FormatException {
        raw = null;
      }
    }
    return LoteProducao(
      id: r.id,
      codigo: r.getStringValue('codigo'),
      fichaId: r.getStringValue('ficha'),
      fichaNome: r.getStringValue('ficha_nome'),
      dataProducao: _data(r.getStringValue('data_producao')) ?? DateTime.now(),
      quantidade: r.getDoubleValue('quantidade'),
      validade: _data(r.getStringValue('validade')),
      ingredientes: [
        if (raw is List)
          for (final e in raw)
            if (e is Map) LoteUsado.fromJson(Map<String, dynamic>.from(e)),
      ],
      responsavel: r.getStringValue('responsavel'),
      notas: r.getStringValue('notas'),
    );
  }
}

DateTime? _data(String s) {
  if (s.trim().isEmpty) return null;
  final d = DateTime.tryParse(s.replaceFirst(' ', 'T'));
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

String _iso(DateTime d) {
  String dois(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${dois(d.month)}-${dois(d.day)}';
}

/// "2026-10-06 00:00:00.000Z" para gravar no PocketBase.
String dataParaPb(DateTime d) => '${_iso(d)} 00:00:00.000Z';

String _semAcentos(String s) {
  const de = 'àáâãäçèéêëìíîïñòóôõöùúûüýÀÁÂÃÄÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝ';
  const para = 'aaaaaceeeeiiiinooooouuuuyAAAAACEEEEIIIINOOOOOUUUUY';
  final b = StringBuffer();
  for (final c in s.runes) {
    final ch = String.fromCharCode(c);
    final i = de.indexOf(ch);
    b.write(i >= 0 ? para[i] : ch);
  }
  return b.toString();
}

/// Código do lote: data (AAMMDD) + 3 letras do produto + nº do lote desse
/// dia, ex.: `261006-ALB-1`.
String codigoLote(DateTime data, String produto, int sequencia) {
  String dois(int n) => n.toString().padLeft(2, '0');
  final letras = _semAcentos(
    produto,
  ).toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  final tres = letras.isEmpty ? 'PRD' : letras.padRight(3, 'X').substring(0, 3);
  return '${dois(data.year % 100)}${dois(data.month)}${dois(data.day)}-$tres-$sequencia';
}

/// O endereço que o QR da etiqueta abre (a página do lote na app).
String urlDoLote(String origem, String codigo) =>
    '${origem.endsWith('/') ? origem.substring(0, origem.length - 1) : origem}/#/lote/${Uri.encodeComponent(codigo)}';
