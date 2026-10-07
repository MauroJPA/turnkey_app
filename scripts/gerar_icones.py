"""Gera os ícones da app (web/icons e web/favicon.png): um cookie com pepitas
de chocolate sobre o castanho da marca. Só precisa do Pillow:

    python scripts/gerar_icones.py

Para mudar o desenho ou as cores, edita as constantes e volta a correr.
"""
import math
import os
import random

from PIL import Image, ImageDraw

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'web')

FUNDO = (141, 91, 52)        # castanho da marca (#8D5B34)
FUNDO_ESCURO = (112, 70, 38)  # cantos mais escuros (profundidade)
MASSA = (232, 184, 124)       # massa do cookie
MASSA_BORDA = (205, 152, 92)  # bordo mais tostado
PEPITA = (74, 44, 23)         # chocolate
REALCE = (244, 214, 168)      # brilho suave na massa

# pepitas: (x, y, raio) em fração do raio do cookie (centro 0,0)
PEPITAS = [
    (-0.42, -0.38, 0.17), (0.10, -0.55, 0.15), (0.50, -0.22, 0.18),
    (-0.58, 0.10, 0.14), (-0.08, -0.08, 0.19), (0.38, 0.30, 0.16),
    (-0.30, 0.50, 0.17), (0.12, 0.62, 0.12), (0.62, 0.55, 0.10),
    (-0.72, -0.20, 0.09),
]


def cookie(tam, margem, redondo, ss=4):
    """Desenha em `tam` px (com supersampling). `margem` = fração livre à volta
    do cookie; `redondo` = cantos arredondados do fundo (ícone normal) ou
    nenhum (maskable: o sistema recorta)."""
    n = tam * ss
    im = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if redondo:
        d.rounded_rectangle([0, 0, n - 1, n - 1], radius=int(n * 0.22), fill=FUNDO)
    else:
        d.rectangle([0, 0, n, n], fill=FUNDO)
    d = ImageDraw.Draw(im)

    cx = cy = n / 2
    r = n * (0.5 - margem)
    # sombra do cookie (um tom mais escuro do fundo, deslocada para baixo)
    off = n * 0.025
    d.ellipse([cx - r, cy - r + off, cx + r, cy + r + off], fill=FUNDO_ESCURO)
    # bordo tostado + massa
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=MASSA_BORDA)
    r2 = r * 0.93
    d.ellipse([cx - r2, cy - r2, cx + r2, cy + r2], fill=MASSA)
    # brilho suave no canto de cima à esquerda
    rb = r * 0.80
    d.arc([cx - rb, cy - rb, cx + rb, cy + rb], 200, 260, fill=REALCE, width=max(2, int(n * 0.012)))
    d.ellipse([cx - r2 + r * 0.05, cy - r2 + r * 0.05, cx + r2 - r * 0.05, cy + r2 - r * 0.05], outline=MASSA_BORDA, width=max(1, int(n * 0.004)))
    # pepitas (ligeiramente irregulares)
    rnd = random.Random(7)
    for (px, py, pr) in PEPITAS:
        x = cx + px * r
        y = cy + py * r
        rr = pr * r
        pts = []
        for i in range(10):
            ang = 2 * math.pi * i / 10
            k = 1 + rnd.uniform(-0.18, 0.18)
            pts.append((x + math.cos(ang) * rr * k, y + math.sin(ang) * rr * k * 0.9))
        d.polygon(pts, fill=PEPITA)
    return im.resize((tam, tam), Image.LANCZOS)


def guardar(im, caminho, rgb=False):
    caminho = os.path.join(RAIZ, caminho)
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    if rgb:
        fundo = Image.new('RGB', im.size, FUNDO)
        fundo.paste(im, (0, 0), im.split()[3])
        im = fundo
    im.save(caminho, optimize=True)
    print('escrito', os.path.normpath(caminho), im.size)


for tam in (192, 512):
    # ícone normal: cantos arredondados, o cookie quase até à borda
    guardar(cookie(tam, 0.14, True), f'icons/Icon-{tam}.png')
    # maskable: fundo cheio; o cookie dentro da zona segura (80 % central)
    guardar(cookie(tam, 0.20, False), f'icons/Icon-maskable-{tam}.png', rgb=True)
guardar(cookie(64, 0.10, True), 'favicon.png')
guardar(cookie(180, 0.14, False), 'icons/apple-touch-icon.png', rgb=True)
