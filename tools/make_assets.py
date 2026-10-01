#!/usr/bin/env python3
"""
NeonScript asset generator.

Renders every image NeonScript uses (toolbar icons, banner, splash, app icon,
toolbar/switchbar backgrounds) with Pillow, so the artwork is reproducible and
nothing has to be downloaded.

    python tools/make_assets.py

Output goes to ../assets.  Fonts are read from C:\\Windows\\Fonts.
"""
import math
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "assets"))
FONTS = os.path.join(os.environ.get("WINDIR", r"C:\Windows"), "Fonts")

SS = 8            # supersampling factor for icons
ICON = 32         # final icon size in pixels
WHITE = (255, 255, 255, 255)


# --------------------------------------------------------------------------- helpers
def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def font(name, size, variation=None):
    path = os.path.join(FONTS, name)
    f = ImageFont.truetype(path, size)
    if variation:
        for v in (variation.encode(), variation):
            try:
                f.set_variation_by_name(v)
                break
            except Exception:
                continue
    return f


def vgradient(w, h, top, bottom):
    strip = Image.new("RGB", (1, h))
    px = strip.load()
    for y in range(h):
        px[0, y] = lerp(top, bottom, y / max(1, h - 1))
    return strip.resize((w, h))


# --------------------------------------------------------------------------- icon tiles
class Glyph:
    """Draws in a 32x32 coordinate space onto a supersampled RGBA layer."""

    def __init__(self):
        n = ICON * SS
        self.im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    @staticmethod
    def s(v):
        return v * SS

    def pts(self, p):
        return [(x * SS, y * SS) for x, y in p]

    def line(self, p, w=2.6, fill=WHITE):
        q = self.pts(p)
        self.d.line(q, fill=fill, width=int(w * SS), joint="curve")
        r = w * SS / 2
        for x, y in (q[0], q[-1]):
            self.d.ellipse([x - r, y - r, x + r, y + r], fill=fill)

    def poly(self, p, fill=WHITE):
        self.d.polygon(self.pts(p), fill=fill)

    def ell(self, box, fill=None, outline=None, w=2.2):
        self.d.ellipse([v * SS for v in box], fill=fill, outline=outline, width=int(w * SS))

    def arc(self, box, a0, a1, w=2.4, fill=WHITE):
        bx = [v * SS for v in box]
        self.d.arc(bx, a0, a1, fill=fill, width=int(w * SS))
        # round caps
        cx, cy = (bx[0] + bx[2]) / 2, (bx[1] + bx[3]) / 2
        rx, ry = (bx[2] - bx[0]) / 2 - w * SS / 2, (bx[3] - bx[1]) / 2 - w * SS / 2
        r = w * SS / 2
        for a in (a0, a1):
            x = cx + rx * math.cos(math.radians(a))
            y = cy + ry * math.sin(math.radians(a))
            self.d.ellipse([x - r, y - r, x + r, y + r], fill=fill)

    def pie(self, box, a0, a1, fill=WHITE):
        self.d.pieslice([v * SS for v in box], a0, a1, fill=fill)

    def rrect(self, box, r=2, fill=None, outline=None, w=2.2):
        self.d.rounded_rectangle([v * SS for v in box], radius=r * SS, fill=fill,
                                 outline=outline, width=int(w * SS))

    def erase_ell(self, box):
        self.d.ellipse([v * SS for v in box], fill=(0, 0, 0, 0))

    def erase_poly(self, p):
        self.d.polygon(self.pts(p), fill=(0, 0, 0, 0))


def star4(cx, cy, ro, ri):
    pts = []
    for i in range(8):
        a = math.radians(-90 + i * 45)
        r = ro if i % 2 == 0 else ri
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def star5(cx, cy, ro, ri):
    pts = []
    for i in range(10):
        a = math.radians(-90 + i * 36)
        r = ro if i % 2 == 0 else ri
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def tile(c1, c2):
    n = ICON * SS
    grad = vgradient(n, n, c1, c2).convert("RGBA")
    mask = Image.new("L", (n, n), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [SS * 1, SS * 1, n - SS * 1 - 1, n - SS * 1 - 1], radius=SS * 7, fill=255)
    # gloss on the upper half
    gloss = Image.new("RGBA", (n, n), (255, 255, 255, 0))
    gp = gloss.load()
    for y in range(int(n * 0.55)):
        a = int(70 * (1 - y / (n * 0.55)))
        for x in range(n):
            gp[x, y] = (255, 255, 255, a)
    grad = Image.alpha_composite(grad, gloss)
    # thin lighter rim
    rim = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    ImageDraw.Draw(rim).rounded_rectangle(
        [SS * 1, SS * 1, n - SS * 1 - 1, n - SS * 1 - 1], radius=SS * 7,
        outline=(255, 255, 255, 70), width=SS)
    grad = Image.alpha_composite(grad, rim)
    out = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    out.paste(grad, (0, 0), mask)
    return out


def compose(c1, c2, glyph):
    base = tile(c1, c2)
    alpha = glyph.im.split()[3]
    shadow = Image.new("RGBA", glyph.im.size, (0, 0, 0, 0))
    shadow.putalpha(alpha.point(lambda v: int(v * 0.35)))
    shadow = ImageChops.offset(shadow, 0, SS)
    shadow = shadow.filter(ImageFilter.GaussianBlur(SS * 0.7))
    base = Image.alpha_composite(base, shadow)
    base = Image.alpha_composite(base, glyph.im)
    return base.resize((ICON, ICON), Image.LANCZOS)


# --------------------------------------------------------------------------- glyphs
def g_power():
    g = Glyph()
    g.arc((8, 9, 24, 25), -55, 235, 2.6)
    g.line([(16, 6.5), (16, 16)], 2.8)
    return g


def g_globe():
    g = Glyph()
    g.ell((7, 7, 25, 25), outline=WHITE, w=2.2)
    g.ell((12, 7, 20, 25), outline=WHITE, w=1.8)
    g.line([(7.5, 16), (24.5, 16)], 1.8)
    g.line([(9, 11.2), (23, 11.2)], 1.4)
    g.line([(9, 20.8), (23, 20.8)], 1.4)
    return g


def g_hash():
    g = Glyph()
    g.line([(13.5, 7.5), (11.2, 24.5)], 2.5)
    g.line([(20.8, 7.5), (18.5, 24.5)], 2.5)
    g.line([(8, 13), (24.5, 13)], 2.5)
    g.line([(7.5, 19.5), (24, 19.5)], 2.5)
    return g


def g_star():
    g = Glyph()
    g.poly(star5(16, 16.5, 10.5, 4.6))
    return g


def g_bubble(dot):
    g = Glyph()
    g.rrect((6.5, 7.5, 25.5, 21.5), r=4, fill=WHITE)
    g.poly([(10.5, 20), (10.5, 26.5), (17.5, 20)])
    for x in (12, 16, 20):
        g.ell((x - 1.35, 13.6, x + 1.35, 16.3), fill=dot)
    return g


def g_moon():
    g = Glyph()
    g.ell((7, 7, 24.5, 24.5), fill=WHITE)
    g.erase_ell((12.5, 3.5, 29.5, 20.5))
    g.poly(star4(23, 21, 3.4, 1.0))
    return g


def g_bell(slash=False):
    g = Glyph()
    g.ell((10, 7, 22, 19), fill=WHITE)
    g.poly([(10, 13), (22, 13), (25, 22), (7, 22)])
    g.ell((13.8, 22.2, 18.2, 26.4), fill=WHITE)
    g.ell((15, 5.2, 17, 8), fill=WHITE)
    if slash:
        g.line([(7, 7), (25.5, 26)], 5.2, fill=(0, 0, 0, 0))
        g.line([(7, 7), (25.5, 26)], 2.6, fill=(255, 255, 255, 255))
    return g


def g_mention(badge=False):
    """An @ sign; with badge=True a red dot in the corner marks unread mentions."""
    g = Glyph()
    g.arc((6, 6.5, 26, 26.5), 35, 330, w=2.6)                 # outer ring, open at the lower right
    g.ell((11.2, 11.7, 20.2, 20.7), outline=WHITE, w=2.4)     # inner ring
    g.line([(20.2, 12.2), (20.2, 19.0)], 2.4)                 # stem
    g.arc((17.5, 13.5, 25.5, 24.5), 0, 85, w=2.4)             # tail joining the stem to the outer ring
    if badge:
        g.ell((17.2, 1.2, 29.8, 13.8), fill=(255, 255, 255, 255))
        g.ell((18.8, 2.8, 28.2, 12.2), fill=(255, 52, 84, 255))
    return g


def g_speaker(muted=False):
    g = Glyph()
    g.poly([(6.5, 13), (11, 13), (16.5, 8.5), (16.5, 23.5), (11, 19), (6.5, 19)])
    if muted:
        g.line([(20, 12.5), (26, 19.5)], 2.4)
        g.line([(26, 12.5), (20, 19.5)], 2.4)
    else:
        g.arc((13, 11, 23, 21), -48, 48, 2.2)
        g.arc((11, 7.5, 27, 24.5), -48, 48, 2.2)
    return g


def g_users():
    g = Glyph()
    # back person
    g.ell((18.2, 8.5, 24.6, 14.9), fill=(255, 255, 255, 190))
    g.ell((15.5, 16.5, 28, 30), fill=(255, 255, 255, 190))
    # front person
    g.ell((8.6, 7, 16.8, 15.2), fill=WHITE)
    g.ell((5, 17, 21.5, 33), fill=WHITE)
    # clip to icon safe area
    clip = Image.new("L", g.im.size, 0)
    ImageDraw.Draw(clip).rectangle([0, 0, ICON * SS, 25.5 * SS], fill=255)
    g.im.putalpha(ImageChops.multiply(g.im.split()[3], clip))
    return g


def g_grid():
    g = Glyph()
    for x0, y0 in ((7, 7), (17.3, 7), (7, 17.3), (17.3, 17.3)):
        g.rrect((x0, y0, x0 + 7.7, y0 + 7.7), r=2, fill=WHITE)
    return g


def g_contrast():
    g = Glyph()
    g.ell((7, 7, 25, 25), outline=WHITE, w=2.2)
    g.pie((7, 7, 25, 25), 90, 270)
    return g


def g_sparkles():
    g = Glyph()
    g.poly(star4(14.5, 17.5, 9, 2.6))
    g.poly(star4(23.5, 9, 4.2, 1.3))
    g.poly(star4(24, 23, 3, 1.0))
    return g


def g_smile():
    g = Glyph()
    g.ell((7, 7, 25, 25), outline=WHITE, w=2.2)
    g.ell((11.6, 12, 14.4, 15.2), fill=WHITE)
    g.ell((17.6, 12, 20.4, 15.2), fill=WHITE)
    g.arc((10.8, 11, 21.2, 21.4), 28, 152, 2.2)
    return g


def g_shield(check):
    g = Glyph()
    g.poly([(16, 5.5), (24.5, 8.6), (24.5, 16), (20.8, 22.2), (16, 26.5),
            (11.2, 22.2), (7.5, 16), (7.5, 8.6)])
    g.line([(12.2, 16), (15, 19), (20.2, 12.4)], 2.4, fill=check)
    return g


def g_crown():
    g = Glyph()
    g.poly([(6.5, 21.5), (7.5, 10.5), (12.4, 15.5), (16, 8.5), (19.6, 15.5),
            (24.5, 10.5), (25.5, 21.5)])
    g.rrect((6.5, 23, 25.5, 26), r=1.4, fill=WHITE)
    return g


def g_download():
    g = Glyph()
    g.line([(16, 6.5), (16, 17.5)], 2.8)
    g.poly([(10, 13.8), (22, 13.8), (16, 20.6)])
    g.line([(8, 19.5), (8, 25), (24, 25), (24, 19.5)], 2.4)
    return g


def g_doc(lines):
    g = Glyph()
    g.rrect((8.5, 5.5, 23.5, 26.5), r=2.4, fill=WHITE)
    for y, x1 in ((12, 20), (16, 20), (20, 16.6)):
        g.line([(11.8, y), (x1, y)], 1.9, fill=lines)
    return g


def g_gear():
    g = Glyph()
    cx = cy = 16
    for i in range(8):
        a = math.radians(i * 45)
        ca, sa = math.cos(a), math.sin(a)
        r0, r1, hw = 6, 10.4, 1.9
        p = [(cx + r0 * ca - hw * sa, cy + r0 * sa + hw * ca),
             (cx + r1 * ca - hw * sa, cy + r1 * sa + hw * ca),
             (cx + r1 * ca + hw * sa, cy + r1 * sa - hw * ca),
             (cx + r0 * ca + hw * sa, cy + r0 * sa - hw * ca)]
        g.poly(p)
    g.ell((8.6, 8.6, 23.4, 23.4), fill=WHITE)
    g.erase_ell((12.6, 12.6, 19.4, 19.4))
    return g


def g_info():
    g = Glyph()
    g.ell((7, 7, 25, 25), outline=WHITE, w=2.2)
    g.ell((14.8, 10.2, 17.2, 12.6), fill=WHITE)
    g.line([(16, 14.6), (16, 21.4)], 2.5)
    return g


def g_search():
    g = Glyph()
    g.ell((7, 7, 19.5, 19.5), outline=WHITE, w=2.4)
    g.line([(18, 18), (24.5, 24.5)], 3.2)
    return g


def g_keyboard(keys):
    g = Glyph()
    g.rrect((5.5, 9.5, 26.5, 23.5), r=3, fill=WHITE)
    for row, (y, xs) in enumerate(((12.4, (8.6, 12.4, 16.2, 20, 23.4)),
                                   (16, (8.6, 12.4, 16.2, 20, 23.4)))):
        for x in xs:
            g.rrect((x - 0.1, y, x + 2.2, y + 2.2), r=0.5, fill=keys)
    g.rrect((10.5, 19.6, 21.5, 21.8), r=0.6, fill=keys)
    return g


def g_wand():
    g = Glyph()
    g.line([(8, 24), (20, 12)], 3.2)
    g.poly(star4(22.5, 9.5, 5.2, 1.6))
    g.poly(star4(10, 10, 2.6, 0.9))
    return g


def g_plug():
    g = Glyph()
    g.rrect((9, 11, 23, 20), r=3, fill=WHITE)
    g.line([(13, 11), (13, 6.5)], 2.4)
    g.line([(19, 11), (19, 6.5)], 2.4)
    g.line([(16, 20), (16, 26)], 2.6)
    return g


def g_flag():
    g = Glyph()
    g.line([(10, 6.5), (10, 26)], 2.6)
    g.poly([(11, 8), (24.5, 8), (21, 12.8), (24.5, 17.5), (11, 17.5)])
    return g



def g_sliders():
    g = Glyph()
    for y, kx in ((10.5, 11), (16, 20), (21.5, 14)):
        g.line([(7, y), (25, y)], 2.0)
        g.ell((kx - 3.2, y - 3.2, kx + 3.2, y + 3.2), fill=WHITE)
    return g

ICONS = {
    # name: (colour top, colour bottom, glyph factory)
    "connect":    ("#2ee6a8", "#0b9e7d", g_power),
    "disconnect": ("#ff6b8b", "#c4234f", g_power),
    "servers":    ("#5cc8ff", "#3556e8", g_globe),
    "channels":   ("#b66dff", "#6a2fc4", g_hash),
    "favorites":  ("#ffd84d", "#f08a12", g_star),
    "query":      ("#ff6fae", "#e0267c", lambda: g_bubble(hexc("#e0267c") + (255,))),
    "away":       ("#7c83ff", "#3f3fc4", g_moon),
    "dnd_off":    ("#ffcf4a", "#e8890b", lambda: g_bell(False)),
    "dnd_on":     ("#ff6b8b", "#b81f4b", lambda: g_bell(True)),
    "sound_on":   ("#4de0f0", "#0f8fb5", lambda: g_speaker(False)),
    "sound_off":  ("#9aa3b2", "#586174", lambda: g_speaker(True)),
    "notify":     ("#ff9f5a", "#e8550f", g_users),
    "dash":       ("#35e0f5", "#0a85a8", g_grid),
    "theme":      ("#f58be0", "#8a3fe0", g_contrast),
    "fx":         ("#ffe55c", "#f0508a", g_sparkles),
    "symbols":    ("#b5f04a", "#4f9a12", g_smile),
    "protect":    ("#3fe5a0", "#0d8f63", lambda: g_shield(hexc("#0d8f63") + (255,))),
    "access":     ("#ffd84d", "#c98a06", g_crown),
    "dcc":        ("#52c8ff", "#0a74c4", g_download),
    "logs":       ("#e8b96a", "#9c6710", lambda: g_doc(hexc("#9c6710") + (255,))),
    "options":    ("#9fb0cc", "#556482", g_gear),
    "help":       ("#6aa8ff", "#2a4fd0", g_info),
    "search":     ("#8be0ff", "#3a7de0", g_search),
    "hotkeys":    ("#c7a6ff", "#6b46c8", lambda: g_keyboard(hexc("#6b46c8") + (255,))),
    "wand":       ("#ff9ad5", "#a63fd8", g_wand),
    "plug":       ("#2ee6a8", "#0b9e7d", g_plug),
    "flag":       ("#ff8a5c", "#d0341c", g_flag),
    "chanctl":    ("#5eead4", "#0f766e", g_sliders),
    "mentions":     ("#7ee787", "#1f9d55", lambda: g_mention(False)),
    "mentions_new": ("#ff9f5a", "#d9480f", lambda: g_mention(True)),
}


def make_icons():
    for name, (c1, c2, factory) in ICONS.items():
        img = compose(hexc(c1), hexc(c2), factory())
        img.save(os.path.join(OUT, f"{name}.png"))
    print(f"  {len(ICONS)} toolbar icons")


# --------------------------------------------------------------------------- synthwave art
def synthwave(w, h, scale=2, sun_r=0.30, horizon=0.58):
    """Retro sun + perspective grid.  Returns an RGB image of size (w, h)."""
    W, H = w * scale, h * scale
    sky = vgradient(W, int(H * horizon), hexc("#07031a"), hexc("#3b0f6b"))
    img = Image.new("RGB", (W, H), hexc("#07031a"))
    img.paste(sky, (0, 0))
    # warm band near the horizon
    hy = int(H * horizon)
    band = vgradient(W, int(H * 0.18), hexc("#3b0f6b"), hexc("#ff2e88"))
    img.paste(band, (0, hy - band.size[1]))

    # sun with scan-line cutouts
    cx, cy, r = int(W * 0.5), int(hy - H * 0.04), int(H * sun_r)
    sun = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sg = vgradient(2 * r, 2 * r, hexc("#ffe14d"), hexc("#ff2e88")).convert("RGBA")
    sm = Image.new("L", (2 * r, 2 * r), 0)
    ImageDraw.Draw(sm).ellipse([0, 0, 2 * r - 1, 2 * r - 1], fill=255)
    cut = ImageDraw.Draw(sm)
    y = int(r * 0.62)
    gap = max(2, int(r * 0.03))
    while y < 2 * r:
        cut.rectangle([0, y, 2 * r, y + gap], fill=0)
        gap += max(1, int(r * 0.014))
        y += int(r * 0.12) + gap
    sun.paste(sg, (cx - r, cy - r), sm)
    # glow
    glow = sun.filter(ImageFilter.GaussianBlur(r * 0.35))
    img = Image.alpha_composite(img.convert("RGBA"), glow)
    img = Image.alpha_composite(img, sun)
    # ground
    ground = vgradient(W, H - hy, hexc("#12052b"), hexc("#05010f")).convert("RGBA")
    img.paste(ground, (0, hy))
    d = ImageDraw.Draw(img)
    # horizon line glow
    d.rectangle([0, hy - 1, W, hy + 1], fill=hexc("#ff7ad9") + (255,))
    # grid: vertical lines converge at the vanishing point
    vx = W / 2
    lw = max(1, scale)
    for i in range(-14, 15):
        x_bottom = vx + i * (W * 0.16)
        d.line([(vx + i * (W * 0.012), hy), (x_bottom, H)], fill=hexc("#33e1ff") + (200,), width=lw)
    # horizontal lines with perspective spacing
    t = 0.0
    k = 0
    while True:
        k += 1
        t = (k / 9.0) ** 2.1
        y = hy + t * (H - hy)
        if y >= H:
            break
        d.line([(0, y), (W, y)], fill=hexc("#ff4fd8") + (210,), width=lw)
    return img.convert("RGB").resize((w, h), Image.LANCZOS)


def glow_text(img, xy, text, fnt, fill, glow, blur=6, anchor="la"):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).text(xy, text, font=fnt, fill=glow + (255,), anchor=anchor)
    halo = layer.filter(ImageFilter.GaussianBlur(blur))
    img.alpha_composite(halo)
    img.alpha_composite(halo)
    ImageDraw.Draw(img).text(xy, text, font=fnt, fill=fill, anchor=anchor)


def gradient_text(img, xy, text, fnt, top, bottom, anchor="la", glow=(255, 46, 136), blur=7):
    """Vertical-gradient lettering with a neon halo."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).text(xy, text, font=fnt, fill=glow + (255,), anchor=anchor)
    halo = layer.filter(ImageFilter.GaussianBlur(blur))
    img.alpha_composite(halo)
    img.alpha_composite(halo)
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).text(xy, text, font=fnt, fill=255, anchor=anchor)
    bbox = mask.getbbox()
    if not bbox:
        return
    grad = vgradient(img.size[0], bbox[3] - bbox[1], top, bottom)
    full = Image.new("RGB", img.size, top)
    full.paste(grad, (0, bbox[1]))
    img.paste(full, (0, 0), mask)


def make_banner():
    w, h = 460, 130
    art = synthwave(w, h, scale=3, sun_r=0.34, horizon=0.60).convert("RGBA")
    f = font("bahnschrift.ttf", 46, "Bold")
    gradient_text(art, (w // 2, 38), "NEONSCRIPT", f, hexc("#ffffff"), hexc("#7ff0ff"),
                  anchor="mm", blur=5)
    sub = font("segoeuib.ttf", 11)
    glow_text(art, (w // 2, 74), "T H E   2 0 2 6   R E M A S T E R", sub,
              hexc("#ffd9f3") + (255,), hexc("#ff2e88"), blur=3, anchor="mm")
    art.convert("RGB").save(os.path.join(OUT, "banner.png"))
    art.convert("RGB").save(os.path.join(OUT, "banner.bmp"))
    print("  banner")


def make_splash():
    w, h = 480, 270
    art = synthwave(w, h, scale=3, sun_r=0.30, horizon=0.60).convert("RGBA")
    f = font("bahnschrift.ttf", 58, "Bold")
    gradient_text(art, (w // 2, 70), "NEONSCRIPT", f, hexc("#ffffff"), hexc("#7ff0ff"),
                  anchor="mm", blur=6)
    sub = font("segoeuib.ttf", 13)
    glow_text(art, (w // 2, 118), "T H E   2 0 2 6   R E M A S T E R", sub,
              hexc("#ffd9f3") + (255,), hexc("#ff2e88"), blur=3, anchor="mm")
    # frame
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w - 1, h - 1], outline=hexc("#ff4fd8") + (255,), width=2)
    d.rectangle([2, 2, w - 3, h - 3], outline=hexc("#33e1ff") + (160,), width=1)
    art.convert("RGB").save(os.path.join(OUT, "splash.png"))
    art.convert("RGB").save(os.path.join(OUT, "splash.bmp"))
    print("  splash")



# dialog header strips: key -> (dialog width, header height) in dialog units (dbu).  The header is
# drawn edge to edge, so each image is rendered at exactly that aspect ratio (4 px per dbu) - mIRC
# keeps the picture's proportions, so any mismatch would leave grey bars at the sides.
HEADERS = {
    "options": ("CONTROL PANEL", 352, 33), "servers": ("SERVERS & NETWORKS", 362, 33),
    "wizard": ("SETUP WIZARD", 300, 30), "fx": ("TEXT EFFECTS", 258, 30),
    "messages": ("MESSAGES", 248, 30), "users": ("USERLIST", 300, 30),
    "kb": ("KICK & BAN", 264, 30), "chars": ("SYMBOL MAP", 248, 30),
    "hotkeys": ("HOTKEYS", 236, 30), "sounds": ("SOUNDS", 260, 30),
    "away": ("AWAY", 232, 30), "cc": ("CHANNEL CONTROL", 340, 30),
    "bnc": ("BOUNCER", 264, 30), "bncnets": ("LURKER NETWORKS", 232, 30),
    "debug": ("DEBUG CONSOLE", 330, 30), "backup": ("BACKUP & RESTORE", 300, 30),
    "mentions": ("MENTIONS", 330, 30),
    "link": ("LINK PREVIEW", 300, 30),
}
PX_PER_DBU = 4


def make_headers():
    """Slim branded strips shown at the top of every NeonScript dialog."""
    for key, (sub, wd, hd) in HEADERS.items():
        w, h = wd * PX_PER_DBU, hd * PX_PER_DBU
        art = synthwave(w, h, scale=3, sun_r=0.75, horizon=0.70).convert("RGBA")
        f = font("bahnschrift.ttf", int(h * 0.42), "Bold")
        left = 14 * PX_PER_DBU
        gradient_text(art, (left, int(h * 0.40)), "NEONSCRIPT", f, hexc("#ffffff"), hexc("#7ff0ff"),
                      anchor="lm", blur=4)
        sf = font("segoeuib.ttf", int(h * 0.16))
        glow_text(art, (left + 2, int(h * 0.76)), "   ".join(sub), sf, hexc("#ffd9f3") + (255,),
                  hexc("#ff2e88"), blur=2, anchor="lm")
        art.convert("RGB").save(os.path.join(OUT, f"header_{key}.png"))
    # the old 640x66 strip is still used as a placeholder picture by the theme gallery
    w, h = 640, 66
    art = synthwave(w, h, scale=3, sun_r=0.75, horizon=0.70).convert("RGBA")
    gradient_text(art, (22, 26), "NEONSCRIPT", font("bahnschrift.ttf", 30, "Bold"), hexc("#ffffff"),
                  hexc("#7ff0ff"), anchor="lm", blur=4)
    glow_text(art, (24, 49), "   ".join("THEMES"), font("segoeuib.ttf", 11), hexc("#ffd9f3") + (255,),
              hexc("#ff2e88"), blur=2, anchor="lm")
    art.convert("RGB").save(os.path.join(OUT, "header_themes.png"))
    # the About dialog's big banner: 250 x 60 dbu
    w, h = 250 * PX_PER_DBU, 60 * PX_PER_DBU
    art = synthwave(w, h, scale=3, sun_r=0.34, horizon=0.60).convert("RGBA")
    gradient_text(art, (w // 2, int(h * 0.30)), "NEONSCRIPT", font("bahnschrift.ttf", int(h * 0.36), "Bold"),
                  hexc("#ffffff"), hexc("#7ff0ff"), anchor="mm", blur=5)
    glow_text(art, (w // 2, int(h * 0.58)), "T H E   2 0 2 6   R E M A S T E R",
              font("segoeuib.ttf", int(h * 0.09)), hexc("#ffd9f3") + (255,), hexc("#ff2e88"),
              blur=3, anchor="mm")
    art.convert("RGB").save(os.path.join(OUT, "banner_about.png"))
    print(f"  {len(HEADERS)} dialog headers + about banner")


def make_app_icon():
    big = 256
    n = big * 4
    grad = Image.new("RGBA", (n, n))
    g1, g2 = hexc("#ff2e88"), hexc("#2ee6ff")
    px = grad.load()
    for y in range(n):
        for x in range(n):
            t = (x + y) / (2.0 * n)
            px[x, y] = lerp(g1, g2, t) + (255,)
    mask = Image.new("L", (n, n), 0)
    ImageDraw.Draw(mask).rounded_rectangle([n * 0.03] * 2 + [n * 0.97] * 2,
                                           radius=int(n * 0.22), fill=255)
    tile_img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    tile_img.paste(grad, (0, 0), mask)
    f = font("bahnschrift.ttf", int(n * 0.66), "Bold")
    layer = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    ImageDraw.Draw(layer).text((n // 2, int(n * 0.52)), "N", font=f, fill=(10, 4, 30, 150), anchor="mm")
    layer = ImageChops.offset(layer, 0, int(n * 0.012)).filter(ImageFilter.GaussianBlur(n * 0.008))
    tile_img.alpha_composite(layer)
    ImageDraw.Draw(tile_img).text((n // 2, int(n * 0.51)), "N", font=f, fill=(255, 255, 255, 255), anchor="mm")
    icon = tile_img.resize((big, big), Image.LANCZOS)
    icon.save(os.path.join(OUT, "neon.png"))
    icon.save(os.path.join(OUT, "neon.ico"),
              sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    print("  app icon")


def make_backgrounds():
    # Toolbar / switchbar / treebar strips (dark + light).  Tiled by mIRC.
    for tag, top, bot, line in (("dark", "#171826", "#0d0e17", "#ff2e88"),
                                ("light", "#f6f4fb", "#e4def2", "#c2188a")):
        w, h = 64, 48
        strip = vgradient(w, h, hexc(top), hexc(bot)).convert("RGBA")
        d = ImageDraw.Draw(strip)
        d.line([(0, h - 1), (w, h - 1)], fill=hexc(line) + (150,), width=1)
        d.line([(0, 0), (w, 0)], fill=(255, 255, 255, 28 if tag == "dark" else 140), width=1)
        strip.convert("RGB").save(os.path.join(OUT, f"bg_{tag}.bmp"))
        strip.convert("RGB").save(os.path.join(OUT, f"bg_{tag}.png"))
    print("  backgrounds")



# --------------------------------------------------------------------------- theme thumbnails
BASE16 = ["ffffff", "000000", "00007f", "009300", "ff0000", "7f0000", "9c009c", "fc7f00",
          "ffff00", "00fc00", "009393", "00ffff", "0000fc", "ff00ff", "7f7f7f", "d2d2d2"]
EXT = ("470000 472100 474700 324700 004700 00472c 004747 002747 000047 2e0047 470047 47002a "
       "740000 743a00 747400 517400 007400 007449 007474 004074 000074 4b0074 740074 740045 "
       "b50000 b56300 b5b500 7db500 00b500 00b571 00b5b5 0063b5 0000b5 7500b5 b500b5 b5006b "
       "ff0000 ff8c00 ffff00 b2ff00 00ff00 00ffa0 00ffff 008cff 0000ff a500ff ff00ff ff0098 "
       "ff5959 ffb459 ffff71 cfff60 6fff6f 65ffc9 6dffff 59b4ff 5959ff c459ff ff66ff ff59bc "
       "ff9c9c ffd39c ffff9c e2ff9c 9cff9c 9cffdb 9cffff 9cd3ff 9c9cff dc9cff ff9cff ff94d3 "
       "000000 131313 282828 363636 4d4d4d 656565 818181 9f9f9f bcbcbc e2e2e2 ffffff").split()
PALETTE = BASE16 + EXT          # index 0..98
ITEMS = ["Background", "Action", "Ctcp", "Highlight", "Info", "Info2", "Invite", "Join", "Kick",
         "Mode", "Nick", "Normal", "Notice", "Notify", "Other", "Own", "Part", "Quit", "Topic",
         "Wallops", "Whois", "Editbox", "Editbox text", "Listbox", "Listbox text", "Gray text",
         "Title text", "Inactive", "Treebar", "Treebar Text", "MDI area"]


def pal(i):
    return hexc(PALETTE[int(i)])


def make_theme_thumbs():
    import configparser
    cp = configparser.ConfigParser(interpolation=None)
    cp.read(os.path.join(HERE, "..", "data", "themes.ini"), encoding="utf-8")
    order = cp["themes"]["order"].split(",")
    mono = lambda sz: ImageFont.truetype(os.path.join(FONTS, "consola.ttf"), sz)
    S2 = 2
    W, H = 240 * S2, 140 * S2
    for tid in order:
        c = [pal(v) for v in cp[tid]["colors"].split(",")]
        col = dict(zip(ITEMS, c))
        img = Image.new("RGB", (W, H), col["MDI area"])
        d = ImageDraw.Draw(img)
        # title strip
        d.rectangle([0, 0, W, 14 * S2], fill=col["Treebar"])
        d.text((6 * S2, 2 * S2), "NeonScript", font=mono(9 * S2), fill=col["Title text"])
        d.line([(0, 14 * S2), (W, 14 * S2)], fill=hexc(cp[tid]["acc1"].lstrip("#")), width=S2)
        # treebar
        d.rectangle([0, 15 * S2, 58 * S2, H], fill=col["Treebar"])
        for i, (t, hi) in enumerate((("Status", 0), ("#neon", 1), ("#chat", 0), ("Nova", 0))):
            y = (20 + i * 12) * S2
            if hi:
                d.rectangle([2 * S2, y - S2, 56 * S2, y + 10 * S2], fill=col["Listbox"])
            d.text((6 * S2, y), t, font=mono(8 * S2), fill=col["Treebar Text"])
        # nick list
        d.rectangle([W - 44 * S2, 15 * S2, W, H - 14 * S2], fill=col["Listbox"])
        for i, n in enumerate(("@Kira", "+Nova", "Zed", "You")):
            d.text((W - 41 * S2, (20 + i * 11) * S2), n, font=mono(8 * S2), fill=col["Listbox text"])
        # chat area
        d.rectangle([59 * S2, 15 * S2, W - 45 * S2, H - 14 * S2], fill=col["Background"])
        f = mono(8 * S2)
        lines = [
            ("12:01", "Join", "→ Nova joined #neon"),
            ("12:01", "Normal", None),
            ("12:02", "Action", "* Kira waves"),
            ("12:02", "Notice", "-ChanServ- welcome!"),
            ("12:03", "Quit", "← Zed quit (timeout)"),
            ("12:03", "Own", "<You> love this theme"),
            ("12:04", "Topic", "Topic: ship it"),
        ]
        y = 19 * S2
        for ts, kind, text in lines:
            x = 62 * S2
            d.text((x, y), ts, font=f, fill=col["Gray text"])
            x += 30 * S2
            if text is None:
                d.text((x, y), "<Nova>", font=f, fill=col["Nick"])
                d.text((x + 38 * S2, y), "hey all", font=f, fill=col["Normal"])
            else:
                d.text((x, y), text, font=f, fill=col[kind])
            y += 11 * S2
        # editbox
        d.rectangle([59 * S2, H - 13 * S2, W, H], fill=col["Editbox"])
        d.text((63 * S2, H - 11 * S2), "/neon_", font=f, fill=col["Editbox text"])
        img = img.resize((240, 140), Image.LANCZOS)
        ImageDraw.Draw(img).rectangle([0, 0, 239, 139], outline=hexc(cp[tid]["acc1"].lstrip("#")), width=1)
        img.save(os.path.join(OUT, f"theme_{tid}.png"))
    print(f"  {len(order)} theme thumbnails")



def main():
    os.makedirs(OUT, exist_ok=True)
    print("NeonScript assets ->", OUT)
    make_icons()
    make_banner()
    make_splash()
    make_headers()
    make_app_icon()
    make_backgrounds()
    make_theme_thumbs()
    print("done")


if __name__ == "__main__":
    main()
