// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
//
// Preferências deste aparelho (não vão para o servidor): ex. o modo de
// contagem escolhido neste telemóvel. A app só é construída para web.
import 'dart:html' as html;

/// Lê uma preferência deste aparelho; `null` se não existe ou o navegador
/// não deixa (janela privada, dados bloqueados).
String? lerPref(String chave) {
  try {
    return html.window.localStorage[chave];
  } on Object {
    return null;
  }
}

/// Guarda uma preferência deste aparelho (ignora erros do navegador).
void guardarPref(String chave, String valor) {
  try {
    html.window.localStorage[chave] = valor;
  } on Object {
    // sem armazenamento: a preferência só dura até recarregar
  }
}
