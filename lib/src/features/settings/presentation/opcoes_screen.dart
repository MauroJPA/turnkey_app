import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/help_actions.dart';
import '../../pricing/data/cost_config_repository.dart';
import '../../sales/data/sales_repository.dart';
import '../application/empresa_providers.dart';
import '../data/aprovacoes_repository.dart';
import '../data/avisos_repository.dart';
import '../data/backups_repository.dart';
import '../data/dois_passos_repository.dart';
import '../domain/opcoes_resumo.dart';
import 'integracoes_sheet.dart';

/// Configurações: uma lista de grupos, cada um com o seu estado à vista
/// ("Backup com problema", "Resumo às 08:00") e a abrir uma página curta.
class OpcoesScreen extends ConsumerWidget {
  const OpcoesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final papel = ref.watch(currentPapelProvider);
    final admin = papel.canEditConfig;
    final cs = Theme.of(context).colorScheme;

    final empresa = ref.watch(currentEmpresaProvider).valueOrNull;
    final custos = ref.watch(costConfigProvider).valueOrNull;
    final avisos = admin ? ref.watch(avisosConfigProvider).valueOrNull : null;
    final backups = admin ? ref.watch(estadoBackupsProvider).valueOrNull : null;
    final doisPassos = admin
        ? ref.watch(estadoDoisPassosProvider).valueOrNull
        : null;
    final vendus = admin ? ref.watch(estadoVendusProvider).valueOrNull : null;
    final aprovacoes = ref.watch(aprovacoesProvider).valueOrNull;

    final backupMal = backups?.problema() ?? false;
    final vendusMal = vendus != null && vendus.desatualizado(DateTime.now());

    String vendusTexto() {
      if (vendus == null) return 'Token do Vendus (guardado cifrado)';
      if (!vendus.configurado) return 'Vendus por configurar';
      if (vendusMal) return 'Vendus sem sincronizar';
      return 'Vendus sincronizado ${vendus.quando(DateTime.now())}';
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
        title: const Text('Configurações'),
        actions: const [HelpActions(topic: HelpTopic.configuracoes)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        children: [
          _Grupo(
            titulo: 'A tua empresa',
            linhas: [
              _Linha(
                chave: 'empresa',
                icon: Icons.storefront_outlined,
                titulo: 'Empresa e aparência',
                subtitulo: empresa == null
                    ? 'Nome, moeda, cores e logótipo'
                    : '${empresa.nome} · ${empresa.moeda.code}',
                rota: Routes.opcoesEmpresa,
              ),
              _Linha(
                chave: 'custos',
                icon: Icons.percent_outlined,
                titulo: 'Custos e IVA',
                subtitulo: custos == null
                    ? 'CMV, custos, IVA e dias de trabalho'
                    : resumoCustos(
                        cmv: custos.cmv,
                        margem: custos.margemLucro,
                        iva: custos.ivaVendas,
                      ),
                rota: Routes.opcoesCustos,
              ),
            ],
          ),
          _Grupo(
            titulo: 'Equipa',
            linhas: [
              if (papel.canManageTeam)
                const _Linha(
                  chave: 'equipa',
                  icon: Icons.group_outlined,
                  titulo: 'Equipa',
                  subtitulo: 'Utilizadores e permissões',
                  rota: Routes.team,
                ),
              if (admin)
                const _Linha(
                  chave: 'navegacao',
                  icon: Icons.view_carousel_outlined,
                  titulo: 'Navegação e permissões',
                  subtitulo: 'Rodapé e o que cada nível pode fazer',
                  rota: Routes.navegacao,
                ),
              if (admin)
                _Linha(
                  chave: 'avisos',
                  icon: Icons.notifications_active_outlined,
                  titulo: 'Avisos e resumos',
                  subtitulo: avisos == null
                      ? 'Email ou Telegram, à hora que escolheres'
                      : resumoAvisos(
                          ativo: avisos.ativo,
                          hora: avisos.hora,
                          email: avisos.emailAtivo,
                          telegram: avisos.telegramAtivo,
                          semanal: avisos.semanalAtivo,
                        ),
                  rota: Routes.avisos,
                ),
            ],
          ),
          if (admin)
            _Grupo(
              titulo: 'Ligações e segurança',
              linhas: [
                _Linha(
                  chave: 'ligacoes',
                  icon: Icons.link_outlined,
                  titulo: 'Ligações',
                  subtitulo: vendusTexto(),
                  alerta: vendusMal,
                  aoTocar: () => showIntegracoesSheet(context),
                ),
                _Linha(
                  chave: 'seguranca',
                  icon: Icons.shield_outlined,
                  titulo: 'Segurança e backups',
                  subtitulo: resumoSeguranca(
                    backupComProblema: backups == null ? null : backupMal,
                    doisPassos: doisPassos?.ativo,
                  ),
                  alerta: backupMal,
                  rota: Routes.opcoesSeguranca,
                ),
              ],
            ),
          _Grupo(
            titulo: 'Manutenção',
            linhas: [
              const _Linha(
                chave: 'dados',
                icon: Icons.health_and_safety_outlined,
                titulo: 'Saúde dos dados',
                subtitulo:
                    'O que falta preencher nas fichas e nos ingredientes',
                rota: Routes.saudeDados,
              ),
              if (aprovacoes?.operador ?? false)
                _Linha(
                  chave: 'aprovacoes',
                  icon: Icons.how_to_reg_outlined,
                  titulo: 'Aprovações de contas',
                  subtitulo: aprovacoes!.pendentes.isEmpty
                      ? 'Ninguém à espera'
                      : '${aprovacoes.pendentes.length} por aprovar',
                  alerta: aprovacoes.pendentes.isNotEmpty,
                  rota: Routes.aprovacoes,
                ),
            ],
          ),
          if (!admin)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
              child: Text(
                'Só administradores podem alterar as definições.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

class _Grupo extends StatelessWidget {
  const _Grupo({required this.titulo, required this.linhas});

  final String titulo;
  final List<Widget> linhas;

  @override
  Widget build(BuildContext context) {
    if (linhas.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 0, 6),
            child: Text(titulo, style: Theme.of(context).textTheme.titleSmall),
          ),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < linhas.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 56),
                  linhas[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha({
    required this.chave,
    required this.icon,
    required this.titulo,
    required this.subtitulo,
    this.rota,
    this.aoTocar,
    this.alerta = false,
  });

  final String chave;
  final IconData icon;
  final String titulo;
  final String subtitulo;
  final String? rota;
  final VoidCallback? aoTocar;

  /// Pede atenção: o estado aparece a vermelho.
  final bool alerta;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      key: ValueKey('opcao-$chave'),
      leading: Icon(icon, color: alerta ? cs.error : null),
      title: Text(titulo),
      subtitle: Text(
        subtitulo,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: alerta ? TextStyle(color: cs.error) : null,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: aoTocar ?? () => context.go(rota!),
    );
  }
}
