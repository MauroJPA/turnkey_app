// Textos de estado que aparecem por baixo de cada grupo das Opções, para se
// ver o essencial sem abrir nada ("Backup com problema", "Resumo às 08:00").

String _n(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// "CMV 30% · margem 25% · IVA 23%".
String resumoCustos({
  required double cmv,
  required double margem,
  required double iva,
}) =>
    'CMV ${_n(cmv)}% · margem ${_n(margem)}%'
    '${iva > 0 ? ' · IVA ${_n(iva)}%' : ''}';

/// "Resumo diário às 08:00 por email e Telegram · semanal ligado".
String resumoAvisos({
  required bool ativo,
  required String hora,
  required bool email,
  required bool telegram,
  required bool semanal,
}) {
  if (!ativo && !semanal) return 'Desligados';
  final canais = [if (email) 'email', if (telegram) 'Telegram'];
  if (canais.isEmpty) return 'Sem email nem Telegram escolhido';
  final partes = [
    if (ativo) 'Resumo diário${hora.isEmpty ? '' : ' às $hora'}',
    if (semanal) 'semanal ligado',
  ];
  return '${partes.join(' · ')} — por ${canais.join(' e ')}';
}

/// "Backups ok · 2 passos ligado"; `null` = ainda não se sabe.
String resumoSeguranca({
  required bool? backupComProblema,
  required bool? doisPassos,
}) {
  final partes = [
    if (backupComProblema != null)
      backupComProblema ? 'Backup com problema' : 'Backups ok',
    if (doisPassos != null)
      doisPassos ? '2 passos ligado' : '2 passos desligado',
  ];
  return partes.isEmpty ? 'Backups e acesso com 2 passos' : partes.join(' · ');
}
