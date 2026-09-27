# Upstream draft — bug 036

Status: **NOT-FILED** (Discussion post ready to paste.)

---

**Title:** `list_agents` renders the session cwd instead of the delegation's
declared tree, and settled rows carry no tree or policy at all

**Body:**

The ordering guard (023/026) keys on the absolute paths a delegation's prompt
declares; `list_agents` does not. Its rows render `live.session.header.cwd`,
so six drills (v16 F2, v17 §5, v20 F2, v21 §5 item 4, v22 §5 item 4, v26 §5
item 4) read a lane as working in the lead's workspace while its declared
target was a drill subpath. v26 additionally observed all 11 direct children
settled with **only id + status + label** — no tree, no file policy — so the
key property of the ordering rule is invisible exactly when a caller sequences
the next wave.

Proposal:

1. Expose the guard's own declared-work harvester on the subagent service
   (`declaredWorkOf(agent) → {trees, basis}`) and render the declared tree in
   each row with its basis (`declared` vs the `cwd` fallback), instead of the
   session cwd.
2. Keep `filePolicy` for live rows, and state in the tool description that a
   settled row carries no `filePolicy` (predictable presence rather than a
   silent omission).
3. Do not change the row's id/status/`checkedAt` shape; the tree fields are
   optional additions.
