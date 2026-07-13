# LCPO — extensions.R
# Tracked-but-UNSOURCED future mechanisms. Code, not prose: prose rots, inert
# code stays coupled to reality. Nothing here is loaded by the live model.
#
# Admission rule (the guardrail): a mechanism enters the live kernel only if it
# changes the MECHANISM, never if it only changes magnitude or realism.

## 1. HUMAN BUFFER — reintroduces an absorber between structural buffers and
## overflow. Deliberately absent from the live kernel: with buffer_cap = 0,
## `unmet` is disposition-agnostic. Turning this on converts part of the
## measured gap into modeled overwork — a different (downstream) research
## question about where unmet demand goes.
route_via_buffer <- function(hidden_left, buffer_cap_min) {
  via_buffer <- min(hidden_left, buffer_cap_min)   # insert after via_unscheduled
  via_buffer                                       # counts as work; add to W_h
}

## 2. RESOLUTION RATIO — efficiency vs standard of care. Identity op at the
## charitable default (ratio = 1, collapsed to R <- W in the kernel). Becomes a
## mechanism only when the ratio departs from 1 (partial resolution feeds back
## into generation).
resolve <- function(work, efficiency = 1.0, standard_of_care = 1.0) {
  work * (efficiency / standard_of_care)
}

## 3. STOCHASTIC ACTIVATION MIXTURE — the poster model's IID weekly draw from a
## clinically anchored follow-up mixture. Injects variance, never mechanism;
## the live kernel uses its expectation (p_act = 0.173). Restore for
## realism-facing runs only.
activation_mixture_path <- function(n_weeks, seed = 20260413L) {
  set.seed(seed)
  sample(c(0.08, 0.25, 0.50),          # quarterly / monthly / biweekly follow-up
         size = n_weeks, replace = TRUE,
         prob = c(0.60, 0.30, 0.10))   # maintenance-heavy panel (charitable)
}

## 4. REDISTRIBUTION ACROSS A GROUP PRACTICE — the entire multi-clinician
## extension, kept to one line of arithmetic by design (a simulation would add
## realism, not mechanism): one clinician's unmet demand lands evenly on peers.
overflow_onto_peers <- function(unmet, n_clinicians) unmet / (n_clinicians - 1)

## 5. CONVEX STRAIN COST — placeholder for pricing sustained overload
## (burnout/attrition risk as a convex function of buffered strain). Requires
## the human buffer (1) to be meaningful; out of scope for the gap-measurement
## claim.
strain_cost <- function(buffered_strain, k = 2) buffered_strain^k
