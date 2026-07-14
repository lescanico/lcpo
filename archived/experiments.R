# LCPO — experiments.R
# Entry point:  Rscript experiments.R
#
# Reporting reframe: the PRIMARY outcome everywhere is unmet demand — cumulative
# (total harm), steady-state rate (still-diverging vs stabilized), and its FTE
# conversion. Everything else is context.
#
# The experiments separate two layers deliberately:
#   PHYSICS (fixed intake)  — what partial observability does on its own
#   GOVERNANCE (thermostats) — what happens when a rational controller acts on
#                              what the dashboard shows
# Headline finding this structure produces: at the charitable defaults the
# physics alone meets all demand at every p_surf; harm enters through the
# controller, and its size is set by WHICH signal the controller can see.

source("params.R")
source("kernel.R")

with_params <- function(p, ...) {
  over <- list(...)
  p[names(over)] <- over
  p
}

print_section <- function(title) {
  bar <- paste(rep("=", nchar(title)), collapse = "")
  cat("\n", bar, "\n", title, "\n", bar, "\n", sep = "")
}

# Per-run scalar summary. Note on semantics: cum_unmet_h sums WEEKLY capacity
# deficits; because unmet demand re-presents (conservation), a persistent
# backlog is counted each week it remains unserved — the correct integrand for
# "extra clinician-hours needed, week by week". It is already net of
# appropriate clearance: attrition (p_out) is applied upstream of overflow.
summarize_run <- function(hist, p) {
  tl  <- tail(hist, p$tail_weeks)
  tot <- sum(hist$active_h)
  fte <- p$annual_fte_min / MINUTES_PER_HOUR
  data.frame(
    cum_unmet_h    = round(sum(hist$unmet_h), 1),
    unmet_rate_h   = round(mean(tl$unmet_h), 2),                # h/wk, tail
    fte_deficit    = round(sum(hist$unmet_h) / fte, 2),         # FTE-years over horizon
    fte_ongoing    = round(mean(tl$unmet_h) * 52 / fte, 2),     # FTEs needed at steady state
    share_served   = round(sum(hist$served_h)   / tot, 3),
    share_absorbed = round(sum(hist$absorbed_h) / tot, 3),
    share_carried  = round(sum(hist$carried_h)  / tot, 3),
    share_unmet    = round(sum(hist$unmet_h)    / tot, 3),
    tail_total_h   = round(mean(tl$total_work_h), 1),
    tail_slack_h   = round(mean(tl$slack_h), 1),
    tail_latent_h  = round(mean(tl$latent_end_h), 1),
    tail_uncleared_h = round(mean(tl$uncleared_end_h), 1)
  )
}

## ── INTAKE GOVERNORS ─────────────────────────────────────────────────────────
# One homeostat, different signals. Constants (experiment-layer, not model):
#   dead band 5-10 h  — keep roughly one clinic day of open time: expand when
#                       >10 h (a day-plus unused), contract when <5 h (less
#                       than half a day of surge room)
#   step 0.01/wk      — gentle governance, 1% of template per week
#   p_in in [0.15, 0.35] — plausible administrative range around the 0.25 default
#   burn_in 4 wk      — let the first month play out before governing
#   burden cap 4xC    — keep total obligations under a month of clinic time
# `reset_week` (E5 only) restores the default p_in, for the recovery question.

make_policy <- function(kind, p, reset_week = NA) {
  step <- 0.01; lo <- 0.15; hi <- 0.35; burn_in <- 4
  if (kind == "fixed") return(NULL)
  function(week, row, p_in) {
    if (!is.na(reset_week) && week >= reset_week) return(p$p_in)
    if (week <= burn_in) return(p_in)
    signal <- switch(kind,
      # unfilled ATTENDED hours — the utilization dashboard. Structural trap:
      # no-shows put a floor of C*(1-p_uti) = 9 h under this signal, so
      # saturation is NEVER visible and the down-step never fires.
      thermo_attended = row$slack_h,
      # unBOOKED hours — the scheduler's availability view. Saturation is
      # visible, but only after hidden demand has surfaced into bookings.
      thermo_booked   = row$open_slots_h,
      # the poster-era pathology: expand on attended slack, never contract
      slack_ratchet   = row$slack_h)
    if (kind == "slack_ratchet") {
      return(if (signal > 10) min(p_in + step, hi) else p_in)
    }
    if (kind == "burden_gov") {
      # estimated TOTAL burden (granted the true stocks: an upper bound showing
      # the signal, not the estimator, is what governs safely)
      burden <- row$latent_end_h + row$uncleared_end_h
      return(if (burden > 4 * p$formal_cap_min / MINUTES_PER_HOUR)
               max(p_in - step, lo) else min(p_in + step, hi))
    }
    if (signal > 10) min(p_in + step, hi)
    else if (signal < 5) max(p_in - step, lo)
    else p_in
  }
}

## ── VERIFICATION ─────────────────────────────────────────────────────────────

# Analytic pin: in the full-service regime (p_uti = 1, p_surf = 1, p_gen < 1,
# from empty) the kernel is linear with fixed point
#   L* = (1-p_out) * p_gen * C*p_in / (1 - (1-p_out) * (1 - p_act*(1-p_gen)))
# Simulated steady state must match the closed form.
verify_analytic_pin <- function(p) {
  q <- with_params(p, p_uti = 1, p_surf = 1, p_gen = 0.5,
                   latent_init_min = 0, n_weeks = 300)
  hist     <- simulate(q)
  L_star_h <- (1 - q$p_out) * q$p_gen * q$formal_cap_min * q$p_in /
    (1 - (1 - q$p_out) * (1 - q$p_act * (1 - q$p_gen))) / MINUTES_PER_HOUR
  assert_close(tail(hist$latent_end_h, 1), L_star_h, "analytic fixed point")
  cat(sprintf("analytic pin OK: simulated latent* = %.2f h, closed form = %.2f h\n",
              tail(hist$latent_end_h, 1), L_star_h))
  cat("conservation: per-week partition + horizon balance asserted inside every run\n")
}

## ── E1: HEADLINE — one thermostat, four signals, across observability ───────

run_p_surf_sweep <- function(p, governor = "fixed", grid = seq(0.1, 0.9, 0.1)) {
  do.call(rbind, lapply(grid, function(s) {
    q <- with_params(p, p_surf = s)
    cbind(data.frame(p_surf = s),
          summarize_run(simulate(q, make_policy(governor, q)), q))
  }))
}

run_governor_ladder <- function(p, governors = c("fixed", "thermo_attended",
                                                 "thermo_booked", "burden_gov")) {
  sweeps <- lapply(governors, function(g) run_p_surf_sweep(p, g))
  names(sweeps) <- governors
  sweeps
}

## ── E2: PHASE MAP — (p_gen, p_out) x p_surf, physics only, from empty ───────
# Cell = net load margin (h/wk) at the tail:
#   positive  = unmet-demand rate (overload; work is capped at C, so overload
#               shows up as unmet, not as total_work - C)
#   negative  = spare visible capacity (slack)
# Exactly one term is nonzero per cell (unmet > 0 implies saturation).
# Horizon doubled: near the phase boundary the transient outlasts 104 wk.

run_phase_map <- function(p, p_gen_grid = seq(0.80, 1.20, 0.025),
                          p_surf_grid = seq(0.1, 0.9, 0.1)) {
  q <- with_params(p, latent_init_min = 0, n_weeks = 208)
  z <- sapply(p_surf_grid, function(s) sapply(p_gen_grid, function(g) {
    tl <- tail(simulate(with_params(q, p_gen = g, p_surf = s)), q$tail_weeks)
    mean(tl$unmet_h) - (q$formal_cap_min / MINUTES_PER_HOUR - mean(tl$total_work_h))
  }))
  list(z = z, p_gen = p_gen_grid, p_surf = p_surf_grid)   # z: gen x surf
}

## ── E3: STRESS TESTS (anti-sophistry) ────────────────────────────────────────

# 3a. Initial conditions must not own the result: sweep p_gen across the phase
# boundary from an empty panel and from an established one (2x cap). If the
# boundary does not move, the claim is "systems DRIFT into this", not merely
# "can't escape it".
run_init_independence <- function(p, p_gen_grid = seq(0.95, 1.15, 0.025),
                                  inits_h = c(0, 80)) {
  do.call(rbind, lapply(inits_h, function(L0) {
    do.call(rbind, lapply(p_gen_grid, function(g) {
      q  <- with_params(p, latent_init_min = L0 * MINUTES_PER_HOUR,
                        p_gen = g, n_weeks = 208)
      tl <- tail(simulate(q), q$tail_weeks)
      data.frame(latent_init_h = L0, p_gen = g,
                 unmet_rate_h = round(mean(tl$unmet_h), 2))
    }))
  }))
}

# 3b. Ratio collapse: if the p_gen/p_out RATIO were the whole mechanism,
# (p_gen, p_out) pairs sharing a ratio would land on the same outcome.
run_ratio_collapse <- function(p) {
  pairs <- data.frame(
    p_gen = c(0.80, 1.00, 1.20,   0.80, 1.00, 1.20),
    p_out = c(0.04, 0.05, 0.06,   0.05, 0.0625, 0.075)
  )
  pairs$ratio <- pairs$p_gen / pairs$p_out
  cbind(pairs, do.call(rbind, lapply(seq_len(nrow(pairs)), function(i) {
    summarize_run(simulate(with_params(p, p_gen = pairs$p_gen[i],
                                       p_out = pairs$p_out[i])), p)
  }))[, c("unmet_rate_h", "tail_latent_h", "tail_uncleared_h")])
}

# 3c. Uncleared leak: does the harm survive when actively-seeking demand can
# attrite (p_out_uncleared > 0)? Run the poster pathology under each leak.
run_leak_toggle <- function(p, leaks = c(0, 0.01, 0.05)) {
  do.call(rbind, lapply(leaks, function(l) {
    q <- with_params(p, p_out_uncleared = l)
    cbind(data.frame(p_out_uncleared = l),
          summarize_run(simulate_scenario(q, "slack_ratchet"), q))
  }))
}

## ── E4: COLLAPSE THRESHOLD (the protective margin) ──────────────────────────
# Closed-form claim: the crowding ratchet has its point of no return where
# uncleared > (1 - p_in) * C  (uncleared alone saturates the visible room and
# can no longer fully re-book). Sweep p_in; check crossings are absorbing
# (never return below) and that persistent unmet demand sets in around them.

run_threshold_check <- function(p, grid = seq(0.10, 0.45, 0.05)) {
  do.call(rbind, lapply(grid, function(pi_) {
    q    <- with_params(p, p_in = pi_, n_weeks = 208)
    hist <- simulate(q)
    thr  <- (1 - pi_) * q$formal_cap_min / MINUTES_PER_HOUR
    over <- hist$uncleared_end_h > thr
    pos  <- hist$unmet_h > 0.1
    cross <- if (any(over)) which(over)[1] else NA
    persistent_unmet <- if (!tail(pos, 1)) NA
                        else if (all(pos)) 1 else max(which(!pos)) + 1
    data.frame(
      p_in                 = pi_,
      threshold_h          = thr,
      cross_week           = cross,
      returned_below       = if (is.na(cross)) NA else any(!over[cross:length(over)]),
      persistent_unmet_wk  = persistent_unmet,
      tail_dU_h_wk         = round(mean(diff(tail(hist$uncleared_end_h, q$tail_weeks + 1))), 2),
      tail_unmet_h         = round(mean(tail(hist$unmet_h, q$tail_weeks)), 1)
    )
  }))
}

## ── E5: POLICY — the poster pathology and its fix (established panel) ────────
# Established panel (2x cap), low observability (p_surf = 0.25). Three intake
# governors: fixed; the poster-era slack ratchet with a reset at week 68 (the
# recovery question); and the burden governor (the fix).

simulate_scenario <- function(p, scenario) {
  q <- with_params(p, p_surf = 0.25, latent_init_min = 80 * MINUTES_PER_HOUR)
  reset <- if (scenario == "slack_ratchet") 68 else NA
  hist <- simulate(q, make_policy(scenario, q, reset_week = reset))
  hist$scenario <- scenario
  hist
}

run_policy_experiment <- function(p) {
  do.call(rbind, lapply(c("fixed", "slack_ratchet", "burden_gov"),
                        function(s) simulate_scenario(p, s)))
}

## ── FIGURES (base R, reference palette; light surface) ──────────────────────

PAL <- list(
  surface = "#fcfcfb", grid = "#e1e0d9", axis = "#c3c2b7",
  ink = "#0b0b0b", ink2 = "#52514e", muted = "#898781",
  served = "#2a78d6", absorbed = "#1baf7a", carried = "#eda100", unmet = "#e34948",
  fixed = "#2a78d6", slack_ratchet = "#e34948", burden_gov = "#1baf7a"
)

open_png <- function(path, w = 1700, h = 1050) {
  png(path, width = w, height = h, res = 150)
  par(family = "sans", bg = PAL$surface, col.axis = PAL$muted,
      col.lab = PAL$ink2, col.main = PAL$ink, las = 1, bty = "n",
      mgp = c(2.4, 0.7, 0), tcl = -0.3)
}

fig_unmet_wedge <- function(sw, path) {
  open_png(path)
  par(mar = c(4.5, 4, 5, 1), xpd = TRUE)
  m <- t(as.matrix(sw[, c("share_served", "share_absorbed", "share_carried", "share_unmet")]))
  bp <- barplot(m, names.arg = sprintf("%.1f", sw$p_surf), col = unlist(PAL[c(
    "served", "absorbed", "carried", "unmet")]), border = PAL$surface, lwd = 2,
    ylim = c(0, 1.02), xlab = "p_surf  (observability: share of activated demand that surfaces)",
    ylab = "share of cumulative panel-active demand",
    main = "The unmet wedge: availability-governed intake as observability falls",
    axes = FALSE)
  mtext("same physics, same thermostat; with fixed intake, unmet demand is zero at every p_surf",
        side = 3, line = 0.4, col = PAL$ink2, cex = 0.85)
  axis(2, at = seq(0, 1, 0.25), labels = sprintf("%.0f%%", seq(0, 100, 25)),
       col = PAL$axis, col.ticks = PAL$axis)
  legend("top", inset = c(0, -0.16), horiz = TRUE, bty = "n",
         fill = unlist(PAL[c("served", "absorbed", "carried", "unmet")]),
         border = NA, text.col = PAL$ink2, cex = 0.85,
         legend = c("served (visible channel)", "absorbed (no-show + unscheduled)",
                    "carried (no-showed, re-presents)", "unmet"))
  # direct-label the headline wedge where it is visible
  for (i in which(sw$share_unmet >= 0.02)) {
    text(bp[i], 1 - sw$share_unmet[i] / 2, sprintf("%.0f%%", 100 * sw$share_unmet[i]),
         col = "white", font = 2, cex = 0.85)
  }
  dev.off()
}

fig_phase_map <- function(pm, path) {
  open_png(path, h = 1150)
  par(mar = c(4.5, 4.5, 4.5, 6))
  # asinh compresses the axis: the supercritical side is ~40x the subcritical
  # side, and a linear diverging scale would wash out all the blues.
  tz   <- asinh(pm$z)
  zmax <- max(abs(tz))
  brks <- seq(-zmax, zmax, length.out = 22)
  cols <- colorRampPalette(c("#0d366b", "#3987e5", "#cde2fb", "#f0efec",
                             "#f5c0bf", "#e34948", "#7a1f1f"))(21)
  image(pm$p_gen, pm$p_surf, tz, breaks = brks, col = cols,
        xlab = "p_gen  (forward obligation per resolved hour; p_out fixed at 0.05)",
        ylab = "p_surf (observability)",
        main = "Net load margin from an EMPTY panel, fixed intake (h/wk, tail of year 4)")
  contour(pm$p_gen, pm$p_surf, pm$z, levels = 0, add = TRUE,
          col = PAL$ink, lwd = 2, drawlabels = FALSE)
  mtext("red: unmet-demand rate    black line: saturation boundary    blue: spare capacity",
        side = 3, line = 0.3, col = PAL$ink2, cex = 0.85)
  par(xpd = TRUE)
  usr <- par("usr"); kx <- usr[2] + 0.02 * diff(usr[1:2])
  ky <- seq(usr[3], usr[4], length.out = 22)
  rect(kx, head(ky, -1), kx + 0.015, tail(ky, -1), col = cols, border = NA)
  kl <- c(-20, -5, 0, 20, 100, 500)   # h/wk, marked on the asinh axis
  text(kx + 0.03, usr[3] + (asinh(kl) + zmax) / (2 * zmax) * diff(usr[3:4]),
       labels = kl, cex = 0.75, col = PAL$muted, adj = 0)
  dev.off()
}

fig_stress <- function(ii, leak_hists, fixed_hist, path) {
  open_png(path, h = 900)
  par(mfrow = c(1, 2), mar = c(4.5, 4, 3.5, 1))
  # (a) the phase boundary does not move with initial conditions
  e <- ii[ii$latent_init_h == 0, ];  f <- ii[ii$latent_init_h == 80, ]
  plot(e$p_gen, e$unmet_rate_h, type = "n",
       xlab = "p_gen (p_out fixed at 0.05)", ylab = "steady-state unmet rate (h/wk)",
       main = "Divergence does not need a loaded start")
  grid(col = PAL$grid, lty = 1)
  lines(f$p_gen, f$unmet_rate_h, col = PAL$carried, lwd = 4)
  lines(e$p_gen, e$unmet_rate_h, col = PAL$served, lwd = 2)
  legend("topleft", bty = "n", lwd = c(2, 4), col = c(PAL$served, PAL$carried),
         legend = c("empty panel (latent = 0)", "established panel (latent = 2x cap)"),
         text.col = PAL$ink2, cex = 0.85)
  # (b) recovery lag under an uncleared leak (poster pathology, reset at wk 68)
  burden <- function(h) h$latent_end_h + h$uncleared_end_h
  ylim <- range(sapply(leak_hists, function(h) range(burden(h))), burden(fixed_hist))
  plot(NA, xlim = c(1, nrow(fixed_hist)), ylim = ylim,
       xlab = "week", ylab = "total burden: latent + uncleared (h)",
       main = "Recovery lag survives an uncleared leak")
  grid(col = PAL$grid, lty = 1)
  abline(v = 68, col = PAL$axis, lty = 2)
  text(68, ylim[2], " policy reset", adj = 0, col = PAL$muted, cex = 0.8)
  lines(fixed_hist$week, burden(fixed_hist), col = PAL$muted, lwd = 2, lty = 2)
  ramp <- c("#86b6ef", "#2a78d6", "#104281")   # ordinal blues, light -> dark
  for (i in seq_along(leak_hists)) {
    lines(leak_hists[[i]]$week, burden(leak_hists[[i]]), col = ramp[i], lwd = 2)
  }
  legend("bottomright", bty = "n", lwd = 2, col = c(ramp, PAL$muted),
         lty = c(1, 1, 1, 2), text.col = PAL$ink2, cex = 0.85,
         legend = c(sprintf("leak = %.2f", c(0, 0.01, 0.05)), "fixed intake (baseline)"))
  dev.off()
}

fig_policy <- function(hists, path) {
  open_png(path, h = 1200)
  par(mfrow = c(2, 1), mar = c(4, 4, 3, 1))
  scen <- c("fixed", "slack_ratchet", "burden_gov")
  labs <- c("fixed intake", "slack ratchet (pathology)", "burden-governed (fix)")
  for (panel in list(c("uncleared_end_h", "uncleared demand (h)", "The ratchet the dashboard cannot see"),
                     c("cum_unmet_h", "cumulative unmet demand (h)", "Total harm"))) {
    ylim <- range(hists[[panel[1]]])
    plot(NA, xlim = c(1, max(hists$week)), ylim = ylim, xlab = "week",
         ylab = panel[2], main = panel[3])
    grid(col = PAL$grid, lty = 1)
    abline(v = 68, col = PAL$axis, lty = 2)
    text(68, ylim[2], " reset", adj = 0, col = PAL$muted, cex = 0.8)
    for (s in scen) {
      d <- hists[hists$scenario == s, ]
      lines(d$week, d[[panel[1]]], col = PAL[[s]], lwd = 2)
    }
    legend("topleft", bty = "n", lwd = 2, col = unlist(PAL[scen]),
           legend = labs, text.col = PAL$ink2, cex = 0.85)
  }
  dev.off()
}

## ── MAIN ─────────────────────────────────────────────────────────────────────

main <- function() {
  p <- params
  dir.create("figs", showWarnings = FALSE)

  print_section("Verification")
  verify_analytic_pin(p)

  print_section("E1  Headline: one thermostat, four signals, across observability")
  ladder <- run_governor_ladder(p)
  cat("cumulative unmet demand (h) over", p$n_weeks, "wk, from an EMPTY panel:\n\n")
  cum <- sapply(ladder, function(sw) sw$cum_unmet_h)
  rownames(cum) <- sprintf("p_surf %.1f", ladder$fixed$p_surf)
  print(round(cum, 1))
  cat("\nfixed:           physics alone — partial observability creates NO unmet demand here\n")
  cat("thermo_attended: utilization dashboard — no-shows floor 'slack' at C*(1-p_uti) = 9 h,\n")
  cat("                 saturation is never visible, the thermostat only expands: runaway at EVERY p_surf\n")
  cat("thermo_booked:   availability dashboard — saturation becomes visible once hidden demand\n")
  cat("                 surfaces into bookings: harm scales with how late that is (THE WEDGE)\n")
  cat("burden_gov:      governing on estimated total burden — safe at every p_surf\n")
  bk <- ladder$thermo_booked
  cat("\nBooked-signal thermostat, detail:\n")
  print(bk[, c("p_surf", "cum_unmet_h", "unmet_rate_h", "fte_deficit", "fte_ongoing",
               "share_served", "share_absorbed", "share_carried", "share_unmet",
               "tail_uncleared_h")], row.names = FALSE)
  cat(sprintf("\nFTE deficit across p_surf 0.9 -> 0.1 (availability-governed): %.2f -> %.2f FTE-years over %d wk;\nongoing shortfall %.2f -> %.2f FTE at steady state\n",
              min(bk$fte_deficit), max(bk$fte_deficit), p$n_weeks,
              min(bk$fte_ongoing), max(bk$fte_ongoing)))
  fig_unmet_wedge(bk, "figs/fig1_unmet_wedge.png")

  print_section("E2  Phase map: p_gen x p_surf from empty (physics, fixed intake)")
  pm <- run_phase_map(p)
  cat("net load margin (h/wk), rows = p_gen, cols = p_surf:\n")
  print(round(`dimnames<-`(pm$z, list(pm$p_gen, pm$p_surf)), 1))
  fig_phase_map(pm, "figs/fig2_phase_map.png")

  print_section("E3a Stress: does the phase boundary move with initial conditions?")
  ii <- run_init_independence(p)
  print(reshape(ii, idvar = "p_gen", timevar = "latent_init_h", direction = "wide"),
        row.names = FALSE)

  print_section("E3b Stress: ratio collapse — same p_gen/p_out, same outcome?")
  print(run_ratio_collapse(p), row.names = FALSE)

  print_section("E3c Stress: does the harm survive an uncleared leak?")
  lk <- run_leak_toggle(p)
  print(lk[, c("p_out_uncleared", "cum_unmet_h", "unmet_rate_h", "fte_deficit",
               "tail_latent_h", "tail_uncleared_h")], row.names = FALSE)
  leak_hists <- lapply(c(0, 0.01, 0.05), function(l)
    simulate_scenario(with_params(p, p_out_uncleared = l), "slack_ratchet"))
  fixed_hist <- simulate_scenario(p, "fixed")
  fig_stress(ii, leak_hists, fixed_hist, "figs/fig3_stress.png")

  print_section("E4  Collapse threshold: onset vs (1 - p_in) x C")
  print(run_threshold_check(p), row.names = FALSE)

  print_section("E5  Policy: the poster pathology and its fix (established panel)")
  hists <- run_policy_experiment(p)
  summaries <- do.call(rbind, lapply(split(hists, hists$scenario), function(d)
    cbind(data.frame(scenario = unique(d$scenario)), summarize_run(d, p))))
  print(summaries[c("fixed", "slack_ratchet", "burden_gov"),
                  c("scenario", "cum_unmet_h", "unmet_rate_h", "fte_deficit",
                    "tail_latent_h", "tail_uncleared_h", "tail_slack_h")],
        row.names = FALSE)
  fig_policy(hists, "figs/fig4_policy.png")

  cat("\nfigures written to figs/\n")
}

main()
