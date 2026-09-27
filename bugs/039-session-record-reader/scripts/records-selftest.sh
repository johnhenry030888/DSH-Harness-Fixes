#!/bin/bash
# Self-test for dsh-records.mjs (bug 039). Builds a scratch DSH_HOME with a
# tiny TWO-FRAME transcript (plus a child transcript), reads it back offline,
# and asserts the multi-frame read, per-type counts, the single-count usage
# rule, the node frame-loop fallback and the honest failures.
#
# Exit 0 = every assertion holds; 1 = the reader regressed.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/dsh-records.mjs"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/dsh-records-selftest.XXXXXX")"
[ "${KEEP_TMP:-0}" = "1" ] || trap 'rm -rf "$TMP"' EXIT
[ "${KEEP_TMP:-0}" = "1" ] && printf "selftest scratch: %s\n" "$TMP"
HOME_DIR="$TMP/home"
PARENT="11111111-1111-4111-8111-111111111111"
CHILD="aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
EMPTY="22222222-2222-4222-8222-222222222222"
BUCKET="--selftest-scratch--"
fail=0

note() { printf '%s\n' "$1"; }
ok() {
  if [ "$1" -eq 0 ]; then
    note "ok: $2"
  else
    note "FAIL: $2"
    fail=1
  fi
}

[ -x "$SCRIPT" ] || {
  note "FAIL: $SCRIPT is not executable"
  exit 1
}

# --- fixture: two zstd frames concatenated (the truncation trap) -----------
node - "$TMP" "$PARENT" "$CHILD" "$EMPTY" "$BUCKET" <<'NODE'
const fs = require("node:fs");
const path = require("node:path");
const { zstdCompressSync } = require("node:zlib");
const [tmp, parent, child, empty, bucket] = process.argv.slice(2);
function writeSession(id, frames, parentSession) {
  const dir = path.join(tmp, "home", "sessions", bucket, `session-${id}`);
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(
    path.join(dir, "session.v3.jsonl.zstd"),
    Buffer.concat(frames.map((lines) => zstdCompressSync(Buffer.from(lines.join("\n") + "\n")))),
  );
  if (parentSession !== undefined) {
    fs.appendFileSync(path.join(dir, "session.lock"), "");
  }
}
const parentFrame1 = [
  JSON.stringify({ type: "session", version: 3, id: `session-${parent}`, cwd: "/tmp/selftest-workspace", delegationDepth: 0 }),
  JSON.stringify({ type: "turn/start", seq: 0, time: 1000, data: { turn: 1 } }),
  JSON.stringify({ type: "request/header", seq: 1, time: 1001, data: { header: { config: { provider: "probe-provider", model: "probe-model", reasoningEffort: "high" }, tools: [{ name: "a" }, { name: "b" }, { name: "c" }] } } }),
  JSON.stringify({ type: "user/message", seq: 2, time: 1002, data: { content: [{ type: "text", text: "read scope: /tmp/selftest" }] } }),
  JSON.stringify({ type: "subagent/catalog", seq: 3, time: 1003, data: { childId: child, mode: "continuable", label: "selftest child" } }),
];
const parentFrame2 = [
  JSON.stringify({
    type: "assistant/message",
    seq: 4,
    time: 1004,
    data: {
      message: { role: "assistant", content: [] },
      usage: { inputTokens: 11, cacheReadTokens: 7, outputTokens: 5 },
      stream: [{ chunk: { usage: { inputTokens: 11, cacheReadTokens: 7, outputTokens: 5 } } }],
    },
  }),
  JSON.stringify({ type: "subagent/box", seq: 5, time: 1005, data: { boxSeconds: 15, elapsedSeconds: 15, hit: true } }),
  JSON.stringify({ type: "subagent/steer-boundary", seq: 6, time: 1006, data: { messageId: "m1", deliveredAt: "T1", boundaryAt: "T2", boundarySeq: 9 } }),
  JSON.stringify({ type: "turn/end", seq: 7, time: 1007, data: { turn: 1 } }),
];
writeSession(parent, [parentFrame1, parentFrame2]);
const childLines = [
  JSON.stringify({ type: "session", version: 3, id: child, cwd: "/tmp/selftest-workspace", parentSession: `session-${parent}`, delegationDepth: 1 }),
  JSON.stringify({ type: "request/header", seq: 0, time: 1010, data: { header: { config: { provider: "probe-provider", model: "child-model", reasoningEffort: "low" }, tools: [{ name: "a" }] } } }),
  JSON.stringify({ type: "assistant/message", seq: 1, time: 1011, data: { message: { role: "assistant", content: [] }, usage: { inputTokens: 3, outputTokens: 2 } } }),
];
writeSession(child, [childLines]);
const emptyLines = [
  JSON.stringify({ type: "session", version: 3, id: `session-${empty}`, cwd: "/tmp/selftest-empty" }),
  JSON.stringify({ type: "turn/start", seq: 0, time: 1020, data: { turn: 1 } }),
  JSON.stringify({ type: "turn/end", seq: 1, time: 1021, data: { turn: 1 } }),
];
writeSession(empty, [emptyLines]);
NODE

run() {
  node "$SCRIPT" "$@"
}

# --- 1. the multi-frame read: frame-2 records are visible ------------------
OUT="$TMP/read.json"
if run --session "$PARENT" --home "$HOME_DIR" --records all --json >"$OUT" 2>"$TMP/err"; then
  node -e '
const j = require(process.argv[1]);
const c = j.session.counts;
const checks = [
  [c["turn/start"] === 1, "frame-1 record counted"],
  [c["subagent/box"] === 1, "frame-2 record counted (multi-frame read)"],
  [c["subagent/steer-boundary"] === 1, "frame-2 steer-boundary counted"],
  [j.session.request.toolCount === 3, "header toolCount is 3"],
  [j.session.request.provider === "probe-provider" && j.session.request.reasoningEffort === "high", "header route fields"],
  [j.session.cwd === "/tmp/selftest-workspace", "session cwd read from the top-level session record"],
  [j.session.compression.frames === 2, "two zstd frames detected"],
  [j.records.length === 9, "records length is 9 with --records all"],
];
let bad = 0;
for (const [pass, name] of checks) if (!pass) { console.log("FAIL: " + name); bad = 1; }
process.exit(bad);
' "$OUT"
  ok $? "multi-frame transcript read"
else
  note "FAIL: read exited $? -- $(cat "$TMP/err")"
  fail=1
fi

# --- 2. usage counts each assistant/message once (stream duplicate) --------
OUT_U="$TMP/usage.json"
if run --session "$PARENT" --home "$HOME_DIR" --usage --json >"$OUT_U" 2>"$TMP/err"; then
  node -e '
const j = require(process.argv[1]);
const d = j.usage.drill;
const checks = [
  [d.inputTokens === 11, "inputTokens counts the stream duplicate once"],
  [d.cacheReadTokens === 7, "cacheReadTokens counted"],
  [d.outputTokens === 5, "outputTokens counted"],
  [d.modelCalls === 1, "modelCalls is 1"],
];
let bad = 0;
for (const [pass, name] of checks) if (!pass) { console.log("FAIL: " + name); bad = 1; }
process.exit(bad);
' "$OUT_U"
  ok $? "usage single-count rule"
else
  note "FAIL: usage exited $? -- $(cat "$TMP/err")"
  fail=1
fi

# --- 3. requested record rows are verbatim ---------------------------------
if run --session "$PARENT" --home "$HOME_DIR" --records subagent/box --json >"$TMP/box.json" 2>"$TMP/err"; then
  node -e '
const j = require(process.argv[1]);
const row = j.records[0];
process.exit(row.type === "subagent/box" && row.data.boxSeconds === 15 && row.data.hit === true ? 0 : 1);
' "$TMP/box.json"
  ok $? "subagent/box row verbatim (boxSeconds/elapsedSeconds/hit)"
else
  note "FAIL: box read exited $? -- $(cat "$TMP/err")"
  fail=1
fi

# --- 4. short id form and the node frame-loop fallback ---------------------
if run --session "session-$PARENT" --home "$HOME_DIR" >/dev/null 2>"$TMP/err"; then
  ok 0 "session id accepted with and without the session- prefix"
else
  note "FAIL: prefixed id read exited $? -- $(cat "$TMP/err")"
  fail=1
fi
if DSH_RECORDS_DECOMPRESS=node run --session "$PARENT" --home "$HOME_DIR" --json >"$TMP/node.json" 2>"$TMP/err"; then
  node -e '
const j = require(process.argv[1]);
process.exit(
  j.session.compression.tool === "node-frame-loop" &&
    j.session.compression.frames === 2 &&
    j.session.counts["subagent/box"] === 1
    ? 0
    : 1,
);
' "$TMP/node.json"
  ok $? "node frame-loop fallback reads both frames"
else
  note "FAIL: node fallback exited $? -- $(cat "$TMP/err")"
  fail=1
fi

# --- 5. --agent and --children beside the parent ---------------------------
if run --session "$PARENT" --home "$HOME_DIR" --agent "$CHILD" --records request/header --json >"$TMP/child.json" 2>"$TMP/err"; then
  node -e '
const j = require(process.argv[1]);
process.exit(
  j.session.sessionId === process.argv[2] &&
    j.session.request.reasoningEffort === "low" &&
    j.records[0].type === "request/header"
    ? 0
    : 1,
);
' "$TMP/child.json" "$CHILD"
  ok $? "--agent reads the child transcript"
else
  note "FAIL: --agent exited $? -- $(cat "$TMP/err")"
  fail=1
fi
if run --session "$PARENT" --home "$HOME_DIR" --usage --children --json >"$TMP/children.json" 2>"$TMP/err"; then
  node -e '
const j = require(process.argv[1]);
const d = j.usage.drill;
const checks = [
  [j.children.length === 1 && j.children[0].reasoningEffort === "low", "per-child header effort"],
  [d.inputTokens === 14 && d.cacheReadTokens === 7 && d.outputTokens === 7 && d.modelCalls === 2, "drill-wide usage adds parent + child"],
  [j.usage.agents.length === 2 && j.usage.agents[0].id !== j.children[0].id, "per-agent rows"],
];
let bad = 0;
for (const [pass, name] of checks) if (!pass) { console.log("FAIL: " + name); bad = 1; }
process.exit(bad);
' "$TMP/children.json"
  ok $? "--children table and drill-wide usage"
else
  note "FAIL: --children exited $? -- $(cat "$TMP/err")"
  fail=1
fi

# --- 6. honest failures -----------------------------------------------------
if run --session "does-not-exist" --home "$HOME_DIR" >"$TMP/miss.out" 2>&1; then
  note "FAIL: a missing session exited 0"
  fail=1
else
  grep -q "tried .*does-not-exist" "$TMP/miss.out"
  ok $? "missing session exits non-zero naming the paths tried"
fi
if run --session "$EMPTY" --home "$HOME_DIR" --records subagent/box >"$TMP/type.out" 2>&1; then
  note "FAIL: a requested absent record type exited 0"
  fail=1
else
  grep -q 'no records of type "subagent/box"' "$TMP/type.out"
  ok $? "requested absent record type exits non-zero naming the type"
fi
if run --session "$PARENT" --home "$TMP/no-home" >/dev/null 2>"$TMP/store.out"; then
  note "FAIL: a missing store exited 0"
  fail=1
else
  grep -q "session store not found" "$TMP/store.out"
  ok $? "missing store exits non-zero naming the store"
fi

if [ "$fail" -ne 0 ]; then
  note "RECORDS-SELFTEST FAIL"
  exit 1
fi
note "RECORDS-SELFTEST PASS"
exit 0
