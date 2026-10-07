import 'package:flutter/material.dart';

import '../../../app/routes.dart';

/// Um passo da checklist "Primeiros passos" (o servidor diz se está feito).
class PassoArranque {
  const PassoArranque({
    required this.chave,
    required this.feito,
    this.detalhe = '',
  });

  final String chave;
  final bool feito;
  final String detalhe;

  factory PassoArranque.fromJson(Map<String, dynamic> j) => PassoArranque(
    chave: '${j['chave'] ?? ''}',
    feito: j['feito'] == true,
    detalhe: '${j['detalhe'] ?? ''}',
  );

  /// Texto, ícone e destino deste passo (o que o servidor não sabe).
  InfoPasso get info => infoPasso(chave);
}

/// O que se mostra de cada passo.
class InfoPasso {
  const InfoPasso({
    required this.titulo,
    required this.icon,
    this.rota,
    this.ajuda = '',
  });

  final String titulo;
  final IconData icon;

  /// Para onde o toque leva; `null` = só mostra a [ajuda].
  final String? rota;
  final String ajuda;
}

InfoPasso infoPasso(String chave) => switch (chave) {
  'empresa' => const InfoPasso(
    titulo: 'Logótipo e cores',
    icon: Icons.storefront_outlined,
    rota: Routes.opcoesEmpresa,
  ),
  'dias' => const InfoPasso(
    titulo: 'Dias em que trabalhas',
    icon: Icons.calendar_month_outlined,
    rota: Routes.opcoesCustos,
  ),
  'ingredientes' => const InfoPasso(
    titulo: 'Ingredientes',
    icon: Icons.kitchen_outlined,
    rota: Routes.ingredients,
  ),
  'precos' => const InfoPasso(
    titulo: 'Preços dos ingredientes',
    icon: Icons.euro,
    rota: Routes.ingredients,
  ),
  'receitas' => const InfoPasso(
    titulo: 'Primeira receita',
    icon: Icons.menu_book_outlined,
    rota: Routes.recipes,
  ),
  'fichas' => const InfoPasso(
    titulo: 'Primeiro produto (ficha técnica)',
    icon: Icons.cookie_outlined,
    rota: Routes.techSheets,
  ),
  'equipa' => const InfoPasso(
    titulo: 'Equipa e cartões',
    icon: Icons.groups_outlined,
    rota: Routes.colaboradores,
  ),
  'horarios' => const InfoPasso(
    titulo: 'Horários da equipa',
    icon: Icons.schedule,
    rota: Routes.pessoasEscala,
  ),
  'avisos' => const InfoPasso(
    titulo: 'Avisos por Telegram ou email',
    icon: Icons.notifications_active_outlined,
    rota: Routes.avisos,
  ),
  'ia' => const InfoPasso(
    titulo: 'IA para ler faturas',
    icon: Icons.auto_awesome_outlined,
    ajuda:
        'No servidor, põe a chave no ficheiro .env (GEMINI_API_KEY) e '
        'reinicia: cd /opt/gc_turnkey && bash gc_turnkey.sh reiniciar',
  ),
  'backups' => const InfoPasso(
    titulo: 'Cópia de segurança externa',
    icon: Icons.backup_outlined,
    rota: Routes.opcoesSeguranca,
  ),
  'vigia' => const InfoPasso(
    titulo: 'Vigia de segurança do servidor',
    icon: Icons.shield_outlined,
    rota: Routes.opcoesSeguranca,
    ajuda:
        'No servidor: cd /opt/gc_turnkey && sudo bash seguranca/instalar-vigia.sh',
  ),
  _ => InfoPasso(titulo: chave, icon: Icons.check_circle_outline),
};

/// A checklist inteira.
class Arranque {
  const Arranque(this.passos);

  final List<PassoArranque> passos;

  int get total => passos.length;
  int get feitos => passos.where((p) => p.feito).length;
  bool get completo => total > 0 && feitos == total;
  double get progresso => total == 0 ? 1 : feitos / total;

  /// O que falta, pela ordem em que faz sentido fazer.
  List<PassoArranque> get porFazer => [
    for (final p in passos)
      if (!p.feito) p,
  ];

  factory Arranque.fromJson(Map<String, dynamic> j) => Arranque([
    for (final p in (j['passos'] as List? ?? const []))
      if (p is Map) PassoArranque.fromJson(Map<String, dynamic>.from(p)),
  ]);
}
