#!/usr/bin/env node
// Module-level behavioural probe for bug 032: the guard computes overlap on
// DECLARED paths on both sides, names the actual overlapping pair, and never
// reports a path the writer merely touched.
//
// Usage: node guard-pair-check.mjs [path-to-dsh-subagent-lib-index.js]
// Exit 0 when every case matches the required behaviour; 1 otherwise.
//
// Cases (reconstructed from drill v26 §5 / Appendix A2/A3):
//   1. overlapping declared paths      => refused naming BOTH paths.
//   2. disjoint declared paths         => admitted.
//   3. writer merely mentions /tmp and a sentinel => admitted, and the
//      barrier message never names the sentinel path.
//   4. writer declares the drill root plus its real targets => the most
//      specific declared target is the reported tree, not the root.
import { readFileSync } from "node:fs";
import { resolve, sep } from "node:path";
import { createContext, runInContext } from "node:vm";

const BASE =
  process.env.DSH_AGENT_BASE ??
  "/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai";
const FILE = process.argv[2] ?? `${BASE}/dsh-subagent/lib/index.js`;
const source = readFileSync(FILE, "utf8");

function sourceBlock(startMarker, endMarker) {
  const start = source.indexOf(startMarker);
  if (start === -1) {
    console.error(`FAIL: ${startMarker} is not present in ${FILE}`);
    process.exit(1);
  }
  const end = source.indexOf(endMarker, start);
  if (end === -1) {
    console.error(`FAIL: end marker ${endMarker} not found after ${startMarker}`);
    process.exit(1);
  }
  return source.slice(start, end + endMarker.length);
}

class FakeSubagentError extends Error {
  constructor(message, code) {
    super(message);
    this.name = "SubagentError";
    this.code = code;
  }
}

const fixed = source.includes("function mostSpecificPaths(");
if (!source.includes("function inspectionConflicts(ctx, parent, readOnlyRequested, readTrees) {")) {
  console.error("FAIL: bug 031 must be applied before this probe can run");
  process.exit(1);
}
const block = fixed
  ? [
      sourceBlock("const DECLARED_PATH_ROOTS", "return mostSpecificPaths([...found]);\n}"),
      sourceBlock("function mostSpecificPaths(paths) {", "\n}"),
      sourceBlock("function treesOverlap(left, right) {", "\n}"),
      sourceBlock("function declaredWorkOfSession(session) {", "\n}"),
      sourceBlock("function declaredWorkOf(agent) {", "\n}"),
      sourceBlock("function declaredTreesOf(agent) {", "\n}"),
      sourceBlock("function declaredPromptTrees(prompt) {", "\n}"),
      sourceBlock(
        "function inspectionConflicts(ctx, parent, readOnlyRequested, readTrees) {",
        "\n}",
      ),
      sourceBlock(
        "function assertInspectionOrdering(ctx, parent, readOnlyRequested, prompt) {",
        "\n}",
      ),
    ].join("\n")
  : [
      sourceBlock("const DECLARED_PATH_ROOTS", "return [...found];\n}"),
      sourceBlock("function treesOverlap(left, right) {", "\n}"),
      sourceBlock("function declaredWorkOfSession(session) {", "\n}"),
      sourceBlock("function declaredWorkOf(agent) {", "\n}"),
      sourceBlock("function declaredTreesOf(agent) {", "\n}"),
      sourceBlock("function declaredPromptTrees(prompt) {", "\n}"),
      sourceBlock(
        "function inspectionConflicts(ctx, parent, readOnlyRequested, readTrees) {",
        "\n}",
      ),
      sourceBlock(
        "function assertInspectionOrdering(ctx, parent, readOnlyRequested, prompt) {",
        "\n}",
      ),
    ].join("\n");
if (!fixed) console.error("NOTE: pre-032 harvester detected; running the same cases against it");
const context = createContext({ resolve, sep, Set, SubagentError: FakeSubagentError, Date });
runInContext(
  `${block}\nthis.api = { declaredTreePaths, declaredTreesOf, inspectionConflicts, assertInspectionOrdering };`,
  context,
);
const api = context.api;

function fakeAgent(id, cwd, prompt, parentId = "parent-032") {
  const events =
    prompt === undefined
      ? []
      : [{ type: "user/message", data: { content: [{ type: "text", text: prompt }] } }];
  const appended = [];
  return {
    id,
    status: "running",
    session: {
      seq: 30,
      header: { id, parentSession: parentId, cwd },
      snapshotEvents: (from, limit) =>
        events.slice(from ?? 0, limit === undefined ? events.length : from + limit),
      append: (type, data) => {
        appended.push({ type, data });
        return { type, seq: appended.length, data };
      },
    },
  };
}

const writePolicy = { overrideOf: () => "writes" };
function run(parent, writer, prompt) {
  const ctx = {
    get(name) {
      if (name === "agents") return { list: () => [parent, writer] };
      if (name === "sandboxPolicy") return writePolicy;
      return undefined;
    },
  };
  try {
    api.assertInspectionOrdering(ctx, parent, true, [{ type: "text", text: prompt }]);
    return undefined;
  } catch (error) {
    return error;
  }
}

const failures = [];
function check(name, condition, detail) {
  if (condition) console.log(`ok: ${name}`);
  else failures.push(`${name}${detail === undefined ? "" : ` — ${detail}`}`);
}

const parent = fakeAgent("parent-032", "/drill", undefined);
const ROOT = "/drill/orchestrator-drill-v26";

// 1. Overlapping declared paths => refused naming BOTH paths.
{
  const writer = fakeAgent(
    "writer-overlap",
    ROOT,
    `Write ${ROOT}/state/verify1/results.json with the sweep table.`,
  );
  const error = run(parent, writer, `Review ${ROOT}/state/verify1/results.json and report.`);
  check(
    "1: overlapping declared paths are refused",
    error?.code === "INSPECTION_CONFLICT",
    error?.message,
  );
  check(
    "1: the refusal names both declared paths",
    error !== undefined &&
      error.message.includes(`${ROOT}/state/verify1/results.json`) &&
      error.message.includes('"writer-overlap"') &&
      error.message.includes("scopeBasis: declared"),
    error?.message,
  );
}

// 2. Disjoint declared paths => admitted.
{
  const writer = fakeAgent("writer-disjoint", ROOT, `Write ${ROOT}/state/sweep2/results.json.`);
  const error = run(parent, writer, `Review ${ROOT}/app/parse.py and report.`);
  check("2: disjoint declared paths are admitted", error === undefined, error?.message);
}

// 3. Writer merely mentions /tmp and a sentinel => admitted, sentinel never named.
{
  const writer = fakeAgent(
    "writer-sentinel",
    ROOT,
    "Do not write outside /tmp. Sentinel: /tmp/v26_tstart records the dispatch timestamp; do not modify it.",
  );
  const error = run(parent, writer, "Review /tmp/v26_rows/app and report.");
  check("3: incidental /tmp + sentinel mentions are admitted", error === undefined, error?.message);
  check(
    "3: the sentinel is not harvested as declared work",
    !api.declaredTreesOf(writer).includes("/tmp/v26_tstart") &&
      !api.declaredTreesOf(writer).includes("/tmp"),
    JSON.stringify(api.declaredTreesOf(writer)),
  );
}

// 4. Declared root plus a real target => the most specific path is reported.
{
  const writer = fakeAgent(
    "writer-root",
    ROOT,
    `The drill root ${ROOT} is the context; the target is ${ROOT}/state/build/a.py.`,
  );
  const trees = api.declaredTreesOf(writer);
  check(
    "4: the declared ancestor collapses to the declared descendant",
    JSON.stringify(trees) === JSON.stringify([`${ROOT}/state/build/a.py`]),
    JSON.stringify(trees),
  );
  const admitted = run(parent, writer, `Review ${ROOT}/app/agg.py and report.`);
  check("4: an unrelated reader is admitted", admitted === undefined, admitted?.message);
  const refused = run(parent, writer, `Review ${ROOT}/state/build/a.py and report.`);
  check(
    "4: the genuine overlap is still refused, naming the real path",
    refused !== undefined &&
      refused.message.includes(`${ROOT}/state/build/a.py`) &&
      !refused.message.includes(`work covers "${ROOT}"`),
    refused?.message,
  );
}

// 5. Exact v26 Appendix A3 text: the refused pair was reported as /tmp.
{
  const writer = fakeAgent(
    "ccf76e8c-808e-4812-9abf-11b4d52c5102",
    ROOT,
    "Do not write outside the drill root. Sentinel: /tmp/v26_tstart records the dispatch timestamp; do not modify it.",
  );
  const error = run(parent, writer, "Read /tmp for the candidate answers.");
  check(
    "5: the A3 shape (writer that only touched /tmp/v26_tstart) is admitted",
    error === undefined,
    error?.message,
  );
}

if (failures.length > 0) {
  for (const failure of failures) console.error(`FAIL: ${failure}`);
  console.error(`GUARD-PAIR-CHECK FAIL (${failures.length} failure(s))`);
  process.exit(1);
}
console.log("GUARD-PAIR-CHECK PASS");
