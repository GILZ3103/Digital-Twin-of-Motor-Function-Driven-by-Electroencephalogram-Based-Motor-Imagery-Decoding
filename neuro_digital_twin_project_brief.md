# Digital Twin of Motor Function — EEG-Driven, Model-Based, Assistive

**Project brief for Claude Code.** This document defines the project scope, architecture, workflow, and tooling so the codebase can be structured and adjusted against a single source of truth. Read this before proposing file structure, dependencies, or build steps.

---

## 1. One-line definition

A closed-loop neurorehabilitation system that decodes EEG motor imagery, drives a **patient-specific musculoskeletal digital twin**, renders it in AR, and commands a **backdrivable actuator that physically assists the patient's own movement on an assist-as-needed basis** — supplying only the force the patient cannot yet produce, and tapering that support as they recover.

---

## 2. What changed from the original scope (read this first)

The project has **pivoted from *visualizing* intended movement to *physically supporting* it.** This is a change in emphasis and goal, not a rejection of the prior work — EEG decoding, LSL streaming, and AR rendering remain the foundation. The changes:

| Aspect | Previous (kinematic MVP) | Current (this brief) |
| --- | --- | --- |
| **Role of the twin** | Preset animation showing how to move | Patient-specific **musculoskeletal model** that characterizes *where and how much* the patient is weak |
| **Role of the actuator** | Mirrors the motion as proprioceptive feedback | **Actively assists** the patient's own effort, calibrated to their deficit |
| **Control paradigm** | Open/close on a discrete command | **Assist-as-needed (AAN)** via impedance control |
| **Adaptation** | None | Assistance adapts across reps/sessions as capability changes |
| **Intelligence source** | Discrete classifier only | Classifier (intent) **+ musculoskeletal model (effort/deficit)** |
| **Scope** | Single 1-DOF finger, fixed | Single joint first, **architecture designed to scale to multi-DOF** |
| **Actuator class** | Hobby position servo | **Backdrivable, torque-capable** actuator (position servo is insufficient — see §6) |

**Rationale for the pivot:** for patients with slow or permanent motor deficit (e.g. spinal-cord injury), *seeing* the correct movement is not the same as being able to *produce* it. The muscle model is not decorative — it is the engine that makes the assistance intelligent, because the gap between the torque a movement demands and the torque the patient can produce **is** the assistance the device must supply.

---

## 3. Core architecture — two loops at separated timescales

The central design principle is **timescale separation** (cascaded control / gain scheduling; formally licensed by singular-perturbation reasoning). The heavy biomechanics that caused the original latency risk are **relocated, not deleted** — they run in a slow loop, so the fast actuation loop stays lightweight.

```
                          ┌─────────────────────────────────────────────┐
                          │           SLOW LOOP  (seconds → sessions)    │
                          │                                              │
   patient state /        │   Musculoskeletal model (OpenSim / MyoSuite) │
   session history  ─────▶│   • estimate torque the MOVEMENT demands     │
                          │   • estimate torque the PATIENT can produce  │
                          │   • deficit = demand − capacity              │
                          │   • → assist parameters {θ_ref, K, B, τ_ff}  │
                          │   • → AR state (weakness, assist %, trend)    │
                          └───────────────┬──────────────────────────────┘
                                          │ writes parameter block
                                          │ BETWEEN movements (held frozen during a movement)
                                          ▼
   EEG (LSL) ─▶ preprocess ─▶ EEGNet ─▶ intent ─▶ ┌──────────────────────────┐
                              (TensorRT)           │  FAST LOOP (kHz servo)   │
                                                   │  impedance / AAN control │──▶ actuator (assist force)
                                                   │  τ = K(θref−θ)+B(θ̇ref−θ̇)+τff │──▶ AR twin (Unity)
                                                   └──────────────────────────┘
```

### Fast loop — the reflex (milliseconds)
- **Job:** intent in, assistive motion out. Nothing else.
- **Input:** discrete intent from EEGNet (Rest / Flex / Extend, extendable to more classes/joints).
- **Control:** **impedance control**, *not* position control. The actuator behaves as a virtual spring-damper pulling the joint along a reference trajectory:
  `τ_assist = K·(θ_ref − θ) + B·(θ̇_ref − θ̇) + τ_ff`
- **Why lightweight:** the law is a handful of multiply-adds evaluated at kHz. It is "dumb" — it executes the parameter block without knowing why the parameters are what they are.
- **Assistance level = K and τ_ff.** High K → device does most of the work. Low K → patient must contribute. The set `{θ_ref, K, B, τ_ff}` is the entire interface to the slow loop, held **constant during a movement**.
- **Latency note:** the *servo* responds in ms, but MI decoding has a floor set by the EEG window (~0.5–2 s of signal, sliding every ~100–250 ms). So intent arrives at a few Hz while the servo executes it smoothly at kHz.

### Slow loop — the clinician (seconds → sessions)
- **Job:** figure out how weak the patient is and how much help each movement needs; update the fast loop and the AR twin.
- **Why it can be slow:** patient capability does not change within a 2 s movement. Fatigue develops over minutes; recovery over sessions. So OpenSim taking ~1 s per solve is fine here.
- **Output:** the parameter block (written between movements) + AR state (which muscles are weak, current assist %, progress trend).
- **The recovery signal:** assistance *decreasing* session-over-session is the rehabilitation outcome — something a kinematic-only twin could never show.

### What passes between loops
Only the small parameter block `{θ_ref, K, B, τ_ff}` (+ AR state). This is the original "hardware–software decoupling" philosophy applied **in time** rather than across modules.

---

## 4. Pretraining strategy (central; do not drop)

Support must be responsive and safe in real time, which means the adaptive behavior is **learned offline and deployed frozen** — never learned on the patient.

- **Environment:** the patient-specific **musculoskeletal model is itself the training environment** (OpenSim, or MuJoCo/MyoSuite for RL). The same model that makes the twin biomechanical doubles as the pretraining ground.
- **Deploy:** train offline → freeze → run cheap inference on the patient under hard safety limits. Same offline-heavy / online-light pattern as the surrogate below.
- **Surrogate for anything fast:** build the full patient model once at calibration; run a lightweight surrogate (lookup table or small regression/network trained on its outputs) for anything that must be frequent. The full model re-fits only rarely (e.g. across sessions).

### On reinforcement learning — scope it carefully
- **Do NOT use RL to raise EEG classification accuracy.** EEGNet is supervised — use the labels. Accuracy levers are subject-specific fine-tuning / transfer learning, better spatial filtering (CSP / FBCSP), artifact rejection, more motor-cortex electrodes, and longer decision windows.
- **RL is defensible only for the *assistance policy*** ("given patient state + movement phase, how much assist?"). Even then:
  - **Never explore on the patient.** Train the policy in the model-sim; deploy frozen. Pretraining is *what makes it real-time-safe.*
  - **For 1-DOF you probably don't need RL yet.** Start with a simple adaptive rule or **Iterative Learning Control** (improves rep-over-rep, analyzable stability). Keep RL as a card for scaling past one joint — and even then, trained in sim, never on the patient.

---

## 5. Module breakdown and tooling

**Module 1 — Input & data routing**
- MVP source: open-source MI datasets (PhysioNet EEG Motor Movement/Imagery, or MOABB-hosted sets).
- Transport: **Lab Streaming Layer (LSL)** — Python replays the dataset as a pseudo-real-time stream over LAN (simulated sensor).
- Deploy phase: physical EEG headset replaces the replay (introduced only after the software/actuation loop is validated — see risk matrix).
- **Tools:** `pylsl`, `mne`, `moabb`, `numpy`, `scipy`.

**Module 2 — Control node (Jetson)**
- Pipeline: LSL in → filtering → **EEGNet** inference → intent → parameter block → actuator command.
- Inference: **EEGNet optimized with TensorRT** for GPU-accelerated, low-latency inference on Jetson.
- **Tools:** PyTorch or TensorFlow/Keras (training), ONNX + **TensorRT** (deployment), Jetson JetPack/L4T, `pyserial` (if bridging to an MCU).

**Module 3 — Digital twin + AR (Unity / PC)**
- **Model-driven, not preset:** the twin reflects joint angles *and* model-derived state (weakness map, assist %).
- Biomechanics: **OpenSim** (Delp/Seth) for IK, inverse dynamics, muscle-force estimation; optionally **MuJoCo / MyoSuite** if RL/sim is used.
- Rendering: **Unity**; AR via **AR Foundation** (or Vuforia).
- Transport: **UDP** for low-latency state from Jetson → Unity.
- **Tools:** `opensim` Python API, Unity + AR Foundation, C# UDP listener.

**Module 4 — Physical actuation (end-effector)**
- Role: deliver **assistive** force (not just mirror motion). Tendon-driven single joint for the MVP.
- **Actuator must be backdrivable and torque-capable** — see §6. This is a change from the hobby servo.
- Control: impedance/AAN on the Jetson, or route via UART to an **ESP32** for a dedicated inner control loop.
- **Tools:** motor driver SDK (see §6), ESP32 firmware (Arduino/PlatformIO or ESP-IDF), PWM/UART.

---

## 6. Hardware decision that is now blocking — force sensing & actuator

The impedance law commands a **torque** and requires the patient to be able to **backdrive** the actuator (so their contribution can be sensed — the contribution defines the deficit, and the deficit is the assistance). **A hobby position servo (SG90-class) cannot do this** — it is a non-backdrivable position device with no torque feedback. It was fine for the old mirror-motion demo; it cannot render a virtual spring.

Three viable actuator routes:

| Route | Force from | Backdrivable | Notes |
| --- | --- | --- | --- |
| **Current-controlled smart servo** (e.g. Dynamixel X-series, current mode) | τ ≈ Kt·I | reasonably, at low gear ratio | **Best starting point** — position + current control in one unit |
| **BLDC + FOC driver** (gimbal motor + ODrive/moteus/SimpleFOC) | current → torque, quasi-direct-drive | yes, very | best fidelity, more build work |
| **Series-elastic actuator (SEA)** (motor + spring + 2 encoders) | F = k·deflection (measured directly) | yes | safest against spastic limb; clean force sensing; costs bandwidth |

**Actuator sizing is an output of the musculoskeletal model, not a guess.** Required torque ≈ (model's peak demanded joint torque) × (target assist fraction) × (safety margin), referred through the tendon moment arm. Build the model, query peak flexion torque for the target patient, and it specifies the motor.

**One open decision drives three things at once** — the actuator, whether RL helps, and how AR shows "weakness." That decision is **how patient effort is sensed**: motor current (cheapest, friction-corrupted), SEA deflection (clean, some mechanism), inline tendon load cell (direct, adds a part), or EMG (richest, most calibration). *Deferred by request — flag it as the next hardware fork.* Note: EEG gives **intent, not effort**; the effort/weakness signal must come from one of these force channels, not from EEG.

---

## 7. Workflow — phased roadmap (re-pointed for the assistive vision)

MVP discipline is retained; the stages are the **road to** the ambitious system, not a replacement for it. Get the fast loop working with fixed assistance first, then layer the adaptive model on top.

1. **Software pipeline (pseudo-real-time).** Train EEGNet on open data (target >70% intent accuracy). Stand up LSL replay. Validate preprocessing → inference → discrete intent locally.
2. **Jetson deployment + acceleration.** Port to Jetson, build the TensorRT pipeline, confirm stable LSL ingest and continuous intent output at low latency.
3. **Digital loop (brain → screen).** Jetson → UDP → Unity. Validate low-latency AR twin driven by the intent stream. *(Twin can start kinematic here, then become model-backed.)*
4. **Physical loop with FIXED assistance.** Backdrivable actuator + impedance controller with **hand-set** K/τ_ff. Acceptance: simulated EEG triggers simultaneous flexion in the AR twin and the physical joint, with the device supplying force.
5. **Model-in-the-loop (slow loop).** Add the patient-specific musculoskeletal model offline; compute deficit → set the parameter block; AR shows weakness + assist %.
6. **Adaptive assistance + pretraining.** Slow loop updates parameters across reps/sessions (ILC or adaptive rule; RL-in-sim optional). AR shows assistance tapering as capability rises.
7. **(Scale / deploy)** Add DOFs; introduce effort sensing (§6) for within-movement modulation; introduce the physical EEG headset.

---

## 8. Risk matrix (updated)

| Risk | Mitigation |
| --- | --- |
| **Muscle-model latency in the control loop** | Do **not** run inverse-dynamics/muscle-force estimation in the fast loop. Keep it in the slow loop / offline; run a surrogate for anything frequent. |
| **Low SNR from physical EEG** | Validate the whole closed loop on LSL replay first; introduce the headset only after software + actuation are proven. |
| **Non-backdrivable actuator defeats AAN** | Choose a torque-capable, backdrivable actuator (§6). The hobby servo is explicitly out for the assistive build. |
| **Unsafe force on a weak/spastic limb** | Impedance (compliant) control + hard torque/position limits + frozen parameters during a movement; SEA gives physical compliance. |
| **RL exploring on the patient** | Train policy in the model-sim, deploy frozen, hard-limit. Prefer ILC/adaptive rule at 1-DOF. |
| **Network latency desyncing feedback** | No HTTP/REST in the loop. UDP direct (Jetson↔Unity) or LSL middleware only. |
| **EEG mistaken for an effort signal** | EEG = intent only. Derive weakness/effort from a force channel (current / SEA / load cell / EMG). |

---

## 9. Suggested reading

Grouped by role in the project; **★ = start here.** For arXiv entries the arXiv ID is given; for journal entries the venue/year is given so each is locatable.

**Assist-as-needed & the clinical foundation**
- ★ Marchal-Crespo, L. & Reinkensmeyer, D. J. (2009). *Review of control strategies for robotic movement training after neurologic injury.* Journal of NeuroEngineering and Rehabilitation, 6, 20. — The paradigm your whole pivot rests on; read for the AAN rationale and the "don't over-assist / guidance hypothesis" argument.
- Frolov, A. A., Mokienko, O., et al. (2017). *Post-stroke rehabilitation training with a motor-imagery-based BCI-controlled hand exoskeleton: a randomized controlled multicenter trial.* Frontiers in Neuroscience, 11, 400. — Clinical evidence that closed-loop MI-BCI + actuation aids recovery.
- Durandau, G., et al. (2019). *Voluntary control of wearable robotic exoskeletons by patients with paresis via neuromechanical modeling.* Journal of NeuroEngineering and Rehabilitation, 16, 91. — Closest to your motivation: post-stroke/incomplete-SCI patients driving an exoskeleton via a musculoskeletal model.

**The "digital twin" framing**
- ★ *A Digital Twin Framework for Precision Neuromusculoskeletal Health Care: Extension Upon Industrial Standards.* Journal of Applied Biomechanics, 39(5), 2023. — Almost your exact system: an SCI use-case integrating EEG headset, stimulation/assistance, and VR inside an NMS-model-driven digital twin.
- García-Rudolph, A., et al. (2025). *Digital twins in stroke rehabilitation: a scoping review.* Topics in Stroke Rehabilitation. — Landscape and open gaps; useful for positioning the contribution.

**EEG intent decoding (fast-loop input)**
- ★ Lawhern, V. J., Solon, A. J., Waytowich, N. R., Gordon, S. M., Hung, C. P. & Lance, B. J. (2018). *EEGNet: a compact convolutional neural network for EEG-based brain–computer interfaces.* Journal of Neural Engineering, 15(5), 056013. — Your decoder.
- *An Accurate EEGNet-based Motor-Imagery Brain-Computer Interface for Low-Power Edge Computing.* arXiv:2004.00077. — EEGNet on low-power edge hardware; directly relevant to the Jetson + TensorRT path.

**Musculoskeletal modeling (twin engine + pretraining environment)**
- Delp, S. L., Anderson, F. C., Arnold, A. S., et al. (2007). *OpenSim: open-source software to create and analyze dynamic simulations of movement.* IEEE Transactions on Biomedical Engineering, 54(11), 1940–1950.
- ★ Seth, A., Hicks, J. L., Uchida, T. K., et al. (2018). *OpenSim: Simulating musculoskeletal dynamics and neuromuscular control to study human and animal movement.* PLoS Computational Biology, 14(7), e1006223. — The modern framework + muscle dynamics; your slow-loop engine.
- Caggiano, V., Wang, H., Durandau, G., Sartori, M. & Kumar, V. (2022). *MyoSuite: A contact-rich simulation suite for musculoskeletal motor control.* arXiv:2205.13600. — RL-ready musculoskeletal simulation = a practical pretraining environment.

**Control, RL & pretraining (the two-loop + policy)**
- Hogan, N. (1985). *Impedance control: an approach to manipulation.* ASME Journal of Dynamic Systems, Measurement, and Control. — Origin of the fast-loop control law.
- ★ *AR3n: A Reinforcement Learning-based Assist-As-Needed Controller for Robotic Rehabilitation.* arXiv:2303.00085. — Directly compares RL-based AAN against BCI/sEMG sensor-based adaptation; read for the tradeoffs behind your "scope RL carefully" decision.
- ★ *Replication of Impedance Identification Experiments on a Reinforcement-Learning-Controlled Digital Twin of Human Elbows.* arXiv:2402.02904. — Your thesis in one paper: an RL-controlled musculoskeletal digital twin (in MyoSuite) used to validate rehab control — including impedance — *before* experiments on real humans.

**(Later) effort sensing branch**
- Durandau, G., Farina, D. & Sartori, M. (2018). *Robust real-time musculoskeletal modeling driven by electromyograms.* IEEE Transactions on Biomedical Engineering, 65(3), 556–564. — For when you add the effort/EMG channel (§6); see also CEINMS (Pizzolato et al., 2015, J. Biomechanics) for the toolbox.
