---
name: human-gate
description: Use whenever work needs the user's sign-off before it continues or counts as done — approving a plan, a checkpoint in fyp-orchestrate, final sign-off, pinning a contract value or resolving a TODO(decide), and before anything irreversible or outward-facing (flashing firmware, a session on real hardware, deleting user files, pushing, publishing, submitting). Defines how to hand over, how feedback is graded, and the rules that stop an agent from approving its own work. A process gate only — it never replaces firmware clamps.
---

# Human Gate

> Adapted from alirezarezvani/claude-skills `engineering/human-gate` (MIT, see
> `../THIRD_PARTY_NOTICES.md`). Kept: the gate rules and loop discipline. Dropped: the HTML review
> page and Python scripts — the reviewer here is one person at a terminal, so chat is the surface.

Machine checks answer "do the checks pass?". This answers what no script can: **has the user
looked at this, and are their objections resolved?**

## Hand over, then stop

A handover message has four things, then the turn ends:
1. **What** to review — the path, or the content inline if it's short.
2. **The decision** wanted, in one line.
3. **Pre-mortem** — the most likely reason it is wrong, named before they read it.
4. **Reversibility** — reversible, or not (and what undoing it would cost).

Never poll, sleep or loop waiting for the user. Their reply arrives as the next message.

## Feedback

In chat, or in a sidecar `<artifact>.review.md` if the user prefers to write it in an editor.
Grades:

| Grade | Meaning |
|---|---|
| BLOCKER | stops the work |
| MAJOR | must be fixed before close |
| MINOR / NIT | fix if cheap; never blocks |
| NOTE | information, no action |
| EDIT | `- before:` / `+ after:` — apply the `after` **verbatim**, and to whatever generates the artifact too |
| APPROVE | explicit sign-off |

Ungraded feedback: ask which items are blockers rather than guessing.

## Gate rules — refuse to close when

| | Condition |
|---|---|
| G1 | No review happened. **Never waivable** — a waiver accepts objections; it can't stand in for review. |
| G2 | A BLOCKER or MAJOR is open. |
| G3 | The action is irreversible and there's no explicit APPROVE. "No blockers" or "looks fine" is not enough — ask. |
| G4 | The feedback changed since you last read it. Re-read first. |
| G5 | Three rounds without convergence. **Escalate**: summarise what is still contested and hand it back — never pass. |
| G6 | A waiver with no reason. Record the user's reason verbatim in the ledger or memory. |

Two consecutive NIT-only rounds means it's done — say so rather than opening a third.

## Hard rules

1. Never report done while a gate is closed. Say what is open.
2. Never treat silence, a timeout, or a subagent's verdict as the user's approval.
3. Never paraphrase an EDIT.
4. A human gate is a process gate. Torque and position limits stay unconditional firmware clamps
   (CLAUDE.md); no approval moves them into Python.
