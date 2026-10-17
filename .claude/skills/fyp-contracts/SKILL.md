---
name: fyp-contracts
description: Use this skill whenever writing or editing code that crosses a module boundary in the neuro digital twin — anything touching electrode/channel arrays, joint angles, torques, stiffness or damping values, the parameter block, UDP packets between Jetson and Unity, UART frames to the ESP32, or ONNX/TensorRT export settings. Defines the interface contracts, unit and sign conventions, and the decisions still outstanding. Load it before writing boundary code, not after.
---

# Neuro Digital Twin — Interface Contracts

> **Status:** living document · last revised 2026-07-26 · phase 0
> Items marked `TODO(decide)` depend on hardware not yet chosen or installed. This file doubles as
> the checklist of decisions still owed — grep it for `TODO(decide)` to see what's outstanding.
> Revise freely — see **Maintenance** at the bottom.

A **contract** is a written agreement about data crossing a boundary between two modules. This
system spans five toolchains (Python/Win11, PyTorch+TensorRT/Jetson, C#/Unity, C++/ESP32, OpenSim),
and every seam between them is a place two pieces of code can silently disagree. *Silently* is the
operative word — most of what follows throws no exception when violated.

Decide these while changing them is free. Changing the sign convention at phase 4 means touching
Python, C# and firmware together and re-validating the whole loop.

---

## 1. Electrode channel order

**The rule: the channel manifest is GENERATED from the data, never typed by hand.**

EEGNet's first depthwise convolution binds spatial filters to *index positions*, not electrode
names. If the live LSL inlet delivers electrodes in a different order than the training loader did,
the model runs, emits confident predictions, and is wrong — no exception, accuracy near chance.
This is the single most dangerous contract in the project.

Do not trust any hand-written electrode list, including one in a paper, a tutorial, or this file.
Generate it once from the actual PhysioNet EDF and commit the artefact:

```python
# scripts/make_channel_manifest.py  — run once, commit the output
import json, mne
raw = mne.io.read_raw_edf(EDF_PATH, preload=False)
json.dump({"source": EDF_PATH, "order": raw.ch_names},
          open("docs/channel_manifest.json", "w"), indent=2)
```

`docs/channel_manifest.json` then becomes the single source of truth. Both the training loader and
the live inlet must assert against it:

```python
assert list(inlet_channel_names) == manifest["order"], "channel order mismatch"
```

**Status:** `TODO(decide)` — manifest not yet generated; no PhysioNet data downloaded at phase 0.
**Phase 1 action:** generate it, commit it, and write the assertion in `tests/contracts/`.

---

## 2. Unit naming rule

**Every symbol carries its unit in its name.** No exceptions, in any language.

| Correct | Wrong |
|---|---|
| `theta_ref_rad` | `theta_ref`, `angle` |
| `theta_dot_ref_rad_s` | `velocity` |
| `tau_ff_Nm` | `torque`, `tau` |
| `K_Nm_per_rad` | `K`, `stiffness` |
| `B_Nm_s_per_rad` | `B`, `damping` |
| `t_ms` | `time` |

This exists because `K` in Nm/deg versus Nm/rad is a factor of 57.3 in the stiffness of a device
pulling on a patient's finger. A naming convention catches that at review time; a comment does not.

**Angles are radians internally.** Degrees only ever appear in UI text and log output, converted at
the display boundary.

---

## 3. Sign conventions

| Quantity | Positive direction |
|---|---|
| `theta` (joint angle) | **flexion** |
| `theta_dot` | increasing flexion |
| `tau` (commanded torque) | assists **flexion** |
| Patient-generated effort | same sign as the motion it produces |

Zero angle is the joint's neutral / fully-extended reference, established at calibration.

A sign disagreement between the Jetson and the ESP32 means the device assists in the wrong
direction. On a weak or spastic limb that is a safety event, not a bug.

---

## 4. Parameter block — the only inter-loop interface

The slow loop writes exactly this, and nothing else, to the fast loop:

| Field | Type | Unit | Range |
|---|---|---|---|
| `theta_ref_rad` | float32 | rad | `TODO(decide)` — joint ROM, set at calibration |
| `K_Nm_per_rad` | float32 | Nm/rad | `TODO(decide)` — output of the musculoskeletal model |
| `B_Nm_s_per_rad` | float32 | Nm·s/rad | `TODO(decide)` |
| `tau_ff_Nm` | float32 | Nm | `TODO(decide)` — bounded by item 8 |

**Two hard invariants:**

1. **Held frozen for the duration of a movement.** The slow loop writes only *between* movements.
   Parameters changing mid-movement is an instability and a safety hazard.
2. **Nothing else crosses.** No muscle activations, no model state, no raw EEG. If something new
   seems to need to cross this boundary, that is a design discussion, not an addition.

The fast loop evaluates only:
`tau = K_Nm_per_rad*(theta_ref_rad - theta_rad) + B_Nm_s_per_rad*(theta_dot_ref - theta_dot) + tau_ff_Nm`

---

## 5. UDP packet — Jetson 🚀 → Unity 🎮

Little-endian (both ends are little-endian; stated so it is never assumed).

| Offset | Field | Type | Unit |
|---|---|---|---|
| 0 | `seq` | uint32 | — |
| 4 | `t_ms` | uint32 | ms since stream start |
| 8 | `theta_rad` | float32 | rad |
| 12 | `theta_dot_rad_s` | float32 | rad/s |
| 16 | `tau_cmd_Nm` | float32 | Nm |
| 20 | `intent` | uint8 | 0=rest, 1=flex, 2=extend |
| 21 | `assist_pct` | uint8 | 0–100 |
| 22 | `_pad` | uint16 | zero |

Total 24 bytes.

**`seq` is mandatory.** UDP is unordered and lossy by design. Unity applies **latest-value-wins**:
drop any packet whose `seq` is not greater than the highest seen. Without this the AR twin snaps
backwards on reordered packets.

Unity side: receive on a background thread, hand off through a thread-safe queue, drain in
`Update()`. Never touch a GameObject off-thread.

**Status:** layout is decided. `assist_pct` semantics `TODO(decide)` — pending the deficit
definition in the slow loop.

---

## 6. UART frame — Jetson 🚀 → ESP32 ⚡

| Setting | Value |
|---|---|
| Baud | `TODO(decide)` — blocked on the actuator route (brief §6) |
| Frame | `TODO(decide)` — likely `0xAA 0x55` header + payload + CRC16 |
| Payload | the parameter block from item 4 |
| Rate | `TODO(decide)` — parameter updates are between-movement, so low |

**Non-negotiable regardless of the above:** the ESP32 must **fail safe on frame loss**. A watchdog
with no valid frame for a defined timeout drives commanded torque to zero. Never hold the last
commanded value indefinitely.

---

## 7. ONNX / TensorRT export

| Setting | Value |
|---|---|
| Opset | `TODO(decide)` — **pin to what the installed JetPack's TensorRT supports**, never the export default |
| Precision | `TODO(decide)` — FP16 vs INT8; INT8 needs a calibration set |
| Input shape | `TODO(decide)` — (1, 1, n_channels, n_samples), fixed batch 1 |
| Window / stride | `TODO(decide)` — 0.5–2 s window, 100–250 ms stride per brief §3 |

**Mandatory gate before an engine is trusted:** compare engine output against the PyTorch model on
identical input, **on the Jetson**. A parity check on the laptop proves nothing — different
TensorRT build, different precision behaviour. See `fyp-troubleshoot` for the depthwise/separable
conv export hazards.

---

## 8. Torque and position limits — safety

**Limits live in ESP32 firmware as unconditional clamps, backed by a hardware current limit.**

They are never in a model's judgement, never in Python, never in a policy network's output range,
and never "reviewed" by an agent. No amount of model review substitutes for a clamp that cannot be
reasoned around.

| Limit | Value |
|---|---|
| `TAU_MAX_NM` | `TODO(decide)` — per brief §6 an **output of the musculoskeletal model**: peak demanded joint torque × target assist fraction × safety margin, referred through the tendon moment arm. Not a guess. |
| `THETA_MIN_RAD` / `THETA_MAX_RAD` | `TODO(decide)` — patient-specific safe ROM, set at calibration |
| `TAU_RATE_MAX_NM_S` | `TODO(decide)` — slew limit; prevents step commands |
| Watchdog timeout | `TODO(decide)` — see item 6 |

Hardware current limit on the driver is set below `TAU_MAX_NM`'s equivalent current, so firmware and
hardware fail independently.

---

## 9. Intent labels

| Value | Meaning |
|---|---|
| 0 | rest |
| 1 | flex |
| 2 | extend |

Fixed and shared by the training label encoding, the engine output ordering, the UDP `intent` field,
and the UART payload. Adding a class means changing all four together — and re-training.

`TODO(decide)` — confidence threshold below which intent falls back to `rest`. A low-confidence
decode must not command assistance.

---

## 10. Literature full-text access

Not a code interface, but it is a project-wide setting `thesis-scout` depends on, so it is tracked
here with everything else outstanding.

| Setting | Value |
|---|---|
| Institutional library proxy URL | `TODO(decide)` — the single highest-value unlock for full text |
| Unpaywall contact email | `TODO(decide)` — required query parameter |
| Crossref polite-pool email | `TODO(decide)` — same address is fine |
| OpenAlex API key | `TODO(decide)` — free, from openalex.org/settings/api; mandatory since 13 Feb 2026 |

The proxy matters because most of the brief's §9 reading list is already reachable free — the arXiv
entries, plus *PLoS Computational Biology*, *Journal of NeuroEngineering and Rehabilitation* and
*Frontiers*, which are all open access. What is left paywalled is mainly the IEEE TBME papers and
Hogan 1985, and those are exactly what a university subscription covers.

Shadow libraries are out of scope. When full text cannot be reached legally, the paper is recorded
with `oa_source: unreachable` and surfaced in the "Full text unreachable" Bases view rather than
quietly dropped.

## Working with this file

**Every resolved `TODO(decide)` triggers two writes:**
1. Update this file with the decided value and delete the marker.
2. Write a memory entry so the decision survives into future sessions — see `CLAUDE.md` for the
   prefix scheme.

**Check what's outstanding:**
```powershell
Select-String "TODO\(decide\)" .claude\skills\fyp-contracts\SKILL.md
```
> Expected: one line per decision still owed

**At phase 1**, every numbered item above becomes an assertion in `tests/contracts/`, and this file
is rendered to `docs/contracts.md` for the thesis. A contract without a test is a comment.

Code style for anything written against these contracts follows `karpathy-guidelines`: simplest
thing that works, surgical changes, and a stated verification step per change.
