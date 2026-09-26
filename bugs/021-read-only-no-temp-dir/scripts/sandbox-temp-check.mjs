// Module-level check for bug 021: every confined mode (including read-only)
// mounts/grants a writable temp area, while the workspace stays fenced.

import { Context } from "/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/cordis/lib/index.js";
import {
  tempWriteRoots,
  writableRoots,
} from "/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-sandbox/lib/index.js";
import { LocalSandboxProvider } from "/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-sandbox-local/lib/index.js";

const failures = [];
const check = (label, condition) => {
  if (!condition) failures.push(label);
  console.log(`${condition ? "ok" : "FAIL"}: ${label}`);
};

const tempRoots = tempWriteRoots();
check("tempWriteRoots() is non-empty", tempRoots.length > 0);
check("tempWriteRoots() contains /tmp", tempRoots.includes("/tmp"));
check(
  "writableRoots(read-only) stays empty",
  writableRoots({ mode: "read-only", workspaceRoot: "/w" }).length === 0,
);

function confined(runner, mode) {
  const ctx = new Context();
  const provider = new LocalSandboxProvider(ctx, {
    runnerCommand: [],
    runnerFailureSignatures: [],
    probeTimeoutMs: 5000,
  });
  provider.internals.chain = [runner];
  provider.internals.landlockLauncher = "/fake/landlock-run";
  provider.internals.seatbeltExec = "sandbox-exec";
  return provider.confine(["bash", "-c", "true"], { mode, workspaceRoot: "/w" }).argv;
}

const bwrapRo = confined("bwrap", "read-only");
const bwrapWw = confined("bwrap", "workspace-write");
check(
  "bwrap read-only mounts --tmpfs /tmp",
  bwrapRo.includes("--tmpfs") && bwrapRo.includes("/tmp"),
);
check(
  "bwrap workspace-write still mounts --tmpfs /tmp",
  bwrapWw.includes("--tmpfs") && bwrapWw.includes("/tmp"),
);
check(
  "bwrap read-only still ro-binds /",
  bwrapRo[0] === "bwrap" && bwrapRo[1] === "--ro-bind" && bwrapRo[2] === "/",
);
check("bwrap read-only has no workspace bind", !bwrapRo.includes("/w"));
check("bwrap workspace-write binds the workspace", bwrapWw.includes("/w"));

const landlockRo = confined("landlock", "read-only");
const landlockWw = confined("landlock", "workspace-write");
const rwPairs = (argv) => argv.flatMap((arg, index) => (arg === "--rw" ? [argv[index + 1]] : []));
check("landlock read-only grants --rw /tmp", rwPairs(landlockRo).includes("/tmp"));
check("landlock read-only does not grant the workspace", !rwPairs(landlockRo).includes("/w"));
check("landlock workspace-write grants the workspace", rwPairs(landlockWw).includes("/w"));

const seatbeltRo = confined("seatbelt", "read-only").join(" ");
check(
  "seatbelt read-only allows file-write under /tmp",
  seatbeltRo.includes('(allow file-write* (subpath "/tmp"))'),
);
check("seatbelt read-only denies the workspace", !seatbeltRo.includes('(subpath "/w")'));

if (failures.length > 0) {
  console.error(`SANDBOX-TEMP-CHECK FAIL (${failures.length}): ${failures.join("; ")}`);
  process.exit(1);
}
console.log("SANDBOX-TEMP-CHECK PASS");
