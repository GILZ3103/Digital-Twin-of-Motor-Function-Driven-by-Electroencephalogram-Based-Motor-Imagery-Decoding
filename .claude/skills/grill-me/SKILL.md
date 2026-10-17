---
name: grill-me
description: Interview the user one question at a time about a plan or design until every branch of the decision tree is resolved, giving a recommended answer with each question. Use when the user wants to stress-test a plan, a module design or a hardware choice, says "grill me", or before fyp-orchestrate writes a plan whose open questions would otherwise become guesses. Not for content creation (that is slow-think).
---

# Grill Me

> Derived from Matt Pocock's `grill-me` via alirezarezvani/claude-skills (MIT, see
> `../THIRD_PARTY_NOTICES.md`). The interview discipline is kept; the helper scripts are dropped.

Interview the user relentlessly about every aspect of this plan until you reach shared
understanding. Walk down each branch of the design tree, resolving dependencies between decisions
one by one.

## Rules

1. **One question per turn.** Never bundle.
2. **Give your recommended answer with each question**, with a one-sentence reason.
3. **Look before asking.** If the briefs, `fyp-contracts`, memory or the code can answer it, read
   them and ask the user to confirm instead. The elbow brief governs elbow work.
4. **Don't re-ask settled decisions** — `decision-*` memories and the handover's "do not
   re-litigate" table. Ask only if you have new evidence against one, and name the evidence.
5. **Depth-first.** Finish a branch before opening another; if B depends on A, ask A first.

## Each turn

```
Q[i]/[total]: <question>
Recommended: <your answer> — <one-sentence reason>
```
or
```
Q[i]/[total]: I found <evidence> in <file>. That implies <answer>. Confirm?
```

## Finish

Report "shared understanding reached", then list the locked-in decisions, one line each. Offer to
record those the CLAUDE.md memory triggers cover (a `TODO(decide)` resolved, a hardware route, a
pinned contract value) — write only what the user confirms.
