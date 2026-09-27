# Upstream draft — bug 032

Status: **NOT-FILED** (Discussion post ready to paste.)

---

**Title:** The inspection guard harvests every path a prompt mentions and
reports collapsed ancestors, refusing genuinely disjoint reviews

**Body:**

The 023/026 ordering guard derives a writer's "declared work" by scanning its
first prompt for absolute paths. The scanner has no notion of context: it
counts prohibition mentions ("do not write /tmp"), sentinel/scratch/timestamp
mentions (`/tmp/v26_tstart`), and every ancestor a prompt names as context
alongside the real targets. The refusal then reports those as the writer's
declared work, and — because the whole set participates in the overlap test —
genuinely disjoint read scopes get refused.

Evidence, both directions: drill v21 §4.2 and v23 §4.2 report the collapse to
a common ancestor; drill v26 §5/Appendix A2 reports the drill ROOT as the
writer's declared work while the real targets were subpaths; drill v26
§5/Appendix A3 refuses a read scope that only intersects a timestamp sentinel
the writer touched (`/tmp/v26_tstart`). Two drills lost a whole wave to false
refusals.

Proposal:

1. Harvest declared **work**, not every path: drop a mention whose local
   context carries a prohibition verb, a read-only framing, or a
   sentinel/scratch/timestamp/marker purpose.
2. Keep the **most specific** path per mention chain: an ancestor declared
   alongside a strict descendant is context, not the target.
3. Refuse only when a declared reader path overlaps a declared writer path;
   name the actual pair (writer id + writer path + reader path) and the
   decision basis in the message, and keep the existing retry guidance.
