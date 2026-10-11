"""Renders the Auto Spend app icon from the design tokens.

Run with Pillow installed:  python3 tool/make_icon.py
Outputs to assets/icon/: icon.png (legacy, full bleed), foreground.png +
background.png (Android adaptive), monochrome.png (Android 13 themed).
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "icon"
FONT = ROOT / "assets" / "fonts" / "PlusJakartaSans-Bold.ttf"

SIZE = 1024
ACCENT = (0xDE, 0x66, 0x45)       # tokens: accent
ACCENT_DEEP = (0xC2, 0x4C, 0x2C)  # tokens: accentDeep
INK = (0x11, 0x11, 0x11)
WHITE = (255, 255, 255)

# Adaptive icons are masked to ~66% of the canvas; keep the mark inside it.
COIN = 0.42        # coin diameter as share of canvas
HALO = 0.53        # halo ring diameter


def background() -> Image.Image:
    """Deep orange lit from the top-right, with the review card's arcs."""
    img = Image.new("RGB", (SIZE, SIZE), ACCENT_DEEP)
    px = img.load()
    cx, cy, r = SIZE, 0, SIZE * 1.35
    for y in range(SIZE):
        for x in range(SIZE):
            t = min(1.0, math.hypot(x - cx, y - cy) / r)
            px[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(ACCENT, ACCENT_DEEP))

    arcs = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(arcs)
    for k, radius in enumerate(range(260, 1100, 150)):
        d.ellipse(
            (SIZE - radius, -radius, SIZE + radius, radius),
            outline=(255, 255, 255, 40 - k * 4),
            width=6,
        )
    img.paste(arcs, (0, 0), arcs)
    return img


def mark(mono: bool = False) -> Image.Image:
    """White coin with an ink ₹, inside a soft halo — the app's accent orb."""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    c = SIZE / 2

    if not mono:
        halo = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        hr = SIZE * HALO / 2
        ImageDraw.Draw(halo).ellipse((c - hr, c - hr, c + hr, c + hr), fill=(255, 255, 255, 46))
        img = Image.alpha_composite(img, halo)

        shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        sr = SIZE * COIN / 2
        ImageDraw.Draw(shadow).ellipse((c - sr, c - sr + 18, c + sr, c + sr + 18), fill=(80, 20, 5, 90))
        img = Image.alpha_composite(img, shadow.filter(ImageFilter.GaussianBlur(22)))

    r = SIZE * COIN / 2
    coin = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(coin).ellipse((c - r, c - r, c + r, c + r), fill=WHITE + (255,))

    # ₹ optically centred on the coin (by its ink box, not the em box).
    font = ImageFont.truetype(str(FONT), int(SIZE * 0.29))
    glyph = Image.new("L", (SIZE, SIZE), 0)
    gd = ImageDraw.Draw(glyph)
    l, t, rr, b = gd.textbbox((0, 0), "₹", font=font)
    gd.text((c - (l + rr) / 2 + SIZE * 0.008, c - (t + b) / 2), "₹", font=font, fill=255)

    if mono:
        # Themed icon: coin silhouette with the ₹ cut out.
        alpha = coin.split()[3]
        alpha = Image.composite(Image.new("L", (SIZE, SIZE), 0), alpha, glyph)
        out = Image.new("RGBA", (SIZE, SIZE), WHITE + (0,))
        out.putalpha(alpha)
        return out

    ink = Image.new("RGBA", (SIZE, SIZE), INK + (255,))
    coin.paste(ink, (0, 0), glyph)
    return Image.alpha_composite(img, coin)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    bg = background()
    fg = mark()
    bg.save(OUT / "background.png")
    fg.save(OUT / "foreground.png")
    mark(mono=True).save(OUT / "monochrome.png")
    full = bg.convert("RGBA")
    full = Image.alpha_composite(full, fg)
    full.convert("RGB").save(OUT / "icon.png")
    # Preview of how launchers will show it (circle mask, small sizes).
    # Launchers show the middle 72/108 of an adaptive icon through a mask.
    inset = SIZE * 18 // 108
    shown = full.crop((inset, inset, SIZE - inset, SIZE - inset)).resize((SIZE, SIZE), Image.LANCZOS)
    preview = Image.new("RGBA", (SIZE * 2 + 60, SIZE), (237, 237, 237, 255))
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, SIZE, SIZE), fill=255)
    preview.paste(shown, (0, 0), mask)
    for i, s in enumerate([192, 96, 48]):
        small = shown.resize((s, s), Image.LANCZOS)
        m = mask.resize((s, s), Image.LANCZOS)
        preview.paste(small, (SIZE + 60 + i * 230, 200), m)
    preview.save(OUT.parent.parent / "build" / "icon-preview.png")
    print("wrote", sorted(p.name for p in OUT.iterdir()))


if __name__ == "__main__":
    main()
