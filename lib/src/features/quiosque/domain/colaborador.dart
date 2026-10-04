import 'package:pocketbase/pocketbase.dart';

/// Deixa só os dígitos hexadecimais, em maiúsculas: o número de série de um
/// cartão chega como "04:a1:b2:c3" (Web NFC) ou "04A1B2C3" (escrito à mão).
String normalizarUid(String s) =>
    s.toUpperCase().replaceAll(RegExp('[^0-9A-F]'), '');

/// Uma pessoa que regista tarefas no quiosque (com ou sem cartão NFC).
class Colaborador {
  const Colaborador({
    required this.id,
    required this.nome,
    this.nfcUid = '',
    this.ordem = 0,
    this.arquivado = false,
  });

  final String id;
  final String nome;

  /// Número de série do cartão (normalizado); vazio = sem cartão.
  final String nfcUid;
  final int ordem;
  final bool arquivado;

  bool get ativo => !arquivado;
  bool get temCartao => nfcUid.isNotEmpty;

  factory Colaborador.fromRecord(RecordModel r) => Colaborador(
    id: r.id,
    nome: r.getStringValue('nome'),
    nfcUid: normalizarUid(r.getStringValue('nfc_uid')),
    ordem: r.getIntValue('ordem'),
    arquivado: r.getBoolValue('arquivado'),
  );
}

/// A pessoa dona de um cartão (`null` se o cartão não está associado a
/// ninguém ativo).
Colaborador? colaboradorDoCartao(String uid, List<Colaborador> todos) {
  final u = normalizarUid(uid);
  if (u.isEmpty) return null;
  for (final c in todos) {
    if (c.ativo && c.nfcUid == u) return c;
  }
  return null;
}
