#!/bin/bash
# Live probe for bug 036 — a live child's `list_agents` row must render the
# tree its delegation prompt DECLARED (labelled `declared`), not the session
# cwd, and must still carry `checkedAt` and `filePolicy`.
#
# It boots the shipped headless profile in a **scratch harness home** (the real
# `~/.dsh` is read, never written; everything lives under `$SCRATCH`, default
# `/tmp/orch-drill-036`), starts one continuable child told to write an
# absolute drill subpath, then reads the lead's `list_agents` tool result.
#
# Exit 0 = the declared path and the row fields are present. Requires `dsh`.
set -u
REAL_HOME="${DSH_REAL_HOME:-$HOME/.dsh}"
SCRATCH="${SCRATCH:-/tmp/orch-drill-036}"
HOME_DIR="$SCRATCH/home"
TARGET="$SCRATCH/declared/sub/file.txt"
TIMEOUT="${PROBE_TIMEOUT:-240}"

PROMPT="Call the subagent tool exactly once with run_in_background true, description \"tree probe\", prompt \"Write the file ${TARGET} with the single line hi. Then reply DONE.\". Then call list_agents once and repeat every row text verbatim, then reply TREE-PROBE-DONE"

command -v dsh >/dev/null 2>&1 || {
  echo "probe: dsh is not on PATH"
  exit 1
}
[ -f "$REAL_HOME/settings.yaml" ] || {
  echo "probe: real harness home $REAL_HOME has no settings.yaml"
  exit 1
}

rm -rf "$SCRATCH"
mkdir -p "$HOME_DIR/sessions" "$HOME_DIR/attachments"
cp "$REAL_HOME/settings.yaml" "$HOME_DIR/settings.yaml"
for link in .credentials.yaml .anonymous-user-id storages profiles; do
  [ -e "$REAL_HOME/$link" ] || continue
  ln -s "$REAL_HOME/$link" "$HOME_DIR/$link"
done

echo "bug 036 live probe — scratch home $HOME_DIR"
echo
out="$(DSH_HOME="$HOME_DIR" timeout "$TIMEOUT" dsh --profile headless "$PROMPT" 2>&1)"
rc=$?
printf '%s\n' "$out" | tail -4 | sed 's/^/    | /'
if ! printf '%s' "$out" | grep -q "TREE-PROBE-DONE"; then
  echo "  FAIL  the lead did not complete the probe run (exit $rc)"
  exit 1
fi
echo

python3 - "$HOME_DIR/sessions" "$TARGET" <<'PY'
import glob, json, os, re, subprocess, sys

root, target = sys.argv[1], sys.argv[2]
row_text = None
for path in glob.glob(os.path.join(root, "**", "session.v3.jsonl.zstd"), recursive=True):
    text = subprocess.run(["zstd", "-dc", path], capture_output=True).stdout.decode("utf8", "replace")
    for line in text.splitlines():
        try:
            record = json.loads(line)
        except Exception:
            continue
        if record.get("type") != "tool/result":
            continue
        def flatten(blocks):
            out = []
            for block in blocks:
                if block.get("type") == "text":
                    out.append(block.get("text", ""))
                elif block.get("type") == "tool-result":
                    out.extend(flatten(block.get("content", [])))
            return out
        text_value = "".join(flatten(record["data"].get("message", {}).get("content", [])))
        if "[running as of" in text_value or "[idle as of" in text_value or "[ready as of" in text_value:
            row_text = text_value

print(f"  list_agents row: {row_text!r}")
fail = 0
def check(name, ok, detail=""):
    global fail
    if ok:
        print(f"  PASS  {name}")
    else:
        print(f"  FAIL  {name} {detail}")
        fail = 1

check("the row renders the declared target path", row_text is not None and target in row_text, row_text)
check("the row labels the declared basis", row_text is not None and "(declared)" in row_text, row_text)
check("the row keeps the file policy", row_text is not None and ("writes" in row_text or "read-only" in row_text), row_text)
check("the row keeps checkedAt", row_text is not None and re.search(r"as of \d{4}-\d{2}-\d{2}T", row_text) is not None, row_text)
sys.exit(fail)
PY
probe_rc=$?
if [ "$probe_rc" -eq 0 ]; then
  echo
  echo "bug-036 live probe: PASS"
else
  echo
  echo "bug-036 live probe: FAIL"
fi
echo "scratch home kept for inspection: $SCRATCH"
exit "$probe_rc"
