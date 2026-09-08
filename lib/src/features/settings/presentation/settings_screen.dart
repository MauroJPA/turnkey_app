import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/help_actions.dart';
import '../../pricing/data/cost_config_repository.dart';
import '../../pricing/domain/cost_config.dart';
import '../application/empresa_providers.dart';
import '../application/settings_providers.dart';
import '../data/empresa_repository.dart';
import '../domain/empresa.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nome = TextEditingController();
  final _cor = TextEditingController();
  final _custos = <String, TextEditingController>{
    for (final k in _rubricas.keys) k: TextEditingController(),
  };
  Moeda _moeda = Moeda.eur;
  RegraArredondamento _regra = RegraArredondamento.cima;
  TemaApp _tema = TemaApp.sistema;
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
    for (final c in _custos.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _prefill(Empresa e, CostConfig c) {
    if (_prefilled) return;
    _prefilled = true;
    _nome.text = e.nome;
    _cor.text = e.corMarca;
    _moeda = e.moeda;
    _regra = e.regraArredondamento;
    _tema = e.tema;
    _custos['salario']!.text = _n(c.salario);
    _custos['aluguel']!.text = _n(c.aluguel);
    _custos['impostos']!.text = _n(c.impostos);
    _custos['servicos']!.text = _n(c.servicos);
    _custos['despesasFixas']!.text = _n(c.despesasFixas);
    _custos['taxasFinanceiras']!.text = _n(c.taxasFinanceiras);
    _custos['margemLucro']!.text = _n(c.margemLucro);
  }

  static String _n(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

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
      );

  Future<void> _run(String ok, Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ok)));
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
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
              ? Center(
                  child: Text(
                    '${empresaAsync.error ?? configAsync.error}',
                  ),
                )
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
                child: Text('Só administradores podem alterar estas definições.'),
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
                    value: _moeda,
                    decoration: const InputDecoration(labelText: 'Moeda'),
                    items: [
                      for (final m in Moeda.values)
                        DropdownMenuItem(
                          value: m,
                          child: Text('${m.code} (${m.symbol})'),
                        ),
                    ],
                    onChanged: (v) =>
                        setState(() => _moeda = v ?? Moeda.eur),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<RegraArredondamento>(
                    value: _regra,
                    decoration:
                        const InputDecoration(labelText: 'Arredondamento'),
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
                    onChanged: (v) => setState(
                      () => _regra = v ?? RegraArredondamento.cima,
                    ),
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
              tema: _tema,
              corHex: _cor.text,
              logoUrl: ref.read(empresaRepositoryProvider).logoUrl(empresa),
              onTema: (t) => setState(() => _tema = t),
              onCor: (hex) => setState(() => _cor.text = hex),
              corController: _cor,
              onGuardar: _busy
                  ? null
                  : () => _run('Aparência guardada.', () async {
                        await ref.read(settingsActionsProvider).saveEmpresa(
                              nome: _nome.text,
                              moeda: _moeda,
                              regra: _regra,
                              corMarca: _cor.text,
                              tema: _tema,
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
                        await ref.read(settingsActionsProvider).definirLogo(
                              nome: f!.name,
                              bytes: f.bytes!.toList(),
                            );
                      }),
              onRemoverLogo: _busy || !empresa.temLogo
                  ? null
                  : () => _run('Logótipo removido.', () async {
                        await ref
                            .read(settingsActionsProvider)
                            .removerLogo();
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
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: e.value,
                    suffixText: '%',
                  ),
                  onChanged: (_) => setState(() {}),
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

/// Controlos de Aparência: modo de tema, cor (amostras + hex avançado) e
/// logótipo da empresa.
class _AparenciaControls extends StatelessWidget {
  const _AparenciaControls({
    required this.tema,
    required this.corHex,
    required this.logoUrl,
    required this.corController,
    required this.onTema,
    required this.onCor,
    required this.onGuardar,
    required this.onEscolherLogo,
    required this.onRemoverLogo,
  });

  final TemaApp tema;
  final String corHex;
  final String logoUrl;
  final TextEditingController corController;
  final ValueChanged<TemaApp> onTema;
  final ValueChanged<String> onCor;
  final VoidCallback? onGuardar;
  final VoidCallback? onEscolherLogo;
  final VoidCallback? onRemoverLogo;

  @override
  Widget build(BuildContext context) {
    final corAtual = AppTheme.parseHex(corHex);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        Text('Cor', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final p in AppTheme.presets)
              _Amostra(
                cor: p.cor,
                nome: p.nome,
                ativa: corAtual != null &&
                    (corAtual.toARGB32() & 0xFFFFFF) ==
                        (p.cor.toARGB32() & 0xFFFFFF),
                onTap: () => onCor(AppTheme.toHex(p.cor)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Theme(
          data: Theme.of(context)
              .copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Avançado'),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            children: [
              TextField(
                controller: corController,
                decoration: const InputDecoration(
                  labelText: 'Cor personalizada (hex, ex. #8D5B34)',
                ),
                onChanged: onCor,
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
