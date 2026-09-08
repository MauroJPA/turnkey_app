import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../domain/fatura.dart';

final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  return InvoiceRepository(ref.watch(pbProvider), requireEmpresaId(ref));
});

/// Uma linha pronta a aplicar (do ecrã de revisão).
typedef LinhaAAplicar = ({
  String? ingredienteId,
  String descricaoFatura,
  double quantidadeG,
  double precoUnitario,
  double totalLinha,
  double embalagemG,
  AcaoFatura acao,
});

class InvoiceRepository {
  InvoiceRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  RecordService get _c => _pb.collection('faturas');

  Future<List<Fatura>> list() async {
    final recs = await _c.getFullList(
      filter: 'empresa = "$_empresaId"',
      sort: '-created',
    );
    return recs.map(Fatura.fromRecord).toList();
  }

  Future<Fatura> getById(String id) async =>
      Fatura.fromRecord(await _c.getOne(id));

  Future<Fatura> criar({
    required FaturaTipo tipo,
    required String fornecedor,
    required List<int> bytes,
    required String nome,
  }) async {
    final rec = await _c.create(
      body: {
        'empresa': _empresaId,
        'tipo': tipo.api,
        'fornecedor': fornecedor.trim(),
        'estado': 'nova',
        if (_pb.authStore.record != null) 'autor': _pb.authStore.record!.id,
      },
      files: [http.MultipartFile.fromBytes('ficheiro', bytes, filename: nome)],
    );
    return Fatura.fromRecord(rec);
  }

  String _mime(String nome) {
    final n = nome.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.pdf')) return 'application/pdf';
    return 'image/jpeg';
  }

  Future<Fatura> analisar(
    String id, {
    required List<int> bytes,
    required String nome,
  }) async {
    await _pb.send(
      '/api/turnkey/faturas/$id/analisar',
      method: 'POST',
      body: {
        'imagem': base64Encode(bytes),
        'mime': _mime(nome),
      },
    );
    return getById(id);
  }

  Future<({int precos, int movimentos})> aplicar(
    String id,
    List<LinhaAAplicar> linhas,
  ) async {
    final res = await _pb.send(
      '/api/turnkey/faturas/$id/aplicar',
      method: 'POST',
      body: {
        'linhas': [
          for (final l in linhas)
            {
              if (l.ingredienteId != null) 'ingredienteId': l.ingredienteId,
              'descricaoFatura': l.descricaoFatura,
              'quantidadeG': l.quantidadeG,
              'precoUnitario': l.precoUnitario,
              'totalLinha': l.totalLinha,
              'embalagemG': l.embalagemG,
              'acao': l.acao.api,
            },
        ],
      },
    );
    final m = res as Map;
    return (
      precos: (m['precos'] as num?)?.toInt() ?? 0,
      movimentos: (m['movimentos'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> apagar(String id) => _c.delete(id);

  String ficheiroUrl(Fatura f, {bool thumb = false}) {
    if (!f.temFicheiro) return '';
    final base = _pb.baseURL.endsWith('/')
        ? _pb.baseURL.substring(0, _pb.baseURL.length - 1)
        : _pb.baseURL;
    final u = '$base/api/files/faturas/${f.id}/${f.ficheiro}';
    return thumb ? '$u?thumb=0x240' : u;
  }
}
