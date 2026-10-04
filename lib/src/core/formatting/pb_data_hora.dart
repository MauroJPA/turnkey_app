/// Data e hora no formato que o PocketBase guarda e compara
/// (`yyyy-MM-dd HH:mm:ss.SSSZ`, em UTC).
String pbDataHora(DateTime local) {
  final u = local.toUtc();
  String d2(int n) => n.toString().padLeft(2, '0');
  return '${u.year.toString().padLeft(4, '0')}-${d2(u.month)}-${d2(u.day)} '
      '${d2(u.hour)}:${d2(u.minute)}:${d2(u.second)}.000Z';
}
