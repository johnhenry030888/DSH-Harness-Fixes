#!/bin/bash
# Live probe for bug 007 — the one fix the orchestrator drills could not
# exercise, because it needs a `toolFilter` edit that the drills forbid under
# `~/.dsh`.
#
# It boots the shipped headless profile against a **targeted overlay** on that
# profile's own delegation row, inside a **scratch harness home** (the real
# `~/.dsh` is read, never written; everything this script creates lives under
# `$SCRATCH`, default `/tmp/orch-drill-007`).
#
#   variant A (known-but-non-restrictable name) — the v3 deny list (the 17
#     restrictable names plus `subagent`) must still spawn a child: the tolerant
#     child composition drops the name with a warning instead of letting
#     `restrict()` throw and killing every delegation.
#   variant B (typo) — `subagnt_fast` in the same list must fail loudly, naming
#     the offending loader row and the name. A child spawning here is the bug.
#
# The standing row cannot enable `modelSelectionSettings` (the harness rejects
# that outside a scoped preset context), so `list_subagent_models` — the other
# known-but-non-restrictable name — is covered by the bug's own
# `scripts/tolerance-check.mjs` rather than this live probe.
#
# Exit 0 = both variants matched the fix. Exit 1 = a variant failed (details on
# stdout). Requires `dsh` on PATH and a working model route.
set -u
REAL_HOME="${DSH_REAL_HOME:-$HOME/.dsh}"
SCRATCH="${SCRATCH:-/tmp/orch-drill-007}"
HOME_DIR="$SCRATCH/home"
PATCH="$SCRATCH/007.yml"
TIMEOUT="${PROBE_TIMEOUT:-600}"

# Names that exist in the headless base catalog, so the only thing the
# pre-spawn check can object to is what this probe adds to them. (The web
# preset's 17-name list names its own pins, which the headless host does not
# compose — using it here would fail the check for the wrong reason.)
PRESENT="send_message, list_agents, interrupt_agent, subagent_fork, workflow, ralph, create_goal, get_goal, update_goal, web_search, web_fetch, skill, todo_write, exit_plan_mode, read_image, glob, grep"

PROMPT="Call the subagent tool exactly once, with the instruction \"Reply with exactly the single word READY and stop.\" Then reply with the child's answer verbatim and nothing else."

fail=0
ok() { echo "  PASS  $1"; }
bad() {
  echo "  FAIL  $1"
  fail=1
}

command -v dsh >/dev/null 2>&1 || {
  echo "probe: dsh is not on PATH"
  exit 1
}
[ -f "$REAL_HOME/settings.yaml" ] || {
  echo "probe: real harness home $REAL_HOME has no settings.yaml"
  exit 1
}

# ---------------------------------------------------------------------------
# Scratch home: real credentials and settings are borrowed, the session store
# is the probe's own, so the user's harness keeps no probe transcript.
# ---------------------------------------------------------------------------
rm -rf "$SCRATCH"
mkdir -p "$HOME_DIR/sessions" "$HOME_DIR/attachments"
cp "$REAL_HOME/settings.yaml" "$HOME_DIR/settings.yaml"
for link in .credentials.yaml .anonymous-user-id storages profiles; do
  [ -e "$REAL_HOME/$link" ] || continue
  ln -s "$REAL_HOME/$link" "$HOME_DIR/$link"
done

write_patch() {
  cat >"$PATCH" <<YAML
# Targeted overlay on the headless profile's own delegation row (variant: $2).
- id: tool-subagent
  config:
    provider: spawn
    toolName: subagent
    backgroundMode: one-shot
    toolFilter:
      deny: [$1]
YAML
}

# The newest delegated child's own tool list, read from the scratch transcripts:
# the proof that the filter was applied instead of throwing.
child_tools() {
  python3 - "$HOME_DIR/sessions" <<'PYX'
import glob, json, os, subprocess, sys
root = sys.argv[1]
best = None
for path in glob.glob(os.path.join(root, "**", "session.v3.jsonl.zstd"), recursive=True):
    try:
        head = json.loads(subprocess.run(["zstd", "-dc", path], capture_output=True).stdout.decode("utf8", "replace").splitlines()[0])
    except Exception:
        continue
    if head.get("origin") != "subagent":
        continue
    if best is None or os.path.getmtime(path) > best[0]:
        best = (os.path.getmtime(path), path)
if best is None:
    print("NONE")
    raise SystemExit
lines = subprocess.run(["zstd", "-dc", best[1]], capture_output=True).stdout.decode("utf8", "replace").splitlines()
for line in lines:
    try:
        record = json.loads(line)
    except Exception:
        continue
    if record.get("type") == "request/header":
        print(",".join(sorted(tool["name"] for tool in record["data"]["header"].get("tools", []))))
        break
else:
    print("NONE")
PYX
}

run_probe() {
  DSH_HOME="$HOME_DIR" timeout "$TIMEOUT" dsh --profile headless --patch "$PATCH" "$PROMPT" 2>&1
}

echo "bug 007 live probe — scratch home $HOME_DIR"
echo

# --- variant A: a name the composition knows but cannot restrict ------------
echo "variant A — filter drops present names plus the non-restrictable subagent"
write_patch "$PRESENT, subagent" tolerant
a_out="$(run_probe)"
a_rc=$?
printf '%s\n' "$a_out" | tail -6 | sed 's/^/    | /'
if printf '%s' "$a_out" | grep -q "READY"; then
  ok "delegation survived the non-restrictable name (child replied READY)"
else
  bad "no child reply: the tolerant path did not spawn (exit $a_rc)"
fi
if printf '%s' "$a_out" | grep -Eq 'names unknown global tools|absent from the child catalog'; then
  bad "the row still hard-fails on the name the composition can drop"
else
  ok "no unknown-name failure for a name the child scope cannot restrict"
fi
a_tools="$(child_tools)"
echo "    child tools: ${a_tools:-NONE}"
case "$a_tools" in
NONE | "")
  bad "no child transcript found to confirm the filtered catalog"
  ;;
*web_search* | *workflow*)
  bad "the child header still carries a name the filter should have dropped"
  ;;
*)
  ok "the filter really applied: the child's catalog dropped the restrictable names"
  ;;
esac
echo

# --- variant B: one typo ---------------------------------------------------
echo "variant B — same list with subagnt_fast (typo)"
# Clear the store first: "no child session appeared" is then unambiguous.
rm -rf "$HOME_DIR/sessions"
mkdir -p "$HOME_DIR/sessions"
write_patch "$PRESENT, subagnt_fast" typo
b_out="$(run_probe)"
b_rc=$?
printf '%s\n' "$b_out" | grep -i 'subagnt_fast\|toolFilter\|^Error' | head -4 | sed 's/^/    | /'
if printf '%s' "$b_out" | grep -q "subagnt_fast"; then
  ok "the typo is named in the failure"
else
  bad "the typo was never reported (exit $b_rc) — silent-outage risk"
fi
if printf '%s' "$b_out" | grep -q 'toolFilter names a tool' &&
  printf '%s' "$b_out" | grep -q 'absent from the child catalog' &&
  printf '%s' "$b_out" | grep -qi 'tool-subagent'; then
  ok "the failure names the offending loader row"
else
  bad "the failure does not identify the row (exit $b_rc)"
fi
if [ "$(child_tools)" = "NONE" ]; then
  ok "no child session was created on the poisoned filter (exit $b_rc)"
else
  bad "a child spawned despite the typo — the bug is present"
fi
echo

if [ "$fail" -eq 0 ]; then
  echo "bug-007 live probe: PASS (both variants)"
else
  echo "bug-007 live probe: FAIL"
fi
echo "scratch home kept for inspection: $SCRATCH"
exit "$fail"
