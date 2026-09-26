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
 *   --json              print one JSON result object and nothing else
 *   --keep              keep the Web app running; print the URL and cookie for follow-ups
 *
 * Exit code 0 only when the session was created; 1 on any failure.
 */
import { spawn } from "node:child_process";
import { randomUUID } from "node:crypto";
import { chmodSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

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
    }
    const result = {
      sessionId: created.sessionId,
      ...(created.agentPreset === undefined ? {} : { agentPreset: created.agentPreset }),
      cwd,
      baseUrl: baseUrl.href,
      prompted,
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
