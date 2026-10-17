# EEG Motor-Imagery Pipeline — Implementation Handover

**For:** Claude Code
**From:** planning work done in Cowork
**Project:** EEG Signal & Neural Digital Twin (FYP)
**Scope of this document:** Phase A only — offline work on public data. No hardware required.

---

## 1. Context in one paragraph

This is a final-year project building an EEG motor-imagery decoding pipeline, aimed eventually at controlling an upper-limb effector. The planning phase is finished and the design decisions are settled (Section 7). What remains is implementation. Phase A runs entirely on a public benchmark dataset, establishes a verified baseline, and executes two controlled experiments that generate the project's research contribution. Phase B (own recordings, closed-loop control) is out of scope here.

**The key constraint to respect:** this project must be able to tell a correct implementation from an incorrect one. That is why Step 1 is reproducing a published number, not building something new.

---

## 2. What to build, in order

| # | Deliverable | Acceptance criterion |
|---|---|---|
| A1 | Reproduce the published CSP+LDA baseline | 4-class accuracy within a few points of **65.99%** on BNCI2014_001, within-session |
| A2 | Experiment 1 — electrode row ablation | Six montage configurations, identical pipeline, statistical comparison |
| A3 | Experiment 2 — ASR cutoff vs ERD preservation | Accuracy and ERD magnitude as functions of the ASR cutoff |
| A4 | Causal twin of the validated pipeline | Measured offline-to-online accuracy gap and a latency breakdown |

Build A1 completely and verify it before touching A2.

---

## 3. Environment

```bash
python -m venv .venv && source .venv/bin/activate
pip install moabb mne pyriemann scikit-learn numpy scipy pandas matplotlib seaborn
```

Primary libraries and what each is for:

- **MOABB** — dataset download, parsing, and the evaluation protocols. Use it rather than hand-rolling data loading. It handles the GDF parsing and, critically, prevents protocol mistakes.
- **MNE-Python** — filtering, epoching, CSP, time-frequency analysis for ERD.
- **pyRiemann** — covariance estimation, tangent space projection, MDM.
- **scikit-learn** — classifiers, pipelines, cross-validation.

**Use `sklearn.pipeline.Pipeline` for everything.** Spatial filters and classifiers must be fitted inside each cross-validation fold. This is the single most common defect in student work in this field.

---

## 4. Dataset

**BCI Competition IV dataset 2a**, accessed through MOABB as `BNCI2014_001`.

| Property | Value |
|---|---|
| Subjects | 9 |
| Sessions | 2, recorded on different days |
| Channels | 22 EEG + 3 EOG |
| Sampling rate | 250 Hz |
| Classes | 4 — left hand, right hand, both feet, tongue |
| Trials | 288 per session (576 per subject) |
| Filtering as supplied | 0.5–100 Hz, 50 Hz notch |

```python
from moabb.datasets import BNCI2014_001
dataset = BNCI2014_001()
```

> **Do not hardcode channel names from memory.** Read them from the loaded data. The 22-label enumeration is quoted inconsistently across secondary sources and was never confirmed against the organisers' own description. Print `raw.ch_names` and build the row groupings from what is actually there.

---

## 5. Pipeline specification

Steps in this order. Deviations must be deliberate and recorded.

### 5.1 Preprocessing

| Step | Setting | Note |
|---|---|---|
| 1. Band-pass | **8–30 Hz** | Applied to the **continuous** recording, before epoching |
| 2. Epoch | **0.5 to 2.5 s** after cue onset | Load a wider window (−1 to 4 s) then crop, so filter edges fall outside the analysis window |
| 3. Baseline | rest interval before cue | For ERD computation only, not for the classifier features |
| 4. Artifact | ASR, 0.5 s windows, 50% overlap | Cutoff is **determined by Experiment 2**, not taken from the literature |

**Filter before epoching, never after.** Filtering each epoch separately introduces an edge transient on every epoch — roughly 0.465 s for a typical filter, which is a large fraction of a 2 s analysis window and lands directly in the variance feature.

For the offline pipeline use zero-phase filtering (`filtfilt` / `mne` default). For the causal twin in A4, see Section 6.3.

### 5.2 Decoders

Implement both. The first is the baseline to verify against; the second is the project's primary method.

```python
# Baseline — must reproduce ~65.99%
from mne.decoding import CSP
from sklearn.discriminant_analysis import LinearDiscriminantAnalysis
baseline = Pipeline([("csp", CSP(n_components=8)), ("lda", LinearDiscriminantAnalysis())])

# Primary — Riemannian tangent space
from pyriemann.estimation import Covariances
from pyriemann.tangentspace import TangentSpace
from sklearn.linear_model import LogisticRegression
primary = Pipeline([
    ("cov", Covariances(estimator="oas")),   # shrinkage; not plain sample covariance
    ("ts",  TangentSpace()),
    ("clf", LogisticRegression(max_iter=1000)),
])
```

Notes on the choices:

- `CSP(n_components=8)` for 4-class — MNE applies one-vs-rest internally.
- Use a **shrinkage** covariance estimator (`oas` or `lwf`), not the plain sample covariance. With 22 channels and short windows the sample estimate is poorly conditioned.
- Tangent-space dimensionality is `n(n+1)/2`. At 22 channels that is 253 features from ~288 trials per session. If this overfits, reduce the channel set before the covariance step rather than adding regularisation after it.

### 5.3 Evaluation

```python
from moabb.evaluations import WithinSessionEvaluation, CrossSessionEvaluation
```

Report both, **never pooled**:

- **Within-session** — comparable with the published benchmark number. Optimistic.
- **Cross-session** — train on one session, test on the other. This predicts real deployment. Expect roughly **5 to 15 points lower**.

---

## 6. The three experiments

### 6.1 Experiment 1 — electrode row ablation

**Question:** does electrode row membership change 4-class accuracy when everything else is held constant?

This is the project's primary contribution. No published study varies row membership with all other factors fixed.

Build six configurations from the existing 22-channel montage:

| ID | Configuration | Approx. channels |
|---|---|---|
| C-1 | C row only | 5 |
| C-2 | C + FC rows | 10 |
| C-3 | C + CP rows | 10 |
| C-4 | C + FC + CP (the block) | 15 |
| C-5 | Block + outer 10-20 ring | ~19 |
| C-6 | All available channels | 22 |

**Hold constant across all six:** band, epoch window, artifact handling, feature extraction, classifier, random seed, and cross-validation fold assignment. Only the channel subset varies.

**Run with both decoders** (baseline and primary), to establish whether any row effect is a property of the montage or an interaction with the decoder.

**Analysis:** repeated-measures comparison across configurations. Report **effect size alongside p-values**, and correct for multiple comparisons. Nine subjects is a small sample — say so in the output.

**The cleanest single test is C-2 against C-3.** Both have ten channels, so channel count is controlled and only row membership differs. Treat this as the primary comparison and the rest as supporting.

A null result is a valid and publishable outcome. Report it plainly if that is what the data says.

### 6.2 Experiment 2 — ASR cutoff versus ERD preservation

**Question:** does ASR, while removing artifacts, also attenuate the ERD feature the decoder depends on?

Background: ASR rejects principal components whose variance exceeds a threshold. ERD is itself a variance decrease. Nobody has characterised the interaction, and published cutoff guidance conflicts — one source recommends 10–100, another 20–30, another 7–14.

**Procedure:** sweep the cutoff across the full published range. At each setting record:

1. Classification accuracy
2. Contralateral mu ERD magnitude, relative to unrepaired data
3. Proportion of signal variance removed

Then repeat on data with **deliberately injected artifacts of known type and amplitude**, so artifact removal can be separated from signal removal.

Report the accuracy-optimal cutoff and the ERD-preserving cutoff **separately**. They need not coincide, and that is the interesting result.

ERD is computed as:

```
ERD% = (A − R) / R × 100
```

where `A` is mean band power in the activity interval and `R` in the reference interval. Procedure: band-pass each trial, square each sample, average across trials, average over samples within each interval. **ERD is negative under this convention.**

### 6.3 Experiment 3 — the causal twin

Re-implement the validated pipeline with causal processing and measure what it costs.

| Offline | Causal twin |
|---|---|
| Zero-phase filtering (`filtfilt`) | Minimum-phase FIR, or low-order Butterworth in **second-order-sections** form |
| Whole epoch available | Sliding window, 1 s, with a defined step |
| Filter applied to full recording | **Filter state carried across blocks** — do not re-initialise per window |

Report the accuracy gap between the two, and attribute the end-to-end latency across: window length, filter group delay, feature computation, classifier inference.

Zero-phase filtering uses future samples. In one published study a 1 Hz zero-phase high-pass shifted a measured onset by roughly **106 ms**, where the causal equivalent shifted it by 5 ms. Any offline result is therefore an optimistic bound, and quantifying that bound is the point of this experiment.

---

## 7. Decisions already made — do not re-litigate

These were settled during planning with evidence. Treat them as given.

| Decision | Reason |
|---|---|
| Band is **8–30 Hz** (mu + beta) | Slow potentials are out of scope. This commits the project to discrete classification. |
| **Riemannian tangent space** is the primary decoder | Best performer on the largest public benchmark; fewer hyperparameters; works with fewer electrodes. |
| **Not deep learning** as primary | On this dataset under identical protocol, four of six deep architectures score below CSP+LDA and one reaches 35.29% against a 25% chance level. Insufficient data volume. |
| **Large Laplacian** over small, where a geometric filter is used | Measured r² 0.41 vs 0.30. |
| **CAR must not precede CSP** on the full channel set | CAR drops rank by one; CSP's whitening step then divides by zero. |
| **Spectral regression** before any notch filter | Mains interference is non-stationary; a fixed notch under-removes it and damages neighbouring spectrum. |
| Four degrees of freedom come from a **hybrid architecture**, not four MI classes | Same-limb imagined movements classify at chance. Out of scope for Phase A but constrains Phase B. |

---

## 8. Reporting rules

### Always

- State the **chance level** for the number of classes. 4-class chance is 25%.
- Report **Cohen's kappa** for all multi-class results. For balanced 4-class: `accuracy ≈ 0.75 × kappa + 0.25`.
- Use confidence bounds appropriate to the trial count. With few trials, the upper bound of the chance distribution sits appreciably above the nominal level — exceeding 25% does not by itself demonstrate control.
- Report per-subject results, not only the mean. Subject spread on this dataset is large (published per-subject kappa ranges 0.27 to 0.77).

### Never

- **Never compare AUC to accuracy.** Benchmark two-class results are often ROC-AUC and multi-class are accuracy.
- **Never pool within-session and cross-session results.**
- **Never fit a spatial filter or scaler outside the cross-validation fold.**
- **Never use a fixed peak-to-peak rejection threshold** (e.g. ±150 µV). Applied uniformly, that threshold dropped every trial in 17% of subjects in at least one condition in one published analysis. Use learned per-sensor thresholds.
- **Never segment trials into overlapping windows and then shuffle windows across train and test.** This is the standard leakage route and produces implausibly high numbers.

---

## 9. Calibrated targets

Within-session, 4-class, BNCI2014_001. From the MOABB benchmark.

| Result | Meaning |
|---|---|
| below 45% | Implementation defect. At or near chance. |
| 45–62% | Working but suboptimal. Check band, epoching, artifact settings. |
| **62–69%** | **Objective met.** CSP+LDA published figure is 65.99 ± 15.47%. |
| 69–78% | Good. Riemannian territory — TS+EL is 72.38%, FgMDM 70.14%. |
| ~78% | Benchmark best. ACM+TS+SVM is 77.82%. |
| above 85% | **Audit for leakage before reporting.** Almost certainly a defect. |

Reference points on the same dataset and protocol: ShallowConvNet 72.47%, EEGNet 60.46%, DeepConvNet 35.29%.

---

## 10. Open questions — do not guess

These need a human decision. Flag them rather than choosing.

1. **Lab hardware** — amplifier model, channel count, electrode type. Unknown. Affects Phase B only, but Experiment 1's practical relevance depends on how many channels are ultimately available.
2. **Submission deadline** — unknown. Phase durations are indicative.
3. **Ethics approval** — whether institutional approval is needed for Phase B human recording, and its turnaround. This is on the critical path.
4. **Second modality** — whether SSVEP or EOG is acceptable for the four-DOF selection layer. Affects Phase B architecture.
5. **Assessment** — whether public-dataset results count toward the project's assessed deliverables. Two of the three contributions are Phase A results.

---

## 11. Suggested build order

1. Load BNCI2014_001 through MOABB. Print channel names, sampling rate, trial counts. Confirm the data matches Section 4.
2. Implement the baseline pipeline. Run `WithinSessionEvaluation` on all nine subjects. **Stop and verify against 65.99% before continuing.**
3. Add the Riemannian pipeline. Compare against the baseline on the same folds.
4. Run `CrossSessionEvaluation` on both. Record the gap.
5. Build the channel-subset machinery for Experiment 1. Run all six configurations.
6. Build the ASR sweep for Experiment 2, with the ERD measurement alongside accuracy.
7. Build the causal twin for Experiment 3.

Write results to disk as you go, with the configuration that produced them. Do not rely on notebook state.

---

## 12. Provenance

Every figure quoted in this document traces to a primary source and was fact-checked during planning. Where a source could not be opened directly, the planning documents mark it as attested rather than primary, and no equation numbers should be quoted from those.

The supporting documents in the Claude project are:

- `research-proposal.md` — full academic justification for every decision in Section 7
- `bci-foundations-and-signal-integrity.md` — acquisition detail: impedance, electrodes, amplifiers, environment
- `front-end-signal-chain.md` — the signal chain in Simplified Technical English

If a decision in Section 7 needs defending, the reasoning and the citation are in the proposal.
