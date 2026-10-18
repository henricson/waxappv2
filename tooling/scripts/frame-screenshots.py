#!/usr/bin/env python3
"""Frame raw screenshots into App Store marketing slides.

    tooling/scripts/frame-screenshots.py [iphone|ipad ...]

Reads tooling/Marketing/raw/<device>/<locale>/<scene>.png (see
store-shots.py) and the copy in tooling/Marketing/captions/captions.json,
and writes App Store-sized slides to

    tooling/fastlane/screenshots/<locale>/<NN>_<device>_<scene>.png

ready for `fastlane ios screenshots`. Needs Pillow.
"""

import json
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[2]
CAPTIONS = ROOT / "tooling/Marketing/captions/captions.json"
RAW = ROOT / "tooling/Marketing/raw"
OUT = ROOT / "tooling/fastlane/screenshots"
ICON = ROOT / "tooling/Marketing/header/app-icon.png"
FONT = "/System/Library/Fonts/SFNS.ttf"

# App Store canvas per device class: 6.9" iPhone and 13" iPad.
CANVAS = {"iphone": (1320, 2868), "ipad": (2064, 2752)}

# Share of the canvas width the device occupies, and the screen's corner
# radius as a share of the screen width.
DEVICE = {
    "iphone": {"width": 0.80, "radius": 0.135, "bezel": 0.020},
    "ipad": {"width": 0.84, "radius": 0.030, "bezel": 0.014},
}

TOP = (14, 38, 78)
BOTTOM = (44, 104, 189)


def font(size, weight):
    f = ImageFont.truetype(FONT, size)
    f.set_variation_by_name(weight)
    return f


def gradient(size):
    w, h = size
    column = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / (h - 1)
        column.putpixel((0, y), tuple(int(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)))
    return column.resize((w, h))


def ridges(size):
    """Two faint mountain ranges across the lower half, echoing the ridge
    printed on the Pro by Swix packs."""
    w, h = size
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for top, alpha, profile in (
        (0.56, 26, [0.30, 0.10, 0.42, 0.00, 0.30, 0.05, 0.36]),
        (0.66, 34, [0.62, 0.40, 0.55, 0.22, 0.00, 0.34, 0.46, 0.18, 0.50]),
    ):
        depth = 0.10
        points = [(0, h)]
        for i, v in enumerate(profile):
            points.append((w * i / (len(profile) - 1), h * (top + v * depth)))
        points.append((w, h))
        draw.polygon(points, fill=(255, 255, 255, alpha))
    return layer


def wrap(draw, text, face, max_width):
    words, lines, line = text.split(), [], ""
    for word in words:
        candidate = f"{line} {word}".strip()
        if draw.textlength(candidate, font=face) <= max_width or not line:
            line = candidate
        else:
            lines.append(line)
            line = word
    lines.append(line)
    if len(lines) != 2:
        return lines

    # Two lines: split where the longer line is shortest, so a title never
    # ends with one orphaned word.
    best = None
    for i in range(1, len(words)):
        first, second = " ".join(words[:i]), " ".join(words[i:])
        widest = max(draw.textlength(first, font=face), draw.textlength(second, font=face))
        if widest <= max_width and (best is None or widest < best[0]):
            best = (widest, [first, second])
    return best[1] if best else lines


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def frame(device, raw_path, copy, shows_logo):
    w, h = CANVAS[device]
    spec = DEVICE[device]
    canvas = gradient((w, h)).convert("RGBA")
    canvas.alpha_composite(ridges((w, h)))
    draw = ImageDraw.Draw(canvas)

    y = int(h * 0.055)

    if shows_logo and ICON.exists():
        icon_size = int(w * 0.115)
        icon = Image.open(ICON).convert("RGBA").resize((icon_size, icon_size), Image.LANCZOS)
        icon.putalpha(rounded_mask(icon.size, int(icon_size * 0.2237)))
        word = font(int(w * 0.050), "Bold")
        word_width = draw.textlength("GetGrip", font=word)
        gap = int(w * 0.025)
        x = int((w - icon_size - gap - word_width) / 2)
        canvas.alpha_composite(icon, (x, y))
        draw.text(
            (x + icon_size + gap, y + icon_size / 2), "GetGrip", font=word,
            fill=(255, 255, 255), anchor="lm")
        y += icon_size + int(h * 0.028)

    headline = font(int(w * (0.074 if device == "iphone" else 0.058)), "Bold")
    for line in wrap(draw, copy["headline"], headline, w * 0.86):
        draw.text((w / 2, y), line, font=headline, fill=(255, 255, 255), anchor="ma")
        y += int(headline.size * 1.12)

    y += int(h * 0.010)
    subhead = font(int(w * (0.040 if device == "iphone" else 0.030)), "Regular")
    for line in wrap(draw, copy["subhead"], subhead, w * 0.82):
        draw.text((w / 2, y), line, font=subhead, fill=(255, 255, 255, 214), anchor="ma")
        y += int(subhead.size * 1.25)

    # Device: screen in a dark bezel, standing on a soft shadow, running off
    # the bottom of the slide.
    shot = Image.open(raw_path).convert("RGBA")
    screen_w = int(w * spec["width"])
    screen_h = int(shot.height * screen_w / shot.width)
    shot = shot.resize((screen_w, screen_h), Image.LANCZOS)
    radius = int(screen_w * spec["radius"])
    shot.putalpha(rounded_mask(shot.size, radius))

    bezel = int(w * spec["bezel"])
    body_size = (screen_w + 2 * bezel, screen_h + 2 * bezel)
    top = y + int(h * 0.035)
    left = (w - body_size[0]) // 2

    shadow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (left, top + int(h * 0.012), left + body_size[0], top + body_size[1]),
        radius=radius + bezel, fill=(0, 0, 0, 110))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(int(w * 0.03))))

    body = Image.new("RGBA", body_size, (0, 0, 0, 0))
    ImageDraw.Draw(body).rounded_rectangle(
        (0, 0, body_size[0] - 1, body_size[1] - 1), radius=radius + bezel, fill=(16, 17, 21, 255))
    ImageDraw.Draw(body).rounded_rectangle(
        (1, 1, body_size[0] - 2, body_size[1] - 2), radius=radius + bezel,
        outline=(92, 96, 104, 255), width=max(2, bezel // 6))
    body.alpha_composite(shot, (bezel, bezel))
    canvas.alpha_composite(body, (left, top))

    return canvas.convert("RGB")


def main():
    devices = sys.argv[1:] or list(CANVAS)
    slides = json.loads(CAPTIONS.read_text())["slides"]

    for device in devices:
        for locale_dir in sorted((RAW / device).glob("*")):
            locale = locale_dir.name
            out_dir = OUT / locale
            out_dir.mkdir(parents=True, exist_ok=True)
            for index, slide in enumerate(slides, start=1):
                raw = locale_dir / f"{slide['scene']}.png"
                copy = slide.get(locale) or slide["en-US"]
                if not raw.exists():
                    continue
                image = frame(device, raw, copy, slide.get("showsLogo", False))
                target = out_dir / f"{index:02d}_{device}_{slide['scene']}.png"
                image.save(target, optimize=True)
                print(f"{target.relative_to(ROOT)}  {image.size[0]}x{image.size[1]}")


if __name__ == "__main__":
    main()
