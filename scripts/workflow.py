#!/usr/bin/env python3
"""Host-neutral project workflow controller.

The project marker seeds an ignored sidecar so opencode, DSH, and a shell
invocation share durable state without making completion dirty the product tree.
Transitions are intentionally small and atomic.
"""

from __future__ import annotations

import argparse
import contextlib
from datetime import UTC, datetime
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
from typing import Any

MARKER = ".scaffold.json"
WORKFLOW_SIDECAR = ".scaffold-workflow.json"
STAGES = ("bootstrap", "implementation", "release")
REQUIRED_GATES = ("verify", "secrets")
OPTIONAL_GATES = {
    "lint",
    "tests",
    "typecheck",
    "api",
    "perf",
    "ui_review",
    "visual_baseline",
    "commit",
    "push",
}


def fail(message: str) -> None:
    print(json.dumps({"ok": False, "error": message}, sort_keys=True))
    raise SystemExit(1)


def load(root: Path) -> dict[str, Any]:
    path = root / MARKER
    if not path.is_file():
        fail(f"{MARKER} is missing; scaffold or audit the project first")
    try:
        marker = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"cannot read {MARKER}: {exc}")
    if not isinstance(marker, dict):
        fail(f"{MARKER} must contain an object")
    sidecar = root / WORKFLOW_SIDECAR
    if sidecar.is_file():
        try:
            current = json.loads(sidecar.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            fail(f"cannot read {WORKFLOW_SIDECAR}: {exc}")
        if not isinstance(current, dict):
            fail(f"{WORKFLOW_SIDECAR} must contain an object")
        marker["workflow"] = current
    return marker


def detected_runtimes(root: Path | None) -> set[str]:
    """Detect every runtime present, including additive stacks."""
    if root is None:
        return set()
    ignored = {
        ".git",
        "node_modules",
        ".venv",
        "venv",
        "vendor",
        "dist",
        "build",
        "target",
        ".next",
        "coverage",
        "__pycache__",
        ".ui-artifacts",
    }
    house_files = {"scripts/workflow.py", "scripts/validate_app_map.py"}
    files = []
    try:
        for path in root.rglob("*"):
            if not path.is_file():
                continue
            relative = path.relative_to(root)
            if relative.as_posix() in house_files or ignored.intersection(
                relative.parts
            ):
                continue
            files.append(path)
    except OSError:
        return set()
    names = {path.name.lower() for path in files}
    node = bool(
        names
        & {
            "package.json",
            "package-lock.json",
            "pnpm-lock.yaml",
            "yarn.lock",
            "bun.lockb",
            "tsconfig.json",
        }
    ) or any(path.suffix.lower() in {".js", ".jsx", ".ts", ".tsx"} for path in files)
    python = bool(
        names
        & {
            "pyproject.toml",
            "requirements.txt",
            "requirements-dev.txt",
            "setup.py",
            "setup.cfg",
            "uv.lock",
            "poetry.lock",
        }
    ) or any(path.suffix.lower() == ".py" for path in files)
    runtimes = set()
    if node:
        runtimes.add("node")
    if python:
        runtimes.add("python")
    if (root / "Cargo.toml").is_file():
        runtimes.add("rust")
    if (root / "go.mod").is_file():
        runtimes.add("go")
    return runtimes


def detected_stack(root: Path | None) -> str:
    """Return the primary detected stack for compatibility and reporting."""
    runtimes = detected_runtimes(root)
    if "node" in runtimes and "python" in runtimes:
        return "polyglot"
    for runtime in ("node", "python", "rust", "go"):
        if runtime in runtimes:
            return runtime
    return "none"


def has_ui_scope(root: Path | None, features: Any) -> bool:
    """Match the house UI predicate, including files added after scaffolding."""
    if any(
        feature in {"ui", "design"} for feature in features if isinstance(feature, str)
    ):
        return True
    if root is None:
        return False
    skipped = {
        ".git",
        "node_modules",
        ".venv",
        "venv",
        "vendor",
        "dist",
        "build",
        ".ui-artifacts",
    }
    try:
        for path in root.rglob("*"):
            if not path.is_file() or skipped.intersection(path.parts):
                continue
            if path.relative_to(root).as_posix() == "src/index.ts":
                continue
            if path.suffix.lower() in {".tsx", ".jsx", ".ts", ".html", ".css"}:
                return True
    except OSError:
        return False
    return False


def required_gates(marker: dict[str, Any], root: Path | None = None) -> list[str]:
    """Return gates for the marker plus runtimes/files added since its audit."""
    gates = ["verify", "secrets"]
    stack = marker.get("stack", "none")
    features = marker.get("features", [])
    detected = detected_stack(root)
    runtimes = {stack, detected, *detected_runtimes(root)}
    if runtimes & {"node", "python", "rust", "go", "polyglot"}:
        gates.extend(("lint", "tests"))
    if runtimes & {"node", "polyglot"}:
        gates.append("typecheck")
    if has_ui_scope(root, features):
        gates.extend(("ui_review", "visual_baseline"))
    return gates


def default_workflow(
    marker: dict[str, Any], root: Path | None = None
) -> dict[str, Any]:
    return {
        "schema": 1,
        "project": marker.get("project", ""),
        "stack": marker.get("stack", "none"),
        "features": marker.get("features", []),
        "state": "ready",
        "stage": "bootstrap",
        "required_artifacts": [
            "AGENTS.md",
            "README.md",
            "STATE.md",
            "scripts/verify.sh",
            MARKER,
        ],
        "required_gates": required_gates(marker, root),
        "baseline_dirty": [],
        "gates": {},
        "commit": {"state": "pending", "hash": "", "evidence": ""},
        "push": {"state": "pending", "evidence": ""},
        "residual_risks": [],
        "retry": {"attempt": 0, "last_error": "", "resumable": True},
        "history": [],
    }


def workflow(marker: dict[str, Any], root: Path | None = None) -> dict[str, Any]:
    current = marker.get("workflow")
    if not isinstance(current, dict):
        current = default_workflow(marker, root)
    else:
        base = default_workflow(marker, root)
        base.update(current)
        current = base
    current["project"] = marker.get("project", current["project"])
    current["stack"] = marker.get("stack", current["stack"])
    current["features"] = marker.get("features", current["features"])
    existing_gates = current.get("required_gates", [])
    if not isinstance(existing_gates, list):
        existing_gates = []
    current["required_gates"] = list(
        dict.fromkeys(existing_gates + required_gates(marker, root))
    )
    return current


def ensure_sidecar_ignored(root: Path) -> None:
    """Keep older adopted projects clean without rewriting their .gitignore."""
    exclude = root / ".git" / "info" / "exclude"
    if not exclude.parent.is_dir():
        return
    try:
        text = exclude.read_text(encoding="utf-8") if exclude.is_file() else ""
        if any(line.strip() == WORKFLOW_SIDECAR for line in text.splitlines()):
            return
        if text and not text.endswith("\n"):
            text += "\n"
        exclude.write_text(
            f"{text}\n# House workflow state\n{WORKFLOW_SIDECAR}\n",
            encoding="utf-8",
        )
    except OSError as exc:
        fail(f"cannot configure local workflow ignore: {exc}")


def save(root: Path, marker: dict[str, Any], record: dict[str, Any]) -> None:
    path = root / WORKFLOW_SIDECAR
    ensure_sidecar_ignored(root)
    fd, name = tempfile.mkstemp(prefix=".scaffold.", suffix=".tmp", dir=root)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            text = json.dumps(record, indent=2)
            for key in ("features", "required_gates"):
                pattern = rf'(?m)^(  "{key}": )\[(?:\n    .*?)+\n  \](,?)$'
                replacement = json.dumps(record[key])
                text = re.sub(
                    pattern,
                    lambda match, replacement=replacement: (
                        f"{match.group(1)}{replacement}{match.group(2)}"
                    ),
                    text,
                )
            handle.write(text + "\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(name, path)
    except OSError as exc:
        with contextlib.suppress(OSError):
            os.unlink(name)
        fail(f"cannot persist workflow record: {exc}")


def event(
    record: dict[str, Any], action: str, detail: dict[str, Any] | None = None
) -> None:
    record.setdefault("history", []).append({"action": action, **(detail or {})})


def artifacts_ok(root: Path, record: dict[str, Any]) -> list[str]:
    return [
        rel
        for rel in record.get("required_artifacts", [])
        if not (root / rel).is_file()
    ]


def gate_satisfied(entry: Any, current_head: str = "") -> bool:
    if not isinstance(entry, dict):
        return False
    if entry.get("status") == "pass":
        return not current_head or entry.get("commit") == current_head
    if entry.get("status") != "waived":
        return False
    raw = str(entry.get("waiver_until", "")).strip().replace("Z", "+00:00")
    try:
        expiry = datetime.fromisoformat(raw)
    except ValueError:
        return False
    if expiry.tzinfo is None:
        expiry = expiry.replace(tzinfo=UTC)
    return expiry > datetime.now(UTC) and (
        not current_head or entry.get("commit") == current_head
    )


def current_head(root: Path) -> str:
    """Return the commit gates are bound to, or empty before the first commit."""
    return git_ref(root, "HEAD")


def cmd_start(root: Path, marker: dict[str, Any]) -> dict[str, Any]:
    record = workflow(marker, root)
    if record["state"] == "complete":
        record["iteration"] = int(record.get("iteration", 1)) + 1
        record["stage"] = "implementation"
        record["gates"] = {}
        record["commit"] = {"state": "pending", "hash": "", "evidence": ""}
        record["push"] = {"state": "pending", "evidence": ""}
        record["baseline_dirty"] = sorted(git_status_paths(root) or [])
        record["residual_risks"] = []
        record["retry"] = {"attempt": 0, "last_error": "", "resumable": True}
        record["state"] = "active"
        event(
            record,
            "restart",
            {"iteration": record["iteration"], "stage": "implementation"},
        )
        save(root, marker, record)
        return {"ok": True, "action": "restart", "workflow": record}
    stored_workflow = marker.get("workflow")
    if not isinstance(stored_workflow, dict) or "baseline_dirty" not in stored_workflow:
        record["baseline_dirty"] = sorted(git_status_paths(root) or [])
    record["state"] = "active"
    record["retry"]["resumable"] = True
    event(record, "start", {"stage": record["stage"]})
    save(root, marker, record)
    return {"ok": True, "action": "start", "workflow": record}


def cmd_next(root: Path, marker: dict[str, Any]) -> dict[str, Any]:
    record = workflow(marker, root)
    missing = artifacts_ok(root, record)
    if missing:
        record["state"] = "blocked"
        record["retry"]["last_error"] = "missing artifacts: " + ", ".join(missing)
        event(record, "blocked", {"reason": record["retry"]["last_error"]})
        save(root, marker, record)
        return {"ok": False, "action": "next", "resumable": True, "missing": missing}
    if record["state"] == "blocked":
        return {
            "ok": False,
            "action": "next",
            "resumable": True,
            "error": "workflow is blocked; resume first",
        }
    if record["state"] == "complete":
        return {"ok": True, "action": "next", "complete": True, "workflow": record}
    record["state"] = "active"
    stage = record["stage"]
    if stage == "bootstrap":
        record["stage"] = "implementation"
    elif stage == "implementation":
        head = current_head(root)
        missing_gates = [
            gate
            for gate in record.get("required_gates", REQUIRED_GATES)
            if not gate_satisfied(record.get("gates", {}).get(gate), head)
        ]
        if missing_gates:
            return {
                "ok": False,
                "action": "next",
                "error": "required gates are incomplete: " + ", ".join(missing_gates),
                "missing_gates": missing_gates,
                "resumable": True,
            }
        record["stage"] = "release"
    else:
        return {
            "ok": False,
            "action": "next",
            "error": "release is terminal; use complete",
            "resumable": True,
        }
    event(record, "next", {"from": stage, "to": record["stage"]})
    save(root, marker, record)
    return {"ok": True, "action": "next", "workflow": record}


def cmd_gate(
    root: Path,
    marker: dict[str, Any],
    gate: str,
    status: str,
    evidence: str,
    waiver_until: str,
) -> dict[str, Any]:
    record = workflow(marker, root)
    if record.get("state") == "complete":
        return {
            "ok": False,
            "error": (
                "workflow is complete; call workflow_start before recording new gates"
            ),
            "resumable": True,
        }
    if gate not in set(record.get("required_gates", [])) and gate not in OPTIONAL_GATES:
        return {"ok": False, "error": f"unknown gate: {gate}"}
    if status not in {"pass", "fail", "waived"}:
        return {"ok": False, "error": "status must be pass, fail, or waived"}
    if status in {"pass", "waived"} and not evidence.strip():
        return {"ok": False, "error": "passing or waived gates require evidence"}
    if status == "waived" and not waiver_until:
        return {"ok": False, "error": "waived gates require waiver_until"}
    if status == "waived" and not gate_satisfied(
        {"status": status, "waiver_until": waiver_until}
    ):
        return {
            "ok": False,
            "error": "waiver_until must be a future ISO-8601 timestamp",
        }
    record.setdefault("gates", {})[gate] = {
        "status": status,
        "evidence": evidence,
        "waiver_until": waiver_until,
        "commit": current_head(root),
    }
    if status == "fail":
        record["state"] = "blocked"
        record["retry"]["last_error"] = f"gate failed: {gate}"
    event(record, "record-gate", {"gate": gate, "status": status})
    save(root, marker, record)
    return {
        "ok": status != "fail",
        "action": "record-gate",
        "workflow": record,
        "resumable": True,
    }


def cmd_resume(root: Path, marker: dict[str, Any]) -> dict[str, Any]:
    record = workflow(marker, root)
    if record["state"] != "blocked":
        return {
            "ok": True,
            "action": "resume",
            "note": "workflow was not blocked",
            "workflow": record,
        }
    record["state"] = "active"
    record["retry"]["attempt"] = int(record["retry"].get("attempt", 0)) + 1
    record["retry"]["resumable"] = True
    event(record, "resume", {"attempt": record["retry"]["attempt"]})
    save(root, marker, record)
    return {"ok": True, "action": "resume", "workflow": record}


def git_hash(root: Path, value: str) -> bool:
    if value == "HEAD":
        args = ["rev-parse", "--verify", "HEAD"]
    else:
        args = ["cat-file", "-e", f"{value}^{{commit}}"]
    return (
        subprocess.run(
            ["git", *args], cwd=root, capture_output=True, text=True, timeout=10
        ).returncode
        == 0
    )


def git_ref(root: Path, ref: str) -> str:
    result = subprocess.run(
        ["git", "rev-parse", "--verify", ref],
        cwd=root,
        capture_output=True,
        text=True,
        timeout=10,
    )
    return result.stdout.strip() if result.returncode == 0 else ""


def git_status_paths(root: Path) -> set[str] | None:
    result = subprocess.run(
        ["git", "status", "--porcelain=v1", "--untracked-files=all"],
        cwd=root,
        capture_output=True,
        text=True,
        timeout=10,
    )
    if result.returncode != 0:
        return None
    paths = set()
    for line in result.stdout.splitlines():
        if len(line) < 4:
            continue
        path = line[3:]
        if " -> " in path:
            paths.update(path.split(" -> ", 1))
        else:
            paths.add(path)
    return paths


def git_clean(root: Path, baseline_dirty: set[str] | None = None) -> bool:
    baseline_dirty = baseline_dirty or set()
    current = git_status_paths(root)
    return current is not None and not current.difference(baseline_dirty)


def upstream_matches_head(root: Path, head: str) -> bool:
    upstream = git_ref(root, "@{u}")
    return bool(upstream) and upstream == head


def cmd_complete(
    root: Path, marker: dict[str, Any], commit_hash: str, push: str, push_evidence: str
) -> dict[str, Any]:
    record = workflow(marker, root)
    head = current_head(root)
    missing = [
        gate
        for gate in record.get("required_gates", REQUIRED_GATES)
        if not gate_satisfied(record.get("gates", {}).get(gate), head)
    ]
    if missing:
        return {
            "ok": False,
            "error": "required gates are incomplete",
            "missing_gates": missing,
            "resumable": True,
        }
    if record.get("stage") != "release":
        return {
            "ok": False,
            "error": "workflow must reach release before completion",
            "resumable": True,
        }
    head = git_ref(root, "HEAD")
    supplied = git_ref(root, commit_hash) if commit_hash else ""
    if (
        not commit_hash
        or not git_hash(root, commit_hash)
        or not head
        or supplied != head
    ):
        return {
            "ok": False,
            "error": "commit evidence must identify the current HEAD",
            "resumable": True,
        }
    baseline_dirty = record.get("baseline_dirty", [])
    if not isinstance(baseline_dirty, list):
        baseline_dirty = []
    if not git_clean(root, set(baseline_dirty)):
        return {
            "ok": False,
            "error": "working tree must be clean before completion",
            "resumable": True,
        }
    if push not in {"pushed", "deferred"}:
        return {
            "ok": False,
            "error": "push evidence is required: pushed or deferred",
            "resumable": True,
        }
    if push == "deferred" and not push_evidence.strip():
        return {
            "ok": False,
            "error": "push deferral requires a reason",
            "resumable": True,
        }
    if push == "pushed" and not upstream_matches_head(root, head):
        return {
            "ok": False,
            "error": "pushed completion requires an upstream ref at current HEAD",
            "resumable": True,
        }
    record["commit"] = {
        "state": "committed",
        "hash": commit_hash,
        "evidence": "validated by git",
    }
    record["push"] = {"state": push, "evidence": push_evidence or "remote accepted"}
    record["state"] = "complete"
    record["stage"] = "release"
    record["retry"]["resumable"] = False
    event(record, "complete", {"commit": commit_hash, "push": push})
    save(root, marker, record)
    return {"ok": True, "action": "complete", "workflow": record}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "action", choices=("start", "next", "record-gate", "resume", "complete")
    )
    parser.add_argument("--project-root", default=".")
    parser.add_argument("--gate", default="")
    parser.add_argument("--status", default="")
    parser.add_argument("--evidence", default="")
    parser.add_argument("--waiver-until", default="")
    parser.add_argument("--commit-hash", default="")
    parser.add_argument("--push", choices=("pushed", "deferred"), default="")
    parser.add_argument("--push-evidence", default="")
    args = parser.parse_args()
    root = Path(args.project_root).resolve()
    if not root.is_dir():
        fail(f"project root is not a directory: {root}")
    marker = load(root)
    actions = {
        "start": lambda: cmd_start(root, marker),
        "next": lambda: cmd_next(root, marker),
        "record-gate": lambda: cmd_gate(
            root, marker, args.gate, args.status, args.evidence, args.waiver_until
        ),
        "resume": lambda: cmd_resume(root, marker),
        "complete": lambda: cmd_complete(
            root, marker, args.commit_hash, args.push, args.push_evidence
        ),
    }
    result = actions[args.action]()
    print(json.dumps(result, indent=2, sort_keys=True))
    if not result.get("ok"):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
