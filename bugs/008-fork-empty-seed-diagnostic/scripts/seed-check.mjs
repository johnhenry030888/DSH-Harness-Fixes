// Module-level live check for bug 008's fork seed diagnostic.
// Exercises the installed @deepseek-ai/dsh-subagent-fork-in-process provider:
//   - a parent with no completed turn yields no seed, logs the warning, and the
//     warning names the parent session and "inherits 0 events";
//   - a parent with a completed turn yields the balanced prefix (> 0 events)
//     and logs nothing.
import { apply } from "/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-subagent-fork-in-process/lib/index.js";

const warnings = [];
let provider;
apply(
  {
    subagents: {
      registerProvider: (p) => {
        provider = p;
      },
    },
    logger: { warn: (m) => warnings.push(m) },
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

const report = {
  emptySeed: empty.seed === undefined ? "no seed" : empty.seed.length,
  seededCount: seeded.seed?.length ?? 0,
  warnings,
};
console.log(JSON.stringify(report, null, 2));

const ok =
  empty.seed === undefined &&
  seeded.seed?.length === 4 &&
  warnings.length === 1 &&
  warnings[0].includes("session-open") &&
  warnings[0].includes("inherits 0 events") &&
  !warnings.some((w) => w.includes("session-completed"));
console.log(ok ? "SEED-CHECK PASS" : "SEED-CHECK FAIL");
process.exit(ok ? 0 : 1);
