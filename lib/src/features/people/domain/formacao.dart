/// O tipo de documento.
enum TipoFormacao {
  formacao('formacao', 'Formação'),
  certificado('certificado', 'Certificado'),
  aptidao('aptidao', 'Ficha de aptidão');

  const TipoFormacao(this.api, this.label);
  final String api;
  final String label;

  static TipoFormacao fromApi(String? v) => TipoFormacao.values.firstWhere(
    (t) => t.api == v,
    orElse: () => TipoFormacao.formacao,
  );
}

/// Em que ponto está a validade de um certificado.
enum EstadoValidade {
  semValidade('Não caduca'),
  valida('Válida'),
  aCaducar('A caducar'),
  caducada('Caducada');

  const EstadoValidade(this.label);
  final String label;
}

/// Avisar quando faltam menos de tantos dias para caducar.
const diasAvisoFormacao = 30;

/// Ideias para o título (aparecem como sugestões ao registar).
const titulosSugeridos = [
  'Manipulador de alimentos',
  'HACCP',
  'Higiene e segurança alimentar',
  'Alergénios',
  'Primeiros socorros',
  'Prevenção de incêndios',
  'Ficha de aptidão médica',
];

/// Uma formação ou certificado de uma pessoa.
class Formacao {
  const Formacao({
    required this.id,
    required this.pessoa,
    required this.nome,
    required this.titulo,
    required this.tipo,
    this.userId = '',
    this.realizada,
    this.validade,
    this.entidade = '',
    this.notas = '',
    this.ficheiro = '',
  });

  final String id;

  /// Chave da pessoa: `u:<conta>` ou `c:<colaborador>`.
  final String pessoa;
  final String nome;
  final String titulo;
  final TipoFormacao tipo;
  final String userId;
  final DateTime? realizada;

  /// Dia (inclusive) até ao qual vale; `null` = não caduca.
  final DateTime? validade;
  final String entidade;
  final String notas;

  /// Nome do ficheiro no servidor ('' se não há).
  final String ficheiro;

  bool get temFicheiro => ficheiro.isNotEmpty;

  /// Dias até caducar (negativo = já caducou); `null` se não caduca.
  int? diasParaCaducar(DateTime hoje) {
    final v = validade;
    if (v == null) return null;
    final h = DateTime.utc(hoje.year, hoje.month, hoje.day);
    return DateTime.utc(v.year, v.month, v.day).difference(h).inDays;
  }

  EstadoValidade estado(DateTime hoje) {
    final d = diasParaCaducar(hoje);
    if (d == null) return EstadoValidade.semValidade;
    if (d < 0) return EstadoValidade.caducada;
    if (d <= diasAvisoFormacao) return EstadoValidade.aCaducar;
    return EstadoValidade.valida;
  }

  /// "caduca em 12 dias", "caduca amanhã", "caducou há 3 dias".
  String quando(DateTime hoje) {
    final d = diasParaCaducar(hoje);
    if (d == null) return 'não caduca';
    if (d == 0) return 'caduca hoje';
    if (d == 1) return 'caduca amanhã';
    if (d > 1) return 'caduca em $d dias';
    if (d == -1) return 'caducou ontem';
    return 'caducou há ${-d} dias';
  }
}

/// Soma [anos] a [d] (29 de fevereiro + 1 ano → 28 de fevereiro).
DateTime somarAnos(DateTime d, int anos) {
  final ultimo = DateTime(d.year + anos, d.month + 1, 0).day;
  return DateTime(d.year + anos, d.month, d.day > ultimo ? ultimo : d.day);
}

/// A validade sugerida para a renovação de [antiga] feita em [hoje]: o mesmo
/// período que o certificado anterior durava (3 anos → mais 3 anos). Sem
/// validade antes, não caduca; sem data de realização, assume 1 ano.
DateTime? validadeRenovada(Formacao antiga, DateTime hoje) {
  final v = antiga.validade;
  if (v == null) return null;
  final r = antiga.realizada;
  // em UTC, para a mudança de hora não tirar um dia à conta
  var dias = r == null
      ? 365
      : DateTime.utc(
          v.year,
          v.month,
          v.day,
        ).difference(DateTime.utc(r.year, r.month, r.day)).inDays;
  if (dias < 30) dias = 365;
  final anos = (dias / 365).round();
  if (anos >= 1 && (dias - anos * 365).abs() <= 40) {
    return somarAnos(hoje, anos);
  }
  return DateTime(hoje.year, hoje.month, hoje.day + dias);
}

String _norm(String s) => s.trim().toLowerCase();

/// Só vale a versão mais recente de cada título por pessoa: se renovaste o
/// "Manipulador de alimentos", a cópia antiga (já caducada) deixa de contar.
/// Uma versão que não caduca ganha sempre.
List<Formacao> vigentes(List<Formacao> todas) {
  final melhor = <String, Formacao>{};
  for (final f in todas) {
    final k = '${f.pessoa}|${_norm(f.titulo)}';
    final atual = melhor[k];
    if (atual == null || _maisRecente(f, atual)) melhor[k] = f;
  }
  return melhor.values.toList();
}

bool _maisRecente(Formacao a, Formacao b) {
  // sem validade (não caduca) ganha a qualquer uma com validade
  if (a.validade == null) return b.validade != null || _antes(b, a);
  if (b.validade == null) return false;
  return a.validade!.isAfter(b.validade!);
}

bool _antes(Formacao a, Formacao b) {
  final ra = a.realizada, rb = b.realizada;
  if (ra == null || rb == null) return false;
  return ra.isBefore(rb);
}

/// O que pede atenção: caducadas ou a caducar nos próximos [diasAvisoFormacao]
/// dias, das mais urgentes para as menos.
List<Formacao> formacoesEmAlerta(List<Formacao> todas, DateTime hoje) {
  final out = [
    for (final f in vigentes(todas))
      if (f.estado(hoje) == EstadoValidade.caducada ||
          f.estado(hoje) == EstadoValidade.aCaducar)
        f,
  ];
  out.sort(
    (a, b) => a.diasParaCaducar(hoje)!.compareTo(b.diasParaCaducar(hoje)!),
  );
  return out;
}
