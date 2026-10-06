import 'dart:math' as math;

import '../../pricing/domain/dias_trabalho.dart';

/// Quanto de um sabor se vendeu e se deitou fora num dia.
class ConsumoDia {
  const ConsumoDia({
    required this.dia,
    required this.fichaId,
    this.vendido = 0,
    this.desperdicio = 0,
  });

  /// Só o dia conta (sem horas).
  final DateTime dia;
  final String fichaId;
  final double vendido;
  final double desperdicio;
}

/// Os modelos que a previsão experimenta para cada sabor. Para cada um a app
/// vê quão perto teria andado nos dias passados e fica com o que erra menos.
enum ModeloPrevisao {
  recente('mais peso às últimas semanas'),
  media('média das últimas semanas'),
  mediana('mediana (ignora dias esquisitos)'),
  ultima('igual à última semana');

  const ModeloPrevisao(this.label);
  final String label;
}

enum Confianca {
  baixa('pouco histórico'),
  media('histórico razoável'),
  alta('histórico bom');

  const Confianca(this.label);
  final String label;
}

/// A previsão de um sabor para um dia.
class PrevisaoFicha {
  const PrevisaoFicha({
    required this.fichaId,
    required this.previsto,
    required this.sugerido,
    required this.modelo,
    required this.confianca,
    required this.pontos,
    this.erroMedio,
    this.desperdicioPct = 0,
    this.margem = 0,
    this.deFallback = false,
  });

  final String fichaId;

  /// Unidades que se espera vender nesse dia (já com o ajuste do dia).
  final double previsto;

  /// O que convém ter pronto: [previsto] + margem de segurança, arredondado.
  final int sugerido;
  final ModeloPrevisao modelo;
  final Confianca confianca;

  /// Quantos dias iguais (mesmo dia da semana) alimentaram o modelo.
  final int pontos;

  /// Erro médio (em unidades) do modelo nos dias passados; `null` se ainda
  /// não há dias suficientes para o medir.
  final double? erroMedio;

  /// % do que se fez que foi para o lixo (últimas semanas).
  final double desperdicioPct;

  /// Unidades a mais sobre o previsto, para não faltar.
  final double margem;

  /// `true` quando ainda não há dias iguais suficientes e a previsão vem da
  /// média geral do sabor.
  final bool deFallback;
}

double _media(List<double> v) =>
    v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;

double _mediana(List<double> v) {
  if (v.isEmpty) return 0;
  final s = [...v]..sort();
  final m = s.length ~/ 2;
  return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
}

const _ultimosParaMedia = 6;
const _ultimosParaMediana = 5;
const _decaimento = 0.7;

/// Prevê o próximo valor de [historico] (do mais antigo para o mais recente)
/// com o [modelo] dado.
double preverComModelo(ModeloPrevisao modelo, List<double> historico) {
  if (historico.isEmpty) return 0;
  switch (modelo) {
    case ModeloPrevisao.ultima:
      return historico.last;
    case ModeloPrevisao.media:
      return _media(
        historico.sublist(math.max(0, historico.length - _ultimosParaMedia)),
      );
    case ModeloPrevisao.mediana:
      return _mediana(
        historico.sublist(math.max(0, historico.length - _ultimosParaMediana)),
      );
    case ModeloPrevisao.recente:
      var soma = 0.0, pesos = 0.0, p = 1.0;
      for (var i = historico.length - 1; i >= 0; i--) {
        soma += historico[i] * p;
        pesos += p;
        p *= _decaimento;
      }
      return soma / pesos;
  }
}

/// Dias de treino mínimos antes de se testar um modelo.
const _treinoMinimo = 3;

/// Erro médio absoluto de [modelo] em [historico]: para cada dia a partir do
/// 4.º, prevê-o só com o que havia antes e compara com o que aconteceu.
/// `null` se há poucos dias para testar.
double? erroDoModelo(ModeloPrevisao modelo, List<double> historico) {
  if (historico.length <= _treinoMinimo) return null;
  var soma = 0.0;
  var n = 0;
  for (var i = _treinoMinimo; i < historico.length; i++) {
    soma += (preverComModelo(modelo, historico.sublist(0, i)) - historico[i])
        .abs();
    n++;
  }
  return soma / n;
}

/// O modelo com menor erro nos dias passados (em empate, o que dá mais peso
/// ao recente); sem dias para testar usa o "recente".
({ModeloPrevisao modelo, double? erro}) melhorModelo(List<double> historico) {
  ModeloPrevisao melhor = ModeloPrevisao.recente;
  double? melhorErro;
  for (final m in ModeloPrevisao.values) {
    final e = erroDoModelo(m, historico);
    if (e == null) continue;
    if (melhorErro == null || e < melhorErro - 1e-9) {
      melhor = m;
      melhorErro = e;
    }
  }
  return (modelo: melhor, erro: melhorErro);
}

DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);

/// Quantas semanas para trás se olha.
const semanasDeHistorico = 12;

/// Quantos dias de movimentos a previsão precisa de ir buscar.
const diasDeHistoricoPrevisao = semanasDeHistorico * 7;

/// Quanto desperdício (% do que se fez) deixa de pedir margem de segurança.
const desperdicioSemMargem = 15.0;
const desperdicioMargemMeia = 5.0;

/// Prevê o que vender (e por isso assar) em [alvo], sabor a sabor.
///
/// Para cada sabor junta as vendas dos últimos dias **iguais** a [alvo]
/// (mesma quinta-feira, etc.) em que a loja vendeu alguma coisa, experimenta
/// vários modelos nesses dias passados e fica com o que erra menos. A margem
/// de segurança vem do erro desse modelo, e encolhe — ou desaparece — se o
/// sabor costuma ir para o lixo. [ajustePct] sobe/desce o dia todo (evento,
/// chuva…).
List<PrevisaoFicha> preverDia({
  required DateTime hoje,
  required DateTime alvo,
  required List<ConsumoDia> consumo,
  double ajustePct = 0,
  Set<int> diasTrabalho = todosOsDias,
}) {
  final hoje0 = _d(hoje);
  final alvo0 = _d(alvo);
  // dia de folga: não há nada a prever
  if (!diasTrabalho.contains(alvo0.weekday)) return const [];
  final inicio = hoje0.subtract(const Duration(days: diasDeHistoricoPrevisao));

  // dias em que a loja vendeu (só nesses se conta "zero" de um sabor)
  final diasAtivos = <DateTime>{};
  final porFicha = <String, Map<DateTime, ConsumoDia>>{};
  final desperdicioPorFicha = <String, double>{};
  final vendidoRecentePorFicha = <String, double>{};
  final janelaLixo = hoje0.subtract(const Duration(days: 56));
  for (final c in consumo) {
    final dia = _d(c.dia);
    if (dia.isBefore(inicio) || !dia.isBefore(hoje0)) continue;
    if (c.vendido > 0) diasAtivos.add(dia);
    final m = porFicha.putIfAbsent(c.fichaId, () => {});
    final antes = m[dia];
    m[dia] = ConsumoDia(
      dia: dia,
      fichaId: c.fichaId,
      vendido: (antes?.vendido ?? 0) + c.vendido,
      desperdicio: (antes?.desperdicio ?? 0) + c.desperdicio,
    );
    if (!dia.isBefore(janelaLixo)) {
      desperdicioPorFicha[c.fichaId] =
          (desperdicioPorFicha[c.fichaId] ?? 0) + c.desperdicio;
      vendidoRecentePorFicha[c.fichaId] =
          (vendidoRecentePorFicha[c.fichaId] ?? 0) + c.vendido;
    }
  }

  // os dias iguais ao alvo, do mais antigo para o mais recente
  final diasIguais = <DateTime>[];
  for (var k = semanasDeHistorico; k >= 1; k--) {
    final d = alvo0.subtract(Duration(days: 7 * k));
    if (!d.isBefore(inicio) && d.isBefore(hoje0) && diasAtivos.contains(d)) {
      diasIguais.add(d);
    }
  }

  final fator = 1 + ajustePct / 100;
  final out = <PrevisaoFicha>[];
  for (final e in porFicha.entries) {
    final id = e.key;
    final dias = e.value;
    final vendeuAlgo = dias.values.any((c) => c.vendido > 0);
    if (!vendeuAlgo) continue;

    final serie = [for (final d in diasIguais) dias[d]?.vendido ?? 0.0];
    final vendido = vendidoRecentePorFicha[id] ?? 0;
    final lixo = desperdicioPorFicha[id] ?? 0;
    final produzido = vendido + lixo;
    final lixoPct = produzido > 0 ? lixo / produzido * 100 : 0.0;

    double base;
    ModeloPrevisao modelo;
    double? erro;
    var fallback = false;
    if (serie.length >= 2) {
      final m = melhorModelo(serie);
      modelo = m.modelo;
      erro = m.erro;
      base = preverComModelo(modelo, serie);
    } else {
      // poucos dias iguais: a média diária do sabor nos dias em que a loja abriu
      fallback = true;
      modelo = ModeloPrevisao.media;
      final ativos = diasAtivos.length;
      base = ativos == 0
          ? 0
          : dias.values.fold<double>(0, (s, c) => s + c.vendido) / ativos;
    }

    final k = lixoPct >= desperdicioSemMargem
        ? 0.0
        : (lixoPct >= desperdicioMargemMeia ? 0.5 : 1.0);
    final margem = k * (erro ?? base * 0.1);
    final previsto = base * fator;
    final sugerido = math.max(0, (previsto + margem * fator).round());

    final conf = fallback || serie.length < 4
        ? Confianca.baixa
        : (serie.length >= 8 && erro != null && erro <= 0.35 * math.max(base, 1)
              ? Confianca.alta
              : Confianca.media);

    out.add(
      PrevisaoFicha(
        fichaId: id,
        previsto: previsto,
        sugerido: sugerido,
        modelo: modelo,
        confianca: conf,
        pontos: serie.length,
        erroMedio: erro,
        desperdicioPct: lixoPct,
        margem: margem * fator,
        deFallback: fallback,
      ),
    );
  }
  out.sort((a, b) => b.sugerido.compareTo(a.sugerido));
  return out;
}
