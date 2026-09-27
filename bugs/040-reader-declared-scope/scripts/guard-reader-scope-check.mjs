#!/usr/bin/env node
// Module-level behavioural probe for bug 040 — a reader's declared read scope
// must survive the incidental-mention filter (drill v27 §6 F2), while the
// writer-side sentinel/scratch rule of bug 032 keeps working.
//
// Usage: node guard-reader-scope-check.mjs [path-to-dsh-subagent-lib-index.js]
// Exit 0 when every case matches the required behaviour; 1 otherwise.
//
// Cases:
//   A. "read scope: /tmp/dsh040-lane" + a live writer elsewhere => ADMITTED,
//      scopeBasis "declared", readTrees ["/tmp/dsh040-lane"].
//   B. the same declaration + a live writer on that path        => REFUSED,
//      naming the real pair (the /tmp/dsh040-lane writer tree).
//   C. the exact drill-v27 prompt ("Read only the /tmp scratch area. Your read
//      scope is declared as: /tmp/ …") + writers on the drill root
//      => ADMITTED and declared (the F2 regression).
//   D. v26 A3 writer-side case: a writer that only mentions /tmp and
//      /tmp/v26_tstart as a sentinel declares no work there (cwd fallback) and
//      a disjoint reader is ADMITTED.
//   E. genuinely empty declaration                              => maximal.
//   F. filtered-but-declared: a path whose only mention is incidental
//      => maximal refusal that NAMES the dropped path, and the record carries
//      droppedIncidental.
//   G. cue forms "only read /tmp/x" and "scope: /tmp/a, /tmp/b" declare both.
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

// The fixed bundle carries the reader-side harvester; a pre-040 bundle is
// extracted through its own markers so the probe can demonstrate the
// behavioural difference both ways (the A/B/C/F cases are the F2 regression).
const fixed = source.includes("function declaredReadScopePaths(text) {");
if (!fixed) console.error("NOTE: pre-040 guard detected; running the same cases against it");

const block = [
  sourceBlock("const DECLARED_PATH_ROOTS", "return mostSpecificPaths([...found]);\n}"),
  ...(fixed
    ? [
        sourceBlock("function declaredReadScopePaths(text) {", "\n}"),
        sourceBlock("function declaredPromptScope(prompt) {", "\n}"),
      ]
    : []),
  sourceBlock("function declaredPromptTrees(prompt) {", "\n}"),
  sourceBlock("function treesOverlap(left, right) {", "\n}"),
  sourceBlock("function declaredWorkOfSession(session) {", "\n}"),
  sourceBlock("function declaredWorkOf(agent) {", "\n}"),
  sourceBlock("function declaredTreesOf(agent) {", "\n}"),
  sourceBlock("function inspectionConflicts(ctx, parent, readOnlyRequested, readTrees) {", "\n}"),
  sourceBlock("function assertInspectionOrdering(ctx, parent, readOnlyRequested, prompt) {", "\n}"),
].join("\n");

const context = createContext({
  resolve,
  sep,
  Set,
  SubagentError: FakeSubagentError,
  Date,
});
runInContext(
  `${block}\nthis.api = { declaredTreePaths, declaredPromptTrees, declaredTreesOf, inspectionConflicts, assertInspectionOrdering, declaredWorkOf${fixed ? ", declaredPromptScope, declaredReadScopePaths" : ""} };`,
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

const writes = { overrideOf: () => "writes" };
const parent = fakeAgent("parent", "/drill", undefined);

function refusalOf(writer, prompt) {
  const ctx = fakeCtx([parent, writer], writes);
  try {
    api.assertInspectionOrdering(ctx, parent, true, [{ type: "text", text: prompt }]);
    return undefined;
  } catch (error) {
    return error;
  }
}

function lastScopeRecord() {
  return parent.appended.findLast((event) => event.type === "subagent/inspection-scope");
}

// A. "read scope: /tmp/dsh040-lane" + live writer elsewhere => admitted.
{
  const writer = fakeAgent("writer-a", "/drill", "write /drill/sub/out/file.txt");
  const error = refusalOf(writer, "read scope for the scratch tree: /tmp/dsh040-lane");
  check(
    "A: a declared /tmp read scope is admitted while a writer is live",
    error === undefined,
    error?.message,
  );
  const record = lastScopeRecord();
  check(
    "A: the record says scopeBasis declared and readTrees [/tmp/dsh040-lane]",
    record !== undefined &&
      record.data.scopeBasis === "declared" &&
      record.data.outcome === "admitted" &&
      JSON.stringify(record.data.readTrees) === JSON.stringify(["/tmp/dsh040-lane"]),
    JSON.stringify(record?.data),
  );
}

// B. declared /tmp/dsh040-lane + live writer there => refused naming the pair.
{
  const writer = fakeAgent("writer-b", "/drill", "write /tmp/dsh040-lane");
  const error = refusalOf(writer, "read scope for the scratch tree: /tmp/dsh040-lane");
  check(
    "B: an overlapping /tmp pair is refused",
    error !== undefined && error.code === "INSPECTION_CONFLICT",
  );
  check(
    "B: the refusal names the real pair and keeps scopeBasis declared",
    error?.message.includes('against the same target path "/tmp/dsh040-lane"') === true &&
      error?.message.includes('the writer\'s declared work covers "/tmp/dsh040-lane"') === true &&
      error?.message.includes("scopeBasis: declared") === true,
    error?.message,
  );
  const record = lastScopeRecord();
  check(
    "B: the refusal is recorded as declared/refused",
    record !== undefined &&
      record.data.scopeBasis === "declared" &&
      record.data.outcome === "refused",
    JSON.stringify(record?.data),
  );
}

// C. the exact drill-v27 F2 prompt => admitted + declared.
{
  const writer = fakeAgent(
    "writer-c",
    "/drill",
    "write /home/john/Documents/dsh-drill-archive/roots/orchestrator-drill-v27-20260928-0012/app",
  );
  const prompt =
    "Read only the /tmp scratch area.\nYour read scope is declared as: /tmp/\nCheck whether the file /tmp/dsh-v27-sentinel.txt exists right now and reply with exactly one line: sentinel=<yes|no>.\nWrite nothing anywhere.";
  const error = refusalOf(writer, prompt);
  check(
    "C: the v27 F2 reader declaration is admitted, not refused as maximal",
    error === undefined,
    error?.message,
  );
  const trees = api.declaredPromptTrees([{ type: "text", text: prompt }]);
  check(
    "C: the declared scope is the scratch tree, not empty",
    JSON.stringify(trees) === JSON.stringify(["/tmp/dsh-v27-sentinel.txt"]),
    JSON.stringify(trees),
  );
  const record = lastScopeRecord();
  check(
    "C: the record is scopeBasis declared with no dropped caveat",
    record !== undefined &&
      record.data.scopeBasis === "declared" &&
      record.data.droppedIncidental === undefined,
    JSON.stringify(record?.data),
  );
}

// D. v26 A3 writer-side incidental filter still works.
{
  const writer = fakeAgent(
    "writer-d",
    "/drill",
    "Do not write /tmp. The sentinel file /tmp/v26_tstart marks the start; do not touch it.",
  );
  const error = refusalOf(writer, "review /tmp/review-notes.md");
  check(
    "D: incidental /tmp + sentinel writer mentions do not refuse",
    error === undefined,
    error?.message,
  );
  const work = api.declaredWorkOf(writer);
  check(
    "D: the writer's declared work still falls back to its cwd",
    JSON.stringify(work.trees) === JSON.stringify(["/drill"]) && work.basis === "cwd",
    JSON.stringify(work),
  );
}

// E. genuinely empty declaration => maximal.
{
  const writer = fakeAgent("writer-e", "/drill", "write /drill/sub/out/file.txt");
  const error = refusalOf(writer, "review the whole workspace");
  check(
    "E: an empty declaration is still maximal",
    error?.message.includes("scopeBasis: maximal") === true,
    error?.message,
  );
  const record = lastScopeRecord();
  check(
    "E: the maximal record carries no dropped caveat",
    record !== undefined &&
      record.data.scopeBasis === "maximal" &&
      record.data.droppedIncidental === undefined,
    JSON.stringify(record?.data),
  );
}

// F. filtered-but-declared => refusal names the dropped paths.
{
  const writer = fakeAgent("writer-f", "/drill", "write /drill/sub/out/file.txt");
  const error = refusalOf(writer, "Review the sentinel /tmp/v26_tstart only");
  check(
    "F: a filtered declaration is still refused as maximal",
    error?.message.includes("scopeBasis: maximal") === true,
    error?.message,
  );
  check(
    "F: the refusal names the dropped incidental path",
    error?.message.includes("1 path mention was ignored as incidental/scratch") &&
      error.message.includes('"/tmp/v26_tstart"'),
    error?.message,
  );
  const record = lastScopeRecord();
  check(
    "F: the record carries droppedIncidental",
    record !== undefined &&
      JSON.stringify(record.data.droppedIncidental) === JSON.stringify(["/tmp/v26_tstart"]),
    JSON.stringify(record?.data),
  );
}

// G. cue forms.
{
  const only = api.declaredPromptTrees([{ type: "text", text: "only read /tmp/x" }]);
  check(
    "G: `only read /tmp/x` declares /tmp/x",
    JSON.stringify(only) === JSON.stringify(["/tmp/x"]),
    JSON.stringify(only),
  );
  const listed = api.declaredPromptTrees([{ type: "text", text: "scope: /tmp/a, /tmp/b" }]);
  check(
    "G: `scope: /tmp/a, /tmp/b` declares both paths",
    JSON.stringify(listed) === JSON.stringify(["/tmp/a", "/tmp/b"]),
    JSON.stringify(listed),
  );
  if (fixed) {
    const scoped = api.declaredPromptScope([{ type: "text", text: "scope: /tmp/scratch" }]);
    check(
      "G: a scratch-suffixed cue path has no dropped caveat",
      scoped.dropped.length === 0,
      JSON.stringify(scoped),
    );
  }
}

if (failures.length > 0) {
  for (const failure of failures) console.error(`FAIL: ${failure}`);
  console.error(`GUARD-READER-SCOPE-CHECK FAIL (${failures.length} failure(s))`);
  process.exit(1);
}
console.log("GUARD-READER-SCOPE-CHECK PASS");
