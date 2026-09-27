#!/usr/bin/env node
// Module-level behavioural probe for bug 031 (and the 032 overlap cases that
// share the same predicate): drives the installed guard functions directly
// with fake live writers, so no model or live host is needed.
//
// Usage: node guard-scope-check.mjs [path-to-dsh-subagent-lib-index.js]
// Exit 0 when every case matches the required behaviour; 1 otherwise.
//
// Cases:
//   A. no declared read scope + a live write-capable child  => REFUSED with
//      the "declared no read scope ... whole workspace" message and a
//      `scopeBasis: "maximal"` durable record on the parent session.
//   B. declared disjoint scope + a live writer               => ADMITTED.
//   C. declared overlapping paths                            => REFUSED naming
//      the actual pair, never a collapsed ancestor.
//   D. declared disjoint paths                               => ADMITTED.
//   E. writer prompt that merely mentions /tmp and a sentinel => ADMITTED.
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

// The 031/032 bundle carries the new harvester; a pre-031 bundle (the
// 023+026 stack without this fix) is extracted through its own markers so the
// probe can demonstrate the behavioural difference both ways.
const fixed = source.includes("function mostSpecificPaths(");
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
if (!fixed) console.error("NOTE: pre-031 guard detected; running the same cases against it");

const context = createContext({
  resolve,
  sep,
  Set,
  SubagentError: FakeSubagentError,
  Date,
});
runInContext(
  `${block}\nthis.api = { declaredTreePaths, declaredTreesOf, declaredPromptTrees, inspectionConflicts, assertInspectionOrdering${fixed ? ", declaredWorkOf" : ""} };`,
  context,
);
const api = context.api;

/** One fake live agent with a first user/message prompt. */
function fakeAgent(id, cwd, prompt) {
  const events =
    prompt === undefined
      ? []
      : [{ type: "user/message", data: { content: [{ type: "text", text: prompt }] } }];
  const appended = [];
  return {
    id,
    status: "running",
    appended,
    session: {
      seq: 30,
      header: { id, parentSession: "parent", cwd },
      snapshotEvents: (from, limit) =>
        events.slice(from ?? 0, limit === undefined ? events.length : from + limit),
      append: (type, data) => {
        appended.push({ type, data });
        return { type, seq: appended.length, data };
      },
    },
  };
}

function fakeCtx(agents, policy) {
  return {
    agents: { list: () => agents },
    policy,
    get(name) {
      if (name === "agents") return this.agents;
      if (name === "sandboxPolicy") return this.policy;
      return undefined;
    },
  };
}

const failures = [];
function check(name, condition, detail) {
  if (condition) console.log(`ok: ${name}`);
  else failures.push(`${name}${detail === undefined ? "" : ` — ${detail}`}`);
}

function refusalOf(parent, prompt, writer, policy) {
  const ctx = fakeCtx([parent, writer], policy);
  try {
    api.assertInspectionOrdering(ctx, parent, true, [{ type: "text", text: prompt }]);
    return undefined;
  } catch (error) {
    return error;
  }
}

const writes = { overrideOf: () => "writes" };
const parent = fakeAgent("parent", "/drill", undefined);

// A. undeclared read scope + live writer => maximal refusal + record.
{
  const writer = fakeAgent("writer-a", "/drill", "write /drill/sub/out/file.txt");
  const error = refusalOf(parent, "review the whole workspace", writer, writes);
  check(
    "A: undeclared read scope is refused while a writer is live",
    error !== undefined && error.code === "INSPECTION_CONFLICT",
  );
  check(
    "A: refusal states the maximal rule and names the writer",
    error?.message.includes("refused a read-only delegation that declared no read scope") &&
      error.message.includes("it is treated as covering the whole workspace") &&
      error.message.includes('write-capable agent "writer-a" is still running') &&
      error.message.includes("scopeBasis: maximal"),
    error?.message,
  );
  check(
    "A: refusal keeps the retry guidance sentence",
    error?.message.includes(
      "Wait for the child's settlement notice, or interrupt_agent it, then retry the same read-only call unchanged",
    ),
  );
  const record = parent.appended.findLast((event) => event.type === "subagent/inspection-scope");
  check(
    "A: parent session records scopeBasis=refused/maximal",
    record !== undefined &&
      record.data.scopeBasis === "maximal" &&
      record.data.outcome === "refused" &&
      Array.isArray(record.data.readTrees) &&
      record.data.readTrees.length === 0,
    JSON.stringify(record?.data),
  );
}

// B. declared disjoint scope + live writer => admitted.
{
  const writer = fakeAgent("writer-b", "/drill", "write /drill/sub/out/file.txt");
  const error = refusalOf(parent, "review /drill/elsewhere/report.md only", writer, writes);
  check("B: declared disjoint scope is admitted", error === undefined, error?.message);
  const record = parent.appended.findLast((event) => event.type === "subagent/inspection-scope");
  check(
    "B: admitted declared delegation records scopeBasis=declared",
    record !== undefined &&
      record.data.scopeBasis === "declared" &&
      record.data.outcome === "admitted",
    JSON.stringify(record?.data),
  );
}

// C. overlapping declared paths => refused, naming the actual pair.
{
  const writer = fakeAgent("writer-c", "/drill", "write /drill/sub/out/file.txt and stop");
  const error = refusalOf(parent, "review /drill/sub/out", writer, writes);
  check(
    "C: declared overlap is refused",
    error !== undefined && error.code === "INSPECTION_CONFLICT",
  );
  check(
    "C: refusal names the actual overlapping pair, not a collapsed ancestor",
    error?.message.includes('"/drill/sub/out"') &&
      error.message.includes('"/drill/sub/out/file.txt"') &&
      !error.message.includes('work covers "/drill"'),
    error?.message,
  );
}

// D. disjoint declared paths => admitted.
{
  const writer = fakeAgent("writer-d", "/drill", "write /drill/sub-a/file.txt");
  const error = refusalOf(parent, "review /drill/sub-b", writer, writes);
  check("D: disjoint declared paths are admitted", error === undefined, error?.message);
}

// E. writer prompt merely mentions /tmp and a sentinel => admitted.
{
  const writer = fakeAgent(
    "writer-e",
    "/drill",
    "Do not write /tmp. The sentinel file /tmp/v26_tstart marks the start; do not touch it.",
  );
  const error = refusalOf(parent, "review /tmp/review-notes.md", writer, writes);
  check(
    "E: incidental /tmp + sentinel mentions do not refuse",
    error === undefined,
    error?.message,
  );
  const trees = api.declaredTreesOf(writer);
  check(
    "E: the writer's declared work falls back to its cwd, not the sentinel",
    JSON.stringify(trees) === JSON.stringify(["/drill"]),
    JSON.stringify(trees),
  );
}

// F. most-specific: a declared ancestor collapses to the declared descendant.
{
  const writer = fakeAgent(
    "writer-f",
    "/drill",
    "the drill root /drill is context; the target is /drill/sub-a/file.txt",
  );
  const error = refusalOf(parent, "review /drill/sub-b", writer, writes);
  check(
    "F: declared descendant wins and the unrelated reader is admitted",
    error === undefined,
    error?.message,
  );
}

if (failures.length > 0) {
  for (const failure of failures) console.error(`FAIL: ${failure}`);
  console.error(`GUARD-SCOPE-CHECK FAIL (${failures.length} failure(s))`);
  process.exit(1);
}
console.log("GUARD-SCOPE-CHECK PASS");
