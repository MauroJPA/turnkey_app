import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../schedule/domain/production_plan.dart';

/// Uma linha do carrinho "adicionar à agenda" (ainda não persistida).
class CartLinha {
  const CartLinha({
    required this.id,
    required this.receitaId,
    required this.receitaNome,
    required this.kg,
    required this.formatoId,
    required this.formatoNome,
    required this.unidadesPrevistas,
    this.recheioId,
    this.recheioNome,
    this.prioridade = Prioridade.media,
    this.horaLimite = '',
  });

  final String id; // chave local (timestamp)
  final String receitaId;
  final String receitaNome;
  final double kg;
  final String formatoId;
  final String formatoNome;
  final int unidadesPrevistas;
  final String? recheioId;
  final String? recheioNome;
  final Prioridade prioridade;
  final String horaLimite;

  CartLinha copyWith({
    double? kg,
    String? formatoId,
    String? formatoNome,
    int? unidadesPrevistas,
    String? recheioId,
    String? recheioNome,
    bool limparRecheio = false,
    Prioridade? prioridade,
    String? horaLimite,
  }) =>
      CartLinha(
        id: id,
        receitaId: receitaId,
        receitaNome: receitaNome,
        kg: kg ?? this.kg,
        formatoId: formatoId ?? this.formatoId,
        formatoNome: formatoNome ?? this.formatoNome,
        unidadesPrevistas: unidadesPrevistas ?? this.unidadesPrevistas,
        recheioId: limparRecheio ? null : (recheioId ?? this.recheioId),
        recheioNome: limparRecheio ? null : (recheioNome ?? this.recheioNome),
        prioridade: prioridade ?? this.prioridade,
        horaLimite: horaLimite ?? this.horaLimite,
      );
}

final agendaCartProvider =
    NotifierProvider<AgendaCart, List<CartLinha>>(AgendaCart.new);

class AgendaCart extends Notifier<List<CartLinha>> {
  @override
  List<CartLinha> build() => const [];

  void adicionar(CartLinha linha) => state = [...state, linha];

  void substituir(CartLinha linha) => state = [
        for (final l in state) if (l.id == linha.id) linha else l,
      ];

  void remover(String id) =>
      state = [for (final l in state) if (l.id != id) l];

  void limpar() => state = const [];
}
