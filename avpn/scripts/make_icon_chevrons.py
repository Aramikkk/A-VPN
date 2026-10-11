"""Generate A-VPN icon assets: two chevrons pointing up (near-black, acid green) on white.

Usage: python make_icon.py <hiddify_repo_dir> <preview_png>
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw

INK = "#111113"
ACCENT = "#9EFF1F"   # acid green
BG = "#FFFFFF"

# The mark in a 512x512 box: two chevrons, centred. Each is a polyline drawn with a round-capped stroke.
STROKE = 58
LOWER = [(132, 363), (256, 267), (380, 363)]
UPPER = [(132, 245), (256, 149), (380, 245)]


def _path(points):
    (x0, y0), (x1, y1), (x2, y2) = points
    return f"M{x0},{y0} L{x1},{y1} L{x2},{y2}"


def _chevron_mask(size, scale, points):
    ss = 4
    big = size * ss
    k = big * scale / 512
    off = big * (1 - scale) / 2
    pts = [(off + x * k, off + y * k) for x, y in points]
    w = STROKE * k
    m = Image.new("L", (big, big), 0)
    d = ImageDraw.Draw(m)
    d.line(pts, fill=255, width=round(w), joint="curve")
    for x, y in (pts[0], pts[-1]):  # round caps
        d.ellipse((x - w / 2, y - w / 2, x + w / 2, y + w / 2), fill=255)
    return m.resize((size, size), Image.LANCZOS)


def render_mark(size, scale, lower=INK, upper=ACCENT):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    img.paste(Image.new("RGBA", (size, size), lower), (0, 0), _chevron_mask(size, scale, LOWER))
    img.paste(Image.new("RGBA", (size, size), upper), (0, 0), _chevron_mask(size, scale, UPPER))
    return img


def render_launcher(size, round_=False, mark_scale=0.84):
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
    img.paste(Image.new("RGBA", (size, size), BG), (0, 0), shape)
    img.alpha_composite(render_mark(size, mark_scale))
    return img


def vector_mark(viewport, lower, upper):
    """Adaptive-icon foreground: the mark inside the 66dp safe zone of a 108dp canvas."""
    off = (viewport - 512) / 2
    paths = "".join(
        f'''
    <path android:pathData="{_path(points)}" android:strokeColor="{color}" android:strokeWidth="{STROKE}"
        android:strokeLineCap="round" android:strokeLineJoin="round"/>''' for points, color in ((LOWER, lower), (UPPER, upper)))
    return f'''<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="{viewport}"
    android:viewportHeight="{viewport}">
  <group android:translateX="{off}" android:translateY="{off}">{paths}
  </group>
</vector>
'''


def main(repo, preview):
    repo = Path(repo)
    res = repo / "android/app/src/main/res"

    # In-app logo: white rounded square with the mark.
    strokes = "".join(
        f'<path d="{_path(points)}" stroke="{color}" stroke-width="{STROKE}" stroke-linecap="round" '
        f'stroke-linejoin="round" fill="none"/>' for points, color in ((LOWER, INK), (UPPER, ACCENT)))
    (repo / "assets/images/logo.svg").write_text(
        '<svg width="64" height="64" viewBox="0 0 512 512" fill="none" xmlns="http://www.w3.org/2000/svg">\n'
        f'<rect width="512" height="512" rx="134" fill="{BG}"/>\n'
        f'<g transform="translate(41 41) scale(0.84)">{strokes}</g>\n</svg>\n',
        encoding="utf-8")

    # Adaptive icon: white background, the mark as foreground.
    (res / "drawable/ic_launcher_gradient.xml").unlink(missing_ok=True)
    for name in ("ic_launcher_background", "ic_banner_background"):
        (res / f"values/{name}.xml").write_text(
            f'<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="{name}">{BG}</color>\n</resources>\n',
            encoding="utf-8")
    (res / "drawable/ic_launcher_foreground.xml").write_text(vector_mark(680, INK, ACCENT), encoding="utf-8")
    (res / "drawable/ic_banner_foreground.xml").write_text(vector_mark(680, INK, ACCENT), encoding="utf-8")
    # the Android 12 splash sits on the system's dark or light background: white-and-green reads on both
    (res / "drawable/android12splash.xml").write_text(vector_mark(680, "#FFFFFF", ACCENT), encoding="utf-8")
    for name in ("ic_launcher", "ic_launcher_round", "ic_banner"):
        bg = "ic_banner_background" if name == "ic_banner" else "ic_launcher_background"
        fg = "ic_banner_foreground" if name == "ic_banner" else "ic_launcher_foreground"
        (res / f"mipmap-anydpi-v26/{name}.xml").write_text(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            f'    <background android:drawable="@color/{bg}"/>\n'
            f'    <foreground android:drawable="@drawable/{fg}"/>\n'
            '</adaptive-icon>\n', encoding="utf-8")

    # Legacy launcher icons.
    for folder, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        render_launcher(px).save(res / f"mipmap-{folder}/ic_launcher.webp", "WEBP", lossless=True)
        render_launcher(px, round_=True, mark_scale=0.74).save(
            res / f"mipmap-{folder}/ic_launcher_round.webp", "WEBP", lossless=True)

    # TV banner.
    banner = Image.new("RGBA", (320, 180), (0, 0, 0, 255))
    banner.alpha_composite(render_launcher(150), (85, 15))
    banner.save(res / "mipmap-xhdpi/ic_banner.png")

    # Notification icon: white silhouette of both chevrons.
    render_mark(24, 0.98, "#FFFFFF", "#FFFFFF").save(res / "drawable-mdpi/ic_stat_logo.png")
    render_mark(36, 0.98, "#FFFFFF", "#FFFFFF").save(res / "drawable-hdpi/ic_stat_logo.png")

    # Pre-Android-12 splash image.
    render_launcher(216).save(res / "drawable-xxxhdpi/splash.png")

    # Preview on OLED black.
    prev = Image.new("RGBA", (760, 300), (0, 0, 0, 255))
    prev.alpha_composite(render_launcher(256), (30, 22))
    prev.alpha_composite(render_launcher(160, round_=True, mark_scale=0.74), (330, 70))
    prev.alpha_composite(render_launcher(96), (530, 102))
    prev.alpha_composite(render_launcher(48), (670, 126))
    prev.alpha_composite(render_mark(48, 0.98, "#FFFFFF", "#FFFFFF"), (690, 30))
    prev.save(preview)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
