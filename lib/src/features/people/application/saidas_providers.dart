import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_user.dart';
import '../domain/escala.dart';
import '../domain/ponto.dart';
import 'escala_providers.dart';
import 'ponto_providers.dart';

/// Quem entrou e ainda não marcou a saída, passado o que era normal (só para
/// a administração, que é quem vê as marcações de todos).
final saidasPorMarcarProvider = Provider.autoDispose<List<SaidaPorMarcar>>((
  ref,
) {
  if (!ref.watch(currentPapelProvider).canEditConfig) return const [];
  final regs = ref.watch(pontoRecenteProvider).valueOrNull ?? const [];
  if (regs.isEmpty) return const [];
  final agora = DateTime.now();
  final hoje = DateTime(agora.year, agora.month, agora.day);
  final modelo = ref.watch(escalaModeloProvider).valueOrNull ?? const [];
  final regras = ref.watch(escalaRegrasProvider).valueOrNull ?? const [];
  final excecoes =
      ref
          .watch(
            escalaExcecoesProvider((
              de: DateTime(hoje.year, hoje.month, hoje.day - 3),
              ate: DateTime(hoje.year, hoje.month, hoje.day + 1),
            )),
          )
          .valueOrNull ??
      const [];
  return saidasPorMarcar(
    calcularJornadas(regs, agora),
    agora,
    fimPrevisto: (pessoa, entrada) => fimDoTurno(
      diaDaEscala(
        pessoa: pessoa,
        dia: DateTime(entrada.year, entrada.month, entrada.day),
        modelo: modelo,
        excecoes: excecoes,
        regras: regras,
      ),
    ),
  );
});
