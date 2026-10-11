// Colar imagens (Ctrl+V) nas tarefas.
//
// O Flutter só vê texto na área de transferência; as imagens (capturas de
// ecrã, imagens copiadas) chegam ao navegador no evento `paste`. Este script
// escuta esse evento e, SE a app tiver registado um ouvinte (a folha de uma
// tarefa aberta), entrega-lhe cada imagem. Texto colado segue o caminho normal.
// Nenhuma função lança erro para fora.
'use strict';

(function () {
  var ouvinte = null;

  // fn(nome: string, bytes: Uint8Array) — a app regista ao abrir a tarefa e
  // retira ao fechar (gcColarLimpar).
  window.gcColarRegistar = function (fn) {
    ouvinte = typeof fn === 'function' ? fn : null;
  };
  window.gcColarLimpar = function () {
    ouvinte = null;
  };

  function extensao(tipo) {
    switch (String(tipo).toLowerCase()) {
      case 'image/jpeg':
        return '.jpg';
      case 'image/webp':
        return '.webp';
      default:
        return '.png';
    }
  }

  document.addEventListener(
    'paste',
    function (e) {
      try {
        if (!ouvinte) return;
        var cd = e.clipboardData;
        if (!cd) return;
        // com texto (ex.: células do Excel trazem texto + imagem) cola-se o texto
        var texto = cd.getData('text/plain');
        if (texto && texto.length > 0) return;
        var imagens = [];
        var ficheiros = cd.files ? Array.prototype.slice.call(cd.files) : [];
        for (var i = 0; i < ficheiros.length; i++) {
          var f = ficheiros[i];
          if (f && f.type && f.type.indexOf('image/') === 0) imagens.push(f);
        }
        if (!imagens.length) return;
        e.preventDefault();
        var agora = Date.now();
        imagens.forEach(function (f, n) {
          f.arrayBuffer().then(function (buf) {
            try {
              if (ouvinte) {
                ouvinte('colada-' + agora + '-' + (n + 1) + extensao(f.type), new Uint8Array(buf));
              }
            } catch (_) {}
          });
        });
      } catch (_) {}
    },
    true
  );
})();
