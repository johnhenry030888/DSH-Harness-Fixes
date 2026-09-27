#!/bin/bash
# Live probe for bug 037 — `agent(prompt, { effort })` must pin a workflow
# stage's reasoning effort, record it on the run record, and reject an
# unadvertised effort with the platform's own code.
#
# It boots the shipped headless profile in a **scratch harness home** (the real
# `~/.dsh` is read, never written; everything this script creates lives under
# `$SCRATCH`, default `/tmp/orch-drill-037`), asks the lead for one four-stage
# workflow, then asserts:
#   1. stage-one   — pinned longcat-2.0 @ low: `requestedEffort`/`resolvedEffort`
#      "low" with `effortSource: "pinned"`, and a child header at "low";
#   2. stage-two   — no effort: `effortSource: "inherited"` at the lead's max,
#      and a child header at "max";
#   3. stage-three — an unadvertised effort: the stage fails loudly with the
#      platform's `UNSUPPORTED_REASONING_EFFORT` code (run record + script catch);
#   4. stage-four  — `effort: 5` (not a string): INVALID_ARGUMENT naming `effort`,
#      and no child start record.
#
# Exit 0 = every assertion holds. Requires `dsh` on PATH and a working route.
set -u
REAL_HOME="${DSH_REAL_HOME:-$HOME/.dsh}"
SCRATCH="${SCRATCH:-/tmp/orch-drill-037}"
HOME_DIR="$SCRATCH/home"
TIMEOUT="${PROBE_TIMEOUT:-600}"

PROMPT='Call the workflow tool exactly once with meta {"name":"effort-option-probe","description":"probe the agent() effort option"} and this exact script body (copy it verbatim, add nothing):

const out = {};
try { out.stage1 = await agent("Reply with exactly the single word OK.", { label: "stage-one", provider: "opencode-go", model: "longcat-2.0", effort: "low" }); } catch (error) { out.stage1Error = { code: error.code, message: error.message }; }
try { out.stage2 = await agent("Reply with exactly the single word OK.", { label: "stage-two" }); } catch (error) { out.stage2Error = { code: error.code, message: error.message }; }
try { out.stage3 = await agent("Reply with exactly the single word OK.", { label: "stage-three", provider: "opencode-go", model: "longcat-2.0", effort: "extreme" }); } catch (error) { out.stage3Error = { code: error.code, message: error.message }; }
try { out.stage4 = await agent("Reply with exactly the single word OK.", { label: "stage-four", effort: 5 }); } catch (error) { out.stage4Error = { code: error.code, message: error.message }; }
return out;

After the tool returns, reply with exactly one line: EFFORT-OPTION-PROBE-DONE followed by the workflow tool result value (its result field) as compact JSON. Do not call any other tool.'

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

echo "bug 037 live probe — scratch home $HOME_DIR"
echo
out="$(DSH_HOME="$HOME_DIR" timeout "$TIMEOUT" dsh --profile headless "$PROMPT" 2>&1)"
rc=$?
printf '%s\n' "$out" | tail -6 | sed 's/^/    | /'
if ! printf '%s' "$out" | grep -q "EFFORT-OPTION-PROBE-DONE"; then
  echo "  FAIL  the lead did not complete the probe run (exit $rc)"
  exit 1
fi
echo "  PASS  the lead completed the workflow run"
echo

printf '%s' "$out" >"$SCRATCH/lead-output.txt"
python3 - "$SCRATCH" <<'PY'
import glob, json, os, subprocess, sys

def events_of(path):
    text = subprocess.run(["zstd", "-dc", path], capture_output=True).stdout.decode("utf8", "replace")
    events = []
    for line in text.splitlines():
        try:
            events.append(json.loads(line))
        except Exception:
            pass
    return events

scratch = sys.argv[1]
root = os.path.join(scratch, "home", "sessions")
records = {path: events_of(path) for path in glob.glob(os.path.join(root, "**", "session.v3.jsonl.zstd"), recursive=True)}
records = {path: events for path, events in records.items() if events}

starts, ends, headers = [], [], []
for path, events in records.items():
    is_lead = any(event.get("type") == "tool-workflow/agent-start" for event in events)
    header_seen = False
    for event in events:
        if event.get("type") == "tool-workflow/agent-start":
            starts.append(event["data"])
        if event.get("type") == "tool-workflow/agent-end":
            ends.append(event["data"])
        if not is_lead and not header_seen and event.get("type") == "request/header":
            headers.append((path, event["data"]["header"]["config"]))
            header_seen = True

lead_output = open(scratch + "/lead-output.txt", encoding="utf8", errors="replace").read()
marker = lead_output.rfind("EFFORT-OPTION-PROBE-DONE")
payload = None
if marker != -1:
    tail = lead_output[marker + len("EFFORT-OPTION-PROBE-DONE"):]
    start, end = tail.find("{"), tail.rfind("}")
    if start != -1 and end > start:
        try:
            payload = json.loads(tail[start:end + 1])
        except Exception:
            payload = None

print("agent-start records:")
for start in starts:
    print(f"  seq={start.get('seq')} label={start.get('label')} "
          f"requested={start.get('requestedProvider')}/{start.get('requestedModel')} "
          f"requestedEffort={start.get('requestedEffort')!r} "
          f"resolvedEffort={start.get('resolvedEffort')!r} effortSource={start.get('effortSource')!r}")
print("agent-end records:")
for end in ends:
    print(f"  seq={end.get('seq')} outcome={end.get('outcome')} errorCode={end.get('errorCode')!r}")
print("workflow return value (from the lead's final line):")
print(f"  {json.dumps(payload, sort_keys=True)}")
print("child request headers:")
for path, config in headers:
    print(f"  {config.get('provider')}/{config.get('model')} reasoningEffort={config.get('reasoningEffort')!r}")
print()

fail = 0
def check(name, ok, detail=""):
    global fail
    if ok:
        print(f"  PASS  {name}")
    else:
        print(f"  FAIL  {name} {detail}")
        fail = 1

by_label = {start.get("label"): start for start in starts}
end_by_seq = {end.get("seq"): end for end in ends}
s1, s2, s3 = by_label.get("stage-one"), by_label.get("stage-two"), by_label.get("stage-three")

check("exactly three children started (stage-four never spawns)",
      sorted(by_label) == ["stage-one", "stage-three", "stage-two"], sorted(by_label))
check("stage-one records requestedEffort/resolvedEffort low with effortSource pinned",
      s1 is not None and s1.get("requestedEffort") == "low" and s1.get("resolvedEffort") == "low" and s1.get("effortSource") == "pinned",
      s1)
check("stage-two records no requestedEffort and the lead's max as inherited",
      s2 is not None and "requestedEffort" not in s2 and s2.get("resolvedEffort") == "max" and s2.get("effortSource") == "inherited",
      s2)
check("stage-three records the requested extreme effort as pinned and fails with the platform code",
      s3 is not None and s3.get("requestedEffort") == "extreme" and s3.get("effortSource") == "pinned"
      and end_by_seq.get(s3.get("seq"), {}).get("outcome") == "failed"
      and end_by_seq.get(s3.get("seq"), {}).get("errorCode") == "UNSUPPORTED_REASONING_EFFORT",
      (s3, end_by_seq.get(s3.get("seq")) if s3 else None))
check("stage-three's failure names the advertised ladder",
      isinstance(end_by_seq.get(s3.get("seq"), {}).get("error"), str)
      and "does not support reasoning effort" in end_by_seq[s3["seq"]]["error"],
      end_by_seq.get(s3.get("seq"), {}).get("error"))
longcat_headers = [config for _, config in headers if config.get("model") == "longcat-2.0"]
check("exactly two child headers exist (stage-three failed before its header)",
      len(headers) == 2, [(config.get("model"), config.get("reasoningEffort")) for _, config in headers])
check("a longcat-2.0 child header carries reasoningEffort low",
      any(config.get("reasoningEffort") == "low" for config in longcat_headers),
      [config.get("reasoningEffort") for config in longcat_headers])
check("the route-inheriting child header carries the lead's max",
      any(config.get("reasoningEffort") == "max" and config.get("model") == "deepseek-v4.1-flash" for _, config in headers),
      [(config.get("model"), config.get("reasoningEffort")) for _, config in headers])
check("stage-four rejects effort:5 with INVALID_ARGUMENT naming the option",
      isinstance(payload, dict)
      and payload.get("stage4Error", {}).get("code") == "INVALID_ARGUMENT"
      and "effort" in payload.get("stage4Error", {}).get("message", ""),
      payload.get("stage4Error") if isinstance(payload, dict) else payload)
check("both positive stages returned the child's text and the negative stages returned no text",
      isinstance(payload, dict) and isinstance(payload.get("stage1"), str) and payload["stage1"].strip() == "OK"
      and isinstance(payload.get("stage2"), str) and payload["stage2"].strip() == "OK"
      and "stage3" not in payload and "stage4" not in payload,
      payload if not isinstance(payload, dict) else {k: payload.get(k) for k in ("stage1", "stage2", "stage3Error", "stage4Error")})
sys.exit(fail)
PY
probe_rc=$?
if [ "$probe_rc" -eq 0 ]; then
  echo
  echo "bug-037 live probe: PASS"
else
  echo
  echo "bug-037 live probe: FAIL"
fi
echo "scratch home kept for inspection: $SCRATCH"
exit "$probe_rc"
