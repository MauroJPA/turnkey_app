import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/help_actions.dart';
import '../../dashboard/presentation/home_shell.dart' show marcaAppBar;
import '../../pricing/data/cost_config_repository.dart';
import '../../pricing/domain/cost_config.dart';
import '../application/empresa_providers.dart';
import '../application/settings_providers.dart';
import '../data/empresa_repository.dart';
import '../domain/empresa.dart';
import 'integracoes_sheet.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nome = TextEditingController();
  final _cor = TextEditingController();
  final _corSec = TextEditingController();
  final _corFundo = TextEditingController();
  final _corTexto = TextEditingController();
  final _custos = <String, TextEditingController>{
    for (final k in _rubricas.keys) k: TextEditingController(),
  };
  final _ivaVendas = TextEditingController();
  Moeda _moeda = Moeda.eur;
  RegraArredondamento _regra = RegraArredondamento.cima;
  TemaApp _tema = TemaApp.sistema;
  bool _logoVisivel = true;
  Alinhamento _logoAlinhamento = Alinhamento.esquerda;
  double _logoTamanho = 28;
  bool _nomeVisivel = true;
  Alinhamento _nomeAlinhamento = Alinhamento.esquerda;
  double _nomeTamanho = 18;
  String _fonteFamilia = '';
  bool _prefilled = false;
  bool _busy = false;

  static const _rubricas = {
    'salario': 'Salário',
    'aluguel': 'Aluguel',
    'impostos': 'Impostos',
    'servicos': 'Serviços e gastos intangíveis',
    'despesasFixas': 'Despesas fixas',
    'taxasFinanceiras': 'Taxas financeiras',
    'margemLucro': 'Margem de lucro',
  };

  bool get _podeEditar => ref.read(currentPapelProvider).canEditConfig;

  @override
  void dispose() {
    _nome.dispose();
    _cor.dispose();
    _corSec.dispose();
    _corFundo.dispose();
    _corTexto.dispose();
    for (final c in _custos.values) {
      c.dispose();
    }
    _ivaVendas.dispose();
    super.dispose();
  }

  void _prefill(Empresa e, CostConfig c) {
    if (_prefilled) return;
    _prefilled = true;
    _nome.text = e.nome;
    _cor.text = e.corMarca;
    _corSec.text = e.corSecundaria;
    _corFundo.text = e.corFundo;
    _corTexto.text = e.corTexto;
    _moeda = e.moeda;
    _regra = e.regraArredondamento;
    _tema = e.tema;
    _logoVisivel = e.logoVisivel;
    _logoAlinhamento = e.logoAlinhamento;
    _logoTamanho = e.logoTamanho;
    _nomeVisivel = e.nomeVisivel;
    _nomeAlinhamento = e.nomeAlinhamento;
    _nomeTamanho = e.nomeTamanho;
    _fonteFamilia = e.fonteFamilia;
    _custos['salario']!.text = _n(c.salario);
    _custos['aluguel']!.text = _n(c.aluguel);
    _custos['impostos']!.text = _n(c.impostos);
    _custos['servicos']!.text = _n(c.servicos);
    _custos['despesasFixas']!.text = _n(c.despesasFixas);
    _custos['taxasFinanceiras']!.text = _n(c.taxasFinanceiras);
    _custos['margemLucro']!.text = _n(c.margemLucro);
    _ivaVendas.text = c.ivaVendas > 0 ? _n(c.ivaVendas) : '';
  }

  static String _n(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  static String _familiaFromNomeFicheiro(String nome) {
    final semExtensao = nome.contains('.')
        ? nome.substring(0, nome.lastIndexOf('.'))
        : nome;
    return semExtensao.replaceAll(RegExp(r'[^A-Za-z0-9]+'), ' ').trim();
  }

  double _v(String k) =>
      double.tryParse(_custos[k]!.text.replaceAll(',', '.').trim()) ?? 0;

  CostConfig get _configFromForm => CostConfig(
    salario: _v('salario'),
    aluguel: _v('aluguel'),
    impostos: _v('impostos'),
    servicos: _v('servicos'),
    despesasFixas: _v('despesasFixas'),
    taxasFinanceiras: _v('taxasFinanceiras'),
    margemLucro: _v('margemLucro'),
    ivaVendas:
        double.tryParse(_ivaVendas.text.replaceAll(',', '.').trim()) ?? 0,
  );

  Future<void> _run(String ok, Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok)));
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final empresaAsync = ref.watch(currentEmpresaProvider);
    final configAsync = ref.watch(costConfigProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
        title: const Text('Configurações'),
        actions: const [HelpActions(topic: HelpTopic.configuracoes)],
      ),
      body: (empresaAsync.isLoading || configAsync.isLoading)
          ? const Center(child: CircularProgressIndicator())
          : (empresaAsync.hasError || configAsync.hasError)
          ? Center(child: Text('${empresaAsync.error ?? configAsync.error}'))
          : _form(empresaAsync.value!, configAsync.value!),
    );
  }

  Widget _form(Empresa empresa, CostConfig config) {
    _prefill(empresa, config);
    final cmv = _configFromForm.cmvPercent;

    return AbsorbPointer(
      absorbing: !_podeEditar,
      child: Opacity(
        opacity: _podeEditar ? 1 : 0.6,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (!_podeEditar)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Só administradores podem alterar estas definições.',
                ),
              ),

            // ---- Empresa ----
            Text('Empresa', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _nome,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<Moeda>(
                    initialValue: _moeda,
                    decoration: const InputDecoration(labelText: 'Moeda'),
                    items: [
                      for (final m in Moeda.values)
                        DropdownMenuItem(
                          value: m,
                          child: Text('${m.code} (${m.symbol})'),
                        ),
                    ],
                    onChanged: (v) => setState(() => _moeda = v ?? Moeda.eur),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<RegraArredondamento>(
                    initialValue: _regra,
                    decoration: const InputDecoration(
                      labelText: 'Arredondamento',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: RegraArredondamento.cima,
                        child: Text('Para cima'),
                      ),
                      DropdownMenuItem(
                        value: RegraArredondamento.normal,
                        child: Text('Normal'),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _regra = v ?? RegraArredondamento.cima),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run('Empresa guardada.', () async {
                        await ref
                            .read(settingsActionsProvider)
                            .saveEmpresa(
                              nome: _nome.text,
                              moeda: _moeda,
                              regra: _regra,
                              corMarca: _cor.text,
                              tema: _tema,
                            );
                      }),
                child: const Text('Guardar empresa'),
              ),
            ),

            const Divider(height: 40),

            // ---- Aparência ----
            Text('Aparência', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Aplica-se a toda a equipa desta empresa.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _AparenciaControls(
              empresaBase: empresa,
              tema: _tema,
              corHex: _cor.text,
              corController: _cor,
              corSecController: _corSec,
              corFundoController: _corFundo,
              corTextoController: _corTexto,
              logoUrl: ref.read(empresaRepositoryProvider).logoUrl(empresa),
              logoVisivel: _logoVisivel,
              logoAlinhamento: _logoAlinhamento,
              logoTamanho: _logoTamanho,
              nomeVisivel: _nomeVisivel,
              nomeAlinhamento: _nomeAlinhamento,
              nomeTamanho: _nomeTamanho,
              fonteFamilia: _fonteFamilia,
              temFontePersonalizada: empresa.temFontePersonalizada,
              onTema: (t) => setState(() => _tema = t),
              onCor: (hex) => setState(() => _cor.text = hex),
              onLogoVisivel: (v) => setState(() => _logoVisivel = v),
              onLogoAlinhamento: (a) => setState(() => _logoAlinhamento = a),
              onLogoTamanho: (v) => setState(() => _logoTamanho = v),
              onNomeVisivel: (v) => setState(() => _nomeVisivel = v),
              onNomeAlinhamento: (a) => setState(() => _nomeAlinhamento = a),
              onNomeTamanho: (v) => setState(() => _nomeTamanho = v),
              onGuardar: _busy
                  ? null
                  : () => _run('Aparência guardada.', () async {
                      await ref
                          .read(settingsActionsProvider)
                          .saveAparencia(
                            corMarca: _cor.text,
                            tema: _tema,
                            corSecundaria: _corSec.text,
                            corFundo: _corFundo.text,
                            corTexto: _corTexto.text,
                            logoVisivel: _logoVisivel,
                            logoAlinhamento: _logoAlinhamento,
                            logoTamanho: _logoTamanho,
                            nomeVisivel: _nomeVisivel,
                            nomeAlinhamento: _nomeAlinhamento,
                            nomeTamanho: _nomeTamanho,
                            fonteFamilia: _fonteFamilia,
                          );
                    }),
              onEscolherLogo: _busy
                  ? null
                  : () => _run('Logótipo atualizado.', () async {
                      final picked = await FilePicker.platform.pickFiles(
                        type: FileType.image,
                        withData: true,
                      );
                      final f = picked?.files.single;
                      if (f?.bytes == null) return;
                      await ref
                          .read(settingsActionsProvider)
                          .definirLogo(nome: f!.name, bytes: f.bytes!.toList());
                    }),
              onRemoverLogo: _busy || !empresa.temLogo
                  ? null
                  : () => _run('Logótipo removido.', () async {
                      await ref.read(settingsActionsProvider).removerLogo();
                    }),
              onEscolherFonte: _busy
                  ? null
                  : () => _run('Tipo de letra atualizado.', () async {
                      final picked = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: const ['ttf', 'otf'],
                        withData: true,
                      );
                      final f = picked?.files.single;
                      if (f?.bytes == null) return;
                      await ref
                          .read(settingsActionsProvider)
                          .definirFonte(
                            nome: f!.name,
                            bytes: f.bytes!.toList(),
                          );
                      if (mounted) {
                        setState(
                          () =>
                              _fonteFamilia = _familiaFromNomeFicheiro(f.name),
                        );
                      }
                    }),
              onRemoverFonte: _busy || !empresa.temFontePersonalizada
                  ? null
                  : () => _run('Tipo de letra removido.', () async {
                      await ref.read(settingsActionsProvider).removerFonte();
                      if (mounted) setState(() => _fonteFamilia = '');
                    }),
            ),

            const Divider(height: 40),

            // ---- Custos ----
            Text(
              'Percentuais de custo',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              cmv <= 0
                  ? 'Somam ≥ 100% — o preço sugerido fica a 0.'
                  : 'Sobra ${cmv.toStringAsFixed(1)}% para a matéria-prima (CMV).',
              style: TextStyle(
                color: cmv <= 0
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            for (final e in _rubricas.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: TextField(
                  controller: _custos[e.key],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: e.value,
                    suffixText: '%',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            const Divider(height: 28),
            TextField(
              controller: _ivaVendas,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'IVA das vendas',
                suffixText: '%',
                helperText:
                    'Não entra nos percentuais acima. Serve para estimar o IVA '
                    'a entregar quando uma venda não traz o valor sem IVA '
                    '(Painel financeiro → IVA a separar).',
                helperMaxLines: 3,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run('Percentuais guardados.', () async {
                        await ref
                            .read(settingsActionsProvider)
                            .saveCustos(_configFromForm);
                      }),
                child: const Text('Guardar percentuais'),
              ),
            ),

            const Divider(height: 40),

            // ---- Formatos de cookie ----
            if (ref.read(currentPapelProvider).canEditConfig)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cookie_outlined),
                title: const Text('Formatos de cookie'),
                subtitle: const Text('Tamanhos, massa e recheio por unidade'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go(Routes.cookieFormats),
              ),

            // ---- Categorias de receitas ----
            if (ref.read(currentPapelProvider).canEditConfig)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.label_outline),
                title: const Text('Categorias de receitas'),
                subtitle: const Text(
                  'Massa, recheio, cobertura — geríveis por ti',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go(Routes.categoriasReceita),
              ),

            // ---- Navegação e permissões ----
            if (ref.read(currentPapelProvider).canEditConfig)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.view_carousel_outlined),
                title: const Text('Navegação e permissões'),
                subtitle: const Text('Rodapé e o que cada nível pode fazer'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go(Routes.navegacao),
              ),

            // ---- Integrações ----
            if (ref.read(currentPapelProvider).canEditConfig)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link_outlined),
                title: const Text('Integrações'),
                subtitle: const Text('Token do Vendus (guardado cifrado)'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showIntegracoesSheet(context),
              ),

            // ---- Equipa ----
            if (ref.read(currentPapelProvider).canManageTeam)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.group_outlined),
                title: const Text('Equipa'),
                subtitle: const Text('Utilizadores e permissões'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go(Routes.team),
              ),
          ],
        ),
      ),
    );
  }
}

/// Controlos de Aparência: modo de tema, distribuição de cores, logótipo,
/// nome da marca (posição/tamanho/visibilidade) e tipo de letra.
class _AparenciaControls extends StatelessWidget {
  const _AparenciaControls({
    required this.empresaBase,
    required this.tema,
    required this.corHex,
    required this.corController,
    required this.corSecController,
    required this.corFundoController,
    required this.corTextoController,
    required this.logoUrl,
    required this.logoVisivel,
    required this.logoAlinhamento,
    required this.logoTamanho,
    required this.nomeVisivel,
    required this.nomeAlinhamento,
    required this.nomeTamanho,
    required this.fonteFamilia,
    required this.temFontePersonalizada,
    required this.onTema,
    required this.onCor,
    required this.onLogoVisivel,
    required this.onLogoAlinhamento,
    required this.onLogoTamanho,
    required this.onNomeVisivel,
    required this.onNomeAlinhamento,
    required this.onNomeTamanho,
    required this.onGuardar,
    required this.onEscolherLogo,
    required this.onRemoverLogo,
    required this.onEscolherFonte,
    required this.onRemoverFonte,
  });

  final Empresa empresaBase;
  final TemaApp tema;
  final String corHex;
  final TextEditingController corController;
  final TextEditingController corSecController;
  final TextEditingController corFundoController;
  final TextEditingController corTextoController;
  final String logoUrl;
  final bool logoVisivel;
  final Alinhamento logoAlinhamento;
  final double logoTamanho;
  final bool nomeVisivel;
  final Alinhamento nomeAlinhamento;
  final double nomeTamanho;
  final String fonteFamilia;
  final bool temFontePersonalizada;
  final ValueChanged<TemaApp> onTema;
  final ValueChanged<String> onCor;
  final ValueChanged<bool> onLogoVisivel;
  final ValueChanged<Alinhamento> onLogoAlinhamento;
  final ValueChanged<double> onLogoTamanho;
  final ValueChanged<bool> onNomeVisivel;
  final ValueChanged<Alinhamento> onNomeAlinhamento;
  final ValueChanged<double> onNomeTamanho;
  final VoidCallback? onGuardar;
  final VoidCallback? onEscolherLogo;
  final VoidCallback? onRemoverLogo;
  final VoidCallback? onEscolherFonte;
  final VoidCallback? onRemoverFonte;

  static const _alinhamentos = [
    ButtonSegment(
      value: Alinhamento.esquerda,
      icon: Icon(Icons.format_align_left),
    ),
    ButtonSegment(
      value: Alinhamento.centro,
      icon: Icon(Icons.format_align_center),
    ),
    ButtonSegment(
      value: Alinhamento.direita,
      icon: Icon(Icons.format_align_right),
    ),
  ];

  /// A mesma [Empresa] gravada, mas com o que está a ser ajustado agora
  /// (ainda por guardar) — para a pré-visualização mostrar exatamente a
  /// barra superior real, em tempo real.
  Empresa get _previewEmpresa => empresaBase.copyWith(
    logoOculto: !logoVisivel,
    logoAlinhamento: logoAlinhamento,
    logoTamanho: logoTamanho,
    nomeOculto: !nomeVisivel,
    nomeAlinhamento: nomeAlinhamento,
    nomeTamanho: nomeTamanho,
  );

  @override
  Widget build(BuildContext context) {
    final corAtual = AppTheme.parseHex(corHex);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Pré-visualização', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: AppBar(
            automaticallyImplyLeading: false,
            titleSpacing: 12,
            title: marcaAppBar(context, _previewEmpresa, logoUrl),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Atualiza-se ao vivo — a barra real só muda depois de guardares.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Text('Modo', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        SegmentedButton<TemaApp>(
          segments: const [
            ButtonSegment(value: TemaApp.claro, label: Text('Claro')),
            ButtonSegment(value: TemaApp.sistema, label: Text('Automático')),
            ButtonSegment(value: TemaApp.escuro, label: Text('Escuro')),
          ],
          selected: {tema},
          onSelectionChanged: (s) => onTema(s.first),
        ),
        const SizedBox(height: 16),
        Text('Cor de destaque', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final p in AppTheme.presets)
              _Amostra(
                cor: p.cor,
                nome: p.nome,
                ativa:
                    corAtual != null &&
                    (corAtual.toARGB32() & 0xFFFFFF) ==
                        (p.cor.toARGB32() & 0xFFFFFF),
                onTap: () => onCor(AppTheme.toHex(p.cor)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Avançado — distribuição de cores'),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            children: [
              TextField(
                controller: corController,
                decoration: const InputDecoration(
                  labelText: 'Cor de destaque (hex, ex. #8D5B34)',
                ),
                onChanged: onCor,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: corSecController,
                decoration: const InputDecoration(
                  labelText: 'Cor secundária (hex)',
                  helperText:
                      'Vazio = derivada automaticamente da cor de destaque',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: corFundoController,
                decoration: const InputDecoration(
                  labelText: 'Cor de fundo (hex)',
                  helperText: 'Vazio = fundo automático (cinza suave/escuro)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: corTextoController,
                decoration: const InputDecoration(
                  labelText: 'Cor das letras e títulos (hex)',
                  helperText: 'Vazio = cor automática com bom contraste',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Logótipo', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: logoUrl.isEmpty
                  ? const Icon(Icons.storefront_outlined)
                  : Image.network(
                      logoUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onEscolherLogo,
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Escolher imagem'),
                  ),
                  if (onRemoverLogo != null)
                    TextButton(
                      onPressed: onRemoverLogo,
                      child: const Text('Remover'),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Mostrar logótipo na barra superior'),
          value: logoVisivel,
          onChanged: onLogoVisivel,
        ),
        if (logoVisivel) ...[
          const SizedBox(height: 4),
          Text('Posição', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          SegmentedButton<Alinhamento>(
            segments: _alinhamentos,
            selected: {logoAlinhamento},
            onSelectionChanged: (s) => onLogoAlinhamento(s.first),
          ),
          const SizedBox(height: 10),
          Text(
            'Tamanho: ${logoTamanho.round()} px',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Slider(
            value: logoTamanho,
            min: 16,
            max: 56,
            divisions: 20,
            onChanged: onLogoTamanho,
          ),
        ],
        const SizedBox(height: 12),
        Text('Nome da marca', style: Theme.of(context).textTheme.labelLarge),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Mostrar nome na barra superior'),
          value: nomeVisivel,
          onChanged: onNomeVisivel,
        ),
        if (nomeVisivel) ...[
          const SizedBox(height: 4),
          Text('Posição', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          SegmentedButton<Alinhamento>(
            segments: _alinhamentos,
            selected: {nomeAlinhamento},
            onSelectionChanged: (s) => onNomeAlinhamento(s.first),
          ),
          const SizedBox(height: 10),
          Text(
            'Tamanho: ${nomeTamanho.round()} px',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Slider(
            value: nomeTamanho,
            min: 14,
            max: 28,
            divisions: 14,
            onChanged: onNomeTamanho,
          ),
        ],
        const SizedBox(height: 12),
        Text('Tipo de letra', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Text(
          temFontePersonalizada && fonteFamilia.isNotEmpty
              ? 'Personalizado: $fonteFamilia'
              : 'A usar a fonte do sistema (padrão).',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: onEscolherFonte,
              icon: const Icon(Icons.font_download_outlined),
              label: const Text('Adicionar tipo de letra (.ttf/.otf)'),
            ),
            if (onRemoverFonte != null)
              TextButton(
                onPressed: onRemoverFonte,
                child: const Text('Usar a do sistema'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: onGuardar,
            child: const Text('Guardar aparência'),
          ),
        ),
      ],
    );
  }
}

class _Amostra extends StatelessWidget {
  const _Amostra({
    required this.cor,
    required this.nome,
    required this.ativa,
    required this.onTap,
  });

  final Color cor;
  final String nome;
  final bool ativa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(40),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cor,
              shape: BoxShape.circle,
              border: Border.all(
                color: ativa
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.transparent,
                width: 3,
              ),
            ),
            child: ativa
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : null,
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 64,
            child: Text(
              nome,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}
