import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/errors/mensagem_amigavel.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../quiosque/application/colaboradores_providers.dart';
import '../../quiosque/domain/colaborador.dart';
import '../application/formacoes_providers.dart';
import '../data/formacoes_repository.dart';
import '../domain/formacao.dart';
import '../domain/ponto.dart';
import '../../../app/theme/cores_estado.dart';

String _data(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

Color _cor(EstadoValidade e, ColorScheme cs) => switch (e) {
  EstadoValidade.caducada => cs.error,
  EstadoValidade.aCaducar => cs.aviso,
  EstadoValidade.valida => cs.sucesso,
  EstadoValidade.semValidade => cs.outline,
};

/// Formações e certificados: o que cada pessoa tem, o que caduca e quando.
class FormacoesView extends ConsumerStatefulWidget {
  const FormacoesView({super.key});

  @override
  ConsumerState<FormacoesView> createState() => _FormacoesViewState();
}

class _FormacoesViewState extends ConsumerState<FormacoesView> {
  bool _soAlertas = false;

  Future<void> _abrirFicheiro(Formacao f) async {
    try {
      final url = await ref.read(formacoesRepositoryProvider).urlFicheiro(f);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o ficheiro.')),
        );
      }
    }
  }

  Future<void> _apagar(Formacao f) async {
    final ok = await confirmDialog(
      context,
      titulo: 'Apagar "${f.titulo}"?',
      mensagem:
          'Apaga também o ficheiro guardado. Se só renovaste o certificado, '
          'em vez de apagar regista o novo: o mais recente é o que conta.',
      confirmar: 'Apagar',
      destrutivo: true,
    );
    if (!ok) return;
    try {
      await ref.read(formacoesRepositoryProvider).apagar(f.id);
      ref.invalidate(formacoesProvider);
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(currentPapelProvider).canEditConfig;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hoje = DateTime.now();
    final uid = ref.read(formacoesRepositoryProvider).utilizadorId;
    // a administração renova qualquer uma; cada pessoa só as suas
    bool podeRenovar(Formacao f) =>
        ref.watch(currentPapelProvider).canEditBusiness &&
        (admin || (uid != null && f.userId == uid));
    return AsyncValueView<List<Formacao>>(
      value: ref.watch(formacoesProvider),
      onRetry: () => ref.invalidate(formacoesProvider),
      data: (todas) {
        final alertas = formacoesEmAlerta(todas, hoje);
        final idsAlerta = {for (final f in alertas) f.id};
        final vig = vigentes(todas);
        final idsVigentes = {for (final f in vig) f.id};
        final lista = _soAlertas
            ? [
                for (final f in todas)
                  if (idsAlerta.contains(f.id)) f,
              ]
            : [...todas];
        // o que caduca primeiro; depois, por pessoa
        lista.sort((a, b) {
          final aa = idsAlerta.contains(a.id);
          final bb = idsAlerta.contains(b.id);
          if (aa != bb) return aa ? -1 : 1;
          if (aa) {
            return a.diasParaCaducar(hoje)!.compareTo(b.diasParaCaducar(hoje)!);
          }
          final c = a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
          if (c != 0) return c;
          final da = a.diasParaCaducar(hoje) ?? 100000;
          final db = b.diasParaCaducar(hoje) ?? 100000;
          return da.compareTo(db);
        });
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(formacoesProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  admin
                      ? 'Certificados e formações de cada pessoa, com a validade. '
                            'Avisamos $diasAvisoFormacao dias antes de caducar.'
                      : 'Os teus certificados e formações. Avisamos a administração '
                            'antes de caducarem.',
                  style: tt.bodySmall,
                ),
              ),
              if (alertas.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilterChip(
                    avatar: const Icon(Icons.warning_amber_rounded, size: 18),
                    label: Text('A caducar ou caducados (${alertas.length})'),
                    selected: _soAlertas,
                    onSelected: (v) => setState(() => _soAlertas = v),
                  ),
                ),
              if (lista.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      todas.isEmpty
                          ? 'Ainda não há formações. Regista o certificado de '
                                'manipulador de alimentos, o HACCP, os primeiros '
                                'socorros… com o botão "Nova formação".'
                          : 'Nada a caducar. 👍',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              for (final f in lista)
                Builder(
                  builder: (context) {
                    final estado = f.estado(hoje);
                    // uma versão antiga já renovada fica discreta
                    final substituida = !idsVigentes.contains(f.id);
                    final cor = substituida ? cs.outline : _cor(estado, cs);
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: Icon(switch (f.tipo) {
                          TipoFormacao.formacao => Icons.school_outlined,
                          TipoFormacao.certificado =>
                            Icons.workspace_premium_outlined,
                          TipoFormacao.aptidao =>
                            Icons.health_and_safety_outlined,
                        }, color: cor),
                        title: Text(f.titulo),
                        isThreeLine: idsAlerta.contains(f.id) && podeRenovar(f),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              [
                                if (admin) f.nome,
                                f.tipo.label,
                                if (f.entidade.isNotEmpty) f.entidade,
                                if (f.realizada != null) _data(f.realizada!),
                                if (substituida)
                                  'substituída por uma mais recente',
                              ].join(' · '),
                            ),
                            if (idsAlerta.contains(f.id) && podeRenovar(f))
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(0, 36),
                                  padding: EdgeInsets.zero,
                                ),
                                onPressed: () =>
                                    mostrarFormacao(context, ref, renovar: f),
                                icon: const Icon(Icons.autorenew, size: 18),
                                label: const Text('Renovar'),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  substituida ? '—' : estado.label,
                                  style: TextStyle(
                                    color: cor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (f.validade != null)
                                  Text(
                                    substituida
                                        ? _data(f.validade!)
                                        : f.quando(hoje),
                                    style: tt.bodySmall,
                                  ),
                              ],
                            ),
                            if (f.temFicheiro)
                              IconButton(
                                tooltip: 'Abrir o ficheiro',
                                icon: const Icon(Icons.attach_file),
                                onPressed: () => _abrirFicheiro(f),
                              ),
                          ],
                        ),
                        onTap: () => mostrarFormacao(context, ref, editar: f),
                        onLongPress: () => _apagar(f),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Registar (ou editar) uma formação ou certificado.
Future<void> mostrarFormacao(
  BuildContext context,
  WidgetRef ref, {
  Formacao? editar,
  Formacao? renovar,
}) async {
  final admin = ref.read(currentPapelProvider).canEditConfig;
  final pessoas = admin && editar == null && renovar == null
      ? (await ref.read(
          todosColaboradoresProvider.future,
        )).where((p) => p.ativo).toList()
      : const <Colaborador>[];
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) =>
        _FormacaoDialog(pessoas: pessoas, editar: editar, renovar: renovar),
  );
}

class _FormacaoDialog extends ConsumerStatefulWidget {
  const _FormacaoDialog({required this.pessoas, this.editar, this.renovar});

  final List<Colaborador> pessoas;
  final Formacao? editar;

  /// Renovar um certificado: mesma pessoa e título, datas novas.
  final Formacao? renovar;

  @override
  ConsumerState<_FormacaoDialog> createState() => _FormacaoDialogState();
}

class _FormacaoDialogState extends ConsumerState<_FormacaoDialog> {
  final _titulo = TextEditingController();
  final _entidade = TextEditingController();
  final _notas = TextEditingController();
  Colaborador? _pessoa; // só a administração escolhe, ao criar
  TipoFormacao _tipo = TipoFormacao.certificado;
  DateTime? _realizada;
  DateTime? _validade;
  PlatformFile? _ficheiro;
  bool _ocupado = false;
  String? _erro;

  bool get _admin => ref.read(currentPapelProvider).canEditConfig;

  @override
  void initState() {
    super.initState();
    final f = widget.editar;
    if (f != null) {
      _titulo.text = f.titulo;
      _entidade.text = f.entidade;
      _notas.text = f.notas;
      _tipo = f.tipo;
      _realizada = f.realizada;
      _validade = f.validade;
    } else if (widget.renovar != null) {
      final r = widget.renovar!;
      final hoje = DateTime.now();
      _titulo.text = r.titulo;
      _entidade.text = r.entidade;
      _tipo = r.tipo;
      _realizada = DateTime(hoje.year, hoje.month, hoje.day);
      _validade = validadeRenovada(r, hoje);
    } else {
      _realizada = DateTime.now();
    }
  }

  @override
  void dispose() {
    _titulo.dispose();
    _entidade.dispose();
    _notas.dispose();
    super.dispose();
  }

  Future<void> _escolherData({required bool validade}) async {
    final agora = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: (validade ? _validade : _realizada) ?? agora,
      firstDate: DateTime(2000),
      lastDate: DateTime(agora.year + 15),
    );
    if (d == null) return;
    setState(() => validade ? _validade = d : _realizada = d);
  }

  Future<void> _escolherFicheiro() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final f = r?.files.firstOrNull;
    if (f != null) setState(() => _ficheiro = f);
  }

  Future<void> _guardar() async {
    final titulo = _titulo.text.trim();
    if (titulo.isEmpty) {
      setState(() => _erro = 'Indica o que é (ex.: Manipulador de alimentos).');
      return;
    }
    final f = _ficheiro;
    if (f != null && f.size > 10 * 1024 * 1024) {
      setState(() => _erro = 'O ficheiro é grande demais (máximo 10 MB).');
      return;
    }
    final base = _validade;
    if (base != null && _realizada != null && base.isBefore(_realizada!)) {
      setState(
        () => _erro = 'A validade não pode ser antes da data da formação.',
      );
      return;
    }
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    final repo = ref.read(formacoesRepositoryProvider);
    try {
      final antigo = widget.editar;
      if (antigo != null) {
        await repo.editar(
          antigo.id,
          titulo: titulo,
          tipo: _tipo,
          realizada: _realizada,
          validade: _validade,
          entidade: _entidade.text,
          notas: _notas.text,
          bytes: f?.bytes,
          nomeFicheiro: f?.name ?? '',
        );
      } else {
        final String pessoa;
        final String nome;
        final String userId;
        if (widget.renovar != null) {
          pessoa = widget.renovar!.pessoa;
          nome = widget.renovar!.nome;
          userId = widget.renovar!.userId;
        } else if (_admin && _pessoa != null) {
          pessoa = chavePessoa(_pessoa!);
          nome = _pessoa!.nome;
          userId = _pessoa!.userId;
        } else {
          final uid = repo.utilizadorId ?? '';
          pessoa = 'u:$uid';
          nome = ref.read(currentUserNameProvider) ?? '';
          userId = uid;
        }
        await repo.criar(
          pessoa: pessoa,
          nome: nome,
          userId: userId,
          titulo: titulo,
          tipo: _tipo,
          realizada: _realizada,
          validade: _validade,
          entidade: _entidade.text,
          notas: _notas.text,
          bytes: f?.bytes,
          nomeFicheiro: f?.name ?? '',
        );
      }
      ref.invalidate(formacoesProvider);
      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _ocupado = false;
          _erro = mensagemAmigavel(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editar = widget.editar;
    final tt = Theme.of(context).textTheme;
    final base = _realizada ?? DateTime.now();
    return AlertDialog(
      title: Text(
        widget.renovar != null
            ? 'Renovar: ${widget.renovar!.titulo}'
            : editar == null
            ? 'Nova formação'
            : 'Editar formação',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.renovar != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '${widget.renovar!.nome}: já vem tudo preenchido; só falta '
                  'anexar o certificado novo e guardar.',
                  style: tt.bodySmall,
                ),
              ),
            if (_admin && editar == null && widget.renovar == null) ...[
              DropdownButtonFormField<Colaborador>(
                initialValue: _pessoa,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Pessoa',
                  helperText: 'Vazio = eu',
                ),
                items: [
                  for (final p in widget.pessoas)
                    DropdownMenuItem(value: p, child: Text(p.nome)),
                ],
                onChanged: (v) => setState(() => _pessoa = v),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _titulo,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'O que é'),
              onChanged: (_) => setState(() {}),
            ),
            if (_titulo.text.trim().isEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 0,
                children: [
                  for (final s in titulosSugeridos)
                    ActionChip(
                      label: Text(s),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() {
                        _titulo.text = s;
                        if (s == 'Ficha de aptidão médica') {
                          _tipo = TipoFormacao.aptidao;
                        }
                      }),
                    ),
                ],
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<TipoFormacao>(
              initialValue: _tipo,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: [
                for (final t in TipoFormacao.values)
                  DropdownMenuItem(value: t, child: Text(t.label)),
              ],
              onChanged: (v) => setState(() => _tipo = v ?? _tipo),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _escolherData(validade: false),
              icon: const Icon(Icons.event_available_outlined),
              label: Text(
                _realizada == null
                    ? 'Data em que foi feita'
                    : 'Feita em ${_data(_realizada!)}',
              ),
            ),
            const SizedBox(height: 12),
            Text('Validade', style: tt.labelLarge),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 0,
              children: [
                ChoiceChip(
                  label: const Text('Não caduca'),
                  selected: _validade == null,
                  onSelected: (_) => setState(() => _validade = null),
                ),
                for (final a in const [1, 2, 3, 5])
                  ChoiceChip(
                    label: Text('+$a ${a == 1 ? 'ano' : 'anos'}'),
                    selected:
                        _validade != null && _validade == somarAnos(base, a),
                    onSelected: (_) =>
                        setState(() => _validade = somarAnos(base, a)),
                  ),
              ],
            ),
            TextButton.icon(
              onPressed: () => _escolherData(validade: true),
              icon: const Icon(Icons.edit_calendar_outlined),
              label: Text(
                _validade == null
                    ? 'Escolher outra data'
                    : 'Válida até ${_data(_validade!)}',
              ),
            ),
            TextField(
              controller: _entidade,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Entidade (opcional)',
                helperText: 'Quem deu a formação ou emitiu o certificado',
              ),
            ),
            TextField(
              controller: _notas,
              maxLength: 300,
              decoration: const InputDecoration(labelText: 'Notas (opcional)'),
            ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: _escolherFicheiro,
              icon: const Icon(Icons.attach_file),
              label: Text(
                _ficheiro != null
                    ? _ficheiro!.name
                    : (editar?.temFicheiro ?? false)
                    ? 'Trocar o ficheiro guardado'
                    : 'Anexar o certificado (PDF ou foto)',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_erro != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _erro!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (editar != null)
          TextButton(
            onPressed: _ocupado
                ? null
                : () async {
                    final ok = await confirmDialog(
                      context,
                      titulo: 'Apagar "${editar.titulo}"?',
                      mensagem: 'Apaga também o ficheiro guardado.',
                      confirmar: 'Apagar',
                      destrutivo: true,
                    );
                    if (!ok || !context.mounted) return;
                    final nav = Navigator.of(context);
                    try {
                      await ref
                          .read(formacoesRepositoryProvider)
                          .apagar(editar.id);
                      ref.invalidate(formacoesProvider);
                      nav.pop();
                    } on Object catch (e) {
                      if (mounted) setState(() => _erro = mensagemAmigavel(e));
                    }
                  },
            child: const Text('Apagar'),
          ),
        TextButton(
          onPressed: _ocupado ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _ocupado ? null : _guardar,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
