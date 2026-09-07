import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/current_user.dart';
import '../../pricing/data/cost_config_repository.dart';
import '../../pricing/domain/cost_config.dart';
import '../application/empresa_providers.dart';
import '../application/settings_providers.dart';
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
            TextField(
              controller: _cor,
              decoration: const InputDecoration(
                labelText: 'Cor de marca (hex, ex. #8D5B34)',
              ),
              onChanged: (_) => setState(() {}),
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
                              );
                        }),
                child: const Text('Guardar empresa'),
              ),
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
