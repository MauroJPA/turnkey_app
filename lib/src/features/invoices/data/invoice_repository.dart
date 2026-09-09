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
      files: [
        http.MultipartFile.fromBytes(
          'ficheiro',
          bytes,
          // Nome provisório com a data de hoje; renomeado para a data da
          // fatura depois da análise (renomearFicheiro).
          filename: nomeFicheiro(fornecedor, DateTime.now(), nome),
        ),
      ],
    );
    return Fatura.fromRecord(rec);
  }

  /// Re-carrega o mesmo ficheiro com o nome final `FT-FORNECEDOR-DDMMAAAA`,
  /// já com a data lida da fatura.
  Future<Fatura> renomearFicheiro(
    String id, {
    required List<int> bytes,
    required String nomeOriginal,
    required String fornecedor,
    required DateTime dataFatura,
  }) async {
    final rec = await _c.update(
      id,
      files: [
        http.MultipartFile.fromBytes(
          'ficheiro',
          bytes,
          filename: nomeFicheiro(fornecedor, dataFatura, nomeOriginal),
        ),
      ],
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

  static String _ext(String nome) {
    final n = nome.toLowerCase();
    for (final e in const ['.jpeg', '.jpg', '.png', '.webp', '.pdf']) {
      if (n.endsWith(e)) return e;
    }
    return '.jpg';
  }

  static String _slugFornecedor(String s) {
    const acc = {
      'Á': 'A', 'À': 'A', 'Ã': 'A', 'Â': 'A', 'Ä': 'A',
      'É': 'E', 'È': 'E', 'Ê': 'E', 'Ë': 'E',
      'Í': 'I', 'Ì': 'I', 'Î': 'I', 'Ï': 'I',
      'Ó': 'O', 'Ò': 'O', 'Õ': 'O', 'Ô': 'O', 'Ö': 'O',
      'Ú': 'U', 'Ù': 'U', 'Û': 'U', 'Ü': 'U',
      'Ç': 'C',
    };
    var out = s.toUpperCase();
    acc.forEach((k, v) => out = out.replaceAll(k, v));
    out = out.replaceAll(RegExp('[^A-Z0-9]'), '');
    if (out.isEmpty) return 'FORNECEDOR';
    return out.length > 40 ? out.substring(0, 40) : out;
  }

  /// `FT-NOMEFORNECEDOR-DDMMAAAA.ext` (o PocketBase normaliza e junta um
  /// sufixo aleatório ao guardar).
  static String nomeFicheiro(String fornecedor, DateTime data, String origem) {
    final dd = data.day.toString().padLeft(2, '0');
    final mm = data.month.toString().padLeft(2, '0');
    final aaaa = data.year.toString().padLeft(4, '0');
    return 'FT-${_slugFornecedor(fornecedor)}-$dd$mm$aaaa${_ext(origem)}';
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

  Future<({int precos, int precosIgnorados, int movimentos})> aplicar(
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
      precosIgnorados: (m['precosIgnorados'] as num?)?.toInt() ?? 0,
      movimentos: (m['movimentos'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> apagar(String id) => _c.delete(id);

  /// Faturas confirmadas no intervalo (para o contabilista). Cada item tem
  /// `fornecedor`, `dataFatura`, `numero`, `total`, `iva`, `nomeFicheiro`,
  /// `ficheiroUrl`, `linhas`.
  Future<List<Map<String, dynamic>>> exportContabilidade({
    required String de,
    required String ate,
  }) async {
    final res = await _pb.send(
      '/api/turnkey/faturas/export?de=$de&ate=$ate',
      method: 'GET',
    );
    final list = (res as Map)['faturas'];
    return list is List
        ? list.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];
  }

  String ficheiroUrl(Fatura f, {bool thumb = false}) {
    if (!f.temFicheiro) return '';
    final base = _pb.baseURL.endsWith('/')
        ? _pb.baseURL.substring(0, _pb.baseURL.length - 1)
        : _pb.baseURL;
    final u = '$base/api/files/faturas/${f.id}/${f.ficheiro}';
    return thumb ? '$u?thumb=0x240' : u;
  }
}
