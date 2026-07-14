LCPO — Longitudinal Capacity under Partial Observability

A minimal dynamical model of intake governance in continuity-based (longitudinal) care systems. It isolates a single question and answers it in closed form:

Does the rule for splitting finite capacity between standing follow-up obligations and new intake, on its own, separate unconditional stability from structural divergence?
Answer (within the model class): yes, and the stability boundary has an exact, interpretable, closed form.

________________________________________

Status of the claims (read this first)

This project deliberately separates three epistemic layers. Keeping them distinct is the point; collapsing them is the main failure mode to avoid.

Layer
Claim
Status
1. Analytic
If a system has this structure, the sustainability boundary is `p_in·(1+L) ≤ 1`.
Established. A theorem about the model, confirmed numerically to grid resolution. Needs no empirical validation.
2. Falsifiable prediction
Real panels crossing the boundary accumulate backlog; those below it stay bounded.
Specified, sharp, untested. A risky quantitative prediction.
3. Empirical correspondence
Real continuity-care systems are in this model class (conserved, forward-generating obligation; estimable, stable-enough `L`).
Open. Only data can adjudicate.

The elegance of Layer 1 is NOT evidence for Layer 3. A wrong model can be beautiful. The value here is not "this is true of the world" but "this is provable-or-refutable about the world" — a sharp test where most work in this space offers only unfalsifiable framing.

________________________________________

The model (MVP / first pillar)

Discrete-time, single-clinician, time-quantity (hours) stock-flow. Starts empty.

Two intake-governance regimes on identical demand/capacity dynamics:

A — flexible / residual intake: standing obligations served first; intake takes whatever capacity remains (intake is endogenous).
B — reactive / fixed intake: `p_in · C` reserved off the top for intake; obligations compete for the remainder.
Dormant knobs (held at identity for this pillar): `p_surf = 1` (full observability) and `p_uti = 1` (no no-shows). With these off, the accumulating quantity is capacity-overflowing demand, NOT hidden demand. Observability (the censored-signal claim) is a separate pillar. Outflow composition (formal discharge vs. attrition vs. balking vs. death) is deliberately collapsed into a single `p_out` here and NOT decomposed.

Parameters

Symbol
Meaning
`C`
weekly capacity (hours)
`p_in`
intake reservation fraction (Regime B lever; endogenous in A)
`p_out`
attrition per period (lower = more longitudinal; defines the system class)
`p_act`
activation: fraction of panel obligation coming due per period
`p_gen`
forward obligation generated per served encounter

________________________________________

The central result

Closed-form stability boundary (Regime B)

Let the generation-loop factor `a = (1 − p_act·(1 − p_gen))·(1 − p_out)`.

If `a ≥ 1`: panel diverges for all `p_in` → `max_safe_p_in = 0`.
Else: `max_safe_p_in = M / (M + N)` where
`M = p_out + p_act·(1 − p_gen)·(1 − p_out)`
`N = p_act·p_gen·(1 − p_out)`
(note `M + N = p_out + p_act·(1 − p_out)`, independent of `p_gen`)
The 1-D collapse (case p_gen = 1)

The whole boundary collapses onto a single interpretable composite:

L = p_act · (1 − p_out) / p_out          # follow-up hours generated per hour of intake
max_safe_p_in = 1 / (1 + L)
sustainability condition:  p_in · (1 + L) ≤ 1

Plain language: each hour of intake eventually creates `L` hours of follow-up obligation. Intake is sustainable only if intake plus its own downstream load fits within capacity. Different `(p_act, p_out)` pairs with the same `L` give the same safe cap — the spectrum is genuinely one-dimensional at `p_gen = 1`. `p_gen` is a real third dimension away from 1, but the full closed form above remains exact.

Why this matters operationally: `L` is a ratio of two things a clinic already counts (steady-state follow-up hours ÷ intake hours). The tool collapses from "estimate three latent parameters" to "estimate one observable ratio."

________________________________________

Analytic derivation

Work in Regime B, in the bounded regime (steady state exists, backlog = 0 so all obligations are served each period).

Setup. With `backlog = 0`, the period's obligation is just the activated follow-up: `obligation = follow_due = panel · p_act`. In the bounded regime the remaining capacity after intake covers it, so:

served_oblig  = follow_due = panel · p_act
served_intake = p_in · C

Panel recursion. Generated forward obligation is `generated = (served_oblig + served_intake) · p_gen`. The panel update (activated mass leaves, generated mass enters, then attrition) is:

panel_{t+1} = (panel_t − follow_due + generated) · (1 − p_out)

Substitute `follow_due = panel_t·p_act` and `generated = (panel_t·p_act + p_in·C)·p_gen`:

panel_{t+1} = ( panel_t·(1 − p_act) + (panel_t·p_act + p_in·C)·p_gen ) · (1 − p_out)
= panel_t · (1 − p_act·(1 − p_gen)) · (1 − p_out)  +  p_in·C·p_gen·(1 − p_out)

This is an affine map `panel_{t+1} = a·panel_t + b` with:

a = (1 − p_act·(1 − p_gen)) · (1 − p_out)     # generation-loop factor
b = p_in · C · p_gen · (1 − p_out)

Fixed point. A stable steady state exists iff `a < 1`, giving `panel* = b / (1 − a)`, and the denominator is exactly `M`:

1 − a = p_out + p_act·(1 − p_gen)·(1 − p_out) = M

Sustainability condition. The bounded regime is self-consistent only if the steady-state follow-up demand fits in the capacity left after intake:

panel* · p_act  ≤  C · (1 − p_in)

Substitute `panel* = p_in·C·p_gen·(1 − p_out) / M` and let `N = p_act·p_gen·(1 − p_out)`:

p_in · N / M  ≤  1 − p_in
p_in · (M + N)  ≤  M
p_in  ≤  M / (M + N)          [QED]

Collapse at p_gen = 1. Then `M = p_out` and `N = p_act·(1 − p_out)`, so:

max_safe_p_in = p_out / (p_out + p_act·(1 − p_out)) = 1 / (1 + L),   L = p_act·(1 − p_out)/p_out

The numeric simulation reproduces this boundary to grid resolution across all tested `(p_act, p_gen, p_out)`, confirming the derivation.

________________________________________

Figures produced by the MVP

FIG 1 — Mechanism: intake crossover (A admits more early, then throttles) + cumulative completed care (A ≥ B).
FIG 2 — Structural: terminal backlog vs `p_out` for both regimes; B tips below a threshold, A bounded across the whole spectrum.
FIG 3 — Phase diagram + derived safe-intake margin: (a) stable/diverging map of B in `(p_in, p_out)`; (b) the `max_safe_p_in` boundary curve — the deliverable.
FIG 4 — Dynamical: hysteresis after a transient demand pulse — A recovers, B stays permanently elevated.
Pinned reference values (baseline: p_in=0.2, p_out=0.05, p_gen=1.0, p_act=0.25, 520 wk)

Intake crossover: week 10
B tips at p_out ≤ ~0.055; A bounded across all p_out
Hysteresis: A settles ~0; B settles ~513 (permanent)
p_gen = 1.0 is NOT a knife-edge (divergence spans p_gen 0.9–1.2)
Safe-intake margin curve: 0.04 → 0.50 across p_out 0.01 → 0.20
Cross-language check: R and Python kernels must reproduce these four values.

________________________________________

Positioning (what is / isn't novel)

The follow-up-vs-access tension is well-known (NHS PIFU; Queensland review-visit waitlist work; practice-management N:F ratio heuristics). Queueing theory owns utilization→nonlinear-delay (Green; the 85% rule; the NICU Mt/Gt/∞ "average-safe still overflows" result). System dynamics is used for chronic-disease prevention, not intake-governance stability. NHS England has a "caseload model" (a planning calculator, not a stability analysis).

The niche this fills: a minimal, legible model of a self-generating longitudinal obligation system that (a) shows the intake-governance rule determines dynamical stability class, (b) yields a closed-form, tunable, per-system safe-intake margin, and (c) reframes ubiquitous "anomalous" accumulation as a deterministic structural consequence, not local mismanagement. Contribution type: synthesis + application + deliverable — NOT new mathematics, NOT a newly discovered phenomenon.

Must-cite nearest neighbors to differentiate against:
NICU Mt/Gt/∞ capacity paper (bounded-LOS bed occupancy vs. our unbounded-horizon self-generating obligation).
NHS England caseload model (planning calculator vs. stability/phase analysis).
Green / queueing theory (specialization to self-generating longitudinal demand, not competition).
________________________________________

Roadmap / next steps

Now (capstone-ready)
[x] Analytic derivation (steady-state recursion → fixed point → boundary). (above)
[ ] Confirm R↔Python parity on the four pinned values.
[ ] Draft the related-work / positioning paragraph using the neighbors above.
Pillar 2 (named, not built for MVP)
[ ] Observability layer: reactivate `p_surf < 1` (the censored-signal claim) as a distinct pillar.
[ ] `p_out` decomposition: split real outflow into appropriate discharge (safe to count as headroom) vs. attrition-unmet / abandonment (must NOT count as headroom). Capacity math is composition-agnostic by design, but counting abandonment as capacity rewards the exact failure the cap exists to prevent — pair the tool with a composition monitor.
[ ] Human-buffer / overwork and quality-degradation loss terms (likely the reason real systems may tip before the `p_in·(1+L)=1` boundary).
Empirical validation layer (the falsification frame)
[ ] Estimate `L` (and `p_gen`, `p_act`, `p_out`) retrospectively from panel/EHR data.
[ ] Test the sharp prediction: do panels above `p_in·(1+L)=1` accumulate, and those below stay bounded?
[ ] Every outcome is informative: clean corroboration → deployable heuristic; directional-but-miscalibrated → localizes the omitted loss term (informs Pillar 2); no prediction → conserved-generation assumption fails, systems aren't in this class (still a real finding).
[ ] Estimation must use recency-weighting / changepoint detection, not a growing pooled mean: narrowing confidence intervals are trustworthy only under confirmed stationarity; a stable-looking average can be confidently wrong across a regime shift.
[ ] Conservative calibration heuristic: err toward lower `p_out` (→ lower `L` → lower cap), since over-estimating headroom is the asymmetrically dangerous error.
Operational artifact (aspirational)
[ ] Per-clinician positioning/monitoring instrument (not an oracle): "here is where your panel sits relative to the stability boundary, with confidence bounds" — a leading-indicator dashboard, decision-rights left with the clinician/manager.
________________________________________

Run

Rscript mvp.R          # writes figures to ./figs, prints pinned summary

Dependencies: base R only. Tune everything in the `PARAMS` / `SWEEPS` blocks; the kernel and figure blocks need no edits for parameter exploration.

________________________________________

Design discipline (guardrails)

Add complexity only where it changes the mechanism, never where it only changes magnitude or realism.
Keep the three epistemic layers distinct: derived result ≠ falsifiable prediction ≠ empirical truth.
Beauty of the formula is not evidence of its correspondence to reality.