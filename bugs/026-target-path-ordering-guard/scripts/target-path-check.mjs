// Module-level check for bug 026's shipped declared-path predicate.
//
// The guard itself is exercised live (see EVIDENCE.md); this check pins the
// piece a single live workspace cannot vary: `declaredTreePaths` (extraction,
// normalization, URL/system-root filtering) and its intersection with
// `treesOverlap`, extracted verbatim from the installed bundle so a prose
// prompt's declared trees can never key the guard on a URL path or a system
// root, and a tree-B prompt can never intersect a tree-A writer.
import { readFileSync } from "node:fs";
import { resolve, sep } from "node:path";
import { createContext, runInContext } from "node:vm";

const BASE =
  process.env.DSH_AGENT_BASE ??
  "/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai";
const FILE = `${BASE}/dsh-subagent/lib/index.js`;
const source = readFileSync(FILE, "utf8");

function sourceBlock(startMarker, endMarker) {
  const start = source.indexOf(startMarker);
  if (start === -1) {
    console.error(`FAIL: ${startMarker} is not present in the installed dsh-subagent`);
    process.exit(1);
  }
  const end = source.indexOf(endMarker, start);
  if (end === -1) {
    console.error(`FAIL: end marker ${endMarker} not found after ${startMarker}`);
    process.exit(1);
  }
  return source.slice(start, end + endMarker.length);
}

const block = `${sourceBlock("const DECLARED_PATH_ROOTS", "return [...found];\n}")}\n${sourceBlock("function treesOverlap(left, right) {", "\n}")}`;
const context = createContext({ resolve, sep, Set });
runInContext(
  `${block}\nthis.declaredTreePaths = declaredTreePaths; this.treesOverlap = treesOverlap;`,
  context,
);
const { declaredTreePaths, treesOverlap } = context;

const failures = [];
function check(name, actual, expected) {
  const ok = JSON.stringify(actual) === JSON.stringify(expected);
  if (!ok)
    failures.push(`${name}: got ${JSON.stringify(actual)}, expected ${JSON.stringify(expected)}`);
  else console.log(`ok: ${name}`);
}

check("plain path", declaredTreePaths("review /work/tree-a/stats.py and stop"), [
  "/work/tree-a/stats.py",
]);
check(
  "markdown backticks and punctuation",
  declaredTreePaths("run `cd /work/tree-a/` then read /work/tree-a/stats.py, twice"),
  ["/work/tree-a", "/work/tree-a/stats.py"],
);
check(
  "URLs are not filesystem trees",
  declaredTreePaths("see https://github.com/john/repo/blob/main/README.md for context"),
  [],
);
check(
  "system roots are dropped",
  declaredTreePaths("run /usr/bin/python3 -m pytest from /work/tree-b"),
  ["/work/tree-b"],
);
check("relative paths are ignored", declaredTreePaths("read project/stats.py"), []);
check(
  "two trees stay distinct",
  declaredTreePaths("write /work/tree-a/x.py then review /work/tree-b/y.py"),
  ["/work/tree-a/x.py", "/work/tree-b/y.py"],
);

check(
  "tree A writer overlaps tree A reader",
  treesOverlap("/work/tree-a", "/work/tree-a/sub"),
  true,
);
check(
  "tree B reader does not overlap tree A writer",
  treesOverlap("/work/tree-b", "/work/tree-a"),
  false,
);

if (failures.length > 0) {
  for (const failure of failures) console.error(`FAIL: ${failure}`);
  console.error(`TARGET-PATH-CHECK FAIL (${failures.length} failure(s))`);
  process.exit(1);
}
console.log("TARGET-PATH-CHECK PASS");
