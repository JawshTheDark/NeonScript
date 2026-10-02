#!/usr/bin/env python3
"""
Makes the small (16 px) and large (24 px) copies of every 32 px toolbar icon:

    python tools/make_icon_sizes.py

mIRC's /toolbar -z switch does not rescale PNG pictures, so NeonScript's "Icon size" setting (Customize Toolbar) picks the file
instead:  assets/s16/<same path>  and  assets/s24/<same path>  next to the original 32 px icons in assets/ and assets/icons_*/.
Run it again after tools/make_assets.py regenerates the icons.
"""
import glob
import os

from PIL import Image

PACK = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
ASSETS = os.path.join(PACK, "assets")
SIZES = (16, 24)


def main():
    made = 0
    sources = glob.glob(os.path.join(ASSETS, "*.png")) + glob.glob(os.path.join(ASSETS, "icons_*", "*.png"))
    for src in sources:
        im = Image.open(src)
        if im.size != (32, 32):
            continue                                    # banners, headers and the like are left alone
        rel = os.path.relpath(src, ASSETS)
        for s in SIZES:
            dst = os.path.join(ASSETS, "s%d" % s, rel)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            im.convert("RGBA").resize((s, s), Image.LANCZOS).save(dst, optimize=True)
            made += 1
    print("wrote %d icons into assets/s16 and assets/s24" % made)


if __name__ == "__main__":
    main()
