# LCPO: Longitudinal Capacity under Partial Observability

*The road to hell is paved with partial observability.*

------------------------------------------------------------------------

## The claim

In longitudinal care, what dashboards measure (utilization, availability,
throughput) is not what determines whether the system is sustainable
(follow-up obligations, hidden work, latent demand). This repository is a
minimal, auditable, deliberately charitable model of that gap.

The model is a **conservation law under an observability filter**. Demand,
capacity, and workload are a single conserved time-quantity (hours). The one
load-bearing empirical assumption: **unmet demand does not evaporate** — it
carries forward, re-presents, and accumulates. Every week, panel-active demand
partitions exactly into four channels:

| channel | meaning |
|---|---|
| **served** | met through the legitimate visible channel (scheduled, attended) |
| **absorbed** | met through accidental structural buffers (no-show slots + unscheduled slots) |
| **unmet** | overflow — *disposition-agnostic* unmet demand (the headline) |
| **carried** | booked but no-showed; re-presents next week |

There is no human buffer (`buffer_cap = 0`, a principled structural decision):
the model measures the gap and refuses to model where it goes. Conservation is
asserted numerically every step of every run.

## The one-line version

`minimal.R` is the seed-crystal claim in four objects (template, panel,
backlog, thermostat) and one line of arithmetic: attended hours can never
exceed `u·C`, so a utilization dashboard's visible slack can never read below
`C·(1−u)` ≈ 9 h — **the signal is censored exactly where the danger is**. An
intake thermostat that expands on visible slack and contracts on visible
saturation therefore has an arithmetically unreachable contract condition:
it only ever expands, and conserved demand accumulates without bound while
the dashboard shows a day of open time, every week, forever. The same
thermostat governed on total burden is stable. `Rscript minimal.R` prints
both runs and regenerates `figs/fig0_censoring.png`.

## What the model shows

1. **Physics alone is survivable here.** At the charitable defaults, with fixed
   intake, unmet demand is zero at *every* observability level. Partial
   observability does not destroy demand fulfillment directly — it creates
   **misperception**: at `p_surf = 0.1` the dashboard shows ~30 h of weekly
   slack while the clinician is fully loaded.

2. **Harm enters through governance.** Give the same rational thermostat
   (expand intake on visible slack, contract on visible saturation) different
   dashboard signals:
   - **attended-hours slack** — no-shows put a floor of `C·(1−p_uti)` ≈ 9 h
     under this signal, so saturation is *never visible* and the thermostat
     only expands: runaway at every `p_surf` (~2,800–3,000 h unmet over 2 yrs).
   - **booking availability** — saturation becomes visible, but only after
     hidden demand surfaces into bookings: cumulative unmet demand falls
     monotonically from ~770 h at `p_surf = 0.1` to 0 at `p_surf ≥ 0.6`
     (**the unmet wedge**, `figs/fig1_unmet_wedge.png`).
   - **estimated total burden** — safe at every `p_surf`.

3. **Intrinsic runaway is a generation-side phase boundary.** From an *empty*
   panel, overload ignites at `p_gen ≈ 1.05–1.075` (at `p_out = 0.05`), nearly
   independent of `p_surf` and of initial conditions
   (`figs/fig2_phase_map.png`). The runaway stock is *uncleared* demand, whose
   point of no return tracks the closed form `uncleared > (1 − p_in)·C`.

4. **Stress tests (anti-sophistry), built in:** the phase boundary does not
   move with initial panel load ("systems drift into this", not merely "can't
   escape it"); equal `p_gen/p_out` ratios do **not** collapse onto equal
   outcomes (the ratio alone is not the mechanism); with a small attrition
   leak on uncleared demand the steady-state divergence heals but the
   cumulative harm (hundreds of hours) is already banked.

Unmet demand is reported cumulatively (total harm), as a steady-state rate
(diverging vs stabilized), and as an FTE conversion (`cum_unmet_h / 1840`).

## Run it

``` r
Rscript experiments.R
```

No external dependencies (base R only). Prints all experiment tables and
regenerates `figs/fig1`–`fig4`.

## Files

| file | contents |
|---|---|
| `params.R` | every parameter with tier tag (mechanism / policy / passenger), default justification, and sweep rationale |
| `kernel.R` | the stock-flow kernel + conservation assertions |
| `experiments.R` | governor ladder, phase map, stress tests, threshold check, policy experiment, figures |
| `extensions.R` | future mechanisms as inert code (human buffer, resolution ratio, activation mixture, redistribution, strain cost) |

The parameter discipline: every number is swept (Tier 1 mechanism), swept only
in the policy experiments (Tier 2), or frozen with a one-line justification
(Tier 3 passenger). Anything else is a fenced dormant hook. An unjustified
parameter is a hole in the lower-bound argument, so none are allowed.

The poster-era single-file model is preserved at the git tag `poster-2026-04`.
The rebuilt kernel reproduces it exactly (float-level parity) when the
poster's stochastic activation mixture is pinned to its expectation.

## Scope

A minimal conceptual model — a lower-bound argument, not a simulator. It
assumes away nearly everything hard (fungible demand, frictionless capacity,
no strategic behavior, no human buffer) and asks whether partial observability
plus ordinary rational governance is *already* enough to generate divergence
between visible stability and true burden. It is not clinical decision
support, uses no patient data, and does not model where unmet demand goes —
measuring the gap is the complete claim; its fate is a separate research
program.

## Intellectual property notice

This repository contains a minimal conceptual implementation intended for
research and demonstration purposes. It does not represent a production system
or complete operational framework.
