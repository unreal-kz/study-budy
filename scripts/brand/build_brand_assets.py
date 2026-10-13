#!/usr/bin/env python3
"""Generate the Study Buddy brand SVGs and render the PNGs the apps consume.

One geometry (two speech bubbles + three sparks, taken from the mockups in
``docs/concept/02-app-screens-wireframes.jpeg``) is emitted in several
palettes. SVGs go to ``design/brand/`` (not bundled with the app); PNGs are
rendered through headless Chrome, so there are no extra dependencies.

Usage::

    python3 scripts/brand/build_brand_assets.py            # SVG + PNG
    python3 scripts/brand/build_brand_assets.py --svg-only

``flutter_launcher_icons`` then turns the PNGs into the platform icon sets
(see ``flutter_launcher_icons.yaml`` and the README "Brand assets" section).
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SVG_DIR = ROOT / "design" / "brand"
PNG_DIR = SVG_DIR / "png"
CHROME = Path("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")

# Palette taken from lib/theme/app_theme.dart (AppColors).
PINE800 = "#1B3A33"
GREEN600 = "#3F9142"
CREAM50 = "#FCF3EF"
GOLD500 = "#E0A83E"

# --- Geometry, in "mark space" (the mark spans roughly x 18..639, y -23..624).
BACK_BUBBLE = (
    "M150,40 H290 A120,120 0 0 1 410,160 V220 A120,120 0 0 1 290,340 "
    "H165 L45,432 L90,340 H150 A120,120 0 0 1 30,220 V160 A120,120 0 0 1 150,40 Z"
)
FRONT_BUBBLE = (
    "M335,235 H445 A125,125 0 0 1 570,360 V400 A125,125 0 0 1 445,525 "
    "L520,612 L345,525 H335 A125,125 0 0 1 210,400 V360 A125,125 0 0 1 335,235 Z"
)
DOTS = ((316, 380), (390, 380), (464, 380))
DOT_RADIUS = 28
SPARKS = (
    ((508, 46), (508, -10)),
    ((551.8, 64.2), (591.4, 24.6)),
    ((570, 108), (626, 108)),
)
SPARK_WIDTH = 26
JOIN_WIDTH = 24  # stroke in the fill colour; rounds every corner and the tails
GAP = 26  # transparent gap the front bubble cuts out of the back bubble

# Visual centre of the mark (bubbles, sparks count half) and its height, used to place it.
MARK_CX, MARK_CY = 320.0, 300.5
MARK_H = 647.0


@dataclass(frozen=True)
class Palette:
    """Colours for one rendering of the mark.

    Attributes:
        bg: Background fill, or ``None`` for a transparent canvas.
        glow: Whether to add the soft white radial highlight over ``bg``.
        back: Fill of the back bubble.
        front: ``(top, bottom)`` stops of the front bubble gradient.
        dots: Fill of the three dots, or ``None`` to cut them out of the front bubble.
        sparks: Stroke colour of the sparks.
    """

    bg: str | None
    glow: bool
    back: str
    front: tuple[str, str]
    dots: str | None
    sparks: str


LIGHT = Palette(CREAM50, True, PINE800, ("#4AA24D", "#37833B"), CREAM50, GOLD500)
TRANSPARENT = Palette(None, False, PINE800, ("#4AA24D", "#37833B"), CREAM50, GOLD500)
DARK = Palette(None, False, "#F4EADF", ("#56B65B", "#3F9142"), CREAM50, GOLD500)
TINTED = Palette("#000000", False, "#A8A8A8", ("#FFFFFF", "#E6E6E6"), "#000000", "#8A8A8A")
MONO = Palette(None, False, "#000000", ("#000000", "#000000"), None, "#000000")


def _shape(d: str, fill: str, extra: str = "") -> str:
    return (
        f'<path d="{d}" fill="{fill}" stroke="{fill}" stroke-width="{JOIN_WIDTH}" '
        f'stroke-linejoin="round" {extra}/>'
    )


def mark_svg(p: Palette) -> str:
    """Return the ``<defs>`` and group that draw the mark in mark space."""
    cut = JOIN_WIDTH + 2 * GAP
    defs = [
        '<mask id="gap" maskUnits="userSpaceOnUse" x="-200" y="-200" width="1000" height="1000">'
        '<rect x="-200" y="-200" width="1000" height="1000" fill="#fff"/>'
        f'<path d="{FRONT_BUBBLE}" fill="#000" stroke="#000" stroke-width="{cut}" '
        'stroke-linejoin="round"/></mask>',
        f'<linearGradient id="front" x1="0" y1="0" x2="0" y2="1">'
        f'<stop offset="0" stop-color="{p.front[0]}"/>'
        f'<stop offset="1" stop-color="{p.front[1]}"/></linearGradient>',
    ]
    front_extra = ""
    if p.dots is None:
        circles = "".join(f'<circle cx="{x}" cy="{y}" r="{DOT_RADIUS}" fill="#000"/>' for x, y in DOTS)
        defs.append(
            '<mask id="holes" maskUnits="userSpaceOnUse" x="-200" y="-200" width="1000" height="1000">'
            f'<rect x="-200" y="-200" width="1000" height="1000" fill="#fff"/>{circles}</mask>'
        )
        front_extra = 'mask="url(#holes)"'
    parts = [
        f'<g mask="url(#gap)">{_shape(BACK_BUBBLE, p.back)}</g>',
        _shape(FRONT_BUBBLE, "url(#front)", front_extra),
    ]
    if p.dots is not None:
        parts.append(
            "".join(f'<circle cx="{x}" cy="{y}" r="{DOT_RADIUS}" fill="{p.dots}"/>' for x, y in DOTS)
        )
    for (x1, y1), (x2, y2) in SPARKS:
        parts.append(
            f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{p.sparks}" '
            f'stroke-width="{SPARK_WIDTH}" stroke-linecap="round"/>'
        )
    return f"<defs>{''.join(defs)}</defs>" + "".join(parts)


def _canvas(p: Palette, size: int, scale: float) -> str:
    """Return a ``size`` x ``size`` SVG with the mark centred at ``scale``."""
    tx = size / 2 - MARK_CX * scale
    ty = size / 2 - MARK_CY * scale
    bg = ""
    if p.bg is not None:
        bg = f'<rect width="{size}" height="{size}" fill="{p.bg}"/>'
        if p.glow:
            bg += (
                '<defs><radialGradient id="glow" cx="0.3" cy="0.22" r="0.85">'
                '<stop offset="0" stop-color="#fff" stop-opacity="0.8"/>'
                '<stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient></defs>'
                f'<rect width="{size}" height="{size}" fill="url(#glow)"/>'
            )
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" '
        f'viewBox="0 0 {size} {size}">{bg}'
        f'<g transform="translate({tx:.2f} {ty:.2f}) scale({scale})">{mark_svg(p)}</g></svg>\n'
    )


def _logo_mark_svg() -> str:
    """Square, tightly padded mark on a transparent canvas for in-app use."""
    side = MARK_H + 40
    x0, y0 = MARK_CX - side / 2, MARK_CY - side / 2
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{side:.0f}" height="{side:.0f}" '
        f'viewBox="{x0:.1f} {y0:.1f} {side:.1f} {side:.1f}">{mark_svg(TRANSPARENT)}</svg>\n'
    )


# Android adaptive icons: flutter_launcher_icons insets the foreground by 16% per
# side, so the artwork is drawn larger to land inside the 66dp safe zone.
ICON_SCALE = 1.0
ADAPTIVE_SCALE = 1.28


def write_svgs() -> dict[str, Path]:
    """Write every SVG under ``design/brand`` and return them by name."""
    SVG_DIR.mkdir(parents=True, exist_ok=True)
    files = {
        "app_icon": _canvas(LIGHT, 1024, ICON_SCALE),
        "app_icon_dark": _canvas(DARK, 1024, ICON_SCALE),
        "app_icon_tinted": _canvas(TINTED, 1024, ICON_SCALE),
        "app_icon_foreground": _canvas(TRANSPARENT, 1024, ADAPTIVE_SCALE),
        "app_icon_monochrome": _canvas(MONO, 1024, ADAPTIVE_SCALE),
        "logo_mark": _logo_mark_svg(),
    }
    out: dict[str, Path] = {}
    for name, text in files.items():
        path = SVG_DIR / f"{name}.svg"
        path.write_text(text, encoding="utf-8")
        out[name] = path
    return out


def render_png(svg: Path, dest: Path, px: int) -> None:
    """Render ``svg`` to a ``px`` x ``px`` PNG with a transparent background."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    html = (
        '<!doctype html><meta charset="utf-8"><style>html,body{margin:0;background:transparent}'
        f'img{{display:block}}</style><img src="{svg.as_uri()}" width="{px}" height="{px}">'
    )
    with tempfile.TemporaryDirectory() as tmp:
        page = Path(tmp) / "page.html"
        page.write_text(html, encoding="utf-8")
        subprocess.run(
            [
                str(CHROME),
                "--headless=new",
                "--disable-gpu",
                "--hide-scrollbars",
                "--force-device-scale-factor=1",
                f"--window-size={px},{px}",
                "--default-background-color=00000000",
                f"--screenshot={dest}",
                page.as_uri(),
            ],
            check=True,
            capture_output=True,
            timeout=60,
        )


# (svg name, destination relative to the repo root, pixel size)
RENDERS: tuple[tuple[str, str, int], ...] = (
    ("app_icon", "design/brand/png/app_icon_1024.png", 1024),
    ("app_icon_dark", "design/brand/png/app_icon_dark_1024.png", 1024),
    ("app_icon_tinted", "design/brand/png/app_icon_tinted_1024.png", 1024),
    ("app_icon_foreground", "design/brand/png/app_icon_foreground_1024.png", 1024),
    ("app_icon_monochrome", "design/brand/png/app_icon_monochrome_1024.png", 1024),
    # In-app logo: 1x is 200px, Flutter picks the 2.0x/3.0x variants by DPR.
    ("logo_mark", "assets/brand/logo_mark.png", 200),
    ("logo_mark", "assets/brand/2.0x/logo_mark.png", 400),
    ("logo_mark", "assets/brand/3.0x/logo_mark.png", 600),
    # iOS launch image (140pt).
    ("logo_mark", "ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png", 140),
    ("logo_mark", "ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png", 280),
    ("logo_mark", "ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png", 420),
    # Android launch image (nodpi: shown at its pixel size).
    ("logo_mark", "android/app/src/main/res/drawable-nodpi/launch_logo.png", 432),
)


def main(argv: list[str] | None = None) -> int:
    """Entry point; returns a process exit code."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--svg-only", action="store_true", help="write SVGs, skip PNG rendering")
    args = parser.parse_args(argv)

    svgs = write_svgs()
    print(f"wrote {len(svgs)} SVGs to {SVG_DIR.relative_to(ROOT)}")
    if args.svg_only:
        return 0
    if not CHROME.exists():
        print(f"Chrome not found at {CHROME}", file=sys.stderr)
        return 1
    for name, rel, px in RENDERS:
        render_png(svgs[name], ROOT / rel, px)
        print(f"rendered {rel} ({px}px)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
