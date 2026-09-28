import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../domain/analise_resumo.dart';
import '../domain/fatura.dart';

/// Resultado de analisar um ficheiro: a fatura original, os ids de todas as
/// faturas criadas a partir dele e se o PDF foi cortado em ficheiros separados.
typedef AnaliseFaturas = ({
  Fatura fatura,
  List<String> ids,
  bool dividido,
  int duplicadas,
  ResumoAnalise resumo,
});

final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  return InvoiceRepository(ref.watch(pbProvider), requireEmpresaId(ref));
});

/// Uma linha pronta a aplicar (do ecrã de revisão).
typedef LinhaAAplicar = ({
  /// Posição desta linha em `fatura.linhasIa` — o servidor usa-a para saber o
  /// que já foi aplicado antes e não voltar a tocar (aplicar por partes).
  int index,
  String? ingredienteId,
  String? consumivelId,
  String? embalagemId,
  String descricaoFatura,
  double quantidadeG,
  double precoUnitario,
  double totalLinha,
  double embalagemG,
  AcaoFatura acao,
  String? produtoId,
  String marca,
  String produtoNome,
});

/// Resultado de aplicar as linhas de uma fatura.
typedef ResultadoAplicar = ({
  int precos,
  int precosIgnorados,
  int movimentos,
  int pendentes,
  int puladas,
});

class InvoiceRepository {
  InvoiceRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  RecordService get _c => _pb.collection('faturas');

  Future<List<Fatura>> list() async {
    final recs = await _c.getFullList(
      filter: 'empresa = "$_empresaId" && apagada != true',
      sort: '-created',
    );
    return recs.map(Fatura.fromRecord).toList();
  }

  /// Faturas apagadas pelo proprietário (continuam na base de dados).
  Future<List<Fatura>> listApagadas() async {
    final recs = await _c.getFullList(
      filter: 'empresa = "$_empresaId" && apagada = true',
      sort: '-apagada_em',
    );
    return recs.map(Fatura.fromRecord).toList();
  }

  /// Corrige fornecedor, número, data e total (só o proprietário; fica no histórico).
  Future<Fatura> editar(
    String id, {
    required String fornecedor,
    required String numero,
    DateTime? data,
    double? total,
  }) async {
    String dia(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} 00:00:00.000Z';
    final rec = await _c.update(
      id,
      body: {
        'fornecedor': fornecedor.trim(),
        'numero': numero.trim(),
        'data_fatura': data == null ? '' : dia(data),
        if (total != null) 'total': total,
      },
    );
    return Fatura.fromRecord(rec);
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
      'Á': 'A',
      'À': 'A',
      'Ã': 'A',
      'Â': 'A',
      'Ä': 'A',
      'É': 'E',
      'È': 'E',
      'Ê': 'E',
      'Ë': 'E',
      'Í': 'I',
      'Ì': 'I',
      'Î': 'I',
      'Ï': 'I',
      'Ó': 'O',
      'Ò': 'O',
      'Õ': 'O',
      'Ô': 'O',
      'Ö': 'O',
      'Ú': 'U',
      'Ù': 'U',
      'Û': 'U',
      'Ü': 'U',
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

  /// Analisa o ficheiro. Se tiver várias faturas (ex.: um PDF com 3 fornecedores),
  /// o servidor cria uma fatura por documento e [ids] tem todas; [fatura] é a
  /// original (a primeira).
  Future<AnaliseFaturas> analisar(
    String id, {
    required List<int> bytes,
    required String nome,
  }) async {
    final res = await _pb.send(
      '/api/gc_turnkey/faturas/$id/analisar',
      method: 'POST',
      body: {'imagem': base64Encode(bytes), 'mime': _mime(nome)},
    );
    final m = res is Map ? res : const <String, dynamic>{};
    final ids = [
      for (final v in (m['faturas'] as List? ?? const [])) v.toString(),
    ];
    return (
      fatura: await getById(id),
      ids: ids.isEmpty ? [id] : ids,
      dividido: m['dividido'] == true,
      duplicadas: (m['duplicadas'] as num?)?.toInt() ?? 0,
      resumo: const ResumoAnalise(),
    );
  }

  /// Ficheiros grandes: o servidor lê o ficheiro já guardado e analisa-o por
  /// janelas de páginas (uma por pedido), para se ver o progresso e retomar.
  Future<({int paginas, int proxima, bool retomado})> preparar(
    String id,
  ) async {
    final res = await _pb.send(
      '/api/gc_turnkey/faturas/$id/preparar',
      method: 'POST',
      body: const {},
    );
    final m = res is Map ? res : const <String, dynamic>{};
    return (
      paginas: (m['paginas'] as num?)?.toInt() ?? 1,
      proxima: (m['proxima'] as num?)?.toInt() ?? 1,
      retomado: m['retomado'] == true,
    );
  }

  /// Lê a próxima janela de páginas. `feito` quando já não há mais.
  Future<({bool feito, int proxima, int paginas})> analisarParte(
    String id,
  ) async {
    final res = await _pb.send(
      '/api/gc_turnkey/faturas/$id/analisar-parte',
      method: 'POST',
      body: const {},
    );
    final m = res is Map ? res : const <String, dynamic>{};
    return (
      feito: m['feito'] == true,
      proxima: (m['proxima'] as num?)?.toInt() ?? 1,
      paginas: (m['paginas'] as num?)?.toInt() ?? 1,
    );
  }

  /// Junta as janelas, separa as faturas (uma por documento) e grava.
  Future<AnaliseFaturas> concluirAnalise(String id) async {
    final res = await _pb.send(
      '/api/gc_turnkey/faturas/$id/concluir-analise',
      method: 'POST',
      body: const {},
    );
    final m = res is Map ? res : const <String, dynamic>{};
    final ids = [
      for (final v in (m['faturas'] as List? ?? const [])) v.toString(),
    ];
    return (
      fatura: await getById(id),
      ids: ids.isEmpty ? [id] : ids,
      dividido: m['dividido'] == true,
      duplicadas: (m['duplicadas'] as num?)?.toInt() ?? 0,
      resumo: ResumoAnalise.fromJson(m['resumo']),
    );
  }

  /// Volta a descarregar o ficheiro guardado (para tentar a análise de novo).
  Future<List<int>> descarregarFicheiro(Fatura f) async {
    final url = await ficheiroUrlSeguro(f);
    final r = await http.get(Uri.parse(url));
    if (r.statusCode != 200) {
      throw Exception('Não foi possível obter o ficheiro da fatura.');
    }
    return r.bodyBytes;
  }

  Future<ResultadoAplicar> aplicar(
    String id,
    List<LinhaAAplicar> linhas,
  ) async {
    final res = await _pb.send(
      '/api/gc_turnkey/faturas/$id/aplicar',
      method: 'POST',
      body: {
        'linhas': [
          for (final l in linhas)
            {
              'index': l.index,
              if (l.ingredienteId != null) 'ingredienteId': l.ingredienteId,
              'descricaoFatura': l.descricaoFatura,
              'quantidadeG': l.quantidadeG,
              'precoUnitario': l.precoUnitario,
              'totalLinha': l.totalLinha,
              'embalagemG': l.embalagemG,
              'acao': l.acao.api,
              if (l.produtoId != null) 'produtoId': l.produtoId,
              if (l.consumivelId != null) 'consumivelId': l.consumivelId,
              if (l.embalagemId != null) 'embalagemId': l.embalagemId,
              if (l.marca.isNotEmpty) 'marca': l.marca,
              'produtoNome': l.produtoNome,
            },
        ],
      },
    );
    final m = res as Map;
    return (
      precos: (m['precos'] as num?)?.toInt() ?? 0,
      precosIgnorados: (m['precosIgnorados'] as num?)?.toInt() ?? 0,
      movimentos: (m['movimentos'] as num?)?.toInt() ?? 0,
      pendentes: (m['pendentes'] as num?)?.toInt() ?? 0,
      puladas: (m['puladas'] as num?)?.toInt() ?? 0,
    );
  }

  /// Decisões já gravadas nesta fatura (rondas anteriores de "Aplicar"), por
  /// índice de linha — para reabrir a revisão sem repetir o que já está feito.
  Future<List<ItemFaturaAnterior>> itensAnteriores(String faturaId) async {
    final recs = await _pb
        .collection('faturas_itens')
        .getFullList(filter: 'fatura = "$faturaId"');
    return recs.map(ItemFaturaAnterior.fromRecord).toList();
  }

  /// Corrige a marca e/ou o fornecedor de uma linha JÁ APLICADA (mesmo com a
  /// fatura confirmada) — só o proprietário e o administrador, para o caso de
  /// algo passar despercebido e só se notar depois, olhando de novo para a
  /// fatura em PDF/imagem. Ao contrário de `aplicar`, isto substitui sempre o
  /// valor gravado, mesmo que já não estivesse em branco.
  Future<({String marca, String fornecedor})> corrigirItem(
    String faturaId,
    int index, {
    String? marca,
    String? fornecedor,
  }) async {
    final res = await _pb.send(
      '/api/gc_turnkey/faturas/$faturaId/corrigir-item',
      method: 'POST',
      body: {
        'index': index,
        if (marca != null) 'marca': marca,
        if (fornecedor != null) 'fornecedor': fornecedor,
      },
    );
    final m = res as Map;
    return (
      marca: (m['marca'] ?? '').toString(),
      fornecedor: (m['fornecedor'] ?? '').toString(),
    );
  }

  /// Só o proprietário: a fatura fica escondida (não se perde nada) e pode ser restaurada.
  Future<void> apagar(String id) => _c.update(id, body: {'apagada': true});

  Future<void> restaurar(String id) => _c.update(id, body: {'apagada': false});

  /// Apaga as faturas que não dão para usar: estado `nova` (por analisar),
  /// `erro`, e `analisada` em que a IA não conseguiu devolver nenhuma linha.
  /// Nunca toca nas `confirmada`. Devolve quantas apagou.
  Future<int> limparInvalidas() async {
    final recs = await _c.getFullList(
      filter:
          'empresa = "$_empresaId" && '
          '(estado = "nova" || estado = "erro" || estado = "analisada")',
    );
    var n = 0;
    for (final r in recs) {
      final f = Fatura.fromRecord(r);
      // 'analisada' só se apaga quando a IA não trouxe linhas aproveitáveis.
      if (f.estado == FaturaEstado.analisada && f.linhasIa.isNotEmpty) {
        continue;
      }
      await _c.update(r.id, body: {'apagada': true});
      n++;
    }
    return n;
  }

  /// Faturas confirmadas no intervalo (para o contabilista). Cada item tem
  /// `fornecedor`, `dataFatura`, `numero`, `total`, `iva`, `nomeFicheiro`,
  /// `ficheiroUrl`, `linhas`.
  Future<List<Map<String, dynamic>>> exportContabilidade({
    required String de,
    required String ate,
  }) async {
    final res = await _pb.send(
      '/api/gc_turnkey/faturas/export?de=$de&ate=$ate',
      method: 'GET',
    );
    final list = (res as Map)['faturas'];
    return list is List
        ? list.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];
  }

  /// URL do ficheiro (protegido no servidor: só abre com um [token] de
  /// curta duração — ver [ficheiroUrlSeguro]).
  String ficheiroUrl(Fatura f, {bool thumb = false, String? token}) {
    if (!f.temFicheiro) return '';
    final base = _pb.baseURL.endsWith('/')
        ? _pb.baseURL.substring(0, _pb.baseURL.length - 1)
        : _pb.baseURL;
    final q = [if (thumb) 'thumb=0x240', if (token != null) 'token=$token'];
    return '$base/api/files/faturas/${f.id}/${f.ficheiro}'
        '${q.isEmpty ? '' : '?${q.join('&')}'}';
  }

  /// URL do ficheiro com um token novo (válido cerca de 2 minutos).
  Future<String> ficheiroUrlSeguro(Fatura f, {bool thumb = false}) async {
    if (!f.temFicheiro) return '';
    return ficheiroUrl(f, thumb: thumb, token: await _pb.files.getToken());
  }

  /// Acrescenta um token novo a um URL de ficheiro protegido.
  Future<String> comToken(String url) async {
    if (url.isEmpty) return url;
    final t = await _pb.files.getToken();
    return '$url${url.contains('?') ? '&' : '?'}token=$t';
  }
}
