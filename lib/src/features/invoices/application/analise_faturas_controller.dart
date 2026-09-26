import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/invoice_repository.dart';
import '../domain/fatura.dart';
import '../domain/invoice_erros.dart';
import 'invoice_providers.dart';

/// Em que ponto está o trabalho de envio + análise de um ficheiro.
enum FaseAnalise { aEnviar, aPreparar, aLer, aSeparar, feita, erro }

/// Um ficheiro de faturas a ser enviado e analisado (pode ter dezenas de páginas).
class TrabalhoAnalise {
  const TrabalhoAnalise({
    required this.chave,
    required this.titulo,
    required this.fase,
    this.faturaId,
    this.paginas = 0,
    this.feitas = 0,
    this.mensagem = '',
    this.totalFaturas = 0,
    this.duplicadas = 0,
    this.tamanhoBytes = 0,
  });

  /// Id local até o ficheiro estar no servidor; depois, o id da fatura.
  final String chave;
  final String titulo;
  final FaseAnalise fase;
  final String? faturaId;
  final int paginas;
  final int feitas;
  final String mensagem;
  final int totalFaturas;
  final int duplicadas;
  final int tamanhoBytes;

  bool get ativo => fase != FaseAnalise.feita && fase != FaseAnalise.erro;

  double? get progresso =>
      fase == FaseAnalise.aLer && paginas > 0 ? feitas / paginas : null;

  TrabalhoAnalise copyWith({
    String? chave,
    FaseAnalise? fase,
    String? faturaId,
    int? paginas,
    int? feitas,
    String? mensagem,
    int? totalFaturas,
    int? duplicadas,
  }) => TrabalhoAnalise(
    chave: chave ?? this.chave,
    titulo: titulo,
    fase: fase ?? this.fase,
    faturaId: faturaId ?? this.faturaId,
    paginas: paginas ?? this.paginas,
    feitas: feitas ?? this.feitas,
    mensagem: mensagem ?? this.mensagem,
    totalFaturas: totalFaturas ?? this.totalFaturas,
    duplicadas: duplicadas ?? this.duplicadas,
    tamanhoBytes: tamanhoBytes,
  );

  /// Texto curto do que está a acontecer (para a barra de progresso).
  String get texto {
    switch (fase) {
      case FaseAnalise.aEnviar:
        final mb = tamanhoBytes > 0
            ? ' (${(tamanhoBytes / 1048576).toStringAsFixed(1).replaceAll('.', ',')} MB)'
            : '';
        return 'A enviar o ficheiro$mb… Ficheiros grandes demoram um pouco.';
      case FaseAnalise.aPreparar:
        return 'A preparar o ficheiro…';
      case FaseAnalise.aLer:
        return paginas > 0
            ? 'A IA está a ler as páginas: $feitas de $paginas…'
            : 'A IA está a ler o ficheiro…';
      case FaseAnalise.aSeparar:
        return 'A separar as faturas…';
      case FaseAnalise.feita:
        return totalFaturas > 1
            ? 'Pronto: $totalFaturas faturas'
                  '${duplicadas > 0 ? ' ($duplicadas já existia/m)' : ''}.'
            : 'Pronto: fatura analisada.';
      case FaseAnalise.erro:
        return mensagem;
    }
  }
}

final analiseFaturasProvider =
    NotifierProvider<AnaliseFaturasController, Map<String, TrabalhoAnalise>>(
      AnaliseFaturasController.new,
    );

/// Corre o envio e a análise dos ficheiros de faturas **em segundo plano**
/// (continua se a pessoa mudar de ecrã, enquanto a app estiver aberta) e guarda o
/// progresso para o mostrar. O servidor guarda o que já foi lido: se falhar ou a app
/// fechar, "Continuar" retoma de onde ficou.
class AnaliseFaturasController extends Notifier<Map<String, TrabalhoAnalise>> {
  @override
  Map<String, TrabalhoAnalise> build() => const {};

  InvoiceRepository get _repo => ref.read(invoiceRepositoryProvider);

  bool get haTrabalhoAtivo => state.values.any((t) => t.ativo);

  bool estaAAnalisar(String faturaId) => state[faturaId]?.ativo ?? false;

  void _set(TrabalhoAnalise t) => state = {...state, t.chave: t};

  void fechar(String chave) {
    final novo = {...state}..remove(chave);
    state = novo;
  }

  /// Envia o ficheiro e analisa-o. Devolve logo (o trabalho corre em segundo plano).
  void iniciar({
    required FaturaTipo tipo,
    required String fornecedor,
    required List<int> bytes,
    required String nome,
  }) {
    final chave = 'novo-${DateTime.now().microsecondsSinceEpoch}';
    _set(
      TrabalhoAnalise(
        chave: chave,
        titulo: nome,
        fase: FaseAnalise.aEnviar,
        tamanhoBytes: bytes.length,
      ),
    );
    unawaited(_enviarECorrer(chave, tipo, fornecedor, bytes, nome));
  }

  /// Continua (ou repete) a análise de uma fatura já carregada.
  void retomar(String faturaId, {String titulo = ''}) {
    if (estaAAnalisar(faturaId)) return;
    _set(
      TrabalhoAnalise(
        chave: faturaId,
        titulo: titulo.isEmpty ? 'Fatura' : titulo,
        faturaId: faturaId,
        fase: FaseAnalise.aPreparar,
      ),
    );
    unawaited(_correr(faturaId, titulo));
  }

  Future<void> _enviarECorrer(
    String chave,
    FaturaTipo tipo,
    String fornecedor,
    List<int> bytes,
    String nome,
  ) async {
    late final Fatura f;
    try {
      f = await _repo.criar(
        tipo: tipo,
        fornecedor: fornecedor,
        bytes: bytes,
        nome: nome,
      );
    } on Object catch (e) {
      final t = state[chave];
      if (t != null) {
        _set(t.copyWith(fase: FaseAnalise.erro, mensagem: mensagemAmigavel(e)));
      }
      return;
    }
    ref.invalidate(faturasListProvider);
    fechar(chave);
    _set(
      TrabalhoAnalise(
        chave: f.id,
        titulo: nome,
        faturaId: f.id,
        fase: FaseAnalise.aPreparar,
        tamanhoBytes: bytes.length,
      ),
    );
    await _correr(f.id, nome, bytes: bytes, fornecedor: fornecedor);
  }

  Future<void> _correr(
    String id,
    String titulo, {
    List<int>? bytes,
    String fornecedor = '',
  }) async {
    TrabalhoAnalise atual() =>
        state[id] ??
        TrabalhoAnalise(
          chave: id,
          titulo: titulo,
          faturaId: id,
          fase: FaseAnalise.aPreparar,
        );
    try {
      _set(atual().copyWith(fase: FaseAnalise.aPreparar));
      final prep = await _repo.preparar(id);
      _set(
        atual().copyWith(
          fase: FaseAnalise.aLer,
          paginas: prep.paginas,
          feitas: (prep.proxima - 1).clamp(0, prep.paginas),
        ),
      );
      var feito = prep.proxima > prep.paginas;
      var guarda = 0;
      while (!feito && guarda++ < 5000) {
        final r = await _repo.analisarParte(id);
        feito = r.feito;
        _set(
          atual().copyWith(
            fase: FaseAnalise.aLer,
            paginas: r.paginas,
            feitas: (r.proxima - 1).clamp(0, r.paginas),
          ),
        );
      }
      _set(atual().copyWith(fase: FaseAnalise.aSeparar));
      final res = await _repo.concluirAnalise(id);

      // Fatura única e ficheiro pequeno: renomeia para FT-FORNECEDOR-DDMMAAAA.
      if (res.ids.length == 1 &&
          bytes != null &&
          bytes.length <= 10 * 1048576 &&
          res.fatura.estado != FaturaEstado.erro &&
          res.fatura.dataFatura.isNotEmpty) {
        final data = DateTime.tryParse(res.fatura.dataFatura);
        if (data != null) {
          try {
            await _repo.renomearFicheiro(
              id,
              bytes: bytes,
              nomeOriginal: titulo,
              fornecedor: res.fatura.fornecedor.isNotEmpty
                  ? res.fatura.fornecedor
                  : fornecedor,
              dataFatura: data,
            );
          } on Object {
            // fica com o nome provisório
          }
        }
      }
      ref.invalidate(faturasListProvider);
      ref.invalidate(faturaProvider(id));
      _set(
        atual().copyWith(
          fase: FaseAnalise.feita,
          totalFaturas: res.ids.length,
          duplicadas: res.duplicadas,
          paginas: atual().paginas,
        ),
      );
    } on Object catch (e) {
      ref.invalidate(faturasListProvider);
      ref.invalidate(faturaProvider(id));
      _set(
        atual().copyWith(fase: FaseAnalise.erro, mensagem: mensagemAmigavel(e)),
      );
    }
  }
}
