import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/errors/mensagem_amigavel.dart';
import '../../../core/printing/print_html.dart';
import '../../products/application/produtor_providers.dart';
import '../../settings/application/empresa_providers.dart';
import '../data/haccp_repository.dart';
import '../domain/haccp.dart';
import '../domain/haccp_relatorio.dart';

/// Gera o relatório HACCP formal de um período (e de um tipo, ou de todos),
/// numerado, e abre-o para imprimir ou guardar em PDF. O número e a
/// impressão digital ficam guardados na emissão (auditoria).
Future<void> gerarRelatorioHaccp(
  BuildContext context,
  WidgetRef ref, {
  required TipoControlo? tipo,
  required DateTime desde,
  required DateTime ate,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final repo = ref.read(haccpRepositoryProvider);
    final controlos = await repo.listControlos(incluirArquivados: true);
    final todos = await repo.registos(desde: desde, ate: ate);
    final ids = {
      for (final c in controlos)
        if (tipo == null || c.tipo == tipo) c.id,
    };
    final registos = [
      for (final r in todos)
        if (ids.contains(r.controloId)) r,
    ];
    final integridade = integridadeHaccp(registos);
    final nc = registos.where((r) => !r.conforme).length;
    final codigo = await repo.emitirRelatorio(
      tipo: tipo?.api ?? 'todos',
      desde: desde,
      ate: ate,
      registos: registos.length,
      naoConformidades: nc,
      integridade: integridade,
    );
    final empresa = ref.read(currentEmpresaProvider).valueOrNull?.nome ?? '';
    final operador = await ref.read(produtorRotuloProvider.future);
    final relatorio = RelatorioHaccp(
      codigo: codigo,
      empresa: empresa,
      operador: operador,
      desde: desde,
      ate: ate,
      tipo: tipo,
      controlos: [
        for (final c in controlos)
          // controlos arquivados só se tiverem registos neste período
          if (c.ativo || registos.any((r) => r.controloId == c.id)) c,
      ],
      registos: registos,
      emitidoEm: DateTime.now(),
      emitidoPor: ref.read(currentUserNameProvider) ?? '',
    );
    abrirImpressao(
      '$codigo — ${tituloTipoRelatorio(tipo)}',
      haccpRelatorioLegalHtml(relatorio),
      estiloExtra: haccpRelatorioEstilo(codigo),
    );
    messenger.showSnackBar(SnackBar(content: Text('Relatório $codigo emitido.')));
  } on Object catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
  }
}
