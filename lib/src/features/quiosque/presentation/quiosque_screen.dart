import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/device/nfc_leitor.dart';
import '../../daily_count/presentation/forno_widgets.dart';
import '../../haccp/domain/haccp.dart';
import '../../haccp/presentation/haccp_icones.dart';
import '../../invoices/domain/invoice_erros.dart';
import '../../people/application/escala_providers.dart';
import '../../people/domain/escala.dart';
import '../../people/domain/ponto.dart';
import '../application/fila_offline_service.dart';
import '../domain/colaborador.dart';
import '../domain/fila_offline.dart';

/// Segundos sem tocar em nada até o quiosque voltar a pedir o cartão.
const segundosDeInatividade = 45;

/// Quiosque de tarefas diárias: o telemóvel fica sempre com isto aberto.
/// Cada pessoa encosta o seu cartão NFC (ou escolhe o nome) e vê só os botões
/// das tarefas — um toque regista (limpeza, temperaturas, pragas, lote…).
class QuiosqueScreen extends ConsumerStatefulWidget {
  const QuiosqueScreen({super.key});

  @override
  ConsumerState<QuiosqueScreen> createState() => _QuiosqueScreenState();
}

class _QuiosqueScreenState extends ConsumerState<QuiosqueScreen> {
  Colaborador? _quem;
  Timer? _inatividade;
  Timer? _reenvio;
  bool _nfcLigado = false;
  String? _avisoNfc;
  String? _avisoCartao;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    if (NfcLeitor.suporta) _ligarNfc();
    _reenvio = Timer.periodic(
      const Duration(seconds: segundosEntreReenvios),
      (_) => _reenviar(),
    );
  }

  @override
  void dispose() {
    _inatividade?.cancel();
    _reenvio?.cancel();
    NfcLeitor.parar();
    super.dispose();
  }

  void _ligarNfc() {
    NfcLeitor.iniciar(
      aoLer: _aoLerCartao,
      aoErro: (m) {
        if (!mounted) return;
        setState(() {
          _nfcLigado = false;
          _avisoNfc = m;
        });
      },
    );
    // o leitor só confirma depois; marca como ligado e o erro (se houver)
    // desfaz isto
    setState(() {
      _nfcLigado = true;
      _avisoNfc = null;
    });
  }

  void _aoLerCartao(String serie) {
    if (!mounted) return;
    final todos = ref.read(pessoasQuiosqueProvider).valueOrNull ?? const [];
    final c = colaboradorDoCartao(serie, todos);
    if (c == null) {
      setState(() => _avisoCartao = 'Cartão não reconhecido.');
      Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _avisoCartao = null);
      });
      return;
    }
    _identificar(c);
  }

  void _identificar(Colaborador c) {
    ref.invalidate(estadoPontoQuiosqueProvider);
    setState(() {
      _quem = c;
      _avisoCartao = null;
    });
    _reiniciarInatividade();
  }

  void _terminar() {
    _inatividade?.cancel();
    setState(() => _quem = null);
  }

  void _reiniciarInatividade() {
    _inatividade?.cancel();
    _inatividade = Timer(const Duration(seconds: segundosDeInatividade), () {
      if (mounted) setState(() => _quem = null);
    });
  }

  void _msg(String t, {bool erro = false}) {
    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: erro ? cs.error : null,
          content: Text(t, style: const TextStyle(fontSize: 18)),
        ),
      );
  }

  Future<void> _registar(
    ControloHaccp c, {
    double? valor,
    bool conforme = true,
    String notas = '',
    String acao = '',
  }) async {
    final quem = _quem;
    if (quem == null || _ocupado) return;
    setState(() => _ocupado = true);
    try {
      final enviado = await ref
          .read(filaOfflineProvider.notifier)
          .registar(
            controloId: c.id,
            dataHora: DateTime.now(),
            valor: valor,
            conforme: conforme,
            responsavel: quem.nome,
            notas: notas,
            acaoCorretiva: acao,
          );
      if (enviado) {
        _msg(
          conforme
              ? '✓ ${c.nome} — registado, ${quem.nome}'
              : '⚠ ${c.nome} — registado como problema',
          erro: !conforme,
        );
      } else {
        _msg(
          '✓ ${c.nome} — guardado neste aparelho (sem ligação). '
          'Segue quando a ligação voltar.',
        );
      }
    } on Object catch (e) {
      _msg(mensagemAmigavel(e), erro: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
      _reiniciarInatividade();
    }
  }

  Future<void> _marcarPonto(TipoPonto tipo) async {
    final quem = _quem;
    if (quem == null || _ocupado) return;
    setState(() => _ocupado = true);
    final agora = DateTime.now();
    try {
      final enviado = await ref
          .read(filaOfflineProvider.notifier)
          .registarPonto(
            pessoa: chavePessoa(quem),
            nome: quem.nome,
            userId: quem.userId,
            tipo: tipo,
            dataHora: agora,
          );
      final hh = agora.hour.toString().padLeft(2, '0');
      final mm = agora.minute.toString().padLeft(2, '0');
      _msg(
        enviado
            ? '✓ ${tipo.label} às $hh:$mm — ${quem.nome}'
            : '✓ ${tipo.label} às $hh:$mm guardada neste aparelho (sem ligação). '
                  'Segue quando a ligação voltar.',
      );
    } on Object catch (e) {
      _msg(mensagemAmigavel(e), erro: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
      _reiniciarInatividade();
    }
  }

  /// De tempos a tempos: envia o que ficou guardado e, se a lista de tarefas
  /// veio da memória, tenta buscar a verdadeira.
  Future<void> _reenviar({bool aPedido = false}) async {
    if (!mounted) return;
    final fila = ref.read(filaOfflineProvider);
    if (fila.pendentes.isNotEmpty) {
      final n = await ref.read(filaOfflineProvider.notifier).sincronizar();
      if (!mounted) return;
      if (n > 0) {
        _msg('✓ $n registo(s) enviado(s).');
      } else if (aPedido) {
        _msg('Ainda sem ligação ao servidor.', erro: true);
      }
      final rej = ref.read(filaOfflineProvider).rejeitados;
      if (rej > fila.rejeitados) {
        _msg(
          '$rej registo(s) não foram aceites pelo servidor. Avisa quem gere a app.',
          erro: true,
        );
      }
    }
    final doServidor = ref.read(estadosQuiosqueProvider).valueOrNull;
    if (doServidor == null || doServidor.daCache) {
      ref.invalidate(estadosQuiosqueProvider);
      ref.invalidate(pessoasQuiosqueProvider);
    }
  }

  Future<void> _tocar(ControloHaccp c) async {
    if (_quem == null || _ocupado) return;
    _reiniciarInatividade();
    switch (c.tipo) {
      case TipoControlo.limpeza || TipoControlo.manutencao:
        await _registar(c);
      case TipoControlo.temperatura:
        final v = await showDialog<double>(
          context: context,
          builder: (_) => _TecladoTemperatura(controlo: c),
        );
        if (v == null) return;
        final ok = c.valorConforme(v);
        String acao = '';
        if (!ok) {
          if (!mounted) return;
          final a = await showDialog<String>(
            context: context,
            builder: (_) => _ForaDosLimites(controlo: c, valor: v),
          );
          if (a == null) return;
          acao = a;
        }
        await _registar(c, valor: v, conforme: ok, acao: acao);
      case TipoControlo.praga:
        final r = await showDialog<_RespostaPraga>(
          context: context,
          builder: (_) => _PerguntaPraga(controlo: c),
        );
        if (r == null) return;
        await _registar(
          c,
          conforme: r.semProblema,
          notas: r.nota,
          acao: r.semProblema ? '' : 'Avisar o responsável e verificar.',
        );
      case TipoControlo.outro:
        final t = await showDialog<String>(
          context: context,
          builder: (_) => _PedeTexto(controlo: c),
        );
        if (t == null) return;
        await _registar(c, notas: t);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Listener(
          // qualquer toque conta como atividade
          onPointerDown: (_) {
            if (_quem != null) _reiniciarInatividade();
          },
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Tarefas do dia', style: tt.titleLarge),
                    ),
                    _ChipPorEnviar(onTap: () => _reenviar(aPedido: true)),
                    if (NfcLeitor.suporta)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Chip(
                          visualDensity: VisualDensity.compact,
                          avatar: Icon(
                            Icons.nfc,
                            size: 16,
                            color: _nfcLigado ? cs.primary : cs.outline,
                          ),
                          label: Text(
                            _nfcLigado ? 'NFC ligado' : 'NFC desligado',
                          ),
                        ),
                      ),
                    // sair do quiosque: toque longo (para ninguém sair sem querer)
                    GestureDetector(
                      onLongPress: () => context.go(Routes.home),
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Tooltip(
                          message: 'Sair do quiosque: mantém premido',
                          child: Icon(Icons.lock_outline),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _quem == null ? _espera(context) : _tarefas(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- à espera de alguém ------------------------------------------------------

  Widget _espera(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final colaboradores =
        ref.watch(pessoasQuiosqueProvider).valueOrNull ?? const <Colaborador>[];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: [
        const ResumoFornoCard(),
        Icon(Icons.nfc, size: 96, color: _nfcLigado ? cs.primary : cs.outline),
        const SizedBox(height: 8),
        Text(
          NfcLeitor.suporta && _nfcLigado
              ? 'Encosta o teu cartão'
              : 'Quem és tu?',
          textAlign: TextAlign.center,
          style: tt.headlineSmall,
        ),
        if (_avisoCartao != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _avisoCartao!,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.error, fontSize: 18),
            ),
          ),
        if (NfcLeitor.suporta && !_nfcLigado)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: FilledButton.icon(
              onPressed: _ligarNfc,
              icon: const Icon(Icons.nfc),
              label: const Text('Ligar o leitor de cartões'),
            ),
          ),
        if (_avisoNfc != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _avisoNfc!,
              textAlign: TextAlign.center,
              style: tt.bodySmall,
            ),
          ),
        if (!NfcLeitor.suporta)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Este aparelho não lê cartões: escolhe o teu nome.',
              textAlign: TextAlign.center,
              style: tt.bodySmall,
            ),
          ),
        const SizedBox(height: 24),
        if (colaboradores.isEmpty)
          Text(
            'Ainda não há ninguém na Equipa. Quem gere a app cria as '
            'contas em Definições → Equipa.',
            textAlign: TextAlign.center,
            style: tt.bodyMedium,
          )
        else ...[
          Text(
            'Sem cartão? Toca no teu nome',
            textAlign: TextAlign.center,
            style: tt.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in colaboradores)
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(120, 56),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  onPressed: () => _identificar(c),
                  child: Text(c.nome),
                ),
            ],
          ),
        ],
      ],
    );
  }

  // --- tarefas ----------------------------------------------------------------

  Widget _tarefas(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final estados = ref.watch(estadosQuiosqueProvider);
    final pendentes = ref.watch(filaOfflineProvider).pendentes;
    final base = estados.valueOrNull;
    final lista = base == null
        ? null
        : comPendentes(base.lista, pendentes, DateTime.now());
    return Column(
      children: [
        if (base != null && base.daCache)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.tertiaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Sem ligação ao servidor — a mostrar a última lista. O que '
              'registares fica guardado neste aparelho e segue quando a '
              'ligação voltar.',
              style: tt.bodyMedium,
            ),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: ResumoFornoCard(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Olá, ${_quem!.nome}',
                  style: tt.headlineSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: _terminar,
                icon: const Icon(Icons.logout),
                label: const Text('Terminar'),
              ),
            ],
          ),
        ),
        _CartaoPonto(
          pessoa: chavePessoa(_quem!),
          ocupado: _ocupado,
          onMarcar: _marcarPonto,
        ),
        Expanded(
          child: lista == null
              ? (estados.hasError
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Sem ligação ao servidor e ainda não há uma '
                                'lista guardada neste aparelho.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: () =>
                                    ref.invalidate(estadosQuiosqueProvider),
                                child: const Text('Tentar de novo'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : const Center(child: CircularProgressIndicator()))
              : lista.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Ainda não há tarefas. Quem gere a app cria-as em HACCP '
                      '→ Controlos.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : GridView.count(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.05,
                  children: [
                    for (final s in lista)
                      _Tarefa(
                        status: s,
                        cs: cs,
                        ocupado: _ocupado,
                        onTap: () => _tocar(s.controlo),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Quantos segundos entre tentativas de enviar o que ficou guardado.
const segundosEntreReenvios = 20;

/// "N por enviar" / "Sem ligação": aparece quando há registos à espera de
/// ligação (ou a última tentativa falhou); tocar tenta enviar já.
class _ChipPorEnviar extends ConsumerWidget {
  const _ChipPorEnviar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fila = ref.watch(filaOfflineProvider);
    if (fila.pendentes.isEmpty && !fila.semLigacao) {
      return const SizedBox.shrink();
    }
    final cs = Theme.of(context).colorScheme;
    final n = fila.pendentes.length;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: ActionChip(
        visualDensity: VisualDensity.compact,
        backgroundColor: n > 0 ? cs.tertiaryContainer : cs.errorContainer,
        avatar: Icon(
          fila.aEnviar ? Icons.sync : Icons.cloud_off_outlined,
          size: 16,
        ),
        label: Text(n > 0 ? '$n por enviar' : 'Sem ligação'),
        onPressed: fila.aEnviar ? null : onTap,
      ),
    );
  }
}

/// O ponto de quem está no quiosque: o que marcou por último e os botões do
/// que pode marcar a seguir (entrada, pausa, saída).
class _CartaoPonto extends ConsumerWidget {
  const _CartaoPonto({
    required this.pessoa,
    required this.ocupado,
    required this.onMarcar,
  });

  final String pessoa;
  final bool ocupado;
  final void Function(TipoPonto) onMarcar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final estado =
        ref.watch(estadoPontoQuiosqueProvider).valueOrNull ?? const {};
    var ultimo = estado[pessoa];
    // uma marcação com mais de 16 horas é de outro dia (saída esquecida)
    if (ultimo != null &&
        DateTime.now().difference(ultimo.dataHora) > jornadaMaxima) {
      ultimo = null;
    }
    final opcoes = proximosPontos(ultimo?.tipo);
    String hora(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final texto = ultimo == null
        ? 'Ponto: ainda sem entrada'
        : '${ultimo.tipo.label} às ${hora(ultimo.dataHora)}';
    // o horário de hoje (da escala), se há
    final hojeD = DateTime.now();
    final dia0 = DateTime(hojeD.year, hojeD.month, hojeD.day);
    final modeloEscala = ref.watch(escalaModeloProvider).valueOrNull;
    final excecoesHoje = ref
        .watch(
          escalaExcecoesProvider((
            de: dia0,
            ate: dia0.add(const Duration(days: 1)),
          )),
        )
        .valueOrNull;
    final regrasEscala = ref.watch(escalaRegrasProvider).valueOrNull;
    final turnoHoje = modeloEscala == null || excecoesHoje == null
        ? null
        : diaDaEscala(
            pessoa: pessoa,
            dia: dia0,
            modelo: modeloEscala,
            excecoes: excecoesHoje,
            regras: regrasEscala ?? const [],
          );
    final horarioHoje = turnoHoje != null && turnoHoje.estado == EstadoDia.turno
        ? 'Hoje: ${turnoHoje.texto}'
        : null;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time),
              const SizedBox(width: 8),
              Expanded(child: Text(texto, style: tt.titleSmall)),
              if (horarioHoje != null) Text(horarioHoje, style: tt.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < opcoes.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      textStyle: const TextStyle(fontSize: 17),
                    ),
                    onPressed: ocupado ? null : () => onMarcar(opcoes[i]),
                    child: Text(opcoes[i].label),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Um botão grande de uma tarefa.
class _Tarefa extends StatelessWidget {
  const _Tarefa({
    required this.status,
    required this.cs,
    required this.ocupado,
    required this.onTap,
  });

  final StatusControlo status;
  final ColorScheme cs;
  final bool ocupado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = status.controlo;
    final (fundo, texto) = switch (status.estado) {
      EstadoControlo.atrasado ||
      EstadoControlo.semRegisto => (cs.errorContainer, 'Em atraso'),
      EstadoControlo.pendenteHoje => (
        cs.tertiaryContainer,
        c.esperadosPorDia > 1
            ? 'Hoje: ${status.feitosHoje} de ${status.esperadosHoje}'
            : 'Fazer hoje',
      ),
      EstadoControlo.emDia => (
        cs.primaryContainer,
        status.fechadoHoje ? 'Dia de folga' : 'Feito ✓',
      ),
      EstadoControlo.ocasional => (
        cs.surfaceContainerHighest,
        'Quando for preciso',
      ),
    };
    return Material(
      color: fundo,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: ocupado ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(iconeDoControlo(c.tipo), size: 44),
              const SizedBox(height: 8),
              Text(
                c.nome,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(texto, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// diálogos grandes
// ---------------------------------------------------------------------------

/// Teclado numérico grande para a temperatura.
class _TecladoTemperatura extends StatefulWidget {
  const _TecladoTemperatura({required this.controlo});
  final ControloHaccp controlo;

  @override
  State<_TecladoTemperatura> createState() => _TecladoTemperaturaState();
}

class _TecladoTemperaturaState extends State<_TecladoTemperatura> {
  String _txt = '';

  double? get _valor => double.tryParse(_txt.replaceAll(',', '.'));

  void _tecla(String t) {
    setState(() {
      switch (t) {
        case '⌫':
          if (_txt.isNotEmpty) _txt = _txt.substring(0, _txt.length - 1);
        case '−':
          _txt = _txt.startsWith('-') ? _txt.substring(1) : '-$_txt';
        case ',':
          if (!_txt.contains(',') && _txt.length < 6) {
            _txt = _txt.isEmpty || _txt == '-' ? '${_txt}0,' : '$_txt,';
          }
        default:
          if (_txt.length < 6) _txt += t;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controlo;
    final tt = Theme.of(context).textTheme;
    Widget tecla(String t) => SizedBox(
      width: 76,
      height: 60,
      child: FilledButton.tonal(
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(76, 60),
          textStyle: const TextStyle(fontSize: 24),
        ),
        onPressed: () => _tecla(t),
        child: Text(t),
      ),
    );
    return AlertDialog(
      title: Text(c.nome, style: tt.titleMedium),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_txt.isEmpty ? '— °C' : '$_txt °C', style: tt.displaySmall),
          if (c.limitesTexto.isNotEmpty)
            Text('Limites: ${c.limitesTexto}', style: tt.bodySmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final t in [
                '1',
                '2',
                '3',
                '4',
                '5',
                '6',
                '7',
                '8',
                '9',
                '−',
                '0',
                ',',
              ])
                tecla(t),
              tecla('⌫'),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(140, 52)),
          onPressed: _valor == null
              ? null
              : () => Navigator.pop(context, _valor),
          child: const Text('Registar'),
        ),
      ],
    );
  }
}

/// Temperatura fora dos limites: o que foi feito (rápido).
class _ForaDosLimites extends StatefulWidget {
  const _ForaDosLimites({required this.controlo, required this.valor});
  final ControloHaccp controlo;
  final double valor;

  @override
  State<_ForaDosLimites> createState() => _ForaDosLimitesState();
}

class _ForaDosLimitesState extends State<_ForaDosLimites> {
  static const _opcoes = [
    'Porta mal fechada — fechei e vou medir de novo',
    'Avisei o responsável',
    'Produtos verificados',
  ];
  final _outra = TextEditingController();
  String _escolha = _opcoes.first;

  @override
  void dispose() {
    _outra.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(
        'Fora dos limites: ${widget.valor.toString().replaceAll('.', ',')} °C',
        style: TextStyle(color: cs.error),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('O que fizeste?'),
            for (final o in [..._opcoes, ''])
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  _escolha == o
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: _escolha == o ? cs.primary : null,
                ),
                title: Text(o.isEmpty ? 'Outra coisa…' : o),
                onTap: () => setState(() => _escolha = o),
              ),
            if (_escolha.isEmpty)
              TextField(
                controller: _outra,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'O que fizeste'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final a = _escolha.isEmpty ? _outra.text.trim() : _escolha;
            if (a.isEmpty) return;
            Navigator.pop(context, a);
          },
          child: const Text('Registar'),
        ),
      ],
    );
  }
}

class _RespostaPraga {
  const _RespostaPraga({required this.semProblema, this.nota = ''});
  final bool semProblema;
  final String nota;
}

/// Controlo de pragas: tudo bem, ou vi sinais.
class _PerguntaPraga extends StatefulWidget {
  const _PerguntaPraga({required this.controlo});
  final ControloHaccp controlo;

  @override
  State<_PerguntaPraga> createState() => _PerguntaPragaState();
}

class _PerguntaPragaState extends State<_PerguntaPraga> {
  bool _problema = false;
  final _nota = TextEditingController();

  @override
  void dispose() {
    _nota.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.controlo.nome),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_problema) ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(64),
              ),
              onPressed: () => Navigator.pop(
                context,
                const _RespostaPraga(semProblema: true),
              ),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Tudo bem', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(64),
                backgroundColor: cs.errorContainer,
              ),
              onPressed: () => setState(() => _problema = true),
              icon: const Icon(Icons.pest_control),
              label: const Text(
                'Vi sinais de pragas',
                style: TextStyle(fontSize: 20),
              ),
            ),
          ] else ...[
            TextField(
              controller: _nota,
              autofocus: true,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'O que viste e onde?',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: () => Navigator.pop(
                context,
                _RespostaPraga(semProblema: false, nota: _nota.text.trim()),
              ),
              child: const Text('Registar o problema'),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

/// Texto curto (ex.: o número do lote).
class _PedeTexto extends StatefulWidget {
  const _PedeTexto({required this.controlo});
  final ControloHaccp controlo;

  @override
  State<_PedeTexto> createState() => _PedeTextoState();
}

class _PedeTextoState extends State<_PedeTexto> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controlo;
    return AlertDialog(
      title: Text(c.nome),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(fontSize: 22),
            decoration: InputDecoration(
              labelText: 'Lote / nota',
              helperText: c.instrucoes.isEmpty ? null : c.instrucoes,
              helperMaxLines: 3,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(140, 52)),
          onPressed: () {
            final t = _ctrl.text.trim();
            if (t.isNotEmpty) Navigator.pop(context, t);
          },
          child: const Text('Registar'),
        ),
      ],
    );
  }
}
