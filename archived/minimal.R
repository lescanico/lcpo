# LCPO — minimal.R
# The censored-signal theorem in four objects. Run:  Rscript minimal.R
#
# THEOREM (one line of arithmetic): attended hours <= u*C, so the utilization
# dashboard's "slack" can NEVER read below C*(1-u) — with a 22.5% no-show rate
# on a 40 h template, the dashboard shows >= 9 h of apparent slack even in
# total collapse. The signal is not noisy near the danger zone; it is CENSORED.
#
# COROLLARY: an intake thermostat that expands on visible slack and contracts
# on visible saturation is guaranteed one-directional when it reads that
# signal — its contract condition is arithmetically unreachable. Demand that
# is conserved (re-presents rather than evaporating) then accumulates without
# bound while the dashboard reports "a day of open time, every week, forever".
#
# Objects (everything else in LCPO is refinement):
#   template    C = 40 h/wk (definitional, 1 FTE), show rate u = 0.775
#               (literature-typical outpatient no-show ~22.5%)
#   panel   P   standing weekly follow-up demand (h/wk); admissions add to it,
#               turnover drains it
#   backlog B   demand that presented and was not attended; re-presents next
#               week — the one empirical hinge (conservation)
#   thermostat  intake share p_in, stepped +/-0.01/wk on a governance signal

C_H   <- 40
U     <- 0.775
FLOOR <- C_H * (1 - U)   # = 9 h: the censoring floor

# Magnitude-only constants (they set timing, never the mechanism):
D_TURN <- 0.01   # panel turnover 1%/wk  (~2-year median panel tenure)
G_FU   <- 0.02   # h/wk of standing follow-up created per attended intake hour
                 # (chosen so the p_in = 0.25 baseline is comfortably subcritical)
STEP <- 0.01; P_LO <- 0.15; P_HI <- 0.50   # thermostat step + administrative bounds

step_week <- function(P, B, p_in) {
  intake_bk <- p_in * C_H                    # reserved intake, always filled
  fu_bk     <- min(P + B, C_H - intake_bk)   # follow-up books whatever fits
  attended  <- U * (intake_bk + fu_bk)
  B_new     <- (P + B) - U * fu_bk           # unbooked + no-showed re-present
  stopifnot(abs((P + B) - (U * fu_bk + B_new)) < 1e-9)  # exact conservation
  slack     <- C_H - attended                # the utilization dashboard
  stopifnot(slack >= FLOOR - 1e-9)           # the theorem, asserted live
  P_new     <- P * (1 - D_TURN) + G_FU * U * intake_bk
  list(P = P_new, B = B_new, slack = slack, burden = P + B)
}

# One thermostat, two signals. Dead bands:
#   attended slack: expand > 10 h, contract < 5 h  (a day / half-day of open
#     time — but 5 h is BELOW the 9 h floor, so contraction can never fire;
#     any band inside the floor is equally unreachable)
#   burden: hold P+B near 60% of template (22-26 h) — illustrative target
run <- function(signal, n_weeks = 520) {
  P <- 15.5; B <- 4.5; p_in <- 0.25   # analytic steady state of the baseline
  rows <- vector("list", n_weeks)
  for (w in seq_len(n_weeks)) {
    s <- step_week(P, B, p_in)
    rows[[w]] <- data.frame(week = w, p_in = p_in, slack = s$slack,
                            burden = s$burden, backlog = s$B)
    p_in <- if (signal == "attended_slack") {
      if      (s$slack > 10) min(p_in + STEP, P_HI)
      else if (s$slack <  5) max(p_in - STEP, P_LO)   # unreachable: slack >= 9
      else p_in
    } else {                                          # signal == "burden"
      if      (s$burden < 22) min(p_in + STEP, P_HI)
      else if (s$burden > 26) max(p_in - STEP, P_LO)
      else p_in
    }
    P <- s$P; B <- s$B
  }
  do.call(rbind, rows)
}

## ── Demonstration ────────────────────────────────────────────────────────────

a <- run("attended_slack")
b <- run("burden")

cat("Censoring floor: C*(1-u) =", FLOOR, "h — visible slack can never read lower.\n\n")
show <- c(1, seq(104, 520, 104))
cat("Run A — thermostat on ATTENDED SLACK (the utilization dashboard):\n")
print(a[show, ], row.names = FALSE, digits = 3)
cat("\nRun B — same thermostat on TOTAL BURDEN (P + B):\n")
print(b[show, ], row.names = FALSE, digits = 3)
cat(sprintf(
  "\nAfter %d weeks:  A: p_in %.2f, slack pinned at %.1f h, backlog %.0f h and growing %.1f h/wk\n",
  nrow(a), tail(a$p_in, 1), tail(a$slack, 1), tail(a$backlog, 1),
  mean(diff(tail(a$backlog, 13)))))
cat(sprintf(
  "                 B: p_in %.2f, slack %.1f h, backlog %.1f h (bounded)\n",
  tail(b$p_in, 1), tail(b$slack, 1), tail(b$backlog, 1)))

## ── Figure ───────────────────────────────────────────────────────────────────

dir.create("figs", showWarnings = FALSE)
png("figs/fig0_censoring.png", width = 1700, height = 900, res = 150)
par(mfrow = c(1, 2), family = "sans", bg = "#fcfcfb", col.axis = "#898781",
    col.lab = "#52514e", col.main = "#0b0b0b", las = 1, bty = "n",
    mgp = c(2.4, 0.7, 0), tcl = -0.3, mar = c(4.5, 4, 3.5, 1))
plot(NA, xlim = c(1, nrow(a)), ylim = c(0, max(a$slack, b$slack)),
     xlab = "week", ylab = "visible slack (h)",
     main = "What the dashboard shows")
grid(col = "#e1e0d9", lty = 1)
abline(h = FLOOR, col = "#898781", lty = 2)
text(nrow(a), FLOOR, "censoring floor C(1-u) = 9 h ", adj = c(1, -0.5),
     col = "#898781", cex = 0.8)
lines(a$week, a$slack, col = "#e34948", lwd = 2)
lines(b$week, b$slack, col = "#1baf7a", lwd = 2)
legend("topright", bty = "n", lwd = 2, col = c("#e34948", "#1baf7a"),
       legend = c("governed on attended slack", "governed on total burden"),
       text.col = "#52514e", cex = 0.85)
plot(NA, xlim = c(1, nrow(a)), ylim = range(a$backlog, b$backlog),
     xlab = "week", ylab = "backlog of re-presenting demand (h)",
     main = "What is actually happening")
grid(col = "#e1e0d9", lty = 1)
lines(a$week, a$backlog, col = "#e34948", lwd = 2)
lines(b$week, b$backlog, col = "#1baf7a", lwd = 2)
dev.off()
cat("\nfigure written to figs/fig0_censoring.png\n")
