"""Small vector pictures for the holiday themes' gallery thumbnails (drawn with Pillow, no files needed).

    motif(theme_id, pal) -> RGBA image, `size` pixels square, `pal` is the theme's 16 own colours as (r, g, b) tuples.
"""
import math

from PIL import Image, ImageDraw


def _c(pal, slot, a=255):
    r, g, b = pal[slot]
    return (r, g, b, a)


def _heart(d, u, cx, cy, s, fill):
    """A heart: two circles and a triangle; s is half the width."""
    r = s * 0.5
    d.ellipse([(cx - s * 0.5 - r) * u, (cy - s * 0.35 - r) * u, (cx - s * 0.5 + r) * u, (cy - s * 0.35 + r) * u], fill=fill)
    d.ellipse([(cx + s * 0.5 - r) * u, (cy - s * 0.35 - r) * u, (cx + s * 0.5 + r) * u, (cy - s * 0.35 + r) * u], fill=fill)
    d.polygon([((cx - s) * u, (cy - s * 0.12) * u), ((cx + s) * u, (cy - s * 0.12) * u), (cx * u, (cy + s * 1.15) * u)], fill=fill)


def _star(d, u, cx, cy, r_out, r_in, fill, rot=-90):
    pts = []
    for i in range(10):
        r = r_out if i % 2 == 0 else r_in
        a = math.radians(rot + i * 36)
        pts.append(((cx + r * math.cos(a)) * u, (cy + r * math.sin(a)) * u))
    d.polygon(pts, fill=fill)


def _spark(d, u, cx, cy, r, fill):
    """A four-point sparkle."""
    pts = [(cx, cy - r), (cx + r * 0.22, cy - r * 0.22), (cx + r, cy), (cx + r * 0.22, cy + r * 0.22), (cx, cy + r), (cx - r * 0.22, cy + r * 0.22),
           (cx - r, cy), (cx - r * 0.22, cy - r * 0.22)]
    d.polygon([(x * u, y * u) for x, y in pts], fill=fill)


def _canvas(size, ss=8):
    n = size * ss
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im), n / 100.0


def newyear(pal, size):
    im, d, u = _canvas(size)
    gold, silver, face = _c(pal, 8), _c(pal, 15), _c(pal, 2)
    d.ellipse([14 * u, 14 * u, 86 * u, 86 * u], fill=face, outline=gold, width=int(4.5 * u))
    for i in range(12):                                  # ticks
        a = math.radians(i * 30 - 90)
        r0, r1 = (35, 41) if i % 3 == 0 else (38, 41)
        d.line([((50 + r0 * math.cos(a)) * u, (50 + r0 * math.sin(a)) * u), ((50 + r1 * math.cos(a)) * u, (50 + r1 * math.sin(a)) * u)], fill=silver, width=int(2.4 * u))
    d.line([(50 * u, 50 * u), (50 * u, 24 * u)], fill=gold, width=int(4 * u))          # midnight: both hands up
    d.line([(50 * u, 50 * u), (54 * u, 28 * u)], fill=silver, width=int(3 * u))
    d.ellipse([46 * u, 46 * u, 54 * u, 54 * u], fill=gold)
    for (x, y, r, k) in ((10, 12, 8, 13), (90, 16, 7, 11), (88, 84, 8, 8), (12, 86, 6, 6)):
        _spark(d, u, x, y, r, _c(pal, k))
    return im.resize((size, size), Image.LANCZOS)


def valentine(pal, size):
    im, d, u = _canvas(size)
    _heart(d, u, 50, 38, 34, _c(pal, 4))
    _heart(d, u, 46, 30, 12, _c(pal, 13, 150))                                          # a shine
    _spark(d, u, 86, 18, 8, _c(pal, 8))
    _spark(d, u, 14, 78, 6, _c(pal, 13))
    return im.resize((size, size), Image.LANCZOS)


def stpatrick(pal, size):
    im, d, u = _canvas(size)
    green = _c(pal, 3)
    d.line([(50 * u, 54 * u), (50 * u, 66 * u), (57 * u, 90 * u)], fill=_c(pal, 9), width=int(4 * u), joint="curve")    # the stem
    leaf = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(leaf)
    _heart(ld, u, 50, 27, 21, green)                     # one heart whose point is the middle of the shamrock ...
    _heart(ld, u, 48, 22, 7, _c(pal, 9, 140))
    for ang in (0, 120, 240):                            # ... turned around it
        im.alpha_composite(leaf.rotate(ang, center=(50 * u, 52 * u), resample=Image.BICUBIC))
    d = ImageDraw.Draw(im)
    _spark(d, u, 86, 16, 8, _c(pal, 8))
    return im.resize((size, size), Image.LANCZOS)


def easter(pal, size):
    im, d, u = _canvas(size)
    body = Image.new("RGBA", im.size, (0, 0, 0, 0))
    bd = ImageDraw.Draw(body)
    bd.ellipse([22 * u, 8 * u, 78 * u, 92 * u], fill=_c(pal, 6, 255))
    bands = Image.new("RGBA", im.size, (0, 0, 0, 0))
    b = ImageDraw.Draw(bands)
    for k, (y0, col) in enumerate(((30, 13), (46, 8), (62, 3), (76, 11))):
        pts = []
        for i in range(0, 9):
            pts.append(((18 + i * 8.5) * u, (y0 + (5 if i % 2 else -5)) * u))
        b.line(pts, fill=_c(pal, col), width=int(6 * u), joint="curve")
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).ellipse([22 * u, 8 * u, 78 * u, 92 * u], fill=255)
    bands.putalpha(Image.composite(bands.getchannel("A"), Image.new("L", im.size, 0), mask))
    im.alpha_composite(body)
    im.alpha_composite(bands)
    d = ImageDraw.Draw(im)
    for (x, y, k) in ((38, 24, 0), (60, 40, 0), (42, 82, 0)):
        d.ellipse([(x - 2) * u, (y - 2) * u, (x + 2) * u, (y + 2) * u], fill=_c(pal, k, 220))
    return im.resize((size, size), Image.LANCZOS)


def memorial(pal, size):
    im, d, u = _canvas(size)
    red = _c(pal, 4)
    for i in range(5):                                    # a poppy
        a = math.radians(i * 72 - 90)
        cx, cy = 50 + 19 * math.cos(a), 50 + 19 * math.sin(a)
        d.ellipse([(cx - 20) * u, (cy - 20) * u, (cx + 20) * u, (cy + 20) * u], fill=red)
    d.ellipse([36 * u, 36 * u, 64 * u, 64 * u], fill=_c(pal, 5))
    d.ellipse([41 * u, 41 * u, 59 * u, 59 * u], fill=_c(pal, 1))
    for i in range(10):
        a = math.radians(i * 36)
        x, y = 50 + 13 * math.cos(a), 50 + 13 * math.sin(a)
        d.ellipse([(x - 1.6) * u, (y - 1.6) * u, (x + 1.6) * u, (y + 1.6) * u], fill=_c(pal, 1))
    return im.resize((size, size), Image.LANCZOS)


def juneteenth(pal, size):
    im, d, u = _canvas(size)
    for i in range(24):                                   # a burst of dots around the star
        a = math.radians(i * 15)
        r = 42 if i % 2 == 0 else 36
        x, y = 50 + r * math.cos(a), 50 + r * math.sin(a)
        col = (4, 8, 3)[i % 3]
        d.ellipse([(x - 3) * u, (y - 3) * u, (x + 3) * u, (y + 3) * u], fill=_c(pal, col))
    _star(d, u, 50, 52, 27, 11, _c(pal, 0))
    return im.resize((size, size), Image.LANCZOS)


def july4(pal, size):
    im, d, u = _canvas(size)
    cols = (4, 0, 12)
    for i in range(16):                                   # a firework
        a = math.radians(i * 22.5)
        r0, r1 = 12, (44 if i % 2 == 0 else 34)
        col = _c(pal, cols[i % 3])
        d.line([((50 + r0 * math.cos(a)) * u, (50 + r0 * math.sin(a)) * u), ((50 + (r1 - 5) * math.cos(a)) * u, (50 + (r1 - 5) * math.sin(a)) * u)], fill=col, width=int(3 * u))
        d.ellipse([(50 + r1 * math.cos(a) - 3.2) * u, (50 + r1 * math.sin(a) - 3.2) * u, (50 + r1 * math.cos(a) + 3.2) * u, (50 + r1 * math.sin(a) + 3.2) * u], fill=col)
    _star(d, u, 50, 51, 11, 4.6, _c(pal, 8))
    return im.resize((size, size), Image.LANCZOS)


def labor(pal, size):
    im, d, u = _canvas(size)
    orange = _c(pal, 7)
    for i in range(8):                                    # a gear
        a = math.radians(i * 45)
        cx, cy = 50 + 31 * math.cos(a), 50 + 31 * math.sin(a)
        pts = []
        for dx, dy in ((-7, -6), (7, -6), (7, 6), (-7, 6)):
            rx = dx * math.cos(a) - dy * math.sin(a)
            ry = dx * math.sin(a) + dy * math.cos(a)
            pts.append(((cx + rx) * u, (cy + ry) * u))
        d.polygon(pts, fill=orange)
    d.ellipse([22 * u, 22 * u, 78 * u, 78 * u], fill=orange)
    d.ellipse([38 * u, 38 * u, 62 * u, 62 * u], fill=_c(pal, 1))
    d.ellipse([44 * u, 44 * u, 56 * u, 56 * u], fill=_c(pal, 12))
    return im.resize((size, size), Image.LANCZOS)


def halloween(pal, size):
    im, d, u = _canvas(size)
    orange, dark = _c(pal, 7), _c(pal, 1)
    d.ellipse([8 * u, 24 * u, 52 * u, 90 * u], fill=_c(pal, 7))
    d.ellipse([48 * u, 24 * u, 92 * u, 90 * u], fill=_c(pal, 7))
    d.ellipse([22 * u, 20 * u, 78 * u, 94 * u], fill=orange)
    d.polygon([(46 * u, 26 * u), (54 * u, 26 * u), (58 * u, 10 * u), (47 * u, 12 * u)], fill=_c(pal, 3))      # stem
    d.polygon([(30 * u, 52 * u), (44 * u, 52 * u), (37 * u, 38 * u)], fill=dark)                              # eyes
    d.polygon([(56 * u, 52 * u), (70 * u, 52 * u), (63 * u, 38 * u)], fill=dark)
    pts = [(28, 66), (36, 62), (42, 70), (50, 62), (58, 70), (64, 62), (72, 66), (68, 80), (58, 76), (50, 84), (42, 76), (32, 80)]
    d.polygon([(x * u, y * u) for x, y in pts], fill=dark)
    return im.resize((size, size), Image.LANCZOS)


def thanksgiving(pal, size):
    im, d, u = _canvas(size)
    leaf = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(leaf)
    outline = []
    for i in range(0, 41):
        t = i / 40.0
        y = 10 + 74 * t
        w = 30 * (math.sin(math.pi * t) ** 0.75) * (1.0 + 0.18 * math.sin(t * math.pi * 7))
        outline.append((50 - w, y))
    for i in range(40, -1, -1):
        t = i / 40.0
        y = 10 + 74 * t
        w = 30 * (math.sin(math.pi * t) ** 0.75) * (1.0 + 0.18 * math.sin(t * math.pi * 7))
        outline.append((50 + w, y))
    ld.polygon([(x * u, y * u) for x, y in outline], fill=_c(pal, 7))
    ld.polygon([((50 + (x - 50) * 0.62) * u, (47 + (y - 47) * 0.7) * u) for x, y in outline], fill=_c(pal, 8, 190))
    ld.line([(50 * u, 16 * u), (50 * u, 92 * u)], fill=_c(pal, 5), width=int(3 * u))
    for y, dx in ((34, 15), (48, 20), (62, 15)):
        ld.line([(50 * u, (y + 6) * u), ((50 - dx) * u, (y - 4) * u)], fill=_c(pal, 5), width=int(2 * u))
        ld.line([(50 * u, (y + 6) * u), ((50 + dx) * u, (y - 4) * u)], fill=_c(pal, 5), width=int(2 * u))
    leaf = leaf.rotate(-18, center=(50 * u, 50 * u), resample=Image.BICUBIC)
    im.alpha_composite(leaf)
    return im.resize((size, size), Image.LANCZOS)


def hanukkah(pal, size):
    im, d, u = _canvas(size)
    gold, blue = _c(pal, 8), _c(pal, 12)
    w = int(3.4 * u)
    for r in (10, 20, 30, 40):                            # the arms: nested U shapes
        d.arc([(50 - r) * u, (62 - r) * u, (50 + r) * u, (62 + r) * u], 0, 180, fill=blue, width=w)
    d.line([(50 * u, 62 * u), (50 * u, 92 * u)], fill=blue, width=w)
    d.rectangle([34 * u, 90 * u, 66 * u, 95 * u], fill=blue)
    for x, top in ((10, 38), (20, 38), (30, 38), (40, 38), (50, 28), (60, 38), (70, 38), (80, 38), (90, 38)):
        d.line([(x * u, 62 * u), (x * u, (top + 4) * u)], fill=blue, width=w)
        d.rectangle([(x - 2.4) * u, top * u, (x + 2.4) * u, (top + 8) * u], fill=_c(pal, 15))
        d.ellipse([(x - 2.6) * u, (top - 8) * u, (x + 2.6) * u, (top + 1) * u], fill=gold)
    return im.resize((size, size), Image.LANCZOS)


def christmas(pal, size):
    im, d, u = _canvas(size)
    green = _c(pal, 3)
    d.rectangle([44 * u, 80 * u, 56 * u, 94 * u], fill=_c(pal, 5))
    for (top, bot, half) in ((22, 50, 22), (36, 66, 30), (50, 82, 38)):
        d.polygon([(50 * u, top * u), ((50 - half) * u, bot * u), ((50 + half) * u, bot * u)], fill=green)
    _star(d, u, 50, 14, 9, 4, _c(pal, 8))
    for (x, y, k) in ((42, 40, 4), (58, 58, 8), (36, 66, 8), (62, 74, 4), (50, 52, 13), (46, 76, 11)):
        d.ellipse([(x - 3.2) * u, (y - 3.2) * u, (x + 3.2) * u, (y + 3.2) * u], fill=_c(pal, k))
    return im.resize((size, size), Image.LANCZOS)


MOTIFS = {
    "h_newyear": newyear, "h_valentine": valentine, "h_stpatrick": stpatrick, "h_easter": easter, "h_memorial": memorial,
    "h_juneteenth": juneteenth, "h_july4": july4, "h_labor": labor, "h_halloween": halloween, "h_thanksgiving": thanksgiving,
    "h_hanukkah": hanukkah, "h_christmas": christmas,
}


def motif(theme_id, pal, size=44):
    f = MOTIFS.get(theme_id)
    return f(pal, size) if f else None
