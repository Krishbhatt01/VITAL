# ADRs proposed by agent `fq` (M6, MIL-F-8785C Class IV flying qualities)

## ADR-0xx: Rule records encode one Level boundary; the engine reports a Level per paragraph and Category (2026-09-29)
- **Context:** RULE_SCHEMA asks for one record per sub-paragraph, and the extract's 235 candidates are one per (paragraph, metric, Level, Category). MIL-F-8785C 6.7.1 defines the Level as the best Level whose boundary is satisfied, and a Level boundary of one paragraph can involve several metrics (Figures 1-3: CAP, omega_nsp floor, n/alpha edge; Table VI: zeta_d, zeta_d*omega_nd, omega_nd).
- **Decision:**
  - A curated record (`rules/mil_f_8785c/records/*.json`, 95 files) is one (paragraph, metric, Level, Category) boundary `lo <= y <= hi` (strict when the spec says "exceed"/"greater than"), with `source.candidate_id` and a verbatim `source.extract_quote`. "All", "A&C", "B&C" are expanded to one record per Category; Category A of 3.3.1.1 is split into the CO/GA row and the other-phase row (extract 6.2 item 8, the extract's interpretation).
  - Records sharing a `group` (paragraph + Category [+ phase subset]) form the unit whose Level is reported. At a point: Level = the smallest L whose records all pass (not-applicable counts as pass); none -> 4 ("worse than Level 3"). A group whose records define only Level 3 (3.2.1.1: Levels 1-2 are stick-force based) reports "Level 3 boundary met (Levels 1-2 not assessed)".
  - Margin m = min((y - lo)/scale, (hi - y)/scale), finite bounds only; scale = |lower bound|, else |upper bound|, else (bound 0) the next Level's non-zero bound (stated per record in `scale_basis`).
  - Table VI increment: lo_eff = lo + slope*max(0, omega_nd^2|phi/beta|_d - 20) with slope .014 (L1), .009 (L2). Level 3 has no base zeta_d*omega_nd ("-"), so its .005 increment is not encoded (coverage NO-REQUIREMENT; see NOTES).
  - The 3.3.1.4 CO/GA prohibition is a Q-PROXY record `coupled_roll_spiral_present <= 0`.
- **Why:** the record stays traceable 1:1 to a transcribed number, and the Level logic is the spec's own (6.7.1).
- **Evidence:** `tests/M6/tFqRules.m` (traceability to the candidate file and to the extract text, strictness, coverage), `tests/M6/tFqEngine.m`.

## ADR-0xx: Status-aware search; PARTIAL results; NOT_ASSESSABLE (2026-09-29)
- **Decision:** a point is used for a record only if its trim, linearization and point evaluation are OK and the metric status is OK with a non-NaN value. Every other point is EXCLUDED and counted by `<stage>:<status>`; a NOT_APPLICABLE metric (no coupled roll-spiral mode) is counted separately. The critical point is the smallest margin over USED points only (FC-702). Record/group status: ASSESSED, PARTIAL (some points excluded: the Level holds over the used points only and is an optimistic bound for the excluded region), NOT_ASSESSABLE (no used point, FC-701, or a Category the policy does not assess), NOT_APPLICABLE.
- **Consequence:** an excluded point can never improve or worsen a verdict silently; the report always lists how many points were excluded and why.
- **Optional refinement:** one step around every critical grid point, at the midpoints to the neighbouring grid values on every axis (never outside the axis range). A refined point is used only if OK.

## ADR-0xx: Category C is NOT_ASSESSABLE for the NESC F-16 (2026-09-29)
- **Context:** Category C (TO, CT, PA, WO, L) is defined by terminal-phase configurations. The NESC F-16 model (F16_aero.dml) has no gear, flap or speed-brake terms.
- **Decision:** the Category C records are curated (they are part of the spec and traceable) but `conditions_f16.json` sets `category_policy.C.assess = false`; every Category C record and group is NOT_ASSESSABLE with that reason. A clean configuration at approach speed is NOT used as an approach configuration. 3.2.1.3 (PA only) is listed OUT-OF-SIM in the coverage table.
- **Evidence:** `tests/M6/tF16Fq.m#categoryCNotAssessable`, `tests/M6/tFqEngine.m#categoryPolicyNotAssessable`.

## ADR-0xx: Condition space and Operational Flight Envelope proxy for the NESC F-16 (2026-09-29)
- **Context:** 3.1.10.1 requires Level 1 in the Operational Flight Envelope (Table I: e.g. CO from 1.4 V_S to V_MAT, MSL to combat ceiling). The NESC model defines neither V_S (no stall/buffet boundary), nor V_MAT or ceilings, and its aero tables have **no Mach dependence** (low-speed data; only the thrust table depends on Mach 0-1 and altitude 0-50,000 ft).
- **Decision:** `rules/mil_f_8785c/conditions_f16.json` registers an OFE PROXY: altitude 5,000-37,000 ft, Mach 0.30-0.76, CG 20-30 % MAC, level 1-g flight, standard day, flat Earth, zero wind (default grid 5 x 5 x 3 = 75 points). The grid values AND their refinement midpoints avoid the thrust-table breakpoints (every 10,000 ft and every 0.2 Mach): a first default grid on Mach 0.4/0.6/0.8 and 5,000/15,000/... ft lost 76 of 141 points to breakpoint NOT_CONVERGED linearizations (FC-510, by design). Mach 0.30 keeps trim alpha below about 21 deg; the upper limit stays below Mach 0.8 because Mach-independent aero data are not defensible beyond it. Points that do not trim are excluded and counted, never extrapolated. Small registered grids (`test`, `readme`, `mutation`) keep tests fast.
- **Consequence:** the reported Levels are "Levels over the proxy envelope", not a statement about the real F-16's OFE.

## ADR-0xx: Metric definitions for the bare-airframe NESC F-16 (2026-09-29)
- **n/alpha** follows 6.2 (p.77) literally: steady-state normal acceleration per alpha for an incremental pitch-control deflection at constant speed, from the [alpha q] rows of the air-axis model with the elevator column (includes the elevator's own lift). It is (V/g)(1/T_theta2) of the usual handbooks. It differs from the M5-A `lin.n_alpha` (alpha-only lift slope): 14.77 vs 14.90 g/rad at the README trim. Defined for level trims only (NOT_LEVEL otherwise).
- **Equivalent system (3.1.12):** the bare airframe's classical modes are used directly (no low-order fit).
- **Phugoid (3.2.1.2) and speed divergence (3.2.1.1)** use `vital.linear.modes(lin, 'IncludeHeight', true)` (coordinator instruction after M5-X: the nonlinear F-16 follows the 9-state phugoid, zeta 0.077, not the 8-state 0.095). All other metrics use the 8-state modes; `tF16Fq#heightCouplingOnlyMovesPhugoid` shows the 9-state model moves the short period by < 1e-3 relative and the lateral modes by < 1e-9.
- **Times to double** are Inf for modes that do not diverge (6.2.1 defines T2 only for divergence); ln 2 replaces the printed .693. An unstable roll root has tau_R = Inf (no convergence time constant; worse than every Level). The aperiodic speed divergence (3.2.1.1 Level 3) is the largest positive real longitudinal root whose participation is u/theta dominated (p_u + p_theta > p_w + p_q), whatever name the M5-A classifier gives it.
- **Non-OK modes** (NOT_OSCILLATORY, UNCLASSIFIED, missing) give a metric status, never a number (FC-703). An over-damped or split short period is therefore excluded, not rated.

## ADR-0xx: AeroScale mutation multipliers (2026-09-29)
- **Decision:** `vital.aircraft.f16.config('AeroScale', struct(...))` with Cm_q, Cl_p, Cn_beta (default 1; unknown names or values that are not finite reals >= 0 are vital:badInput). `vital.aircraft.f16.loads` applies each multiplier that is not 1 to ONE term of the generated NESC model:
  - Cm_q: `cm = cmt + cq2v*(Cm_q*cmq)` (the czq normal force and its moment arm to the CG are not scaled; at CG 25 % that arm contributes about 0.1*czq ~ -3 of the effective Cm_q,cg ~ -8, so "Cm_q x 0.3" reduces the total pitch damping to about 0.56 of its value)
  - Cl_p: `cl = cl1 + b2v*(Cl_p*clp*p + clr*r)`
  - Cn_beta: `cn = Cn_beta*cnt + dcnda*dail + dcndr*drdr + b2v*(cnp*p + cnr*r)` (cnt is the whole beta dependence of Cn, zero at beta = 0)
- With every multiplier equal to 1 the aero outputs are not touched (bit-identical; `tAeroScale#defaultIsBitIdentical`, and the full M2-M5 gate).

---

# Revisions after review R2 (2026-10-05; coordinator decisions)
The ADRs above are kept as first proposed. Where a revision below differs, the revision supersedes them.

## ADR-0xx (R2-1): A divergent point FAILS; it is never excluded
Supersedes the "split short period is excluded" part of the metric ADR.
- **Context (R2 B1):**
  - At 37,000 ft / Mach 0.5 / CG 30 % the bare F-16 has a real longitudinal root of about +0.2 1/s (T2 = 3.4 s). Its participation is not u/theta dominated.
  - The 3.2.1.1 speed metric ignored it, and the split short period was EXCLUDED as NOT_OSCILLATORY. No longitudinal group failed.
- **Decision:**
  - New metric status **DIVERGENT**: the requirement cannot be met at the point (an unstable real root where an oscillation is required).
    - The engine USES the point with margin -Inf. It fails every Level (Level 4) and is not counted as excluded.
    - A short period split into real roots with an unstable root makes zeta_sp, omega_nsp and CAP DIVERGENT.
    - A split phugoid with an unstable root makes zeta_p DIVERGENT, and T2_phugoid_s = ln2/lambda (6.2.1, first-order divergence).
    - A split with both roots stable stays NOT_OSCILLATORY (excluded and counted).
  - New metrics:
    - `lon_divergence_rate_1_s`: the largest real longitudinal root over the 8-state and 9-state modes, height root included.
    - `T2_aperiodic_divergence_s` = ln2/rate (Inf if the rate is <= 0).
    - `speed_divergence_rate_1_s`: the same over the u/theta-dominated roots, 9-state, height root included (R2 MINOR 10).
  - New records **3.2.2.2** (Q-PROXY; interpretation recorded in `source.interpretation`):
    - Source (p.13): "no tendency for the airplane pitch attitude or angle of attack to diverge aperiodically with controls fixed or with controls free".
    - No Level is named, so the requirement applies at all Levels (3.1.10.3.2).
    - Encoded as `lon_divergence_rate_1_s <= 0` at Levels 1–3, Categories A, B and C.
    - The level 1-g trim is taken as the n = 1 member of the steady pull-ups.
    - Controls free and the force/deflection sense remain OUT-OF-SIM.
  - New records **3.2.1.1 Levels 1–2** (R2 M1):
    - Source (p.11): "no tendency for airspeed to diverge aperiodically", controls fixed.
    - Encoded as `speed_divergence_rate_1_s <= 0`.
    - The force/position gradients (a sufficient demonstration) and the controls-free half stay in coverage.
  - Scale of the rate records: ln2/6 1/s, the rate of a 6-s time to double (the 3.2.1.1 Level 3 floor), stated in `scale_basis`.
  - Note: in the validity envelope the binding root of `lon_divergence_rate_1_s` is the slow, slightly stable height root (about -0.0013 1/s), so the in-envelope 3.2.2.2 margin is small (0.011) but positive.
- **Evidence:**
  - `tests/M6/tFqMetricsR2.m`
  - `tests/M6/tFqEngineR2.m#divergentMetricFailsNotExcluded`
  - `tests/M6/tF16FqR2.m#pitchDivergencePointFails`

## ADR-0xx (R2-2): Excluded points never hide a worse Level
Supersedes the "PARTIAL ... optimistic bound" wording.
- **Decision:**
  - A group with excluded (unrated) points is `complete = false`.
  - Its `levelHeadline` is NaN, unless a rated point is already worse than Level 3; then Level 4 is certain.
  - Its `levelText` reads "Level L or worse (k of n points unrated)" and is printed instead of a plain Level.
  - `worstLevel` keeps its meaning (the worst Level over the rated points).
  - A group whose rated points are all NOT_APPLICABLE but which has unrated points is PARTIAL, and both counts are given (R2 MINOR 2).
- **Roll mode fallback (R2 B2 b):**
  - When the classifier names no OK roll mode, tau_R uses the fastest lateral real root that is not a Dutch-roll root. The spiral is then the slowest.
  - The classifier disagreement is recorded in the metric reason and in the point notes.
  - The classifier's body-axis "p largest" signature is not a MIL definition: at alpha 25 deg the roll subsidence is about the stability axis.
  - With a coupled roll-spiral oscillation, tau_R and spiral_T2 are NOT_APPLICABLE (R2 MINOR 11).
- **Evidence:**
  - `tests/M6/tFqEngineR2.m#excludedPointNeverHidesWorseLevel`, `#missingModeNeverPasses` and `#notApplicableWithExclusionsIsPartial`
  - `tests/M6/tFqMetricsR2.m#rollFallbackFastestLateralRealRoot`
  - `tests/M6/tF16FqR2.m#lowSpeedRollModeRated`: at 29,000 ft / Mach 0.30 / CG 20 %, tau_R = 4.57 s and 3.3.1.2-CatB is Level 3.

## ADR-0xx (R2-3): The NESC model's validity envelope; headline Levels are in-envelope Levels
Supersedes the OFE-proxy ADR's grid and its "alpha below 21 deg".
- **Context (R2 M8):**
  - The NESC F16_package README (Assumptions and Limitations, README.html line 910) says: "Flight envelope is limited to the vicinity of 10,000 ft MSL and 287.8 knots equivalent airspeed".
  - The earlier report gave every Level from points at 25–37 kft and 92–232 KEAS without saying so.
- **Decision:**
  - `conditions_f16.json` registers `validity`:
    - **|h − 10,000 ft| <= 5,000 ft and |KEAS − 287.8| <= 20 % (230.24–345.36 KEAS); CG not restricted.**
    - The radius is a **JUDGMENT** by agent fq (the README gives none). It is labelled as such in the file, the report and the printout.
  - Every point is tagged `envelope: IN | EXTRAPOLATED` (`vital.fq.envelopeTag`; KEAS from `vital.fq.f16Factory`, US 1976).
  - Every record and group carries `.inEnvelope` and `.extrapolated` summaries.
  - The HEADLINE Level per group is the in-envelope Level. The EXTRAPOLATED Level and its critical condition are printed in a separate table, labelled "indicative only".
  - Grids:
    - `default`: h {5,000, 8,000, 13,000, 21,000, 29,000, 37,000} ft × Mach {0.30, 0.37, 0.45, 0.50, 0.55, 0.63, 0.76} × CG {20, 25, 30} %, i.e. 126 grid points; 30 points are IN after refinement.
    - `exploration`: the earlier wide 5 × 5 × 3 grid.
    - Grid values and refinement midpoints avoid the thrust-table breakpoints.
  - At the low-speed, high-altitude corner the trim alpha reaches about 25 deg (R2 MINOR 1: the earlier "below 21 deg" text was wrong).
- **Evidence:**
  - `tests/M6/tFqEngineR2.m#envelopeTagging`
  - `tests/M6/tF16FqR2.m#defaultGridHeadlineAndExtrapolation` and `#readmeRevisedRecords`

## ADR-0xx (R2-4): Report files are named by grid and AeroScale and never silently overwritten (R2 M9)
- **Decision:**
  - `run_f16_fq` writes `<ReportDir>/f16_fq_<grid>_<tag>.json/.md` (`vital.fq.reportName`). The tag is `baseline` or, e.g., `Cm_q0.3`; the grid is `user` for 'Axes'.
  - If such a file exists and 'Overwrite' is false (the default), the run is written under a timestamped name and the printout says the existing file was kept.
  - The delivered reports are `reports/fq/f16_fq_default_baseline.*` and `reports/fq/f16_fq_exploration_baseline.*`, regenerated on 2026-10-05 with 'Overwrite', true.
- **Evidence:** `tests/M6/tF16FqR2.m#reportNamingNeverOverwritesDefault`.

## ADR-0xx (R2-5): AeroScale 'Cn_beta' renamed 'Cnt_table' (R2 M5)
Supersedes the AeroScale ADR's Cn_beta bullet.
- **Decision:**
  - The knob scales the NESC static sideslip yawing-moment TABLE cnt(beta, alpha) about the MRC (35 % MAC).
  - The airplane's N_beta about the CG also contains the side-force transfer (cy0 = −0.02 beta(deg), arm 0.345 m at CG 25 %). So `Cnt_table` × 0.2 gives body N_beta × 0.335 at the README trim, not × 0.2.
  - The old name is vital:badInput.
  - The effective CG-derivative ratios are registered REG checks (`tests/M6/tF16FqR2.m#aeroScaleEffectiveDerivatives`):
    - Cnt_table × 0.2 → body N_beta × 0.335 ± 0.01
    - Cm_q × 0.3 → M_q × 0.556 ± 0.01
    - Cl_p × 0.4 → L_p × 0.400 ± 0.005
  - M8 must treat these multipliers as multipliers of MRC coefficients, not as CG-derivative uncertainties.

## ADR-0xx (R2-6): Table VI increments at every Level (R2 M4, MINOR 3)
- **Decision:**
  - The source (p.22): "the minimum zeta_d omega_nd shall be increased above the zeta_d omega_nd minimums listed above by" .014 / .009 / .005 (omega_nd²|phi/beta|_d − 20).
  - Where the base is printed "–", the increment is applied with base 0:
    - Level 3 (all groups): `zeta_d_omega_nd > 0 + .005 max(0, x − 20)`
    - Level 1 CO/GA: `zeta_d_omega_nd > 0 + .014 max(0, x − 20)`
  - Both are strict ("shall exceed").
  - This is the only reading that gives the printed lines an effect. It is recorded in `source.interpretation`.
- **Not changed (MINOR 3):**
  - CO/GA use the "A (CO and GA)" row only (the extract's interpretation). The "both rows" reading is not encoded, and the report says so.
  - The two readings differ only through the increment, when omega_nd < 1.74 rad/s. On the current grids zeta_d < 0.19 everywhere, so the Level is the same.

## ADR-0xx (R2-7): 3.3.1.4 prohibition for Category A phases other than CO/GA (R2 M2)
- **Decision:** add group `3.3.1.4-CatA-other` with the Q-PROXY prohibition `coupled_roll_spiral_present <= 0`.
- **Why:** this is the conservative reading of "such as CO and GA": the ζω permission is given to Categories B and C only.

## ADR-0xx (R2-8): Linear column status (R2 MINOR 6; linear ADR-028)
- **Decision:**
  - `vital.fq.metrics` accepts a linear model whose status is NOT_CONVERGED when the columns it uses (1–8, 13) are OK.
  - `vital.fq.evaluatePoint` then computes the 8-state metrics. The phugoid and speed metrics need the h column, so they get NOT_CONVERGED when column 12 is not OK.
- **Not implemented:** the second half of MINOR 6, i.e. evaluating zeta_p with both one-sided h columns at an altitude breakpoint and keeping the worse.
  - The registered grids avoid the altitude breakpoints.
  - At a breakpoint the phugoid metrics are reported as unrated, never as a two-sided average.
