#!/usr/bin/env python3
"""Pin the macOS Aerial screensaver (Sonoma+) to a named idleassets video."""

from __future__ import annotations

import json
import plistlib
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

PROVIDER = "com.apple.wallpaper.choice.aerials"
STORE = Path.home() / "Library/Application Support/com.apple.wallpaper/Store/Index.plist"
CATALOGS = (
    Path.home() / "Library/Application Support/com.apple.wallpaper/aerials/manifest/entries.json",
    Path("/Library/Application Support/com.apple.idleassetsd/Customer/entries.json"),
)
# Apple's catalog id for "Antarctica's Southern Lights" (preview / asset UUID).
KNOWN_IDS = {
    "antarcticas southern lights": "03EC0F5E-CCA8-4E0A-9FEC-5BD1CE151182",
    "antarctica southern lights": "03EC0F5E-CCA8-4E0A-9FEC-5BD1CE151182",
}


def norm(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", " ", text.lower()).strip()


def load_assets() -> list[dict]:
    assets: list[dict] = []
    for path in CATALOGS:
        if not path.is_file():
            continue
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        chunk = data.get("assets")
        if isinstance(chunk, list):
            assets.extend(a for a in chunk if isinstance(a, dict))
    return assets


def find_asset(want: str) -> tuple[str, str]:
    needle = norm(want)
    if not needle:
        raise SystemExit("screensaver name is empty")

    best: tuple[int, str, str] | None = None
    for asset in load_assets():
        asset_id = str(asset.get("id") or "")
        label = str(asset.get("accessibilityLabel") or "")
        if not asset_id or not label:
            continue
        hay = norm(label)
        if hay == needle:
            return label, asset_id
        if needle in hay or hay in needle:
            score = len(hay)
            if best is None or score < best[0]:
                best = (score, label, asset_id)
    if best:
        return best[1], best[2]

    fallback = KNOWN_IDS.get(needle)
    if fallback:
        return want, fallback

    raise SystemExit(f"unknown aerial screensaver: {want}")


def aerial_choice(asset_id: str) -> dict:
    return {
        "Configuration": plistlib.dumps({"assetID": asset_id}, fmt=plistlib.FMT_BINARY),
        "Files": [],
        "Provider": PROVIDER,
    }


def aerial_section(asset_id: str) -> dict:
    now = datetime.now(timezone.utc)
    return {
        "Content": {"Choices": [aerial_choice(asset_id)]},
        "LastSet": now,
        "LastUse": now,
    }


def apply_section(container: dict, asset_id: str) -> None:
    section = aerial_section(asset_id)
    kind = container.get("Type")
    if kind == "linked":
        container["Linked"] = section
        return
    if kind == "individual" or "Idle" in container:
        container["Type"] = kind or "individual"
        container["Idle"] = section
        return
    if "Linked" in container:
        container["Linked"] = section
        return
    container["Type"] = "individual"
    container["Idle"] = section


def apply(want: str) -> str:
    label, asset_id = find_asset(want)
    STORE.parent.mkdir(parents=True, exist_ok=True)

    root: dict
    if STORE.is_file():
        with STORE.open("rb") as fh:
            loaded = plistlib.load(fh)
        root = loaded if isinstance(loaded, dict) else {}
    else:
        root = {}

    asd = root.get("AllSpacesAndDisplays")
    if not isinstance(asd, dict):
        asd = {}
        root["AllSpacesAndDisplays"] = asd
    apply_section(asd, asset_id)

    displays = root.get("Displays")
    if isinstance(displays, dict):
        for display in displays.values():
            if isinstance(display, dict):
                apply_section(display, asset_id)

    with STORE.open("wb") as fh:
        plistlib.dump(root, fh, fmt=plistlib.FMT_BINARY)

    print(f"{label}|{asset_id}")
    return asset_id


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {sys.argv[0]} 'Antarctica\\'s Southern Lights'")
    apply(sys.argv[1])
