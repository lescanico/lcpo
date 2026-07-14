# A Closed-Form Sustainability Boundary for Intake Governance in Longitudinal Continuity-Based Care: A Minimal Dynamical Model and Its Operational Implications

*Nicolas A. Lescano, MD*
Department of Psychiatry, Perelman School of Medicine, University of Pennsylvania; Master of Biomedical Informatics Program

## Abstract

**Objective.** Continuity-based ambulatory services (e.g., outpatient psychiatry, primary care, chronic disease management) recurrently experience access collapse—growing waits for established patients despite apparently adequate scheduling. We ask whether a single structural feature, the rule by which finite clinician capacity is divided between standing follow-up obligations and new-patient intake, is sufficient on its own to separate long-run stability from unbounded backlog accumulation.

**Methods.** We construct a minimal, discrete-time, single-clinician stock-flow model in which each served encounter generates a forward follow-up obligation. We compare two intake-governance regimes on identical demand and capacity dynamics: a fixed regime (new-patient capacity reserved off the top) and a flexible regime (standing obligations served first; intake takes the residual). We derive the steady-state behavior analytically and corroborate it numerically, independently reimplemented in Python and R.

**Results.** The fixed regime exhibits a sharp tipping point: below a critical intake fraction the system is bounded; above it, backlog diverges without limit and does not recover after transient shocks (hysteresis). The flexible regime is unconditionally stable. The stability boundary has an exact closed form, $p_{in}^{\max} = 1/(1+L)$, where $L$ is the total follow-up load one new patient generates over their panel lifetime. Equivalently, defining lifetime cost per patient $W = 1+L$, the sustainability condition reduces to a conservation law, $p_{in}\cdot W \le 1$. The boundary is monotone in system "longitudinality" (patient retention), formally connecting a governance rule to a computable, per-system safe-intake ceiling.

**Conclusion.** Within the model class, chronic access failure in continuity care is a deterministic structural consequence of fixed-intake governance operated past a computable threshold—not primarily a failure of individual effort. The result yields a falsifiable prediction and a candidate operational artifact: a proactively-informed intake-governance policy. Empirical validation against panel data is the necessary next step.

**Keywords:** capacity management, panel size, continuity of care, systems modeling, health operations, access to care.

## 1. Introduction

### 1.1 The problem

Timely access to care is a defining performance metric for ambulatory health systems, and academic medical centers face intensifying pressure to expand new-patient throughput [1,2]. Yet clinicians and operational leaders in continuity-based services repeatedly observe a paradox: schedules appear full but functional on standard dashboards, while established patients wait progressively longer for clinically indicated follow-up [3,4]. When the strain becomes undeniable—manifesting as patient complaints, clinician burnout, or attrition—services often respond by abruptly suspending new-patient intake, typically without a principled account of when the suspension should have begun, how long it should persist, or to what level intake should resume [5,6].

This pattern is usually narrated as a local failure: an inefficient provider, a disorganized team, or bad luck [7]. We argue instead that a substantial component is structural and deterministic, arising from a single feature of how capacity is allocated between existing obligations and new demand.

### 1.2 Why continuity care is special

The distinguishing feature of continuity-based care is memory: a completed encounter is not a terminal event but a commitment to future encounters. A new intake is therefore better understood as a subscription than a purchase. This contrasts sharply with episodic/single-service settings (e.g., emergency care), where demand resolved in one period does not, structurally, oblige service in the next. Standard capacity heuristics—fixed new-patient targets, occupancy thresholds—were largely developed for episodic or bounded-length-of-stay systems [8,9] and may be misapplied when demand is self-generating.

### 1.3 What is known, and the gap

Three literatures bear on this problem but do not, individually, close it:

Queueing theory rigorously establishes that in finite-capacity systems with random arrivals, delay grows nonlinearly as utilization approaches capacity—the basis of the widely cited 85% occupancy guideline [8,10,11]. Recent work shows that even long-run utilization targets can mask periodic overload under time-varying demand [9]. However, classical queueing models treat arrivals as exogenous; they do not natively represent a service process whose own output becomes future arrivals.

Panel-size and access research identifies the review/follow-up burden as a driver of waitlists [3,4] and offers planning calculators (e.g., the NHS England "caseload model") and new-to-follow-up ratio heuristics [12,13,14]. These are largely static or steady-state accounting tools; they do not characterize dynamical stability—whether a given governance rule is self-correcting or divergent—nor do they yield a bifurcation threshold.

System dynamics in health models feedback and accumulation, but predominantly for disease-state prevention at the population level [15], rather than for the intake-governance stability of a single provider's panel.

The gap, then, is a minimal, legible dynamical model of a self-generating longitudinal obligation system that (a) shows the intake-governance rule determines stability class, (b) produces a closed-form, tunable, per-system safe-intake margin, and (c) reframes ubiquitous "anomalous" accumulation as a structural consequence.

### 1.4 Contribution and epistemic scope

We make a deliberately bounded claim. Our contribution is synthesis, application, and a deliverable, not new mathematics (the underlying tools—birth–death processes, fixed-point stability, Little's Law—are classical [16]) and not a newly discovered phenomenon (the follow-up/access tension is widely felt [3,5]). We separate three epistemic layers throughout (Table 1): an analytic result (a theorem about the model), a falsifiable prediction (specified but untested), and empirical correspondence (open). The elegance of the analytic layer is not evidence for empirical correspondence; a well-specified model can be both beautiful and wrong. Its value is that it makes a sharp, refutable prediction where prior framing has been largely unfalsifiable.

**Table 1.** Epistemic status of the claims.

| Layer | Claim | Status |
|---|---|---|
| Analytic | If a system has this structure, the sustainability boundary is $p_{in}\cdot(1+L)\le 1$ | Established; derived and numerically confirmed |
| Falsifiable prediction | Real panels above the boundary accumulate; below, they remain bounded | Specified, sharp, untested |
| Empirical correspondence | Real continuity systems belong to this model class | Open; requires data |

## 2. Methods

### 2.1 Model overview

We model a single clinician over discrete weekly periods $t = 1,\dots,T$, with all quantities expressed in hours of clinical capacity rather than patient counts. This time-quantity abstraction is intentional: the object of interest is the balance between committed obligation and available capacity, which is scale-invariant to individual patient identity, and it avoids agent-level assumptions that would add contestable parameters without changing the aggregate dynamics [15,16].

The system carries two state variables:

- $D_t$ — the panel obligation stock: latent future follow-up demand embodied by the established panel (hours).
- $B_t$ — the backlog: demand that could not be served in prior periods and carries forward (hours).

Both initialize empty ($D_0 = 0$, $B_0 = 0$), so all accumulation is endogenous rather than assumed.

### 2.2 Parameters

**Table 2.** Model parameters.

| Symbol | Meaning | Baseline |
|---|---|---|
| $C$ | Weekly capacity (hours) | 40 |
| $p_{in}$ | Intake reservation fraction (fixed regime lever) | 0.20 |
| $p_{out}$ | Panel attrition per period (lower ⇒ more longitudinal) | 0.05 |
| $p_{act}$ | Activation: fraction of panel obligation coming due per period | 0.25 |
| $p_{gen}$ | Forward obligation generated per served encounter | 1.00 |
| $p_{surf}$ | Surfacing (observability); dormant at 1 in MVP | 1.00 |
| $p_{uti}$ | Utilization (1 − no-show rate); dormant at 1 in MVP | 1.00 |

Two knobs are held at identity for this pillar. With $p_{surf}=1$ (full observability) and $p_{uti}=1$ (no no-shows), the accumulating quantity is capacity-overflowing demand, not hidden demand; this isolates the intake-governance question from the separate observability question (Section 5). Outflow composition (appropriate discharge vs. loss-to-follow-up vs. transfer vs. death) is deliberately collapsed into a single $p_{out}$ and not decomposed here (Section 5.2).

### 2.3 Per-period dynamics

Each period, the activated follow-up demand and total obligation are:

$$\text{follow\_due}_t = p_{act}\,D_t, \qquad \text{obligation}_t = \text{follow\_due}_t + B_t .$$

The two regimes differ only in the capacity-allocation rule:

**Fixed regime (B):** intake is reserved off the top; obligations receive the remainder:

$$s^{in}_t = p_{in}\,C, \qquad s^{ob}_t = \min\!\big(\text{obligation}_t,\; C - s^{in}_t\big).$$

**Flexible regime (A):** obligations are served first; intake takes the residual (intake is endogenous):

$$s^{ob}_t = \min\!\big(\text{obligation}_t,\; C\big), \qquad s^{in}_t = \max\!\big(0,\; C - s^{ob}_t\big).$$

Unserved obligation carries forward; each served encounter generates forward obligation; the panel then attrits:

$$\text{unserved}_t = \text{obligation}_t - s^{ob}_t,$$
$$\text{generated}_t = \big(s^{ob}_t + s^{in}_t\big)\,p_{gen},$$
$$D_{t+1} = \big(D_t - \text{follow\_due}_t + \text{generated}_t\big)\,(1-p_{out}),$$
$$B_{t+1} = \text{unserved}_t\,(1-p_{out}^{B}),$$

with $p_{out}^{B}=0$ in the MVP (backlog persists until served).

### 2.4 Divergence criterion

For each run we fit an ordinary-least-squares slope to $B_t$ over the final third of a $T=520$-week (10-year) horizon; a run is classified diverging if that slope exceeds $0.05$ hr/week and terminal backlog exceeds 1 hr, else bounded. The long horizon distinguishes true divergence from slow transients; the classification was verified stable between 156- and 520-week horizons.

### 2.5 Experiments

We report four analyses: (1) mechanism—intake trajectories and cumulative completed care; (2) structural—terminal backlog across the attrition ($p_{out}$) spectrum; (3) phase diagram and margin—the stability boundary in $(p_{in}, p_{out})$ space and the derived safe-intake curve; (4) dynamical—recovery after a transient demand pulse. A robustness sweep over $p_{gen}$ confirms the central finding is not a knife-edge artifact.

### 2.6 Implementation and reproducibility

The kernel was implemented independently in Python (reference oracle) and R (deliverable), with a shared configuration block. Both implementations reproduce all pinned reference values to the reported precision, providing a cross-language correctness check. Code and figures are in the project repository. (Placeholder: repository URL / DOI.)

## 3. Results

### 3.1 Mechanism: the flexible regime admits more early, then self-throttles

*(Figure 1 — two panels: (a) intake hours/week for A vs. B, showing crossover; (b) cumulative completed care.)*

Starting from an empty panel, the flexible regime (A) initially admits more new patients than the fixed regime, because little follow-up obligation yet competes for capacity. As earlier intakes mature into obligations, A's residual intake declines and crosses below B's fixed level (baseline: week $\approx 10$). Despite lower late-stage intake, A delivers greater cumulative completed care over the horizon (baseline: 20,800 vs. 20,376 capacity-hours), because B's nominal intake increasingly converts to unserved backlog rather than completed encounters. This defeats the intuitive objection that the flexible regime is merely "restrictive."

### 3.2 Structural: a sharp tipping point along the longitudinality spectrum

*(Figure 2 — terminal backlog vs. $p_{out}$ for both regimes, symlog scale, tipping threshold marked.)*

Regime B is bounded for high attrition and diverges below a critical $p_{out}$ (baseline: $p_{out}\le 0.055$), with divergence severity increasing monotonically as the system becomes more longitudinal (lower $p_{out}$). Regime A is bounded across the entire spectrum. Because $p_{out}$ operationally defines how continuity-based a service is—$p_{out}\to 1$ recovers the memoryless, episodic limit (e.g., emergency care), where every period's demand is effectively a fresh intake—this result states precisely that fixed-intake governance fails specifically in the longitudinal regime and is adequate in the episodic one.

### 3.3 Phase diagram and the derived safe-intake margin

*(Figure 3 — (a) stable/diverging phase map of B in $(p_{in}, p_{out})$ with critical boundary; (b) derived safe-intake margin curve, $p_{in}^{\max}$ vs. $p_{out}$.)*

The stability boundary of Regime B in $(p_{in}, p_{out})$ space is monotone: the more longitudinal the system, the lower the sustainable intake fraction (Table 3). The typical operating region for continuity psychiatry (low $p_{out}$, moderate $p_{in}$) falls inside the divergent region. Regime A is stable across the entire plane and, by construction, self-locates on or below this boundary—it cannot over-admit, because intake is only ever the residual after obligations.

**Table 3.** Derived safe-intake ceiling (baseline $p_{act}=0.25$, $p_{gen}=1$).

| $p_{out}$ | $p_{in}^{\max}$ | Regime |
|---|---|---|
| 0.02 | 0.07 | Highly longitudinal |
| 0.03 | 0.11 | Highly longitudinal |
| 0.05 | 0.17 | Longitudinal |
| 0.06 | 0.20 | Longitudinal |
| 0.10 | 0.30 | Near-episodic |
| 0.20 | 0.50 | Near-episodic |

### 3.4 Dynamical: hysteresis and the failure of reactive correction

*(Figure 4 — backlog trajectories for A and B after a transient demand pulse; pulse window shaded.)*

A transient demand pulse (activation ×1.8 for 12 weeks) produces qualitatively different responses. Regime A returns to baseline after the pulse ends. Regime B does not: backlog settles at a permanently elevated level (baseline: $\approx 513$ hr). This hysteresis is the formal signature of irreversibility—once past the boundary, the system cannot be restored by simply removing the perturbation, implying that reactive management (waiting for a strain signal, then correcting) is structurally insufficient.

### 3.5 Robustness

Across $p_{gen}\in[0.8,1.2]$, the accumulation region is broad rather than confined to $p_{gen}=1$, confirming the tipping behavior is not a knife-edge artifact of the unit-generation assumption. Cross-language reimplementation reproduced all pinned values.

## 4. Analytic derivation

We derive the boundary in the bounded regime of B, where a steady state exists and backlog is zero (obligations fully served each period). With $B_t=0$, $\text{obligation}_t = p_{act}D_t$, and $s^{in}=p_{in}C$, $s^{ob}=p_{act}D_t$. Substituting into the panel update yields an affine recursion:

$$D_{t+1} = a\,D_t + b, \qquad a = \big(1 - p_{act}(1-p_{gen})\big)(1-p_{out}), \quad b = p_{in}\,C\,p_{gen}\,(1-p_{out}).$$

A stable fixed point exists iff $a<1$, giving $D^\ast = b/(1-a)$, with

$$1-a = \underbrace{p_{out} + p_{act}(1-p_{gen})(1-p_{out})}_{\displaystyle M}.$$

The bounded regime is self-consistent only if steady-state follow-up demand fits within the capacity left after intake, $D^\ast\,p_{act}\le C(1-p_{in})$. Writing $N = p_{act}\,p_{gen}\,(1-p_{out})$ and simplifying:

$$p_{in}\,\frac{N}{M} \le 1-p_{in} \;\Longrightarrow\; p_{in}\,(M+N)\le M \;\Longrightarrow\; \boxed{\,p_{in}^{\max} = \dfrac{M}{M+N}\,}.$$

**The elegant special case ($p_{gen}=1$).** Then $M=p_{out}$, $N=p_{act}(1-p_{out})$, and

$$p_{in}^{\max} = \frac{p_{out}}{p_{out}+p_{act}(1-p_{out})} = \frac{1}{1+L}, \qquad L = p_{act}\cdot\underbrace{\frac{1-p_{out}}{p_{out}}}_{\text{residence time }T}.$$

Here $T=(1-p_{out})/p_{out}$ is expected panel residence (periods), so $L = p_{act}\,T$ is the total follow-up load one new patient generates over their lifetime. Defining lifetime cost $W = 1 + L$ (the intake encounter plus all downstream follow-ups), the boundary collapses to a conservation law:

$$\boxed{\,p_{in}\cdot W \le 1\,} \quad\Longleftrightarrow\quad (\text{intake rate})\times(\text{lifetime work per intake})\le(\text{capacity}),$$

structurally identical in form to Little's Law [16]. The divergent case $a\ge 1$ corresponds to $W\to\infty$: a self-amplifying follow-up loop that no positive intake can sustain. The numeric simulation reproduces $p_{in}^{\max}$ to grid resolution across all tested parameter combinations.

## 5. Planned extensions (scoped, not yet implemented)

These are named to map the trajectory and are explicitly outside the MVP.

### 5.1 Observability (the censored-signal pillar)

Reactivating $p_{surf}<1$ reintroduces hidden (versus merely overflowing) demand: obligations that neither surface as booked demand nor are cleared. This connects to the identifiability of latent demand under censoring—a system that observes only served demand cannot directly measure the demand its own capacity censored [17,18], with methodological parallels to capture–recapture estimation of unobserved populations [19,20] and partially observable decision processes [21]. The central meta-question—can a partially observing system estimate the degree of its own partiality?—is addressable only through imported structural assumptions, made explicit and falsifiable.

### 5.2 Outflow decomposition and an ethical constraint

The single $p_{out}$ conflates appropriate discharge (a resolved obligation, safe to count as recovered capacity) with attrition-unmet (a patient lost while still in need). These are identical to a demand-only observer but opposite in human terms. A naive calibration that counts abandonment as headroom would reward the failure the model exists to prevent [22]. Future work will split $p_{out}$ and pair any calibrated tool with a composition monitor.

### 5.3 Provider load, quality degradation, and turnover cascade

Real systems likely tip before the idealized boundary due to unmodeled loss terms (after-hours "human buffer" absorption; quality degradation under load) [6,23]. Sustained operation past threshold plausibly drives provider attrition; a departing provider's obligations redistribute onto colleagues, raising their effective load—a contagion propagating instability across a group. We flag this cascade as an inferable consequence and a financially salient extension, but do not model it here.

### 5.4 Stochastic and autocorrelated demand

Deterministic runs isolate the mechanism; stochastic activation would test robustness. Because backlog carryover is asymmetric (slack in a backlog-free period is lost, whereas overflow persists), temporally clustered demand is strictly more destabilizing than independent variability—so an i.i.d. treatment yields a conservative (lower-bound) estimate of instability.

## 6. Discussion

### 6.1 Principal finding

Within a deliberately minimal model, the rule for allocating capacity between standing obligations and new intake is, by itself, sufficient to separate unconditional stability from structural divergence. The failure mode of continuity care under fixed-intake governance is therefore not primarily a matter of individual effort or efficiency but of structural configuration operated past a computable threshold. This reframes a recurrent "people problem" as a tractable "policy problem."

### 6.2 From diagnosis to control policy

Many services already suspend intake reactively, triggered by lagging strain signals, with undefined start, duration, and reopening [5]. Our result supplies the missing setpoints: intake should be governed so that $p_{in}\,W\le 1$; a suspension is warranted once the boundary is crossed; recovery duration follows from the drawdown dynamics; and reopening should target the sustainable ceiling $1/W$ rather than the prior (destabilizing) rate or an over-corrected zero. This converts bang–bang, alarm-driven closures into proactive, variance-reducing governance—an operational framing more legible to administrators than clinician-experience arguments, particularly given the downstream turnover costs (Section 5.3) that fall directly on institutional budgets [1,23].

### 6.3 The operational deliverable

Because the boundary depends on $W$—the average lifetime follow-up load per new patient, a quantity estimable from retrospective cohort data a clinic already holds—the model yields a candidate per-clinician instrument: a positioning/monitoring dashboard indicating where a panel sits relative to its stability boundary, with confidence bounds, rather than an oracle prescribing an exact cap. We emphasize the positioning framing to respect irreducible uncertainty and to keep decision rights with the clinician and manager.

### 6.4 Relationship to prior work

Our boundary specializes the queueing insight that utilization near capacity produces nonlinear delay [8,9,10,11] to the case of self-generating longitudinal demand, and it complements static panel-planning tools [12,13,14] by supplying a dynamical stability criterion and a bifurcation threshold they do not provide. Unlike bounded-length-of-stay bed-capacity models [9], obligation here is unbounded-horizon and self-replenishing.

### 6.5 Limitations

The results are, at present, properties of a model, not of the world (Table 1). Key simplifications—full observability, no no-shows, a single lumped outflow term, deterministic demand, and a single clinician—are provisional and enumerated in Section 5. The recovery-timing and reopening-level guidance carries greater uncertainty than the existence of the boundary itself and depends on parameters ($W$ and its drift) that require empirical estimation. Most importantly, whether real continuity systems belong to the model class—whether demand is genuinely conserved and forward-generating with a stable, estimable $W$—is an open empirical question.

### 6.6 Falsification plan

The prediction is sharp: panels with $p_{in}\,W>1$ should accumulate backlog, and those with $p_{in}\,W\le 1$ should remain bounded. This can be tested against longitudinal panel/EHR data by estimating $W$ from new-patient cohorts and relating it to observed backlog trajectories. Crucially, every outcome is informative: corroboration yields a deployable heuristic; a directionally-correct but miscalibrated boundary localizes the omitted loss terms of Section 5.3; and failure to predict would indicate that continuity systems are not in this model class—itself a substantive finding. Estimation must use recency-weighting or changepoint detection rather than a pooled mean, since $W$ may be non-stationary.

## 7. Conclusion

We present a minimal dynamical model showing that intake-governance rule alone determines whether a longitudinal care panel is dynamically stable, together with an exact closed-form sustainability boundary, $p_{in}\,W\le 1$, interpretable as a conservation law between intake rate and lifetime work per patient. The model reframes chronic access failure as a deterministic structural consequence, supplies setpoints for proactive intake governance, and yields a testable prediction and a candidate operational artifact. Its empirical adequacy is the next, and decisive, question.

## Figures (placeholders)

1. **Figure 1.** Mechanism: intake crossover and cumulative completed care (Regimes A vs. B).
2. **Figure 2.** Structural: terminal backlog across the attrition spectrum, with tipping threshold.
3. **Figure 3.** (a) Stability phase map in $(p_{in}, p_{out})$; (b) derived safe-intake margin curve.
4. **Figure 4.** Dynamical: hysteresis in backlog recovery after a transient demand pulse.

## References

1. McKinsey & Company. Ensuring the financial sustainability of academic medical centers. 2024.
2. Penn Medicine. Serving a Changing World: 2023–2028 Strategic Plan. 2023.
3. [Author(s)]. Timely access to specialist outpatient care: applying systems thinking to review and repeat-review outpatients. BMC Health Serv Res. 2025.
4. Sherlaw-Johnson C, Georghiou T, Reed S, et al. Investigating innovations in outpatient services: a mixed-methods rapid evaluation (Patient-Initiated Follow-Up). NIHR Health Soc Care Deliv Res. 2024;12(38).
5. NHS England. Demand and capacity models (core and caseload models). 2022.
6. [Author(s)]. The Hidden Workload Study protocol: national mixed-methods analysis of general-practice workload. BJGP Open. 2025.
7. [Author(s)]. Patient flow issues in medical practices and their root causes. 2025. *(Placeholder—replace with peer-reviewed source.)*
8. Green LV. Queueing theory and modeling. In: Handbook of Healthcare Delivery Systems. 2011.
9. Akbari-Moghaddam M, Down DG, Li N, et al. Data-driven bed capacity planning using $M_t/G_t/\infty$ queueing models. arXiv:2510.02852. 2025.
10. Bagust A, Place M, Posnett JW. Dynamics of bed use in accommodating emergency admissions: stochastic simulation model. BMJ. 1999;319(7203):155–158.
11. Kuntz L, Mennicken R, Scholtes S. Stress on the ward: evidence of safety tipping points in hospitals. Manage Sci. 2015;61(4):754–771.
12. Green LV, Savin S, Murray M. Providing timely access to care: what is the right patient panel size? Jt Comm J Qual Patient Saf. 2007;33(4):211–218.
13. Shekelle PG, Paige NM, Apaydin EA, et al. What is the optimal panel size in primary care? A systematic review. Dept of Veterans Affairs; 2019.
14. Abu Dabrh AM, Farah WH, McLeod HM, et al. Determining patient panel size in primary care: a meta-narrative review. J Prim Care Community Health. 2025;16.
15. Wang Y, Hu B, Zhao Y, et al. Applications of system dynamics models in chronic disease prevention: a systematic review. Prev Chronic Dis. 2021;18:210175.
16. Little JDC. A proof for the queuing formula: $L=\lambda W$. Oper Res. 1961;9(3):383–387.
17. Rodrigues F. Diffusion-aware censored Gaussian processes for demand modelling. Proc IJCAI. 2025.
18. Ding J, Huh WT, Rong Y. Feature-based inventory control with censored demand. SSRN. 2024.
19. Wesson P, Jewell NP, McFarland W, Glymour MM. Evaluating tools for capture–recapture model selection to estimate hidden population size. Ann Epidemiol. 2023;77:24–30.
20. Zhang Y, Ge L, Waller LA, Shah S, Lyles RH. A capture–recapture modeling framework emphasizing expert opinion in disease surveillance. Stat Methods Med Res. 2024;33(7):1197–1210.
21. Shi M, Liang Y, Shroff NB. Near-optimal partially observable reinforcement learning with partial online state information. arXiv:2306.08762. 2024.
22. Wieringa TH, Sanchez-Herrera MF, Espinoza NR, Tran V-T, Boehmer K. Crafting care that fits: workload and capacity assessments (minimally disruptive medicine; cumulative complexity model). J Particip Med. 2020;12(1):e13763.
23. Kivlahan C, Sinsky C. Panel sizes for primary care physicians. AMA STEPS Forward. 2018 (renewed 2024).