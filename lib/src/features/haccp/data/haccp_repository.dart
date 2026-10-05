import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/formatting/pb_data_hora.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../../sales/domain/venda.dart' show ymd;
import '../domain/haccp.dart';

final haccpRepositoryProvider = Provider<HaccpRepository>((ref) {
  return HaccpRepository(ref.watch(pbProvider), requireEmpresaId(ref));
});

/// Controlos de segurança alimentar e os seus registos
/// (`haccp_controlos`, `haccp_registos`).
class HaccpRepository {
  HaccpRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  RecordService get _controlos => _pb.collection('haccp_controlos');
  RecordService get _registos => _pb.collection('haccp_registos');

  // --- controlos ------------------------------------------------------------

  Future<List<ControloHaccp>> listControlos({
    bool incluirArquivados = false,
  }) async {
    final filtros = ['empresa = "$_empresaId"'];
    if (!incluirArquivados) filtros.add('arquivado != true');
    final recs = await _controlos.getFullList(
      filter: filtros.join(' && '),
      sort: 'ordem,nome',
    );
    return recs.map(ControloHaccp.fromRecord).toList();
  }

  Future<void> criarControlo(ControloInput input) => _controlos.create(
    body: {...input.toBody(), 'empresa': _empresaId, 'arquivado': false},
  );

  Future<void> atualizarControlo(String id, ControloInput input) =>
      _controlos.update(id, body: input.toBody());

  Future<void> arquivarControlo(String id, {required bool arquivado}) =>
      _controlos.update(id, body: {'arquivado': arquivado});

  /// Cria os controlos habituais (frigorífico, limpezas, pragas, extintor…).
  Future<void> criarHabituais() async {
    for (final c in controlosHabituais()) {
      await criarControlo(c);
    }
  }

  // --- registos ---------------------------------------------------------------

  /// Registos entre [desde] e [ate] (dias locais, inclusive).
  Future<List<RegistoHaccp>> registos({
    required DateTime desde,
    required DateTime ate,
    String? controloId,
  }) async {
    final inicio = DateTime(desde.year, desde.month, desde.day);
    final fim = DateTime(ate.year, ate.month, ate.day + 1);
    final filtros = [
      'empresa = "$_empresaId"',
      'data_hora >= "${pbDataHora(inicio)}"',
      'data_hora < "${pbDataHora(fim)}"',
      if (controloId != null) 'controlo = "$controloId"',
    ];
    final recs = await _registos.getFullList(
      filter: filtros.join(' && '),
      sort: '-data_hora',
    );
    return recs.map(RegistoHaccp.fromRecord).toList();
  }

  Future<void> registar({
    required String controloId,
    required DateTime dataHora,
    double? valor,
    required bool conforme,
    String responsavel = '',
    String notas = '',
    String acaoCorretiva = '',
    DateTime? proximoVencimento,

    /// Id escolhido por quem chama (15 letras/números): permite reenviar um
    /// registo sem o duplicar (usado pelo quiosque sem ligação).
    String? id,
  }) => _registos.create(
    body: {
      if (id != null) 'id': id,
      'empresa': _empresaId,
      'controlo': controloId,
      'data_hora': pbDataHora(dataHora),
      if (valor != null) 'valor': valor,
      'conforme': conforme,
      'responsavel': responsavel.trim(),
      'notas': notas.trim(),
      'acao_corretiva': acaoCorretiva.trim(),
      'resolvido': false,
      if (proximoVencimento != null)
        'proximo_vencimento': ymd(proximoVencimento),
      if (_pb.authStore.record != null) 'autor': _pb.authStore.record!.id,
    },
  );

  /// Emite um relatório: reserva o número seguinte desta empresa e ano
  /// (HACCP-2026-0007) e guarda o período, o tipo e a impressão digital dos
  /// dados. Devolve o código.
  Future<String> emitirRelatorio({
    required String tipo,
    required DateTime desde,
    required DateTime ate,
    required int registos,
    required int naoConformidades,
    required String integridade,
  }) async {
    final ano = DateTime.now().year;
    final col = _pb.collection('haccp_relatorios');
    for (var tentativa = 0; tentativa < 3; tentativa++) {
      final ultimo = await col.getList(
        perPage: 1,
        sort: '-sequencia',
        filter: 'empresa = "$_empresaId" && ano = $ano',
      );
      final seq = ultimo.items.isEmpty
          ? 1
          : ultimo.items.first.getIntValue('sequencia') + 1;
      final codigo = 'HACCP-$ano-${seq.toString().padLeft(4, '0')}';
      try {
        await col.create(
          body: {
            'empresa': _empresaId,
            'codigo': codigo,
            'ano': ano,
            'sequencia': seq,
            'tipo': tipo,
            'desde': ymd(desde),
            'ate': ymd(ate),
            'registos': registos,
            'nao_conformidades': naoConformidades,
            'integridade': integridade,
            if (_pb.authStore.record != null) 'autor': _pb.authStore.record!.id,
          },
        );
        return codigo;
      } on ClientException catch (e) {
        // outro aparelho reservou este número ao mesmo tempo: tenta o seguinte
        if (e.statusCode != 400 || tentativa == 2) rethrow;
      }
    }
    throw StateError('Não foi possível numerar o relatório.');
  }

  /// Marca uma não conformidade como tratada.
  Future<void> resolver(String registoId, {String acaoCorretiva = ''}) =>
      _registos.update(
        registoId,
        body: {
          'resolvido': true,
          if (acaoCorretiva.trim().isNotEmpty)
            'acao_corretiva': acaoCorretiva.trim(),
        },
      );
}
