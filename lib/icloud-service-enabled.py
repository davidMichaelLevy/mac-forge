#!/usr/bin/env python3
"""Exit 0 if MobileMeAccounts says an iCloud service matching KEYWORD is enabled.

Usage: icloud-service-enabled.py KEYWORD   (e.g. CALENDAR, MOBILE_DOCUMENTS)

Missing Enabled is treated as off so forge does not keep opening Settings.
"""

from __future__ import annotations

import pathlib
import plistlib
import sys


def enabled(keyword: str) -> bool:
    path = pathlib.Path.home() / "Library/Preferences/MobileMeAccounts.plist"
    if not path.is_file():
        return False
    try:
        data = plistlib.loads(path.read_bytes())
    except Exception:
        return False
    for account in data.get("Accounts") or []:
        if not isinstance(account, dict):
            continue
        for service in account.get("Services") or []:
            if not isinstance(service, dict):
                continue
            name = str(service.get("Name") or service.get("ServiceName") or "")
            sid = str(service.get("ServiceID") or "")
            if keyword not in f"{name} {sid}".upper():
                continue
            if service.get("Enabled") in (True, 1, "1"):
                return True
    return False


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit(1)
    raise SystemExit(0 if enabled(sys.argv[1].upper()) else 1)
