// Ajudas do aparelho para a app (som, vibração, leitor NFC). A app Flutter
// chama estas funções com `dart:js_interop`; nenhuma lança erro para fora.

// --- aviso do forno -----------------------------------------------------------
window.gcAvisarForno = function () {
  try {
    if (navigator.vibrate) navigator.vibrate([300, 150, 300, 150, 300]);
  } catch (_) {}
  try {
    var Ctx = window.AudioContext || window.webkitAudioContext;
    if (!Ctx) return;
    var ctx = new Ctx();
    for (var i = 0; i < 3; i++) {
      var osc = ctx.createOscillator();
      var ganho = ctx.createGain();
      osc.type = 'sine';
      osc.frequency.value = 880;
      ganho.gain.value = 0.25;
      osc.connect(ganho);
      ganho.connect(ctx.destination);
      var t0 = ctx.currentTime + i * 0.45;
      osc.start(t0);
      osc.stop(t0 + 0.25);
    }
  } catch (_) {}
};

// --- leitor de cartões NFC (Web NFC: só Chrome/Android e só em HTTPS) ---------
window.gcNfcSuporta = function () {
  return 'NDEFReader' in window && window.isSecureContext === true;
};

window.gcNfcLeitor = null;

// Começa a ler cartões. `aoLer(serie)` recebe o número de série do cartão;
// `aoErro(mensagem)` os problemas (permissão negada, sem NFC…).
window.gcNfcIniciar = function (aoLer, aoErro) {
  try {
    if (!window.gcNfcSuporta()) {
      aoErro('Este navegador não lê cartões NFC (precisa de Chrome no Android e de HTTPS).');
      return;
    }
    window.gcNfcParar();
    var leitor = new NDEFReader();
    var ctrl = new AbortController();
    window.gcNfcLeitor = ctrl;
    leitor
      .scan({ signal: ctrl.signal })
      .then(function () {
        leitor.onreading = function (ev) {
          try {
            aoLer(String(ev.serialNumber || ''));
          } catch (_) {}
        };
        leitor.onreadingerror = function () {
          aoErro('Não consegui ler o cartão. Tenta outra vez.');
        };
      })
      .catch(function (e) {
        aoErro(
          e && e.name === 'NotAllowedError'
            ? 'Sem permissão para usar o NFC. Autoriza no navegador.'
            : 'Não foi possível ligar o leitor NFC.'
        );
      });
  } catch (e) {
    aoErro('Não foi possível ligar o leitor NFC.');
  }
};

window.gcNfcParar = function () {
  try {
    if (window.gcNfcLeitor) window.gcNfcLeitor.abort();
  } catch (_) {}
  window.gcNfcLeitor = null;
};
