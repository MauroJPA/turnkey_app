import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/env/app_version.dart';
import '../../../core/help/help_content.dart';
import '../../../core/storage/prefs_locais.dart';
import '../../../core/widgets/help_actions.dart';
import '../../daily_count/presentation/forno_widgets.dart';
import '../../navigation/application/navigation_providers.dart';
import '../../navigation/presentation/mais_sheet.dart';
import '../../settings/application/empresa_providers.dart';
import '../../settings/data/empresa_repository.dart';
import '../../settings/domain/empresa.dart';
import '../domain/atalhos_inicio.dart';
import '../domain/tarefa_hoje.dart';
import 'tarefas_hoje_provider.dart';

/// Ecrã inicial: o que precisa de ti hoje, com o botão que o resolve ali
/// mesmo, e três atalhos para o que mais usas. O resto vive no rodapé e no
/// "Mais" (que também pesquisa).
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  late String? _atalhos = lerPref(chaveAtalhosInicio);

  Future<void> _escolherAtalhos(bool Function(String) acessivel) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => _EscolherAtalhos(
        inicial: [
          for (final a in atalhosEscolhidos(_atalhos, acessivel)) a.chave,
        ],
        acessivel: acessivel,
        aoMudar: (chaves) {
          final v = chaves.join(',');
          guardarPref(chaveAtalhosInicio, v);
          setState(() => _atalhos = v);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final empresa = ref.watch(currentEmpresaProvider).valueOrNull;
    final userName = ref.watch(currentUserNameProvider);
    final papel = ref.watch(currentPapelProvider);
    final navConfig = ref.watch(navConfigAtualProvider);
    bool acessivel(String chave) => navConfig.acessivel(papel, chave);

    final logoUrl = empresa == null
        ? ''
        : ref.read(empresaRepositoryProvider).logoUrl(empresa);

    final tarefas = separarTarefas(ref.watch(tarefasHojeProvider));
    final atalhos = atalhosEscolhidos(_atalhos, acessivel);
    final agora = DateTime.now();
    final nome = primeiroNome(userName);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: marcaAppBar(context, empresa, logoUrl),
        actions: [
          IconButton(
            key: const ValueKey('pesquisar'),
            tooltip: 'Procurar',
            icon: const Icon(Icons.search),
            onPressed: () => showMaisSheet(context, procurar: true),
          ),
          IconButton(
            tooltip: 'Configurações',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go(Routes.settings),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'sair') {
                ref.read(authControllerProvider.notifier).signOut();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Text('${userName ?? ''} · ${papel.label}'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'sair',
                child: Text('Terminar sessão'),
              ),
              const PopupMenuDivider(),
              // versão da app, discreta (útil para saber se o telemóvel já atualizou)
              PopupMenuItem(
                enabled: false,
                height: 32,
                child: Text(
                  'gc_turnkey · $versaoAppTexto',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const HelpActions(topic: HelpTopic.dashboard),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        children: [
          _Cabecalho(
            titulo: nome.isEmpty
                ? saudacao(agora)
                : '${saudacao(agora)}, $nome',
            subtitulo: dataPorExtenso(agora),
            aEscolher: () => _escolherAtalhos(acessivel),
          ),
          if (atalhos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              // todos da mesma altura, mesmo que um nome ocupe duas linhas
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < atalhos.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: _AtalhoBotao(atalho: atalhos[i])),
                    ],
                  ],
                ),
              ),
            ),
          // o que está no forno (some sozinho quando está vazio)
          if (acessivel('contagem')) const ResumoFornoCard(),
          const SizedBox(height: 8),
          _TituloSecao(
            tarefas.precisa.isEmpty
                ? 'Precisa de ti'
                : 'Precisa de ti · ${tarefas.precisa.length}',
          ),
          if (tarefas.precisa.isEmpty)
            const _TudoEmDia()
          else
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < tarefas.precisa.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _LinhaTarefa(
                      key: ValueKey('tarefa-${tarefas.precisa[i].chave}'),
                      tarefa: tarefas.precisa[i],
                    ),
                  ],
                ],
              ),
            ),
          if (tarefas.saber.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                key: const ValueKey('para-saber'),
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text(
                  'Para saber · ${tarefas.saber.length}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                children: [
                  for (final t in tarefas.saber) ...[
                    const Divider(height: 1),
                    _LinhaTarefa(key: ValueKey('tarefa-${t.chave}'), tarefa: t),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({
    required this.titulo,
    required this.subtitulo,
    required this.aEscolher,
  });

  final String titulo;
  final String subtitulo;
  final VoidCallback aEscolher;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 0, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(subtitulo, style: tt.bodySmall),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('escolher-atalhos'),
            tooltip: 'Escolher os 3 atalhos',
            icon: const Icon(Icons.tune),
            onPressed: aEscolher,
          ),
        ],
      ),
    );
  }
}

class _TituloSecao extends StatelessWidget {
  const _TituloSecao(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 0, 6),
    child: Text(texto, style: Theme.of(context).textTheme.titleSmall),
  );
}

class _AtalhoBotao extends StatelessWidget {
  const _AtalhoBotao({required this.atalho});
  final AtalhoInicio atalho;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: cs.primaryContainer,
      child: InkWell(
        key: ValueKey('atalho-${atalho.chave}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go(atalho.rota),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(atalho.icon, size: 28, color: cs.onPrimaryContainer),
              const SizedBox(height: 6),
              Text(
                atalho.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: cs.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TudoEmDia extends StatelessWidget {
  const _TudoEmDia();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: cs.primary, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Tudo em dia. Nada precisa de ti agora.'),
            ),
          ],
        ),
      ),
    );
  }
}

Color _corUrgencia(Urgencia u, ColorScheme cs) => switch (u) {
  Urgencia.urgente => cs.error,
  Urgencia.atencao => const Color(0xFFE08A00),
  Urgencia.info => cs.outline,
};

/// Uma tarefa: título, o que há, e o botão que a resolve (um só item) ou a
/// lista de itens com um botão cada (vários). Sem botões, abre a página.
class _LinhaTarefa extends ConsumerStatefulWidget {
  const _LinhaTarefa({super.key, required this.tarefa});
  final TarefaHoje tarefa;

  @override
  ConsumerState<_LinhaTarefa> createState() => _LinhaTarefaState();
}

class _LinhaTarefaState extends ConsumerState<_LinhaTarefa> {
  bool _aberta = false;
  bool _ocupada = false;

  Future<void> _correr(ItemTarefa item) async {
    if (_ocupada || item.acao == null) return;
    setState(() => _ocupada = true);
    try {
      await item.acao!(context, ref);
    } finally {
      if (mounted) setState(() => _ocupada = false);
    }
  }

  ButtonStyle get _estiloBotao => FilledButton.styleFrom(
    minimumSize: const Size(0, 36),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    visualDensity: VisualDensity.compact,
  );

  @override
  Widget build(BuildContext context) {
    final t = widget.tarefa;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final cor = _corUrgencia(t.urgencia, cs);
    final direta = t.acaoDireta;

    return Column(
      children: [
        InkWell(
          onTap: () {
            if (t.expansivel) {
              setState(() => _aberta = !_aberta);
            } else {
              context.go(t.rota);
            }
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Icon(t.icon, size: 22, color: cs.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              t.titulo,
                              style: tt.titleSmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (t.total > 1) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: cor.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${t.total}',
                                style: tt.labelSmall?.copyWith(
                                  color: cor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (t.subtitulo.isNotEmpty && !_aberta)
                        Text(
                          t.subtitulo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodySmall,
                        ),
                    ],
                  ),
                ),
                if (direta != null) ...[
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    key: ValueKey('acao-${t.chave}'),
                    style: _estiloBotao,
                    onPressed: _ocupada ? null : () => _correr(direta),
                    child: Text(direta.rotuloAcao!),
                  ),
                ] else
                  Icon(
                    t.expansivel
                        ? (_aberta ? Icons.expand_less : Icons.expand_more)
                        : Icons.chevron_right,
                    color: cs.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
        if (_aberta)
          Padding(
            padding: const EdgeInsets.fromLTRB(42, 0, 12, 8),
            child: Column(
              children: [
                for (final item in t.itens)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(child: Text(item.texto, style: tt.bodyMedium)),
                        if (item.temAcao) ...[
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            style: _estiloBotao,
                            onPressed: _ocupada ? null : () => _correr(item),
                            child: Text(item.rotuloAcao!),
                          ),
                        ],
                      ],
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => context.go(t.rota),
                    child: const Text('Abrir página'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Folha para escolher (e ordenar pela ordem de escolha) até 3 atalhos.
class _EscolherAtalhos extends StatefulWidget {
  const _EscolherAtalhos({
    required this.inicial,
    required this.acessivel,
    required this.aoMudar,
  });

  final List<String> inicial;
  final bool Function(String pagina) acessivel;
  final void Function(List<String> chaves) aoMudar;

  @override
  State<_EscolherAtalhos> createState() => _EscolherAtalhosState();
}

class _EscolherAtalhosState extends State<_EscolherAtalhos> {
  late final List<String> _escolhidos = [...widget.inicial];

  void _alternar(String chave, bool ligado) {
    setState(() {
      if (ligado) {
        if (_escolhidos.length < atalhosMaximo) _escolhidos.add(chave);
      } else {
        _escolhidos.remove(chave);
      }
    });
    widget.aoMudar(_escolhidos);
  }

  @override
  Widget build(BuildContext context) {
    final cheio = _escolhidos.length >= atalhosMaximo;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(
              'Os teus 3 atalhos',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Escolhe o que mais usas. Fica guardado só neste aparelho.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final a in atalhosInicio)
                  if (widget.acessivel(a.pagina))
                    CheckboxListTile(
                      key: ValueKey('escolher-${a.chave}'),
                      secondary: Icon(a.icon),
                      title: Text(a.label),
                      value: _escolhidos.contains(a.chave),
                      onChanged: (!_escolhidos.contains(a.chave) && cheio)
                          ? null
                          : (v) => _alternar(a.chave, v ?? false),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Logótipo e/ou nome da marca na barra superior, com a posição, tamanho e
/// visibilidade escolhidos em Configurações → Aparência. Público para a
/// pré-visualização em tempo real no ecrã de Configurações usar exatamente
/// o mesmo desenho da barra real.
Widget marcaAppBar(BuildContext context, Empresa? empresa, String logoUrl) {
  final mostrarLogo = (empresa?.logoVisivel ?? true) && logoUrl.isNotEmpty;
  final mostrarNome = empresa?.nomeVisivel ?? true;
  final tamanhoLogo = empresa?.logoTamanho ?? 28;

  final logo = !mostrarLogo
      ? null
      : ClipRRect(
          borderRadius: BorderRadius.circular(6),
          // Logótipos não são todos quadrados (ex.: uma marca larga tipo
          // wordmark) — em vez de forçar um quadrado e cortar as pontas
          // (BoxFit.cover), mede-se pela altura e mantém-se a proporção
          // (BoxFit.contain), com um teto de largura para não estourar a
          // barra com um logótipo muito largo.
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: tamanhoLogo * 4),
            child: SizedBox(
              height: tamanhoLogo,
              child: Image.network(
                logoUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        );
  final texto = !mostrarNome
      ? null
      : Text(
          empresa?.nome ?? 'gc_turnkey',
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: empresa?.nomeTamanho ?? 18,
          ),
        );
  if (logo == null && texto == null) return const SizedBox.shrink();

  final logoAlinh = empresa?.logoAlinhamento ?? Alinhamento.esquerda;
  final nomeAlinh = empresa?.nomeAlinhamento ?? Alinhamento.esquerda;

  // Mesma posição (ou só um dos dois visível) — ficam juntos numa linha.
  if (logo == null || texto == null || logoAlinh == nomeAlinh) {
    final conteudo = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (logo != null) logo,
        if (logo != null && texto != null) const SizedBox(width: 8),
        if (texto != null) Flexible(child: texto),
      ],
    );
    return SizedBox(
      width: double.infinity,
      child: Align(
        alignment: _alignFor(logo != null ? logoAlinh : nomeAlinh),
        child: conteudo,
      ),
    );
  }

  // Posições diferentes — cada um fica na sua zona da barra.
  return SizedBox(
    width: double.infinity,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Align(alignment: _alignFor(logoAlinh), child: logo),
        Align(alignment: _alignFor(nomeAlinh), child: texto),
      ],
    ),
  );
}

Alignment _alignFor(Alinhamento a) => switch (a) {
  Alinhamento.esquerda => Alignment.centerLeft,
  Alinhamento.centro => Alignment.center,
  Alinhamento.direita => Alignment.centerRight,
};
