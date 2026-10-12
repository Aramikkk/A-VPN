"""Generate A-VPN icon assets: a white A whose lower right leg is red, on near-black.

Drawn after the user's own picture (the Mono style). Earlier icons: make_icon_pixel.py (pixel A), make_icon_chevrons.py.
Usage: python make_icon.py <hiddify repo dir> <preview png>
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

INK = "#111111"      # the tile
MAIN = "#F5F5F5"     # the letter
RED = "#EE4245"      # the lower right leg
TILE = INK


def _fit(points):
    """The user's drawing (a 1254 px square) moved into the 512 box, centred, 440 wide."""
    k = 440 / 812
    return [((x - 624) * k + 256, (y - 614.5) * k + 256) for x, y in points]


# the letter: an A with a crossbar that juts out to the right, its lower right leg cut off in red
A = _fit([(626, 277), (860, 666), (706, 666), (626, 527), (516, 720), (662, 720), (726, 838), (452, 840),
          (388, 952), (218, 952)])
WEDGE = _fit([(706, 666), (860, 666), (1030, 952), (860, 952)])


def render_mark(size, scale, ink=MAIN, red=RED):
    ss = 4
    big = size * ss
    k = big * scale / 512
    off = big * (1 - scale) / 2
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(off + x * k, off + y * k) for x, y in A], fill=ink)
    d.polygon([(off + x * k, off + y * k) for x, y in WEDGE], fill=red)
    return img.resize((size, size), Image.LANCZOS)


def render_launcher(size, round_=False, mark_scale=0.66, tile=TILE):
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
    img.paste(Image.new("RGBA", (size, size), tile), (0, 0), shape)
    img.alpha_composite(render_mark(size, mark_scale))
    return img


def _points(poly, k=1.0, shift=0.0):
    return " ".join(f"{shift + x * k:.1f},{shift + y * k:.1f}" for x, y in poly)


def _path(poly, k, shift):
    first, *rest = poly
    return f"M{shift + first[0] * k:.1f},{shift + first[1] * k:.1f} " + " ".join(
        f"L{shift + x * k:.1f},{shift + y * k:.1f}" for x, y in rest) + " Z"


def vector_mark(viewport, ink, red, scale=0.62):
    """Adaptive-icon foreground: the emblem inside the 66dp safe zone of a 108dp canvas."""
    k = viewport / 512 * scale
    shift = (viewport - 512 * k) / 2
    return f'''<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="{viewport}"
    android:viewportHeight="{viewport}">
    <path android:fillColor="{ink}" android:pathData="{_path(A, k, shift)}"/>
    <path android:fillColor="{red}" android:pathData="{_path(WEDGE, k, shift)}"/>
</vector>
'''


def save_ico(path, images):
    images[-1].save(path, sizes=[im.size for im in images], append_images=images[:-1])


def main(repo, preview):
    repo = Path(repo)
    res = repo / "android/app/src/main/res"

    # in-app logo: the white rounded tile with the emblem
    (repo / "assets/images/logo.svg").write_text(
        '<svg width="64" height="64" viewBox="0 0 512 512" fill="none" xmlns="http://www.w3.org/2000/svg">\n'
        f'<rect width="512" height="512" rx="134" fill="{TILE}"/>\n'
        f'<g transform="translate(97 97) scale(0.62)"><polygon points="{_points(A)}" fill="{MAIN}"/>'
        f'<polygon points="{_points(WEDGE)}" fill="{RED}"/></g>\n</svg>\n',
        encoding="utf-8")

    for name in ("ic_launcher_background", "ic_banner_background"):
        (res / f"values/{name}.xml").write_text(
            f'<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="{name}">{TILE}</color>\n</resources>\n',
            encoding="utf-8")
    (res / "drawable/ic_launcher_foreground.xml").write_text(vector_mark(680, MAIN, RED), encoding="utf-8")
    (res / "drawable/ic_banner_foreground.xml").write_text(vector_mark(680, MAIN, RED), encoding="utf-8")
    # the Android 12 splash sits on a light background
    (res / "drawable/android12splash.xml").write_text(vector_mark(680, INK, RED), encoding="utf-8")

    for folder, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        render_launcher(px).save(res / f"mipmap-{folder}/ic_launcher.webp", "WEBP", lossless=True)
        render_launcher(px, round_=True, mark_scale=0.54).save(
            res / f"mipmap-{folder}/ic_launcher_round.webp", "WEBP", lossless=True)

    banner = Image.new("RGBA", (320, 180), (0, 0, 0, 255))
    banner.alpha_composite(render_launcher(150), (85, 15))
    banner.save(res / "mipmap-xhdpi/ic_banner.png")

    # notification icon: a white silhouette of the whole letter
    for size, folder in ((24, "drawable-mdpi"), (36, "drawable-hdpi")):
        render_mark(size, 0.98, "#FFFFFF", "#FFFFFF").save(res / f"{folder}/ic_stat_logo.png")

    render_launcher(216).save(res / "drawable-xxxhdpi/splash.png")

    # Windows: the app icon and the tray icons
    save_ico(repo / "windows/runner/resources/app_icon.ico", [render_launcher(s) for s in [16, 20, 24, 32, 40, 48, 64, 128, 256]])
    tray = [16, 20, 24, 32, 48, 64]
    for name, ink, red in [("tray_icon", "#FFFFFF", "#FFFFFF"), ("tray_icon_dark", INK, RED),
                           ("tray_icon_connected", "#FFFFFF", RED), ("tray_icon_disconnected", "#8A8A8E", "#8A8A8E")]:
        save_ico(repo / f"assets/images/{name}.ico", [render_mark(s, 0.98, ink, red) for s in tray])
        render_mark(64, 0.98, ink, red).save(repo / f"assets/images/{name}.png")

    # preview: launcher sizes on graphite, the bare emblem on white and on black
    prev = Image.new("RGBA", (980, 300), (60, 60, 64, 255))
    prev.alpha_composite(render_launcher(256), (20, 22))
    prev.alpha_composite(render_launcher(160, round_=True, mark_scale=0.54), (300, 70))
    prev.alpha_composite(render_launcher(96), (490, 102))
    prev.alpha_composite(render_launcher(48), (610, 126))
    light = Image.new("RGBA", (150, 300), (255, 255, 255, 255))
    light.alpha_composite(render_mark(110, 0.98, INK, RED), (20, 95))
    prev.alpha_composite(light, (680, 0))
    dark = Image.new("RGBA", (150, 300), (14, 14, 14, 255))
    dark.alpha_composite(render_mark(110, 0.98, MAIN, RED), (20, 95))
    prev.alpha_composite(dark, (830, 0))
    prev.save(preview)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
