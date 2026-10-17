---
name: fyp-troubleshoot
description: Use this skill when any part of the neuro digital twin stack breaks — EEG dataset replay, LSL streaming, EEGNet training or inference, ONNX/TensorRT export on the Jetson, OpenSim or MyoSuite setup, Unity UDP reception, or ESP32/motor actuation. Symptom-driven runbook of known failure modes with the exact command to confirm each. Invoke when an import fails, a stream is missing, accuracy drops without an error, an engine mismatches PyTorch, Unity receives nothing, or a motor won't align.
---

# Neuro Digital Twin — Troubleshoot Guide

> **Status:** living document · last revised 2026-07-26 · phase 0
> Entries tagged `[unverified]` came from other people's issue trackers and have **not** been
> reproduced on this rig. On first contact, either replace the tag with the real observed output
> or delete the entry. They are hypotheses about how this will break, not facts about this build.
> Revise freely — see **Maintenance** at the bottom.

## Devices (never changes)

| Tag | Machine | Runs |
|---|---|---|
| 💻 | Windows 11 laptop, PowerShell | dataset replay, EEGNet training, dev |
| 🚀 | NVIDIA Jetson (JetPack/L4T) | TensorRT inference, fast loop |
| ⚡ | ESP32 | actuator inner loop, firmware |
| 🎮 | Unity PC | AR digital twin |

At phase 0 only 💻 exists. Sections for 🚀 ⚡ 🎮 are pre-loaded from research, all `[unverified]`.

---

## 💻 Seam 2–3 — LSL streaming

### Symptom: `FileNotFoundError` on `liblsl64.dll` — but the DLL is right there

**Cause:** Not a missing DLL. Missing **Visual C++ Redistributable**. Windows reports the
dependency failure as if the DLL itself were absent. `[unverified]`
Source: [pylsl#31](https://github.com/labstreaminglayer/pylsl/issues/31)

```powershell
python -c "import pylsl; print(pylsl.library_version())"
```
> Expected: an integer version, e.g. `115`

If it throws, install the Microsoft Visual C++ Redistributable (x64) and retry before touching
anything else.

---

### Symptom: pylsl loads the wrong liblsl build

**Cause:** Multiple LSL installs (conda env plus system-wide). pylsl checks its own package `lib`
folder first, so it can silently bind the wrong build. `[unverified]`

```powershell
python -c "import pylsl,os; print(pylsl.lib.__file__ if hasattr(pylsl,'lib') else os.environ.get('PYLSL_LIB','unset'))"
```
> Expected: one unambiguous path

Pin it explicitly with the `PYLSL_LIB` environment variable rather than guessing.

---

### Symptom: timestamps drift or jitter between sender and receiver

**Cause:** Smoothing timestamps at the **sender**. LSL's own docs warn against this — it injects
artificial drift. `[unverified]`

Push raw, unsmoothed `local_clock()` timestamps from the outlet. Do any smoothing at the receiver.

---

### Symptom: dataset replay dumps the whole file instantly instead of streaming

**Cause:** `mne_lsl.PlayerLSL` `chunk_size` left at a default that does not match a realistic
device cadence. `[unverified]`

Set `chunk_size` deliberately so the outlet pushes at something like a real amplifier's rate.
Replay that is not paced like hardware will hide every timing bug until the headset arrives.

---

## 💻 Seam 1 — dataset download

### Symptom: MOABB download fails — timeout, `429 Too Many Requests`, or "DOI not found"

**Cause:** Zenodo-side rate limiting and mirror flakiness. Not fixable in your code. `[unverified]`

Implement retry-with-backoff, and cache the PhysioNet / BCI-IV-2a files locally so a re-run never
re-downloads. Pin a recent MOABB release rather than an old cached wheel — older versions had
FTP-based fetch paths that have since been patched.

---

## 💻 Seam 4 — preprocessing (the dangerous one)

### Symptom: accuracy collapsed toward chance and **nothing threw an exception**

**Cause:** **Electrode channel order differs between the training loader and the live LSL inlet.**
EEGNet's first depthwise convolution binds spatial filters to *index positions*, not electrode
names. Reordered channels mean the model still runs and still emits confident predictions — just
wrong ones. Silent by construction.

This is the highest-priority check for any unexplained accuracy loss. Check it **before** blaming
the model, the export, or the hardware.

```powershell
python -c "import json;print(json.load(open('docs/channel_manifest.json'))['order'][:8])"
```
> Expected: identical first 8 electrode names as the live inlet reports

Make this a permanent assertion, not a manual check — see item 1 in the `fyp-contracts` skill.
`[unverified as a live failure; the mechanism is certain]`

---

## 🚀 Seam 5 — ONNX export and TensorRT

### Symptom: `trtexec` refuses the ONNX file

**Cause:** Opset mismatch. The exported opset is newer than the installed JetPack's TensorRT
supports. This is the single most common `trtexec` failure class. `[unverified]`
Source: [TensorRT#3346](https://github.com/NVIDIA/TensorRT/issues/3346)

```bash
python -c "import tensorrt as trt; print(trt.__version__)"
```
> Expected: the version, which then fixes your export opset — pin it, do not use the export default

---

### Symptom: engine output differs from PyTorch output

**Cause:** EEGNet's depthwise + separable convolutions are exactly the operator class with the most
ONNX/TensorRT friction. Keras `SeparableConv2D` converts to **two plain `Conv2D` ops**, inflating
the graph and sometimes shifting numerics. `groups` handling for depthwise convs has had
correctness bugs across runtimes. `[unverified]`
Source: [onnxmltools#344](https://github.com/onnx/onnxmltools/issues/344)

Run an `onnxruntime` parity check against the original model **before** building the engine, then
re-check engine vs PyTorch **on the Jetson**.

> A parity check that passes on 💻 proves nothing about 🚀. Different TensorRT build, different
> precision behaviour. `engineering-playbook` §6 — measure on the metal.

---

### Symptom: PyTorch wheel imports on the laptop but not the Jetson

**Cause:** PyTorch / ONNX opset / TensorRT / CUDA versions are coupled to the JetPack image. A
wheel built for one JetPack frequently fails to import, or converts a silently-wrong engine, on
another. `[unverified]`

Match everything to NVIDIA's compatibility matrix for your exact board, and re-validate outputs
on-device.

---

## 💻 Seam — OpenSim / MyoSuite setup (slow loop)

### Symptom: `ImportError: DLL load failed while importing _simbody`

**Cause:** Python-version / OpenSim conda-package mismatch on Windows. OpenSim only ships variants
for specific Python versions, and Python 3.8+ changed how Windows resolves DLLs via PATH.
`[unverified]`

Create a **fresh** conda env on a supported Python, and install `opensim-org::opensim` **first**,
before anything else. Installing it after other packages is the usual cause.

```powershell
python -c "import opensim; print(opensim.GetVersion())"
```
> Expected: a version string

---

### Symptom: OpenSim IK hangs, or returns "Unknown error" after a long run

**Cause:** The IK solver's QP tolerance (0.0001) and 1000-iteration cap are not editable via XML.
Complex or badly-scaled models stall. `[unverified]`

Targets after scaling: **global max marker error < 4 cm, RMS < 2 cm**. If you are outside that, the
scaling is the problem, not the solver. Either lower the accuracy setting (costs roughly 4–8° mean
joint-angle error) or use AddBiomechanics' automated scaling instead of doing it by hand.

---

### Symptom: MuJoCo physics behaves differently than it did last month

**Cause:** MuJoCo's major-version bumps change contact and density defaults. `mujoco-py` is
deprecated and unsupported past MuJoCo 2.1. `[unverified]`

Use the official `mujoco` bindings, and **pin exact `mujoco` and `myosuite` versions** in the
environment file. This is what `scout refresh` watches for.

---

## 🎮 Seam 8–9 — UDP into Unity

### Symptom: expected UDP to work through ROS-TCP-Connector; nothing arrives

**Cause:** ROS-TCP-Connector is **TCP only**. UDP support was requested and never implemented.
`[unverified]`
Source: [ROS-TCP-Connector#375](https://github.com/Unity-Technologies/ROS-TCP-Connector/issues/375)

Hand-roll a C# `UdpClient` layer. Do not try to bend the ROS package into a UDP role.

---

### Symptom: `must be called from the main thread` exception in Unity

**Cause:** UDP receive thread touching `MonoBehaviour`/GameObject state directly. Unity's game loop
is single-threaded. `[unverified]`

Background thread writes into a thread-safe queue; `Update()` drains it. Never touch Unity objects
off-thread.

---

### Symptom: the AR twin jitters or snaps backwards

**Cause:** UDP is unordered and lossy by design; stale packets are being applied. `[unverified]`

Add a sequence number to the packet (see item 5 in `fyp-contracts`) and apply latest-value-wins —
drop any packet older than the newest one seen.

---

## ⚡ Seam 11 — actuator

### Symptom: SimpleFOC `initFOC()` reports "Failed to notice movement"

**Cause:** Insufficient align voltage, wrong sensor type/wiring, or Hall-sensor noise. `[unverified]`

Enable `SimpleFOCDebug` serial output before assuming a hardware fault.

> **Roughly 10° alignment error and ~4° cogging error is NORMAL for a small gimbal motor.** Do not
> chase it as a bug. Alignment can only be skipped with an absolute magnetic sensor, never with an
> incremental encoder or Hall sensors.

---

### Symptom: commanded torque and measured torque never agree (Dynamixel)

**Cause:** By design. `present_current` never exactly matches `goal_current`. In current-based
position mode, goal current acts as a **limiter on the position controller's output**, not as a
torque command. Near zero torque, friction and stiction dominate. `[unverified]`
Source: DynamixelSDK issues #454, #523, #528, #559

This is a hard constraint on `τ_ff` precision, not something to tune away. If fine feed-forward
torque near zero is required, the actuator route is wrong — see brief §6.

---

### Symptom: Dynamixel current-based *position* control exceeds the current limit anyway

**Cause:** Reported and left unresolved upstream — a user expected `Goal_Current` to cap torque the
same way it does in pure current-control mode, but current-based position mode did not hold that
limit reliably. `[unverified]`
Source: [dynamixel-workbench#182](https://github.com/ROBOTIS-GIT/dynamixel-workbench/issues/182)

Do not trust any Dynamixel-firmware current limit as the safety clamp, in *any* control mode. The
hard torque/position clamp still belongs on the ESP32 side per `CLAUDE.md` — this is a second,
independent confirmation of that rule, not a reason to add a software workaround on the Dynamixel
side.

---

### Symptom: SimpleFOC torque-voltage control locks the motor after N revolutions, or the ESP32 crashes/hangs under load

**Cause:** Two distinct root causes reported in the same thread. (1) Insufficient electrical
isolation between the ESP32 and the driver board — motor back-EMF/noise couples into the MCU under
load; physically separating driver and MCU resolved it for one user. (2) Voltage limit set far
higher than the motor/PSU pair needs — one user's fix was dropping the voltage limit from 2V to
~0.2V. `[unverified]`
Source: [SimpleFOC community #6904](https://community.simplefoc.com/t/problems-with-torque-control/6904)

Before debugging control-loop math, check driver/MCU isolation and re-derive the voltage limit from
the actual motor+PSU pair rather than copying a value from an example.

---

### Symptom: a series-elastic actuator's closed-loop force-control bandwidth looks disappointingly low

**Cause:** Not a bug — a fundamental SEA tradeoff. A dedicated Master's-level SEA build (two Arduino
Unos, custom torsional spring) achieved only **~30 Hz closed-loop bandwidth** (up from ~10 Hz
open-loop, a 2.93x improvement) despite good torque accuracy. `[unverified]`
Source: [ITregear/SeriesElasticActuation-FYP](https://github.com/ITregear/SeriesElasticActuation-FYP)

If the virtual-spring loop needs response faster than tens of Hz, budget for this ceiling before
choosing SEA — it buys clean low-friction torque sensing at the cost of bandwidth, not "compliance
for free." For a rehab virtual spring rendered at a few Hz of intended motion this is likely fine;
for anything requiring fast reflexive stiffness changes it is not.

---

## Literature-tooling failures (thesis-scout)

### Symptom: OpenAlex returns almost nothing, or 100-request caps

**Cause:** OpenAlex made its API key **mandatory on 13 February 2026**. Unkeyed access is capped at
100 credits/day, which is demo-only. `[unverified]`

Register the free key. Search costs 10 credits; semantic search costs 100.

---

### Symptom: arXiv returns `429` even at the documented rate

**Cause:** arXiv tightened enforcement in 2026; users report 429s while honouring the published
1-request-per-3-seconds guidance. There is also a hard **2000-result pagination cap** per query.
`[unverified]`

Back off and retry regardless of what the documented limit says. Narrow queries rather than paging
deep.

---

## Maintenance

This file is the project's compounding asset. `scout` writes into it from the outside (mining
closed issues); debugging writes into it from the inside.

- **Append every non-obvious fix here, in the same commit as the fix.** (`engineering-playbook` §8)
- On first contact with an `[unverified]` entry: replace the tag with the actual observed output, or
  **delete the entry**. A wrong entry is worse than a missing one.
- Either resolution — confirmed or disproven — triggers a memory write. See `CLAUDE.md`.
- At each phase boundary in brief §7, re-read this whole file and prune.
- Command style follows the `terminal-guide` skill: one command, one `> Expected:` line.
- Debugging method follows `engineering-playbook` §3 (isolate one wire) and §6 (measure on the
  metal). When the failing layer is unknown, delegate to the `rig-doctor` agent instead of guessing.
