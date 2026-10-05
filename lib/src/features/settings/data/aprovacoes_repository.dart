import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/pocketbase/pb_client.dart';

/// Uma conta nova à espera de aprovação.
class ContaPendente {
  const ContaPendente({
    required this.id,
    required this.email,
    this.nome = '',
    this.criada,
  });

  final String id;
  final String email;
  final String nome;
  final DateTime? criada;

  factory ContaPendente.fromJson(Map<String, dynamic> j) => ContaPendente(
    id: (j['id'] ?? '').toString(),
    email: (j['email'] ?? '').toString(),
    nome: (j['nome'] ?? '').toString(),
    criada: DateTime.tryParse(
      (j['criada'] ?? '').toString().replaceFirst(' ', 'T'),
    ),
  );
}

/// O que o servidor devolve: se és o operador da plataforma e, nesse caso, as
/// contas por aprovar.
class Aprovacoes {
  const Aprovacoes({this.operador = false, this.pendentes = const []});
  final bool operador;
  final List<ContaPendente> pendentes;
}

class AprovacoesRepository {
  AprovacoesRepository(this._pb);
  final PocketBase _pb;

  Future<Aprovacoes> carregar() async {
    final res = await _pb.send('/api/gc_turnkey/aprovacoes');
    final m = res is Map ? res : const <String, dynamic>{};
    return Aprovacoes(
      operador: m['operador'] == true,
      pendentes: [
        for (final p in (m['pendentes'] as List? ?? const []))
          if (p is Map) ContaPendente.fromJson(Map<String, dynamic>.from(p)),
      ],
    );
  }

  Future<void> aprovar(String id) =>
      _pb.send('/api/gc_turnkey/aprovacoes/$id/aprovar', method: 'POST');

  Future<void> recusar(String id) =>
      _pb.send('/api/gc_turnkey/aprovacoes/$id/recusar', method: 'POST');
}

final aprovacoesRepositoryProvider = Provider<AprovacoesRepository>(
  (ref) => AprovacoesRepository(ref.watch(pbProvider)),
);

/// As contas por aprovar (só o operador da plataforma vê dados).
final aprovacoesProvider = FutureProvider.autoDispose<Aprovacoes>((ref) {
  return ref.watch(aprovacoesRepositoryProvider).carregar();
});
