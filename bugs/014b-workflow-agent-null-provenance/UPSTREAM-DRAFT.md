# Upstream draft — bug 014b

Status: **NOT-FILED** (follow-up to the bug-014 discussion; ready to paste.)

---

**Title:** workflow `agent()` still returns a bare `null` on a rejected pin —
document the run-record lookup in the tool description

**Body:**

With `agent-end` now carrying `error` + `requestedProvider`/`requestedModel`
(014), a rejected pin inside a workflow is attributable from the run record —
but the script itself still receives `null`, indistinguishable from "the
child returned nothing":

```json
{"runId":"a75834b3-…","seq":1,"outcome":"failed",
 "error":"pi-ai provider \"opencode-go\" has no configured model \"glm-5.3-flash\" (UNKNOWN_MODEL)",
 "requestedProvider":"opencode-go","requestedModel":"glm-5.3-flash"}
```

The tool description's `agent()` bullet said only "Resolves `null` when the
child fails (filter with `.filter(Boolean)`).", so the script author is never
told where the precise failure went.

Proposal (documentation-only, no engine change): extend that sentence to say
the `null` deliberately says nothing about why, and that attribution is read
from the run record — the `workflow/agent-start`/`agent-end` records in the
caller's run history, where `agent-end` carries the `error` diagnostic plus
the requested provider/model on a pre-output failure.

Changing the return value to a discriminated result was considered and
rejected here: scripts rely on the documented `null` + `filter(Boolean)`
contract, so a typed failure (if wanted) is an engine API decision with its
own versioning.
