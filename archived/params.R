# LCPO — Longitudinal Capacity under Partial Observability
# params.R — single source of truth for every number in the model.
#
# DISCIPLINE: every parameter is exactly one of
#   [T1 mechanism]  swept — the claim lives here; sweep range justified inline
#   [T2 policy]     swept ONLY in the policy/threshold experiments (actionable knobs)
#   [T3 passenger]  frozen — can change the MAGNITUDE of results, never the mechanism
# Anything that fits none of these is a dormant hook (fenced block at bottom)
# or inert code in extensions.R. An unjustified parameter is a hole in the
# lower-bound argument, so none are allowed.
#
# Units: demand, capacity, and workload are all conserved TIME-QUANTITIES in
# minutes (reported in hours). No agents, no dispositions.

MINUTES_PER_HOUR <- 60

params <- list(

  ## ── T1: MECHANISM (swept) ─────────────────────────────────────────────────

  # Observability filter: fraction of freshly activated latent demand that
  # surfaces into a visible (schedulable) slot. THE independent variable.
  # Default 0.5 = agnostic midpoint, used only when p_surf is not the axis.
  # Sweep 0.1–0.9: near-blind to near-full observability; 0 and 1 are
  # degenerate analytic anchors (nothing surfaces / everything surfaces).
  p_surf = 0.50,

  # Forward-obligation generation: minutes of new latent demand created per
  # minute of resolved care. Default 1.0 is the charitable knife-edge — the
  # pure re-entrant longitudinal-care limit (every visit begets one comparable
  # follow-up). Swept 0.8–1.2, jointly with p_out: the result must hold on a
  # range, not at exactly 1.0, and the joint sweep tests whether the
  # p_gen/p_out ratio alone carries the mechanism (E3b).
  p_gen = 1.00,

  # Weekly attrition of DORMANT latent demand (resolves elsewhere / genuinely
  # clears). Default 0.05/wk gives half-life ≈ 13.5 wk ≈ one quarter: a dormant
  # obligation that has not re-presented within a quarter has meaningfully
  # cleared. Swept jointly with p_gen (E3b ratio-collapse check).
  p_out = 0.05,

  # Initial latent stock. Default 0 = start-from-EMPTY, the strongest ownable
  # claim ("systems DRIFT into overload", not merely "can't escape it").
  # Swept 0 → 2×formal_cap; 2×cap (80 h) is the established-panel scenario
  # carried over from the poster model.
  latent_init_min = 0 * MINUTES_PER_HOUR,

  # Weekly attrition of UNCLEARED (actively seeking) demand. Default 0 is
  # conservation-strict: demand still actively seeking care does not evaporate.
  # Toggled {0, 0.01, 0.05} to disentangle the general birth-death imbalance
  # from a permanent-ratchet artifact (does recovery lag survive a leak?).
  p_out_uncleared = 0,

  ## ── T2: POLICY (swept only in policy/threshold experiments) ───────────────

  # Fraction of the formal template reserved for intake of new patients.
  # Default 0.25 = a quarter of the week, a common access allocation. The one
  # actionable knob; also sets the closed-form crowding threshold: the ratchet
  # ignites when uncleared demand exceeds the visible room (1 − p_in)·C^F.
  p_in = 0.25,

  # Weekly activation rate of dormant latent demand (flat, deterministic).
  # 0.173 = expectation of the poster model's clinically anchored follow-up
  # mixture (0.6×quarterly 0.08 + 0.3×monthly 0.25 + 0.1×biweekly 0.50),
  # i.e. mean follow-up interval ≈ 6 weeks. FROZEN FLAT during mechanism runs:
  # the stochastic mixture injects variance, never mechanism (it lives in
  # extensions.R). T2 because activation policy is in principle steerable.
  p_act = 0.173,

  ## ── T3: PASSENGERS (frozen; magnitude only, never mechanism) ─────────────

  # Formal weekly capacity. 40 h defines 1.0 FTE — the unit of the model;
  # every conserved quantity scales linearly with it.
  formal_cap_min = 40 * MINUTES_PER_HOUR,

  # Human buffer capacity. ZERO IS A PRINCIPLED STRUCTURAL DECISION, not an
  # unset value: with no human absorber, `unmet` (overflow) is DISPOSITION-
  # AGNOSTIC unmet demand — the model measures the gap and refuses to model
  # where it goes (overwork / attrition / quality loss are a separate research
  # program). The kernel therefore has no buffer route at all; reintroducing
  # one is an extension (see extensions.R).
  buffer_cap_min = 0,

  # Show-up rate (1 − no-show). 0.775 ≈ literature-typical outpatient
  # psychiatry no-show of ~22.5%. Passenger: it sets the SIZE of the accidental
  # structural buffer (no-show slots), not whether the mechanism exists.
  # Preserved insight: raising utilization 77.5%→95% removes ~78% of the
  # system's accidental absorption — efficiency optimization strips the
  # life-support (a resilience risk, demonstrable but frozen here).
  p_uti = 0.775,

  # Horizon and steady-state window. 104 wk ≥ 5× the slowest time constant
  # (1/p_out = 20 wk), so tail means are steady-state where a steady state
  # exists; 12-wk tail averages over any residual transient.
  n_weeks = 104,
  tail_weeks = 12,

  # FTE conversion constant (pure arithmetic, no modeling): 40 h/wk clinical
  # template × 46 working weeks. Used to express cumulative unmet hours in
  # units administrators already use.
  annual_fte_min = 40 * 46 * MINUTES_PER_HOUR
)

## ── DORMANT EXTENSION HOOKS (inactive) ──────────────────────────────────────
# Removed from the live kernel because at their defaults they are identity
# operations or dead routes; reactivating any of them is a mechanism change
# and belongs in extensions.R:
#   efficiency / standard_of_care  (ratio = 1 → R <- W collapsed)
#   buffer routing                 (buffer_cap_min = 0 → route deleted)
#   stochastic activation mixture  (flat expectation p_act = 0.173 used instead)
