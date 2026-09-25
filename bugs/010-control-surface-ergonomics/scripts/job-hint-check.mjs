// Module-level live check for bug 010's job/agent namespace hint.
// Instantiates the installed LocalJobRegistry and calls expect() with an agent
// id (UUID), a non-UUID unknown id, and a real job id.
import { Context } from "/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/cordis/lib/index.js";
import LocalJobRegistry from "/home/john/.local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-jobs-local/lib/index.js";

const registry = new LocalJobRegistry(new Context(), { maxConcurrentJobsPerOwner: 4 });
const results = {};
try {
  registry.expect("3c4b4cd4-0f3b-43fc-983c-ad0ab9bafbc1");
} catch (error) {
  results.agentId = error.message;
}
try {
  registry.expect("not-a-job");
} catch (error) {
  results.plainUnknown = error.message;
}
console.log(JSON.stringify(results, null, 2));

const ok =
  results.agentId?.includes("unknown job 3c4b4cd4-0f3b-43fc-983c-ad0ab9bafbc1") &&
  results.agentId?.includes("looks like a subagent/agent id, not a job id") &&
  results.agentId?.includes("list_agents") &&
  results.agentId?.includes("interrupt_agent") &&
  results.plainUnknown === "unknown job not-a-job";
console.log(ok ? "JOB-HINT-CHECK PASS" : "JOB-HINT-CHECK FAIL");
process.exit(ok ? 0 : 1);
