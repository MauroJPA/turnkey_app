import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/pocketbase/pb_client.dart';

final telegramPessoalRepositoryProvider = Provider<TelegramPessoalRepository>(
  (ref) => TelegramPessoalRepository(ref.watch(pbProvider)),
);

/// O meu Telegram: ligado (e com que nome) ou não.
class EstadoTelegramPessoal {
  const EstadoTelegramPessoal({
    this.id = '',
    this.ligado = false,
    this.nome = '',
  });

  final String id;
  final bool ligado;
  final String nome;
}

/// O Telegram de cada pessoa (`telegram_pessoas`), para receber as menções.
class TelegramPessoalRepository {
  TelegramPessoalRepository(this._pb);

  final PocketBase _pb;

  String get _uid => _pb.authStore.record?.id ?? '';

  Future<EstadoTelegramPessoal> estado() async {
    final l = await _pb
        .collection('telegram_pessoas')
        .getList(perPage: 1, filter: _pb.filter('user = {:u}', {'u': _uid}));
    if (l.items.isEmpty) return const EstadoTelegramPessoal();
    final r = l.items.first;
    final chat = r.getStringValue('chat');
    return EstadoTelegramPessoal(
      id: r.id,
      ligado: chat.isNotEmpty,
      nome: r.getStringValue('nome'),
    );
  }

  /// O link `t.me/<bot>?start=<código>` para abrir o bot.
  Future<String> pedirLink() async {
    final r = await _pb.send(
      '/api/gc_turnkey/telegram/pessoal/ligar',
      method: 'POST',
    );
    return (r as Map)['link'] as String? ?? '';
  }

  /// Vê já se a pessoa carregou em "Iniciar" (o servidor pergunta ao Telegram).
  Future<bool> verificar() async {
    final r = await _pb.send(
      '/api/gc_turnkey/telegram/pessoal/verificar',
      method: 'POST',
    );
    return (r as Map)['ligado'] == true;
  }

  Future<void> testar() =>
      _pb.send('/api/gc_turnkey/telegram/pessoal/testar', method: 'POST');

  Future<void> desligar(String id) =>
      _pb.collection('telegram_pessoas').delete(id);
}

/// O estado do meu Telegram (para o menu e o ecrã de ligar).
final telegramPessoalProvider =
    FutureProvider.autoDispose<EstadoTelegramPessoal>(
      (ref) => ref.watch(telegramPessoalRepositoryProvider).estado(),
    );
