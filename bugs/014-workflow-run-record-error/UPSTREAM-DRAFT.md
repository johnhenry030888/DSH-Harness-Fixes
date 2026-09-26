# Upstream draft — bug 014

Status: **NOT-FILED** (Discussion post ready to paste.)

---

**Title:** `tool-workflow/agent-end` records `outcome: failed` with no error and
no requested route

**Body:**

A rejected model pin inside a workflow produces

```
tool-workflow/agent-start {"runId":"…","seq":1,"label":"reject-pin","childId":"…"}
tool-workflow/agent-end   {"runId":"…","seq":1,"outcome":"failed"}
```

The child's own `turn/end` already carries the failure
(`{"kind":"error","error":{"message":"pi-ai provider \"opencode-go\" has no
configured model \"glm-5.3-flash\"","code":"UNKNOWN_MODEL"}}`), but:

1. the in-process driver's `readResult` never populates
   `SubagentResult.diagnostic` (the seam's field for exactly this);
2. the worker-thread host drops `diagnostic` when forwarding `ChildSettled`;
3. `agent-start`/`agent-end` never carry the requested provider/model;
4. the `tool-workflow` recorder persists only the four identity fields.

Proposal: render the turn failure into `diagnostic`, forward it, attach
`error` + `requestedProvider`/`requestedModel` to `workflow/agent-start`/
`agent-end`, and persist them in `tool-workflow/*`. A failed pin is then
attributable from the run record alone. (The script still receives `null` from
`agent()` per the documented contract; this is about the record.)
