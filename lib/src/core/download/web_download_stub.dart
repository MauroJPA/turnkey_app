/// Usado fora da web (android/ios não têm `dart:html`).
void baixarFicheiro(String nome, List<int> bytes) {
  throw UnsupportedError(
    'Descarregar ficheiros só está disponível na versão web.',
  );
}
