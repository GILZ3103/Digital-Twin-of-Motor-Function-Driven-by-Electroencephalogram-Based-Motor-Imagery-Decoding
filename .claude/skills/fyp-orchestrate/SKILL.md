---
name: fyp-orchestrate
description: Use when executing a multi-task implementation plan for the neuro digital twin with subagents — a fresh implementer subagent per task, a fresh-context reviewer after each, a bounded fix loop, and human gates at plan approval, user-chosen checkpoints, safety-class work and final sign-off. Also covers writing the plan it executes. Use when the user says "run the plan", "use subagents", "multi-agent", or hands over work with 3+ separable tasks. Not for one-file changes (just do them), an unknown failing layer (rig-doctor), or anything that runs on real hardware.
---

# FYP Orchestrate — subagents with a human in the loop

> Adapted from obra/superpowers `subagent-driven-development` + `writing-plans` (MIT, see
> `../THIRD_PARTY_NOTICES.md`). Changed for this project: upstream never pauses for a human; here
> the human approves the plan, sets the checkpoints, owns every safety-class task and signs off.

## Roles

| Role | Who | Does | Never |
|---|---|---|---|
| Controller | main thread (you) | writes the plan, dispatches, rules on small ambiguities, keeps the ledger | writes product code; fixes review findings itself |
| Implementer | fresh subagent per task | implements, tests, commits, self-reviews, reports | spawns subagents; touches the fence list |
| Reviewer | fresh subagent per review | reads the diff, returns verdicts | edits anything; trusts the implementer's report |
| Human | the user | approves the plan, answers gates, signs off | is assumed to have approved anything they didn't say |

## Before starting

- **Git is required** — review works on diffs. If `git rev-parse --show-toplevel` fails, stop and
  ask the user to run `git init` (and make an initial commit). Do not run it for them.
- **Containment.** Settings run `bypassPermissions`, so an implementer subagent has full tools and
  no prompts (see memory `tooling-bypass-permissions-containment`). The fence below is the only
  boundary. **Fence — no subagent touches:**
  - firmware or microcontroller code, wherever it lives
  - anything that opens a serial/UART port, flashes a board, or commands a motor
  - torque, position or current limits, anywhere
  - package installs outside the project venv; `~/.claude` or any settings file
  - files outside the repo; the Obsidian vault
  - deleting files the task did not create; `git push` or any publish/send
  
  A task that needs any of these is tagged `[HUMAN]` and done in the main thread with the user, or
  by the user.

## 1. Write the plan

Save to `docs/plans/YYYY-MM-DD-<name>.md`. Load `fyp-contracts` first if any task crosses a module
boundary. The plan is the set of decisions an implementer cannot make alone — not the code.

```markdown
# <Name> Plan
**Goal:** one sentence
**Spec:** which document governs (the elbow brief for elbow work) and the section
**Global constraints:** exact values copied verbatim from the spec/contracts, one per line
**Checkpoints:** after Task N, … (the user chooses at approval)

### Task N: <component>  [HUMAN if fenced]
**Files:** create/modify/test — exact paths
**Interfaces:** Consumes: <exact signatures from earlier tasks> · Produces: <what later tasks use>
1. <step> → verify: `<command>` → expected: <output>
2. …
```

Self-check before handing it over: every spec requirement maps to a task; every step has a verify;
names and signatures match across tasks; no step says "TBD", "handle edge cases", or "add tests".

## Gate 1 — plan approval (human)

Follow `human-gate`. Give the plan path, a one-paragraph summary, your recommended checkpoints, and
every open question the plan depends on (a `TODO(decide)` in `fyp-contracts` or an open item in a
brief is a question for the user, never a ruling). End the turn. Nothing is dispatched until the
user explicitly approves.

## 2. Ledger

Workspace: `.runs/<plan-name>/` (add `.runs/` to `.gitignore` if absent). It holds `ledger.md`,
`task-N-brief.md`, `task-N-report.md`, `review-N*.diff`. First ledger line:
`# Ledger — plan: <plan path>`. Lines you append:

```
Task N: complete (<base7>..<head7>, review clean | K parked)
Task N: fix round R/5 (X addressed, Y open — <one-liners>; <a7>..<b7>)
Task N: minor (deferred): <one-liner>
Task N: parked — <finding> — Ruling: <why the code stands>
Ruling: <what you decided> — <why> — <what it costs if wrong>
```

After compaction, trust the ledger and `git log` over your own recollection. Never re-dispatch a
task the ledger marks complete.

## 3. Per-task loop

1. **Brief.** Copy the task's full text verbatim into `task-N-brief.md`. Record `BASE=$(git rev-parse HEAD)`.
2. **Dispatch the implementer** — Agent tool, `subagent_type: general-purpose`, explicit `model`,
   `run_in_background: false`, prompt from [implementer-prompt.md](implementer-prompt.md). The
   dispatch carries: one line on where the task fits, the brief path, interfaces from earlier tasks,
   your resolution of any ambiguity, the report path. Never the session history. Never two
   implementers at once. Record the agent ID.
3. **Handle the status.** DONE → review. DONE_WITH_CONCERNS → read them; correctness concerns get
   resolved before review. NEEDS_CONTEXT → supply it, re-dispatch. BLOCKED → more context, a
   stronger model, a smaller task, or — if the plan is wrong in a way that touches a contract, a
   recorded decision or the fence — ask the user.
4. **Check the claim.** `git diff --stat $BASE..HEAD` must show the files the report claims
   (`verification-before-completion`). A report is not evidence.
5. **Review.** Build the package in one command and hand over the path, not the contents:
   `{ git log --oneline $BASE..HEAD; git diff --stat $BASE..HEAD; git diff -U10 $BASE..HEAD; } > .runs/<plan>/review-N.diff`
   Dispatch a reviewer with [reviewer-prompt.md](reviewer-prompt.md) (mode: task), passing the
   brief, report and diff paths plus the Global Constraints verbatim. Never tell a reviewer what
   not to flag.
6. **Fix loop** — triggered by spec ❌, any Critical/Important, or a ⚠️ you confirm is real. Minors
   go to the ledger as deferred and never enter the loop. Up to 5 rounds; each round is one fix plus
   one scoped re-review ([re-review-prompt.md](re-review-prompt.md)) over `FIX_BASE..HEAD`.
   - Rounds 1–3: resume the same implementer (SendMessage to its ID) with the findings verbatim.
   - Rounds 4–5: fresh implementer one model tier up: "A prior implementer tried N times; read the
     report file for what was tried."
   - **No progress ends the loop early:** a round that addresses zero findings goes straight to cap handling.
   - **At the cap:** park non-load-bearing findings with a ruling. Load-bearing ones (a later task
     builds on it, or it exposes a plan defect) go to the user — this is a gate, not a ruling.
7. **Complete.** Append the completion line. If a checkpoint follows this task, stop and run a
   `human-gate` round: tasks done, the verify output actually seen, rulings since the last
   checkpoint, deferred minors. Continue only on approval.

## Stop and ask — at any point

An irreversible or destructive action · anything on the fence · a ruling that would change a
contract value, a `decision-*` memory, a brief, or a safety limit · a plan so broken that every
path forward is a guess. Everything else you rule on, ledger, and keep going — no "should I
continue?" between checkpoints.

## 4. Final review

Package `MERGE_BASE..HEAD` (the commit before Task 1). Dispatch [reviewer-prompt.md](reviewer-prompt.md)
in final mode on `opus`, pointing it at the deferred and parked ledger lines. If it finds anything:
ONE fix dispatch with the whole list, one scoped re-review, and residual findings go to the user.

## Gate 2 — sign-off (human)

Final message, then end the turn (`human-gate` rules):
- what was built, in one paragraph
- verification evidence — commands run this session and their output
- **Rulings I made** — every `Ruling:` line in the ledger, in order, each with its cost if wrong
- parked findings, deferred minors, open questions

The work is not "done" until the user approves.

## 5. Learn from it

Scan the ledger for a finding class that recurred in 2+ tasks, or a review catch that a test or
contract line would have prevented. **Propose** one line for each — a `fyp-troubleshoot` entry, a
`fyp-contracts` line, a test, or a memory entry under the CLAUDE.md triggers. Write only the ones
the user approves.

## Model selection

Always pass `model` explicitly; an omitted model inherits the session's most expensive one.

| Role | Model |
|---|---|
| Implementer, plan contains the complete code | `haiku` |
| Implementer, default | `sonnet` |
| Implementer, needs design judgment / fix rounds 4–5 | `opus` |
| Task reviewer | `sonnet`; `opus` if the task crosses a module boundary |
| Scoped re-review | `sonnet` |
| Final review | `opus` |

## Rationalizations

| Excuse | Reality |
|---|---|
| "I'll fix it myself, dispatching is overhead" | Controller fixes skip review and pollute your context. |
| "The fix was small, skip the re-review" | Unreviewed fixes are how regressions land. |
| "The user is busy, I'll treat silence as approval" | Silence is not approval. Hand over and end the turn. |
| "It's only a limits tweak in Python" | Limits live in firmware. It's on the fence — stop. |
| "The ruling is obvious, no need to ledger it" | An unledgered ruling is a decision made in secret. |
| "One more round will converge" | A round with zero progress is structural. Escalate. |
