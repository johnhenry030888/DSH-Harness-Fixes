#!/bin/bash
# Live probe for bug 040 — a read-only delegation that declares a /tmp scratch
# path must be admitted while a writer is live (not refused as maximally
# scoped), must be refused naming the pair when the declared paths overlap the
# live writer, and must be admitted after the writer settles.
#
# It boots the shipped headless profile in a scratch harness home (the real
# ~/.dsh is read, never written) with one `--patch` overlay that ADDS a
# read-only delegation row (bug 019 row config `readOnly: true`), starts a
# write-capable background child that declares /tmp/dsh040-live/writer.txt,
# and then runs the three read-only delegations.
#
# Exit 0 = all three tool results and the durable inspection-scope records
# match. Requires `dsh` on PATH and a working route.
set -u
REAL_HOME="${DSH_REAL_HOME:-$HOME/.dsh}"
SCRATCH="${SCRATCH:-/tmp/orch-drill-040}"
HOME_DIR="$SCRATCH/home"
TIMEOUT="${PROBE_TIMEOUT:-600}"
fail=0

command -v dsh >/dev/null 2>&1 || {
  echo "probe: dsh is not on PATH"
  exit 1
}
[ -f "$REAL_HOME/settings.yaml" ] || {
  echo "probe: real harness home $REAL_HOME has no settings.yaml"
  exit 1
}

rm -rf "$SCRATCH" /tmp/dsh040-live
mkdir -p "$HOME_DIR/sessions" "$HOME_DIR/attachments" /tmp/dsh040-live
cp "$REAL_HOME/settings.yaml" "$HOME_DIR/settings.yaml"
for link in .credentials.yaml .anonymous-user-id storages profiles; do
  [ -e "$REAL_HOME/$link" ] || continue
  ln -s "$REAL_HOME/$link" "$HOME_DIR/$link"
done

cat >"$SCRATCH/reader-scope.yml" <<'YAML'
# Add one read-only delegation row on top of the headless profile's
# write-capable `subagent` row (bug 019 row config).
- insert:
    - id: tool-subagent-readonly
      name: '@deepseek-ai/dsh-tool-subagent'
      config:
        provider: spawn
        toolName: subagent_read
        backgroundMode: continuable
        readOnly: true
        boxSeconds: 120
YAML

# The probe prompt is a literal single-quoted template: its backticks and
# \n escapes must reach dsh verbatim, so no shell expansion is intended.
# shellcheck disable=SC2016
PROMPT='You are a mechanical probe; follow the steps exactly in order and immediately, with no reflection between steps: the writer from step 1 is only live for 180 seconds, and steps 2 and 3 must execute while it sleeps.

Step 1. Call subagent once with description "040 live writer", run_in_background true, box_seconds 240, and this prompt: "Write the single line writer-start to /tmp/dsh040-live/writer.txt using the write tool, then call bash with the command `sleep 180`, then reply with exactly WRITER-DONE." Record the returned subagentId.

Step 2. Call subagent_read once with description "040 reader disjoint", run_in_background false, and this prompt: "Read scope: /tmp/dsh040-live/readers\nReply with exactly READ-ADMITTED-DISJOINT". If it returns normally, quote it verbatim as RESULT-DISJOINT: <result>. If it is refused with INSPECTION_CONFLICT, quote the refusal verbatim as RESULT-DISJOINT-REFUSED: <message>.

Step 3. Call subagent_read once with description "040 reader overlap", run_in_background false, and this prompt: "Read scope: /tmp/dsh040-live/writer.txt\nReply with exactly READ-OVERLAP". Quote the result verbatim as RESULT-OVERLAP: <result or error message>.

Step 4. Call interrupt_agent with the subagentId from step 1.

Step 5. Call bash with command `sleep 10`, then call list_agents. If the writer still shows as running, repeat the sleep 10 + list_agents up to 3 more times until it is settled.

Step 6. Call subagent_read once with description "040 reader after settle", run_in_background false, and this prompt: "Read scope: /tmp/dsh040-live/writer.txt\nReply with exactly READ-ADMITTED-AFTER". Quote the result verbatim as RESULT-AFTER: <result or error message>.

Step 7. Reply with exactly the RESULT lines from steps 2, 3 and 6, nothing else.'

echo "bug 040 live probe — scratch home $HOME_DIR"
echo
out="$(DSH_HOME="$HOME_DIR" timeout "$TIMEOUT" dsh --profile headless --patch "$SCRATCH/reader-scope.yml" "$PROMPT" 2>&1)"
rc=$?
printf '%s\n' "$out" | grep -E "RESULT-|refused a read-only|READ-ADMITTED" | head -12 | sed 's/^/    | /'
if [ "$rc" -ne 0 ]; then
  echo "  FAIL  dsh exited $rc"
  fail=1
fi

assert_contains() {
  local name="$1" needle="$2"
  if printf '%s' "$out" | grep -qF "$needle"; then
    echo "  PASS  $name"
  else
    echo "  FAIL  $name (missing: $needle)"
    fail=1
  fi
}

assert_contains "disjoint /tmp declaration admitted while the writer is live" "READ-ADMITTED-DISJOINT"
assert_contains "overlapping declaration refused" "refused a read-only delegation while write-capable"
assert_contains "refusal names the declared writer pair" "/tmp/dsh040-live/writer.txt"
assert_contains "refusal keeps scopeBasis declared" "scopeBasis: declared"
assert_contains "the same declaration admitted after settlement" "READ-ADMITTED-AFTER"
# Pre-fix, step 2's disjoint declaration was refused as maximally scoped: the
# maximal refusal text is the one string that must never appear in this run.
if printf '%s' "$out" | grep -q "declared no read scope"; then
  echo "  FAIL  a maximal refusal occurred (the v27 F2 bug)"
  fail=1
else
  echo "  PASS  no maximal-scope refusal in the run"
fi

# Durable records: read the parent transcript with the bug-039 reader.
DRILL="$(cd "$(dirname "$0")/../.." && pwd)"
RECORDS="$DRILL/039-session-record-reader/scripts/dsh-records.mjs"
PARENT_SID=""
for f in "$HOME_DIR"/sessions/*/*/session.v3.jsonl.zstd; do
  [ -e "$f" ] || continue
  if zstd -dc -- "$f" | grep -q '"type":"subagent/inspection-scope"'; then
    PARENT_SID="$(basename "$(dirname "$f")")"
    break
  fi
done

if [ -z "$PARENT_SID" ]; then
  echo "  FAIL  no parent transcript carries the refusal (store: $HOME_DIR/sessions)"
  fail=1
elif [ ! -x "$RECORDS" ]; then
  echo "  FAIL  the bug-039 reader is not executable: $RECORDS"
  fail=1
else
  echo "  -- durable subagent/inspection-scope records (via bug-039 reader)"
  node "$RECORDS" --session "$PARENT_SID" --home "$HOME_DIR" --records subagent/inspection-scope --json \
    >"$SCRATCH/inspection-scope.json" 2>"$SCRATCH/records.err" || {
    echo "  FAIL  dsh-records could not read $PARENT_SID"
    sed 's/^/    | /' "$SCRATCH/records.err"
    fail=1
  }
  if [ -s "$SCRATCH/inspection-scope.json" ]; then
    if node - "$SCRATCH/inspection-scope.json" <<'NODE'; then
const fs = require("node:fs");
const rows = JSON.parse(fs.readFileSync(process.argv[2], "utf8")).records;
const refused = rows.find((row) => row.data.outcome === "refused");
const disjoint = rows.find(
  (row) =>
    row.data.outcome === "admitted" && JSON.stringify(row.data.readTrees) === JSON.stringify(["/tmp/dsh040-live/readers"]),
);
const after = rows.find(
  (row) =>
    row.data.outcome === "admitted" && JSON.stringify(row.data.readTrees) === JSON.stringify(["/tmp/dsh040-live/writer.txt"]),
);
const checks = [
  [refused !== undefined && refused.data.scopeBasis === "declared", "refused record is scopeBasis declared"],
  [
    refused !== undefined &&
      JSON.stringify(refused.data.readTrees) === JSON.stringify(["/tmp/dsh040-live/writer.txt"]) &&
      refused.data.conflicts.some((conflict) => conflict.writerTree === "/tmp/dsh040-live/writer.txt"),
    "refused record carries the declared pair",
  ],
  [disjoint !== undefined, "admitted record for /tmp/dsh040-live/readers"],
  [after !== undefined, "admitted record for /tmp/dsh040-live/writer.txt after settlement"],
];
let bad = 0;
for (const [pass, name] of checks) {
  console.log(`  ${pass ? "PASS" : "FAIL"}  ${name}`);
  if (!pass) bad = 1;
}
process.exit(bad);
NODE
      :
    else
      fail=1
    fi
  fi
fi

if [ "$fail" -ne 0 ]; then
  echo "READER-SCOPE-PROBE FAIL"
  exit 1
fi
echo "READER-SCOPE-PROBE PASS"
