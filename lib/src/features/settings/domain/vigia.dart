// Estado do vigia de segurança do servidor (o script `deploy/seguranca/vigia.py`
// escreve-o; a app só o mostra ao dono do servidor).

enum GravidadeVigia {
  critico('critico', 'Urgente'),
  atencao('atencao', 'Atenção'),
  info('info', 'Para saber');

  const GravidadeVigia(this.api, this.label);
  final String api;
  final String label;

  static GravidadeVigia fromApi(Object? v) => GravidadeVigia.values.firstWhere(
    (g) => g.api == v,
    orElse: () => GravidadeVigia.info,
  );
}

/// Um alerta: o que foi visto, o que significa e o que fazer.
class AchadoVigia {
  const AchadoVigia({
    required this.id,
    required this.gravidade,
    required this.titulo,
    this.categoria = '',
    this.detalhe = '',
    this.fazer = '',
    this.desde,
    this.vezes = 0,
    this.itens = const [],
    this.aceite = false,
  });

  final String id;
  final GravidadeVigia gravidade;
  final String categoria;
  final String titulo;
  final String detalhe;
  final String fazer;

  /// Desde quando está ativo.
  final DateTime? desde;
  final int vezes;
  final List<String> itens;

  /// Já foi marcado "já verifiquei": o vigia vai aprender na próxima ronda.
  final bool aceite;

  /// Pede ação (não é só informação nem está a ser aprendido).
  bool get ativo => gravidade != GravidadeVigia.info && !aceite;

  factory AchadoVigia.fromJson(Map<String, dynamic> j) {
    final d = (j['desde'] as num?)?.toInt() ?? 0;
    return AchadoVigia(
      id: '${j['id'] ?? ''}',
      gravidade: GravidadeVigia.fromApi(j['gravidade']),
      categoria: '${j['categoria'] ?? ''}',
      titulo: '${j['titulo'] ?? ''}',
      detalhe: '${j['detalhe'] ?? ''}',
      fazer: '${j['fazer'] ?? ''}',
      desde: d > 0 ? DateTime.fromMillisecondsSinceEpoch(d * 1000) : null,
      vezes: (j['vezes'] as num?)?.toInt() ?? 0,
      itens: [for (final i in (j['itens'] as List? ?? const [])) '$i'],
      aceite: j['aceite'] == true,
    );
  }
}

/// O resultado da última ronda do vigia.
class EstadoVigia {
  const EstadoVigia({
    this.instalado = false,
    this.estado = 'ok',
    this.pontuacao = 0,
    this.quando,
    this.parado = false,
    this.achados = const [],
    this.verificacoes = 0,
    this.verificacoesComErro = 0,
    this.notas = const [],
    this.iaAtiva = false,
    this.iaProvider = '',
  });

  /// O script está instalado no servidor (já escreveu resultados).
  final bool instalado;

  /// `ok`, `atencao` ou `critico` — como o vigia o calculou.
  final String estado;
  final int pontuacao;
  final DateTime? quando;

  /// Sem dados há mais de 40 minutos: o vigia deixou de correr.
  final bool parado;
  final List<AchadoVigia> achados;
  final int verificacoes;
  final int verificacoesComErro;
  final List<String> notas;

  /// "Explicar com IA" está disponível (e qual é o fornecedor, p. ex. "Gemini
  /// (Google)").
  final bool iaAtiva;
  final String iaProvider;

  /// Os alertas que pedem ação, os mais graves primeiro.
  List<AchadoVigia> get ativos => [
    for (final a in achados)
      if (a.ativo) a,
  ];

  List<AchadoVigia> get paraSaber => [
    for (final a in achados)
      if (a.gravidade == GravidadeVigia.info && !a.aceite) a,
  ];

  List<AchadoVigia> get aAprender => [
    for (final a in achados)
      if (a.aceite) a,
  ];

  int get criticos =>
      ativos.where((a) => a.gravidade == GravidadeVigia.critico).length;

  bool get haIncidente => achados.any((a) => a.id == 'incidente' && !a.aceite);

  /// O estado que a pessoa deve ver: um vigia parado conta como atenção.
  GravidadeVigia get nivel {
    if (ativos.any((a) => a.gravidade == GravidadeVigia.critico)) {
      return GravidadeVigia.critico;
    }
    if (ativos.isNotEmpty || parado) return GravidadeVigia.atencao;
    return GravidadeVigia.info;
  }

  /// "Tudo calmo", "2 alertas a ver (1 urgente)", "Possível intrusão".
  String get resumo {
    if (!instalado) return 'Vigia ainda não instalado';
    if (haIncidente) return 'POSSÍVEL INTRUSÃO — vê já os alertas';
    final n = ativos.length;
    if (n == 0) return parado ? 'O vigia parou de correr' : 'Tudo calmo';
    final urg = criticos;
    return '$n alerta${n == 1 ? '' : 's'} a ver'
        '${urg > 0 ? ' ($urg urgente${urg == 1 ? '' : 's'})' : ''}';
  }

  factory EstadoVigia.fromJson(Map<String, dynamic> j) {
    if (j['operador'] != true || j['instalado'] != true) {
      return const EstadoVigia();
    }
    final q = (j['quando'] as num?)?.toInt() ?? 0;
    final verif = (j['verificacoes'] as Map?) ?? const {};
    return EstadoVigia(
      instalado: true,
      estado: '${j['estado'] ?? 'ok'}',
      pontuacao: (j['pontuacao'] as num?)?.toInt() ?? 0,
      quando: q > 0 ? DateTime.fromMillisecondsSinceEpoch(q * 1000) : null,
      parado: j['parado'] == true,
      achados: [
        for (final a in (j['achados'] as List? ?? const []))
          if (a is Map) AchadoVigia.fromJson(Map<String, dynamic>.from(a)),
      ],
      verificacoes: verif.length,
      verificacoesComErro: verif.values
          .where((v) => v is Map && v['ok'] != true)
          .length,
      notas: [for (final n in (j['notas'] as List? ?? const [])) '$n'],
      iaAtiva: (j['ia'] as Map?)?['ativa'] == true,
      iaProvider: '${(j['ia'] as Map?)?['provider'] ?? ''}',
    );
  }
}

/// "agora mesmo", "há 5 min", "há 3 h", "há 2 dias".
String textoHa(DateTime? quando, DateTime agora) {
  if (quando == null) return '';
  final d = agora.difference(quando);
  if (d.inMinutes < 2) return 'agora mesmo';
  if (d.inMinutes < 60) return 'há ${d.inMinutes} min';
  if (d.inHours < 48) return 'há ${d.inHours} h';
  return 'há ${d.inDays} dias';
}

/// O que a IA acha de um alerta.
enum VereditoIa {
  normal('provavelmente_normal', 'Provavelmente normal'),
  duvidoso('duvidoso', 'Não dá para ter a certeza'),
  suspeito('suspeito', 'Parece suspeito');

  const VereditoIa(this.api, this.label);
  final String api;
  final String label;

  static VereditoIa fromApi(Object? v) => VereditoIa.values.firstWhere(
    (e) => e.api == v,
    orElse: () => VereditoIa.duvidoso,
  );
}

class PassoIa {
  const PassoIa(this.texto, {this.comando});
  final String texto;

  /// Um comando só de leitura para confirmar (nunca se corre sozinho).
  final String? comando;
}

/// A explicação devolvida pela IA (já limpa pelo servidor).
class ExplicacaoIa {
  const ExplicacaoIa({
    required this.veredito,
    required this.resumo,
    this.porque = '',
    this.passos = const [],
    this.naoFazer = const [],
    this.provider = '',
    this.doCache = false,
  });

  final VereditoIa veredito;
  final String resumo;
  final String porque;
  final List<PassoIa> passos;
  final List<String> naoFazer;
  final String provider;

  /// Já estava guardada: nada foi enviado agora.
  final bool doCache;

  factory ExplicacaoIa.fromJson(
    Map<String, dynamic> e, {
    String provider = '',
    bool doCache = false,
  }) {
    return ExplicacaoIa(
      veredito: VereditoIa.fromApi(e['veredito']),
      resumo: '${e['resumo'] ?? ''}',
      porque: '${e['porque'] ?? ''}',
      passos: [
        for (final p in (e['passos'] as List? ?? const []))
          if (p is Map)
            PassoIa(
              '${p['texto'] ?? ''}',
              comando: (p['comando'] as String?)?.isEmpty ?? true
                  ? null
                  : p['comando'] as String?,
            ),
      ],
      naoFazer: [for (final n in (e['naoFazer'] as List? ?? const [])) '$n'],
      provider: provider,
      doCache: doCache,
    );
  }
}

/// O que se mostra antes de enviar: o texto exato, para onde vai e o que já
/// existe guardado.
class PreviaIa {
  const PreviaIa({
    required this.texto,
    required this.provider,
    required this.restantes,
    this.cache,
  });

  final String texto;
  final String provider;
  final int restantes;

  /// Explicação já guardada (se houver, mostra-se sem enviar nada).
  final ExplicacaoIa? cache;

  factory PreviaIa.fromJson(Map<String, dynamic> j) {
    final c = j['cache'];
    final provider = '${j['provider'] ?? ''}';
    return PreviaIa(
      texto: '${j['previa'] ?? ''}',
      provider: provider,
      restantes: (j['restantes'] as num?)?.toInt() ?? 0,
      cache: c is Map && c['explicacao'] is Map
          ? ExplicacaoIa.fromJson(
              Map<String, dynamic>.from(c['explicacao'] as Map),
              provider: '${c['provider'] ?? provider}',
              doCache: true,
            )
          : null,
    );
  }
}
