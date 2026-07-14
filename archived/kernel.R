# LCPO — kernel.R
# Discrete-time stock-flow kernel. Deterministic; every line is numerically
# active (identity ops and dead routes live in extensions.R, not here).
#
# Two stocks, both conserved time-quantities (minutes):
#   latent    — dormant forward obligations, not yet seeking care
#   uncleared — demand that presented and was not served (actively seeking)
#
# THE ACCOUNTING IDENTITY IS THE RESULT. Each week, panel-active demand
# partitions exactly into four channels:
#   served    — met through the legitimate visible channel (scheduled, attended)
#   absorbed  — met through accidental structural buffers (no-show slots +
#               unscheduled slots); the only absorbers, since buffer_cap = 0
#   unmet     — overflow: disposition-agnostic unmet demand (THE headline)
#   carried   — booked visibly but no-showed; re-presents next week
# Both this per-week partition and the whole-horizon stock-flow balance are
# asserted on every run; a leak anywhere aborts loudly.

assert_close <- function(a, b, label) {
  if (abs(a - b) > 1e-6 * (1 + abs(b))) {
    stop(sprintf("conservation leak [%s]: %.9f != %.9f", label, a, b))
  }
}

kernel_step <- function(latent, uncleared, p) {
  C <- p$formal_cap_min

  ## 1. ACTIVATION — dormant latent activates at flat rate p_act;
  ##    uncleared is active by definition (it never went dormant).
  latent_active  <- latent * p$p_act
  latent_dormant <- latent - latent_active
  active         <- uncleared + latent_active     # panel-active demand this week

  ## 2. INTAKE — p_in of the template reserved for new patients; an infinite
  ##    external queue fills every reserved slot. Exogenous to the panel:
  ##    reported separately, excluded from the panel partition (its forward
  ##    obligations enter `latent` via generation below).
  intake_booked <- C * p$p_in
  intake_served <- intake_booked * p$p_uti

  ## 3. SURFACING — the observability filter.
  ##    Priority assumption: uncleared re-books with certainty (already engaged,
  ##    front of queue); freshly activated latent surfaces only at p_surf.
  visible_room     <- C - intake_booked
  uncleared_booked <- min(uncleared, visible_room)
  latent_booked    <- min(latent_active * p$p_surf, visible_room - uncleared_booked)
  reentrant_booked <- uncleared_booked + latent_booked
  served           <- reentrant_booked * p$p_uti
  carried          <- reentrant_booked - served   # booked, no-showed -> next week
  hidden           <- active - reentrant_booked   # never reached the schedule

  ## 4. STRUCTURAL BUFFERS — slots freed by no-shows + slots never booked.
  ##    booked <= C by construction, so unscheduled_slots >= 0.
  booked            <- intake_booked + reentrant_booked
  no_show_slots     <- booked * (1 - p$p_uti)
  unscheduled_slots <- C - booked

  ## 5. HIDDEN ROUTING — hidden demand fills buffers in priority order
  ##    (freed slots first, then never-booked slots); the remainder is unmet.
  via_no_show     <- min(hidden, no_show_slots)
  via_unscheduled <- min(hidden - via_no_show, unscheduled_slots)
  absorbed        <- via_no_show + via_unscheduled
  unmet           <- hidden - absorbed

  ## 6. WORK + GENERATION — every worked minute creates p_gen forward
  ##    obligation (resolution ratio collapsed: R = W, see extensions.R).
  work_visible <- intake_served + served
  work_total   <- work_visible + absorbed
  generated    <- work_total * p$p_gen

  ## 7. CARRYOVER
  attrition   <- (latent_dormant + generated) * p$p_out
  latent_new  <- latent_dormant + generated - attrition
  leak        <- (carried + unmet) * p$p_out_uncleared
  uncleared_new <- carried + unmet - leak

  ## PER-WEEK CONSERVATION: active demand partitions exactly into 4 channels.
  assert_close(active, served + absorbed + unmet + carried, "weekly partition")

  h <- MINUTES_PER_HOUR
  data.frame(
    p_in            = p$p_in,
    active_h        = active        / h,
    served_h        = served        / h,
    absorbed_h      = absorbed      / h,
    unmet_h         = unmet         / h,   # HEADLINE channel
    carried_h       = carried       / h,
    intake_served_h = intake_served / h,
    visible_work_h  = work_visible  / h,
    total_work_h    = work_total    / h,
    slack_h         = max(0, C - work_visible) / h,   # dashboard: unfilled ATTENDED hours
    open_slots_h    = unscheduled_slots / h,          # dashboard: unBOOKED hours
    generated_h     = generated     / h,
    attrition_h     = attrition     / h,
    leak_h          = leak          / h,
    latent_end_h    = latent_new    / h,
    uncleared_end_h = uncleared_new / h
  )
}

# simulate() — trajectory mode (one row per week).
# `policy`: optional function(week, row, p_in) -> p_in for next week; NULL =
# fixed intake. This is the only moving part policies may touch.
simulate <- function(p, policy = NULL) {
  latent    <- p$latent_init_min
  uncleared <- 0
  p_live    <- p
  rows      <- vector("list", p$n_weeks)

  for (week in seq_len(p$n_weeks)) {
    row          <- kernel_step(latent, uncleared, p_live)
    row$week     <- week
    rows[[week]] <- row
    latent       <- row$latent_end_h    * MINUTES_PER_HOUR
    uncleared    <- row$uncleared_end_h * MINUTES_PER_HOUR
    if (!is.null(policy)) p_live$p_in <- policy(week, row, p_live$p_in)
  }

  hist <- do.call(rbind, rows)
  hist$cum_unmet_h <- cumsum(hist$unmet_h)

  ## WHOLE-HORIZON STOCK-FLOW BALANCE:
  ## initial stocks + all generation = terminal stocks + all panel work
  ## + all attrition + all leak. (Σ unmet is deliberately absent: overflow
  ## recirculates into `uncleared`; it is a burden integral, not an outflow.)
  h <- MINUTES_PER_HOUR
  inflow  <- p$latent_init_min / h + sum(hist$generated_h)
  outflow <- latent / h + uncleared / h +
    sum(hist$served_h + hist$absorbed_h + hist$attrition_h + hist$leak_h)
  assert_close(inflow, outflow, "horizon stock-flow balance")

  hist
}
