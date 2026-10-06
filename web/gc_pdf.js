// Converte um PDF em imagens PNG (uma por página), no próprio aparelho, com o
// PDF.js que vai dentro da app (web/pdfjs). Nada sai do aparelho e não depende
// de nada instalado no servidor. A app (Dart) chama `gcPdfParaImagens`.
//
// Devolve { paginas: <total de páginas do PDF>, imagens: [Uint8Array PNG, …] }
// (só as primeiras `maxPaginas`).
'use strict';

window.gcPdfParaImagens = async function (url, escala, maxPaginas) {
  const pdfjs = await import('./pdfjs/pdf.min.js');
  pdfjs.GlobalWorkerOptions.workerSrc = new URL(
    './pdfjs/pdf.worker.min.js',
    document.baseURI,
  ).href;
  const doc = await pdfjs.getDocument({ url: url, isEvalSupported: false })
    .promise;
  try {
    const total = doc.numPages;
    const n = Math.min(total, maxPaginas || 10);
    const imagens = [];
    for (let i = 1; i <= n; i++) {
      const page = await doc.getPage(i);
      // escala pedida, mas sem passar de ~3000 px no lado maior (memória do telemóvel)
      const base = page.getViewport({ scale: 1 });
      const maior = Math.max(base.width, base.height);
      const e = Math.min(escala || 2.5, 3000 / maior);
      const vp = page.getViewport({ scale: e });
      const canvas = document.createElement('canvas');
      canvas.width = Math.max(1, Math.floor(vp.width));
      canvas.height = Math.max(1, Math.floor(vp.height));
      const ctx = canvas.getContext('2d');
      ctx.fillStyle = '#ffffff'; // PDFs têm fundo transparente
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      await page.render({ canvasContext: ctx, viewport: vp }).promise;
      const blob = await new Promise((res) => canvas.toBlob(res, 'image/png'));
      imagens.push(new Uint8Array(await blob.arrayBuffer()));
      canvas.width = canvas.height = 0; // liberta a memória
      page.cleanup();
    }
    return { paginas: total, imagens: imagens };
  } finally {
    await doc.destroy();
  }
};
