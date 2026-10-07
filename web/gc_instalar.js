// Instalar a app no aparelho ("Adicionar ao ecrã principal").
//
// O Chrome/Edge (Android e computador) avisa com `beforeinstallprompt` e deixa
// a página escolher o momento: guarda-se o evento e a app (Flutter) mostra um
// cartão com "Instalar". O Safari (iPhone/iPad) não tem isso: lá só se pode
// instalar à mão (Partilhar → Adicionar ao ecrã principal), por isso a app
// mostra as instruções. Nenhuma função lança erro para fora.
'use strict';

(function () {
  var evento = null;
  var instaladaAgora = false;

  window.addEventListener('beforeinstallprompt', function (e) {
    e.preventDefault();
    evento = e;
  });
  window.addEventListener('appinstalled', function () {
    evento = null;
    instaladaAgora = true;
  });

  // JSON: { instalada, podeInstalar, ios }
  window.gcInstalarEstado = function () {
    var instalada = false;
    var ios = false;
    try {
      instalada =
        instaladaAgora ||
        (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches) ||
        navigator.standalone === true;
    } catch (_) {}
    try {
      var ua = navigator.userAgent || '';
      ios =
        /iPad|iPhone|iPod/.test(ua) ||
        (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
    } catch (_) {}
    return JSON.stringify({ instalada: instalada, podeInstalar: !!evento, ios: ios });
  };

  // Mostra o pedido do navegador; devolve "accepted", "dismissed" ou "indisponivel".
  window.gcInstalar = async function () {
    if (!evento) return 'indisponivel';
    try {
      evento.prompt();
      var r = await evento.userChoice;
      evento = null;
      return r && r.outcome ? String(r.outcome) : 'dismissed';
    } catch (_) {
      return 'indisponivel';
    }
  };
})();
