#!/usr/bin/env python3
"""Report a TCC permission for any of the given clients.

Usage: tcc-state.py SERVICE CLIENT [CLIENT...]

Prints one of:
  granted  some client is allowed
  denied   some client was explicitly turned off
  missing  every TCC database was readable and no client has an entry
  unknown  a database could not be read (needs Full Disk Access)
"""

from __future__ import annotations

import sqlite3
import sys
from pathlib import Path

TCC_DBS = (
    Path.home() / "Library/Application Support/com.apple.TCC/TCC.db",
    Path("/Library/Application Support/com.apple.TCC/TCC.db"),
)


def rows_for(con: sqlite3.Connection, column: str, service: str, client: str) -> list[tuple]:
    return con.execute(
        f"SELECT {column} FROM access WHERE service = ? AND client = ?",
        (service, client),
    ).fetchall()


def state(service: str, clients: list[str]) -> str:
    denied = False
    unreadable = False
    for path in TCC_DBS:
        if not path.is_file():
            continue
        try:
            con = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
            cols = {row[1] for row in con.execute("PRAGMA table_info(access)")}
        except sqlite3.Error:
            unreadable = True
            continue
        try:
            for client in clients:
                if "auth_value" in cols:
                    values = [v for (v,) in rows_for(con, "auth_value", service, client)]
                    if any(v in (2, 3) for v in values):
                        return "granted"
                    if 0 in values:
                        denied = True
                elif "allowed" in cols:
                    values = [v for (v,) in rows_for(con, "allowed", service, client)]
                    if 1 in values:
                        return "granted"
                    if 0 in values:
                        denied = True
        except sqlite3.Error:
            unreadable = True
        finally:
            con.close()
    if denied:
        return "denied"
    return "unknown" if unreadable else "missing"


def main() -> None:
    if len(sys.argv) < 3:
        print("unknown")
        return
    print(state(sys.argv[1], sys.argv[2:]))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        print("unknown")
    raise SystemExit(0)
