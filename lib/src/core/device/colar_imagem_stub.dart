import 'dart:typed_data';

/// Fora do navegador (testes, outras plataformas) não há colagem de imagens.
void ouvirImagensColadas(void Function(String nome, Uint8List bytes) aoColar) {}

void deixarDeOuvirImagensColadas() {}
