#!/bin/bash
# Live probe for bug 034 — the steer split must be derivable from the
# transcript: the send_message result carries `deliveredAt`, the child records
# `subagent/steer`, and the step boundary it adopts the steer at is stamped as
# `subagent/steer-boundary`, with deliveredAt <= boundaryAt <= reply time.
#
# It boots the shipped headless profile in a **scratch harness home** (the real
# `~/.dsh` is read, never written; everything lives under `$SCRATCH`, default
# `/tmp/orch-drill-034`), asks the lead to start a background child that sleeps
# 60 s and immediately steer it, then reads both transcripts.
#
# Exit 0 = the three stamps are present and ordered. Requires `dsh` on PATH.
set -u
REAL_HOME="${DSH_REAL_HOME:-$HOME/.dsh}"
SCRATCH="${SCRATCH:-/tmp/orch-drill-034}"
HOME_DIR="$SCRATCH/home"
TIMEOUT="${PROBE_TIMEOUT:-240}"

PROMPT='Call the subagent tool exactly once with run_in_background true, description "steer probe", prompt "Run the bash command: sleep 60 (pass timeout_ms 60000). Then reply DONE." The tool result names a subagent id. Call list_agents once (to confirm the child is running), then call send_message with that agent_id and message "Stop sleeping and reply STEERED now." exactly once. Then call list_agents in a loop, one call at a time, until the child row no longer says running (at most 8 calls) — do not stop early. Then repeat the send_message result text verbatim, then reply STEER-PROBE-DONE'

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
for link in .credentials.yml .credentials.yaml .anonymous-user-id storages profiles; do
  [ -e "$REAL_HOME/$link" ] || continue
  ln -s "$REAL_HOME/$link" "$HOME_DIR/$link"
done

echo "bug 034 live probe — scratch home $HOME_DIR"
echo
out="$(DSH_HOME="$HOME_DIR" timeout "$TIMEOUT" dsh --profile headless "$PROMPT" 2>&1)"
rc=$?
printf '%s\n' "$out" | tail -4 | sed 's/^/    | /'
if ! printf '%s' "$out" | grep -q "STEER-PROBE-DONE"; then
  echo "  FAIL  the lead did not complete the probe run (exit $rc)"
  exit 1
fi
echo

python3 - "$HOME_DIR/sessions" <<'PY'
import glob, json, os, subprocess, sys

root = sys.argv[1]
sessions = {}
for path in glob.glob(os.path.join(root, "**", "session.v3.jsonl.zstd"), recursive=True):
    text = subprocess.run(["zstd", "-dc", path], capture_output=True).stdout.decode("utf8", "replace")
    events = []
    for line in text.splitlines():
        try:
            events.append(json.loads(line))
        except Exception:
            pass
    if events:
        sessions[path] = events

delivered = []
steers = []
boundaries = []
session_of = {}
for path, events in sessions.items():
    for event in events:
        if event.get("type") == "tool/result":
            message = event.get("data", {}).get("message", {})
            def flatten(blocks):
                out = []
                for block in blocks:
                    if block.get("type") == "text":
                        out.append(block.get("text", ""))
                    elif block.get("type") == "tool-result":
                        out.extend(flatten(block.get("content", [])))
                return out
            text = "".join(flatten(message.get("content", [])))
            if "message delivered to agent" in text:
                delivered.append(text)
        if event.get("type") == "subagent/steer":
            steers.append((path, event.get("data")))
        if event.get("type") == "subagent/steer-boundary":
            boundaries.append((path, event))

print(f"  send_message results: {delivered}")
print(f"  subagent/steer:       {[data for _, data in steers]}")
print(f"  steer-boundaries:     {[data.get('data') for _, data in boundaries]}")

fail = 0
def check(name, ok, detail=""):
    global fail
    if ok:
        print(f"  PASS  {name}")
    else:
        print(f"  FAIL  {name} {detail}")
        fail = 1

import re
from datetime import datetime
def to_ms(iso):
    return datetime.fromisoformat(iso.replace("Z", "+00:00")).timestamp() * 1000

stamps = [match.group(1) for text in delivered for match in [re.search(r"deliveredAt (\S+)", text)] if match]
check("the send_message result carries deliveredAt", len(stamps) >= 1, delivered)
check("the child records subagent/steer with deliveredAt/target/messageId",
      len(steers) >= 1 and all(key in steers[-1][1] for key in ("deliveredAt", "target", "messageId")),
      [data for _, data in steers])
check("the child stamps subagent/steer-boundary with boundaryAt/boundarySeq",
      len(boundaries) >= 1 and all("boundaryAt" in event["data"] and "boundarySeq" in event["data"] for _, event in boundaries),
      [data.get("data") for _, data in boundaries])

ordered = None
for stamp in stamps:
    for path, steer in steers:
        if steer.get("deliveredAt") != stamp:
            continue
        for boundary_path, boundary in boundaries:
            if boundary_path != path or to_ms(boundary["data"]["boundaryAt"]) < to_ms(stamp):
                continue
            reply_time = None
            for event in sessions[path]:
                if event.get("seq", 0) > boundary.get("seq", 0) and event.get("type") == "assistant/message":
                    reply_time = event.get("time")
                    break
            if reply_time is not None and to_ms(boundary["data"]["boundaryAt"]) <= reply_time:
                ordered = (stamp, boundary["data"]["boundaryAt"], reply_time)
                break
        if ordered is not None:
            break
    if ordered is not None:
        break
check("a delivery pairs with its child record and an ordered boundary/reply",
      ordered is not None,
      f"stamps={stamps} boundaries={[data.get('data') for _, data in boundaries]}")
if ordered is not None:
    print(f"  ordered triple: deliveredAt={ordered[0]} boundaryAt={ordered[1]} reply={ordered[2]}")
sys.exit(fail)
PY
probe_rc=$?
if [ "$probe_rc" -eq 0 ]; then
  echo
  echo "bug-034 live probe: PASS"
else
  echo
  echo "bug-034 live probe: FAIL"
fi
echo "scratch home kept for inspection: $SCRATCH"
exit "$probe_rc"
