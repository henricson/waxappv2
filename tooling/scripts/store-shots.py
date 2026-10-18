#!/usr/bin/env python3
"""Capture raw App Store screenshots from a booted simulator.

    tooling/scripts/store-shots.py <simulator-udid> <iphone|ipad> [locale ...]

For every slide in tooling/Marketing/captions/captions.json and every store
locale, launches GetGrip in demo mode with the slide's launch arguments and
the locale's language, then saves the screen to

    tooling/Marketing/raw/<device>/<locale>/<scene>.png

Build the app and install it on the simulator first (a stale install
silently ignores newer demo switches). Frame the results with
tooling/scripts/frame-screenshots.py.
"""

import json
import pathlib
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parents[2]
CAPTIONS = ROOT / "tooling/Marketing/captions/captions.json"
RAW = ROOT / "tooling/Marketing/raw"
BUNDLE_ID = "com.squarewave.waxappv2"

# App Store locale → (app language, locale with region). The region also
# picks the default wax kit, so Norwegian shots show the Norwegian kit.
LOCALES = {
    "en-US": ("en", "en_US"),
    "no": ("nb", "nb_NO"),
    "sv": ("sv", "sv_SE"),
    "fi": ("fi", "fi_FI"),
}

SETTLE_SECONDS = 6


def simctl(*args, check=True):
    return subprocess.run(["xcrun", "simctl", *args], check=check, capture_output=True, text=True)


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    udid, device = sys.argv[1], sys.argv[2]
    locales = sys.argv[3:] or list(LOCALES)
    slides = json.loads(CAPTIONS.read_text())["slides"]

    simctl(
        "status_bar", udid, "override", "--time", "9:41", "--batteryState", "charged",
        "--batteryLevel", "100", "--wifiBars", "3", "--cellularBars", "4", check=False)

    for locale in locales:
        language, region_locale = LOCALES[locale]
        out_dir = RAW / device / locale
        out_dir.mkdir(parents=True, exist_ok=True)

        for slide in slides:
            args = ["-GGDemoMode", "YES"]
            for key, value in slide.get("launch", {}).items():
                # A value starting with "-" would be read as the next flag;
                # the app trims the leading space back off.
                args += [f"-{key}", f" {value}" if value.startswith("-") else value]
            args += ["-AppleLanguages", f"({language})", "-AppleLocale", region_locale]

            simctl("terminate", udid, BUNDLE_ID, check=False)
            simctl("launch", udid, BUNDLE_ID, *args)
            time.sleep(SETTLE_SECONDS)

            target = out_dir / f"{slide['scene']}.png"
            simctl("io", udid, "screenshot", str(target))
            print(f"{device} {locale} {slide['scene']} → {target.relative_to(ROOT)}")

    simctl("terminate", udid, BUNDLE_ID, check=False)


if __name__ == "__main__":
    main()
