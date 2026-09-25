// Module-level live check for bug 007's tolerant child composition.
// Exercises the installed @deepseek-ai/dsh-subagent applyChildComposition with a
// stub child scope: the two v3 names must be dropped AND named in the warning,
// the valid remainder applied, and an all-unknown list must still call restrict()
// (deny: [] for deny-only, allow: [] for allow-only, which fails closed).
import { applyChildComposition } from "/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-subagent/lib/index.js";

const known = new Set(["bash", "read", "workflow", "subagent_fast"]);
function makeChild() {
  const warnings = [];
  const restricted = [];
  return {
    warnings,
    restricted,
    ctx: {
      get: () => undefined,
      systemPrompt: {
        context() {},
        section() {},
        getContextOrder: () => 0,
        getSectionOrder: () => 0,
      },
      tools: { view: () => ({ restrictableNames: known }), restrict: (f) => restricted.push(f) },
      logger: { warn: (m) => warnings.push(m) },
    },
  };
}

const results = [];
{
  const child = makeChild();
  applyChildComposition(
    child.ctx,
    { ctx: {} },
    { toolFilter: { deny: ["subagent", "list_subagent_models", "workflow", "not_a_tool"] } },
    "child-123",
  );
  results.push({
    case: "v3-like deny list",
    warning: child.warnings[0] ?? null,
    restricted: child.restricted,
  });
}
{
  const child = makeChild();
  applyChildComposition(
    child.ctx,
    { ctx: {} },
    { toolFilter: { deny: ["subagent", "list_subagent_models"] } },
    "child-456",
  );
  results.push({
    case: "all-unknown deny list",
    warning: child.warnings[0] ?? null,
    restricted: child.restricted,
  });
}
{
  const child = makeChild();
  applyChildComposition(
    child.ctx,
    { ctx: {} },
    { toolFilter: { allow: ["bash", "subagent"] } },
    "child-789",
  );
  results.push({
    case: "partial allow list",
    warning: child.warnings[0] ?? null,
    restricted: child.restricted,
  });
}
console.log(JSON.stringify(results, null, 2));

const ok =
  results[0].warning?.includes('"subagent"') &&
  results[0].warning?.includes('"list_subagent_models"') &&
  results[0].warning?.includes('"not_a_tool"') &&
  results[0].warning?.includes("child-123") &&
  JSON.stringify(results[0].restricted) === JSON.stringify([{ deny: ["workflow"] }]) &&
  results[1].warning?.includes('"subagent"') &&
  JSON.stringify(results[1].restricted) === JSON.stringify([{ deny: [] }]) &&
  results[2].warning?.includes('"subagent"') &&
  JSON.stringify(results[2].restricted) === JSON.stringify([{ allow: ["bash"] }]);
console.log(ok ? "TOLERANCE-CHECK PASS" : "TOLERANCE-CHECK FAIL");
process.exit(ok ? 0 : 1);
