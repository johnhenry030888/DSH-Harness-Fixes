#!/usr/bin/env node
// Regenerate (or verify) the installed harness's live opencode-go catalog.
//
// The bug-005 patch exports the catalog builder from
// dsh-llm-pi-ai/lib/index.js. This script reuses that one implementation so a
// refresh and a check can never drift from what the host serves.
//
//   node refresh-opencode-go-catalog.mjs          # fetch live sources, write the cache
//   node refresh-opencode-go-catalog.mjs --check  # compare the cache with live sources (no write)
//
// Exit codes: 0 ok, 1 drift/failure, 2 patch or module missing,
// 3 sources unreachable during --check (cache kept).
//
// Override the installed module with DSH_LLM_PI_AI_MODULE.

import { existsSync, readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

const MODULE =
  process.env.DSH_LLM_PI_AI_MODULE ??
  "/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-llm-pi-ai/lib/index.js";
const PROVIDER = "opencode-go";
const check = process.argv.includes("--check");

let module_;
try {
  module_ = await import(pathToFileURL(MODULE).href);
} catch (error) {
  console.error(`cannot load ${MODULE}: ${error instanceof Error ? error.message : error}`);
  process.exit(2);
}
if (
  typeof module_.previewLiveCatalog !== "function" ||
  typeof module_.refreshLiveCatalog !== "function" ||
  typeof module_.liveCatalogPath !== "function"
) {
  console.error(
    "the installed module lacks the live-catalog exports; is the bug-005 patch applied? (scripts/reapply.sh)",
  );
  process.exit(2);
}

const cachePath = module_.liveCatalogPath(PROVIDER);

if (!check) {
  try {
    const changed = await module_.refreshLiveCatalog(PROVIDER);
    console.log(`${changed ? "updated" : "unchanged"}: ${cachePath}`);
    process.exit(0);
  } catch (error) {
    console.error(`refresh failed: ${error instanceof Error ? error.message : error}`);
    process.exit(1);
  }
}

let expected;
try {
  expected = await module_.previewLiveCatalog(PROVIDER);
} catch (error) {
  console.error(`live sources unreachable: ${error instanceof Error ? error.message : error}`);
  process.exit(existsSync(cachePath) ? 3 : 1);
}

let actual;
try {
  actual = JSON.parse(readFileSync(cachePath, "utf8"));
} catch {
  console.error(`no live catalog cache at ${cachePath}; run scripts/reapply.sh`);
  process.exit(1);
}

const ids = (models) =>
  (Array.isArray(models) ? models : [])
    .map((model) => model?.id)
    .filter((id) => typeof id === "string" && id.length > 0)
    .sort();
const expectedIds = ids(expected);
const actualIds = ids(actual?.models);
const missing = expectedIds.filter((id) => !actualIds.includes(id));
const extra = actualIds.filter((id) => !expectedIds.includes(id));

if (missing.length > 0 || extra.length > 0) {
  console.error(`live catalog drift against ${cachePath}`);
  if (missing.length > 0) console.error(`  available but not served: ${missing.join(", ")}`);
  if (extra.length > 0) console.error(`  served but no longer available: ${extra.join(", ")}`);
  process.exit(1);
}
console.log(`ok: ${expectedIds.length} live ${PROVIDER} models match ${cachePath}`);
