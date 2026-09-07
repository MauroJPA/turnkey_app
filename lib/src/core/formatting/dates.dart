/// Formatação de datas. Portado de `meu_app_ia/lib/utils/ui_helper.dart`.
library;

/// Converte uma data ISO-8601 do PocketBase para `dd/MM HH:mm` (hora local).
///
/// Devolve a string original se não for possível interpretar.
String formatDateTimeShort(String isoDate) {
  try {
    final dt = DateTime.parse(isoDate).toLocal();
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m $h:$min';
  } on FormatException {
    return isoDate;
  }
}

/// Converte uma data ISO-8601 para `dd/MM/yyyy` (hora local).
String formatDateShort(String isoDate) {
  try {
    final dt = DateTime.parse(isoDate).toLocal();
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}';
  } on FormatException {
    return isoDate;
  }
}
