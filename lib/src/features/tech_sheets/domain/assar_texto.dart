/// Texto de forno de um produto: "Assar a 170 °C durante 11 min",
/// "Assar 11 min" ou "Forno a 170 °C". Vazio se não há nada definido.
String textoAssar(int minutos, int graus) {
  if (minutos > 0 && graus > 0) {
    return 'Assar a $graus °C durante $minutos min';
  }
  if (minutos > 0) return 'Assar $minutos min';
  if (graus > 0) return 'Forno a $graus °C';
  return '';
}

/// Versão curta para botões e linhas: "170 °C · 11 min".
String textoAssarCurto(int minutos, int graus) =>
    [if (graus > 0) '$graus °C', if (minutos > 0) '$minutos min'].join(' · ');
