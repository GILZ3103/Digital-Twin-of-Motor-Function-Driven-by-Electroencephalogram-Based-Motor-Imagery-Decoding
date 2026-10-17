# Neuro Digital Twin — standing instructions

## Source of truth

`neuro_digital_twin_project_brief.md` governs this project. This file never restates its content —
read the brief for scope, architecture and roadmap. If this file and the brief ever disagree, the
brief wins and this file is wrong.

## Coding standard

Apply the **`karpathy-guidelines`** skill to all code written here. In short: state assumptions
before implementing, write the minimum code that solves the problem, keep changes surgical, and
frame every task as a verifiable goal.

Its fourth rule matters most for this project — for any multi-step change, state the plan as steps
with a verification per step:

```
1. <step> → verify: <check>
2. <step> → verify: <check>
```

A change with no stated check is not finished.

## Repo layout

Directories mirror the brief's own module numbering (§5), so structure maps 1:1 onto the design and
needs no translation step:

```
src/m1_input/       LSL replay, dataset ingest, preprocessing
src/m2_decode/      EEGNet training, ONNX export, TensorRT inference
src/m3_twin/        digital twin state, UDP sender
src/m4_actuation/   impedance / AAN control, UART bridge
src/m5_slowloop/    OpenSim / MyoSuite, deficit estimation, parameter block
firmware/           ESP32
unity/              AR twin
tests/contracts/    one assertion per item in the fyp-contracts skill
docs/               generated artefacts, references, decisions
```

Nothing above `src/` exists yet — the project is at phase 0. Create directories as their phase
arrives, not in advance.

## Safety — not negotiable

Torque and position limits live in **ESP32 firmware as unconditional clamps**, backed by a hardware
current limit on the driver. They are never in Python, never in a model's output range, and never
"reviewed" by an agent. This device pulls on a weak or spastic limb; no amount of model judgement
substitutes for a clamp that cannot be reasoned around.

## Delegation

| Situation | Use |
|---|---|
| Something broke and the responsible layer is unknown | `rig-doctor` agent |
| Need a library, repo, or example implementation | `scout` agent |
| Need a citation, paper, or prior-art positioning | `thesis-scout` agent |
| Writing code that crosses a module boundary | load the `fyp-contracts` skill first |
| A known symptom recurred | `fyp-troubleshoot` skill |

## Memory — record important updates

Local memory is loaded at the start of every session, which is what makes a decision made in July
still known in November. Write an entry whenever one of these happens:

| Trigger | Filename prefix |
|---|---|
| A `TODO(decide)` in `fyp-contracts` resolves | `decision-` |
| A hardware route is chosen (actuator, effort sensing, EEG headset) | `decision-` |
| A phase boundary in brief §7 is crossed | `decision-` |
| A contract value is pinned (channel order, opset, baud, torque ceiling) | module prefix |
| A `[unverified]` failure mode is confirmed **or disproven** on real hardware | module prefix |
| An agent or skill is materially revised | `tooling-` |
| `thesis-scout` finds literature that changes a design decision | `thesis-` |

Module prefixes: `m1-input-` · `m2-decode-` · `m3-twin-` · `m4-actuation-` · `m5-slowloop-`

Add the matching one-line pointer to `MEMORY.md` under its feature heading, so the index reads as a
labelled table of contents.

**Do not** put in memory what the repo already records — code structure, git history, file contents.
Memory holds *decisions and their reasons*.

## Obsidian vault

Long-form notes live in `C:\Users\HUAWEI\Documents\Obsidian\Skills Development\Neuro Digital Twin\`.

- `Literature/` — written by `thesis-scout`. Never overwrite a note body; it may hold the user's
  own annotations.
- `Synthesis/` — **the user's own finalised conclusions. Never write here.** Read-only for every
  agent and for the main thread.

Memory is short and decision-shaped; the vault is long-form and browsable. The same decision can
appear in both — three lines in memory, a full write-up in `Synthesis/`.

## Also available

- `engineering-playbook` — realtime and edge-device patterns. §3 (isolate one wire), §4 (iterate,
  verify on the real target), §6 (measure on the metal), §8 (write the lesson down).
- `terminal-guide` — command presentation: one command, one `> Expected:` line.
