import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../domain/quadro.dart';

final quadrosRepositoryProvider = Provider<QuadrosRepository>((ref) {
  return QuadrosRepository(ref.watch(pbProvider), requireEmpresaId(ref));
});

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? _data(String v) {
  if (v.length < 10) return null;
  final p = v.substring(0, 10).split('-');
  if (p.length != 3) return null;
  final a = int.tryParse(p[0]), m = int.tryParse(p[1]), d = int.tryParse(p[2]);
  if (a == null || m == null || d == null) return null;
  return DateTime(a, m, d);
}

DateTime _quando(RecordModel r, String campo) =>
    DateTime.tryParse(r.getStringValue(campo))?.toLocal() ?? DateTime.now();

/// Quadros de tarefas da equipa (`quadros`, `quadro_colunas`, `tarefas`,
/// `tarefa_comentarios`).
class QuadrosRepository {
  QuadrosRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  RecordService get _quadros => _pb.collection('quadros');
  RecordService get _colunas => _pb.collection('quadro_colunas');
  RecordService get _tarefas => _pb.collection('tarefas');
  RecordService get _comentarios => _pb.collection('tarefa_comentarios');

  String get utilizadorId => _pb.authStore.record?.id ?? '';

  // ---------------------------------------------------------------- leitura

  static Quadro quadroDe(RecordModel r) => Quadro(
    id: r.id,
    nome: r.getStringValue('nome'),
    ordem: r.getDoubleValue('ordem'),
    arquivado: r.getBoolValue('arquivado'),
    autorId: r.getStringValue('autor'),
  );

  static ColunaQuadro colunaDe(RecordModel r) => ColunaQuadro(
    id: r.id,
    quadroId: r.getStringValue('quadro'),
    nome: r.getStringValue('nome'),
    ordem: r.getDoubleValue('ordem'),
    concluida: r.getBoolValue('concluida'),
  );

  static Tarefa tarefaDe(RecordModel r) => Tarefa(
    id: r.id,
    quadroId: r.getStringValue('quadro'),
    colunaId: r.getStringValue('coluna'),
    titulo: r.getStringValue('titulo'),
    descricao: r.getStringValue('descricao'),
    ordem: r.getDoubleValue('ordem'),
    responsaveis: r.getListValue<String>('responsaveis'),
    prazo: _data(r.getStringValue('prazo')),
    etiquetas: [
      for (final e in r.getListValue<dynamic>('etiquetas'))
        if (e is String && e.trim().isNotEmpty) e.trim(),
    ],
    checklist: ItemChecklist.listaDeJson(r.data['checklist']),
    arquivada: r.getBoolValue('arquivada'),
    autorId: r.getStringValue('autor'),
    autorNome: r.getStringValue('autor_nome'),
    criada: _quando(r, 'created'),
  );

  static ComentarioTarefa comentarioDe(RecordModel r) => ComentarioTarefa(
    id: r.id,
    tarefaId: r.getStringValue('tarefa'),
    texto: r.getStringValue('texto'),
    criado: _quando(r, 'created'),
    autorId: r.getStringValue('autor'),
    autorNome: r.getStringValue('autor_nome'),
    mencoes: r.getListValue<String>('mencoes'),
    lidaPor: r.getListValue<String>('lida_por'),
  );

  Future<List<Quadro>> listarQuadros({bool arquivados = false}) async {
    final recs = await _quadros.getFullList(
      filter:
          'empresa = "$_empresaId" && arquivado = ${arquivados ? 'true' : 'false'}',
      sort: 'ordem,created',
    );
    return recs.map(quadroDe).toList();
  }

  Future<List<ColunaQuadro>> listarColunas(String quadroId) async {
    final recs = await _colunas.getFullList(
      filter: _pb.filter('quadro = {:q}', {'q': quadroId}),
      sort: 'ordem,created',
    );
    return recs.map(colunaDe).toList();
  }

  Future<List<Tarefa>> listarTarefas(
    String quadroId, {
    bool arquivadas = false,
  }) async {
    final recs = await _tarefas.getFullList(
      filter: _pb.filter('quadro = {:q} && arquivada = {:a}', {
        'q': quadroId,
        'a': arquivadas,
      }),
      sort: 'ordem,created',
    );
    return recs.map(tarefaDe).toList();
  }

  /// Os comentários de todas as tarefas abertas do quadro, só com o que o
  /// cartão precisa (contar e saber se há menções por ler).
  Future<List<ComentarioTarefa>> comentariosDoQuadro(String quadroId) async {
    final recs = await _comentarios.getFullList(
      filter: _pb.filter('tarefa.quadro = {:q} && tarefa.arquivada = false', {
        'q': quadroId,
      }),
      fields: 'id,tarefa,autor,mencoes,lida_por,created',
    );
    return recs.map(comentarioDe).toList();
  }

  Future<List<ComentarioTarefa>> listarComentarios(String tarefaId) async {
    final recs = await _comentarios.getFullList(
      filter: _pb.filter('tarefa = {:t}', {'t': tarefaId}),
      sort: 'created',
    );
    return recs.map(comentarioDe).toList();
  }

  /// As minhas tarefas abertas com prazo até hoje (para o Início), de todos os
  /// quadros ativos.
  Future<List<Tarefa>> minhasComPrazoAte(DateTime dia) async {
    final uid = utilizadorId;
    if (uid.isEmpty) return const [];
    final recs = await _tarefas.getFullList(
      filter: _pb.filter(
        'empresa = {:e} && arquivada = false && quadro.arquivado = false'
        ' && coluna.concluida = false && responsaveis ~ {:u}'
        ' && prazo != "" && prazo <= {:d}',
        {'e': _empresaId, 'u': uid, 'd': '${_ymd(dia)} 23:59:59.999Z'},
      ),
      sort: 'prazo',
    );
    return recs.map(tarefaDe).toList();
  }

  /// Comentários que me mencionam e que ainda não vi (para o Início).
  Future<List<ComentarioTarefa>> mencoesPorLer() async {
    final uid = utilizadorId;
    if (uid.isEmpty) return const [];
    final recs = await _comentarios.getFullList(
      filter: _pb.filter(
        'empresa = {:e} && mencoes ~ {:u} && lida_por !~ {:u}'
        ' && tarefa.arquivada = false && tarefa.quadro.arquivado = false',
        {'e': _empresaId, 'u': uid},
      ),
      sort: '-created',
    );
    return recs.map(comentarioDe).toList();
  }

  /// Uma tarefa (para abrir a partir do Início).
  Future<Tarefa> tarefa(String id) async => tarefaDe(await _tarefas.getOne(id));

  // ---------------------------------------------------------------- quadros

  /// Cria o quadro já com as fases "A fazer", "Em curso" e "Feito".
  Future<Quadro> criarQuadro(String nome, {required double ordem}) async {
    final r = await _quadros.create(
      body: {
        'empresa': _empresaId,
        'nome': nome.trim(),
        'ordem': ordem,
        'arquivado': false,
        'autor': utilizadorId,
      },
    );
    for (var i = 0; i < fasesPorOmissao.length; i++) {
      await _colunas.create(
        body: {
          'empresa': _empresaId,
          'quadro': r.id,
          'nome': fasesPorOmissao[i],
          'ordem': (i + 1) * 1000,
          'concluida': i == fasesPorOmissao.length - 1,
        },
      );
    }
    return quadroDe(r);
  }

  Future<void> renomearQuadro(String id, String nome) =>
      _quadros.update(id, body: {'nome': nome.trim()});

  Future<void> arquivarQuadro(String id, {required bool arquivado}) =>
      _quadros.update(id, body: {'arquivado': arquivado});

  Future<void> apagarQuadro(String id) => _quadros.delete(id);

  // ---------------------------------------------------------------- fases

  Future<void> criarColuna(
    String quadroId,
    String nome, {
    required double ordem,
  }) => _colunas.create(
    body: {
      'empresa': _empresaId,
      'quadro': quadroId,
      'nome': nome.trim(),
      'ordem': ordem,
      'concluida': false,
    },
  );

  Future<void> editarColuna(
    String id, {
    String? nome,
    double? ordem,
    bool? concluida,
  }) => _colunas.update(
    id,
    body: {
      if (nome != null) 'nome': nome.trim(),
      if (ordem != null) 'ordem': ordem,
      if (concluida != null) 'concluida': concluida,
    },
  );

  Future<void> apagarColuna(String id) => _colunas.delete(id);

  // ---------------------------------------------------------------- tarefas

  Future<Tarefa> criarTarefa({
    required String quadroId,
    required String colunaId,
    required String titulo,
    required double ordem,
    required String autorNome,
    List<String> responsaveis = const [],
  }) async {
    final r = await _tarefas.create(
      body: {
        'empresa': _empresaId,
        'quadro': quadroId,
        'coluna': colunaId,
        'titulo': titulo.trim(),
        'ordem': ordem,
        'responsaveis': responsaveis,
        'arquivada': false,
        'autor': utilizadorId,
        'autor_nome': autorNome,
      },
    );
    return tarefaDe(r);
  }

  Future<void> mover(
    String id, {
    required String colunaId,
    required double ordem,
  }) => _tarefas.update(id, body: {'coluna': colunaId, 'ordem': ordem});

  /// Grava os campos editáveis de [t] (título, descrição, responsáveis, prazo,
  /// etiquetas, lista de verificação, fase e ordem).
  Future<void> guardar(Tarefa t) => _tarefas.update(
    t.id,
    body: {
      'titulo': t.titulo.trim(),
      'descricao': t.descricao.trim(),
      'coluna': t.colunaId,
      'ordem': t.ordem,
      'responsaveis': t.responsaveis,
      'prazo': t.prazo == null ? '' : '${_ymd(t.prazo!)} 12:00:00.000Z',
      'etiquetas': t.etiquetas,
      'checklist': [for (final i in t.checklist) i.toJson()],
    },
  );

  Future<void> arquivarTarefa(String id, {required bool arquivada}) =>
      _tarefas.update(id, body: {'arquivada': arquivada});

  Future<void> apagarTarefa(String id) => _tarefas.delete(id);

  // ---------------------------------------------------------------- comentários

  Future<void> comentar(
    String tarefaId,
    String texto, {
    required List<String> mencoes,
    required String autorNome,
  }) => _comentarios.create(
    body: {
      'empresa': _empresaId,
      'tarefa': tarefaId,
      'texto': texto.trim(),
      'mencoes': mencoes,
      // quem escreve já "leu" (se se mencionar a si próprio)
      'lida_por': [utilizadorId],
      'autor': utilizadorId,
      'autor_nome': autorNome,
    },
  );

  Future<void> editarComentario(
    String id,
    String texto, {
    required List<String> mencoes,
  }) => _comentarios.update(
    id,
    body: {'texto': texto.trim(), 'mencoes': mencoes},
  );

  Future<void> apagarComentario(String id) => _comentarios.delete(id);

  /// Marca estes comentários como vistos por mim (só os que me mencionam e
  /// ainda estavam por ler).
  Future<void> marcarLidas(Iterable<ComentarioTarefa> comentarios) async {
    final uid = utilizadorId;
    for (final c in comentarios) {
      if (!c.mencaoPorLer(uid)) continue;
      await _comentarios.update(c.id, body: {'lida_por+': uid});
    }
  }

  // ---------------------------------------------------------------- tempo real

  /// Avisa quando alguém mexe no quadro (tarefas, fases ou comentários), para
  /// a equipa ver as mudanças sem atualizar. Devolve a função que desliga.
  Future<Future<void> Function()> ouvirQuadro(
    String quadroId,
    void Function() mudou,
  ) async {
    final desligar = <UnsubscribeFunc>[];
    void handler(RecordSubscriptionEvent e) {
      final r = e.record;
      if (r == null) return;
      final quadro = r.getStringValue('quadro');
      // comentários não trazem o quadro: qualquer um da empresa serve
      if (quadro.isEmpty || quadro == quadroId) mudou();
    }

    for (final c in [_tarefas, _colunas, _comentarios]) {
      try {
        desligar.add(await c.subscribe('*', handler));
      } on Object {
        // sem tempo real (rede/proxy): continua a funcionar ao atualizar
      }
    }
    return () async {
      for (final d in desligar) {
        try {
          await d();
        } on Object {
          // já desligado
        }
      }
    };
  }
}
