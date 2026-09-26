export const name = "probe-mount-p22";
export const inject = ["agentPresets"];

export function apply(ctx) {
  let ran = false;
  ctx.on("agent/created", ({ agent }) => {
    if (ran) return;
    ran = true;
    ctx.agentPresets.select(agent, "p22-alt").then(
      (switched) => console.error(`[probe-mount-p22] switch to ${switched} for ${agent.id}`),
      (error) => console.error(`[probe-mount-p22] switch failed: ${error?.message ?? error}`),
    );
  });
}
