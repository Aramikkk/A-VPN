"""Generate A-VPN icon assets: a pixel letter A (white, its top pixel orange) on near-black.

Concept 12 of the 30 in C:\\dev\\A-VPN\\logo-concepts, in the orange of the Cyber theme. The earlier chevron icon
is make_icon_chevrons.py.
Usage: python make_icon.py <hiddify repo dir> <preview png>
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

INK = "#111113"      # the tile
PIXEL = "#FFFFFF"    # the letter
ACCENT = "#FF8F00"   # its top pixel: the Cyber theme's orange

# the letter on a 5x5 grid
GRID = ["..#..", ".#.#.", "#...#", "#####", "#...#"]
CELL, GAP = 72, 10                       # in a 512 box: 5*72 + 4*10 = 400
OFFSET = (512 - (5 * CELL + 4 * GAP)) / 2
RADIUS = 10


def cells():
    """(x, y, is_top) of every lit cell, in the 512 box."""
    for r, row in enumerate(GRID):
        for c, ch in enumerate(row):
            if ch == "#":
                yield OFFSET + c * (CELL + GAP), OFFSET + r * (CELL + GAP), r == 0


def render_mark(size, scale, pixel=PIXEL, accent=ACCENT):
    ss = 4
    big = size * ss
    k = big * scale / 512
    off = big * (1 - scale) / 2
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for x, y, top in cells():
        x0, y0 = off + x * k, off + y * k
        d.rounded_rectangle((x0, y0, x0 + CELL * k, y0 + CELL * k), radius=RADIUS * k, fill=accent if top else pixel)
    return img.resize((size, size), Image.LANCZOS)


def render_launcher(size, round_=False, mark_scale=0.66):
    ss = 4
    big = size * ss
    shape = Image.new("L", (big, big), 0)
    d = ImageDraw.Draw(shape)
    if round_:
        d.ellipse((0, 0, big - 1, big - 1), fill=255)
    else:
        d.rounded_rectangle((0, 0, big - 1, big - 1), radius=big * 0.26, fill=255)
    shape = shape.resize((size, size), Image.LANCZOS)
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    img.paste(Image.new("RGBA", (size, size), INK), (0, 0), shape)
    img.alpha_composite(render_mark(size, mark_scale))
    return img


def svg_cells(pixel, accent):
    return "".join(
        f'<rect x="{x:.1f}" y="{y:.1f}" width="{CELL}" height="{CELL}" rx="{RADIUS}" fill="{accent if top else pixel}"/>'
        for x, y, top in cells())


def vector_mark(viewport, pixel, accent, scale=0.62):
    """Adaptive-icon foreground: the letter inside the 66dp safe zone of a 108dp canvas."""
    k = viewport / 512 * scale
    shift = (viewport - 512 * k) / 2

    def rect(x, y, top):
        x0, y0, s, r = shift + x * k, shift + y * k, CELL * k, RADIUS * k
        e = s - 2 * r
        path = (f"M{x0 + r:.1f},{y0:.1f} h{e:.1f} a{r:.1f},{r:.1f} 0 0 1 {r:.1f},{r:.1f} v{e:.1f} "
                f"a{r:.1f},{r:.1f} 0 0 1 -{r:.1f},{r:.1f} h-{e:.1f} a{r:.1f},{r:.1f} 0 0 1 -{r:.1f},-{r:.1f} "
                f"v-{e:.1f} a{r:.1f},{r:.1f} 0 0 1 {r:.1f},-{r:.1f} z")
        return f'\n    <path android:fillColor="{accent if top else pixel}" android:pathData="{path}"/>'

    paths = "".join(rect(*c) for c in cells())
    return f'''<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="{viewport}"
    android:viewportHeight="{viewport}">{paths}
</vector>
'''


def save_ico(path, images):
    images[-1].save(path, sizes=[im.size for im in images], append_images=images[:-1])


def main(repo, preview):
    repo = Path(repo)
    res = repo / "android/app/src/main/res"

    # in-app logo: the dark rounded tile with the letter
    (repo / "assets/images/logo.svg").write_text(
        '<svg width="64" height="64" viewBox="0 0 512 512" fill="none" xmlns="http://www.w3.org/2000/svg">\n'
        f'<rect width="512" height="512" rx="134" fill="{INK}"/>\n'
        f'<g transform="translate(87 87) scale(0.66)">{svg_cells(PIXEL, ACCENT)}</g>\n</svg>\n',
        encoding="utf-8")

    # adaptive icon: the dark tile as background, the letter as foreground
    for name in ("ic_launcher_background", "ic_banner_background"):
        (res / f"values/{name}.xml").write_text(
            f'<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="{name}">{INK}</color>\n</resources>\n',
            encoding="utf-8")
    (res / "drawable/ic_launcher_foreground.xml").write_text(vector_mark(680, PIXEL, ACCENT), encoding="utf-8")
    (res / "drawable/ic_banner_foreground.xml").write_text(vector_mark(680, PIXEL, ACCENT), encoding="utf-8")
    # the Android 12 splash sits on a light background: a dark letter with the orange top
    (res / "drawable/android12splash.xml").write_text(vector_mark(680, INK, ACCENT), encoding="utf-8")

    # legacy launcher icons
    for folder, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        render_launcher(px).save(res / f"mipmap-{folder}/ic_launcher.webp", "WEBP", lossless=True)
        render_launcher(px, round_=True, mark_scale=0.56).save(
            res / f"mipmap-{folder}/ic_launcher_round.webp", "WEBP", lossless=True)

    banner = Image.new("RGBA", (320, 180), (0, 0, 0, 255))
    banner.alpha_composite(render_launcher(150), (85, 15))
    banner.save(res / "mipmap-xhdpi/ic_banner.png")

    # notification icon: a white silhouette of the letter
    render_mark(24, 0.98, "#FFFFFF", "#FFFFFF").save(res / "drawable-mdpi/ic_stat_logo.png")
    render_mark(36, 0.98, "#FFFFFF", "#FFFFFF").save(res / "drawable-hdpi/ic_stat_logo.png")

    render_launcher(216).save(res / "drawable-xxxhdpi/splash.png")

    # Windows: the app icon and the tray icons
    save_ico(repo / "windows/runner/resources/app_icon.ico", [render_launcher(s) for s in [16, 20, 24, 32, 40, 48, 64, 128, 256]])
    tray = [16, 20, 24, 32, 48, 64]
    for name, pixel, accent in [("tray_icon", "#FFFFFF", ACCENT), ("tray_icon_dark", INK, ACCENT),
                                ("tray_icon_connected", ACCENT, ACCENT), ("tray_icon_disconnected", "#8A8A8E", "#8A8A8E")]:
        save_ico(repo / f"assets/images/{name}.ico", [render_mark(s, 0.98, pixel, accent) for s in tray])
        render_mark(64, 0.98, pixel, accent).save(repo / f"assets/images/{name}.png")

    # preview: launcher sizes on black, the bare letter on white
    prev = Image.new("RGBA", (900, 300), (0, 0, 0, 255))
    prev.alpha_composite(render_launcher(256), (20, 22))
    prev.alpha_composite(render_launcher(160, round_=True, mark_scale=0.56), (300, 70))
    prev.alpha_composite(render_launcher(96), (490, 102))
    prev.alpha_composite(render_launcher(48), (610, 126))
    light = Image.new("RGBA", (220, 300), (255, 255, 255, 255))
    light.alpha_composite(render_mark(120, 0.98, INK, ACCENT), (50, 90))
    prev.alpha_composite(light, (680, 0))
    prev.save(preview)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
