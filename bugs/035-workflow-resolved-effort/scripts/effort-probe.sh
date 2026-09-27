#!/bin/bash
# Live probe for bug 035 — the workflow run record must carry the resolved
# reasoning effort and its provenance, and every adapter's request header must
# carry an explicit `reasoningEffort` key.
#
# It boots the shipped headless profile in a **scratch harness home** (the real
# `~/.dsh` is read, never written; everything this script creates lives under
# `$SCRATCH`, default `/tmp/orch-drill-035`), asks the lead for one three-stage
# workflow (two different pinned models + one route-inheriting stage), then:
#   1. asserts every `tool-workflow/agent-start` record carries
#      `resolvedEffort` + `effortSource`;
#   2. prints each stage child's `request/header.config.reasoningEffort`
#      (longcat-2.0 and deepseek-v4-flash pins must show a key).
#
# Exit 0 = both assertions hold. Requires `dsh` on PATH and a working route.
set -u
REAL_HOME="${DSH_REAL_HOME:-$HOME/.dsh}"
SCRATCH="${SCRATCH:-/tmp/orch-drill-035}"
HOME_DIR="$SCRATCH/home"
TIMEOUT="${PROBE_TIMEOUT:-420}"

PROMPT='Call the workflow tool exactly once. Run three sequential agent() stages with trivial prompts ("Reply with exactly the single word OK and nothing else."): stage 1 pinned with provider "opencode-go" and model "longcat-2.0"; stage 2 pinned with provider "opencode-go" and model "deepseek-v4-flash"; stage 3 with no provider/model so it inherits your route. Label the stages stage-one, stage-two, stage-three. After the workflow returns, reply with exactly: EFFORT-PROBE-DONE'

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

echo "bug 035 live probe — scratch home $HOME_DIR"
echo
out="$(DSH_HOME="$HOME_DIR" timeout "$TIMEOUT" dsh --profile headless "$PROMPT" 2>&1)"
rc=$?
printf '%s\n' "$out" | tail -4 | sed 's/^/    | /'
if ! printf '%s' "$out" | grep -q "EFFORT-PROBE-DONE"; then
  echo "  FAIL  the lead did not complete the probe run (exit $rc)"
  exit 1
fi
echo "  PASS  the lead completed the workflow run"
echo

python3 - "$HOME_DIR/sessions" <<'PY'
import glob, json, os, subprocess, sys

root = sys.argv[1]
records = {}
for path in glob.glob(os.path.join(root, "**", "session.v3.jsonl.zstd"), recursive=True):
    text = subprocess.run(["zstd", "-dc", path], capture_output=True).stdout.decode("utf8", "replace")
    events = []
    for line in text.splitlines():
        try:
            events.append(json.loads(line))
        except Exception:
            pass
    if events:
        records[path] = events

starts = []
headers = []
for path, events in records.items():
    header_seen = False
    for event in events:
        if event.get("type") == "tool-workflow/agent-start":
            starts.append(event["data"])
        if not header_seen and event.get("type") == "request/header":
            headers.append((path, event["data"]["header"]["config"]))
            header_seen = True

print("agent-start records:")
for start in starts:
    print(f"  seq={start.get('seq')} label={start.get('label')} "
          f"requested={start.get('requestedProvider')}/{start.get('requestedModel')} "
          f"resolvedEffort={start.get('resolvedEffort')!r} effortSource={start.get('effortSource')!r}")
print()
print("child request headers:")
for path, config in headers:
    print(f"  {config.get('provider')}/{config.get('model')} reasoningEffort={config.get('reasoningEffort')!r}")

fail = 0
def check(name, ok, detail=""):
    global fail
    if ok:
        print(f"  PASS  {name}")
    else:
        print(f"  FAIL  {name} {detail}")
        fail = 1

check("at least three agent-start records", len(starts) >= 3, f"got {len(starts)}")
check(
    "every agent-start record carries resolvedEffort + effortSource",
    all("resolvedEffort" in start and "effortSource" in start for start in starts),
)
check(
    "the route-inheriting stage records the lead's effort as inherited",
    any(start.get("effortSource") == "inherited" and start.get("resolvedEffort") == "max" for start in starts),
    [ (s.get("resolvedEffort"), s.get("effortSource")) for s in starts ],
)
check(
    "a route-changed stage records the adapter default",
    any(start.get("effortSource") == "default" for start in starts),
)
check(
    "every child request header carries a reasoningEffort key",
    len(headers) >= 3 and all("reasoningEffort" in config for _, config in headers),
    [config.get("reasoningEffort") for _, config in headers],
)
check(
    "the longcat-2.0 pin shows a concrete value or the default marker",
    any(config.get("model") == "longcat-2.0" and isinstance(config.get("reasoningEffort"), str) and config.get("reasoningEffort") != "" for _, config in headers),
)
sys.exit(fail)
PY
probe_rc=$?
if [ "$probe_rc" -eq 0 ]; then
  echo
  echo "bug-035 live probe: PASS"
else
  echo
  echo "bug-035 live probe: FAIL"
fi
echo "scratch home kept for inspection: $SCRATCH"
exit "$probe_rc"
