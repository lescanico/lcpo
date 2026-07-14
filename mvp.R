# LCPO — mvp.R
# First-pillar MVP,
# Run: Rscript mvp.R
#
# Two intake-governance regimes on identical demand/capacity dynamics:
#   A = flexible / residual intake  (obligations served first; intake = residual)
#   B = reactive  / fixed intake     (p_in*C reserved off the top; intake first)
#
# Dormant for this MVP (held at identity, so accumulation = capacity-
# overflowing demand, NOT hidden demand): p_surf = 1 (full observability),
# p_uti = 1 (no no-shows). Those knobs are minimal.R's pillar (the censored-
# signal claim); the compositional mess of outflow (formal discharge vs.
# uncertain attrition/balking/death) is deliberately not modeled as a single
# lever here either. This script isolates one question: does the capacity-
# split rule between standing obligations and new intake, on its own,
# separate unconditional stability from structural divergence?

# ------------------------------- CONFIG -------------------------------------
PARAMS <- list(
  C             = 40.0,   # weekly capacity (hours), single clinician
  n_weeks       = 520,    # horizon (10 yrs): separates divergence from slow transient
  p_in          = 0.20,   # intake reservation fraction (Regime B lever; endogenous in A)
  p_out         = 0.05,   # panel attrition / week. LOWER = more longitudinally-bounded.
  p_gen         = 1.00,   # forward obligation generated per served encounter
  p_act         = 0.25,   # activation: fraction of panel obligation coming due per week
  p_out_backlog = 0.00    # attrition on carried-over backlog (0 = permanent until served)
)

SWEEPS <- list(
  pout_grid     = round(seq(0.01, 0.20, by = 0.005), 4),  # FIG 2 & 3
  pin_grid      = round(seq(0.02, 0.50, by = 0.01),  3),  # FIG 3 (floor 0.02 completes curve)
  pulse_weeks   = c(40, 52),  # FIG 4 transient window, Python-style [start, end)
  pulse_factor  = 1.8,        # FIG 4 p_act multiplier during pulse
  div_slope_eps = 0.05        # divergence: last-third backlog slope threshold (hrs/wk)
)

# ------------------------------- KERNEL -------------------------------------
# One run. regime in {"A","B"}. Starts empty (panel=0, backlog=0).
simulate <- function(regime, C, n_weeks, p_in, p_out, p_gen, p_act, p_out_backlog,
                      act_series = NULL, div_slope_eps = 0.05) {
  panel   <- 0.0   # latent follow-up obligation stock (hours)
  backlog <- 0.0   # carried-over unserved demand (hours)
  intake_t <- backlog_t <- panel_t <- served_t <- numeric(n_weeks)
  completed_care <- 0.0
  overflow_cum   <- 0.0

  for (w in seq_len(n_weeks)) {
    pact       <- if (is.null(act_series)) p_act else act_series[w]
    follow_due <- panel * pact
    obligation <- follow_due + backlog             # follow-up + carried backlog

    if (regime == "B") {                            # fixed intake off the top
      served_intake <- min(p_in * C, C)
      served_oblig  <- min(obligation, C - served_intake)
    } else {                                        # A: obligations first, intake = residual
      served_oblig  <- min(obligation, C)
      served_intake <- max(0.0, C - served_oblig)
    }

    unserved     <- obligation - served_oblig
    overflow_cum <- overflow_cum + max(0.0, unserved)
    generated    <- (served_oblig + served_intake) * p_gen

    panel   <- max(0.0, (panel - follow_due + generated) * (1 - p_out))
    backlog <- max(0.0, unserved * (1 - p_out_backlog))
    completed_care <- completed_care + served_oblig + served_intake

    intake_t[w]  <- served_intake
    backlog_t[w] <- backlog
    panel_t[w]   <- panel
    served_t[w]  <- served_oblig + served_intake
  }

  # Last-third divergence test.
  start <- floor(2 * n_weeks / 3) + 1
  last  <- backlog_t[start:n_weeks]
  idx   <- seq_along(last)
  # Closed-form OLS slope
  slope <- if (length(idx) > 1) cov(idx, last) / var(idx) else 0
  diverging <- (slope > div_slope_eps) && (backlog_t[n_weeks] > 1)

  list(
    intake = intake_t, backlog = backlog_t, panel = panel_t,
    served_total = served_t, terminal_backlog = backlog_t[n_weeks],
    total_care = completed_care, slope = slope, diverging = diverging,
    overflow_cumulative = overflow_cum
  )
}

# Convenience wrapper: run a regime with inline param overrides.
run <- function(regime, act_series = NULL, ...) {
  p <- modifyList(PARAMS, list(...))
  do.call(simulate, c(list(regime = regime, act_series = act_series,
                            div_slope_eps = SWEEPS$div_slope_eps), p))
}

# ------------------------------ PLOTTING -------------------------------------
dir.create("figs", showWarnings = FALSE)

PAL <- list(
  surface = "#fcfcfb", grid = "#e1e0d9", muted = "#898781",
  ink2 = "#52514e", ink = "#0b0b0b",
  A = "#1baf7a",   # flexible/residual -- stable
  B = "#e34948"    # reactive/fixed -- unstable
)

open_png <- function(path, w = 1700, h = 900) {
  png(path, width = w, height = h, res = 150)
  par(family = "sans", bg = PAL$surface, col.axis = PAL$muted,
      col.lab = PAL$ink2, col.main = PAL$ink, las = 1, bty = "n",
      mgp = c(2.4, 0.7, 0), tcl = -0.3, mar = c(4.5, 4, 3.5, 1))
}

# =========================== FIG 1 — MECHANISM ==============================
A <- run("A"); B <- run("B")
wk <- seq_len(PARAMS$n_weeks)

open_png("figs/regime_fig1_mechanism.png", w = 1950, h = 660)
par(mfrow = c(1, 2))

plot(wk, A$intake, type = "l", col = PAL$A, lwd = 2, xlim = c(0, 120),
     ylim = range(A$intake, B$intake), xlab = "week", ylab = "intake (hrs/wk)",
     main = "FIG 1a — Intake crossover")
grid(col = PAL$grid, lty = 1)
lines(wk, B$intake, col = PAL$B, lwd = 2)
legend("topright", bty = "n", lwd = 2, col = c(PAL$A, PAL$B),
       legend = c("A (flexible)", "B (fixed)"), text.col = PAL$ink2)

cumA <- cumsum(A$served_total); cumB <- cumsum(B$served_total)
plot(wk, cumA, type = "l", col = PAL$A, lwd = 2, ylim = range(cumA, cumB),
     xlab = "week", ylab = "cumulative served (hrs)",
     main = "FIG 1b — Cumulative completed care")
grid(col = PAL$grid, lty = 1)
lines(wk, cumB, col = PAL$B, lwd = 2)
legend("topleft", bty = "n", lwd = 2, col = c(PAL$A, PAL$B),
       legend = c("A", "B"), text.col = PAL$ink2)
dev.off()

# Crossover week index
cross <- which(diff(sign(A$intake - B$intake)) != 0) - 1

# ==================== FIG 2 — STRUCTURAL (p_out spectrum) ===================
A_term <- numeric(length(SWEEPS$pout_grid))
B_term <- numeric(length(SWEEPS$pout_grid))
B_tip  <- NULL
for (i in seq_along(SWEEPS$pout_grid)) {
  po <- SWEEPS$pout_grid[i]
  a <- run("A", p_out = po); b <- run("B", p_out = po)
  A_term[i] <- a$terminal_backlog
  B_term[i] <- b$terminal_backlog
  if (b$diverging) B_tip <- po      # ascending grid -> ends at the tipping boundary
}

yA <- log1p(A_term); yB <- log1p(B_term)

open_png("figs/regime_fig2_structural.png", w = 1200, h = 690)
plot(SWEEPS$pout_grid, yA, type = "o", col = PAL$A, pch = 16, cex = 0.6, lwd = 2,
     ylim = range(yA, yB), yaxt = "n",
     xlab = "p_out (attrition; lower = more longitudinal)",
     ylab = "terminal backlog (hrs, log1p scale)",
     main = "FIG 2 — Longitudinal-spectrum tipping")
grid(col = PAL$grid, lty = 1)
ticks <- pretty(c(yA, yB))
axis(2, at = ticks, labels = round(expm1(ticks)))
lines(SWEEPS$pout_grid, yB, type = "o", col = PAL$B, pch = 15, cex = 0.6, lwd = 2)

leg_lab <- c("A (flexible)", "B (fixed)")
leg_lty <- c(1, 1); leg_lwd <- c(2, 2); leg_col <- c(PAL$A, PAL$B)
if (!is.null(B_tip)) {
  abline(v = B_tip + 0.0025, lty = 3, col = PAL$ink)
  leg_lab <- c(leg_lab, sprintf("B tips ~p_out=%s", B_tip))
  leg_lty <- c(leg_lty, 3); leg_lwd <- c(leg_lwd, 1); leg_col <- c(leg_col, PAL$ink)
}
legend("topright", bty = "n", cex = 0.8, text.col = PAL$ink2,
       lty = leg_lty, lwd = leg_lwd, col = leg_col, legend = leg_lab)
dev.off()

# ============= FIG 3 — PHASE DIAGRAM + SAFE-INTAKE MARGIN CURVE =============
pin_g  <- SWEEPS$pin_grid
pout_g <- SWEEPS$pout_grid
DIV <- matrix(0, nrow = length(pout_g), ncol = length(pin_g))
for (i in seq_along(pout_g)) {
  for (j in seq_along(pin_g)) {
    DIV[i, j] <- if (run("B", p_in = pin_g[j], p_out = pout_g[i])$diverging) 1 else 0
  }
}
boundary <- sapply(seq_along(pout_g), function(i) {
  safe <- pin_g[DIV[i, ] == 0]
  if (length(safe) > 0) max(safe) else NA_real_
})

open_png("figs/regime_fig3_phase_margin.png", w = 2100, h = 750)
par(mfrow = c(1, 2))

# FIG 3a -- phase map. image()'s z is indexed [x, y]; our natural loop order
# is [pout, pin], so DIV must be transposed here or the map renders sideways.
image(pin_g, pout_g, t(DIV), col = c(PAL$A, PAL$B), breaks = c(-0.5, 0.5, 1.5),
      xlab = "p_in", ylab = "p_out", main = "FIG 3a — Regime B phase map")
lines(boundary, pout_g, col = PAL$ink, lwd = 2.5)
points(PARAMS$p_in, PARAMS$p_out, pch = 21, bg = "yellow", col = PAL$ink, cex = 1.6)
rect(0.20, 0.02, 0.30, 0.05, border = "blue", lty = 2, lwd = 2)
text(0.25, 0.035, "typical\nlongitudinal\npsychiatry", col = "blue", cex = 0.65, font = 2)
text(0.055, 0.17, "Regime A:\nSTABLE everywhere", col = "darkgreen", cex = 0.85, font = 2,
     adj = c(0, 0.5))  # matplotlib's text() defaults to left-aligned, unlike R's centered default
legend("topright", bty = "n", cex = 0.75, text.col = PAL$ink2,
       legend = c("critical boundary", sprintf("operating pt (%.2f,%.2f)", PARAMS$p_in, PARAMS$p_out)),
       lty = c(1, NA), lwd = c(2.5, NA), pch = c(NA, 21), pt.bg = c(NA, "yellow"),
       col = c(PAL$ink, PAL$ink))

# FIG 3b -- derived safe-intake margin
plot(pout_g, boundary, type = "o", col = PAL$ink, pch = 16, cex = 0.5, lwd = 2,
     ylim = c(0.02, 0.50), xlab = "p_out (attrition)", ylab = "max sustainable p_in",
     main = "FIG 3b — DERIVED SAFE-INTAKE MARGIN")
grid(col = PAL$grid, lty = 1)
polygon(c(pout_g, rev(pout_g)), c(boundary, rev(rep(0.02, length(pout_g)))),
        col = adjustcolor(PAL$A, alpha.f = 0.15), border = NA)
polygon(c(pout_g, rev(pout_g)), c(boundary, rev(rep(0.50, length(pout_g)))),
        col = adjustcolor(PAL$B, alpha.f = 0.15), border = NA)
lines(pout_g, boundary, col = PAL$ink, lwd = 2)
text(0.12, 0.42, "UNSAFE", col = "darkred", font = 2)
text(0.14, 0.10, "SAFE", col = "darkgreen", font = 2)
dev.off()

# ==================== FIG 4 — DYNAMICAL (hysteresis) =======================
n <- PARAMS$n_weeks
act <- rep(PARAMS$p_act, n)
a0 <- SWEEPS$pulse_weeks[1]; a1 <- SWEEPS$pulse_weeks[2]
# Python act[a0:a1] is a 0-indexed half-open slice [a0, a1); the equivalent
# 1-indexed R slice is (a0+1):a1.
act[(a0 + 1):a1] <- PARAMS$p_act * SWEEPS$pulse_factor

Ah <- run("A", act_series = act)
Bh <- run("B", act_series = act)

open_png("figs/regime_fig4_hysteresis.png", w = 1275, h = 675)
ylimH <- range(Ah$backlog, Bh$backlog)
plot(wk, Ah$backlog, type = "n", ylim = ylimH, xlab = "week", ylab = "backlog (hrs)",
     main = "FIG 4 — Hysteresis: recovery after transient demand pulse")
rect(a0 + 1, ylimH[1], a1, ylimH[2], col = adjustcolor(PAL$muted, alpha.f = 0.2), border = NA)
grid(col = PAL$grid, lty = 1)
lines(wk, Ah$backlog, col = PAL$A, lwd = 2)
lines(wk, Bh$backlog, col = PAL$B, lwd = 2)
legend("topleft", bty = "n", lwd = 2, col = c(PAL$A, PAL$B),
       legend = c("A (flexible) — recovers", "B (fixed) — stays elevated"),
       text.col = PAL$ink2, cex = 0.85)
dev.off()

# ==================== ROBUSTNESS (printed, not plotted) ====================
cat(strrep("=", 72), "\n", sep = "")
cat("ROBUSTNESS — p_gen x p_out, Regime B (confirm p_gen=1.0 not a knife-edge)\n")
cat(strrep("=", 72), "\n", sep = "")
pg_list <- c(0.8, 0.9, 1.0, 1.1, 1.2)
po_list <- c(0.02, 0.05, 0.10, 0.20)
cat("p_gen\\p_out", sprintf("%10.2f", po_list), "\n")
for (pg in pg_list) {
  cells <- sapply(po_list, function(po) {
    b <- run("B", p_gen = pg, p_out = po)
    sprintf("%6.0f(%s)", b$terminal_backlog, if (b$diverging) "DIV" else "ok")
  })
  cat(sprintf("%9.1f ", pg), sprintf("%10s", cells), "\n")
}

# ============================ PINNED SUMMARY ===============================
cat("\n", strrep("=", 72), "\n", sep = "")
cat("PINNED RESULTS\n")
cat(strrep("=", 72), "\n", sep = "")
cat(sprintf("Intake crossover week: [%s]\n", paste(head(cross, 3), collapse = " ")))
cat(sprintf("Total care: A=%.0f  B=%.0f  (A advantage %.0f)\n",
            A$total_care, B$total_care, A$total_care - B$total_care))
cat(sprintf("p_out tipping (B): diverges for p_out <= %s; A bounded across all p_out\n",
            if (is.null(B_tip)) "NA" else B_tip))
cat(sprintf("Hysteresis: A settles ~%.1f  |  B settles ~%.1f (permanent elevation)\n",
            mean(tail(Ah$backlog, 50)), mean(tail(Bh$backlog, 50))))
cat("\nSAFE-INTAKE MARGIN (max sustainable p_in vs p_out):\n")
cat(sprintf("%7s %14s\n", "p_out", "max_safe_p_in"))
checkpoints <- c(0.01, 0.02, 0.03, 0.04, 0.05, 0.06, 0.08, 0.10, 0.15, 0.20)
for (i in seq_along(pout_g)) {
  if (round(pout_g[i], 3) %in% checkpoints) {
    cat(sprintf("%7.3f %14.2f\n", pout_g[i], boundary[i]))
  }
}
cat("\nFigures: figs/regime_fig1_mechanism / regime_fig2_structural /",
    "regime_fig3_phase_margin / regime_fig4_hysteresis\n")
