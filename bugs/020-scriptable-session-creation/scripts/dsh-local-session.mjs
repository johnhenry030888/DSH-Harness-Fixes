#!/usr/bin/env node
/**
 * dsh-local-session.mjs — create a DSH session on the local Web app without a
 * browser, respecting authentication end to end.
 *
 * Why this exists (harness bug 020): the drills could not open a session
 * programmatically — the web GUI answers 401 without the per-process launch
 * token, and the token was only announced on the operator's terminal. It is
 * announced on the process's stdout, so this helper starts the Web app itself,
 * reads the authenticated URL line, exchanges the token for the signed session
 * cookie exactly like a browser index request, and then drives the documented
 * local /api RPC surface (`session/create`, optional `session/prompt`) with
 * that cookie. Authentication is never weakened: the token is minted by the
 * same process, used over loopback, and optionally written to a 0600 file
 * under the caller's control.
 *
 * Usage:
 *   node dsh-local-session.mjs [options]
 *
 * Options:
 *   --home <dir>        DSH_HOME for the spawned Web app (default: inherited)
 *   --port <n>          listen port (default 0: OS-assigned)
 *   --cwd <path>        session workspace cwd (default: current directory)
 *   --preset <name>     agent preset to mount (e.g. orchestrator)
 *   --prompt <text>     send one user prompt after creating the session
 *   --token-file <p>    write the authenticated URL (with token) to <p>, mode 0600
 *   --timeout <ms>      startup timeout (default 60000)
 *   --turn-timeout <ms> bound on waiting for the prompted turn (default: max(timeout, 120000))
 *   --no-wait           return as soon as the prompt is QUEUED (see below)
 *   --json              print one JSON result object and nothing else
 *   --keep              keep the Web app running; print the URL and cookie for follow-ups
 *
 * `session/prompt` queues (`mode: "queue"`), so `prompted: true` alone means the
 * message was accepted, not answered — and killing the server right after it
 * leaves the turn at `turn/start` with no `request/header`. Unless `--no-wait`
 * is passed, a prompted run therefore reads the session transcript (under
 * `<home>/sessions/<cwd-bucket>/<sessionId>/session.v3.jsonl.zstd`, via Node's
 * `zstd` CLI) until the first `turn/end` and reports `turnCompleted`,
 * `headerToolCount`, `assistantText` and `waitedMs` beside the ids. The wait is
 * bounded by `--turn-timeout`; a timed-out wait still exits 0 with whatever it
 * observed, so a caller can tell "queued" from "answered".
 *
 * Exit code 0 only when the session was created; 1 on any failure.
 */
import { spawn, spawnSync } from "node:child_process";
import { randomUUID } from "node:crypto";
import { chmodSync, existsSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join, resolve } from "node:path";
import * as zlib from "node:zlib";

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i++) {
    const key = argv[i];
    const next = argv[i + 1];
    switch (key) {
      case "--home":
        args.home = next;
        i++;
        break;
      case "--port":
        args.port = Number(next);
        i++;
        break;
      case "--cwd":
        args.cwd = next;
        i++;
        break;
      case "--preset":
        args.preset = next;
        i++;
        break;
      case "--prompt":
        args.prompt = next;
        i++;
        break;
      case "--token-file":
        args.tokenFile = next;
        i++;
        break;
      case "--timeout":
        args.timeout = Number(next);
        i++;
        break;
      case "--turn-timeout":
        args.turnTimeout = Number(next);
        i++;
        break;
      case "--no-wait":
        args.noWait = true;
        break;
      case "--json":
        args.json = true;
        break;
      case "--keep":
        args.keep = true;
        break;
      case "--help":
      case "-h":
        args.help = true;
        break;
      default:
        throw new Error(`unknown argument ${JSON.stringify(key)}`);
    }
  }
  return args;
}

/** The session's transcript under the harness home, wherever its cwd bucket is. */
function findTranscript(root, sessionId) {
  try {
    for (const bucket of readdirSync(root)) {
      const candidate = join(root, bucket, sessionId, "session.v3.jsonl.zstd");
      if (existsSync(candidate)) return candidate;
    }
  } catch {
    // the store does not exist yet: still nothing to read
  }
  return undefined;
}

/**
 * Decompress a transcript. The store appends one zstd frame per flush, so the
 * CLI (`zstd -dc`, all frames) is the primary path: Node's single-shot
 * `zstdDecompressSync` stops at the first frame and would hide the turn end.
 * It is kept as a fallback for hosts without the CLI, where a truncated read
 * only costs the caller a timed-out wait.
 */
function decompress(file) {
  const out = spawnSync("zstd", ["-dc", file], { maxBuffer: 512 * 1024 * 1024 });
  if (out.status === 0) return out.stdout.toString("utf8");
  if (typeof zlib.zstdDecompressSync === "function") {
    try {
      return zlib.zstdDecompressSync(readFileSync(file)).toString("utf8");
    } catch {
      // torn tail while the turn is still writing
    }
  }
  return undefined;
}

/**
 * Wait for the prompted turn to end, reporting what the session advertised.
 * `session/prompt` only queues, so this is the difference between "accepted"
 * and "answered" — and the header count is the composition proof a drill needs.
 */
async function awaitFirstTurn(root, sessionId, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  let observed = { turnCompleted: false };
  for (;;) {
    const file = findTranscript(root, sessionId);
    if (file !== undefined) {
      const text = decompress(file);
      if (text !== undefined) {
        const records = [];
        for (const line of text.split("\n")) {
          if (line.trim().length === 0) continue;
          try {
            records.push(JSON.parse(line));
          } catch {
            // a partially written tail record is expected while the turn runs
          }
        }
        const header = records.find((record) => record.type === "request/header");
        const ended = records.find((record) => record.type === "turn/end");
        const assistant = records.findLast((record) => record.type === "assistant/message");
        const textBlocks =
          assistant?.data?.message?.content?.filter((block) => block.type === "text") ?? [];
        observed = {
          turnCompleted: ended !== undefined,
          ...(header === undefined ? {} : { headerToolCount: header.data.header.tools.length }),
          ...(textBlocks.length === 0
            ? {}
            : { assistantText: textBlocks.map((block) => block.text).join("\n") }),
          ...(ended === undefined ? {} : { turnEndReason: ended.data.reason }),
        };
        if (ended !== undefined) return observed;
      }
    }
    if (Date.now() >= deadline) return observed;
    await new Promise((resume) => setTimeout(resume, 500));
  }
}

/** Wait for the `dsh web: <url>` line on stdout, or fail the startup bound. */
function awaitAnnouncedUrl(child, timeoutMs) {
  return new Promise((resolvePromise, rejectPromise) => {
    let buffer = "";
    const timer = setTimeout(() => {
      rejectPromise(new Error(`dsh web did not announce a URL within ${timeoutMs} ms`));
    }, timeoutMs);
    const onData = (chunk) => {
      buffer += chunk.toString("utf8");
      const match = /dsh web: (\S+)/.exec(buffer);
      if (match === null) return;
      clearTimeout(timer);
      child.stdout.off("data", onData);
      resolvePromise(match[1]);
    };
    child.stdout.on("data", onData);
    child.once("exit", (code) => {
      clearTimeout(timer);
      rejectPromise(new Error(`dsh web exited early with code ${String(code)}: ${buffer.trim()}`));
    });
  });
}

/** Exchange the process launch token for the signed browser-session cookie. */
async function exchangeCookie(authenticatedUrl) {
  const response = await fetch(authenticatedUrl, { redirect: "manual" });
  if (response.status !== 303)
    throw new Error(`token exchange expected 303, got ${response.status}`);
  const cookies =
    typeof response.headers.getSetCookie === "function"
      ? response.headers.getSetCookie()
      : [response.headers.get("set-cookie")];
  const cookie = cookies
    .filter(Boolean)
    .map((value) => value.split(";", 1)[0])
    .join("; ");
  if (cookie.length === 0) throw new Error("token exchange returned no session cookie");
  return cookie;
}

/** POST one RPC endpoint on the authenticated /api channel. */
async function rpc(baseUrl, cookie, endpoint, payload) {
  const response = await fetch(new URL(`/api/${endpoint}`, baseUrl), {
    method: "POST",
    headers: { "content-type": "application/json", cookie },
    body: JSON.stringify({
      type: "client-request",
      rpcId: randomUUID(),
      method: endpoint,
      payload: { args: payload },
    }),
  });
  if (!response.ok)
    throw new Error(`${endpoint} answered HTTP ${response.status}: ${await response.text()}`);
  const envelope = await response.json();
  if (envelope?.result?.ok !== true)
    throw new Error(`${endpoint} failed: ${JSON.stringify(envelope?.result?.error ?? envelope)}`);
  return envelope.result.value;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    console.log(
      await import("node:fs").then((fs) =>
        fs
          .readFileSync(new URL(import.meta.url), "utf8")
          .split("*/")[0]
          .split("/**")[1]
          .replace(/^ ?\* ?/gm, ""),
      ),
    );
    return;
  }
  const port = Number.isInteger(args.port) ? args.port : 0;
  const timeoutMs = Number.isInteger(args.timeout) ? args.timeout : 60000;
  const turnTimeoutMs = Number.isInteger(args.turnTimeout)
    ? args.turnTimeout
    : Math.max(timeoutMs, 120000);
  const homeDir = resolve(args.home ?? process.env.DSH_HOME ?? join(homedir(), ".dsh"));
  const cwd = resolve(args.cwd ?? process.cwd());
  const env = { ...process.env };
  if (args.home !== undefined) env.DSH_HOME = resolve(args.home);
  const child = spawn("dsh", ["web", "--no-open", "--port", String(port)], {
    env,
    stdio: ["ignore", "pipe", "pipe"],
  });
  let stderrTail = "";
  child.stderr.on("data", (chunk) => {
    stderrTail = `${stderrTail}${chunk.toString("utf8")}`.slice(-4000);
  });
  try {
    const authenticatedUrl = await awaitAnnouncedUrl(child, timeoutMs);
    const baseUrl = new URL(authenticatedUrl);
    const cookie = await exchangeCookie(authenticatedUrl);
    if (args.tokenFile !== undefined) {
      writeFileSync(resolve(args.tokenFile), `${authenticatedUrl}\n`, { mode: 0o600 });
      chmodSync(resolve(args.tokenFile), 0o600);
    }
    const created = await rpc(baseUrl.href, cookie, "session/create", {
      request: { cwd, ...(args.preset === undefined ? {} : { agentPreset: args.preset }) },
    });
    let prompted = false;
    let observed = {};
    if (args.prompt !== undefined) {
      await rpc(baseUrl.href, cookie, "session/prompt", {
        request: {
          requestId: randomUUID(),
          sessionId: created.sessionId,
          mode: "queue",
          content: [{ type: "text", text: args.prompt }],
        },
      });
      prompted = true;
      if (args.noWait !== true) {
        const started = Date.now();
        observed = await awaitFirstTurn(
          join(homeDir, "sessions"),
          created.sessionId,
          turnTimeoutMs,
        );
        observed.waitedMs = Date.now() - started;
      }
    }
    const result = {
      sessionId: created.sessionId,
      ...(created.agentPreset === undefined ? {} : { agentPreset: created.agentPreset }),
      cwd,
      // The PID of the server this call booted: a caller asserting "no stray
      // server" can compare against its pre-call baseline instead of guessing
      // which of several `dsh web` processes is the new one (drill v15 #3).
      webPid: child.pid,
      ...(args.keep ? { kept: true } : {}),
      baseUrl: baseUrl.href,
      prompted,
      ...observed,
    };
    if (args.json) console.log(JSON.stringify(result));
    else {
      console.log(
        `session: ${created.sessionId}${created.agentPreset === undefined ? "" : ` (preset: ${created.agentPreset})`}`,
      );
      console.log(`workspace: ${cwd}`);
      console.log(`web: ${baseUrl.href}`);
      if (args.keep) console.log(`cookie: ${cookie}`);
    }
    if (!args.keep) child.kill("SIGTERM");
    else {
      process.on("SIGINT", () => {
        child.kill("SIGTERM");
        process.exit(130);
      });
      await new Promise(() => {});
    }
  } finally {
    if (!args.keep) {
      await new Promise((resolveExit) => {
        if (child.exitCode !== null) return resolveExit();
        child.once("exit", resolveExit);
        setTimeout(() => {
          child.kill("SIGKILL");
          resolveExit();
        }, 5000);
      });
    }
  }
  if (stderrTail.trim().length > 0 && process.env.DSH_LOCAL_SESSION_VERBOSE === "1")
    process.stderr.write(stderrTail);
}

main().catch((error) => {
  console.error(`dsh-local-session: ${error instanceof Error ? error.message : String(error)}`);
  process.exitCode = 1;
});
