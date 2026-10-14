# M8 uncertainty: does the augmented F-16's in-envelope MIL-F-8785C Level hold?

**The 1-sigma widths are JUDGMENT (engineering judgment, docs/PLAN_M5_M8.md M8), not published values.** Every Level is a REG result of the VITAL chain; only in-envelope points count.

Aircraft: bare NESC F-16 + pitch SAS Kq = 0.02 s, Ka = 0.14 + yaw damper Kr = 0.82 s (reports/ctrl/f16_sas_suggestion.md (vital.ctrl.suggestGains, TARGET_REACHED, confirmed)).
Conditions `F16-NESC-OFE-PROXY-2` grid `user`: h_ft [5000 8000 13000], mach [0.45 0.5 0.55 0.63], cg_pct_mac [20 25 30].
Search budget (stated): centre + 2^d corners + 8 LHS points (seed 2026); method auto per group (grid for <= 2 searched parameters: 11 points per dimension, 3 local refinement levels, at most 8 Lipschitz refinement levels and 2000 lattice points, safety factor 2; hybrid above: differential evolution 8 members x 4 generations, then Nelder-Mead from 1 best points x 120 evaluations, TolX 0.01, TolFun 0.0001; sqp: fmincon from 1 best points x 120 evaluations); 3 candidate conditions; at most 3 moving-limit rounds; Monte Carlo N = 60 (seed 2026); reserve 0; required CP lower bound 0.95. Runtime 6869 s; 9284 single-point assessments, 48 cache hits, 13 full assessments.
CSR (amendment R4-1): AlphaMax 3, resolution 0.01, reference shapes judged (k_g sigma) and equal percentage (10 %), at most 15 box searches per shape; every box search uses the group's method and budget above.

## Uncertain parameters (JUDGMENT; spec `f16_uncertainty_v2`)

| parameter | AeroScale field | NASA term | group | sigma | d | k_g | half-width x1 |
|---|---|---|---|---|---|---|---|
| Cm_q | Cm_q | cmq | pitchDamping | 0.1 | 1 | 2.5758 | 0.2576 |
| Cm_basic | Cm_basic | cmt(el=0) | pitchStatic | 0.05 | 2 | 3.0349 | 0.1517 |
| Cm_de | Cm_de | cmt-cmt(el=0) | pitchStatic | 0.05 | 2 | 3.0349 | 0.1517 |
| Cl_p | Cl_p | clp | latDamping | 0.1 | 2 | 3.0349 | 0.3035 |
| Cn_r | Cn_r | cnr | latDamping | 0.1 | 2 | 3.0349 | 0.3035 |
| Cl_table | Cl_table | clt | latStatic | 0.05 | 2 | 3.0349 | 0.1517 |
| Cnt_table | Cnt_table | cnt | latStatic | 0.05 | 2 | 3.0349 | 0.1517 |

**Joint coverage of the box: 0.9758** under the analysis' own model (independent normal multipliers): the product of the group boxes (pitchDamping 0.9900 (d = 1), pitchStatic 0.9952 (d = 2), latDamping 0.9952 (d = 2), latStatic 0.9952 (d = 2)). It is the same at every width, because the box and the Monte Carlo sigma scale together; per-group 99 % ellipsoids do not make a 99 % joint box.

**What a multiplier means.** Every multiplier scales ONE term of NASA's aerodynamic tables about the moment reference centre, i.e. about the MRC (35 % MAC), not a stability derivative about the CG (ADR R2-5). Cm_table scales the whole pitching-moment table cmt(el, alpha): Cm0, M_alpha (about the MRC) and the elevator power M_de together, so it also moves the trim and scales the authority of the pitch SAS (its Ka and Kq act through M_de). Because the MRC and CG parts of M_alpha can have opposite signs, the effect about the CG is not a plain scaling (effective CG-derivative ratios: tests/M8/tUqR3F16.m#effectiveDerivativeRatios). Amendment R4-5 splits it (aero-database build-up): Cm_basic scales cmt(el = 0, alpha), the static part (Cm0 and the static slope about the MRC), and Cm_de scales cmt(el, alpha) - cmt(el = 0, alpha), the elevator increment (elevator power and the SAS's authority); both are in the R4 specification instead of Cm_table (effective CG-derivative ratios: tests/M8/tUqR4F16.m#effectiveDerivativeRatiosR4). Cn_r (named Cnr_table until R4-6) scales the yaw-damping table cnr(alpha).

**Search.** Longitudinal groups (3.2.x) are searched over the longitudinal parameters only (Cm_q and Cm_table, or Cm_basic and Cm_de in the R4 specification), the lateral multipliers held at 1: at a wings-level, beta = 0 trim they change no longitudinal metric (tests/M8/tUqR3F16.m#lonLatInvariance, 1e-9 relative). Lateral groups use the full box, because Cm_table moves the trim. A group whose nominal margin is +Inf (3.3.1.3 spiral) is searched on the surrogate Re(spiral root), maximized, with its candidate conditions ranked by it; if the largest value found is <= 0 the spiral is stable over the box (bound-worst +Inf). When the confirmation (a fresh in-envelope assessment at the arg-min) finds a smaller margin at a non-candidate condition (a moving limit), that condition is added and the search re-run, at most 3 rounds; the status can be OK only if the final confirmation did not move (otherwise NOT_ASSESSABLE, MOVING_LIMIT). The Mahalanobis distance D of each arg-min is in the x1 (judgment) sigmas, with the chi-square tail for the number of searched parameters. Amendment R4: a box of at most 2 searched parameters is decided on a grid (dense grid, local refinement around the minimum, Lipschitz bound from the measured slopes x 2: "grid-certified (Lipschitz estimate)"); a box of more parameters by a hybrid search (seeded differential evolution, then Nelder-Mead with a bound transform: a "search estimate"), with the convergence of every stage reported.

## Headline

Widths are JUDGMENT multiples of the 1-sigma judgment widths (x1 = the judged box).

| group | nominal Level | nominal margin | CSR alpha* judged (k_g sigma) | parametric safety margin (judged, multiplier) | CPV condition | alpha* x 10 % (equal percentage) | x1 bound-worst (status) | x1 MC (CP lower) | R4 verdict | decided by |
|---|---|---|---|---|---|---|---|---|---|---|
| 3.2.2.1.1-CatA | 1 | 0.05125 | NOT_ASSESSABLE (in [0.22, 0.6]) | - | h_ft=13000 mach=0.45 cg_pct_mac=30 (margin -0.00608, confirmed) | NOT_ASSESSABLE (in [4.6 %, 9.105 %]) | -0.0374 (VIOLATED, grid-certified, shared lattice) | 60/60 (0.9513) | **NOT_ROBUST** | stage 1 (lattice) |
| 3.3.1.1-CatA-other | 1 | 1.218 | 2.75 (OK; CPV at 2.76) | Cm_basic +/-0.417, Cm_de +/-0.417, Cl_p +/-0.835, Cn_r +/-0.835, Cl_table +/-0.417, Cnt_table +/-0.417 | h_ft=13000 mach=0.45 cg_pct_mac=30 (margin -0.00248, confirmed) | >= 30 % (ROBUST_TO_CAP) | 0.9025 (OK) | 60/60 (0.9513) | **ROBUST** | stage 1 |
| 3.3.1.3-CatA | 1 | Inf | 1.80 (OK; CPV at 1.81) | Cm_basic +/-0.273, Cm_de +/-0.273, Cl_p +/-0.546, Cn_r +/-0.546, Cl_table +/-0.273, Cnt_table +/-0.273 | h_ft=5000 mach=0.55 cg_pct_mac=20 (margin -0.00275, confirmed) | >= 30 % (ROBUST_TO_CAP) | Inf (OK, surrogate) | 60/60 (0.9513) | **ROBUST** | stage 1 |

**Critical Similitude Ratio (CSR; Crespo, Kenny and Giesy, NASA LaRC).** alpha* is the largest scaling of the reference box [1 - alpha m, 1 + alpha m] about the nominal, alpha in [0, 3], whose in-envelope margin to the nominal Level stays >= 0; it is bracketed to 0.01 by searched boxes: alpha* is the largest box searched clean, and the CPV (critical parameter value: a failing point, confirmed by a fresh in-envelope assessment) lies at scaled distance at most alpha* + 0.01. The parametric safety margin is alpha* m in multiplier units. Two reference shapes: judged (m = k_g sigma, the x1 half-widths: alpha* >= 1 means the judged box holds) and equal percentage (m = 10 % for every searched multiplier: alpha* x 10 % is the uniform tolerance the Level tolerates, independent of the judged ratios between the parameters). ROBUST_TO_CAP: no failure up to alpha = 3.

R4 verdict: ROBUST = CSR alpha*(judged) >= 1 (status OK) or ROBUST_TO_CAP, AND the Monte Carlo Clopper-Pearson one-sided 95 % lower bound >= 0.95; NOT_ROBUST = a confirmed CPV inside the judged box (alpha*(judged) < 1) OR the lower bound below 0.95; NOT_ASSESSABLE = anything else.

**Shared lattice (amendment R4b, R4-3 corrected).** The longitudinal groups (3.2.2.1.1-CatA) are decided on ONE adaptive lattice over the AlphaMax box of the judged shape, evaluated once per candidate condition (h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.5 cg_pct_mac=30) and reused by every group, both shapes and every alpha: 2993 lattice points, 5985 single-point evaluations, 3 confirmations; refined only near the zero level set (caps: 10 levels per axis, 3000 points per group; capped: 3.2.2.1.1-CatA). A cell is certified when its minimum vertex margin minus sum L_i h_i (L = 2 x the measured local slopes) is >= 0: grid-certified (Lipschitz estimate), not a proof. alpha* is read from the lattice to 0.01 and the CPV confirmed by a fresh in-envelope assessment; an undecided box is NOT_ASSESSABLE (GRID).

**Breakpoint bracketing (R4-7).** A point whose closed-loop linearization is NOT_CONVERGED with its trim alpha or elevator within 0.01 deg of a NESC aero-table breakpoint (read from the generated model) is evaluated at theta x (1 -/+ d), d = 1e-3 up to 1e-2; when the two sides trim on opposite sides of the breakpoint and both are OK, the point is OK with the WORSE of the two margins and is labelled BRACKETED (both values are listed below). Physical failures (trim INFEASIBLE or NOT_CONVERGED, DIVERGENT, non-classical modes) are never bracketed. BRACKETED points in this run: 0.

**Staged run (R4-8).** Stage 1: every group at NumCandidates 2, differential evolution 8 x 4, Monte Carlo N = 60. Stage 2 (the full budget: NumCandidates 3, differential evolution 8 x 4) only for the groups whose judged CSR bracket overlaps [0.8, 1.2] or that are NOT_ASSESSABLE for budget reasons (FC-901); the lattice groups need no stage 2. Re-run in stage 2: none. The column "decided by" gives the stage of each group.

**Lateral groups without Cm_q (R4-9).** Cm_q acts only through the pitch rate, zero at the wings-level trim, so a lateral group (3.3.x) is searched without it; this is gated per group at its critical condition (margin unchanged within 1e-9 relative with Cm_q at the extreme values of every box searched) and falls back to the full set of parameters if the gate fails (tests/M8/tUqR4bF16.m#lateralInvarianceCmq).

| group | nominal Level | nominal margin | x1 bound-worst (status) | x1 MC (CP lower) | x1 box verdict |
|---|---|---|---|---|---|
| 3.2.2.1.1-CatA | 1 | 0.05125 | -0.0374 (VIOLATED, grid-certified, shared lattice) | 60/60 (0.9513) | **NOT_ROBUST** |
| 3.3.1.1-CatA-other | 1 | 1.218 | 0.9025 (OK) | 60/60 (0.9513) | **ROBUST** |
| 3.3.1.3-CatA | 1 | Inf | Inf (OK, surrogate) | 60/60 (0.9513) | **ROBUST** |

**The bound-worst margin is a search estimate (upper bound), not a proof:** it is the smallest margin the search found (centre, 2^d corners, Latin hypercube, then fmincon (sqp), or differential evolution + Nelder-Mead (hybrid), from the best points, re-searched at a moving limit); the true minimum over the box can only be lower. A grid search (at most 2 searched parameters) is grid-certified (Lipschitz estimate): its status OK rests on a lower bound between the grid points from the measured slopes x 2, an estimate, not a proof. "sampled only" marks a binary or flat metric (e.g. 3.3.1.4), where the optimizer's convergence means nothing and the value rests on the sampled points. alpha* inherits the nature of its box searches.

The boxes are nested (x0.5 inside x1 inside x1.5, and R(a) inside R(b) for a < b): robustness of a box implies robustness of every box it contains. NOT_ASSESSABLE means "not established" (the search could not support a verdict), not "fails".

Groups omitted (no finite in-envelope headline Level of the nominal aircraft): none.

Box verdict (per width, the original M8 definition): ROBUST = bound-worst status OK with margin >= reserve AND Clopper-Pearson one-sided 95 % lower bound >= required; NOT_ROBUST = a counterexample in the box OR the lower bound below required; NOT_ASSESSABLE = anything else (e.g. the optimizer did not converge, FC-901, or a point in the box is not OK).

## Details per group

### 3.2.2.1.1-CatA
Nominal Level 1, margin 0.0512487, critical MIL-F-8785C-3.2.2.1.1-CAP-L1-CatA at h_ft=13000 mach=0.45 cg_pct_mac=30.
Candidates: h_ft=13000 mach=0.45 cg_pct_mac=30 (0.05125); h_ft=13000 mach=0.5 cg_pct_mac=30 (0.05524).
Search (longitudinal; margin to the nominal Level (minimized)): longitudinal group: searched over the longitudinal parameters only (Cm_q, Cm_basic, Cm_de), the lateral multipliers held at 1 (they change no longitudinal metric at a wings-level, beta = 0 trim: tests/M8/tUqR3F16.m#lonLatInvariance).
Lon/lat spot check: passed (margin 0.05124870653 with the lateral multipliers at 1 and 0.05124870653 at their most extreme lower values [0.08954 0.08954 0.5448 0.5448] (h_ft=13000 mach=0.45 cg_pct_mac=30): equal within 1e-9 relative).
Search method: lattice.
Shared lattice (R4b): 2993 lattice points and 2155 cells of this group (capped 1), 1 round(s), conditions h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.5 cg_pct_mac=30; certificate over all cells: 1003 of 2155 cells certified.
Decided by stage 1 (R4-8): longitudinal lattice group: decided by the shared lattice in stage 1 (no stage 2).

| width | bound-worst | status | label | arg-min theta | condition | record | confirmation | rounds | Mahalanobis D (tail) | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | box verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x1 | -0.0373981 | VIOLATED | grid-certified (Lipschitz estimate) | [0.8455 1.137 0.8634 1 1 1 1] | h_ft=13000 mach=0.45 cg_pct_mac=30 | MIL-F-8785C-3.2.2.1.1-CAP-L1-CatA | OK -0.0374 | 1 | 4.16 (0.00061, dof 3) |  | 1577 | 60/60 | 0 | 0 | 0.9513 | NOT_ROBUST |

- x1: lattice counterexample: margin -0.0373981 < reserve 0 at h_ft=13000 mach=0.45 cg_pct_mac=30, theta [0.84545 1.13657 0.863432]; 29 of 1577 lattice points inside fail. Verdict reason: bound-worst margin -0.0374 < reserve 0 (VIOLATED): a counterexample inside the box.
  - round 1: 2 candidate condition(s) (h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.5 cg_pct_mac=30); search value -0.0373981 at h_ft=13000 mach=0.45 cg_pct_mac=30, theta [0.8455 1.137 0.8634 1 1 1 1]; confirmation OK -0.0373981 at h_ft=13000 mach=0.45 cg_pct_mac=30 (did not move)
  - stages: lattice 1577 points (converged no)
  - grid certificate (Lipschitz estimate): certified 0, lower bound -0.225437, L [0.3678 0.3741 0.5774] (= 2 x measured slopes [0.1839 0.1871 0.2887]), lattice counterexample: margin -0.0373981 < reserve 0 at h_ft=13000 mach=0.45 cg_pct_mac=30, theta [0.84545 1.13657 0.863432]; 29 of 1577 lattice points inside fail

Critical Similitude Ratio over Cm_q, Cm_basic, Cm_de; R4 verdict **NOT_ROBUST**: alpha*(judged) < 1: a confirmed CPV at scaled norm 0.6 <= 1 lies inside the judged box (CSR NOT_ASSESSABLE, alpha* NaN).
- judged shape (m = [0.2576 0.1517 0.1517]): status NOT_ASSESSABLE, alpha* NaN, bracket [0.225, 0.6]; parametric safety margin [NaN NaN NaN 0 0 0 0]; CPV [0.88409 1.0683 0.90895 1 1 1 1] at h_ft=13000 mach=0.45 cg_pct_mac=30 (margin -0.00608422, MIL-F-8785C-3.2.2.1.1-CAP-L1-CatA), confirmation OK -0.00608422 at h_ft=13000 mach=0.45 cg_pct_mac=30; GRID: the lattice caps are reached (MaxLevel 10, MaxPoints 3000 per group, 2993 points of the group, capped 1) with 1 uncertified cell(s) at entry alpha 0.225 (grid-certified (Lipschitz estimate)); alpha* in [0.225, 0.6] is not resolved to 0.01
- equal shape (m = [0.1 0.1 0.1]): status NOT_ASSESSABLE, alpha* NaN, bracket [0.4552, 0.9105]; parametric safety margin [NaN NaN NaN 0 0 0 0]; CPV [0.92273 1.091 0.90895 1 1 1 1] at h_ft=13000 mach=0.45 cg_pct_mac=30 (margin -0.00333175, MIL-F-8785C-3.2.2.1.1-CAP-L1-CatA), confirmation OK -0.00333175 at h_ft=13000 mach=0.45 cg_pct_mac=30; GRID: the lattice caps are reached (MaxLevel 10, MaxPoints 3000 per group, 2993 points of the group, capped 1) with 2 uncertified cell(s) at entry alpha 0.4552 (grid-certified (Lipschitz estimate)); alpha* in [0.4552, 0.9105] is not resolved to 0.01

### 3.3.1.1-CatA-other
Nominal Level 1, margin 1.21845, critical MIL-F-8785C-3.3.1.1-zeta_d-L1-CatA-other at h_ft=13000 mach=0.45 cg_pct_mac=20.
Candidates: h_ft=13000 mach=0.45 cg_pct_mac=20 (1.218); h_ft=13000 mach=0.45 cg_pct_mac=25 (1.231).
Search (lateral; margin to the nominal Level (minimized)): all parameters (the margin depends on the whole box); R4-9: lateral group, Cm_q is not searched (held at 1): it acts only through the pitch rate, zero at the wings-level trim, so it cannot change a lateral metric (gated); the R4-9 gate passed (value 1.218451435 unchanged at 2 moved point(s) within 1e-09 relative (largest 2.37e-15)).
Search method: hybrid.
R4-9 gate (Cm_q held at 1) at h_ft=13000 mach=0.45 cg_pct_mac=20: passed (value 1.218451435 unchanged at 2 moved point(s) within 1e-09 relative (largest 2.37e-15)).
Decided by stage 1 (R4-8): the judged CSR bracket [2.75, 2.76] (OK) does not overlap [0.8, 1.2] and is not NOT_ASSESSABLE for budget reasons.

| width | bound-worst | status | label | arg-min theta | condition | record | confirmation | rounds | Mahalanobis D (tail) | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | box verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x1 | 0.902542 | OK | search estimate (hybrid: differential evolution + Nelder-Mead) | [1 1.152 0.8483 0.6965 0.6965 1.152 1.152] | h_ft=13000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.3.1.1-zeta_d-L1-CatA-other | OK 0.9025 | 1 | 7.43 (4.1e-10, dof 6) | 1 | 215 | 60/60 | 0 | 0 | 0.9513 | ROBUST |

- x1: every evaluated point OK (215), every Nelder-Mead start of the local stage converged; bound-worst 0.902542 >= reserve 0; 1 round(s), the final confirmation did not move. Verdict reason: bound-worst margin 0.9025 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9513 >= 0.95.
  - round 1: 2 candidate condition(s) (h_ft=13000 mach=0.45 cg_pct_mac=20; h_ft=13000 mach=0.45 cg_pct_mac=25); search value 0.902542 at h_ft=13000 mach=0.45 cg_pct_mac=20, theta [1 1.152 0.8483 0.6965 0.6965 1.152 1.152]; confirmation OK 0.902542 at h_ft=13000 mach=0.45 cg_pct_mac=20 (did not move)
  - stages: centre 1 points (converged -); corner 64 points (converged -); lhs 8 points (converged -); de 32 points (converged no); local 110 points (converged yes)

Critical Similitude Ratio over Cm_basic, Cm_de, Cl_p, Cn_r, Cl_table, Cnt_table; R4 verdict **ROBUST**: CSR alpha*(judged) = 2.75 >= 1 (OK) and Clopper-Pearson lower bound 0.9513 >= 0.95.
- judged shape (m = [0.1517 0.1517 0.3035 0.3035 0.1517 0.1517]): status OK, alpha* 2.75, bracket [2.75, 2.76]; parametric safety margin [0 0.4173 0.4173 0.8345 0.8345 0.4173 0.4173]; CPV [1 1.4188 0.58123 0.16245 0.16245 1.4188 0.58123] at h_ft=13000 mach=0.45 cg_pct_mac=30 (margin -0.00247521, MIL-F-8785C-3.3.1.1-zeta_d_omega_nd_rad_s-L1-CatA-other), confirmation OK -0.00247521 at h_ft=13000 mach=0.45 cg_pct_mac=30; alpha* in [2.75, 2.76] (resolution 0.01): the box R(2.75) was searched clean and the CPV at scaled norm 2.76 fails (margin -0.00247521 at h_ft=13000 mach=0.45 cg_pct_mac=30, MIL-F-8785C-3.3.1.1-zeta_d_omega_nd_rad_s-L1-CatA-other), confirmed by a fresh assessment
  - box search alpha 3 (cap): VIOLATED, value -0.304464 at h_ft=13000 mach=0.45 cg_pct_mac=30, 200 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - box search alpha 2.75 (optimistic): OK, value 0.00959889 at h_ft=13000 mach=0.45 cg_pct_mac=30, 194 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - ray (cap): failing at scaled norm 2.76 (t in [0.9189, 0.9199]), margin -0.00247521 at h_ft=13000 mach=0.45 cg_pct_mac=30
- equal shape (m = [0.1 0.1 0.1 0.1 0.1 0.1]): status ROBUST_TO_CAP, alpha* 3, bracket [3, Inf]; parametric safety margin [0 0.3 0.3 0.3 0.3 0.3 0.3]; CPV [1 NaN NaN NaN NaN NaN NaN] at  (margin NaN, ), confirmation  NaN at ; a box searched clean contains the cap box R(3): no failure up to AlphaMax
  - ray (prior): failing at scaled norm 8.375 (t in [0.0000, 1.0000]), margin -0.00247521 at 

### 3.3.1.3-CatA
Nominal Level 1, margin Inf, critical MIL-F-8785C-3.3.1.3-spiral_T2_s-L1-CatA at h_ft=5000 mach=0.55 cg_pct_mac=20.
Candidates: h_ft=5000 mach=0.55 cg_pct_mac=20 (margin Inf, spiral Re -0.04412 1/s); h_ft=13000 mach=0.63 cg_pct_mac=20 (margin Inf, spiral Re -0.0448 1/s).
Search (surrogate; spiral root real part (1/s), maximized): the nominal margin is +Inf (a stable spiral: T2 infinite), which an optimizer cannot move; the box is searched on the smooth surrogate Re(spiral root) (maximized) over all parameters, and the candidate conditions are ranked by it; R4-9: lateral group, Cm_q is not searched (held at 1): it acts only through the pitch rate, zero at the wings-level trim, so it cannot change a lateral metric (gated); the R4-9 gate passed (value -0.04412243892 unchanged at 2 moved point(s) within 1e-09 relative (largest 8.02e-15)).
Search method: hybrid.
R4-9 gate (Cm_q held at 1) at h_ft=5000 mach=0.55 cg_pct_mac=20: passed (value -0.04412243892 unchanged at 2 moved point(s) within 1e-09 relative (largest 8.02e-15)).
Decided by stage 1 (R4-8): the judged CSR bracket [1.798, 1.808] (OK) does not overlap [0.8, 1.2] and is not NOT_ASSESSABLE for budget reasons.

| width | bound-worst | status | label | arg-min theta | condition | record | confirmation | rounds | Mahalanobis D (tail) | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | box verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x1 | Inf | OK | search estimate (hybrid: differential evolution + Nelder-Mead) | [1 0.8483 1.152 1.303 0.6965 0.8483 1.152] | h_ft=5000 mach=0.55 cg_pct_mac=20 |  | OK 0.0003457 | 1 | 7.43 (4.1e-10, dof 6) | 1 | 196 | 60/60 | 0 | 0 | 0.9513 | ROBUST |

- x1: stable over the box (surrogate search): the largest spiral root real part (1/s) found is -0.000345721 <= 0 at h_ft=5000 mach=0.55 cg_pct_mac=20, theta [0.848257 1.15174 1.30349 0.696515 0.848257 1.15174]; bound-worst +Inf (surrogate search on -spiral root real part (1/s) (its margins and reserve are in those terms): every evaluated point OK (196), every Nelder-Mead start of the local stage converged; bound-worst 0.000345721 >= reserve -Inf; 1 round(s), the final confirmation did not move). Verdict reason: bound-worst margin Inf >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9513 >= 0.95.
  - surrogate: largest spiral root real part (1/s) found -0.000345721 (surrogate search OK).
  - round 1: 2 candidate condition(s) (h_ft=5000 mach=0.55 cg_pct_mac=20; h_ft=13000 mach=0.63 cg_pct_mac=20); surrogate search value (-spiral root real part (1/s)) 0.000345721 at h_ft=5000 mach=0.55 cg_pct_mac=20, theta [1 0.8483 1.152 1.303 0.6965 0.8483 1.152]; confirmation OK 0.000345721 at h_ft=5000 mach=0.55 cg_pct_mac=20 (did not move)
  - stages: centre 1 points (converged -); corner 64 points (converged -); lhs 8 points (converged -); de 32 points (converged no); local 91 points (converged yes)

Critical Similitude Ratio over Cm_basic, Cm_de, Cl_p, Cn_r, Cl_table, Cnt_table; R4 verdict **ROBUST**: CSR alpha*(judged) = 1.798 >= 1 (OK) and Clopper-Pearson lower bound 0.9513 >= 0.95.
- judged shape (m = [0.1517 0.1517 0.3035 0.3035 0.1517 0.1517]): status OK, alpha* 1.798, bracket [1.798, 1.808]; parametric safety margin [0 0.2728 0.2728 0.5456 0.5456 0.2728 0.2728]; CPV [1 0.72571 1.2743 0.45141 0.45141 0.72571 1.2743] at h_ft=5000 mach=0.55 cg_pct_mac=20 (margin -0.00275099, MIL-F-8785C-3.3.1.3-spiral_T2_s-L1-CatA), confirmation OK -0.00275099 at h_ft=5000 mach=0.55 cg_pct_mac=20; alpha* in [1.798, 1.808] (resolution 0.01): the box R(1.798) was searched clean and the CPV at scaled norm 1.808 fails (margin -0.00275099 at h_ft=5000 mach=0.55 cg_pct_mac=20, MIL-F-8785C-3.3.1.3-spiral_T2_s-L1-CatA), confirmed by a fresh assessment
  - box search alpha 3 (cap): VIOLATED, value -0.839306 at h_ft=5000 mach=0.55 cg_pct_mac=20, 211 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - box search alpha 1.798 (optimistic): OK, value 0.0155185 at h_ft=5000 mach=0.55 cg_pct_mac=20, 208 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - ray (cap): failing at scaled norm 1.808 (t in [0.6016, 0.6025]), margin -0.00275099 at h_ft=5000 mach=0.55 cg_pct_mac=20
- equal shape (m = [0.1 0.1 0.1 0.1 0.1 0.1]): status ROBUST_TO_CAP, alpha* 3, bracket [3, Inf]; parametric safety margin [0 0.3 0.3 0.3 0.3 0.3 0.3]; CPV [1 NaN NaN NaN NaN NaN NaN] at  (margin NaN, ), confirmation  NaN at ; no failure up to AlphaMax: the cap box R(3) was searched clean (search estimate (hybrid: differential evolution + Nelder-Mead); the largest spiral root real part (1/s) found is 0.0415687 > 0 at h_ft=5000 mach=0.55 cg_pct_mac=20, theta [0.7 1.3 0.7 0.7 0.7 1.3]: margin there 0.38956 (MIL-F-8785C-3.3.1.3-spiral_T2_s-L1-CatA), the bound-worst (the margin decreases as the surrogate grows); surrogate search on -spiral root real part (1/s) (its margins and reserve are in those terms): every evaluated point OK (212), every Nelder-Mead start of the local stage converged; bound-worst -0.0415687 >= reserve -Inf; 1 round(s), the final confirmation did not move)
  - box search alpha 3 (cap): OK, value 0.38956 at h_ft=5000 mach=0.55 cg_pct_mac=20, 212 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - ray (prior): failing at scaled norm 5.483 (t in [0.9990, 0.9995]), margin -0.00115729 at h_ft=5000 mach=0.55 cg_pct_mac=20

## Nominal augmented aircraft (in-envelope headline, vital.fq.assess at theta = 1)

| group | Level | critical margin | critical condition | status |
|---|---|---|---|---|
| 3.2.1.1-CatA | Level 1 | 0.0111 | h_ft=13000 mach=0.45 cg_pct_mac=30 | ASSESSED |
| 3.2.1.1-CatB | Level 1 | 0.0111 | h_ft=13000 mach=0.45 cg_pct_mac=30 | ASSESSED |
| 3.2.1.1-CatC |  | NaN | (none) | NOT_ASSESSABLE |
| 3.2.1.2-CatA | Level 1 | 0.4906 | h_ft=13000 mach=0.45 cg_pct_mac=30 | ASSESSED |
| 3.2.1.2-CatB | Level 1 | 0.4906 | h_ft=13000 mach=0.45 cg_pct_mac=30 | ASSESSED |
| 3.2.1.2-CatC |  | NaN | (none) | NOT_ASSESSABLE |
| 3.2.2.1.1-CatA | Level 1 | 0.05125 | h_ft=13000 mach=0.45 cg_pct_mac=30 | ASSESSED |
| 3.2.2.1.1-CatB | Level 1 | 2.463 | h_ft=13000 mach=0.45 cg_pct_mac=30 | ASSESSED |
| 3.2.2.1.1-CatC |  | NaN | (none) | NOT_ASSESSABLE |
| 3.2.2.1.2-CatA | Level 1 | 0.1021 | h_ft=13000 mach=0.45 cg_pct_mac=20 | ASSESSED |
| 3.2.2.1.2-CatB | Level 1 | 0.2857 | h_ft=13000 mach=0.45 cg_pct_mac=20 | ASSESSED |
| 3.2.2.1.2-CatC |  | NaN | (none) | NOT_ASSESSABLE |
| 3.2.2.2-CatA | Level 1 | 0.0111 | h_ft=13000 mach=0.45 cg_pct_mac=30 | ASSESSED |
| 3.2.2.2-CatB | Level 1 | 0.0111 | h_ft=13000 mach=0.45 cg_pct_mac=30 | ASSESSED |
| 3.2.2.2-CatC |  | NaN | (none) | NOT_ASSESSABLE |
| 3.3.1.1-CatA-COGA | Level 1 | 0.05376 | h_ft=13000 mach=0.45 cg_pct_mac=20 | ASSESSED |
| 3.3.1.1-CatA-other | Level 1 | 1.218 | h_ft=13000 mach=0.45 cg_pct_mac=20 | ASSESSED |
| 3.3.1.1-CatB | Level 1 | 4.269 | h_ft=13000 mach=0.45 cg_pct_mac=20 | ASSESSED |
| 3.3.1.1-CatC |  | NaN | (none) | NOT_ASSESSABLE |
| 3.3.1.2-CatA | Level 1 | 0.5394 | h_ft=13000 mach=0.45 cg_pct_mac=20 | ASSESSED |
| 3.3.1.2-CatB | Level 1 | 0.671 | h_ft=13000 mach=0.45 cg_pct_mac=20 | ASSESSED |
| 3.3.1.2-CatC |  | NaN | (none) | NOT_ASSESSABLE |
| 3.3.1.3-CatA | Level 1 | Inf | h_ft=5000 mach=0.45 cg_pct_mac=20 | ASSESSED |
| 3.3.1.3-CatB | Level 1 | Inf | h_ft=5000 mach=0.45 cg_pct_mac=20 | ASSESSED |
| 3.3.1.3-CatC |  | NaN | (none) | NOT_ASSESSABLE |
| 3.3.1.4-CatA-COGA | Level 1 | 0 | h_ft=5000 mach=0.45 cg_pct_mac=20 | ASSESSED |
| 3.3.1.4-CatA-other | Level 1 | 0 | h_ft=5000 mach=0.45 cg_pct_mac=20 | ASSESSED |
| 3.3.1.4-CatB |  | NaN | (none) | NOT_APPLICABLE |
| 3.3.1.4-CatC |  | NaN | (none) | NOT_ASSESSABLE |
