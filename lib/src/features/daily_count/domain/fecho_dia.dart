import 'package:flutter/material.dart';

import '../../../app/routes.dart';

/// Como está um passo do fecho do dia.
enum EstadoPasso {
  /// Tratado.
  ok,

  /// Falta fazer (conta para o "faltam N coisas").
  falta,

  /// Só para saber (não bloqueia o fecho).
  info,
}

/// Um passo do "Fecho do dia": o que se viu, em que estado está e onde se trata.
class PassoFecho {
  const PassoFecho({
    required this.chave,
    required this.icon,
    required this.titulo,
    required this.texto,
    required this.estado,
    required this.rota,
  });

  final String chave;
  final IconData icon;
  final String titulo;
  final String texto;
  final EstadoPasso estado;
  final String rota;
}

/// O que se sabe do dia, já em números (o ecrã é que vai buscar os dados).
/// `null` num campo = esta pessoa não tem acesso a essa parte (o passo não
/// aparece).
class DadosFecho {
  const DadosFecho({
    this.semFechoPorLocal,
    this.comFecho = 0,
    this.desperdicioUn,
    this.vendasN,
    this.vendasTotal = 0,
    this.haccpPorFazer,
    this.naoConformidades = 0,
    this.saidasPorMarcar,
    this.aTrabalhar = const [],
    this.planoAmanha,
    this.porComprar,
  });

  /// Por local: quantos sabores tiveram movimento e ainda não têm o fecho
  /// contado.
  final Map<String, int>? semFechoPorLocal;

  /// Quantos sabores já têm o fecho contado.
  final int comFecho;

  /// Unidades de desperdício registadas hoje.
  final double? desperdicioUn;

  final int? vendasN;
  final double vendasTotal;

  final int? haccpPorFazer;
  final int naoConformidades;

  /// Entradas sem saída que já deviam ter acabado.
  final List<String>? saidasPorMarcar;

  /// Quem ainda está a trabalhar (entrou e não saiu).
  final List<String> aTrabalhar;

  /// Há produção agendada para amanhã?
  final bool? planoAmanha;

  /// Itens da lista de compras por comprar.
  final int? porComprar;
}

String _un(double v) {
  final r = v == v.roundToDouble()
      ? v.toInt().toString()
      : v.toStringAsFixed(1);
  return '$r un';
}

/// Os passos do fecho, pela ordem em que se fazem. Cada um só aparece se a
/// pessoa tem acesso a essa parte.
List<PassoFecho> passosFecho(
  DadosFecho d, {
  required String Function(double) dinheiro,
}) {
  final out = <PassoFecho>[];

  final sem = d.semFechoPorLocal;
  if (sem != null) {
    final faltam = sem.values.fold<int>(0, (s, n) => s + n);
    if (faltam > 0) {
      final onde = [
        for (final e in sem.entries)
          if (e.value > 0) '${e.key} (${e.value})',
      ].join(', ');
      out.add(
        PassoFecho(
          chave: 'contagem',
          icon: Icons.fact_check_outlined,
          titulo: 'Contar o que sobrou',
          texto:
              'Falta o fecho de $faltam sabor${faltam == 1 ? '' : 'es'}: $onde',
          estado: EstadoPasso.falta,
          rota: Routes.contagem,
        ),
      );
    } else {
      out.add(
        PassoFecho(
          chave: 'contagem',
          icon: Icons.fact_check_outlined,
          titulo: 'Contar o que sobrou',
          texto: d.comFecho > 0
              ? 'Fecho contado em ${d.comFecho} sabor${d.comFecho == 1 ? '' : 'es'}'
              : 'Sem movimento na contagem hoje',
          estado: d.comFecho > 0 ? EstadoPasso.ok : EstadoPasso.info,
          rota: Routes.contagem,
        ),
      );
    }
  }

  final desp = d.desperdicioUn;
  if (desp != null) {
    out.add(
      PassoFecho(
        chave: 'desperdicio',
        icon: Icons.delete_sweep_outlined,
        titulo: 'Desperdício',
        texto: desp > 0
            ? '${_un(desp)} registadas hoje'
            : 'Nada registado hoje. Queimou ou caiu alguma coisa? Regista na Contagem',
        estado: EstadoPasso.info,
        rota: Routes.contagem,
      ),
    );
  }

  final vn = d.vendasN;
  if (vn != null) {
    out.add(
      PassoFecho(
        chave: 'vendas',
        icon: Icons.point_of_sale_outlined,
        titulo: 'Vendas do dia',
        texto: vn > 0
            ? '$vn venda${vn == 1 ? '' : 's'} · ${dinheiro(d.vendasTotal)}'
            : 'Ainda sem vendas registadas hoje',
        estado: vn > 0 ? EstadoPasso.ok : EstadoPasso.info,
        rota: Routes.sales,
      ),
    );
  }

  final h = d.haccpPorFazer;
  if (h != null) {
    final falta = h > 0 || d.naoConformidades > 0;
    out.add(
      PassoFecho(
        chave: 'haccp',
        icon: Icons.health_and_safety_outlined,
        titulo: 'HACCP',
        texto: falta
            ? [
                if (h > 0) '$h controlo${h == 1 ? '' : 's'} por fazer',
                if (d.naoConformidades > 0)
                  '${d.naoConformidades} não conformidade${d.naoConformidades == 1 ? '' : 's'}',
              ].join(' · ')
            : 'Controlos de hoje em dia',
        estado: falta ? EstadoPasso.falta : EstadoPasso.ok,
        rota: Routes.haccp,
      ),
    );
  }

  final s = d.saidasPorMarcar;
  if (s != null) {
    final ficam = d.aTrabalhar;
    out.add(
      PassoFecho(
        chave: 'ponto',
        icon: Icons.fingerprint,
        titulo: 'Ponto da equipa',
        texto: s.isNotEmpty
            ? 'Falta marcar a saída: ${s.join(', ')}'
            : (ficam.isNotEmpty
                  ? 'Ainda a trabalhar: ${ficam.join(', ')}'
                  : 'Sem saídas por marcar'),
        estado: s.isNotEmpty
            ? EstadoPasso.falta
            : (ficam.isNotEmpty ? EstadoPasso.info : EstadoPasso.ok),
        rota: Routes.pessoasPonto,
      ),
    );
  }

  final p = d.planoAmanha;
  if (p != null) {
    out.add(
      PassoFecho(
        chave: 'amanha',
        icon: Icons.local_fire_department_outlined,
        titulo: 'Amanhã',
        texto: p
            ? 'Produção agendada para amanhã'
            : 'Nada agendado para amanhã. Vê quantos assar',
        estado: p ? EstadoPasso.ok : EstadoPasso.info,
        rota: p ? Routes.schedule : Routes.productionPrevisao,
      ),
    );
  }

  final c = d.porComprar;
  if (c != null) {
    out.add(
      PassoFecho(
        chave: 'compras',
        icon: Icons.shopping_cart_outlined,
        titulo: 'Compras',
        texto: c > 0
            ? '$c ite${c == 1 ? 'm' : 'ns'} por comprar'
            : 'Lista de compras em dia',
        estado: c > 0 ? EstadoPasso.info : EstadoPasso.ok,
        rota: Routes.shopping,
      ),
    );
  }
  return out;
}

/// "Tudo em ordem" ou "Falta 1 coisa" / "Faltam 3 coisas".
String resumoFecho(List<PassoFecho> passos) {
  final faltam = passos.where((p) => p.estado == EstadoPasso.falta).length;
  if (passos.isEmpty) return 'Nada para fechar';
  if (faltam == 0) return 'Tudo em ordem — bom descanso!';
  return faltam == 1 ? 'Falta 1 coisa' : 'Faltam $faltam coisas';
}
