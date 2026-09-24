/// Escapa texto para o pôr dentro de HTML (conteúdo ou atributo entre aspas).
/// Os nomes de clientes, produtos e empresas vêm dos utilizadores e nunca
/// podem ir para uma página de impressão sem passar por aqui.
String escaparHtml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
