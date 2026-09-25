# UPSTREAM DRAFT — route/effort rejection diagnostics are ambiguous

Status: NOT-FILED.

---

**Packages:** `@deepseek-ai/dsh-tool-subagent` 0.1.5-rc.2,
`@deepseek-ai/dsh-llm` 0.1.5-rc.2

## Summary

Two distinct route failures return byte-identical text, and the effort failure
omits the ladder it already knows:

```
# invented id and served-but-not-allowed id, identical:
child LLM route "opencode-go/glm-5.3-flash" is not allowed for this Session

# unsupported effort, no supported ids / default:
provider "opencode-go" model "deepseek-v4.1-flash" does not support reasoning
effort "medium"
```

Drill v4 N1/N3 were indistinguishable; N2 forced a guess (or a separate
`list_subagent_models` call) to learn that the model accepts `low/high/max`.
The LLM runtime already holds `info.reasoning.efforts` and
`info.reasoning.defaultEffort` when it throws, and the delegation tool can ask
`llm.listModels(provider)` on the failure path.

## Suggested fix

1. On a policy miss in `assertAllowedModelSelection` / `listSubagentModels`,
   classify against `llm.listModels(provider)`:
   - served → `… is not allowed for this Session: the provider serves this
     model id, but it is outside the Session's allowed routes`;
   - unserved → `LLM provider "…" does not serve a model with id "…" (child
     LLM route "…" is not allowed for this Session)`.
2. Render the ladder on both effort-rejection sites:
   `— supported: low, high, max (default: high)` (or
   `— supported: none advertised`).

Keep the existing headline substrings so current matchers still work.

**Rejected:** making `restrict()`/`resolveCallWithInfo` consult the Session
allowlist (the LLM layer does not own policy), and adding error codes only
(the model sees text).

## Local patch

`bugs/009-route-effort-diagnostics/` carries both patches and live evidence for
all three classes.
