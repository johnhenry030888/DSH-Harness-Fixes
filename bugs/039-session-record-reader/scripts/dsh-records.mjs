#!/usr/bin/env node
// dsh-records — a supported, offline reader for dsh session records and token
// usage (bug 039; drill v27 §6 F3). It resolves a session transcript under
// $DSH_HOME/sessions/--<cwd-slug>--/<sessionId>/session.v3.jsonl.zstd,
// decompresses the multi-frame zstd file, and prints the request/header
// summary, per-type record counts, the interesting raw rows, and optional
// per-agent / drill-wide usage totals.
//
// The trap this reader closes: a transcript file is multi-frame zstd, and
// Node's single-shot zstdDecompressSync silently truncates at the first frame
// (the v21/v25/v26 wrong parses). Decompression here uses the zstd CLI and falls
// back to an explicit frame-by-frame walk.
//
// Usage:
//   node dsh-records.mjs --session <sessionId|--latest> [--home <dir>]
//        [--json|--table] [--usage] [--records <type,type|all>]
//        [--agent <childId>] [--children|--all]
//
// Exit codes: 0 = read; 1 = store/session/requested record type absent or
// malformed (the paths tried are printed); 2 = usage error.
//
// No model, network, or wall-clock dependence: orderings are derived from
// record seq/time and directory names only.
import { spawnSync } from "node:child_process";
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { zstdDecompressSync } from "node:zlib";

const TRANSCRIPT = "session.v3.jsonl.zstd";
const KNOWN_TYPES = [
  "request/header",
  "turn/start",
  "turn/end",
  "tool/call",
  "tool/result",
  "subagent/descriptor",
  "subagent/box",
  "subagent/steer",
  "subagent/steer-boundary",
  "agent/inbox/spliced",
  "tool-workflow/agent-start",
  "tool-workflow/agent-end",
];
const DEFAULT_RECORD_TYPES = [
  "subagent/descriptor",
  "subagent/box",
  "subagent/steer",
  "subagent/steer-boundary",
  "tool-workflow/agent-start",
  "tool-workflow/agent-end",
  "subagent/inspection-scope",
];

function usageError(message) {
  process.stderr.write(`error: ${message}\n`);
  process.stderr.write(
    "usage: node dsh-records.mjs --session <sessionId|--latest> [--home <dir>] [--json|--table] [--usage] [--records <type,type|all>] [--agent <childId>] [--children|--all]\n",
  );
  process.exit(2);
}

function fail(message) {
  process.stderr.write(`error: ${message}\n`);
  process.exit(1);
}

function parseArgs(argv) {
  const opt = {
    home: process.env.DSH_HOME === undefined ? join(homedir(), ".dsh") : process.env.DSH_HOME,
    session: undefined,
    latest: false,
    json: false,
    usage: false,
    children: false,
    records: undefined,
    agent: undefined,
  };
  const value = (name, i) => {
    const raw = argv[i];
    const eq = raw.indexOf("=");
    if (eq !== -1) return { value: raw.slice(eq + 1), next: i };
    if (i + 1 >= argv.length) usageError(`${name} requires a value`);
    return { value: argv[i + 1], next: i + 1 };
  };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "-h" || arg === "--help") usageError("help requested");
    else if (arg === "--latest") opt.latest = true;
    else if (arg === "--json") opt.json = true;
    else if (arg === "--table") opt.json = false;
    else if (arg === "--usage") opt.usage = true;
    else if (arg === "--children" || arg === "--all") opt.children = true;
    else if (arg === "--session" || arg.startsWith("--session=")) {
      const parsed = value("--session", i);
      opt.session = parsed.value;
      i = parsed.next;
    } else if (arg === "--home" || arg.startsWith("--home=")) {
      const parsed = value("--home", i);
      opt.home = parsed.value;
      i = parsed.next;
    } else if (arg === "--records" || arg.startsWith("--records=")) {
      const parsed = value("--records", i);
      opt.records = parsed.value;
      i = parsed.next;
    } else if (arg === "--agent" || arg.startsWith("--agent=")) {
      const parsed = value("--agent", i);
      opt.agent = parsed.value;
      i = parsed.next;
    } else usageError(`unknown argument: ${arg}`);
  }
  if (opt.session === undefined && !opt.latest)
    usageError("--session <sessionId> or --latest is required");
  return opt;
}

/** zstd frame length, walking the frame header and block layout. */
function frameLength(buffer, start) {
  const magic = [0x28, 0xb5, 0x2f, 0xfd];
  for (let i = 0; i < 4; i += 1) {
    if (buffer[start + i] !== magic[i]) throw new Error(`not a zstd frame at byte ${start}`);
  }
  let pos = start + 4;
  const descriptor = buffer[pos];
  pos += 1;
  const contentSizeFlag = descriptor >> 6;
  const singleSegment = (descriptor & 0x20) !== 0;
  const checksum = (descriptor & 0x04) !== 0;
  const dictIdFlag = descriptor & 0x03;
  if (!singleSegment) pos += 1; // Window_Descriptor
  pos += [0, 1, 2, 4][dictIdFlag]; // Dictionary_ID
  pos += singleSegment && contentSizeFlag === 0 ? 1 : [0, 2, 4, 8][contentSizeFlag];
  for (;;) {
    const header = buffer[pos] | (buffer[pos + 1] << 8) | (buffer[pos + 2] << 16);
    pos += 3;
    const lastBlock = (header & 0x01) !== 0;
    const blockType = (header >> 1) & 0x03;
    const blockSize = header >> 3;
    if (blockType === 3) throw new Error(`reserved zstd block type at byte ${pos - 3}`);
    pos += blockType === 1 ? 1 : blockSize;
    if (lastBlock) break;
  }
  if (checksum) pos += 4;
  return pos - start;
}

/** Multi-frame decompression without the CLI (the single-shot call truncates). */
function decompressFrames(buffer) {
  const chunks = [];
  let pos = 0;
  let frames = 0;
  while (pos < buffer.length) {
    const length = frameLength(buffer, pos);
    chunks.push(zstdDecompressSync(buffer.subarray(pos, pos + length)).toString("utf8"));
    pos += length;
    frames += 1;
  }
  return { text: chunks.join(""), frames };
}

function countFrames(buffer) {
  let pos = 0;
  let frames = 0;
  while (pos < buffer.length) {
    pos += frameLength(buffer, pos);
    frames += 1;
  }
  return frames;
}

function decompress(file) {
  const compressed = readFileSync(file);
  if (process.env.DSH_RECORDS_DECOMPRESS === "node") {
    const forced = decompressFrames(compressed);
    return { text: forced.text, frames: forced.frames, tool: "node-frame-loop" };
  }
  const viaCli = spawnSync("zstd", ["-dc", "--", file], { maxBuffer: 1 << 30 });
  if (viaCli.error === undefined && viaCli.status === 0) {
    let frames;
    try {
      frames = countFrames(compressed);
    } catch {
      frames = null;
    }
    return { text: Buffer.from(viaCli.stdout).toString("utf8"), frames, tool: "zstd -dc" };
  }
  try {
    const fallback = decompressFrames(compressed);
    return { text: fallback.text, frames: fallback.frames, tool: "node-frame-loop" };
  } catch (error) {
    return fail(`cannot decompress ${file}: ${error.message}`);
  }
}

function readRecords(file, displayPath) {
  const { text, frames, tool } = decompress(file);
  const records = [];
  const lines = text.split("\n");
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    if (line.length === 0) continue;
    try {
      records.push({ ...JSON.parse(line), line: index + 1 });
    } catch (error) {
      fail(`malformed transcript line ${index + 1} in ${displayPath}: ${error.message}`);
    }
  }
  if (records.length === 0) fail(`transcript is empty: ${displayPath}`);
  return { records, frames, tool, displayPath };
}

/** Session directories under <home>/sessions/<bucket>/<id>/session.v3.jsonl.zstd. */
function sessionDirs(home) {
  const store = join(home, "sessions");
  if (!existsSync(store) || !statSync(store).isDirectory()) {
    fail(`session store not found: ${store} (--home ${home})`);
  }
  const found = [];
  for (const bucket of readdirSync(store, { withFileTypes: true })) {
    if (!bucket.isDirectory()) continue;
    const bucketPath = join(store, bucket.name);
    for (const entry of readdirSync(bucketPath, { withFileTypes: true })) {
      if (!entry.isDirectory()) continue;
      const file = join(bucketPath, entry.name, TRANSCRIPT);
      if (existsSync(file)) {
        found.push({
          bucket: bucket.name,
          id: entry.name,
          dir: join(bucketPath, entry.name),
          file,
        });
      }
    }
  }
  return { store, found };
}

function matchesId(dirName, id) {
  return dirName === id || dirName === `session-${id}`;
}

function resolveSession(home, opt) {
  const { store, found } = sessionDirs(home);
  if (found.length === 0) fail(`no session transcripts under ${store}`);
  if (opt.latest) {
    const sorted = [...found].sort((a, b) => {
      const at = statSync(a.file).mtimeMs;
      const bt = statSync(b.file).mtimeMs;
      if (at !== bt) return bt - at;
      return a.file < b.file ? -1 : 1;
    });
    return { store, sessions: found, chosen: sorted[0], latest: true };
  }
  const matches = found.filter((entry) => matchesId(entry.id, opt.session));
  if (matches.length === 0) {
    fail(
      `session "${opt.session}" not found; tried ${join(store, "*", opt.session, TRANSCRIPT)} and ${join(store, "*", `session-${opt.session}`, TRANSCRIPT)}`,
    );
  }
  if (matches.length > 1) {
    fail(
      `session "${opt.session}" is ambiguous (${matches.length} matches): ${matches.map((entry) => entry.file).join(", ")}`,
    );
  }
  return { store, sessions: found, chosen: matches[0], latest: false };
}

/** A child transcript beside the parent in the same store bucket, or undefined. */
function findChild(sessions, parent, childId) {
  const sameBucket = sessions.filter(
    (entry) => entry.bucket === parent.bucket && matchesId(entry.id, childId),
  );
  if (sameBucket.length > 1) {
    fail(`child "${childId}" is ambiguous: ${sameBucket.map((entry) => entry.file).join(", ")}`);
  }
  return sameBucket[0];
}

function count(records, type) {
  return records.filter((record) => record.type === type).length;
}

function firstOf(records, type) {
  return records.find((record) => record.type === type);
}

/** The `session` header record carries id/cwd/parentSession at its top level. */
function sessionMeta(records) {
  const record = records.find((entry) => entry.type === "session");
  if (record === undefined) return {};
  return {
    id: record.id,
    cwd: record.cwd,
    parentSession: record.parentSession,
    agentPreset: record.agentPreset,
  };
}

function headerSummary(records) {
  const headers = records.filter((record) => record.type === "request/header");
  const first = headers[0];
  if (first === undefined) {
    return { headers: 0, toolCount: null, provider: null, model: null, reasoningEffort: null };
  }
  const header = first.data?.header ?? {};
  const config = header.config ?? {};
  return {
    headers: headers.length,
    toolCount: Array.isArray(header.tools) ? header.tools.length : null,
    provider: config.provider ?? null,
    model: config.model ?? null,
    reasoningEffort: config.reasoningEffort ?? null,
  };
}

function sortedRecords(records, types) {
  return records
    .filter((record) => types === undefined || types.includes(record.type))
    .sort((a, b) => {
      const as = a.seq ?? -1;
      const bs = b.seq ?? -1;
      if (as !== bs) return as - bs;
      const at = a.time ?? 0;
      const bt = b.time ?? 0;
      if (at !== bt) return at - bt;
      return a.line - b.line;
    });
}

/** Token totals for one transcript, counting each assistant/message usage once. */
function usageOf(records) {
  let inputTokens = 0;
  let cacheReadTokens = 0;
  let outputTokens = 0;
  let modelCalls = 0;
  for (const record of records) {
    if (record.type !== "assistant/message") continue;
    const usage = record.data?.usage;
    if (usage === undefined || usage === null) continue;
    inputTokens += Number(usage.inputTokens ?? 0);
    cacheReadTokens += Number(usage.cacheReadTokens ?? 0);
    outputTokens += Number(usage.outputTokens ?? 0);
    modelCalls += 1;
  }
  return { inputTokens, cacheReadTokens, outputTokens, modelCalls };
}

/** Child ids the parent session references, in first-seen order. */
function childIdsOf(records) {
  const ids = [];
  const add = (id) => {
    if (typeof id === "string" && !ids.includes(id)) ids.push(id);
  };
  for (const record of records) {
    if (record.type === "subagent/catalog") add(record.data?.childId);
    else if (record.type === "tool-workflow/agent-start") add(record.data?.childId);
    else if (record.type === "tool-workflow/agent-end") add(record.data?.childId);
    else if (record.type === "subagent/inspection-scope") {
      for (const conflict of record.data?.conflicts ?? []) add(conflict.agentId);
    }
  }
  return ids;
}

function childRow(entry, records) {
  const header = headerSummary(records);
  const descriptor = firstOf(records, "subagent/descriptor")?.data;
  const catalog = firstOf(records, "subagent/catalog")?.data;
  const box = firstOf(records, "subagent/box")?.data;
  const session = sessionMeta(records);
  const times = records
    .filter((record) => typeof record.time === "number")
    .map((record) => record.time);
  const firstTime = times.length === 0 ? null : Math.min(...times);
  const lastTime = times.length === 0 ? null : Math.max(...times);
  return {
    id: entry.id,
    parentSession: session?.parentSession ?? null,
    mode: catalog?.mode ?? descriptor?.mode ?? null,
    label: catalog?.label ?? descriptor?.label ?? null,
    tools: count(records, "tool/call"),
    records: records.length,
    header,
    reasoningEffort: header.reasoningEffort ?? descriptor?.agentReasoningEffort ?? null,
    box:
      box === undefined
        ? null
        : {
            boxSeconds: box.boxSeconds ?? null,
            elapsedSeconds: box.elapsedSeconds ?? null,
            hit: box.hit ?? null,
          },
    steerCount: count(records, "subagent/steer"),
    firstTime,
    lastTime,
    wallSeconds:
      firstTime === null || lastTime === null
        ? null
        : Number(((lastTime - firstTime) / 1000).toFixed(3)),
  };
}

function readChildren(sessions, parent, parentRecords) {
  const ids = childIdsOf(parentRecords);
  const rows = [];
  const byId = new Map();
  const missing = [];
  for (const id of ids) {
    const entry = findChild(sessions, parent, id);
    if (entry === undefined) {
      missing.push(id);
      continue;
    }
    const read = readRecords(entry.file, entry.file);
    byId.set(id, read.records);
    byId.set(entry.id, read.records);
    rows.push(childRow(entry, read.records));
  }
  if (missing.length > 0) {
    fail(
      `child transcripts missing under the parent's store bucket: ${missing.join(", ")} (each is referenced by ${parent.file})`,
    );
  }
  return { ids, rows, byId };
}

function iso(time) {
  return typeof time === "number" ? new Date(time).toISOString() : "-";
}

function pad(text, width) {
  const value = String(text ?? "-");
  return value.length >= width ? value : value + " ".repeat(width - value.length);
}

function parseRequestedTypes(raw) {
  if (raw === undefined) return undefined;
  if (raw === "all") return null;
  const types = raw
    .split(",")
    .map((type) => type.trim())
    .filter((type) => type.length > 0);
  if (types.length === 0) usageError("--records needs at least one record type (or all)");
  return types;
}

const opt = parseArgs(process.argv.slice(2));
const resolved = resolveSession(opt.home, opt);
const parentEntry = resolved.chosen;
const parentRead = readRecords(parentEntry.file, parentEntry.file);
const parentRecords = parentRead.records;
const parentData = sessionMeta(parentRecords);
const parentId = parentData.id ?? parentEntry.id;

let targetEntry = parentEntry;
if (opt.agent !== undefined) {
  targetEntry = findChild(resolved.sessions, parentEntry, opt.agent);
  if (targetEntry === undefined) {
    fail(
      `child "${opt.agent}" not found beside ${parentEntry.file}; tried ${join(resolved.store, parentEntry.bucket, opt.agent, TRANSCRIPT)} and ${join(resolved.store, parentEntry.bucket, `session-${opt.agent}`, TRANSCRIPT)}`,
    );
  }
}
const targetRead =
  targetEntry === parentEntry ? parentRead : readRecords(targetEntry.file, targetEntry.file);
const targetRecords = targetRead.records;

const counts = {};
for (const type of KNOWN_TYPES) counts[type] = count(targetRecords, type);
for (const record of targetRecords) {
  if (!KNOWN_TYPES.includes(record.type)) counts[record.type] = (counts[record.type] ?? 0) + 1;
}

const requestedTypes = parseRequestedTypes(opt.records);
const explicitTypes = requestedTypes !== undefined && requestedTypes !== null;
if (explicitTypes) {
  for (const type of requestedTypes) {
    if (count(targetRecords, type) === 0) {
      fail(
        `no records of type "${type}" in ${targetRead.displayPath} (types present: ${Object.keys(
          counts,
        )
          .filter((key) => counts[key] > 0)
          .join(", ")})`,
      );
    }
  }
}
// The default row selection is a convenience: absent default types are merely
// noted (a session without subagents is not a failure), while an explicitly
// requested absent type fails above.
const defaultAbsent =
  requestedTypes === undefined
    ? DEFAULT_RECORD_TYPES.filter((type) => count(targetRecords, type) === 0)
    : [];
const rowTypes =
  requestedTypes === undefined
    ? DEFAULT_RECORD_TYPES.filter((type) => count(targetRecords, type) > 0)
    : requestedTypes;
const rows = sortedRecords(targetRecords, rowTypes === null ? undefined : rowTypes);

let childReport;
if (opt.children) childReport = readChildren(resolved.sessions, parentEntry, parentRecords);

let usage;
if (opt.usage) {
  const agents = [];
  const seen = new Set();
  const addAgent = (id, role, records) => {
    if (seen.has(id)) return;
    seen.add(id);
    agents.push({ id, role, records });
  };
  if (childReport !== undefined) {
    addAgent(parentId, "parent", parentRecords);
    for (const row of childReport.rows) {
      addAgent(row.id, row.label ?? "child", childReport.byId.get(row.id) ?? []);
    }
  } else {
    addAgent(targetEntry.id, "target", targetRecords);
  }
  const drill = {
    inputTokens: 0,
    cacheReadTokens: 0,
    outputTokens: 0,
    modelCalls: 0,
  };
  for (const agent of agents) {
    const totals = usageOf(agent.records);
    drill.inputTokens += totals.inputTokens;
    drill.cacheReadTokens += totals.cacheReadTokens;
    drill.outputTokens += totals.outputTokens;
    drill.modelCalls += totals.modelCalls;
  }
  const tokenBase = drill.inputTokens + drill.cacheReadTokens;
  usage = {
    agents: agents.map((agent) => {
      const totals = usageOf(agent.records);
      const tokens = totals.inputTokens + totals.cacheReadTokens;
      return {
        id: agent.id,
        role: agent.role,
        inputTokens: totals.inputTokens,
        cacheReadTokens: totals.cacheReadTokens,
        outputTokens: totals.outputTokens,
        modelCalls: totals.modelCalls,
        sharePct: tokenBase === 0 ? null : Number(((tokens / tokenBase) * 100).toFixed(2)),
        uncachedSharePct:
          drill.inputTokens === 0
            ? null
            : Number(((totals.inputTokens / drill.inputTokens) * 100).toFixed(2)),
      };
    }),
    drill,
    leadSharePct:
      tokenBase === 0
        ? null
        : Number(
            (
              ((agents[0] === undefined
                ? 0
                : usageOf(agents[0].records).inputTokens +
                  usageOf(agents[0].records).cacheReadTokens) /
                tokenBase) *
              100
            ).toFixed(2),
          ),
  };
}

const targetMeta = sessionMeta(targetRecords);
const summary = {
  id: targetEntry.id,
  sessionId: targetMeta.id ?? null,
  path: targetRead.displayPath,
  cwd: targetMeta.cwd ?? null,
  compression: { tool: targetRead.tool, frames: targetRead.frames },
  records: targetRecords.length,
  request: headerSummary(targetRecords),
  counts,
};

if (opt.json) {
  process.stdout.write(
    `${JSON.stringify(
      {
        session: summary,
        ...(defaultAbsent.length === 0 ? {} : { absentDefaultRecordTypes: defaultAbsent }),
        records: rows,
        ...(usage === undefined ? {} : { usage }),
        ...(childReport === undefined
          ? {}
          : {
              children: childReport.rows.map((row) =>
                opt.usage
                  ? {
                      ...row,
                      usage: usage.agents.find((agent) => agent.id === row.id) ?? null,
                    }
                  : row,
              ),
            }),
      },
      null,
      2,
    )}\n`,
  );
  process.exit(0);
}

const out = [];
out.push(
  `session ${summary.id}${summary.sessionId === null || summary.sessionId === summary.id ? "" : ` (${summary.sessionId})`}`,
);
out.push(`path ${summary.path}`);
out.push(
  `records ${summary.records} (multi-frame: ${summary.compression.frames} frame(s) via ${summary.compression.tool})`,
);
out.push(`cwd ${summary.cwd ?? "-"}`);
const request = summary.request;
out.push(
  `request headers ${request.headers}: toolCount=${request.toolCount ?? "-"} provider=${request.provider ?? "-"} model=${request.model ?? "-"} reasoningEffort=${request.reasoningEffort ?? "-"}`,
);
out.push("");
out.push("record counts:");
for (const type of Object.keys(counts)) out.push(`  ${pad(type, 28)} ${counts[type]}`);
out.push("");
if (defaultAbsent.length > 0) {
  out.push(
    `records: absent default types in this session: ${defaultAbsent.join(", ")} (counted as 0 above)`,
  );
}
if (rows.length === 0) {
  out.push(
    `records (${rowTypes === null ? "all" : rowTypes.join(",")}): none present in this session (see counts)`,
  );
} else {
  out.push(`records (${rowTypes === null ? "all" : rowTypes.join(",")}): ${rows.length} row(s)`);
  for (const row of rows) {
    out.push(`  [seq ${row.seq ?? "-"} ${iso(row.time)}] ${row.type} ${JSON.stringify(row.data)}`);
  }
}
if (usage !== undefined) {
  out.push("");
  out.push(`usage (model calls ${usage.drill.modelCalls}, counting each assistant/message once):`);
  out.push(
    `  ${pad("agent", 38)} ${pad("input", 10)} ${pad("cacheRead", 11)} ${pad("output", 9)} ${pad("calls", 6)} ${pad("share%", 7)} ${pad("uncached%", 9)}`,
  );
  for (const agent of usage.agents) {
    out.push(
      `  ${pad(agent.id, 38)} ${pad(agent.inputTokens, 10)} ${pad(agent.cacheReadTokens, 11)} ${pad(agent.outputTokens, 9)} ${pad(agent.modelCalls, 6)} ${pad(agent.sharePct, 7)} ${pad(agent.uncachedSharePct, 9)}`,
    );
  }
  out.push(
    `  ${pad("TOTAL", 38)} ${pad(usage.drill.inputTokens, 10)} ${pad(usage.drill.cacheReadTokens, 11)} ${pad(usage.drill.outputTokens, 9)} ${pad(usage.drill.modelCalls, 6)}`,
  );
}
if (childReport !== undefined) {
  out.push("");
  out.push(`children (${childReport.rows.length}, referenced by this session):`);
  out.push(
    `  ${pad("child", 38)} ${pad("mode", 12)} ${pad("tools", 5)} ${pad("records", 7)} ${pad("effort", 8)} ${pad("wall s", 7)} ${pad("box", 18)} label`,
  );
  for (const child of childReport.rows) {
    const box = child.box === null ? "-" : `${child.box.boxSeconds}s hit=${child.box.hit}`;
    const label = child.label ?? "-";
    out.push(
      `  ${pad(child.id, 38)} ${pad(child.mode, 12)} ${pad(child.tools, 5)} ${pad(child.records, 7)} ${pad(child.reasoningEffort, 8)} ${pad(child.wallSeconds, 7)} ${pad(box, 18)} ${label}`,
    );
  }
}
process.stdout.write(`${out.join("\n")}\n`);
