# ============================================================================
# LCPO — Longitudinal Capacity under Partial Observability
# Consolidated reference kernel.
#
# Two intake-governance regimes on identical demand/capacity dynamics:
#   A = committed / residual intake  (obligations served first; intake = residual)
#   B = reactive  / fixed intake     (p_in*C reserved off the top; intake first)
#
# Dormant for MVP (set to identity so accumulation = capacity-overflowing demand,
# NOT hidden demand):  p_surf = 1 (full observability),  p_uti = 1 (no no-shows).
#
# Tune everything in PARAMS / SWEEPS. The kernel below never needs editing.
# ============================================================================

import numpy as np
import matplotlib
matplotlib.use("Agg")              # remove if running interactively
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap
from matplotlib.patches import Rectangle

# ------------------------------- CONFIG -------------------------------------
PARAMS = dict(
    C             = 40.0,   # weekly capacity (hours), single clinician
    n_weeks       = 520,    # horizon (10 yrs): separates divergence from slow transient
    p_in          = 0.20,   # intake reservation fraction (Regime B lever; endogenous in A)
    p_out         = 0.05,   # panel attrition / week. LOWER = more longitudinal. Defines system class.
    p_gen         = 1.00,   # forward obligation generated per served encounter
    p_act         = 0.25,   # activation: fraction of panel obligation coming due per week
    p_out_backlog = 0.00,   # attrition on carried-over backlog (0 = permanent until served)
)

SWEEPS = dict(
    pout_grid     = np.round(np.arange(0.01, 0.201, 0.005), 4),  # FIG 2 & 3
    pin_grid      = np.round(np.arange(0.02, 0.501, 0.01),  3),  # FIG 3 (floor 0.02 completes curve)
    pulse_weeks   = (40, 52),   # FIG 4 transient window [start, end)
    pulse_factor  = 1.8,        # FIG 4 p_act multiplier during pulse
    div_slope_eps = 0.05,       # divergence: last-third backlog slope threshold (hrs/wk)
)

# ------------------------------- KERNEL -------------------------------------
def simulate(regime, C, n_weeks, p_in, p_out, p_gen, p_act, p_out_backlog,
             act_series=None, div_slope_eps=0.05):
    """One run. regime in {'A','B'}. Starts empty (panel=0, backlog=0)."""
    panel   = 0.0   # latent follow-up obligation stock (hours)
    backlog = 0.0   # carried-over unserved demand (hours)
    intake_t, backlog_t, panel_t, served_t = [], [], [], []
    completed_care = 0.0
    overflow_cum   = 0.0

    for w in range(n_weeks):
        pact       = p_act if act_series is None else act_series[w]
        follow_due = panel * pact
        obligation = follow_due + backlog                 # follow-up + carried backlog

        if regime == 'B':                                 # fixed intake off the top
            served_intake = min(p_in * C, C)
            served_oblig  = min(obligation, C - served_intake)
        else:                                             # A: obligations first, intake = residual
            served_oblig  = min(obligation, C)
            served_intake = max(0.0, C - served_oblig)

        unserved      = obligation - served_oblig
        overflow_cum += max(0.0, unserved)
        generated     = (served_oblig + served_intake) * p_gen

        panel   = max(0.0, (panel - follow_due + generated) * (1 - p_out))
        backlog = max(0.0, unserved * (1 - p_out_backlog))
        completed_care += served_oblig + served_intake

        intake_t.append(served_intake)
        backlog_t.append(backlog)
        panel_t.append(panel)
        served_t.append(served_oblig + served_intake)

    backlog_t = np.array(backlog_t)
    last  = backlog_t[int(2 * n_weeks / 3):]              # last-third divergence test
    slope = float(np.polyfit(np.arange(len(last)), last, 1)[0])
    diverging = (slope > div_slope_eps) and (backlog_t[-1] > 1)

    return dict(
        intake=np.array(intake_t), backlog=backlog_t, panel=np.array(panel_t),
        served_total=np.array(served_t), terminal_backlog=float(backlog_t[-1]),
        total_care=completed_care, slope=slope, diverging=diverging,
        overflow_cumulative=overflow_cum,
    )

def run(regime, act_series=None, **overrides):
    """Convenience wrapper: run a regime with inline param overrides."""
    p = {**PARAMS, **overrides}
    return simulate(regime, act_series=act_series,
                    div_slope_eps=SWEEPS['div_slope_eps'], **p)

# =========================== FIG 1 — MECHANISM ==============================
A = run('A'); B = run('B'); wk = np.arange(PARAMS['n_weeks'])
fig, ax = plt.subplots(1, 2, figsize=(13, 4.4))
ax[0].plot(wk, A['intake'], color='green', lw=2, label='A (committed)')
ax[0].plot(wk, B['intake'], color='red',   lw=2, label='B (fixed)')
ax[0].set_xlim(0, 120); ax[0].set_title('FIG 1a — Intake crossover')
ax[0].set_xlabel('week'); ax[0].set_ylabel('intake (hrs/wk)'); ax[0].legend()
ax[1].plot(wk, np.cumsum(A['served_total']), color='green', lw=2, label='A')
ax[1].plot(wk, np.cumsum(B['served_total']), color='red',   lw=2, label='B')
ax[1].set_title('FIG 1b — Cumulative completed care')
ax[1].set_xlabel('week'); ax[1].set_ylabel('cumulative served (hrs)'); ax[1].legend()
plt.tight_layout(); plt.savefig('FIG1_mechanism.png', dpi=120); plt.close()
cross = np.where(np.diff(np.sign(A['intake'] - B['intake'])))[0]

# ==================== FIG 2 — STRUCTURAL (p_out spectrum) ===================
A_term, B_term, B_tip = [], [], None
for po in SWEEPS['pout_grid']:
    a, b = run('A', p_out=po), run('B', p_out=po)
    A_term.append(a['terminal_backlog']); B_term.append(b['terminal_backlog'])
    if b['diverging']:
        B_tip = po
fig, axf = plt.subplots(figsize=(8, 4.6))
axf.plot(SWEEPS['pout_grid'], A_term, 'o-', color='green', ms=3, label='A (committed)')
axf.plot(SWEEPS['pout_grid'], B_term, 's-', color='red',   ms=3, label='B (fixed)')
if B_tip is not None:
    axf.axvline(B_tip + 0.0025, ls=':', color='k', label=f'B tips ~p_out={B_tip}')
axf.set_yscale('symlog')
axf.set_xlabel('p_out (attrition; lower = more longitudinal)')
axf.set_ylabel('terminal backlog (hrs, symlog)')
axf.set_title('FIG 2 — Longitudinal-spectrum tipping'); axf.legend()
plt.tight_layout(); plt.savefig('FIG2_structural.png', dpi=120); plt.close()

# ============= FIG 3 — PHASE DIAGRAM + SAFE-INTAKE MARGIN CURVE =============
pin_g, pout_g = SWEEPS['pin_grid'], SWEEPS['pout_grid']
DIV = np.zeros((len(pout_g), len(pin_g)))
for i, po in enumerate(pout_g):
    for j, pin in enumerate(pin_g):
        DIV[i, j] = 1.0 if run('B', p_in=pin, p_out=po)['diverging'] else 0.0
boundary = np.array([pin_g[DIV[i] == 0].max() if (DIV[i] == 0).any() else np.nan
                     for i in range(len(pout_g))])

fig, ax = plt.subplots(1, 2, figsize=(14, 5.0))
ax[0].pcolormesh(pin_g, pout_g, DIV, cmap=ListedColormap(['#2ca25f', '#de2d26']),
                 shading='auto', vmin=0, vmax=1)
ax[0].plot(boundary, pout_g, 'k-', lw=2.5, label='critical boundary')
ax[0].scatter([PARAMS['p_in']], [PARAMS['p_out']], c='yellow', edgecolor='k',
              s=120, zorder=5, label=f"operating pt ({PARAMS['p_in']},{PARAMS['p_out']})")
ax[0].add_patch(Rectangle((0.20, 0.02), 0.10, 0.03, fill=False,
                          edgecolor='blue', lw=2, ls='--'))
ax[0].text(0.25, 0.035, 'typical\nlongitudinal\npsychiatry', color='blue',
           ha='center', fontsize=8, fontweight='bold')
ax[0].text(0.055, 0.17, 'Regime A:\nSTABLE everywhere', color='darkgreen',
           fontsize=9, fontweight='bold',
           bbox=dict(boxstyle='round', fc='white', ec='green'))
ax[0].set_xlabel('p_in'); ax[0].set_ylabel('p_out')
ax[0].set_title('FIG 3a — Regime B phase map'); ax[0].legend(loc='upper right', fontsize=8)

ax[1].plot(pout_g, boundary, 'b-o', lw=2, ms=3)
ax[1].fill_between(pout_g, boundary, 0.02, alpha=0.15, color='green')
ax[1].fill_between(pout_g, boundary, 0.50, alpha=0.15, color='red')
ax[1].set_xlabel('p_out (attrition)'); ax[1].set_ylabel('max sustainable p_in')
ax[1].set_title('FIG 3b — DERIVED SAFE-INTAKE MARGIN'); ax[1].grid(alpha=0.3)
ax[1].text(0.12, 0.42, 'UNSAFE', color='darkred',  ha='center', fontweight='bold')
ax[1].text(0.14, 0.10, 'SAFE',   color='darkgreen', ha='center', fontweight='bold')
plt.tight_layout(); plt.savefig('FIG3_phase_deliverable.png', dpi=120); plt.close()

# ==================== FIG 4 — DYNAMICAL (hysteresis) =======================
n = PARAMS['n_weeks']; act = np.full(n, PARAMS['p_act'])
a0, a1 = SWEEPS['pulse_weeks']
act[a0:a1] = PARAMS['p_act'] * SWEEPS['pulse_factor']
Ah, Bh = run('A', act_series=act), run('B', act_series=act)
fig, axh = plt.subplots(figsize=(8.5, 4.5))
axh.plot(Ah['backlog'], color='green', lw=2, label='A (committed) — recovers')
axh.plot(Bh['backlog'], color='red',   lw=2, label='B (fixed) — stays elevated')
axh.axvspan(a0, a1, alpha=0.2, color='gray', label='transient pulse')
axh.set_xlabel('week'); axh.set_ylabel('backlog (hrs)')
axh.set_title('FIG 4 — Hysteresis: recovery after transient demand pulse'); axh.legend()
plt.tight_layout(); plt.savefig('FIG4_hysteresis.png', dpi=120); plt.close()

# ==================== ROBUSTNESS (printed, not plotted) ====================
print("=" * 72)
print("ROBUSTNESS — p_gen x p_out, Regime B (confirm p_gen=1.0 not a knife-edge)")
print("=" * 72)
pg_list, po_list = [0.8, 0.9, 1.0, 1.1, 1.2], [0.02, 0.05, 0.10, 0.20]
print("p_gen\\p_out " + " ".join(f"{po:>10.2f}" for po in po_list))
for pg in pg_list:
    cells = []
    for po in po_list:
        b = run('B', p_gen=pg, p_out=po)
        cells.append(f"{b['terminal_backlog']:>6.0f}({'DIV' if b['diverging'] else 'ok'})")
    print(f"{pg:>9.1f}  " + " ".join(f"{c:>10}" for c in cells))

# ============================ PINNED SUMMARY ===============================
print("\n" + "=" * 72); print("PINNED RESULTS"); print("=" * 72)
print(f"Intake crossover week: {cross[:3]}")
print(f"Total care: A={A['total_care']:.0f}  B={B['total_care']:.0f}  "
      f"(A advantage {A['total_care'] - B['total_care']:.0f})")
print(f"p_out tipping (B): diverges for p_out <= {B_tip}; A bounded across all p_out")
print(f"Hysteresis: A settles ~{Ah['backlog'][-50:].mean():.1f}  |  "
      f"B settles ~{Bh['backlog'][-50:].mean():.1f} (permanent elevation)")
print("\nSAFE-INTAKE MARGIN (max sustainable p_in vs p_out):")
print(f"{'p_out':>7} {'max_safe_p_in':>14}")
for po, bd in zip(pout_g, boundary):
    if round(po, 3) in [0.01, 0.02, 0.03, 0.04, 0.05, 0.06, 0.08, 0.10, 0.15, 0.20]:
        print(f"{po:>7.3f} {bd:>14.2f}")
print("\nFigures: FIG1_mechanism / FIG2_structural / FIG3_phase_deliverable / FIG4_hysteresis")