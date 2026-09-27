#!/usr/bin/env node
// Module-level behavioural probe for bug 034: drives the real inbox `claim`
// method (extracted from the installed bundle) with a fake advancing clock,
// and asserts the steer-delivery and steer-boundary records are present and
// monotone: deliveredAt <= boundaryAt, with the boundary seq recorded.
//
// Usage: node steer-check.mjs [path-to-dsh-agent-loop-lib-index.js]
// Exit 0 when every case matches the required behaviour; 1 otherwise.
import { readFileSync } from "node:fs";
import { createContext, runInContext } from "node:vm";

const BASE =
  process.env.DSH_AGENT_BASE ??
  "/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai";
const LOOP_FILE = process.argv[2] ?? `${BASE}/dsh-agent-loop/lib/index.js`;
const SUB_FILE = process.argv[3] ?? `${BASE}/dsh-subagent/lib/index.js`;

function sourceBlock(file, startMarker, endMarker) {
  const source = readFileSync(file, "utf8");
  const start = source.indexOf(startMarker);
  if (start === -1) {
    console.error(`FAIL: ${startMarker} is not present in ${file}`);
    process.exit(1);
  }
  const end = source.indexOf(endMarker, start);
  if (end === -1) {
    console.error(`FAIL: end marker ${endMarker} not found after ${startMarker} in ${file}`);
    process.exit(1);
  }
  return source.slice(start, end + endMarker.length);
}

// A clock the probe advances explicitly.
const clock = { nowMs: Date.parse("2026-09-27T20:40:00.000Z") };
const FakeDate = class extends Date {
  constructor(...args) {
    if (args.length === 0) super(clock.nowMs);
    else super(...args);
  }
  static now() {
    return clock.nowMs;
  }
};

const boundaryBlock = sourceBlock(
  LOOP_FILE,
  "function steerBoundaryRecord(message, boundaryAt, boundarySeq) {",
  "\n}",
);
const claimMethod = sourceBlock(
  LOOP_FILE,
  "\tclaim(target, turn) {",
  "\t\treturn claimed;\n\t}",
).replace("claim(target, turn) {", "function claim(target, turn) {");
const deliveryBlock = sourceBlock(
  SUB_FILE,
  "function steerDeliveryRecord(messageId, target, senderSessionId, deliveredAt) {",
  "\n}",
);

const context = createContext({ Date: FakeDate, Set });
runInContext(
  `${boundaryBlock}\n${deliveryBlock}\n${claimMethod}\nthis.api = { steerBoundaryRecord, steerDeliveryRecord, claim };`,
  context,
);
const api = context.api;

const failures = [];
function check(name, condition, detail) {
  if (condition) console.log(`ok: ${name}`);
  else failures.push(`${name}${detail === undefined ? "" : ` — ${detail}`}`);
}

function fakeInbox(messages) {
  const appended = [];
  const pending = [...messages];
  return {
    appended,
    get nextStep() {
      return pending;
    },
    mutate(_target, _start, _deleteCount, _inserted, _discard) {
      const claimed = pending.splice(0, pending.length);
      return claimed;
    },
    dispatch: { emit() {} },
    session: {
      seq: 77,
      append(type, data) {
        appended.push({ type, data, seq: this.seq });
        return { type, data, seq: this.seq };
      },
    },
  };
}

// 1. A steer delivered at T0 and adopted 250 ms later.
{
  const deliveredAt = new FakeDate().toISOString();
  clock.nowMs += 250;
  const message = { id: "msg-1", source: { kind: "agent-message", steer: true, deliveredAt } };
  const inbox = fakeInbox([message]);
  const claimed = api.claim.call(inbox, "next-turn", 4);
  const boundary = inbox.appended.find((event) => event.type === "subagent/steer-boundary");
  check("1: the steer message is claimed", claimed.length === 1);
  check("1: a boundary record is appended", boundary !== undefined);
  check(
    "1: deliveredAt <= boundaryAt, both ISO millisecond stamps",
    boundary !== undefined &&
      deliveredAt === "2026-09-27T20:40:00.000Z" &&
      boundary.data.boundaryAt === "2026-09-27T20:40:00.250Z" &&
      Date.parse(boundary.data.deliveredAt) <= Date.parse(boundary.data.boundaryAt),
    JSON.stringify(boundary?.data),
  );
  check(
    "1: the boundary seq is recorded",
    boundary?.data.boundarySeq === 77,
    JSON.stringify(boundary?.data),
  );
  check("1: the message id is recorded", boundary?.data.messageId === "msg-1");
}

// 2. A queued (non-steer) message gets no boundary stamp.
{
  const message = { id: "msg-2", source: { kind: "agent-message" } };
  const inbox = fakeInbox([message]);
  api.claim.call(inbox, "next-turn", 4);
  check(
    "2: non-steer messages are not stamped",
    inbox.appended.every((event) => event.type !== "subagent/steer-boundary"),
  );
}

// 3. A service-stamped steer without a caller stamp still yields a boundary.
{
  const message = { id: "msg-3", source: { steer: true } };
  const inbox = fakeInbox([message]);
  api.claim.call(inbox, "next-step", 4);
  const boundary = inbox.appended.find((event) => event.type === "subagent/steer-boundary");
  check(
    "3: a steer without deliveredAt still records boundaryAt + boundarySeq",
    boundary !== undefined &&
      typeof boundary.data.boundaryAt === "string" &&
      boundary.data.boundarySeq === 77 &&
      !("deliveredAt" in boundary.data),
    JSON.stringify(boundary?.data),
  );
}

// 4. The service-side delivery record shape.
{
  const record = api.steerDeliveryRecord(
    "msg-4",
    "child-4",
    "parent-4",
    "2026-09-27T20:40:01.000Z",
  );
  check(
    "4: the child's subagent/steer record carries deliveredAt/target/messageId",
    record.messageId === "msg-4" &&
      record.target === "child-4" &&
      record.senderSessionId === "parent-4" &&
      record.deliveredAt === "2026-09-27T20:40:01.000Z",
    JSON.stringify(record),
  );
}

if (failures.length > 0) {
  for (const failure of failures) console.error(`FAIL: ${failure}`);
  console.error(`STEER-CHECK FAIL (${failures.length} failure(s))`);
  process.exit(1);
}
console.log("STEER-CHECK PASS");
