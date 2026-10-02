import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/download/web_download.dart';
import '../../invoices/domain/invoice_erros.dart';
import '../application/relatorio_geral_service.dart';
import '../domain/periodo.dart';

/// Escolhe o período, o IVA e o formato e descarrega o Relatório geral
/// (vendas, produção, custo por sabor, despesas, tesouraria… — segue
/// `especificacao-relatorios.md`).
Future<void> showRelatorioGeralSheet(
  BuildContext context, {
  required Periodo periodoDoPainel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => _Sheet(periodoDoPainel: periodoDoPainel),
  );
}

enum _Intervalo { meses12, meses6, anoAtual, painel }

class _Sheet extends ConsumerStatefulWidget {
  const _Sheet({required this.periodoDoPainel});
  final Periodo periodoDoPainel;

  @override
  ConsumerState<_Sheet> createState() => _SheetState();
}

class _SheetState extends ConsumerState<_Sheet> {
  _Intervalo _intervalo = _Intervalo.meses12;
  FormatoRelatorio _formato = FormatoRelatorio.xlsx;
  double? _iva;
  bool _aGerar = false;
  String? _erro;

  static DateTime get _hoje {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  ({DateTime desde, DateTime ate}) get _datas {
    final h = _hoje;
    return switch (_intervalo) {
      _Intervalo.meses12 => (desde: DateTime(h.year, h.month - 11, 1), ate: h),
      _Intervalo.meses6 => (desde: DateTime(h.year, h.month - 5, 1), ate: h),
      _Intervalo.anoAtual => (desde: DateTime(h.year, 1, 1), ate: h),
      _Intervalo.painel => (
        desde: widget.periodoDoPainel.desde,
        ate: widget.periodoDoPainel.ate.isAfter(h)
            ? h
            : widget.periodoDoPainel.ate,
      ),
    };
  }

  static String _dmy(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _gerar() async {
    setState(() {
      _aGerar = true;
      _erro = null;
    });
    try {
      final d = _datas;
      final r = await ref
          .read(relatorioGeralServiceProvider)
          .gerar(
            desde: d.desde,
            ate: d.ate,
            formato: _formato,
            ivaAssumidoPercent: _iva,
          );
      baixarFicheiro(r.nome, r.bytes);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Relatório geral descarregado: ${r.nome}')),
      );
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _aGerar = false;
        _erro = mensagemAmigavel(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final d = _datas;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Relatório geral', style: tt.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Um ficheiro com uma folha por relatório: resumo mensal, vendas '
              '(por canal e sabor), produção, custo por sabor, despesas e '
              'tesouraria. As folhas que a app ainda não regista (plataformas, '
              'pessoal, eventos, origem dos clientes) vão como modelos por '
              'preencher; a folha "Leia-me" diz o que está completo.',
              style: tt.bodySmall,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<_Intervalo>(
              initialValue: _intervalo,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Período',
                helperText: '${_dmy(d.desde)} a ${_dmy(d.ate)}',
              ),
              items: [
                const DropdownMenuItem(
                  value: _Intervalo.meses12,
                  child: Text('Últimos 12 meses'),
                ),
                const DropdownMenuItem(
                  value: _Intervalo.meses6,
                  child: Text('Últimos 6 meses'),
                ),
                const DropdownMenuItem(
                  value: _Intervalo.anoAtual,
                  child: Text('Este ano'),
                ),
                DropdownMenuItem(
                  value: _Intervalo.painel,
                  child: Text(
                    'O período do painel (${widget.periodoDoPainel.label.toLowerCase()})',
                  ),
                ),
              ],
              onChanged: _aGerar
                  ? null
                  : (v) => setState(() => _intervalo = v ?? _intervalo),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<double?>(
              initialValue: _iva,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'IVA a assumir nas vendas sem IVA registado',
                helperText:
                    'As vendas do Vendus mais recentes já trazem o valor sem '
                    'IVA. Para as outras, escolhe uma taxa para estimar — ou '
                    'deixa em branco.',
                helperMaxLines: 3,
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('Não estimar')),
                DropdownMenuItem(value: 6.0, child: Text('6 %')),
                DropdownMenuItem(value: 13.0, child: Text('13 %')),
                DropdownMenuItem(value: 23.0, child: Text('23 %')),
              ],
              onChanged: _aGerar ? null : (v) => setState(() => _iva = v),
            ),
            const SizedBox(height: 12),
            SegmentedButton<FormatoRelatorio>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: FormatoRelatorio.xlsx,
                  label: Text('Excel'),
                  icon: Icon(Icons.table_chart_outlined),
                ),
                ButtonSegment(
                  value: FormatoRelatorio.csvZip,
                  label: Text('CSV (.zip)'),
                  icon: Icon(Icons.folder_zip_outlined),
                ),
              ],
              selected: {_formato},
              onSelectionChanged: _aGerar
                  ? null
                  : (s) => setState(() => _formato = s.first),
            ),
            if (_erro != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_erro!, style: TextStyle(color: cs.error)),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _aGerar ? null : _gerar,
              icon: _aGerar
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
              label: Text(_aGerar ? 'A gerar…' : 'Gerar e descarregar'),
            ),
          ],
        ),
      ),
    );
  }
}
