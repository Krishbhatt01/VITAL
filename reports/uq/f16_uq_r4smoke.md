# M8 uncertainty: does the augmented F-16's in-envelope MIL-F-8785C Level hold?

**The 1-sigma widths are JUDGMENT (engineering judgment, docs/PLAN_M5_M8.md M8), not published values.** Every Level is a REG result of the VITAL chain; only in-envelope points count.

Aircraft: bare NESC F-16 + pitch SAS Kq = 0.02 s, Ka = 0.14 + yaw damper Kr = 0.82 s (reports/ctrl/f16_sas_suggestion.md (vital.ctrl.suggestGains, TARGET_REACHED, confirmed)).
Conditions `F16-NESC-OFE-PROXY-2` grid `user`: h_ft [5000 8000 13000], mach [0.45 0.5 0.55 0.63], cg_pct_mac [20 25 30].
Search budget (stated): centre + 2^d corners + 8 LHS points (seed 2026); method auto per group (grid for <= 2 searched parameters: 11 points per dimension, 3 local refinement levels, at most 8 Lipschitz refinement levels and 2000 lattice points, safety factor 2; hybrid above: differential evolution 8 members x 3 generations, then Nelder-Mead from 1 best points x 120 evaluations, TolX 0.01, TolFun 0.0001; sqp: fmincon from 1 best points x 120 evaluations); 2 candidate conditions; at most 3 moving-limit rounds; Monte Carlo N = 20 (seed 2026); reserve 0; required CP lower bound 0.95. Runtime 5204 s; 5505 single-point assessments, 74 cache hits, 15 full assessments.
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

| group | nominal Level | nominal margin | CSR alpha* judged (k_g sigma) | parametric safety margin (judged, multiplier) | CPV condition | alpha* x 10 % (equal percentage) | x1 bound-worst (status) | x1 MC (CP lower) | R4 verdict |
|---|---|---|---|---|---|---|---|---|---|
| 3.2.2.1.1-CatA | 1 | 0.05125 | 0.44 (OK; CPV at 0.45) | Cm_q +/-0.114, Cm_basic +/-0.067, Cm_de +/-0.067 | h_ft=13000 mach=0.45 cg_pct_mac=30 (margin -0.000289, confirmed) | 8.1 % (alpha* 0.81) | -0.06244 (VIOLATED) | 20/20 (0.8609) | **NOT_ROBUST** |
| 3.3.1.1-CatA-other | 1 | 1.218 | NOT_ASSESSABLE (in [0.00, 2.76]) | - | h_ft=13000 mach=0.45 cg_pct_mac=30 (margin -0.00248, confirmed) | NOT_ASSESSABLE (in [0.0 %, Inf %]) | 0.9025 (NOT_ASSESSABLE) | 20/20 (0.8609) | **NOT_ROBUST** |
| 3.3.1.3-CatA | 1 | Inf | NOT_ASSESSABLE (in [0.00, 1.808]) | - | h_ft=5000 mach=0.55 cg_pct_mac=20 (margin -0.00275, confirmed) | NOT_ASSESSABLE (in [0.0 %, Inf %]) | Inf (NOT_ASSESSABLE, surrogate) | 20/20 (0.8609) | **NOT_ROBUST** |

**Critical Similitude Ratio (CSR; Crespo, Kenny and Giesy, NASA LaRC).** alpha* is the largest scaling of the reference box [1 - alpha m, 1 + alpha m] about the nominal, alpha in [0, 3], whose in-envelope margin to the nominal Level stays >= 0; it is bracketed to 0.01 by searched boxes: alpha* is the largest box searched clean, and the CPV (critical parameter value: a failing point, confirmed by a fresh in-envelope assessment) lies at scaled distance at most alpha* + 0.01. The parametric safety margin is alpha* m in multiplier units. Two reference shapes: judged (m = k_g sigma, the x1 half-widths: alpha* >= 1 means the judged box holds) and equal percentage (m = 10 % for every searched multiplier: alpha* x 10 % is the uniform tolerance the Level tolerates, independent of the judged ratios between the parameters). ROBUST_TO_CAP: no failure up to alpha = 3.

R4 verdict: ROBUST = CSR alpha*(judged) >= 1 (status OK) or ROBUST_TO_CAP, AND the Monte Carlo Clopper-Pearson one-sided 95 % lower bound >= 0.95; NOT_ROBUST = a confirmed CPV inside the judged box (alpha*(judged) < 1) OR the lower bound below 0.95; NOT_ASSESSABLE = anything else.

| group | nominal Level | nominal margin | x1 bound-worst (status) | x1 MC (CP lower) | x1 box verdict |
|---|---|---|---|---|---|
| 3.2.2.1.1-CatA | 1 | 0.05125 | -0.06244 (VIOLATED) | 20/20 (0.8609) | **NOT_ROBUST** |
| 3.3.1.1-CatA-other | 1 | 1.218 | 0.9025 (NOT_ASSESSABLE) | 20/20 (0.8609) | **NOT_ROBUST** |
| 3.3.1.3-CatA | 1 | Inf | Inf (NOT_ASSESSABLE, surrogate) | 20/20 (0.8609) | **NOT_ROBUST** |

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
Search method: hybrid.

| width | bound-worst | status | label | arg-min theta | condition | record | confirmation | rounds | Mahalanobis D (tail) | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | box verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x1 | -0.0624367 | VIOLATED | search estimate (hybrid: differential evolution + Nelder-Mead) | [0.7424 1.152 0.8483 1 1 1 1] | h_ft=13000 mach=0.45 cg_pct_mac=30 | MIL-F-8785C-3.2.2.1.1-CAP-L1-CatA | OK -0.06244 | 1 | 5.01 (1.5e-05, dof 3) | 1 | 70 | 20/20 | 0 | 0 | 0.8609 | NOT_ROBUST |

- x1: counterexample: margin -0.0624367 < reserve 0 at h_ft=13000 mach=0.45 cg_pct_mac=30 (MIL-F-8785C-3.2.2.1.1-CAP-L1-CatA), theta [0.742417 1.15174 0.848257]; 40 of 70 evaluated points violate. Verdict reason: bound-worst margin -0.06244 < reserve 0 (VIOLATED): a counterexample inside the box; Clopper-Pearson lower bound 0.8609 < 0.95.
  - round 1: 2 candidate condition(s) (h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.5 cg_pct_mac=30); search value -0.0624367 at h_ft=13000 mach=0.45 cg_pct_mac=30, theta [0.7424 1.152 0.8483 1 1 1 1]; confirmation OK -0.0624367 at h_ft=13000 mach=0.45 cg_pct_mac=30 (did not move)
  - stages: centre 1 points (converged -); corner 8 points (converged -); lhs 8 points (converged -); de 24 points (converged no); local 29 points (converged yes)

Critical Similitude Ratio over Cm_q, Cm_basic, Cm_de; R4 verdict **NOT_ROBUST**: alpha*(judged) < 1: a confirmed CPV at scaled norm 0.4531 <= 1 lies inside the judged box (CSR OK, alpha* 0.4431); Clopper-Pearson lower bound 0.8609 < 0.95.
- judged shape (m = [0.2576 0.1517 0.1517]): status OK, alpha* 0.4431, bracket [0.4431, 0.4531]; parametric safety margin [0.1141 0.06724 0.06724 0 0 0 0]; CPV [0.88328 1.0688 0.93124 1 1 1 1] at h_ft=13000 mach=0.45 cg_pct_mac=30 (margin -0.000288776, MIL-F-8785C-3.2.2.1.1-CAP-L1-CatA), confirmation OK -0.000288776 at h_ft=13000 mach=0.45 cg_pct_mac=30; alpha* in [0.4431, 0.4531] (resolution 0.01): the box R(0.4431) was searched clean and the CPV at scaled norm 0.4531 fails (margin -0.000288776 at h_ft=13000 mach=0.45 cg_pct_mac=30, MIL-F-8785C-3.2.2.1.1-CAP-L1-CatA), confirmed by a fresh assessment
  - box search alpha 0.4431 (optimistic): OK, value 0.000848216 at h_ft=13000 mach=0.45 cg_pct_mac=30, 74 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - ray (prior): failing at scaled norm 0.4531 (t in [0.4492, 0.4531]), margin -0.000288776 at h_ft=13000 mach=0.45 cg_pct_mac=30
- equal shape (m = [0.1 0.1 0.1]): status OK, alpha* 0.8094, bracket [0.8094, 0.8194]; parametric safety margin [0.08094 0.08094 0.08094 0 0 0 0]; CPV [0.91806 1.0819 0.91806 1 1 1 1] at h_ft=13000 mach=0.45 cg_pct_mac=30 (margin -7.35123e-05, MIL-F-8785C-3.2.2.1.1-CAP-L1-CatA), confirmation OK -7.35123e-05 at h_ft=13000 mach=0.45 cg_pct_mac=30; alpha* in [0.8094, 0.8194] (resolution 0.01): the box R(0.8094) was searched clean and the CPV at scaled norm 0.8194 fails (margin -7.35123e-05 at h_ft=13000 mach=0.45 cg_pct_mac=30, MIL-F-8785C-3.2.2.1.1-CAP-L1-CatA), confirmed by a fresh assessment
  - box search alpha 1.153 (optimistic): VIOLATED, value -0.0209038 at h_ft=13000 mach=0.45 cg_pct_mac=30, 74 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - box search alpha 0.8094 (optimistic): OK, value 0.000552048 at h_ft=13000 mach=0.45 cg_pct_mac=30, 77 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - ray (prior): failing at scaled norm 1.163 (t in [0.9922, 0.9961]), margin -8.75276e-05 at h_ft=13000 mach=0.45 cg_pct_mac=30
  - ray (optimistic): failing at scaled norm 0.8194 (t in [0.7070, 0.7109]), margin -7.35123e-05 at h_ft=13000 mach=0.45 cg_pct_mac=30

### 3.3.1.1-CatA-other
Nominal Level 1, margin 1.21845, critical MIL-F-8785C-3.3.1.1-zeta_d-L1-CatA-other at h_ft=13000 mach=0.45 cg_pct_mac=20.
Candidates: h_ft=13000 mach=0.45 cg_pct_mac=20 (1.218); h_ft=13000 mach=0.45 cg_pct_mac=25 (1.231).
Search (full; margin to the nominal Level (minimized)): all parameters (the margin depends on the whole box).
Search method: hybrid.

| width | bound-worst | status | label | arg-min theta | condition | record | confirmation | rounds | Mahalanobis D (tail) | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | box verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x1 | 0.902542 | NOT_ASSESSABLE | search estimate (hybrid: differential evolution + Nelder-Mead) | [0.7424 1.152 0.8483 0.6965 0.6965 1.152 1.152] | h_ft=13000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.3.1.1-zeta_d-L1-CatA-other | OK 0.9025 | 1 | 7.87 (6.3e-11, dof 7) | 0 | 281 | 20/20 | 0 | 0 | 0.8609 | NOT_ROBUST |

- x1: 1 of 281 evaluated points are not OK inside the box, e.g. EXCLUDED (h_ft=13000 mach=0.45 cg_pct_mac=20: point NOT_CONVERGED at stage linearize: open loop: column 3 (w): no step plateau - successive central-difference estimates never agreed within RelTol 1e-06 over steps 1..1e-06 (noise or non-smooth function) | closed loop: column 3 (w): no step plateau - successive central-difference estimates never agreed within RelTol 1e-06 over steps 1..1e-06 (noise or non-smooth function)) at theta [0.945558 0.863357 1.0591 0.788282 0.793636 1.01873 1.12158]; FC-901: the local stage (Nelder-Mead) did not converge (start 1 exit flag 0 (budget of 120 evaluations exhausted)) and no counterexample was found. Verdict reason: Clopper-Pearson lower bound 0.8609 < 0.95.
  - round 1: 2 candidate condition(s) (h_ft=13000 mach=0.45 cg_pct_mac=20; h_ft=13000 mach=0.45 cg_pct_mac=25); search value 0.902542 at h_ft=13000 mach=0.45 cg_pct_mac=20, theta [0.7424 1.152 0.8483 0.6965 0.6965 1.152 1.152]; confirmation OK 0.902542 at h_ft=13000 mach=0.45 cg_pct_mac=20 (did not move)
  - stages: centre 1 points (converged -); corner 128 points (converged -); lhs 8 points (converged -); de 24 points (converged no); local 120 points (converged no)

Critical Similitude Ratio over Cm_q, Cm_basic, Cm_de, Cl_p, Cn_r, Cl_table, Cnt_table; R4 verdict **NOT_ROBUST**: Clopper-Pearson lower bound 0.8609 < 0.95.
- judged shape (m = [0.2576 0.1517 0.1517 0.3035 0.3035 0.1517 0.1517]): status NOT_ASSESSABLE, alpha* NaN, bracket [0, 2.76]; parametric safety margin [NaN NaN NaN NaN NaN NaN NaN]; CPV [1.7109 1.4188 0.58123 0.16245 0.16245 1.4188 0.58123] at h_ft=13000 mach=0.45 cg_pct_mac=30 (margin -0.00247521, MIL-F-8785C-3.3.1.1-zeta_d_omega_nd_rad_s-L1-CatA-other), confirmation  NaN at ; the box R(2.75) is not decided (alpha* in [0, 2.76]): FC-901: the local stage (Nelder-Mead) did not converge (start 1 exit flag 0 (Exiting: Maximum number of function evaluations has been exceeded - increase MaxFunEvals option. Current function value: 0.009599)) and no counterexample was found
  - box search alpha 3 (cap): VIOLATED, value -0.304464 at h_ft=13000 mach=0.45 cg_pct_mac=30, 281 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - box search alpha 2.75 (optimistic): NOT_ASSESSABLE, value 0.00959889 at h_ft=13000 mach=0.45 cg_pct_mac=30, 281 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - ray (cap): failing at scaled norm 2.76 (t in [0.9189, 0.9199]), margin -0.00247521 at h_ft=13000 mach=0.45 cg_pct_mac=30
- equal shape (m = [0.1 0.1 0.1 0.1 0.1 0.1 0.1]): status NOT_ASSESSABLE, alpha* NaN, bracket [0, Inf]; parametric safety margin [NaN NaN NaN NaN NaN NaN NaN]; CPV [NaN NaN NaN NaN NaN NaN NaN] at  (margin NaN, ), confirmation  NaN at ; the cap box R(3) is not decided: FC-901: the local stage (Nelder-Mead) did not converge (start 1 exit flag 0 (Exiting: Maximum number of function evaluations has been exceeded - increase MaxFunEvals option. Current function value: 0.790695)) and no counterexample was found
  - box search alpha 3 (cap): NOT_ASSESSABLE, value 0.790695 at h_ft=13000 mach=0.45 cg_pct_mac=25, 281 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - ray (prior): failing at scaled norm 8.375 (t in [0.0000, 1.0000]), margin -0.00247521 at 

### 3.3.1.3-CatA
Nominal Level 1, margin Inf, critical MIL-F-8785C-3.3.1.3-spiral_T2_s-L1-CatA at h_ft=5000 mach=0.55 cg_pct_mac=20.
Candidates: h_ft=5000 mach=0.55 cg_pct_mac=20 (margin Inf, spiral Re -0.04412 1/s); h_ft=13000 mach=0.63 cg_pct_mac=20 (margin Inf, spiral Re -0.0448 1/s).
Search (surrogate; spiral root real part (1/s), maximized): the nominal margin is +Inf (a stable spiral: T2 infinite), which an optimizer cannot move; the box is searched on the smooth surrogate Re(spiral root) (maximized) over all parameters, and the candidate conditions are ranked by it.
Search method: hybrid.

| width | bound-worst | status | label | arg-min theta | condition | record | confirmation | rounds | Mahalanobis D (tail) | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | box verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x1 | Inf | NOT_ASSESSABLE | search estimate (hybrid: differential evolution + Nelder-Mead) | [1.258 0.8483 1.152 1.303 0.6965 0.8483 1.152] | h_ft=5000 mach=0.55 cg_pct_mac=20 |  | OK 0.0003457 | 1 | 7.87 (6.3e-11, dof 7) | 0 | 281 | 20/20 | 0 | 0 | 0.8609 | NOT_ROBUST |

- x1: surrogate search on -spiral root real part (1/s) (its margins and reserve are in those terms): FC-901: the local stage (Nelder-Mead) did not converge (start 1 exit flag 0 (Exiting: Maximum number of function evaluations has been exceeded - increase MaxFunEvals option. Current function value: 0.000346)) and no counterexample was found; the largest spiral root real part (1/s) found is -0.000345721 <= 0 at h_ft=5000 mach=0.55 cg_pct_mac=20, theta [1.25758 0.848257 1.15174 1.30349 0.696515 0.848257 1.15174]. Verdict reason: Clopper-Pearson lower bound 0.8609 < 0.95.
  - surrogate: largest spiral root real part (1/s) found -0.000345721 (surrogate search NOT_ASSESSABLE).
  - round 1: 2 candidate condition(s) (h_ft=5000 mach=0.55 cg_pct_mac=20; h_ft=13000 mach=0.63 cg_pct_mac=20); surrogate search value (-spiral root real part (1/s)) 0.000345721 at h_ft=5000 mach=0.55 cg_pct_mac=20, theta [1.258 0.8483 1.152 1.303 0.6965 0.8483 1.152]; confirmation OK 0.000345721 at h_ft=5000 mach=0.55 cg_pct_mac=20 (did not move)
  - stages: centre 1 points (converged -); corner 128 points (converged -); lhs 8 points (converged -); de 24 points (converged no); local 120 points (converged no)

Critical Similitude Ratio over Cm_q, Cm_basic, Cm_de, Cl_p, Cn_r, Cl_table, Cnt_table; R4 verdict **NOT_ROBUST**: Clopper-Pearson lower bound 0.8609 < 0.95.
- judged shape (m = [0.2576 0.1517 0.1517 0.3035 0.3035 0.1517 0.1517]): status NOT_ASSESSABLE, alpha* NaN, bracket [0, 1.808]; parametric safety margin [NaN NaN NaN NaN NaN NaN NaN]; CPV [1.4656 0.72571 1.2743 0.45141 0.45141 0.72571 1.2743] at h_ft=5000 mach=0.55 cg_pct_mac=20 (margin -0.00275099, MIL-F-8785C-3.3.1.3-spiral_T2_s-L1-CatA), confirmation  NaN at ; the box R(1.798) is not decided (alpha* in [0, 1.808]): the largest spiral root real part (1/s) found is 0.0568796 > 0 at h_ft=5000 mach=0.55 cg_pct_mac=20, theta [1.46304 0.727225 1.27278 0.454449 0.454449 0.727225 1.27278]: margin there 0.0155185 (MIL-F-8785C-3.3.1.3-spiral_T2_s-L1-CatA), the bound-worst (the margin decreases as the surrogate grows); surrogate search on -spiral root real part (1/s) (its margins and reserve are in those terms): FC-901: the local stage (Nelder-Mead) did not converge (start 1 exit flag 0 (Exiting: Maximum number of function evaluations has been exceeded - increase MaxFunEvals option. Current function value: -0.056880)) and no counterexample was found
  - box search alpha 3 (cap): VIOLATED, value -0.839306 at h_ft=5000 mach=0.55 cg_pct_mac=20, 281 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - box search alpha 1.798 (optimistic): NOT_ASSESSABLE, value 0.0155185 at h_ft=5000 mach=0.55 cg_pct_mac=20, 281 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - ray (cap): failing at scaled norm 1.808 (t in [0.6016, 0.6025]), margin -0.00275099 at h_ft=5000 mach=0.55 cg_pct_mac=20
- equal shape (m = [0.1 0.1 0.1 0.1 0.1 0.1 0.1]): status NOT_ASSESSABLE, alpha* NaN, bracket [0, Inf]; parametric safety margin [NaN NaN NaN NaN NaN NaN NaN]; CPV [NaN NaN NaN NaN NaN NaN NaN] at  (margin NaN, ), confirmation  NaN at ; the cap box R(3) is not decided: the largest spiral root real part (1/s) found is 0.0415687 > 0 at h_ft=5000 mach=0.55 cg_pct_mac=20, theta [0.7 0.7 1.3 0.7 0.7 0.7 1.3]: margin there 0.38956 (MIL-F-8785C-3.3.1.3-spiral_T2_s-L1-CatA), the bound-worst (the margin decreases as the surrogate grows); surrogate search on -spiral root real part (1/s) (its margins and reserve are in those terms): FC-901: the local stage (Nelder-Mead) did not converge (start 1 exit flag 0 (Exiting: Maximum number of function evaluations has been exceeded - increase MaxFunEvals option. Current function value: -0.041569)) and no counterexample was found
  - box search alpha 3 (cap): NOT_ASSESSABLE, value 0.38956 at h_ft=5000 mach=0.55 cg_pct_mac=20, 281 points (search estimate (hybrid: differential evolution + Nelder-Mead))
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
