"""Arayüz için simgeler, süslü çerçeveler ve İstanbul silueti üretir (assets/ui/).
Kullanım: python3 tools/make_ui_art.py  (Pillow gerekir). Hepsi koddan çizilir; dış kaynak yok."""
import math
import os
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui")
os.makedirs(OUT, exist_ok=True)
S = 4  # örnekleme çarpanı (kenar yumuşatma için büyük çizip küçültürüz)


def canvas(w, h):
    return Image.new("RGBA", (w * S, h * S), (0, 0, 0, 0))


def save(img, name, w, h):
    img.resize((w, h), Image.LANCZOS).save(os.path.join(OUT, name + ".png"))


def P(*pts):
    return [(x * S, y * S) for x, y in pts]


def ell(d, cx, cy, rx, ry, **kw):
    d.ellipse([(cx - rx) * S, (cy - ry) * S, (cx + rx) * S, (cy + ry) * S], **kw)


def shadowed(img, off=2, blur=3, alpha=150):
    a = img.split()[3]
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sh.putalpha(a.point(lambda v: v * alpha // 255))
    sh = sh.filter(ImageFilter.GaussianBlur(blur * S / 2))
    base = Image.new("RGBA", img.size, (0, 0, 0, 0))
    base.alpha_composite(sh, (off * S // 2, off * S))
    base.alpha_composite(img)
    return base


# ------------------------------------------------------------------ simgeler (64 px)

def coin():
    im = canvas(64, 64); d = ImageDraw.Draw(im)
    ell(d, 32, 32, 26, 26, fill=(150, 98, 24))
    ell(d, 32, 30, 25, 25, fill=(240, 190, 70))
    ell(d, 32, 30, 19, 19, outline=(196, 138, 34), width=3 * S)
    ell(d, 26, 24, 7, 5, fill=(255, 236, 160))
    d.rectangle(P((28, 26), (36, 34)), fill=(150, 98, 24))
    save(shadowed(im), "coin", 64, 64)


def castle():
    im = canvas(64, 64); d = ImageDraw.Draw(im)
    stone, dark, light = (196, 182, 156), (120, 108, 92), (226, 214, 190)
    d.rectangle(P((14, 22), (50, 58)), fill=stone)
    d.rectangle(P((14, 22), (22, 58)), fill=light)
    for x in (12, 24, 36, 46):
        d.rectangle(P((x, 12), (x + 7, 24)), fill=stone)
    d.rectangle(P((26, 38), (38, 58)), fill=(60, 44, 30))
    ell(d, 32, 38, 6, 6, fill=(60, 44, 30))
    for y in (30, 46):
        d.line(P((14, y), (50, y)), fill=dark, width=S)
    d.polygon(P((30, 2), (30, 13), (42, 7)), fill=(190, 30, 40))
    d.line(P((30, 2), (30, 14)), fill=(80, 60, 40), width=S)
    save(shadowed(im), "castle", 64, 64)


def swords():
    im = canvas(64, 64); d = ImageDraw.Draw(im)
    for flip in (1, -1):
        def T(x, y):
            return (32 + (x - 32) * flip, y)
        pts = [T(14, 10), T(50, 46)]
        d.line(P(*pts), fill=(225, 228, 235), width=5 * S)
        d.line(P(T(14, 10), T(46, 42)), fill=(255, 255, 255), width=S)
        d.line(P(T(42, 50), T(54, 38)), fill=(214, 168, 60), width=5 * S)
        d.line(P(T(48, 44), T(58, 56)), fill=(120, 70, 30), width=5 * S)
        ell(d, *T(59, 57), 3.5, 3.5, fill=(214, 168, 60))
    save(shadowed(im), "swords", 64, 64)


def logs():
    im = canvas(64, 64); d = ImageDraw.Draw(im)
    for cx, cy in ((20, 44), (44, 44), (32, 24)):
        d.rectangle(P((cx - 14, cy - 9), (cx + 8, cy + 9)), fill=(122, 74, 36))
        ell(d, cx + 8, cy, 9, 9, fill=(214, 170, 110))
        ell(d, cx + 8, cy, 5.5, 5.5, outline=(170, 120, 70), width=S)
        ell(d, cx + 8, cy, 2, 2, fill=(170, 120, 70))
        d.line(P((cx - 12, cy - 4), (cx + 2, cy - 4)), fill=(96, 56, 26), width=S)
    save(shadowed(im), "wood", 64, 64)


def iron():
    im = canvas(64, 64); d = ImageDraw.Draw(im)
    d.polygon(P((10, 46), (18, 30), (46, 30), (54, 46)), fill=(120, 128, 140))
    d.polygon(P((18, 30), (46, 30), (42, 22), (22, 22)), fill=(170, 178, 192))
    d.polygon(P((10, 46), (54, 46), (54, 52), (10, 52)), fill=(80, 86, 98))
    d.polygon(P((16, 26), (40, 26), (38, 24), (20, 24)), fill=(220, 226, 236))
    ell(d, 46, 18, 6, 5, fill=(150, 158, 172))
    save(shadowed(im), "iron", 64, 64)


def bread():
    im = canvas(64, 64); d = ImageDraw.Draw(im)
    ell(d, 32, 38, 26, 17, fill=(150, 86, 34))
    ell(d, 32, 34, 25, 16, fill=(206, 132, 58))
    ell(d, 26, 28, 12, 6, fill=(232, 168, 90))
    for x in (20, 32, 44):
        d.line(P((x - 4, 40), (x + 4, 28)), fill=(130, 70, 26), width=2 * S)
    save(shadowed(im), "food", 64, 64)


def speaker():
    im = canvas(64, 64); d = ImageDraw.Draw(im)
    w = (240, 228, 200)
    d.polygon(P((8, 24), (20, 24), (34, 12), (34, 52), (20, 40), (8, 40)), fill=w)
    for r in (10, 18):
        d.arc([(34 - r) * S, (32 - r) * S, (34 + r) * S, (32 + r) * S], -50, 50, fill=w, width=3 * S)
    save(im, "speaker", 64, 64)


def palace():
    im = canvas(64, 64); d = ImageDraw.Draw(im)
    g, dk = (232, 186, 82), (150, 104, 32)
    d.rectangle(P((10, 34), (54, 58)), fill=g)
    ell(d, 32, 34, 13, 13, fill=g)
    d.rectangle(P((10, 34), (54, 36)), fill=dk)
    d.rectangle(P((28, 44), (36, 58)), fill=(90, 56, 20))
    for x in (6, 54):
        d.rectangle(P((x, 18), (x + 4, 58)), fill=g)
        d.polygon(P((x, 18), (x + 4, 18), (x + 2, 8)), fill=g)
    d.line(P((32, 21), (32, 12)), fill=g, width=2 * S)
    save(shadowed(im), "palace", 64, 64)


def crescent(d, cx, cy, r, color, bg):
    ell(d, cx, cy, r, r, fill=color)
    ell(d, cx + r * 0.3, cy, r * 0.8, r * 0.8, fill=bg)
    sx, sy, sr = cx + r * 0.75, cy, r * 0.42
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rr = sr if i % 2 == 0 else sr * 0.42
        pts.append((sx + math.cos(a) * rr, sy + math.sin(a) * rr))
    d.polygon(P(*pts), fill=color)


def banner():
    w, h = 44, 96
    im = canvas(w, h); d = ImageDraw.Draw(im)
    red = (178, 28, 36)
    d.polygon(P((2, 0), (42, 0), (42, 92), (22, 78), (2, 92)), fill=red)
    d.polygon(P((2, 0), (6, 0), (6, 89), (2, 92)), fill=(140, 18, 26))
    d.line(P((2, 2), (42, 2)), fill=(226, 180, 74), width=3 * S)
    crescent(d, 19, 34, 10, (250, 244, 232), red)
    save(shadowed(im, 2, 3), "banner", w, h)


# ------------------------------------------------------------------ çerçeveler (9 parça)

def frame(name, top, bottom, edge=(214, 168, 72), inner=(120, 84, 34), size=64, r=10, deco=True):
    im = canvas(size, size); d = ImageDraw.Draw(im)
    # dikey renk geçişi
    grad = Image.new("RGBA", (size * S, size * S))
    gd = ImageDraw.Draw(grad)
    for y in range(size * S):
        t = y / (size * S - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,)
        gd.line([(0, y), (size * S, y)], fill=c)
    mask = Image.new("L", (size * S, size * S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size * S - 1, size * S - 1], r * S, fill=255)
    im.paste(grad, (0, 0), mask)
    d.rounded_rectangle([S, S, size * S - S - 1, size * S - S - 1], r * S, outline=edge, width=2 * S)
    d.rounded_rectangle([5 * S, 5 * S, size * S - 5 * S - 1, size * S - 5 * S - 1], max(1, r - 4) * S, outline=inner, width=S)
    if deco:
        for cx, cy in ((10, 10), (size - 10, 10), (10, size - 10), (size - 10, size - 10)):
            d.polygon(P((cx, cy - 4), (cx + 4, cy), (cx, cy + 4), (cx - 4, cy)), fill=edge)
    save(im, name, size, size)


# ------------------------------------------------------------------ İstanbul silueti (gün batımı)

def skyline():
    w, h = 720, 120
    im = Image.new("RGBA", (w * S, h * S))
    d = ImageDraw.Draw(im)
    for y in range(h * S):
        t = y / (h * S)
        top, mid, bot = (58, 64, 98), (214, 132, 78), (246, 200, 120)
        if t < 0.55:
            k = t / 0.55
            c = tuple(int(top[i] + (mid[i] - top[i]) * k) for i in range(3))
        else:
            k = (t - 0.55) / 0.45
            c = tuple(int(mid[i] + (bot[i] - mid[i]) * k) for i in range(3))
        d.line([(0, y), (w * S, y)], fill=c + (255,))
    ell(d, 560, 92, 26, 26, fill=(255, 226, 150))
    sil = (52, 40, 48)
    base = 104
    d.rectangle(P((0, base), (w, h)), fill=sil)
    # camiler: (merkez x, kubbe yarıçapı, minare sayısı)
    for cx, r, mins in ((150, 26, 4), (330, 22, 6), (500, 18, 2), (640, 14, 2), (40, 12, 0)):
        d.rectangle(P((cx - r * 1.6, base - r * 0.5), (cx + r * 1.6, base)), fill=sil)
        ell(d, cx, base - r * 0.5, r, r, fill=sil)
        d.rectangle(P((cx - 1.5, base - r * 1.5 - 8), (cx + 1.5, base - r * 0.5)), fill=sil)
        for k in (-1, 1):
            ell(d, cx + k * r * 1.1, base - r * 0.35, r * 0.45, r * 0.45, fill=sil)
        for m in range(mins):
            side = -1 if m % 2 == 0 else 1
            mx = cx + side * (r * 1.9 + (m // 2) * 14)
            mh = r * 2.6 + 10
            d.rectangle(P((mx - 2.2, base - mh), (mx + 2.2, base)), fill=sil)
            d.polygon(P((mx - 2.6, base - mh), (mx + 2.6, base - mh), (mx, base - mh - 12)), fill=sil)
            d.rectangle(P((mx - 3.6, base - mh * 0.7), (mx + 3.6, base - mh * 0.7 + 2)), fill=sil)
    for x in range(0, w, 22):
        hh = 6 + (x * 7) % 9
        d.rectangle(P((x, base - hh), (x + 16, base)), fill=sil)
    save(im, "skyline", w, h)


for f in (coin, castle, swords, logs, iron, bread, speaker, palace, banner, skyline):
    f()
frame("panel", (40, 30, 22), (22, 16, 12))
frame("button", (58, 44, 32), (34, 25, 18), edge=(180, 140, 66), inner=(90, 64, 30), deco=False)
frame("button_hot", (78, 60, 40), (44, 32, 22), edge=(240, 196, 96), inner=(120, 88, 40), deco=False)
frame("button_off", (36, 28, 22), (26, 20, 16), edge=(90, 72, 50), inner=(56, 42, 30), deco=False)
frame("red", (196, 36, 40), (118, 14, 20), edge=(236, 190, 90), inner=(150, 40, 30), deco=False)
frame("red_hot", (220, 54, 54), (140, 20, 26), edge=(255, 214, 120), inner=(170, 50, 40), deco=False)
frame("card", (56, 42, 30), (30, 22, 16), edge=(150, 116, 60), inner=(80, 60, 36), deco=False, r=8)
frame("card_hot", (74, 56, 38), (38, 28, 20), edge=(240, 196, 96), inner=(120, 88, 40), deco=False, r=8)
print("assets/ui hazır")
