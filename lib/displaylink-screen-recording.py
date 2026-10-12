#!/usr/bin/env python3
"""Report DisplayLink Manager Screen Recording (TCC) as granted, denied, or unknown."""

from __future__ import annotations

import sqlite3
import sys
from pathlib import Path

CLIENTS = (
    "com.displaylink.DisplayLinkUserAgent",
    "com.displaylink.DisplayLinkManager",
)
SERVICE = "kTCCServiceScreenCapture"
TCC_DBS = (
    Path.home() / "Library/Application Support/com.apple.TCC/TCC.db",
    Path("/Library/Application Support/com.apple.TCC/TCC.db"),
)


def rows_for(con: sqlite3.Connection, column: str, client: str) -> list[tuple]:
    return con.execute(
        f"SELECT {column} FROM access WHERE service = ? AND client = ?",
        (SERVICE, client),
    ).fetchall()


def state() -> str:
    denied = False
    for path in TCC_DBS:
        if not path.is_file():
            continue
        try:
            con = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
        except sqlite3.Error:
            continue
        try:
            cols = {row[1] for row in con.execute("PRAGMA table_info(access)")}
            for client in CLIENTS:
                if "auth_value" in cols:
                    values = [v for (v,) in rows_for(con, "auth_value", client)]
                    if any(v in (2, 3) for v in values):
                        return "granted"
                    if 0 in values:
                        denied = True
                elif "allowed" in cols:
                    values = [v for (v,) in rows_for(con, "allowed", client)]
                    if 1 in values:
                        return "granted"
                    if 0 in values:
                        denied = True
        except sqlite3.Error:
            pass
        finally:
            con.close()
    return "denied" if denied else "unknown"


def main() -> None:
    print(state())


if __name__ == "__main__":
    try:
        main()
    except Exception:
        print("unknown")
        raise SystemExit(0)
    raise SystemExit(0)
