# LCPO — Longitudinal Capacity under Partial Observability
# Discrete-time stock-flow model  (minimal sufficiency test)
# Notation: poster symbols noted as [X] beside key variables
options(stringsAsFactors = FALSE)

MINUTES_PER_HOUR <- 60L

params <- list(
  n_weeks          = 104L,
  tail_weeks       = 12L,

  # Capacity — one clinician, full-time template (maximally charitable)
  formal_cap_min   = 40L * MINUTES_PER_HOUR,   # [C^F]
  buffer_cap_min   = 0L,                        # [C^B]

  # Initial state — established panel with pre-existing obligations
  latent_init_min  = 80L * MINUTES_PER_HOUR,   # [D^L_0]; uncleared starts at 0

  # Scheduling policy
  p_in             = 0.25,    # fraction of C^F reserved for intake     [p^in]
  p_surf           = 0.50,    # surfacing rate: active → visible slot    [p^surf]
  p_uti            = 0.775,   # show-up rate (22.5% no-show)

  # Demand dynamics
  p_gen            = 1.00,    # obligation generated per resolved encounter  [p^gen]
  p_out            = 0.05,    # weekly attrition of dormant latent demand    [p^att]

  # Extensibility hooks — dormant at MVP (ratio = 1)
  efficiency       = 1.00,    # η_e  |  R = W × (η_e / σ_c)
  standard_of_care = 1.00,    # σ_c

  # Activation mixture — IID draw each period from panel follow-up distribution
  # Rates correspond to clinical follow-up intervals:
  p_act_quarterly  = 0.08,    # ~13-week interval
  p_act_monthly    = 0.25,    # ~4-week interval
  p_act_biweekly   = 0.50,    # ~2-week interval
  # Panel composition weights (maintenance-heavy = most charitable default):
  w_quarterly      = 0.60,
  w_monthly        = 0.30,
  w_biweekly       = 0.10,

  activation_seed  = 20260413L
)

activation_path <- function(p) {
  set.seed(p$activation_seed)
  sample(
    c(p$p_act_quarterly, p$p_act_monthly, p$p_act_biweekly),
    size    = p$n_weeks,
    replace = TRUE,
    prob    = c(p$w_quarterly, p$w_monthly, p$w_biweekly)
  )
}

kernel_step <- function(latent, uncleared, week, p, p_act_t) {

  # ── 1. ACTIVATION ─────────────────────────────────────────────────────────
  # uncleared: was active last period, failed to clear → activates fully
  # latent: dormant obligations → activate at this period's mixture draw
  latent_active    <- latent * p_act_t
  latent_surviving <- latent * (1 - p_act_t)
  active           <- uncleared + latent_active              # [D^A] total active

  # ── 2. INTAKE ─────────────────────────────────────────────────────────────
  # p_in × C^F reserved for new patients; infinite external queue fills all slots
  intake_reserved <- p$formal_cap_min * p$p_in               # [D_i]
  intake_utilized <- intake_reserved * p$p_uti

  # ── 3. SURFACING ──────────────────────────────────────────────────────────
  # uncleared resurfaces with certainty into available visible slots (priority)
  # remaining room goes to freshly activated latent at p_surf
  visible_room   <- max(0, p$formal_cap_min - intake_reserved)
  uncleared_vis  <- min(uncleared, visible_room)
  room_remaining <- max(0, visible_room - uncleared_vis)
  latent_vis     <- min(latent_active * p$p_surf, room_remaining)

  reentrant_vis   <- uncleared_vis + latent_vis              # [D^v_r]
  reentrant_vis_u <- reentrant_vis * p$p_uti
  active_hidden   <- (uncleared - uncleared_vis) + (latent_active - latent_vis)  # [D^h]

  # ── 4. CAPACITY ───────────────────────────────────────────────────────────
  # no-show slots: booked but patient didn't attend → releases capacity for hidden demand
  # unscheduled slots: formal capacity never booked this period
  scheduled         <- intake_reserved + reentrant_vis
  no_show_slots     <- scheduled - (intake_utilized + reentrant_vis_u)
  unscheduled_slots <- max(0, p$formal_cap_min - scheduled)

  # ── 5. HIDDEN ROUTING ─────────────────────────────────────────────────────
  # Hidden demand absorbs available capacity in priority order
  # Overflow exceeds all routes → returns to uncleared next period
  left            <- active_hidden
  via_no_show     <- min(left, no_show_slots);       left <- left - via_no_show
  via_unscheduled <- min(left, unscheduled_slots);   left <- left - via_unscheduled
  via_buffer      <- min(left, p$buffer_cap_min);    left <- left - via_buffer
  overflow        <- left

  # ── 6. WORKLOAD ───────────────────────────────────────────────────────────
  W_v <- intake_utilized + reentrant_vis_u            # visible  [W_v]
  W_h <- via_no_show + via_unscheduled + via_buffer   # hidden   [W_h]
  W   <- W_v + W_h                                    # total    [W]

  # ── 7. RESOLUTION ─────────────────────────────────────────────────────────
  # R = W × (η_e / σ_c) — extensibility hook; ratio = 1 at MVP
  R <- W * (p$efficiency / p$standard_of_care)

  # ── 8. GENERATION ─────────────────────────────────────────────────────────
  # Each resolved encounter generates a forward obligation
  generated <- R * p$p_gen

  # ── 9. CARRYOVER ──────────────────────────────────────────────────────────
  # latent: surviving dormant + generated, minus weekly attrition [p^att]
  latent_new <- (latent_surviving + generated) * (1 - p$p_out)
  # uncleared: visible reentrant no-shows + overflow (no attrition — still seeking)
  reentrant_return <- reentrant_vis - reentrant_vis_u
  uncleared_new    <- reentrant_return + overflow

  data.frame(
    week            = week,
    p_in            = p$p_in,
    p_surf          = p$p_surf,
    latent_start_h  = latent          / 60,
    active_h        = active          / 60,
    visible_work_h  = W_v             / 60,
    hidden_work_h   = W_h             / 60,
    overwork_h      = via_buffer      / 60,
    total_work_h    = W               / 60,
    slack_h         = max(0, p$formal_cap_min - W_v) / 60,
    overflow_h      = overflow        / 60,
    uncleared_end_h = uncleared_new   / 60,
    latent_end_h    = latent_new      / 60
  )
}

simulate <- function(p) {
  activation <- activation_path(p)
  latent     <- p$latent_init_min
  uncleared  <- 0
  rows       <- vector("list", p$n_weeks)

  for (week in seq_len(p$n_weeks)) {
    row          <- kernel_step(latent, uncleared, week, p, activation[week])
    rows[[week]] <- row
    latent       <- row$latent_end_h    * 60
    uncleared    <- row$uncleared_end_h * 60
  }

  do.call(rbind, rows)
}

simulate_policy <- function(base_p,
                            label,
                            p_surf,
                            reset_week    = NA_integer_,
                            policy_start  = NA_integer_,
                            policy_end    = NA_integer_,
                            p_in_step     = 0,
                            p_in_max      = base_p$p_in,
                            slack_trigger = Inf) {
  activation <- activation_path(base_p)
  latent     <- base_p$latent_init_min
  uncleared  <- 0
  p_in       <- base_p$p_in
  rows       <- vector("list", base_p$n_weeks)

  for (week in seq_len(base_p$n_weeks)) {
    if (!is.na(reset_week) && week == reset_week) {
      p_in <- base_p$p_in
    }

    p        <- base_p
    p$p_in   <- p_in
    p$p_surf <- p_surf

    row          <- kernel_step(latent, uncleared, week, p, activation[week])
    row$scenario <- label
    rows[[week]] <- row
    latent       <- row$latent_end_h    * 60
    uncleared    <- row$uncleared_end_h * 60

    policy_active <- !is.na(policy_start) && week >= policy_start && week <= policy_end
    if (policy_active && row$slack_h > slack_trigger) {
      p_in <- min(p_in + p_in_step, p_in_max)
    }
  }

  do.call(rbind, rows)
}

summarize_tail <- function(history, tail_weeks) {
  tail_rows <- tail(history, tail_weeks)

  data.frame(
    tail_visible_h   = round(mean(tail_rows$visible_work_h),   1),
    tail_hidden_h    = round(mean(tail_rows$hidden_work_h),    1),
    tail_total_h     = round(mean(tail_rows$total_work_h),     1),
    tail_slack_h     = round(mean(tail_rows$slack_h),          1),
    tail_uncleared_h = round(mean(tail_rows$uncleared_end_h),  1),
    tail_latent_h    = round(mean(tail_rows$latent_end_h),     1),
    tail_overflow_h  = round(mean(tail_rows$overflow_h),       1)
  )
}

run_observability_sweep <- function(p) {
  surfacing_sweep <- seq(0.10, 0.60, by = 0.05)

  out <- lapply(surfacing_sweep, function(p_surf) {
    scenario_p        <- p
    scenario_p$p_surf <- p_surf
    history           <- simulate(scenario_p)
    summary           <- summarize_tail(history, p$tail_weeks)
    summary$p_surf    <- p_surf
    summary
  })

  out <- do.call(rbind, out)
  out[, c("p_surf", "tail_visible_h", "tail_hidden_h", "tail_total_h",
          "tail_slack_h", "tail_uncleared_h", "tail_latent_h", "tail_overflow_h")]
}

run_policy_experiment <- function(p) {
  fixed <- simulate_policy(
    base_p = p,
    label  = "fixed_intake",
    p_surf = 0.25
  )

  adaptive <- simulate_policy(
    base_p        = p,
    label         = "adaptive_then_reset",
    p_surf        = 0.25,
    policy_start  = 5L,
    policy_end    = 68L,
    p_in_step     = 0.01,
    p_in_max      = 0.35,
    slack_trigger = 10,
    reset_week    = 69L
  )

  histories <- rbind(fixed, adaptive)

  summaries <- do.call(rbind, lapply(split(histories, histories$scenario), function(df) {
    tail_rows <- tail(df, p$tail_weeks)
    data.frame(
      scenario         = unique(df$scenario),
      tail_p_in        = round(mean(tail_rows$p_in),              2),
      tail_visible_h   = round(mean(tail_rows$visible_work_h),    1),
      tail_latent_h    = round(mean(tail_rows$latent_end_h),      1),
      tail_uncleared_h = round(mean(tail_rows$uncleared_end_h),   1),
      tail_slack_h     = round(mean(tail_rows$slack_h),           1)
    )
  }))

  list(histories = histories, summaries = summaries)
}

print_section <- function(title) {
  cat("\n", paste(rep("=", nchar(title)), collapse = ""), "\n", sep = "")
  cat(title, "\n")
  cat(paste(rep("=", nchar(title)), collapse = ""), "\n", sep = "")
}

main <- function() {
  print_section("LCPO Simulation")

  cat("Defaults\n")
  cat("  weeks:", params$n_weeks, "\n")
  cat("  formal_cap_h:", params$formal_cap_min / 60, "\n")
  cat("  buffer_cap_h:", params$buffer_cap_min / 60, "\n")
  cat("  latent_init_h:", params$latent_init_min / 60, "\n")
  cat("  p_in:", params$p_in, "\n")
  cat("  p_surf:", params$p_surf, "\n")
  cat("  p_uti:", params$p_uti, "\n")
  cat("  p_gen:", params$p_gen, "\n")
  cat("  p_out:", params$p_out, "\n")
  cat("  activation: quarterly", params$w_quarterly,
      "/ monthly", params$w_monthly,
      "/ biweekly", params$w_biweekly, "\n")

  print_section("Observability sweep")
  obs <- run_observability_sweep(params)
  print(obs, row.names = FALSE)

  print_section("Policy experiment")
  pol <- run_policy_experiment(params)
  print(pol$summaries, row.names = FALSE)

  print_section("Final-week snapshots")
  final_rows <- pol$histories[pol$histories$week == params$n_weeks, c(
    "scenario", "week", "p_in",
    "visible_work_h", "hidden_work_h", "overwork_h",
    "slack_h", "uncleared_end_h", "latent_end_h"
  )]
  print(final_rows, row.names = FALSE)
}

main()
