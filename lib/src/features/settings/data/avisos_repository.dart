import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';

/// A configuração dos avisos e do resumo diário da empresa.
class AvisosConfig {
  const AvisosConfig({
    this.id,
    this.ativo = false,
    this.hora = '08:00',
    this.emailAtivo = false,
    this.emailPara = '',
    this.telegramAtivo = false,
    this.telegramChat = '',
    this.incHaccp = true,
    this.incStock = true,
    this.incPagamentos = true,
    this.incFaturas = true,
    this.incPrecos = true,
    this.semanalAtivo = false,
    this.semanalDia = 1,
    this.ultimoEnvio = '',
    this.ultimoResultado = '',
  });

  final String? id;
  final bool ativo;

  /// Hora local do envio, "HH:MM".
  final String hora;
  final bool emailAtivo;
  final String emailPara;
  final bool telegramAtivo;
  final String telegramChat;
  final bool incHaccp;
  final bool incStock;
  final bool incPagamentos;
  final bool incFaturas;
  final bool incPrecos;

  /// Resumo da semana (segunda a domingo) no dia [semanalDia] (1 = segunda).
  final bool semanalAtivo;
  final int semanalDia;
  final String ultimoEnvio;
  final String ultimoResultado;

  AvisosConfig copyWith({
    bool? ativo,
    String? hora,
    bool? emailAtivo,
    String? emailPara,
    bool? telegramAtivo,
    String? telegramChat,
    bool? incHaccp,
    bool? incStock,
    bool? incPagamentos,
    bool? incFaturas,
    bool? incPrecos,
    bool? semanalAtivo,
    int? semanalDia,
  }) => AvisosConfig(
    id: id,
    ativo: ativo ?? this.ativo,
    hora: hora ?? this.hora,
    emailAtivo: emailAtivo ?? this.emailAtivo,
    emailPara: emailPara ?? this.emailPara,
    telegramAtivo: telegramAtivo ?? this.telegramAtivo,
    telegramChat: telegramChat ?? this.telegramChat,
    incHaccp: incHaccp ?? this.incHaccp,
    incStock: incStock ?? this.incStock,
    incPagamentos: incPagamentos ?? this.incPagamentos,
    incFaturas: incFaturas ?? this.incFaturas,
    incPrecos: incPrecos ?? this.incPrecos,
    semanalAtivo: semanalAtivo ?? this.semanalAtivo,
    semanalDia: semanalDia ?? this.semanalDia,
    ultimoEnvio: ultimoEnvio,
    ultimoResultado: ultimoResultado,
  );

  factory AvisosConfig.fromRecord(RecordModel r) {
    final hora = r.getStringValue('hora');
    return AvisosConfig(
      id: r.id,
      ativo: r.getBoolValue('ativo'),
      hora: RegExp(r'^\d{1,2}:\d{2}$').hasMatch(hora) ? hora : '08:00',
      emailAtivo: r.getBoolValue('email_ativo'),
      emailPara: r.getStringValue('email_para'),
      telegramAtivo: r.getBoolValue('telegram_ativo'),
      telegramChat: r.getStringValue('telegram_chat'),
      incHaccp: r.getBoolValue('inc_haccp'),
      incStock: r.getBoolValue('inc_stock'),
      incPagamentos: r.getBoolValue('inc_pagamentos'),
      incFaturas: r.getBoolValue('inc_faturas'),
      incPrecos: r.getBoolValue('inc_precos'),
      semanalAtivo: r.getBoolValue('semanal_ativo'),
      semanalDia:
          (r.getIntValue('semanal_dia') >= 1 &&
              r.getIntValue('semanal_dia') <= 7)
          ? r.getIntValue('semanal_dia')
          : 1,
      ultimoEnvio: r.getStringValue('ultimo_envio'),
      ultimoResultado: r.getStringValue('ultimo_resultado'),
    );
  }

  Map<String, dynamic> toBody() => {
    'ativo': ativo,
    'hora': hora,
    'email_ativo': emailAtivo,
    'email_para': emailPara.trim(),
    'telegram_ativo': telegramAtivo,
    'telegram_chat': telegramChat.trim(),
    'inc_haccp': incHaccp,
    'inc_stock': incStock,
    'inc_pagamentos': incPagamentos,
    'inc_faturas': incFaturas,
    'inc_precos': incPrecos,
    'semanal_ativo': semanalAtivo,
    'semanal_dia': semanalDia,
  };
}

/// O resultado de "enviar um teste".
class ResultadoTeste {
  const ResultadoTeste({
    required this.texto,
    this.resultados = const {},
    this.descricao = '',
  });
  final String texto;

  /// Por canal: '' = enviado; outro texto = o motivo da falha.
  final Map<String, String> resultados;
  final String descricao;
}

class ChatTelegram {
  const ChatTelegram({required this.id, required this.nome});
  final String id;
  final String nome;
}

/// Estado do token do bot do Telegram (nunca o valor).
typedef EstadoTelegram = ({bool configurada, String sufixo, bool cifraOk});

class AvisosRepository {
  AvisosRepository(this._pb, this._empresaId);
  final PocketBase _pb;
  final String _empresaId;

  Future<AvisosConfig> carregar() async {
    final r = await _pb
        .collection('avisos_config')
        .getList(perPage: 1, filter: 'empresa = "$_empresaId"');
    return r.items.isEmpty
        ? const AvisosConfig()
        : AvisosConfig.fromRecord(r.items.first);
  }

  Future<AvisosConfig> guardar(AvisosConfig c) async {
    final col = _pb.collection('avisos_config');
    final rec = c.id == null
        ? await col.create(body: {...c.toBody(), 'empresa': _empresaId})
        : await col.update(c.id!, body: c.toBody());
    return AvisosConfig.fromRecord(rec);
  }

  Future<EstadoTelegram> estadoTelegram() async {
    final r = await _pb.send('/api/gc_turnkey/integracoes/telegram');
    final m = r is Map ? r : const <String, dynamic>{};
    return (
      configurada: m['configurada'] == true,
      sufixo: (m['sufixo'] ?? '').toString(),
      cifraOk: m['cifraDisponivel'] != false,
    );
  }

  Future<void> guardarTokenTelegram(String token) => _pb.send(
    '/api/gc_turnkey/integracoes/telegram',
    method: 'PUT',
    body: {'valor': token.trim()},
  );

  Future<void> removerTokenTelegram() =>
      _pb.send('/api/gc_turnkey/integracoes/telegram', method: 'DELETE');

  Future<List<ChatTelegram>> detetarChats() async {
    final r = await _pb.send(
      '/api/gc_turnkey/avisos/telegram/detetar',
      method: 'POST',
      body: const <String, dynamic>{},
    );
    final m = r is Map ? r : const <String, dynamic>{};
    return [
      for (final c in (m['chats'] as List? ?? const []))
        if (c is Map)
          ChatTelegram(
            id: (c['id'] ?? '').toString(),
            nome: (c['nome'] ?? '').toString(),
          ),
    ];
  }

  Future<ResultadoTeste> testar({
    required bool enviar,
    bool semanal = false,
  }) async {
    final r = await _pb.send(
      '/api/gc_turnkey/avisos/testar',
      method: 'POST',
      body: {'enviar': enviar, if (semanal) 'semanal': true},
    );
    final m = r is Map ? r : const <String, dynamic>{};
    return ResultadoTeste(
      texto: (m['texto'] ?? '').toString(),
      descricao: (m['descricao'] ?? '').toString(),
      resultados: {
        if (m['resultados'] is Map)
          for (final e in (m['resultados'] as Map).entries)
            e.key.toString(): (e.value ?? '').toString(),
      },
    );
  }
}

final avisosRepositoryProvider = Provider<AvisosRepository>(
  (ref) => AvisosRepository(ref.watch(pbProvider), requireEmpresaId(ref)),
);

final avisosConfigProvider = FutureProvider.autoDispose<AvisosConfig>(
  (ref) => ref.watch(avisosRepositoryProvider).carregar(),
);

final estadoTelegramProvider = FutureProvider.autoDispose<EstadoTelegram>(
  (ref) => ref.watch(avisosRepositoryProvider).estadoTelegram(),
);
