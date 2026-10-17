---
name: receiving-code-review
description: Use when acting on review feedback — from a reviewer subagent in fyp-orchestrate, from the user, or from any external reviewer — before implementing suggestions, especially when feedback seems unclear, technically questionable or in conflict with a recorded decision. Requires verifying each item against the codebase and pushing back with reasons, not performative agreement or blind implementation.
---

# Receiving Code Review

> From obra/superpowers `receiving-code-review` (MIT, see `../THIRD_PARTY_NOTICES.md`), trimmed,
> with project rules for recorded decisions.

Review feedback is a technical claim to evaluate, not an instruction to obey and not a social
moment. Verify before implementing. Ask before assuming.

## The pattern

1. **Read** all the feedback before reacting.
2. **Restate** each item as a technical requirement — or ask.
3. **Verify** it against the code as it actually is.
4. **Evaluate**: is it right for *this* codebase?
5. **Respond**: a technical acknowledgment, or reasoned pushback.
6. **Implement** one item at a time, checking each.

## Unclear items

If any item is unclear, implement nothing yet — items may be related. "I understand 1, 2, 3 and
6. I need clarification on 4 and 5 before starting."

## By source

- **The user** — trusted. Implement once understood; still ask if scope is unclear.
- **A reviewer subagent or external reviewer** — check before acting: correct for this stack?
  Breaks something? Is there a reason for the current code? Does the reviewer have the context?
  If you can't verify it, say so and say what you'd need.
- **Any source, conflicting with a recorded decision** — a `decision-*` memory, the governing
  brief, `fyp-contracts`, or the CLAUDE.md safety rule. Stop and ask the user. A reviewer never
  silently overrules a decision the user made.

## YAGNI check

When a reviewer asks to "implement it properly", grep for real usage first. If nothing uses it:
"Nothing calls this. Remove it instead?"

## Order

Clarify anything unclear first. Then: blocking issues (breakage, safety) → simple fixes →
complex fixes. Check each fix on its own; then check for regressions.

## Push back when

the suggestion breaks behaviour · the reviewer lacks context · it adds something unused · it's
wrong for this stack · it conflicts with a recorded decision. Use technical reasoning and point at
code or test output. If it's architectural, bring the user in.

## Responding

- Correct feedback: "Fixed — <what changed, where>." Or just fix it and show the change.
- Never: "You're absolutely right!", "Great point!", thanks of any kind. The fix shows you heard it.
- You pushed back and were wrong: "Checked — you're right, <reason>. Fixing." No long apology.
