import 'package:pocketbase/pocketbase.dart';

/// Deixa só os dígitos hexadecimais, em maiúsculas: o número de série de um
/// cartão chega como "04:a1:b2:c3" (Web NFC) ou "04A1B2C3" (escrito à mão).
String normalizarUid(String s) =>
    s.toUpperCase().replaceAll(RegExp('[^0-9A-F]'), '');

/// Prefixo do id das pessoas da Equipa que ainda não têm linha própria
/// (sem cartão guardado): `equipa:<id da conta>`.
const prefixoEquipa = 'equipa:';

/// Uma pessoa que regista tarefas no quiosque (com ou sem cartão NFC): ou um
/// membro da Equipa, ou alguém sem conta na app.
class Colaborador {
  const Colaborador({
    required this.id,
    required this.nome,
    this.nfcUid = '',
    this.ordem = 0,
    this.arquivado = false,
    this.userId = '',
  });

  final String id;
  final String nome;

  /// Número de série do cartão (normalizado); vazio = sem cartão.
  final String nfcUid;
  final int ordem;
  final bool arquivado;

  /// A conta da Equipa a que pertence (vazio = pessoa sem conta).
  final String userId;

  bool get ativo => !arquivado;
  bool get temCartao => nfcUid.isNotEmpty;
  bool get daEquipa => userId.isNotEmpty;

  /// Ainda não há linha na base de dados (só existe a conta da Equipa).
  bool get virtual => id.startsWith(prefixoEquipa);

  factory Colaborador.fromRecord(RecordModel r) => Colaborador(
    id: r.id,
    nome: r.getStringValue('nome'),
    nfcUid: normalizarUid(r.getStringValue('nfc_uid')),
    ordem: r.getIntValue('ordem'),
    arquivado: r.getBoolValue('arquivado'),
    userId: r.getStringValue('user'),
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

/// Junta a Equipa (as contas da empresa) com as linhas guardadas: cada
/// membro aparece uma vez — com o cartão e o estado da sua linha, se houver —
/// e o nome vem sempre da conta. Quem não tem conta vem das linhas. Por
/// ordem alfabética.
List<Colaborador> juntarEquipa({
  required List<Colaborador> linhas,
  required List<({String id, String nome})> equipa,
}) {
  final porUser = {
    for (final l in linhas)
      if (l.daEquipa) l.userId: l,
  };
  final out = <Colaborador>[
    for (final m in equipa)
      if (porUser[m.id] case final l?)
        Colaborador(
          id: l.id,
          nome: m.nome.isEmpty ? l.nome : m.nome,
          nfcUid: l.nfcUid,
          ordem: l.ordem,
          arquivado: l.arquivado,
          userId: m.id,
        )
      else
        Colaborador(id: '$prefixoEquipa${m.id}', nome: m.nome, userId: m.id),
    // sem conta (ou cuja conta já saiu da empresa)
    for (final l in linhas)
      if (!l.daEquipa) l,
  ]..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
  return out;
}
