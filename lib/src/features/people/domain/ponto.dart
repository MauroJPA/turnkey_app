import '../../quiosque/domain/colaborador.dart';

/// O que se marca no ponto.
enum TipoPonto {
  entrada('entrada', 'Entrada'),
  saida('saida', 'Saída'),
  pausaInicio('pausa_inicio', 'Início da pausa'),
  pausaFim('pausa_fim', 'Fim da pausa');

  const TipoPonto(this.api, this.label);
  final String api;
  final String label;

  static TipoPonto? fromApi(String? v) {
    for (final t in TipoPonto.values) {
      if (t.api == v) return t;
    }
    return null;
  }
}

/// De onde veio a marcação.
enum OrigemPonto {
  quiosque('quiosque', 'Quiosque'),
  app('app', 'App'),
  manual('manual', 'Manual');

  const OrigemPonto(this.api, this.label);
  final String api;
  final String label;

  static OrigemPonto fromApi(String? v) => OrigemPonto.values.firstWhere(
    (o) => o.api == v,
    orElse: () => OrigemPonto.app,
  );
}

/// A chave de uma pessoa nas marcações: a conta, se tem, ou o colaborador.
String chavePessoa(Colaborador c) =>
    c.userId.isNotEmpty ? 'u:${c.userId}' : 'c:${c.id}';

/// Uma marcação de ponto.
class RegistoPonto {
  const RegistoPonto({
    required this.id,
    required this.pessoa,
    required this.nome,
    required this.tipo,
    required this.dataHora,
    this.origem = OrigemPonto.app,
    this.notas = '',
    this.corrigido = false,
    this.dataHoraOriginal,
  });

  final String id;
  final String pessoa;
  final String nome;
  final TipoPonto tipo;

  /// Hora local.
  final DateTime dataHora;
  final OrigemPonto origem;
  final String notas;
  final bool corrigido;

  /// A hora que foi marcada antes de alguém a corrigir.
  final DateTime? dataHoraOriginal;
}

/// A última marcação de uma pessoa (o que o quiosque precisa para oferecer
/// "Entrada", "Pausa" ou "Saída").
class UltimoPonto {
  const UltimoPonto(this.tipo, this.dataHora);

  final TipoPonto tipo;
  final DateTime dataHora;
}

/// O que a pessoa pode marcar a seguir, pela última marcação.
List<TipoPonto> proximosPontos(TipoPonto? ultimo) => switch (ultimo) {
  null || TipoPonto.saida => const [TipoPonto.entrada],
  TipoPonto.entrada ||
  TipoPonto.pausaFim => const [TipoPonto.pausaInicio, TipoPonto.saida],
  TipoPonto.pausaInicio => const [TipoPonto.pausaFim],
};

/// Uma jornada: da entrada à saída (ou ainda em curso).
class Jornada {
  const Jornada({
    required this.pessoa,
    required this.nome,
    required this.entrada,
    this.saida,
    this.pausa = Duration.zero,
    this.registos = const [],
    this.aTrabalhar = false,
    this.semSaida = false,
    this.avisos = const [],
  });

  final String pessoa;
  final String nome;
  final DateTime entrada;
  final DateTime? saida;

  /// Tempo de pausa já descontado.
  final Duration pausa;
  final List<RegistoPonto> registos;

  /// Ainda não saiu e a entrada é de hoje.
  final bool aTrabalhar;

  /// Não houve saída (esqueceu-se de marcar): não conta como trabalhado.
  final bool semSaida;
  final List<String> avisos;

  /// O dia a que pertence (o da entrada).
  DateTime get dia => DateTime(entrada.year, entrada.month, entrada.day);

  /// Tempo trabalhado, sem a pausa. Sem saída (e sem estar a trabalhar) conta 0.
  Duration trabalhado(DateTime agora) {
    final fim = saida ?? (aTrabalhar ? agora : null);
    if (fim == null) return Duration.zero;
    final d = fim.difference(entrada) - pausa;
    return d.isNegative ? Duration.zero : d;
  }
}

/// Uma jornada nunca passa disto: mais do que isto é esquecimento da saída.
const jornadaMaxima = Duration(hours: 16);

/// Agrupa as marcações em jornadas, pessoa a pessoa, por ordem de entrada.
///
/// Entrada → (pausa início → pausa fim)* → saída. Marcações fora de ordem
/// (saída sem entrada, entrada com outra já aberta…) não se perdem: ficam
/// em [Jornada.avisos]. Uma jornada aberta com mais de 16 horas (ou de um
/// dia que já passou) é uma saída esquecida e não conta como trabalhada.
List<Jornada> calcularJornadas(List<RegistoPonto> registos, DateTime agora) {
  final porPessoa = <String, List<RegistoPonto>>{};
  for (final r in registos) {
    porPessoa.putIfAbsent(r.pessoa, () => []).add(r);
  }
  final out = <Jornada>[];
  bool mesmoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  for (final lista in porPessoa.values) {
    lista.sort((a, b) => a.dataHora.compareTo(b.dataHora));
    RegistoPonto? abertaEm;
    var regs = <RegistoPonto>[];
    var pausa = Duration.zero;
    DateTime? pausaDesde;
    var avisos = <String>[];

    void fechar(DateTime? saida, {bool semSaida = false}) {
      final e = abertaEm!;
      final dentroDoLimite =
          saida != null && saida.difference(e.dataHora) <= jornadaMaxima;
      final emCurso =
          saida == null &&
          !semSaida &&
          mesmoDia(e.dataHora, agora) &&
          agora.difference(e.dataHora) <= jornadaMaxima;
      out.add(
        Jornada(
          pessoa: e.pessoa,
          nome: e.nome,
          entrada: e.dataHora,
          saida: dentroDoLimite ? saida : null,
          pausa: pausa,
          registos: regs,
          aTrabalhar: emCurso,
          semSaida: !dentroDoLimite && !emCurso,
          avisos: [...avisos, if (!dentroDoLimite && !emCurso) 'Falta a saída'],
        ),
      );
      abertaEm = null;
      regs = [];
      pausa = Duration.zero;
      pausaDesde = null;
      avisos = [];
    }

    final soltas = <RegistoPonto>[];
    for (final r in lista) {
      switch (r.tipo) {
        case TipoPonto.entrada:
          if (abertaEm != null) fechar(null, semSaida: true);
          abertaEm = r;
          regs = [r];
        case TipoPonto.pausaInicio:
          if (abertaEm == null || pausaDesde != null) {
            soltas.add(r);
          } else {
            regs.add(r);
            pausaDesde = r.dataHora;
          }
        case TipoPonto.pausaFim:
          if (abertaEm == null || pausaDesde == null) {
            soltas.add(r);
          } else {
            regs.add(r);
            pausa += r.dataHora.difference(pausaDesde!);
            pausaDesde = null;
          }
        case TipoPonto.saida:
          if (abertaEm == null) {
            soltas.add(r);
          } else {
            regs.add(r);
            if (pausaDesde != null) {
              // saiu sem fechar a pausa: a pausa acaba na saída
              pausa += r.dataHora.difference(pausaDesde!);
              avisos.add('Pausa sem fim');
            }
            fechar(r.dataHora);
          }
      }
    }
    if (abertaEm != null) {
      if (pausaDesde != null) avisos.add('Pausa sem fim');
      fechar(null);
    }
    // marcações que não encaixam: uma "jornada" de aviso para não se perderem
    for (final r in soltas) {
      out.add(
        Jornada(
          pessoa: r.pessoa,
          nome: r.nome,
          entrada: r.dataHora,
          registos: [r],
          semSaida: false,
          avisos: ['${r.tipo.label} sem entrada'],
        ),
      );
    }
  }
  out.sort((a, b) {
    final c = a.entrada.compareTo(b.entrada);
    return c != 0 ? c : a.nome.compareTo(b.nome);
  });
  return out;
}

/// "7h 32m" (0 = "0m").
String formatarDuracao(Duration d) {
  final min = d.inMinutes;
  final h = min ~/ 60;
  final m = min % 60;
  if (h == 0) return '${m}m';
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}

/// O total por pessoa (nome, jornadas e tempo trabalhado), por nome.
class TotalPessoa {
  const TotalPessoa({
    required this.pessoa,
    required this.nome,
    required this.trabalhado,
    required this.dias,
    required this.avisos,
    required this.aTrabalhar,
  });

  final String pessoa;
  final String nome;
  final Duration trabalhado;

  /// Dias com trabalho.
  final int dias;

  /// Jornadas com problema (falta a saída, etc.).
  final int avisos;
  final bool aTrabalhar;
}

List<TotalPessoa> totaisPorPessoa(List<Jornada> jornadas, DateTime agora) {
  final mapa = <String, List<Jornada>>{};
  for (final j in jornadas) {
    mapa.putIfAbsent(j.pessoa, () => []).add(j);
  }
  final out = [
    for (final e in mapa.entries)
      TotalPessoa(
        pessoa: e.key,
        nome: e.value.last.nome,
        trabalhado: e.value.fold(
          Duration.zero,
          (s, j) => s + j.trabalhado(agora),
        ),
        dias: {
          for (final j in e.value)
            if (j.trabalhado(agora) > Duration.zero) j.dia,
        }.length,
        avisos: e.value.where((j) => j.avisos.isNotEmpty).length,
        aTrabalhar: e.value.any((j) => j.aTrabalhar),
      ),
  ]..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
  return out;
}

/// Folha em CSV (separador ";"): uma linha por jornada.
String jornadasCsv(List<Jornada> jornadas, DateTime agora) {
  String c(String s) => '"${s.replaceAll('"', '""')}"';
  String d(DateTime x) =>
      '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
  String h(DateTime? x) => x == null
      ? ''
      : '${x.hour.toString().padLeft(2, '0')}:${x.minute.toString().padLeft(2, '0')}';
  final b = StringBuffer('Pessoa;Dia;Entrada;Saída;Pausa;Trabalhado;Avisos\n');
  for (final j in jornadas) {
    b.writeln(
      [
        c(j.nome),
        d(j.dia),
        h(j.entrada),
        h(j.saida),
        formatarDuracao(j.pausa),
        formatarDuracao(j.trabalhado(agora)),
        c(j.avisos.join(' / ')),
      ].join(';'),
    );
  }
  return b.toString();
}
