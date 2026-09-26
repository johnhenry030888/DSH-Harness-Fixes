// Module-level check for bug 013: the fork provider announces the seed in BOTH
// directions (host log) and the descriptor schema carries the numeric count.
// Live transcript evidence (descriptor + child runtime context) is in EVIDENCE.md;
// this check covers the host-warning half, which the web host does not print to
// stdout.

import {
  foldSubagentDescriptor,
  snapshotSubagentDescriptor,
} from "/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-subagent/lib/index.js";
import { apply } from "/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-subagent-fork-in-process/lib/index.js";

const warnings = [];
const infos = [];
let provider;
apply(
  {
    subagents: {
      registerProvider: (p) => {
        provider = p;
      },
    },
    logger: {
      warn: (m) => warnings.push(m),
      info: (m) => infos.push(m),
    },
  },
  { providerName: "fork" },
);

const completed = [
  { seq: 0, type: "session/start", data: {} },
  { seq: 1, type: "turn/start", data: { turn: 1 } },
  { seq: 2, type: "assistant/message", data: {} },
  { seq: 3, type: "turn/end", data: { turn: 1, reason: { kind: "completed" } } },
];
const open = completed.slice(0, 3);
const parentOf = (id, events) => ({ session: { header: { id }, snapshotEvents: () => events } });

const empty = await provider.prepareContinuable({ parent: parentOf("session-open", open) });
const seeded = await provider.prepareContinuable({
  parent: parentOf("session-completed", completed),
});

const coldDescriptor = snapshotSubagentDescriptor({
  mode: "one-shot",
  provider: "fork",
  label: "cold",
  inheritedEventCount: 0,
  toolFilter: { deny: ["workflow"] },
});
const seededDescriptor = snapshotSubagentDescriptor({
  mode: "one-shot",
  provider: "fork",
  label: "seeded",
  inheritedEventCount: 4,
});
const folded = foldSubagentDescriptor([{ type: "subagent/descriptor", data: coldDescriptor }]);

const report = {
  emptySeed: empty.seed === undefined ? "no seed" : empty.seed.length,
  seededCount: seeded.seed?.length ?? 0,
  warnings,
  infos,
  coldDescriptor,
  seededDescriptor,
  folded,
};
console.log(JSON.stringify(report, null, 2));

const ok =
  empty.seed === undefined &&
  seeded.seed?.length === 4 &&
  warnings.length === 1 &&
  warnings[0].includes("session-open") &&
  warnings[0].includes("inherits 0 events") &&
  infos.length === 1 &&
  infos[0].includes("session-completed") &&
  infos[0].includes("inherits 4 completed events") &&
  coldDescriptor.inheritedEventCount === 0 &&
  coldDescriptor.toolFilter?.deny?.[0] === "workflow" &&
  seededDescriptor.inheritedEventCount === 4 &&
  folded?.inheritedEventCount === 0 &&
  folded?.toolFilter?.deny?.[0] === "workflow";
console.log(ok ? "SEED-ANNOUNCEMENT-CHECK PASS" : "SEED-ANNOUNCEMENT-CHECK FAIL");
process.exit(ok ? 0 : 1);
