---
name: verification-before-completion
description: Use when about to claim work is complete, fixed, passing or working — before committing, before reporting a subagent's task as done, before a checkpoint or sign-off. Requires running the verifying command in this message and reading its output before making any success claim; evidence before assertions, always.
---

# Verification Before Completion

> From obra/superpowers `verification-before-completion` (MIT, see `../THIRD_PARTY_NOTICES.md`),
> with project rows added. CLAUDE.md's rule is the same one: a change with no stated check is not
> finished.

## The iron law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

If you haven't run the verifying command in this message, you can't claim it passes.

## The gate

Before claiming any status or expressing satisfaction:
1. **Identify** the command that proves the claim.
2. **Run** it — fresh and complete.
3. **Read** the full output: exit code, failure count.
4. **Verify** the output confirms the claim. If not, state the actual status with the evidence.
5. Only then make the claim — with the evidence.

## What counts

| Claim | Requires | Not enough |
|---|---|---|
| Tests pass | test output this message: 0 failures | an earlier run, "should pass" |
| Bug fixed | the original symptom re-tested and gone | code changed, assumed fixed |
| Regression test works | fails with the fix reverted, passes with it | passes once |
| Requirements met | line-by-line against the brief or plan | tests passing |
| Subagent finished | `git diff --stat` shows the claimed changes, and you checked them | its report says DONE |
| Decoder accuracy | a fresh run on held-out data, with chance level stated | an earlier number, notebook state |
| Works on the rig | measured on the real target this session | LSL replay, sim, or "should" |
| Timing / latency | measured on the target hardware | estimated, or measured on the laptop |

## Red flags — stop

- "should", "probably", "seems to"
- satisfaction before evidence ("Done!", "Perfect!")
- trusting a subagent's success report
- partial verification passed off as full
- "just this once"

## Rationalizations

| Excuse | Reality |
|---|---|
| "Should work now" | Run it. |
| "I'm confident" | Confidence isn't evidence. |
| "The linter passed" | A linter isn't a test. |
| "The agent said success" | Verify independently. |
| "It passed in sim" | Sim isn't the rig. Say "passes in sim". |
