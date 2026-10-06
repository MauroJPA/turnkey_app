import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Quão cedo uma coisa precisa de ti. O vermelho só existe para o que é
/// urgente de verdade (segurança alimentar, dinheiro, prazos a acabar).
enum Urgencia {
  /// Já devia estar feito ou é segurança alimentar.
  urgente,

  /// É para fazer hoje.
  atencao,

  /// Para saber; não pede nada agora.
  info,
}

/// O que acontece ao tocar no botão de uma linha (aprovar, renovar…).
typedef ExecutarAcao =
    Future<void> Function(BuildContext context, WidgetRef ref);

/// Uma linha dentro de uma tarefa: "Ana · 3 a 7 de jul", com o botão que a
/// resolve ali mesmo (se houver).
class ItemTarefa {
  const ItemTarefa(this.texto, {this.rotuloAcao, this.acao});

  final String texto;

  /// Texto do botão ("Aprovar"); `null` = só informação.
  final String? rotuloAcao;
  final ExecutarAcao? acao;

  bool get temAcao => rotuloAcao != null && acao != null;
}

/// Uma coisa a tratar no Início: um grupo (ex. "Férias por aprovar") com as
/// suas linhas. Sem [itens], vale o [resumo] ("3 abaixo do mínimo").
class TarefaHoje {
  const TarefaHoje({
    required this.chave,
    required this.icon,
    required this.titulo,
    required this.urgencia,
    required this.rota,
    this.resumo = '',
    this.quantidade = 0,
    this.itens = const [],
  });

  final String chave;
  final IconData icon;
  final String titulo;
  final Urgencia urgencia;

  /// Onde abre a página completa.
  final String rota;
  final String resumo;

  /// Quantas coisas há (para o número ao lado do título). `0` = usa os itens.
  final int quantidade;
  final List<ItemTarefa> itens;

  int get total => quantidade > 0 ? quantidade : itens.length;

  /// Uma só linha com botão: o botão aparece logo na linha do grupo.
  ItemTarefa? get acaoDireta =>
      itens.length == 1 && itens.first.temAcao ? itens.first : null;

  /// Várias linhas com botões: o grupo abre para as mostrar.
  bool get expansivel => itens.length > 1 && itens.any((i) => i.temAcao);

  /// O que se lê por baixo do título quando o grupo está fechado.
  String get subtitulo {
    if (resumo.isNotEmpty) return resumo;
    return itens.take(3).map((i) => i.texto).join(' · ');
  }
}

/// Separa o que precisa de ti (urgente primeiro) do que é só para saber.
({List<TarefaHoje> precisa, List<TarefaHoje> saber}) separarTarefas(
  List<TarefaHoje> todas,
) {
  final precisa = [
    for (final t in todas)
      if (t.urgencia != Urgencia.info) t,
  ];
  final saber = [
    for (final t in todas)
      if (t.urgencia == Urgencia.info) t,
  ];
  // estável: dentro de cada nível mantém a ordem em que foram juntadas
  final ordem = <TarefaHoje, int>{
    for (var i = 0; i < precisa.length; i++) precisa[i]: i,
  };
  precisa.sort((a, b) {
    final c = a.urgencia.index.compareTo(b.urgencia.index);
    return c != 0 ? c : ordem[a]!.compareTo(ordem[b]!);
  });
  return (precisa: precisa, saber: saber);
}

/// "Bom dia", "Boa tarde" ou "Boa noite".
String saudacao(DateTime agora) {
  final h = agora.hour;
  if (h < 12) return 'Bom dia';
  if (h < 20) return 'Boa tarde';
  return 'Boa noite';
}

const _diasSemana = [
  'segunda-feira',
  'terça-feira',
  'quarta-feira',
  'quinta-feira',
  'sexta-feira',
  'sábado',
  'domingo',
];

const _meses = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

/// "terça-feira, 6 de outubro".
String dataPorExtenso(DateTime d) =>
    '${_diasSemana[d.weekday - 1]}, ${d.day} de ${_meses[d.month - 1]}';

/// O primeiro nome de [nome] ("Ana Silva" → "Ana"); vazio se é um email.
String primeiroNome(String? nome) {
  final n = (nome ?? '').trim();
  if (n.isEmpty || n.contains('@')) return '';
  return n.split(RegExp(r'\s+')).first;
}

/// Dias até ao próximo dia [diaPagamento] deste mês (ou do mês seguinte, se
/// já tiver passado neste). `0` = hoje.
int diasAtePagamento(int diaPagamento, DateTime hoje) {
  final hojeSoData = DateTime(hoje.year, hoje.month, hoje.day);
  var proximo = DateTime(hoje.year, hoje.month, diaPagamento);
  if (proximo.isBefore(hojeSoData)) {
    proximo = DateTime(hoje.year, hoje.month + 1, diaPagamento);
  }
  return proximo.difference(hojeSoData).inDays;
}
