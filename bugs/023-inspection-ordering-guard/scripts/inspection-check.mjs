// Module-level check for bug 023's shipped tree predicate.
//
// The ordering guard itself is exercised live (see EVIDENCE.md); this check
// pins the one piece a live single-workspace session cannot vary: the
// path-prefix predicate `treesOverlap`, extracted verbatim from the installed
// bundle and evaluated with node:path's own `resolve`/`sep`, so a
// sibling-prefix directory (`/a/bc` vs `/a/b`) can never be mistaken for an
// overlap.
import { readFileSync } from "node:fs";
import { resolve, sep } from "node:path";
import { createContext, runInContext } from "node:vm";

const BASE =
  process.env.DSH_AGENT_BASE ??
  "/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai";
const FILE = `${BASE}/dsh-subagent/lib/index.js`;
const source = readFileSync(FILE, "utf8");

const start = source.indexOf("function treesOverlap(left, right) {");
if (start === -1) {
  console.error("FAIL: treesOverlap is not present in the installed dsh-subagent");
  process.exit(1);
}
let depth = 0;
let end = -1;
for (let index = start; index < source.length; index += 1) {
  if (source[index] === "{") depth += 1;
  else if (source[index] === "}") {
    depth -= 1;
    if (depth === 0) {
      end = index + 1;
      break;
    }
  }
}
const context = createContext({ resolve, sep });
runInContext(`${source.slice(start, end)}\nthis.treesOverlap = treesOverlap;`, context);
const treesOverlap = context.treesOverlap;

const cases = [
  ["same path", "/work/project", "/work/project", true],
  ["child beneath parent", "/work/project", "/work/project/sub", true],
  ["parent above child", "/work/project/sub", "/work/project", true],
  ["sibling with shared prefix string", "/work/project", "/work/project-2", false],
  ["unrelated trees", "/work/alpha", "/work/beta", false],
  ["missing cwd is conservative", undefined, "/work/project", true],
  ["missing cwd on the other side", "/work/project", undefined, true],
  ["trailing separators normalize", "/work/project/", "/work/project/sub/", true],
];

let failed = 0;
for (const [name, left, right, expected] of cases) {
  const actual = treesOverlap(left, right);
  if (actual !== expected) {
    console.error(
      `FAIL: ${name}: treesOverlap(${String(left)}, ${String(right)}) = ${actual}, expected ${expected}`,
    );
    failed += 1;
  } else {
    console.log(`ok: ${name}`);
  }
}

for (const marker of [
  "function inspectionConflicts(ctx, parent, readOnlyRequested)",
  "function assertInspectionOrdering(ctx, parent, readOnlyRequested)",
  '"INSPECTION_CONFLICT"',
  "assertInspectionOrdering(this.ctx, spec.request.parent, spec.request.readOnly)",
  "assertInspectionOrdering(this.ctx, request.parent, request.readOnly)",
]) {
  if (!source.includes(marker)) {
    console.error(`FAIL: missing guard marker ${marker}`);
    failed += 1;
  } else {
    console.log(`ok: guard marker present`);
  }
}

if (failed > 0) {
  console.error(`INSPECTION-CHECK FAIL (${failed} failure(s))`);
  process.exit(1);
}
console.log("INSPECTION-CHECK PASS");
