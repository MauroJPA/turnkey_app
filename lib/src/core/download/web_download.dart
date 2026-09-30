/// Descarrega bytes como um ficheiro no browser (só implementado na versão
/// web — a app só é lançada como web, mas o projeto tem scaffolding
/// android/ios que não pode arrastar `dart:html` para dentro).
library;

export 'web_download_stub.dart'
    if (dart.library.html) 'web_download_web.dart';
