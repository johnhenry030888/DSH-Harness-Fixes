"""Validator for Stage 2 app-maps (docs/app-map.md).

Checks the screen inventory a scaffold instantiates from
docs/app-map.template.md:

    python3 scripts/validate_app_map.py [docs/app-map.md]

Exit 0 when valid, 1 otherwise (one issue per line, so agents can paste
them back into the slice brief). Wired into scripts/verify.sh on UI
projects. When .ui-artifacts/*.json schemas exist, FSM names are cross-checked
against them (filename stems plus top-level name fields). Also importable:
from validate_app_map import validate_text, validate_file, schema_names.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import sys


def _section(text, name):
    pat = r"^##\s+" + re.escape(name) + r"\s*$"
    m = re.search(pat, text, re.M | re.I)
    if not m:
        return None
    rest = text[m.end() :]
    n = re.search(r"^##\s+\S", rest, re.M)
    return rest[: n.start()] if n else rest


def _table_rows(section):
    rows = []
    for line in section.splitlines():
        line = line.strip()
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        if all(re.fullmatch(r":?-+:?", c) for c in cells):
            continue
        rows.append(cells)
    return rows


def validate_text(text):
    """Return a list of issue strings (empty means valid)."""
    issues = []
    screens = _section(text, "Screens")
    if screens is None:
        return ["missing '## Screens' section"]
    rows = _table_rows(screens)
    if not rows:
        return ["Screens table has no rows"]
    header = [h.lower() for h in rows[0]]
    for col in ("screen", "route", "fsm"):
        if col not in header:
            issues.append("Screens table missing '" + col + "' column")
    if issues:
        return issues
    si = header.index("screen")
    ri = header.index("route")
    fi = header.index("fsm")
    gi = header.index("guard") if "guard" in header else None
    bi = header.index("fallback") if "fallback" in header else None
    seen = {}
    for row in rows[1:]:
        if len(row) < len(header):
            row = row + [""] * (len(header) - len(row))
        name, route, fsm = row[si], row[ri], row[fi]
        if not name:
            issues.append("screen row with empty Screen name")
        if not route:
            issues.append("screen '" + (name or "?") + "': empty Route")
        elif not route.startswith("/"):
            issues.append("route must start with /: " + route)
        if not fsm:
            issues.append("screen '" + (name or "?") + "': orphan, no FSM link")
        if route and route in seen:
            issues.append("duplicate route: " + route)
        elif route:
            seen[route] = name
        guard = row[gi] if gi is not None else ""
        fallback = row[bi] if bi is not None else ""
        if guard and not fallback:
            issues.append("guarded route has no Fallback state: " + route)
    back = _section(text, "Back-stack")
    if back is None or not back.strip():
        issues.append("missing '## Back-stack' section")
    focus = _section(text, "Focus restore")
    if focus is None or not focus.strip():
        issues.append("missing '## Focus restore' section")
    return issues


def _norm(s):
    return re.sub(r"[\s_]+", "-", s.strip().lower())


def table_fsms(text):
    """Non-empty FSM names from the Screens table ([] when unparsable)."""
    screens = _section(text, "Screens")
    if screens is None:
        return []
    rows = _table_rows(screens)
    if not rows:
        return []
    header = [h.lower() for h in rows[0]]
    if "fsm" not in header:
        return []
    fi = header.index("fsm")
    return [row[fi].strip() for row in rows[1:] if len(row) > fi and row[fi].strip()]


def schema_names(root="."):
    """Candidate FSM names from .ui-artifacts/*.json (stems + name fields)."""
    names = set()
    artifacts = Path(root) / ".ui-artifacts"
    if not artifacts.is_dir():
        return names
    for p in sorted(artifacts.glob("*.json")):
        stem = p.stem
        for suffix in ("-interaction-schema", "-schema", "_schema"):
            if stem.endswith(suffix):
                stem = stem[: -len(suffix)]
                break
        if stem and stem != ".gitkeep":
            names.add(_norm(stem))
        try:
            data = json.loads(p.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        if (
            isinstance(data, dict)
            and isinstance(data.get("name"), str)
            and data["name"].strip()
        ):
            names.add(_norm(data["name"]))
    return names


def validate_file(path, root="."):
    """Validate an app-map file plus its FSM cross-check. Returns issues."""
    try:
        text = Path(path).read_text(encoding="utf-8")
    except OSError as e:
        return ["app-map unreadable: " + str(e)]
    issues = validate_text(text)
    known = schema_names(root)
    if known:
        for fsm in table_fsms(text):
            if _norm(fsm) not in known:
                issues.append(
                    "fsm '"
                    + fsm
                    + "' has no matching interaction schema in .ui-artifacts/"
                )
    return issues


def main(argv=None):
    ap = argparse.ArgumentParser(description="Validate docs/app-map.md (Stage 2).")
    ap.add_argument("path", nargs="?", default="docs/app-map.md")
    args = ap.parse_args(argv)
    issues = validate_file(args.path)
    for i in issues:
        print(i)
    return 1 if issues else 0


if __name__ == "__main__":
    sys.exit(main())
