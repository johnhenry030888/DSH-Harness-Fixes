// Module-level check for bug 019: applyChildComposition installs a child-scoped
// guard that refuses edit/write/present with a named, path-aware error when the
// row is read-only, and leaves an unconstrained child alone.
import { applyChildComposition } from "/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-subagent/lib/index.js";

function childCtx() {
  const captured = { guard: undefined, contexts: [], restrictions: [] };
  const ctx = {
    get: () => undefined,
    logger: { warn: () => {} },
    systemPrompt: {
      context: (c) => captured.contexts.push(c),
      section: () => {},
      getContextOrder: () => 118,
      getSectionOrder: () => 0,
    },
    tools: {
      view: () => ({ restrictableNames: new Set(["edit", "write", "present", "bash"]) }),
      restrict: (f) => captured.restrictions.push(f),
      guard: (fn) => (captured.guard = fn),
    },
  };
  return { ctx, captured };
}

const parent = { session: { header: { id: "session-parent-1" } } };
const readOnly = childCtx();
applyChildComposition(
  readOnly.ctx,
  parent,
  { readOnly: true, toolFilter: { deny: ["workflow"] } },
  "child-ro-1",
);

const free = childCtx();
applyChildComposition(free.ctx, parent, {}, "child-free-1");

const editRefusal = readOnly.captured.guard?.({
  name: "edit",
  arguments: { filePath: "/tmp/lead-owned.md" },
});
const writeRefusal = readOnly.captured.guard?.({
  name: "write",
  arguments: { filePath: "/tmp/lead-owned.md" },
});
const presentRefusal = readOnly.captured.guard?.({ name: "present", arguments: {} });
const bashAllowed = readOnly.captured.guard?.({ name: "bash", arguments: { command: "ls" } });
const freeEdit = free.captured.guard?.({ name: "edit", arguments: { filePath: "/tmp/x" } });

const report = {
  hasReadOnlyGuard: typeof readOnly.captured.guard === "function",
  hasFreeGuard: typeof free.captured.guard === "function",
  editRefusal,
  writeRefusal,
  presentRefusal,
  bashAllowed,
  freeEdit,
  readOnlyContext: readOnly.captured.contexts.find((c) => c.name === "subagent:layer")?.text,
};
console.log(JSON.stringify(report, null, 2));

const ok =
  report.hasReadOnlyGuard &&
  !report.hasFreeGuard &&
  typeof editRefusal === "string" &&
  editRefusal.includes("read-only child") &&
  editRefusal.includes("/tmp/lead-owned.md") &&
  editRefusal.includes("allowed write paths: none") &&
  typeof writeRefusal === "string" &&
  writeRefusal.includes("write") &&
  typeof presentRefusal === "string" &&
  bashAllowed === undefined &&
  freeEdit === undefined &&
  report.readOnlyContext?.includes("This layer is read-only");
console.log(ok ? "READ-ONLY-CHECK PASS" : "READ-ONLY-CHECK FAIL");
process.exit(ok ? 0 : 1);
