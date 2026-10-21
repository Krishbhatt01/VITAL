# M8 uncertainty: does the augmented F-16's in-envelope MIL-F-8785C Level hold?

**The 1-sigma widths are JUDGMENT (engineering judgment, docs/PLAN_M5_M8.md M8), not published values.** Every Level is a REG result of the VITAL chain; only in-envelope points count.

Aircraft: bare NESC F-16 + pitch SAS Kq = 0.02 s, Ka = 0.14 + yaw damper Kr = 0.82 s (reports/ctrl/f16_sas_suggestion.md (vital.ctrl.suggestGains, TARGET_REACHED, confirmed)).
Conditions `F16-NESC-OFE-PROXY-2` grid `user`: h_ft [5000 8000 13000], mach [0.45 0.5 0.55 0.63], cg_pct_mac [20 25 30].
Search budget (stated): centre + 2^d corners + 32 LHS points (seed 2026); method auto per group (grid for <= 2 searched parameters: 11 points per dimension, 3 local refinement levels, at most 8 Lipschitz refinement levels and 2000 lattice points, safety factor 2; hybrid above: differential evolution 16 members x 8 generations, then Nelder-Mead from 2 best points x 150 evaluations, TolX 0.01, TolFun 0.0001; sqp: fmincon from 2 best points x 150 evaluations); 4 candidate conditions; at most 3 moving-limit rounds; Monte Carlo N = 200 (seed 2026); reserve 0; required CP lower bound 0.95. Runtime 62580 s; 80241 single-point assessments, 345892 cache hits, 102 full assessments.
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

**Search.** Longitudinal groups (3.2.x) are searched over the longitudinal parameters only (Cm_q and Cm_table, or Cm_basic and Cm_de in the R4 specification), the lateral multipliers held at 1: at a wings-level, beta = 0 trim they change no longitudinal metric (tests/M8/tUqR3F16.m#lonLatInvariance, 1e-9 relative). Lateral groups (3.3.x) search every multiplier except Cm_q (R4-9: Cm_q acts only through the pitch rate, zero at the wings-level trim; gated per group), the pitching-moment multipliers included, because they move the trim. A group whose nominal margin is +Inf (3.3.1.3 spiral) is searched on the surrogate Re(spiral root), maximized, with its candidate conditions ranked by it; if the largest value found is <= 0 the spiral is stable over the box (bound-worst +Inf). When the confirmation (a fresh in-envelope assessment at the arg-min) finds a smaller margin at a non-candidate condition (a moving limit), that condition is added and the search re-run, at most 3 rounds; the status can be OK only if the final confirmation did not move (otherwise NOT_ASSESSABLE, MOVING_LIMIT). The Mahalanobis distance D of each arg-min is in the x1 (judgment) sigmas, with the chi-square tail for the number of searched parameters. Amendments R4/R4b/R5: the longitudinal groups (at most 3 searched parameters) are decided on ONE shared adaptive lattice ("grid-certified (Lipschitz estimate)", h/2 certificate, piecewise at the aero-table breakpoints); any other box of at most 2 searched parameters on a grid (dense grid, local refinement, Lipschitz bound from the measured slopes x 2); a box of more parameters by a hybrid search (seeded differential evolution, then Nelder-Mead with a bound transform: a "search estimate"), with the convergence of every stage reported.

**Judgments and preconditions (amendment R5, review R5 m10).**
- JUDGMENT: Cm_basic and Cm_de are treated as independent, although both come from one wind-tunnel table (cmt): the split (amendment R4-5) is an aero-database build-up, and a correlation between the static part and the elevator increment is not modelled.
- PRECONDITION: every assessed condition is a 1-g, wings-level, gamma = 0, beta = 0 trim; the longitudinal-only search (R3-M3(a)) and the lateral groups without Cm_q (R4-9) rely on it, and their runtime gates check one point per group (the critical condition) only. A turning or sideslipping condition would invalidate both.
- JUDGMENT: the multipliers are independent normal N(1, sigma) with the JUDGMENT sigmas; the CSR headline does not depend on this distribution, only the Monte Carlo and the k_g box do.

## Headline

Widths are JUDGMENT multiples of the 1-sigma judgment widths (x1 = the judged box).

| group | nominal Level | nominal margin | CSR alpha* judged (k_g sigma) | parametric safety margin (judged, multiplier) | CPV condition | alpha* x 10 % (equal percentage) | x1 bound-worst (status) | x1 MC (CP lower) | verdict (R5: from R(1)) | decided by |
|---|---|---|---|---|---|---|---|---|---|---|
| 3.2.1.1-CatA | 1 | 0.0111 | >= 3 (ROBUST_TO_CAP); R(1) certified | Cm_q +/-0.773, Cm_basic +/-0.455, Cm_de +/-0.455 | - | >= 30 % (ROBUST_TO_CAP) | 0.01097 (OK, grid-certified, shared lattice) | 200/200 (0.9851) | **ROBUST** | stage 1 (lattice) |
| 3.2.1.1-CatB | 1 | 0.0111 | >= 3 (ROBUST_TO_CAP); R(1) certified | Cm_q +/-0.773, Cm_basic +/-0.455, Cm_de +/-0.455 | - | >= 30 % (ROBUST_TO_CAP) | 0.01097 (OK, grid-certified, shared lattice) | 200/200 (0.9851) | **ROBUST** | stage 1 (lattice) |
| 3.2.1.2-CatA | 1 | 0.4906 | >= 3 (ROBUST_TO_CAP); R(1) certified | Cm_q +/-0.773, Cm_basic +/-0.455, Cm_de +/-0.455 | - | >= 30 % (ROBUST_TO_CAP) | 0.4816 (OK, grid-certified, shared lattice) | 200/200 (0.9851) | **ROBUST** | stage 1 (lattice) |
| 3.2.1.2-CatB | 1 | 0.4906 | >= 3 (ROBUST_TO_CAP); R(1) certified | Cm_q +/-0.773, Cm_basic +/-0.455, Cm_de +/-0.455 | - | >= 30 % (ROBUST_TO_CAP) | 0.4816 (OK, grid-certified, shared lattice) | 200/200 (0.9851) | **ROBUST** | stage 1 (lattice) |
| 3.2.2.1.1-CatA | 1 | 0.05125 | NOT_ASSESSABLE (in [0.45, 0.4594]); R(0.45) certified | - | h_ft=13000 mach=0.45 cg_pct_mac=30 (margin -0.000573, confirmed) | NOT_ASSESSABLE (in [7.4 %, 9.105 %]) | -0.01699 (VIOLATED, grid-certified, shared lattice) | 198/200 (0.9689) | **NOT_ROBUST** | stage 1 (lattice) |
| 3.2.2.1.1-CatB | 1 | 2.463 | >= 3 (ROBUST_TO_CAP); R(1) certified | Cm_q +/-0.773, Cm_basic +/-0.455, Cm_de +/-0.455 | - | >= 30 % (ROBUST_TO_CAP) | 2.238 (OK, grid-certified, shared lattice) | 200/200 (0.9851) | **ROBUST** | stage 1 (lattice) |
| 3.2.2.1.2-CatA | 1 | 0.1021 | NOT_ASSESSABLE (in [1.16, 1.191]); R(1) certified | - | h_ft=13000 mach=0.45 cg_pct_mac=20 (margin -0.000486, confirmed) | NOT_ASSESSABLE (in [18.2 %, Inf %]) | 0.01825 (OK, grid-certified, shared lattice) | 200/200 (0.9851) | **ROBUST** | stage 1 (lattice) |
| 3.2.2.1.2-CatB | 1 | 0.2857 | 2.77 (OK; CPV at 2.77); R(1) certified | Cm_q +/-0.712, Cm_basic +/-0.420, Cm_de +/-0.420 | h_ft=13000 mach=0.45 cg_pct_mac=20 (margin -0.000235, confirmed) | >= 30 % (ROBUST_TO_CAP) | 0.2257 (OK, grid-certified, shared lattice) | 200/200 (0.9851) | **ROBUST** | stage 1 (lattice) |
| 3.2.2.2-CatA | 1 | 0.0111 | >= 3 (ROBUST_TO_CAP); R(1) certified | Cm_q +/-0.773, Cm_basic +/-0.455, Cm_de +/-0.455 | - | >= 30 % (ROBUST_TO_CAP) | 0.01097 (OK, grid-certified, shared lattice) | 200/200 (0.9851) | **ROBUST** | stage 1 (lattice) |
| 3.2.2.2-CatB | 1 | 0.0111 | >= 3 (ROBUST_TO_CAP); R(1) certified | Cm_q +/-0.773, Cm_basic +/-0.455, Cm_de +/-0.455 | - | >= 30 % (ROBUST_TO_CAP) | 0.01097 (OK, grid-certified, shared lattice) | 200/200 (0.9851) | **ROBUST** | stage 1 (lattice) |
| 3.3.1.1-CatA-COGA | 1 | 0.05376 | NOT_ASSESSABLE (in [0.00, 0.3477]); R(0.00) certified | - | h_ft=13000 mach=0.45 cg_pct_mac=20 (margin -0.000165, confirmed) | NOT_ASSESSABLE (in [0.0 %, 7.389 %]) | -0.09629 (VIOLATED) | 197/200 (0.9617) | **NOT_ROBUST** | stage 2 |
| 3.3.1.1-CatA-other | 1 | 1.218 | NOT_ASSESSABLE (in [0.00, 2.76]); R(0.00) certified | - | h_ft=13000 mach=0.45 cg_pct_mac=30 (margin -0.00248, confirmed) | NOT_ASSESSABLE (in [0.0 %, Inf %]) | 0.9025 (NOT_ASSESSABLE) | 200/200 (0.9851) | **NOT_ASSESSABLE** | stage 2 |
| 3.3.1.1-CatB | 1 | 4.269 | NOT_ASSESSABLE (in [0.00, Inf]); R(0.00) certified | - | - | NOT_ASSESSABLE (in [0.0 %, Inf %]) | 3.519 (NOT_ASSESSABLE) | 200/200 (0.9851) | **NOT_ASSESSABLE** | stage 2 |
| 3.3.1.2-CatA | 1 | 0.5394 | NOT_ASSESSABLE (in [0.00, 1.837]); R(0.00) certified | - | h_ft=13000 mach=0.45 cg_pct_mac=20 (margin -0.00203, confirmed) | NOT_ASSESSABLE (in [0.0 %, Inf %]) | 0.3474 (NOT_ASSESSABLE) | 200/200 (0.9851) | **NOT_ASSESSABLE** | stage 2 |
| 3.3.1.2-CatB | 1 | 0.671 | NOT_ASSESSABLE (in [0.00, 2.27]); R(0.00) certified | - | h_ft=13000 mach=0.5 cg_pct_mac=30 (margin -0.0157, confirmed) | NOT_ASSESSABLE (in [0.0 %, Inf %]) | 0.5339 (NOT_ASSESSABLE) | 200/200 (0.9851) | **NOT_ASSESSABLE** | stage 2 |
| 3.3.1.3-CatA | 1 | Inf | NOT_ASSESSABLE (in [0.00, 1.808]); R(0.00) certified | - | h_ft=5000 mach=0.55 cg_pct_mac=20 (margin -0.00275, confirmed) | NOT_ASSESSABLE (in [0.0 %, Inf %]) | Inf (NOT_ASSESSABLE, surrogate) | 200/200 (0.9851) | **NOT_ASSESSABLE** | stage 2 |
| 3.3.1.3-CatB | 1 | Inf | NOT_ASSESSABLE (in [0.00, 1.559]); R(0.00) certified | - | h_ft=5000 mach=0.55 cg_pct_mac=20 (margin -0.00579, confirmed) | NOT_ASSESSABLE (in [0.0 %, 27.92 %]) | Inf (NOT_ASSESSABLE, surrogate) | 200/200 (0.9851) | **NOT_ASSESSABLE** | stage 2 |
| 3.3.1.4-CatA-COGA | 1 | 0 | 2.15 (OK; CPV at 2.16); R(1) certified | Cm_basic +/-0.327, Cm_de +/-0.327, Cl_p +/-0.653, Cn_r +/-0.653, Cl_table +/-0.327, Cnt_table +/-0.327 | h_ft=5000 mach=0.45 cg_pct_mac=20 (margin -1, confirmed) | >= 30 % (ROBUST_TO_CAP) | 0 (OK, sampled only) | 200/200 (0.9851) | **ROBUST** | stage 1 |
| 3.3.1.4-CatA-other | 1 | 0 | 2.15 (OK; CPV at 2.16); R(1) certified | Cm_basic +/-0.327, Cm_de +/-0.327, Cl_p +/-0.653, Cn_r +/-0.653, Cl_table +/-0.327, Cnt_table +/-0.327 | h_ft=5000 mach=0.45 cg_pct_mac=20 (margin -1, confirmed) | >= 30 % (ROBUST_TO_CAP) | 0 (OK, sampled only) | 200/200 (0.9851) | **ROBUST** | stage 1 |

**Critical Similitude Ratio (CSR; Crespo, Kenny and Giesy, NASA LaRC).** alpha* is the largest scaling of the reference box [1 - alpha m, 1 + alpha m] about the nominal, alpha in [0, 3], whose margin to the nominal Level stays >= 0 at the group's candidate conditions; it is reported as a bracket [alphaLo, alphaHi]: R(alphaLo) is certified (lattice groups: every lattice cell meeting it certified; other groups: the box searched clean) and the CPV (critical parameter value: a failing point, confirmed by a fresh in-envelope assessment) lies at scaled distance alphaHi. The judged shape is resolved to 0.01 when the budget allows; the equal shape is reported at the resolution its budget allows. The parametric safety margin is alpha* m in multiplier units. Two reference shapes: judged (m = k_g sigma, the x1 half-widths: alpha* >= 1 means the judged box holds) and equal percentage (m = 10 % for every searched multiplier: alpha* x 10 % is the uniform tolerance the Level tolerates, independent of the judged ratios between the parameters). ROBUST_TO_CAP: no failure up to alpha = 3.

R5 verdict: ROBUST = every lattice cell (longitudinal groups) or the box search (other groups) meeting the judged box R(1) certified >= 0, i.e. alphaLo >= 1 with R(alphaLo) certified, AND the Clopper-Pearson lower bound >= 0.95; alpha* is reported as the bracket [alphaLo, alphaHi] (0.01 is required for the judged shape only); NOT_ROBUST = a confirmed CPV with scaled norm <= 1 OR the lower bound below 0.95; NOT_ASSESSABLE = anything else.

**Shared lattice (amendment R4b, R4-3 corrected).** The longitudinal groups (3.2.1.1-CatA, 3.2.1.1-CatB, 3.2.1.2-CatA, 3.2.1.2-CatB, 3.2.2.1.1-CatA, 3.2.2.1.1-CatB, 3.2.2.1.2-CatA, 3.2.2.1.2-CatB, 3.2.2.2-CatA, 3.2.2.2-CatB) are decided on ONE adaptive lattice over the AlphaMax box of the judged shape, evaluated once per candidate condition (h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.45 cg_pct_mac=25; h_ft=13000 mach=0.5 cg_pct_mac=30; h_ft=13000 mach=0.45 cg_pct_mac=20; h_ft=13000 mach=0.5 cg_pct_mac=20; h_ft=5000 mach=0.45 cg_pct_mac=30) and reused by every group, both shapes and every alpha: 12000 lattice points, 29444 single-point evaluations, 185 confirmations; refined only near the zero level set (caps: 10 levels per axis, 6000 points per group, 12000 points over all groups; capped: 3.2.2.1.1-CatA, 3.2.2.1.2-CatA). A cell is certified when its minimum vertex margin minus sum L_i h_i/2 (L = 2 x the measured local slopes; amendment R5-1) is >= 0: grid-certified (Lipschitz estimate), not a proof. The lattice decides R(1) of the judged shape first, then reads alpha*(judged) to 0.01 and the equal shape at what the budget leaves; the CPV is confirmed by a fresh in-envelope assessment; an undecided box is NOT_ASSESSABLE (GRID).

- 3.2.1.1-CatA: the margin is DISCONTINUOUS at alpha_deg = 5 (jump up to 0.0003478, 440 edges): 110 cell(s) straddle a breakpoint (110 certified piecewise, each side from its own vertices); largest jump over a straddling edge 0.0003478. Scope: certified over the candidate condition(s) h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.45 cg_pct_mac=25 only; the other conditions are checked by fresh assessments (confirmFcn) at the CPV, the cap-box and box arg-mins and the 2^d corners of R(1) and R(alphaLo).
- 3.2.1.1-CatB: the margin is DISCONTINUOUS at alpha_deg = 5 (jump up to 0.0003478, 440 edges): 110 cell(s) straddle a breakpoint (110 certified piecewise, each side from its own vertices); largest jump over a straddling edge 0.0003478. Scope: certified over the candidate condition(s) h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.45 cg_pct_mac=25 only; the other conditions are checked by fresh assessments (confirmFcn) at the CPV, the cap-box and box arg-mins and the 2^d corners of R(1) and R(alphaLo).
- 3.2.1.2-CatA: the margin is continuous over the group's cells as far as the vertices show (no cell straddles a breakpoint). Scope: certified over the candidate condition(s) h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.5 cg_pct_mac=30 only; the other conditions are checked by fresh assessments (confirmFcn) at the CPV, the cap-box and box arg-mins and the 2^d corners of R(1) and R(alphaLo).
- 3.2.1.2-CatB: the margin is continuous over the group's cells as far as the vertices show (no cell straddles a breakpoint). Scope: certified over the candidate condition(s) h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.5 cg_pct_mac=30 only; the other conditions are checked by fresh assessments (confirmFcn) at the CPV, the cap-box and box arg-mins and the 2^d corners of R(1) and R(alphaLo).
- 3.2.2.1.1-CatA: the margin is continuous over the group's cells as far as the vertices show (no cell straddles a breakpoint). Scope: certified over the candidate condition(s) h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.5 cg_pct_mac=30 only; the other conditions are checked by fresh assessments (confirmFcn) at the CPV, the cap-box and box arg-mins and the 2^d corners of R(1) and R(alphaLo).
- 3.2.2.1.1-CatB: the margin is continuous over the group's cells as far as the vertices show (no cell straddles a breakpoint). Scope: certified over the candidate condition(s) h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.5 cg_pct_mac=30; h_ft=5000 mach=0.45 cg_pct_mac=30 only; the other conditions are checked by fresh assessments (confirmFcn) at the CPV, the cap-box and box arg-mins and the 2^d corners of R(1) and R(alphaLo).
- 3.2.2.1.2-CatA: the margin is DISCONTINUOUS at de_deg = -12 (jump up to 0.008015, 40 edges); alpha_deg = 5 (jump up to 0.0626, 2712 edges): 688 cell(s) straddle a breakpoint (523 certified piecewise, each side from its own vertices); largest jump over a straddling edge 0.0626. Scope: certified over the candidate condition(s) h_ft=13000 mach=0.45 cg_pct_mac=20; h_ft=13000 mach=0.5 cg_pct_mac=20 only; the other conditions are checked by fresh assessments (confirmFcn) at the CPV, the cap-box and box arg-mins and the 2^d corners of R(1) and R(alphaLo).
- 3.2.2.1.2-CatB: the margin is DISCONTINUOUS at de_deg = -12 (jump up to 0.009351, 732 edges); alpha_deg = 5 (jump up to 0.07304, 2376 edges): 777 cell(s) straddle a breakpoint (611 certified piecewise, each side from its own vertices); largest jump over a straddling edge 0.07304. Scope: certified over the candidate condition(s) h_ft=13000 mach=0.45 cg_pct_mac=20; h_ft=13000 mach=0.5 cg_pct_mac=20 only; the other conditions are checked by fresh assessments (confirmFcn) at the CPV, the cap-box and box arg-mins and the 2^d corners of R(1) and R(alphaLo).
- 3.2.2.2-CatA: the margin is DISCONTINUOUS at alpha_deg = 5 (jump up to 0.0003478, 440 edges): 110 cell(s) straddle a breakpoint (110 certified piecewise, each side from its own vertices); largest jump over a straddling edge 0.0003478. Scope: certified over the candidate condition(s) h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.45 cg_pct_mac=25 only; the other conditions are checked by fresh assessments (confirmFcn) at the CPV, the cap-box and box arg-mins and the 2^d corners of R(1) and R(alphaLo).
- 3.2.2.2-CatB: the margin is DISCONTINUOUS at alpha_deg = 5 (jump up to 0.0003478, 440 edges): 110 cell(s) straddle a breakpoint (110 certified piecewise, each side from its own vertices); largest jump over a straddling edge 0.0003478. Scope: certified over the candidate condition(s) h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.45 cg_pct_mac=25 only; the other conditions are checked by fresh assessments (confirmFcn) at the CPV, the cap-box and box arg-mins and the 2^d corners of R(1) and R(alphaLo).

**Breakpoint bracketing (R4-7).** A point whose closed-loop linearization is NOT_CONVERGED with its trim alpha or elevator within 0.01 deg of a NESC aero-table breakpoint (read from the generated model) is evaluated at theta x (1 -/+ d), d = 1e-3 up to 1e-2; when the two sides trim on opposite sides of the breakpoint and both are OK, the point is OK with the WORSE of the two margins and is labelled BRACKETED (both values are listed below). Physical failures (trim INFEASIBLE or NOT_CONVERGED, DIVERGENT, non-classical modes) are never bracketed. BRACKETED points in this run: 0.

**Staged run (R4-8).** Stage 1: every group at NumCandidates 2, differential evolution 8 x 4, Monte Carlo N = 200. Stage 2 (the full budget: NumCandidates 4, differential evolution 16 x 8) only for the groups whose judged CSR bracket overlaps [0.8, 1.2] or that are NOT_ASSESSABLE for budget reasons (FC-901); the lattice groups need no stage 2. Re-run in stage 2: 3.3.1.1-CatA-COGA, 3.3.1.1-CatA-other, 3.3.1.1-CatB, 3.3.1.2-CatA, 3.3.1.2-CatB, 3.3.1.3-CatA, 3.3.1.3-CatB. The column "decided by" gives the stage of each group.

**Lateral groups without Cm_q (R4-9).** Cm_q acts only through the pitch rate, zero at the wings-level trim, so a lateral group (3.3.x) is searched without it; this is gated per group at its critical condition (margin unchanged within 1e-9 relative with Cm_q at the extreme values of every box searched) and falls back to the full set of parameters if the gate fails (tests/M8/tUqR4bF16.m#lateralInvarianceCmq).

| group | nominal Level | nominal margin | x1 bound-worst (status) | x1 MC (CP lower) | x1 box verdict |
|---|---|---|---|---|---|
| 3.2.1.1-CatA | 1 | 0.0111 | 0.01097 (OK, grid-certified, shared lattice) | 200/200 (0.9851) | **ROBUST** |
| 3.2.1.1-CatB | 1 | 0.0111 | 0.01097 (OK, grid-certified, shared lattice) | 200/200 (0.9851) | **ROBUST** |
| 3.2.1.2-CatA | 1 | 0.4906 | 0.4816 (OK, grid-certified, shared lattice) | 200/200 (0.9851) | **ROBUST** |
| 3.2.1.2-CatB | 1 | 0.4906 | 0.4816 (OK, grid-certified, shared lattice) | 200/200 (0.9851) | **ROBUST** |
| 3.2.2.1.1-CatA | 1 | 0.05125 | -0.01699 (VIOLATED, grid-certified, shared lattice) | 198/200 (0.9689) | **NOT_ROBUST** |
| 3.2.2.1.1-CatB | 1 | 2.463 | 2.238 (OK, grid-certified, shared lattice) | 200/200 (0.9851) | **ROBUST** |
| 3.2.2.1.2-CatA | 1 | 0.1021 | 0.01825 (OK, grid-certified, shared lattice) | 200/200 (0.9851) | **ROBUST** |
| 3.2.2.1.2-CatB | 1 | 0.2857 | 0.2257 (OK, grid-certified, shared lattice) | 200/200 (0.9851) | **ROBUST** |
| 3.2.2.2-CatA | 1 | 0.0111 | 0.01097 (OK, grid-certified, shared lattice) | 200/200 (0.9851) | **ROBUST** |
| 3.2.2.2-CatB | 1 | 0.0111 | 0.01097 (OK, grid-certified, shared lattice) | 200/200 (0.9851) | **ROBUST** |
| 3.3.1.1-CatA-COGA | 1 | 0.05376 | -0.09629 (VIOLATED) | 197/200 (0.9617) | **NOT_ROBUST** |
| 3.3.1.1-CatA-other | 1 | 1.218 | 0.9025 (NOT_ASSESSABLE) | 200/200 (0.9851) | **NOT_ASSESSABLE** |
| 3.3.1.1-CatB | 1 | 4.269 | 3.519 (NOT_ASSESSABLE) | 200/200 (0.9851) | **NOT_ASSESSABLE** |
| 3.3.1.2-CatA | 1 | 0.5394 | 0.3474 (NOT_ASSESSABLE) | 200/200 (0.9851) | **NOT_ASSESSABLE** |
| 3.3.1.2-CatB | 1 | 0.671 | 0.5339 (NOT_ASSESSABLE) | 200/200 (0.9851) | **NOT_ASSESSABLE** |
| 3.3.1.3-CatA | 1 | Inf | Inf (NOT_ASSESSABLE, surrogate) | 200/200 (0.9851) | **NOT_ASSESSABLE** |
| 3.3.1.3-CatB | 1 | Inf | Inf (NOT_ASSESSABLE, surrogate) | 200/200 (0.9851) | **NOT_ASSESSABLE** |
| 3.3.1.4-CatA-COGA | 1 | 0 | 0 (OK, sampled only) | 200/200 (0.9851) | **ROBUST** |
| 3.3.1.4-CatA-other | 1 | 0 | 0 (OK, sampled only) | 200/200 (0.9851) | **ROBUST** |

**The bound-worst margin is a search estimate (upper bound), not a proof:** it is the smallest margin the search found (centre, 2^d corners, Latin hypercube, then fmincon (sqp), or differential evolution + Nelder-Mead (hybrid), from the best points, re-searched at a moving limit); the true minimum over the box can only be lower. A grid search (at most 2 searched parameters) is grid-certified (Lipschitz estimate): its status OK rests on a lower bound between the grid points from the measured slopes x 2, an estimate, not a proof. "sampled only" marks a binary or flat metric (e.g. 3.3.1.4), where the optimizer's convergence means nothing and the value rests on the sampled points. alpha* inherits the nature of its box searches.

The boxes are nested (x0.5 inside x1 inside x1.5, and R(a) inside R(b) for a < b): robustness of a box implies robustness of every box it contains. NOT_ASSESSABLE means "not established" (the search could not support a verdict), not "fails".

**Judgments, preconditions and limits (amendment R5).**
- JUDGMENT: Cm_basic and Cm_de are treated as independent, although both come from one wind-tunnel table (cmt): the split (amendment R4-5) is an aero-database build-up, and a correlation between the static part and the elevator increment is not modelled.
- PRECONDITION: every assessed condition is a 1-g, wings-level, gamma = 0, beta = 0 trim; the longitudinal-only search (R3-M3(a)) and the lateral groups without Cm_q (R4-9) rely on it, and their runtime gates check one point per group (the critical condition) only. A turning or sideslipping condition would invalidate both.
- JUDGMENT: the multipliers are independent normal N(1, sigma) with the JUDGMENT sigmas; the CSR headline does not depend on this distribution, only the Monte Carlo and the k_g box do.
- LIMIT: the lattice certificate is a Lipschitz ESTIMATE from measured secants (grid-certified (Lipschitz estimate)), not a proof: a feature narrower than a lattice cell (a notch or a band between the vertices, which no vertex and no neighbouring edge sees) is invisible to it.
- The certified bound of a cell is its minimum vertex margin minus sum_i L_i h_i/2 (h/2: every point of a cell lies within half an edge of a vertex along each axis), L = 2 x the measured local slopes (own edges and the 3^d base neighbourhood; amendment R5-1).
- The margins are discontinuous where a trim alpha or elevator crosses a NESC aero-table breakpoint (e.g. alpha = 5 deg): a cell whose vertices trim on both sides is certified piecewise, each side from its own vertices with the full edge h and slopes measured away from the jump (amendment R5-3); R4-7 bracketing only treats a linearization AT a breakpoint.
- The worse of the two one-sided linearizations of a BRACKETED point is an engineering rule, not a bound for the switched system; the sides theta x (1 -/+ d) scale every parameter, so a side may lie up to 1 % outside the box. The fresh confirmations are not bracketed: one at a breakpoint is NOT_OK, never a pass.
- The Monte Carlo runs at the group's nominal critical condition only: its Clopper-Pearson bound is a per-condition success probability, not an in-envelope one.
- SCOPE: the lattice certificate and the CSR cover the group's candidate conditions only; the other in-envelope conditions are checked by fresh full assessments at the CPV, at the box arg-mins and at the 2^d corners of R(1) and of R(alphaLo), where a smaller margin overrides the lattice as a moving limit (amendment R5-5, M2).
- R5 verdict: ROBUST = every lattice cell (longitudinal groups) or the box search (other groups) meeting the judged box R(1) certified >= 0, i.e. alphaLo >= 1 with R(alphaLo) certified, AND the Clopper-Pearson lower bound >= 0.95; alpha* is reported as the bracket [alphaLo, alphaHi] (0.01 is required for the judged shape only); NOT_ROBUST = a confirmed CPV with scaled norm <= 1 OR the lower bound below 0.95; NOT_ASSESSABLE = anything else.

Groups omitted (no finite in-envelope headline Level of the nominal aircraft; nothing to hold):
- 3.2.1.1-CatC: no finite in-envelope headline Level for the nominal aircraft (status NOT_ASSESSABLE; Category C (terminal phases TO, CT, PA, WO, L) is NOT_ASSESSABLE for this model: the NESC F-16 has no landing configuration (no gear, flap or speed-brake terms in F16_aero.dml), and a clean configuration at low speed is not an approach configuration (proposed ADR, reports/fragments/fq/DECISIONS.md))
- 3.2.1.2-CatC: no finite in-envelope headline Level for the nominal aircraft (status NOT_ASSESSABLE; Category C (terminal phases TO, CT, PA, WO, L) is NOT_ASSESSABLE for this model: the NESC F-16 has no landing configuration (no gear, flap or speed-brake terms in F16_aero.dml), and a clean configuration at low speed is not an approach configuration (proposed ADR, reports/fragments/fq/DECISIONS.md))
- 3.2.2.1.1-CatC: no finite in-envelope headline Level for the nominal aircraft (status NOT_ASSESSABLE; Category C (terminal phases TO, CT, PA, WO, L) is NOT_ASSESSABLE for this model: the NESC F-16 has no landing configuration (no gear, flap or speed-brake terms in F16_aero.dml), and a clean configuration at low speed is not an approach configuration (proposed ADR, reports/fragments/fq/DECISIONS.md))
- 3.2.2.1.2-CatC: no finite in-envelope headline Level for the nominal aircraft (status NOT_ASSESSABLE; Category C (terminal phases TO, CT, PA, WO, L) is NOT_ASSESSABLE for this model: the NESC F-16 has no landing configuration (no gear, flap or speed-brake terms in F16_aero.dml), and a clean configuration at low speed is not an approach configuration (proposed ADR, reports/fragments/fq/DECISIONS.md))
- 3.2.2.2-CatC: no finite in-envelope headline Level for the nominal aircraft (status NOT_ASSESSABLE; Category C (terminal phases TO, CT, PA, WO, L) is NOT_ASSESSABLE for this model: the NESC F-16 has no landing configuration (no gear, flap or speed-brake terms in F16_aero.dml), and a clean configuration at low speed is not an approach configuration (proposed ADR, reports/fragments/fq/DECISIONS.md))
- 3.3.1.1-CatC: no finite in-envelope headline Level for the nominal aircraft (status NOT_ASSESSABLE; Category C (terminal phases TO, CT, PA, WO, L) is NOT_ASSESSABLE for this model: the NESC F-16 has no landing configuration (no gear, flap or speed-brake terms in F16_aero.dml), and a clean configuration at low speed is not an approach configuration (proposed ADR, reports/fragments/fq/DECISIONS.md))
- 3.3.1.2-CatC: no finite in-envelope headline Level for the nominal aircraft (status NOT_ASSESSABLE; Category C (terminal phases TO, CT, PA, WO, L) is NOT_ASSESSABLE for this model: the NESC F-16 has no landing configuration (no gear, flap or speed-brake terms in F16_aero.dml), and a clean configuration at low speed is not an approach configuration (proposed ADR, reports/fragments/fq/DECISIONS.md))
- 3.3.1.3-CatC: no finite in-envelope headline Level for the nominal aircraft (status NOT_ASSESSABLE; Category C (terminal phases TO, CT, PA, WO, L) is NOT_ASSESSABLE for this model: the NESC F-16 has no landing configuration (no gear, flap or speed-brake terms in F16_aero.dml), and a clean configuration at low speed is not an approach configuration (proposed ADR, reports/fragments/fq/DECISIONS.md))
- 3.3.1.4-CatB: no finite in-envelope headline Level for the nominal aircraft (status NOT_APPLICABLE; not applicable at all 30 points)
- 3.3.1.4-CatC: no finite in-envelope headline Level for the nominal aircraft (status NOT_ASSESSABLE; Category C (terminal phases TO, CT, PA, WO, L) is NOT_ASSESSABLE for this model: the NESC F-16 has no landing configuration (no gear, flap or speed-brake terms in F16_aero.dml), and a clean configuration at low speed is not an approach configuration (proposed ADR, reports/fragments/fq/DECISIONS.md))

Box verdict (per width, the original M8 definition): ROBUST = bound-worst status OK with margin >= reserve AND Clopper-Pearson one-sided 95 % lower bound >= required; NOT_ROBUST = a counterexample in the box OR the lower bound below required; NOT_ASSESSABLE = anything else (e.g. the optimizer did not converge, FC-901, or a point in the box is not OK).

## Details per group

### 3.2.1.1-CatA
Nominal Level 1, margin 0.0111042, critical MIL-F-8785C-3.2.1.1-speed_divergence_rate_1_s-L1-CatA at h_ft=13000 mach=0.45 cg_pct_mac=30.
Candidates: h_ft=13000 mach=0.45 cg_pct_mac=30 (0.0111); h_ft=13000 mach=0.45 cg_pct_mac=25 (0.01211).
Search (longitudinal; margin to the nominal Level (minimized)): longitudinal group: searched over the longitudinal parameters only (Cm_q, Cm_basic, Cm_de), the lateral multipliers held at 1 (they change no longitudinal metric at a wings-level, beta = 0 trim: tests/M8/tUqR3F16.m#lonLatInvariance).
Lon/lat spot check: passed (margin 0.01110416464 with the lateral multipliers at 1 and 0.01110416464 at their most extreme lower values [0.08954 0.08954 0.5448 0.5448] (h_ft=13000 mach=0.45 cg_pct_mac=30): equal within 1e-9 relative).
Search method: lattice.
Shared lattice (R4b): 1331 lattice points and 1000 cells of this group (capped 0), 2 round(s), conditions h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.45 cg_pct_mac=25; certificate over all cells: 1000 of 1000 cells certified (bound: minimum vertex margin - sum L_i h_i/2, L = 2 x the measured slopes); 110 cell(s) straddle a breakpoint and are certified piecewise (110 certified).
Discontinuity (R5-3): the margin is DISCONTINUOUS at alpha_deg = 5 (jump up to 0.0003478, 440 edges): 110 cell(s) straddle a breakpoint (110 certified piecewise, each side from its own vertices); largest jump over a straddling edge 0.0003478.
Scope (R5-5 M2): certified over the candidate condition(s) h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.45 cg_pct_mac=25 only; the other conditions are checked by fresh assessments (confirmFcn) at the CPV, the cap-box and box arg-mins and the 2^d corners of R(1) and R(alphaLo).
  - confirmation cap arg-min judged: OK 0.0106031 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0106031; did not move)
  - confirmation cap arg-min equal: OK 0.0107614 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0107614; did not move)
  - confirmation box x1 arg-min: OK 0.0109712 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0109712; did not move)
  - confirmation corner R(1) 1: OK 0.0112848 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0112848; did not move)
  - confirmation corner R(1) 2: OK 0.0112847 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0112847; did not move)
  - confirmation corner R(1) 3: OK 0.0113873 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0113873; did not move)
  - confirmation corner R(1) 4: OK 0.0113872 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0113872; did not move)
  - confirmation corner R(1) 5: OK 0.0108942 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0108942; did not move)
  - confirmation corner R(1) 6: OK 0.010894 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.010894; did not move)
  - confirmation corner R(1) 7: OK 0.0109711 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0109711; did not move)
  - confirmation corner R(1) 8: OK 0.010971 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.010971; did not move)
  - confirmation corner R(3) 1: OK 0.0119462 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0119462; did not move)
  - confirmation corner R(3) 2: OK 0.011946 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.011946; did not move)
  - confirmation corner R(3) 3: OK 0.0124062 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0124062; did not move)
  - confirmation corner R(3) 4: OK 0.012406 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.012406; did not move)
  - confirmation corner R(3) 5: OK 0.0106034 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0106034; did not move)
  - confirmation corner R(3) 6: OK 0.0106031 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0106031; did not move)
  - confirmation corner R(3) 7: OK 0.0107881 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0107881; did not move)
  - confirmation corner R(3) 8: OK 0.0107877 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0107877; did not move)
Decided by stage 1 (R4-8): longitudinal lattice group: decided by the shared lattice in stage 1 (no stage 2).

| width | bound-worst | status | label | arg-min theta | condition | record | confirmation | rounds | Mahalanobis D (tail) | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | box verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x1 | 0.0109712 | OK | grid-certified (Lipschitz estimate) | [1.155 0.909 1.091 1 1 1 1] | h_ft=13000 mach=0.45 cg_pct_mac=30 | MIL-F-8785C-3.2.1.1-speed_divergence_rate_1_s-L1-CatA | OK 0.01097 | 2 | 3 (0.029, dof 3) |  | 27 | 200/200 | 0 | 0 | 0.9851 | ROBUST |

- x1: grid-certified (Lipschitz estimate): every one of the 64 lattice cells meeting the box is certified, lower bound 0.0107232 >= reserve 0. Verdict reason: bound-worst margin 0.01097 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
  - round 1: 2 candidate condition(s) (h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.45 cg_pct_mac=25); search value 0.0109712 at h_ft=13000 mach=0.45 cg_pct_mac=30, theta [1.155 0.909 1.091 1 1 1 1]; confirmation OK 0.0109712 at h_ft=13000 mach=0.45 cg_pct_mac=30 (did not move)
  - round 2: 2 candidate condition(s) (h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.45 cg_pct_mac=25); search value 0.0109712 at h_ft=13000 mach=0.45 cg_pct_mac=30, theta [1.155 0.909 1.091 1 1 1 1]; confirmation OK 0.0109712 at h_ft=13000 mach=0.45 cg_pct_mac=30 (did not move)
  - stages: lattice 27 points (converged yes)
  - grid certificate (Lipschitz estimate): certified 1, lower bound 0.0107232, L [5.054e-07 0.0007821 0.004095] (= 2 x measured slopes [2.527e-07 0.000391 0.002047]), grid-certified (Lipschitz estimate): every one of the 64 lattice cells meeting the box is certified, lower bound 0.0107232 >= reserve 0

Critical Similitude Ratio over Cm_q, Cm_basic, Cm_de; R4 verdict **ROBUST**: no failure up to the cap alpha = 3 (ROBUST_TO_CAP) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- judged shape (m = [0.2576 0.1517 0.1517]): status ROBUST_TO_CAP, alpha* 3, bracket [3, Inf]; parametric safety margin [0.7727 0.4552 0.4552 0 0 0 0]; CPV [NaN NaN NaN 1 1 1 1] at  (margin NaN, ), confirmation OK 0.0106031 at h_ft=13000 mach=0.45 cg_pct_mac=30; no failure up to AlphaMax: every lattice cell meeting the cap box R(3) is certified (grid-certified (Lipschitz estimate)) and no lattice point in it fails
  - lower end (R5-2): R(3) certified 1: every lattice cell meeting R(3) is certified (grid-certified (Lipschitz estimate)); the fresh assessments at 16 corner(s) inside it agree
- equal shape (m = [0.1 0.1 0.1]): status ROBUST_TO_CAP, alpha* 3, bracket [3, Inf]; parametric safety margin [0.3 0.3 0.3 0 0 0 0]; CPV [NaN NaN NaN 1 1 1 1] at  (margin NaN, ), confirmation OK 0.0107614 at h_ft=13000 mach=0.45 cg_pct_mac=30; no failure up to AlphaMax: every lattice cell meeting the cap box R(3) is certified (grid-certified (Lipschitz estimate)) and no lattice point in it fails
  - lower end (R5-2): R(3) certified 1: every lattice cell meeting R(3) is certified (grid-certified (Lipschitz estimate))

### 3.2.1.1-CatB
Nominal Level 1, margin 0.0111042, critical MIL-F-8785C-3.2.1.1-speed_divergence_rate_1_s-L1-CatB at h_ft=13000 mach=0.45 cg_pct_mac=30.
Candidates: h_ft=13000 mach=0.45 cg_pct_mac=30 (0.0111); h_ft=13000 mach=0.45 cg_pct_mac=25 (0.01211).
Search (longitudinal; margin to the nominal Level (minimized)): longitudinal group: searched over the longitudinal parameters only (Cm_q, Cm_basic, Cm_de), the lateral multipliers held at 1 (they change no longitudinal metric at a wings-level, beta = 0 trim: tests/M8/tUqR3F16.m#lonLatInvariance).
Lon/lat spot check: passed (margin 0.01110416464 with the lateral multipliers at 1 and 0.01110416464 at their most extreme lower values [0.08954 0.08954 0.5448 0.5448] (h_ft=13000 mach=0.45 cg_pct_mac=30): equal within 1e-9 relative).
Search method: lattice.
Shared lattice (R4b): 1331 lattice points and 1000 cells of this group (capped 0), 2 round(s), conditions h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.45 cg_pct_mac=25; certificate over all cells: 1000 of 1000 cells certified (bound: minimum vertex margin - sum L_i h_i/2, L = 2 x the measured slopes); 110 cell(s) straddle a breakpoint and are certified piecewise (110 certified).
Discontinuity (R5-3): the margin is DISCONTINUOUS at alpha_deg = 5 (jump up to 0.0003478, 440 edges): 110 cell(s) straddle a breakpoint (110 certified piecewise, each side from its own vertices); largest jump over a straddling edge 0.0003478.
Scope (R5-5 M2): certified over the candidate condition(s) h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.45 cg_pct_mac=25 only; the other conditions are checked by fresh assessments (confirmFcn) at the CPV, the cap-box and box arg-mins and the 2^d corners of R(1) and R(alphaLo).
  - confirmation cap arg-min judged: OK 0.0106031 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0106031; did not move)
  - confirmation cap arg-min equal: OK 0.0107614 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0107614; did not move)
  - confirmation box x1 arg-min: OK 0.0109712 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0109712; did not move)
  - confirmation corner R(1) 1: OK 0.0112848 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0112848; did not move)
  - confirmation corner R(1) 2: OK 0.0112847 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0112847; did not move)
  - confirmation corner R(1) 3: OK 0.0113873 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0113873; did not move)
  - confirmation corner R(1) 4: OK 0.0113872 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0113872; did not move)
  - confirmation corner R(1) 5: OK 0.0108942 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0108942; did not move)
  - confirmation corner R(1) 6: OK 0.010894 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.010894; did not move)
  - confirmation corner R(1) 7: OK 0.0109711 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0109711; did not move)
  - confirmation corner R(1) 8: OK 0.010971 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.010971; did not move)
  - confirmation corner R(3) 1: OK 0.0119462 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0119462; did not move)
  - confirmation corner R(3) 2: OK 0.011946 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.011946; did not move)
  - confirmation corner R(3) 3: OK 0.0124062 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0124062; did not move)
  - confirmation corner R(3) 4: OK 0.012406 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.012406; did not move)
  - confirmation corner R(3) 5: OK 0.0106034 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0106034; did not move)
  - confirmation corner R(3) 6: OK 0.0106031 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0106031; did not move)
  - confirmation corner R(3) 7: OK 0.0107881 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0107881; did not move)
  - confirmation corner R(3) 8: OK 0.0107877 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0107877; did not move)
Decided by stage 1 (R4-8): longitudinal lattice group: decided by the shared lattice in stage 1 (no stage 2).

| width | bound-worst | status | label | arg-min theta | condition | record | confirmation | rounds | Mahalanobis D (tail) | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | box verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x1 | 0.0109712 | OK | grid-certified (Lipschitz estimate) | [1.155 0.909 1.091 1 1 1 1] | h_ft=13000 mach=0.45 cg_pct_mac=30 | MIL-F-8785C-3.2.1.1-speed_divergence_rate_1_s-L1-CatB | OK 0.01097 | 2 | 3 (0.029, dof 3) |  | 27 | 200/200 | 0 | 0 | 0.9851 | ROBUST |

- x1: grid-certified (Lipschitz estimate): every one of the 64 lattice cells meeting the box is certified, lower bound 0.0107232 >= reserve 0. Verdict reason: bound-worst margin 0.01097 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
  - round 1: 2 candidate condition(s) (h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.45 cg_pct_mac=25); search value 0.0109712 at h_ft=13000 mach=0.45 cg_pct_mac=30, theta [1.155 0.909 1.091 1 1 1 1]; confirmation OK 0.0109712 at h_ft=13000 mach=0.45 cg_pct_mac=30 (did not move)
  - round 2: 2 candidate condition(s) (h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.45 cg_pct_mac=25); search value 0.0109712 at h_ft=13000 mach=0.45 cg_pct_mac=30, theta [1.155 0.909 1.091 1 1 1 1]; confirmation OK 0.0109712 at h_ft=13000 mach=0.45 cg_pct_mac=30 (did not move)
  - stages: lattice 27 points (converged yes)
  - grid certificate (Lipschitz estimate): certified 1, lower bound 0.0107232, L [5.054e-07 0.0007821 0.004095] (= 2 x measured slopes [2.527e-07 0.000391 0.002047]), grid-certified (Lipschitz estimate): every one of the 64 lattice cells meeting the box is certified, lower bound 0.0107232 >= reserve 0

Critical Similitude Ratio over Cm_q, Cm_basic, Cm_de; R4 verdict **ROBUST**: no failure up to the cap alpha = 3 (ROBUST_TO_CAP) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- judged shape (m = [0.2576 0.1517 0.1517]): status ROBUST_TO_CAP, alpha* 3, bracket [3, Inf]; parametric safety margin [0.7727 0.4552 0.4552 0 0 0 0]; CPV [NaN NaN NaN 1 1 1 1] at  (margin NaN, ), confirmation OK 0.0106031 at h_ft=13000 mach=0.45 cg_pct_mac=30; no failure up to AlphaMax: every lattice cell meeting the cap box R(3) is certified (grid-certified (Lipschitz estimate)) and no lattice point in it fails
  - lower end (R5-2): R(3) certified 1: every lattice cell meeting R(3) is certified (grid-certified (Lipschitz estimate)); the fresh assessments at 16 corner(s) inside it agree
- equal shape (m = [0.1 0.1 0.1]): status ROBUST_TO_CAP, alpha* 3, bracket [3, Inf]; parametric safety margin [0.3 0.3 0.3 0 0 0 0]; CPV [NaN NaN NaN 1 1 1 1] at  (margin NaN, ), confirmation OK 0.0107614 at h_ft=13000 mach=0.45 cg_pct_mac=30; no failure up to AlphaMax: every lattice cell meeting the cap box R(3) is certified (grid-certified (Lipschitz estimate)) and no lattice point in it fails
  - lower end (R5-2): R(3) certified 1: every lattice cell meeting R(3) is certified (grid-certified (Lipschitz estimate))

### 3.2.1.2-CatA
Nominal Level 1, margin 0.490644, critical MIL-F-8785C-3.2.1.2-zeta_p-L1-CatA at h_ft=13000 mach=0.45 cg_pct_mac=30.
Candidates: h_ft=13000 mach=0.45 cg_pct_mac=30 (0.4906); h_ft=13000 mach=0.5 cg_pct_mac=30 (0.6058).
Search (longitudinal; margin to the nominal Level (minimized)): longitudinal group: searched over the longitudinal parameters only (Cm_q, Cm_basic, Cm_de), the lateral multipliers held at 1 (they change no longitudinal metric at a wings-level, beta = 0 trim: tests/M8/tUqR3F16.m#lonLatInvariance).
Lon/lat spot check: passed (margin 0.4906444102 with the lateral multipliers at 1 and 0.4906444102 at their most extreme lower values [0.08954 0.08954 0.5448 0.5448] (h_ft=13000 mach=0.45 cg_pct_mac=30): equal within 1e-9 relative).
Search method: lattice.
Shared lattice (R4b): 1331 lattice points and 1000 cells of this group (capped 0), 2 round(s), conditions h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.5 cg_pct_mac=30; certificate over all cells: 1000 of 1000 cells certified (bound: minimum vertex margin - sum L_i h_i/2, L = 2 x the measured slopes).
Discontinuity (R5-3): the margin is continuous over the group's cells as far as the vertices show (no cell straddles a breakpoint).
Scope (R5-5 M2): certified over the candidate condition(s) h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.5 cg_pct_mac=30 only; the other conditions are checked by fresh assessments (confirmFcn) at the CPV, the cap-box and box arg-mins and the 2^d corners of R(1) and R(alphaLo).
  - confirmation cap arg-min judged: OK 0.466877 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.466877; did not move)
  - confirmation cap arg-min equal: OK 0.472897 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.472897; did not move)
  - confirmation box x1 arg-min: OK 0.481611 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.481611; did not move)
  - confirmation corner R(1) 1: OK 0.501743 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.501743; did not move)
  - confirmation corner R(1) 2: OK 0.514274 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.514274; did not move)
  - confirmation corner R(1) 3: OK 0.495562 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.495562; did not move)
  - confirmation corner R(1) 4: OK 0.51459 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.51459; did not move)
  - confirmation corner R(1) 5: OK 0.484303 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.484303; did not move)
  - confirmation corner R(1) 6: OK 0.489467 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.489467; did not move)
  - confirmation corner R(1) 7: OK 0.477444 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.477444; did not move)
  - confirmation corner R(1) 8: OK 0.487422 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.487422; did not move)
  - confirmation corner R(3) 1: OK 0.570246 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.570246; did not move)
  - confirmation corner R(3) 2: OK 0.6111 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.6111; did not move)
  - confirmation corner R(3) 3: OK 0.536245 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.536245; did not move)
  - confirmation corner R(3) 4: OK 0.657498 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.657498; did not move)
  - confirmation corner R(3) 5: OK 0.505198 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.505198; did not move)
  - confirmation corner R(3) 6: OK 0.492047 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.492047; did not move)
  - confirmation corner R(3) 7: OK 0.476134 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.476134; did not move)
  - confirmation corner R(3) 8: OK 0.495009 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.495009; did not move)
Decided by stage 1 (R4-8): longitudinal lattice group: decided by the shared lattice in stage 1 (no stage 2).

| width | bound-worst | status | label | arg-min theta | condition | record | confirmation | rounds | Mahalanobis D (tail) | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | box verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x1 | 0.481611 | OK | grid-certified (Lipschitz estimate) | [0.8455 1.091 1.091 1 1 1 1] | h_ft=13000 mach=0.45 cg_pct_mac=30 | MIL-F-8785C-3.2.1.2-zeta_p-L1-CatA | OK 0.4816 | 2 | 3 (0.029, dof 3) |  | 27 | 200/200 | 0 | 0 | 0.9851 | ROBUST |

- x1: grid-certified (Lipschitz estimate): every one of the 64 lattice cells meeting the box is certified, lower bound 0.461772 >= reserve 0. Verdict reason: bound-worst margin 0.4816 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
  - round 1: 2 candidate condition(s) (h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.5 cg_pct_mac=30); search value 0.481611 at h_ft=13000 mach=0.45 cg_pct_mac=30, theta [0.8455 1.091 1.091 1 1 1 1]; confirmation OK 0.481611 at h_ft=13000 mach=0.45 cg_pct_mac=30 (did not move)
  - round 2: 2 candidate condition(s) (h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.5 cg_pct_mac=30); search value 0.481611 at h_ft=13000 mach=0.45 cg_pct_mac=30, theta [0.8455 1.091 1.091 1 1 1 1]; confirmation OK 0.481611 at h_ft=13000 mach=0.45 cg_pct_mac=30 (did not move)
  - stages: lattice 27 points (converged yes)
  - grid certificate (Lipschitz estimate): certified 1, lower bound 0.461772, L [0.149 0.06539 0.4213] (= 2 x measured slopes [0.07451 0.0327 0.2107]), grid-certified (Lipschitz estimate): every one of the 64 lattice cells meeting the box is certified, lower bound 0.461772 >= reserve 0

Critical Similitude Ratio over Cm_q, Cm_basic, Cm_de; R4 verdict **ROBUST**: no failure up to the cap alpha = 3 (ROBUST_TO_CAP) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- judged shape (m = [0.2576 0.1517 0.1517]): status ROBUST_TO_CAP, alpha* 3, bracket [3, Inf]; parametric safety margin [0.7727 0.4552 0.4552 0 0 0 0]; CPV [NaN NaN NaN 1 1 1 1] at  (margin NaN, ), confirmation OK 0.466877 at h_ft=13000 mach=0.45 cg_pct_mac=30; no failure up to AlphaMax: every lattice cell meeting the cap box R(3) is certified (grid-certified (Lipschitz estimate)) and no lattice point in it fails
  - lower end (R5-2): R(3) certified 1: every lattice cell meeting R(3) is certified (grid-certified (Lipschitz estimate)); the fresh assessments at 16 corner(s) inside it agree
- equal shape (m = [0.1 0.1 0.1]): status ROBUST_TO_CAP, alpha* 3, bracket [3, Inf]; parametric safety margin [0.3 0.3 0.3 0 0 0 0]; CPV [NaN NaN NaN 1 1 1 1] at  (margin NaN, ), confirmation OK 0.472897 at h_ft=13000 mach=0.45 cg_pct_mac=30; no failure up to AlphaMax: every lattice cell meeting the cap box R(3) is certified (grid-certified (Lipschitz estimate)) and no lattice point in it fails
  - lower end (R5-2): R(3) certified 1: every lattice cell meeting R(3) is certified (grid-certified (Lipschitz estimate))

### 3.2.1.2-CatB
Nominal Level 1, margin 0.490644, critical MIL-F-8785C-3.2.1.2-zeta_p-L1-CatB at h_ft=13000 mach=0.45 cg_pct_mac=30.
Candidates: h_ft=13000 mach=0.45 cg_pct_mac=30 (0.4906); h_ft=13000 mach=0.5 cg_pct_mac=30 (0.6058).
Search (longitudinal; margin to the nominal Level (minimized)): longitudinal group: searched over the longitudinal parameters only (Cm_q, Cm_basic, Cm_de), the lateral multipliers held at 1 (they change no longitudinal metric at a wings-level, beta = 0 trim: tests/M8/tUqR3F16.m#lonLatInvariance).
Lon/lat spot check: passed (margin 0.4906444102 with the lateral multipliers at 1 and 0.4906444102 at their most extreme lower values [0.08954 0.08954 0.5448 0.5448] (h_ft=13000 mach=0.45 cg_pct_mac=30): equal within 1e-9 relative).
Search method: lattice.
Shared lattice (R4b): 1331 lattice points and 1000 cells of this group (capped 0), 2 round(s), conditions h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.5 cg_pct_mac=30; certificate over all cells: 1000 of 1000 cells certified (bound: minimum vertex margin - sum L_i h_i/2, L = 2 x the measured slopes).
Discontinuity (R5-3): the margin is continuous over the group's cells as far as the vertices show (no cell straddles a breakpoint).
Scope (R5-5 M2): certified over the candidate condition(s) h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.5 cg_pct_mac=30 only; the other conditions are checked by fresh assessments (confirmFcn) at the CPV, the cap-box and box arg-mins and the 2^d corners of R(1) and R(alphaLo).
  - confirmation cap arg-min judged: OK 0.466877 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.466877; did not move)
  - confirmation cap arg-min equal: OK 0.472897 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.472897; did not move)
  - confirmation box x1 arg-min: OK 0.481611 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.481611; did not move)
  - confirmation corner R(1) 1: OK 0.501743 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.501743; did not move)
  - confirmation corner R(1) 2: OK 0.514274 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.514274; did not move)
  - confirmation corner R(1) 3: OK 0.495562 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.495562; did not move)
  - confirmation corner R(1) 4: OK 0.51459 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.51459; did not move)
  - confirmation corner R(1) 5: OK 0.484303 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.484303; did not move)
  - confirmation corner R(1) 6: OK 0.489467 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.489467; did not move)
  - confirmation corner R(1) 7: OK 0.477444 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.477444; did not move)
  - confirmation corner R(1) 8: OK 0.487422 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.487422; did not move)
  - confirmation corner R(3) 1: OK 0.570246 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.570246; did not move)
  - confirmation corner R(3) 2: OK 0.6111 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.6111; did not move)
  - confirmation corner R(3) 3: OK 0.536245 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.536245; did not move)
  - confirmation corner R(3) 4: OK 0.657498 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.657498; did not move)
  - confirmation corner R(3) 5: OK 0.505198 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.505198; did not move)
  - confirmation corner R(3) 6: OK 0.492047 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.492047; did not move)
  - confirmation corner R(3) 7: OK 0.476134 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.476134; did not move)
  - confirmation corner R(3) 8: OK 0.495009 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.495009; did not move)
Decided by stage 1 (R4-8): longitudinal lattice group: decided by the shared lattice in stage 1 (no stage 2).

| width | bound-worst | status | label | arg-min theta | condition | record | confirmation | rounds | Mahalanobis D (tail) | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | box verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x1 | 0.481611 | OK | grid-certified (Lipschitz estimate) | [0.8455 1.091 1.091 1 1 1 1] | h_ft=13000 mach=0.45 cg_pct_mac=30 | MIL-F-8785C-3.2.1.2-zeta_p-L1-CatB | OK 0.4816 | 2 | 3 (0.029, dof 3) |  | 27 | 200/200 | 0 | 0 | 0.9851 | ROBUST |

- x1: grid-certified (Lipschitz estimate): every one of the 64 lattice cells meeting the box is certified, lower bound 0.461772 >= reserve 0. Verdict reason: bound-worst margin 0.4816 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
  - round 1: 2 candidate condition(s) (h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.5 cg_pct_mac=30); search value 0.481611 at h_ft=13000 mach=0.45 cg_pct_mac=30, theta [0.8455 1.091 1.091 1 1 1 1]; confirmation OK 0.481611 at h_ft=13000 mach=0.45 cg_pct_mac=30 (did not move)
  - round 2: 2 candidate condition(s) (h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.5 cg_pct_mac=30); search value 0.481611 at h_ft=13000 mach=0.45 cg_pct_mac=30, theta [0.8455 1.091 1.091 1 1 1 1]; confirmation OK 0.481611 at h_ft=13000 mach=0.45 cg_pct_mac=30 (did not move)
  - stages: lattice 27 points (converged yes)
  - grid certificate (Lipschitz estimate): certified 1, lower bound 0.461772, L [0.149 0.06539 0.4213] (= 2 x measured slopes [0.07451 0.0327 0.2107]), grid-certified (Lipschitz estimate): every one of the 64 lattice cells meeting the box is certified, lower bound 0.461772 >= reserve 0

Critical Similitude Ratio over Cm_q, Cm_basic, Cm_de; R4 verdict **ROBUST**: no failure up to the cap alpha = 3 (ROBUST_TO_CAP) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- judged shape (m = [0.2576 0.1517 0.1517]): status ROBUST_TO_CAP, alpha* 3, bracket [3, Inf]; parametric safety margin [0.7727 0.4552 0.4552 0 0 0 0]; CPV [NaN NaN NaN 1 1 1 1] at  (margin NaN, ), confirmation OK 0.466877 at h_ft=13000 mach=0.45 cg_pct_mac=30; no failure up to AlphaMax: every lattice cell meeting the cap box R(3) is certified (grid-certified (Lipschitz estimate)) and no lattice point in it fails
  - lower end (R5-2): R(3) certified 1: every lattice cell meeting R(3) is certified (grid-certified (Lipschitz estimate)); the fresh assessments at 16 corner(s) inside it agree
- equal shape (m = [0.1 0.1 0.1]): status ROBUST_TO_CAP, alpha* 3, bracket [3, Inf]; parametric safety margin [0.3 0.3 0.3 0 0 0 0]; CPV [NaN NaN NaN 1 1 1 1] at  (margin NaN, ), confirmation OK 0.472897 at h_ft=13000 mach=0.45 cg_pct_mac=30; no failure up to AlphaMax: every lattice cell meeting the cap box R(3) is certified (grid-certified (Lipschitz estimate)) and no lattice point in it fails
  - lower end (R5-2): R(3) certified 1: every lattice cell meeting R(3) is certified (grid-certified (Lipschitz estimate))

### 3.2.2.1.1-CatA
Nominal Level 1, margin 0.0512487, critical MIL-F-8785C-3.2.2.1.1-CAP-L1-CatA at h_ft=13000 mach=0.45 cg_pct_mac=30.
Candidates: h_ft=13000 mach=0.45 cg_pct_mac=30 (0.05125); h_ft=13000 mach=0.5 cg_pct_mac=30 (0.05524).
Search (longitudinal; margin to the nominal Level (minimized)): longitudinal group: searched over the longitudinal parameters only (Cm_q, Cm_basic, Cm_de), the lateral multipliers held at 1 (they change no longitudinal metric at a wings-level, beta = 0 trim: tests/M8/tUqR3F16.m#lonLatInvariance).
Lon/lat spot check: passed (margin 0.05124873902 with the lateral multipliers at 1 and 0.05124873902 at their most extreme lower values [0.08954 0.08954 0.5448 0.5448] (h_ft=13000 mach=0.45 cg_pct_mac=30): equal within 1e-9 relative).
Search method: lattice.
Shared lattice (R4b): 5417 lattice points and 3660 cells of this group (capped 1), 2 round(s), conditions h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.5 cg_pct_mac=30; certificate over all cells: 2427 of 3660 cells certified (bound: minimum vertex margin - sum L_i h_i/2, L = 2 x the measured slopes).
Discontinuity (R5-3): the margin is continuous over the group's cells as far as the vertices show (no cell straddles a breakpoint).
Scope (R5-5 M2): certified over the candidate condition(s) h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.5 cg_pct_mac=30 only; the other conditions are checked by fresh assessments (confirmFcn) at the CPV, the cap-box and box arg-mins and the 2^d corners of R(1) and R(alphaLo).
  - confirmation CPV judged: OK -0.000573286 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice -0.000573286; did not move)
  - confirmation CPV equal: OK -0.00129189 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice -0.00129189; did not move)
  - confirmation box x1 arg-min: OK -0.0169861 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice -0.0169861; did not move)
  - confirmation corner R(0.4488) 1: OK 0.0245917 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0245917; did not move)
  - confirmation corner R(0.4488) 2: OK 0.0655759 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0655759; did not move)
  - confirmation corner R(0.4488) 3: OK 0.0001998 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0001998; did not move)
  - confirmation corner R(0.4488) 4: OK 0.0410775 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0410775; did not move)
  - confirmation corner R(0.4488) 5: OK 0.0617838 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0617838; did not move)
  - confirmation corner R(0.4488) 6: OK 0.102328 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.102328; did not move)
  - confirmation corner R(0.4488) 7: OK 0.0376506 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0376506; did not move)
  - confirmation corner R(0.4488) 8: OK 0.078103 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.078103; did not move)
  - confirmation corner R(1) 1: OK -0.00780305 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice -0.00780305; did not move)
  - confirmation corner R(1) 2: OK 0.0844258 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0844258; did not move)
  - confirmation corner R(1) 3: OK -0.0624366 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice -0.0624366; did not move)
  - confirmation corner R(1) 4: OK 0.0292072 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0292072; did not move)
  - confirmation corner R(1) 5: OK 0.0751281 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0751281; did not move)
  - confirmation corner R(1) 6: OK 0.165089 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.165089; did not move)
  - confirmation corner R(1) 7: OK 0.0217589 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0217589; did not move)
  - confirmation corner R(1) 8: OK 0.111298 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.111298; did not move)
Decided by stage 1 (R4-8): longitudinal lattice group: decided by the shared lattice in stage 1 (no stage 2).

| width | bound-worst | status | label | arg-min theta | condition | record | confirmation | rounds | Mahalanobis D (tail) | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | box verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x1 | -0.0169861 | VIOLATED | grid-certified (Lipschitz estimate) | [0.8455 1.091 0.909 1 1 1 1] | h_ft=13000 mach=0.45 cg_pct_mac=30 | MIL-F-8785C-3.2.2.1.1-CAP-L1-CatA | OK -0.01699 | 2 | 3 (0.029, dof 3) |  | 4113 | 198/200 | 0 | 2 | 0.9689 | NOT_ROBUST |

- x1: lattice counterexample: margin -0.0169861 < reserve 0 at h_ft=13000 mach=0.45 cg_pct_mac=30, theta [0.84545 1.09105 0.908954]; 244 of 4113 lattice points inside fail. Verdict reason: bound-worst margin -0.01699 < reserve 0 (VIOLATED): a counterexample inside the box.
  - round 1: 2 candidate condition(s) (h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.5 cg_pct_mac=30); search value -0.0169861 at h_ft=13000 mach=0.45 cg_pct_mac=30, theta [0.8455 1.091 0.909 1 1 1 1]; confirmation OK -0.0169861 at h_ft=13000 mach=0.45 cg_pct_mac=30 (did not move)
  - round 2: 2 candidate condition(s) (h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.5 cg_pct_mac=30); search value -0.0169861 at h_ft=13000 mach=0.45 cg_pct_mac=30, theta [0.8455 1.091 0.909 1 1 1 1]; confirmation OK -0.0169861 at h_ft=13000 mach=0.45 cg_pct_mac=30 (did not move)
  - stages: lattice 4113 points (converged no)
  - grid certificate (Lipschitz estimate): certified 0, lower bound -0.155292, L [0.3678 0.3741 0.5774] (= 2 x measured slopes [0.1839 0.1871 0.2887]), lattice counterexample: margin -0.0169861 < reserve 0 at h_ft=13000 mach=0.45 cg_pct_mac=30, theta [0.84545 1.09105 0.908954]; 244 of 4113 lattice points inside fail

Critical Similitude Ratio over Cm_q, Cm_basic, Cm_de; R4 verdict **NOT_ROBUST**: alpha*(judged) < 1: a confirmed CPV at scaled norm 0.4594 <= 1 lies inside the judged box (CSR NOT_ASSESSABLE, alpha* NaN).
- judged shape (m = [0.2576 0.1517 0.1517]): status NOT_ASSESSABLE, alpha* NaN, bracket [0.4488, 0.4594]; parametric safety margin [NaN NaN NaN 0 0 0 0]; CPV [0.88409 1.0697 0.93029 1 1 1 1] at h_ft=13000 mach=0.45 cg_pct_mac=30 (margin -0.000573286, MIL-F-8785C-3.2.2.1.1-CAP-L1-CatA), confirmation OK -0.000573286 at h_ft=13000 mach=0.45 cg_pct_mac=30; GRID: the lattice caps are reached (MaxLevel 10, MaxPoints 6000 per group, 5417 points of the group, capped 1) with 5 uncertified cell(s) at entry alpha 0.4488 (grid-certified (Lipschitz estimate)); the global lattice budget (MaxTotalPoints 12000 over all groups) is exhausted; alpha* in [0.4488, 0.4594] is not resolved to 0.01
  - lower end (R5-2): R(0.4488) certified 1: every lattice cell meeting R(0.4488) is certified (grid-certified (Lipschitz estimate)); the fresh assessments at 8 corner(s) inside it agree
- equal shape (m = [0.1 0.1 0.1]): status NOT_ASSESSABLE, alpha* NaN, bracket [0.7397, 0.9105]; parametric safety margin [NaN NaN NaN 0 0 0 0]; CPV [0.92273 1.0797 0.90895 1 1 1 1] at h_ft=13000 mach=0.45 cg_pct_mac=30 (margin -0.00129189, MIL-F-8785C-3.2.2.1.1-CAP-L1-CatA), confirmation OK -0.00129189 at h_ft=13000 mach=0.45 cg_pct_mac=30; GRID: the lattice caps are reached (MaxLevel 10, MaxPoints 6000 per group, 5417 points of the group, capped 1) with 5 uncertified cell(s) at entry alpha 0.7397 (grid-certified (Lipschitz estimate)); the global lattice budget (MaxTotalPoints 12000 over all groups) is exhausted; alpha* in [0.7397, 0.9105] is not resolved to 0.01
  - lower end (R5-2): R(0.7397) certified 1: every lattice cell meeting R(0.7397) is certified (grid-certified (Lipschitz estimate))

### 3.2.2.1.1-CatB
Nominal Level 1, margin 2.46294, critical MIL-F-8785C-3.2.2.1.1-CAP-L1-CatB at h_ft=13000 mach=0.45 cg_pct_mac=30.
Candidates: h_ft=13000 mach=0.45 cg_pct_mac=30 (2.463); h_ft=13000 mach=0.5 cg_pct_mac=30 (2.476).
Search (longitudinal; margin to the nominal Level (minimized)): longitudinal group: searched over the longitudinal parameters only (Cm_q, Cm_basic, Cm_de), the lateral multipliers held at 1 (they change no longitudinal metric at a wings-level, beta = 0 trim: tests/M8/tUqR3F16.m#lonLatInvariance).
Lon/lat spot check: passed (margin 2.462937023 with the lateral multipliers at 1 and 2.462937023 at their most extreme lower values [0.08954 0.08954 0.5448 0.5448] (h_ft=13000 mach=0.45 cg_pct_mac=30): equal within 1e-9 relative).
Search method: lattice.
Shared lattice (R4b): 1331 lattice points and 1000 cells of this group (capped 0), 2 round(s), conditions h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.5 cg_pct_mac=30; h_ft=5000 mach=0.45 cg_pct_mac=30; certificate over all cells: 1000 of 1000 cells certified (bound: minimum vertex margin - sum L_i h_i/2, L = 2 x the measured slopes).
Discontinuity (R5-3): the margin is continuous over the group's cells as far as the vertices show (no cell straddles a breakpoint).
Scope (R5-5 M2): certified over the candidate condition(s) h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.5 cg_pct_mac=30; h_ft=5000 mach=0.45 cg_pct_mac=30 only; the other conditions are checked by fresh assessments (confirmFcn) at the CPV, the cap-box and box arg-mins and the 2^d corners of R(1) and R(alphaLo).
  - confirmation cap arg-min judged: OK 1.3427 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 1.3427; did not move)
  - confirmation cap arg-min equal: OK 1.97138 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 1.97138; did not move)
  - confirmation box x1 arg-min: OK 2.23816 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 2.23816; did not move)
  - confirmation corner R(1) 1: OK 2.26841 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 2.26841; did not move)
  - confirmation corner R(1) 2: OK 2.57223 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 2.57223; did not move)
  - confirmation corner R(1) 3: OK 2.08844 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 2.08844; did not move)
  - confirmation corner R(1) 4: OK 2.39033 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 2.39033; did not move)
  - confirmation corner R(1) 5: OK 2.5416 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 2.5416; did not move)
  - confirmation corner R(1) 6: OK 2.83794 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 2.83794; did not move)
  - confirmation corner R(1) 7: OK 2.36579 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 2.36579; did not move)
  - confirmation corner R(1) 8: OK 2.66075 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 2.66075; did not move)
  - confirmation corner R(3) 1: OK 1.90039 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 1.90039; did not move)
  - confirmation corner R(3) 2: OK 2.86791 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 2.86791; did not move)
  - confirmation corner R(3) 3: OK 1.3427 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 1.3427; did not move)
  - confirmation corner R(3) 4: OK 2.28237 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 2.28237; did not move)
  - confirmation corner R(3) 5: OK 2.70717 at h_ft=5000 mach=0.45 cg_pct_mac=30 (lattice 2.70717; did not move)
  - confirmation corner R(3) 6: OK 3.58884 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 3.58884; did not move)
  - confirmation corner R(3) 7: OK 2.19279 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 2.19279; did not move)
  - confirmation corner R(3) 8: OK 3.06207 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 3.06207; did not move)
Decided by stage 1 (R4-8): longitudinal lattice group: decided by the shared lattice in stage 1 (no stage 2).

| width | bound-worst | status | label | arg-min theta | condition | record | confirmation | rounds | Mahalanobis D (tail) | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | box verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x1 | 2.23816 | OK | grid-certified (Lipschitz estimate) | [0.8455 1.091 0.909 1 1 1 1] | h_ft=13000 mach=0.45 cg_pct_mac=30 | MIL-F-8785C-3.2.2.1.1-CAP-L1-CatB | OK 2.238 | 2 | 3 (0.029, dof 3) |  | 27 | 200/200 | 0 | 0 | 0.9851 | ROBUST |

- x1: grid-certified (Lipschitz estimate): every one of the 64 lattice cells meeting the box is certified, lower bound 1.78257 >= reserve 0. Verdict reason: bound-worst margin 2.238 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
  - round 1: 2 candidate condition(s) (h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.5 cg_pct_mac=30); search value 2.23816 at h_ft=13000 mach=0.45 cg_pct_mac=30, theta [0.8455 1.091 0.909 1 1 1 1]; confirmation OK 2.23816 at h_ft=13000 mach=0.45 cg_pct_mac=30 (did not move)
  - round 2: 3 candidate condition(s) (h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.5 cg_pct_mac=30; h_ft=5000 mach=0.45 cg_pct_mac=30); search value 2.23816 at h_ft=13000 mach=0.45 cg_pct_mac=30, theta [0.8455 1.091 0.909 1 1 1 1]; confirmation OK 2.23816 at h_ft=13000 mach=0.45 cg_pct_mac=30 (did not move)
  - stages: lattice 27 points (converged yes)
  - grid certificate (Lipschitz estimate): certified 1, lower bound 1.78257, L [1.212 1.232 1.902] (= 2 x measured slopes [0.6058 0.6162 0.951]), grid-certified (Lipschitz estimate): every one of the 64 lattice cells meeting the box is certified, lower bound 1.78257 >= reserve 0

Critical Similitude Ratio over Cm_q, Cm_basic, Cm_de; R4 verdict **ROBUST**: no failure up to the cap alpha = 3 (ROBUST_TO_CAP) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- judged shape (m = [0.2576 0.1517 0.1517]): status ROBUST_TO_CAP, alpha* 3, bracket [3, Inf]; parametric safety margin [0.7727 0.4552 0.4552 0 0 0 0]; CPV [NaN NaN NaN 1 1 1 1] at  (margin NaN, ), confirmation OK 1.3427 at h_ft=13000 mach=0.45 cg_pct_mac=30; no failure up to AlphaMax: every lattice cell meeting the cap box R(3) is certified (grid-certified (Lipschitz estimate)) and no lattice point in it fails
  - lower end (R5-2): R(3) certified 1: every lattice cell meeting R(3) is certified (grid-certified (Lipschitz estimate)); the fresh assessments at 16 corner(s) inside it agree
- equal shape (m = [0.1 0.1 0.1]): status ROBUST_TO_CAP, alpha* 3, bracket [3, Inf]; parametric safety margin [0.3 0.3 0.3 0 0 0 0]; CPV [NaN NaN NaN 1 1 1 1] at  (margin NaN, ), confirmation OK 1.97138 at h_ft=13000 mach=0.45 cg_pct_mac=30; no failure up to AlphaMax: every lattice cell meeting the cap box R(3) is certified (grid-certified (Lipschitz estimate)) and no lattice point in it fails
  - lower end (R5-2): R(3) certified 1: every lattice cell meeting R(3) is certified (grid-certified (Lipschitz estimate))

### 3.2.2.1.2-CatA
Nominal Level 1, margin 0.102065, critical MIL-F-8785C-3.2.2.1.2-zeta_sp-L1-CatA at h_ft=13000 mach=0.45 cg_pct_mac=20.
Candidates: h_ft=13000 mach=0.45 cg_pct_mac=20 (0.1021); h_ft=13000 mach=0.5 cg_pct_mac=20 (0.1373).
Search (longitudinal; margin to the nominal Level (minimized)): longitudinal group: searched over the longitudinal parameters only (Cm_q, Cm_basic, Cm_de), the lateral multipliers held at 1 (they change no longitudinal metric at a wings-level, beta = 0 trim: tests/M8/tUqR3F16.m#lonLatInvariance).
Lon/lat spot check: passed (margin 0.1020650197 with the lateral multipliers at 1 and 0.1020650197 at their most extreme lower values [0.08954 0.08954 0.5448 0.5448] (h_ft=13000 mach=0.45 cg_pct_mac=20): equal within 1e-9 relative).
Search method: lattice.
Shared lattice (R4b): 4049 lattice points and 2672 cells of this group (capped 1), 2 round(s), conditions h_ft=13000 mach=0.45 cg_pct_mac=20; h_ft=13000 mach=0.5 cg_pct_mac=20; certificate over all cells: 1847 of 2672 cells certified (bound: minimum vertex margin - sum L_i h_i/2, L = 2 x the measured slopes); 688 cell(s) straddle a breakpoint and are certified piecewise (523 certified).
Discontinuity (R5-3): the margin is DISCONTINUOUS at de_deg = -12 (jump up to 0.008015, 40 edges); alpha_deg = 5 (jump up to 0.0626, 2712 edges): 688 cell(s) straddle a breakpoint (523 certified piecewise, each side from its own vertices); largest jump over a straddling edge 0.0626.
Scope (R5-5 M2): certified over the candidate condition(s) h_ft=13000 mach=0.45 cg_pct_mac=20; h_ft=13000 mach=0.5 cg_pct_mac=20 only; the other conditions are checked by fresh assessments (confirmFcn) at the CPV, the cap-box and box arg-mins and the 2^d corners of R(1) and R(alphaLo).
  - confirmation CPV judged: OK -0.000486176 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice -0.000486176; did not move)
  - confirmation cap arg-min equal: OK 0.00183265 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice 0.00183265; did not move)
  - confirmation box x1 arg-min: OK 0.0182511 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice 0.0182511; did not move)
  - confirmation corner R(1) 1: OK 0.0187545 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice 0.0187545; did not move)
  - confirmation corner R(1) 2: OK 0.189542 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice 0.189542; did not move)
  - confirmation corner R(1) 3: OK 0.0165174 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice 0.0165174; did not move)
  - confirmation corner R(1) 4: OK 0.187107 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice 0.187107; did not move)
  - confirmation corner R(1) 5: OK 0.0438358 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice 0.0438358; did not move)
  - confirmation corner R(1) 6: OK 0.214399 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice 0.214399; did not move)
  - confirmation corner R(1) 7: OK 0.0545174 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice 0.0545174; did not move)
  - confirmation corner R(1) 8: OK 0.226405 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice 0.226405; did not move)
  - confirmation corner R(1.163) 1: OK 0.00492535 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice 0.00492535; did not move)
  - confirmation corner R(1.163) 2: OK 0.20391 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice 0.20391; did not move)
  - confirmation corner R(1.163) 3: OK 0.0023427 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice 0.0023427; did not move)
  - confirmation corner R(1.163) 4: OK 0.201063 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice 0.201063; did not move)
  - confirmation corner R(1.163) 5: OK 0.0288718 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice 0.0288718; did not move)
  - confirmation corner R(1.163) 6: OK 0.226771 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice 0.226771; did not move)
  - confirmation corner R(1.163) 7: OK 0.0411167 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice 0.0411167; did not move)
  - confirmation corner R(1.163) 8: OK 0.240799 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice 0.240799; did not move)
Decided by stage 1 (R4-8): longitudinal lattice group: decided by the shared lattice in stage 1 (no stage 2).

| width | bound-worst | status | label | arg-min theta | condition | record | confirmation | rounds | Mahalanobis D (tail) | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | box verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x1 | 0.0182511 | OK | grid-certified (Lipschitz estimate) | [0.7489 1.137 1 1 1 1 1] | h_ft=13000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.2.2.1.2-zeta_sp-L1-CatA | OK 0.01825 | 2 | 3.71 (0.0032, dof 3) |  | 111 | 200/200 | 0 | 0 | 0.9851 | ROBUST |

- x1: grid-certified (Lipschitz estimate): every one of the 144 lattice cells meeting the box is certified, lower bound 0.000296484 >= reserve 0. Verdict reason: bound-worst margin 0.01825 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
  - round 1: 2 candidate condition(s) (h_ft=13000 mach=0.45 cg_pct_mac=20; h_ft=13000 mach=0.5 cg_pct_mac=20); search value 0.0182511 at h_ft=13000 mach=0.45 cg_pct_mac=20, theta [0.7489 1.137 1 1 1 1 1]; confirmation OK 0.0182511 at h_ft=13000 mach=0.45 cg_pct_mac=20 (did not move)
  - round 2: 2 candidate condition(s) (h_ft=13000 mach=0.45 cg_pct_mac=20; h_ft=13000 mach=0.5 cg_pct_mac=20); search value 0.0182511 at h_ft=13000 mach=0.45 cg_pct_mac=20, theta [0.7489 1.137 1 1 1 1 1]; confirmation OK 0.0182511 at h_ft=13000 mach=0.45 cg_pct_mac=20 (did not move)
  - stages: lattice 111 points (converged yes)
  - grid certificate (Lipschitz estimate): certified 1, lower bound 0.000296484, L [0.6944 0.08715 0.05788] (= 2 x measured slopes [0.3472 0.04357 0.02894]), grid-certified (Lipschitz estimate): every one of the 144 lattice cells meeting the box is certified, lower bound 0.000296484 >= reserve 0

Critical Similitude Ratio over Cm_q, Cm_basic, Cm_de; R4 verdict **ROBUST**: the judged box R(1) is certified: alphaLo = 1.163 >= 1 (alpha* in [1.163, 1.191], CSR NOT_ASSESSABLE; every lattice cell meeting R(1.163) is certified (grid-certified (Lipschitz estimate)); the fresh assessments at 16 corner(s) inside it agree) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- judged shape (m = [0.2576 0.1517 0.1517]): status NOT_ASSESSABLE, alpha* NaN, bracket [1.163, 1.191]; parametric safety margin [NaN NaN NaN 0 0 0 0]; CPV [0.69332 1.1707 1.0455 1 1 1 1] at h_ft=13000 mach=0.45 cg_pct_mac=20 (margin -0.000486176, MIL-F-8785C-3.2.2.1.2-zeta_sp-L1-CatA), confirmation OK -0.000486176 at h_ft=13000 mach=0.45 cg_pct_mac=20; GRID: the lattice caps are reached (MaxLevel 10, MaxPoints 6000 per group, 4049 points of the group, capped 1) with 27 uncertified cell(s) at entry alpha 1.163 (grid-certified (Lipschitz estimate)); the global lattice budget (MaxTotalPoints 12000 over all groups) is exhausted; alpha* in [1.163, 1.191] is not resolved to 0.01
  - lower end (R5-2): R(1.163) certified 1: every lattice cell meeting R(1.163) is certified (grid-certified (Lipschitz estimate)); the fresh assessments at 16 corner(s) inside it agree
- equal shape (m = [0.1 0.1 0.1]): status NOT_ASSESSABLE, alpha* NaN, bracket [1.821, Inf]; parametric safety margin [NaN NaN NaN 0 0 0 0]; CPV [NaN NaN NaN 1 1 1 1] at  (margin NaN, ), confirmation OK 0.00183265 at h_ft=13000 mach=0.45 cg_pct_mac=20; GRID: the lattice caps are reached (MaxLevel 10, MaxPoints 6000 per group, 4049 points of the group, capped 1) with 36 uncertified cell(s) at entry alpha 1.821 (grid-certified (Lipschitz estimate)); the global lattice budget (MaxTotalPoints 12000 over all groups) is exhausted; alpha* in [1.821, Inf] is not resolved to 0.01
  - lower end (R5-2): R(1.821) certified 1: every lattice cell meeting R(1.821) is certified (grid-certified (Lipschitz estimate))

### 3.2.2.1.2-CatB
Nominal Level 1, margin 0.285743, critical MIL-F-8785C-3.2.2.1.2-zeta_sp-L1-CatB at h_ft=13000 mach=0.45 cg_pct_mac=20.
Candidates: h_ft=13000 mach=0.45 cg_pct_mac=20 (0.2857); h_ft=13000 mach=0.5 cg_pct_mac=20 (0.3268).
Search (longitudinal; margin to the nominal Level (minimized)): longitudinal group: searched over the longitudinal parameters only (Cm_q, Cm_basic, Cm_de), the lateral multipliers held at 1 (they change no longitudinal metric at a wings-level, beta = 0 trim: tests/M8/tUqR3F16.m#lonLatInvariance).
Lon/lat spot check: passed (margin 0.285742523 with the lateral multipliers at 1 and 0.285742523 at their most extreme lower values [0.08954 0.08954 0.5448 0.5448] (h_ft=13000 mach=0.45 cg_pct_mac=20): equal within 1e-9 relative).
Search method: lattice.
Shared lattice (R4b): 5211 lattice points and 3496 cells of this group (capped 0), 2 round(s), conditions h_ft=13000 mach=0.45 cg_pct_mac=20; h_ft=13000 mach=0.5 cg_pct_mac=20; certificate over all cells: 2978 of 3496 cells certified (bound: minimum vertex margin - sum L_i h_i/2, L = 2 x the measured slopes); 777 cell(s) straddle a breakpoint and are certified piecewise (611 certified).
Discontinuity (R5-3): the margin is DISCONTINUOUS at de_deg = -12 (jump up to 0.009351, 732 edges); alpha_deg = 5 (jump up to 0.07304, 2376 edges): 777 cell(s) straddle a breakpoint (611 certified piecewise, each side from its own vertices); largest jump over a straddling edge 0.07304.
Scope (R5-5 M2): certified over the candidate condition(s) h_ft=13000 mach=0.45 cg_pct_mac=20; h_ft=13000 mach=0.5 cg_pct_mac=20 only; the other conditions are checked by fresh assessments (confirmFcn) at the CPV, the cap-box and box arg-mins and the 2^d corners of R(1) and R(alphaLo).
  - confirmation CPV judged: OK -0.000234862 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice -0.000234862; did not move)
  - confirmation cap arg-min equal: OK 0.223675 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice 0.223675; did not move)
  - confirmation box x1 arg-min: OK 0.225664 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice 0.225664; did not move)
  - confirmation corner R(1) 1: OK 0.188547 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice 0.188547; did not move)
  - confirmation corner R(1) 2: OK 0.387799 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice 0.387799; did not move)
  - confirmation corner R(1) 3: OK 0.185937 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice 0.185937; did not move)
  - confirmation corner R(1) 4: OK 0.384958 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice 0.384958; did not move)
  - confirmation corner R(1) 5: OK 0.217808 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice 0.217808; did not move)
  - confirmation corner R(1) 6: OK 0.416798 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice 0.416798; did not move)
  - confirmation corner R(1) 7: OK 0.23027 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice 0.23027; did not move)
  - confirmation corner R(1) 8: OK 0.430805 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice 0.430805; did not move)
  - confirmation corner R(2.766) 1: OK 0.00731664 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice 0.00731664; did not move)
  - confirmation corner R(2.766) 2: OK 0.57408 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice 0.57408; did not move)
  - confirmation corner R(2.766) 3: OK 0.000632315 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice 0.000632315; did not move)
  - confirmation corner R(2.766) 4: OK 0.565987 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice 0.565987; did not move)
  - confirmation corner R(2.766) 5: OK 0.0301695 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice 0.0301695; did not move)
  - confirmation corner R(2.766) 6: OK 0.56946 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice 0.56946; did not move)
  - confirmation corner R(2.766) 7: OK 0.0594762 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice 0.0594762; did not move)
  - confirmation corner R(2.766) 8: OK 0.61015 at h_ft=13000 mach=0.45 cg_pct_mac=20 (lattice 0.61015; did not move)
Decided by stage 1 (R4-8): longitudinal lattice group: decided by the shared lattice in stage 1 (no stage 2).

| width | bound-worst | status | label | arg-min theta | condition | record | confirmation | rounds | Mahalanobis D (tail) | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | box verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x1 | 0.225664 | OK | grid-certified (Lipschitz estimate) | [0.8455 1.091 1 1 1 1 1] | h_ft=13000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.2.2.1.2-zeta_sp-L1-CatB | OK 0.2257 | 2 | 2.39 (0.13, dof 3) |  | 27 | 200/200 | 0 | 0 | 0.9851 | ROBUST |

- x1: grid-certified (Lipschitz estimate): every one of the 64 lattice cells meeting the box is certified, lower bound 0.0311256 >= reserve 0. Verdict reason: bound-worst margin 0.2257 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
  - round 1: 2 candidate condition(s) (h_ft=13000 mach=0.45 cg_pct_mac=20; h_ft=13000 mach=0.5 cg_pct_mac=20); search value 0.225664 at h_ft=13000 mach=0.45 cg_pct_mac=20, theta [0.8455 1.091 1 1 1 1 1]; confirmation OK 0.225664 at h_ft=13000 mach=0.45 cg_pct_mac=20 (did not move)
  - round 2: 2 candidate condition(s) (h_ft=13000 mach=0.45 cg_pct_mac=20; h_ft=13000 mach=0.5 cg_pct_mac=20); search value 0.225664 at h_ft=13000 mach=0.45 cg_pct_mac=20, theta [0.8455 1.091 1 1 1 1 1]; confirmation OK 0.225664 at h_ft=13000 mach=0.45 cg_pct_mac=20 (did not move)
  - stages: lattice 27 points (converged yes)
  - grid certificate (Lipschitz estimate): certified 1, lower bound 0.0311256, L [0.8102 0.1017 0.06753] (= 2 x measured slopes [0.4051 0.05083 0.03377]), grid-certified (Lipschitz estimate): every one of the 64 lattice cells meeting the box is certified, lower bound 0.0311256 >= reserve 0

Critical Similitude Ratio over Cm_q, Cm_basic, Cm_de; R4 verdict **ROBUST**: the judged box R(1) is certified: alphaLo = 2.766 >= 1 (alpha* in [2.766, 2.775], CSR OK; every lattice cell meeting R(2.766) is certified (grid-certified (Lipschitz estimate)); the fresh assessments at 16 corner(s) inside it agree) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- judged shape (m = [0.2576 0.1517 0.1517]): status OK, alpha* 2.766, bracket [2.766, 2.775]; parametric safety margin [0.7124 0.4197 0.4197 0 0 0 0]; CPV [0.28521 1.4097 0.59029 1 1 1 1] at h_ft=13000 mach=0.45 cg_pct_mac=20 (margin -0.000234862, MIL-F-8785C-3.2.2.1.2-zeta_sp-L1-CatB), confirmation OK -0.000234862 at h_ft=13000 mach=0.45 cg_pct_mac=20; alpha* in [2.766, 2.775] (resolution 0.01), read from the lattice: every cell meeting R(2.766) is certified (grid-certified (Lipschitz estimate)) and the CPV at scaled norm 2.775 fails (margin -0.000234862 at h_ft=13000 mach=0.45 cg_pct_mac=20, MIL-F-8785C-3.2.2.1.2-zeta_sp-L1-CatB), confirmed by a fresh assessment
  - lower end (R5-2): R(2.766) certified 1: every lattice cell meeting R(2.766) is certified (grid-certified (Lipschitz estimate)); the fresh assessments at 16 corner(s) inside it agree
- equal shape (m = [0.1 0.1 0.1]): status ROBUST_TO_CAP, alpha* 3, bracket [3, Inf]; parametric safety margin [0.3 0.3 0.3 0 0 0 0]; CPV [NaN NaN NaN 1 1 1 1] at  (margin NaN, ), confirmation OK 0.223675 at h_ft=13000 mach=0.45 cg_pct_mac=20; no failure up to AlphaMax: every lattice cell meeting the cap box R(3) is certified (grid-certified (Lipschitz estimate)) and no lattice point in it fails
  - lower end (R5-2): R(3) certified 1: every lattice cell meeting R(3) is certified (grid-certified (Lipschitz estimate))

### 3.2.2.2-CatA
Nominal Level 1, margin 0.0111042, critical MIL-F-8785C-3.2.2.2-lon_divergence_rate_1_s-L1-CatA at h_ft=13000 mach=0.45 cg_pct_mac=30.
Candidates: h_ft=13000 mach=0.45 cg_pct_mac=30 (0.0111); h_ft=13000 mach=0.45 cg_pct_mac=25 (0.01211).
Search (longitudinal; margin to the nominal Level (minimized)): longitudinal group: searched over the longitudinal parameters only (Cm_q, Cm_basic, Cm_de), the lateral multipliers held at 1 (they change no longitudinal metric at a wings-level, beta = 0 trim: tests/M8/tUqR3F16.m#lonLatInvariance).
Lon/lat spot check: passed (margin 0.01110416464 with the lateral multipliers at 1 and 0.01110416464 at their most extreme lower values [0.08954 0.08954 0.5448 0.5448] (h_ft=13000 mach=0.45 cg_pct_mac=30): equal within 1e-9 relative).
Search method: lattice.
Shared lattice (R4b): 1331 lattice points and 1000 cells of this group (capped 0), 2 round(s), conditions h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.45 cg_pct_mac=25; certificate over all cells: 1000 of 1000 cells certified (bound: minimum vertex margin - sum L_i h_i/2, L = 2 x the measured slopes); 110 cell(s) straddle a breakpoint and are certified piecewise (110 certified).
Discontinuity (R5-3): the margin is DISCONTINUOUS at alpha_deg = 5 (jump up to 0.0003478, 440 edges): 110 cell(s) straddle a breakpoint (110 certified piecewise, each side from its own vertices); largest jump over a straddling edge 0.0003478.
Scope (R5-5 M2): certified over the candidate condition(s) h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.45 cg_pct_mac=25 only; the other conditions are checked by fresh assessments (confirmFcn) at the CPV, the cap-box and box arg-mins and the 2^d corners of R(1) and R(alphaLo).
  - confirmation cap arg-min judged: OK 0.0106031 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0106031; did not move)
  - confirmation cap arg-min equal: OK 0.0107614 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0107614; did not move)
  - confirmation box x1 arg-min: OK 0.0109712 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0109712; did not move)
  - confirmation corner R(1) 1: OK 0.0112848 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0112848; did not move)
  - confirmation corner R(1) 2: OK 0.0112847 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0112847; did not move)
  - confirmation corner R(1) 3: OK 0.0113873 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0113873; did not move)
  - confirmation corner R(1) 4: OK 0.0113872 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0113872; did not move)
  - confirmation corner R(1) 5: OK 0.0108942 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0108942; did not move)
  - confirmation corner R(1) 6: OK 0.010894 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.010894; did not move)
  - confirmation corner R(1) 7: OK 0.0109711 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0109711; did not move)
  - confirmation corner R(1) 8: OK 0.010971 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.010971; did not move)
  - confirmation corner R(3) 1: OK 0.0119462 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0119462; did not move)
  - confirmation corner R(3) 2: OK 0.011946 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.011946; did not move)
  - confirmation corner R(3) 3: OK 0.0124062 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0124062; did not move)
  - confirmation corner R(3) 4: OK 0.012406 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.012406; did not move)
  - confirmation corner R(3) 5: OK 0.0106034 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0106034; did not move)
  - confirmation corner R(3) 6: OK 0.0106031 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0106031; did not move)
  - confirmation corner R(3) 7: OK 0.0107881 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0107881; did not move)
  - confirmation corner R(3) 8: OK 0.0107877 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0107877; did not move)
Decided by stage 1 (R4-8): longitudinal lattice group: decided by the shared lattice in stage 1 (no stage 2).

| width | bound-worst | status | label | arg-min theta | condition | record | confirmation | rounds | Mahalanobis D (tail) | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | box verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x1 | 0.0109712 | OK | grid-certified (Lipschitz estimate) | [1.155 0.909 1.091 1 1 1 1] | h_ft=13000 mach=0.45 cg_pct_mac=30 | MIL-F-8785C-3.2.2.2-lon_divergence_rate_1_s-L1-CatA | OK 0.01097 | 2 | 3 (0.029, dof 3) |  | 27 | 200/200 | 0 | 0 | 0.9851 | ROBUST |

- x1: grid-certified (Lipschitz estimate): every one of the 64 lattice cells meeting the box is certified, lower bound 0.0107232 >= reserve 0. Verdict reason: bound-worst margin 0.01097 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
  - round 1: 2 candidate condition(s) (h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.45 cg_pct_mac=25); search value 0.0109712 at h_ft=13000 mach=0.45 cg_pct_mac=30, theta [1.155 0.909 1.091 1 1 1 1]; confirmation OK 0.0109712 at h_ft=13000 mach=0.45 cg_pct_mac=30 (did not move)
  - round 2: 2 candidate condition(s) (h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.45 cg_pct_mac=25); search value 0.0109712 at h_ft=13000 mach=0.45 cg_pct_mac=30, theta [1.155 0.909 1.091 1 1 1 1]; confirmation OK 0.0109712 at h_ft=13000 mach=0.45 cg_pct_mac=30 (did not move)
  - stages: lattice 27 points (converged yes)
  - grid certificate (Lipschitz estimate): certified 1, lower bound 0.0107232, L [5.054e-07 0.0007821 0.004095] (= 2 x measured slopes [2.527e-07 0.000391 0.002047]), grid-certified (Lipschitz estimate): every one of the 64 lattice cells meeting the box is certified, lower bound 0.0107232 >= reserve 0

Critical Similitude Ratio over Cm_q, Cm_basic, Cm_de; R4 verdict **ROBUST**: no failure up to the cap alpha = 3 (ROBUST_TO_CAP) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- judged shape (m = [0.2576 0.1517 0.1517]): status ROBUST_TO_CAP, alpha* 3, bracket [3, Inf]; parametric safety margin [0.7727 0.4552 0.4552 0 0 0 0]; CPV [NaN NaN NaN 1 1 1 1] at  (margin NaN, ), confirmation OK 0.0106031 at h_ft=13000 mach=0.45 cg_pct_mac=30; no failure up to AlphaMax: every lattice cell meeting the cap box R(3) is certified (grid-certified (Lipschitz estimate)) and no lattice point in it fails
  - lower end (R5-2): R(3) certified 1: every lattice cell meeting R(3) is certified (grid-certified (Lipschitz estimate)); the fresh assessments at 16 corner(s) inside it agree
- equal shape (m = [0.1 0.1 0.1]): status ROBUST_TO_CAP, alpha* 3, bracket [3, Inf]; parametric safety margin [0.3 0.3 0.3 0 0 0 0]; CPV [NaN NaN NaN 1 1 1 1] at  (margin NaN, ), confirmation OK 0.0107614 at h_ft=13000 mach=0.45 cg_pct_mac=30; no failure up to AlphaMax: every lattice cell meeting the cap box R(3) is certified (grid-certified (Lipschitz estimate)) and no lattice point in it fails
  - lower end (R5-2): R(3) certified 1: every lattice cell meeting R(3) is certified (grid-certified (Lipschitz estimate))

### 3.2.2.2-CatB
Nominal Level 1, margin 0.0111042, critical MIL-F-8785C-3.2.2.2-lon_divergence_rate_1_s-L1-CatB at h_ft=13000 mach=0.45 cg_pct_mac=30.
Candidates: h_ft=13000 mach=0.45 cg_pct_mac=30 (0.0111); h_ft=13000 mach=0.45 cg_pct_mac=25 (0.01211).
Search (longitudinal; margin to the nominal Level (minimized)): longitudinal group: searched over the longitudinal parameters only (Cm_q, Cm_basic, Cm_de), the lateral multipliers held at 1 (they change no longitudinal metric at a wings-level, beta = 0 trim: tests/M8/tUqR3F16.m#lonLatInvariance).
Lon/lat spot check: passed (margin 0.01110416464 with the lateral multipliers at 1 and 0.01110416464 at their most extreme lower values [0.08954 0.08954 0.5448 0.5448] (h_ft=13000 mach=0.45 cg_pct_mac=30): equal within 1e-9 relative).
Search method: lattice.
Shared lattice (R4b): 1331 lattice points and 1000 cells of this group (capped 0), 2 round(s), conditions h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.45 cg_pct_mac=25; certificate over all cells: 1000 of 1000 cells certified (bound: minimum vertex margin - sum L_i h_i/2, L = 2 x the measured slopes); 110 cell(s) straddle a breakpoint and are certified piecewise (110 certified).
Discontinuity (R5-3): the margin is DISCONTINUOUS at alpha_deg = 5 (jump up to 0.0003478, 440 edges): 110 cell(s) straddle a breakpoint (110 certified piecewise, each side from its own vertices); largest jump over a straddling edge 0.0003478.
Scope (R5-5 M2): certified over the candidate condition(s) h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.45 cg_pct_mac=25 only; the other conditions are checked by fresh assessments (confirmFcn) at the CPV, the cap-box and box arg-mins and the 2^d corners of R(1) and R(alphaLo).
  - confirmation cap arg-min judged: OK 0.0106031 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0106031; did not move)
  - confirmation cap arg-min equal: OK 0.0107614 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0107614; did not move)
  - confirmation box x1 arg-min: OK 0.0109712 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0109712; did not move)
  - confirmation corner R(1) 1: OK 0.0112848 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0112848; did not move)
  - confirmation corner R(1) 2: OK 0.0112847 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0112847; did not move)
  - confirmation corner R(1) 3: OK 0.0113873 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0113873; did not move)
  - confirmation corner R(1) 4: OK 0.0113872 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0113872; did not move)
  - confirmation corner R(1) 5: OK 0.0108942 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0108942; did not move)
  - confirmation corner R(1) 6: OK 0.010894 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.010894; did not move)
  - confirmation corner R(1) 7: OK 0.0109711 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0109711; did not move)
  - confirmation corner R(1) 8: OK 0.010971 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.010971; did not move)
  - confirmation corner R(3) 1: OK 0.0119462 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0119462; did not move)
  - confirmation corner R(3) 2: OK 0.011946 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.011946; did not move)
  - confirmation corner R(3) 3: OK 0.0124062 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0124062; did not move)
  - confirmation corner R(3) 4: OK 0.012406 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.012406; did not move)
  - confirmation corner R(3) 5: OK 0.0106034 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0106034; did not move)
  - confirmation corner R(3) 6: OK 0.0106031 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0106031; did not move)
  - confirmation corner R(3) 7: OK 0.0107881 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0107881; did not move)
  - confirmation corner R(3) 8: OK 0.0107877 at h_ft=13000 mach=0.45 cg_pct_mac=30 (lattice 0.0107877; did not move)
Decided by stage 1 (R4-8): longitudinal lattice group: decided by the shared lattice in stage 1 (no stage 2).

| width | bound-worst | status | label | arg-min theta | condition | record | confirmation | rounds | Mahalanobis D (tail) | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | box verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x1 | 0.0109712 | OK | grid-certified (Lipschitz estimate) | [1.155 0.909 1.091 1 1 1 1] | h_ft=13000 mach=0.45 cg_pct_mac=30 | MIL-F-8785C-3.2.2.2-lon_divergence_rate_1_s-L1-CatB | OK 0.01097 | 2 | 3 (0.029, dof 3) |  | 27 | 200/200 | 0 | 0 | 0.9851 | ROBUST |

- x1: grid-certified (Lipschitz estimate): every one of the 64 lattice cells meeting the box is certified, lower bound 0.0107232 >= reserve 0. Verdict reason: bound-worst margin 0.01097 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
  - round 1: 2 candidate condition(s) (h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.45 cg_pct_mac=25); search value 0.0109712 at h_ft=13000 mach=0.45 cg_pct_mac=30, theta [1.155 0.909 1.091 1 1 1 1]; confirmation OK 0.0109712 at h_ft=13000 mach=0.45 cg_pct_mac=30 (did not move)
  - round 2: 2 candidate condition(s) (h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.45 cg_pct_mac=25); search value 0.0109712 at h_ft=13000 mach=0.45 cg_pct_mac=30, theta [1.155 0.909 1.091 1 1 1 1]; confirmation OK 0.0109712 at h_ft=13000 mach=0.45 cg_pct_mac=30 (did not move)
  - stages: lattice 27 points (converged yes)
  - grid certificate (Lipschitz estimate): certified 1, lower bound 0.0107232, L [5.054e-07 0.0007821 0.004095] (= 2 x measured slopes [2.527e-07 0.000391 0.002047]), grid-certified (Lipschitz estimate): every one of the 64 lattice cells meeting the box is certified, lower bound 0.0107232 >= reserve 0

Critical Similitude Ratio over Cm_q, Cm_basic, Cm_de; R4 verdict **ROBUST**: no failure up to the cap alpha = 3 (ROBUST_TO_CAP) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- judged shape (m = [0.2576 0.1517 0.1517]): status ROBUST_TO_CAP, alpha* 3, bracket [3, Inf]; parametric safety margin [0.7727 0.4552 0.4552 0 0 0 0]; CPV [NaN NaN NaN 1 1 1 1] at  (margin NaN, ), confirmation OK 0.0106031 at h_ft=13000 mach=0.45 cg_pct_mac=30; no failure up to AlphaMax: every lattice cell meeting the cap box R(3) is certified (grid-certified (Lipschitz estimate)) and no lattice point in it fails
  - lower end (R5-2): R(3) certified 1: every lattice cell meeting R(3) is certified (grid-certified (Lipschitz estimate)); the fresh assessments at 16 corner(s) inside it agree
- equal shape (m = [0.1 0.1 0.1]): status ROBUST_TO_CAP, alpha* 3, bracket [3, Inf]; parametric safety margin [0.3 0.3 0.3 0 0 0 0]; CPV [NaN NaN NaN 1 1 1 1] at  (margin NaN, ), confirmation OK 0.0107614 at h_ft=13000 mach=0.45 cg_pct_mac=30; no failure up to AlphaMax: every lattice cell meeting the cap box R(3) is certified (grid-certified (Lipschitz estimate)) and no lattice point in it fails
  - lower end (R5-2): R(3) certified 1: every lattice cell meeting R(3) is certified (grid-certified (Lipschitz estimate))

### 3.3.1.1-CatA-COGA
Nominal Level 1, margin 0.0537643, critical MIL-F-8785C-3.3.1.1-zeta_d-L1-CatA-COGA at h_ft=13000 mach=0.45 cg_pct_mac=20.
Candidates: h_ft=13000 mach=0.45 cg_pct_mac=20 (0.05376); h_ft=13000 mach=0.45 cg_pct_mac=25 (0.05951); h_ft=13000 mach=0.45 cg_pct_mac=30 (0.06708); h_ft=13000 mach=0.5 cg_pct_mac=20 (0.187).
Search (lateral; margin to the nominal Level (minimized)): all parameters (the margin depends on the whole box); R4-9: lateral group, Cm_q is not searched (held at 1): it acts only through the pitch rate, zero at the wings-level trim, so it cannot change a lateral metric (gated); the R4-9 gate passed (value 0.05376429546 unchanged at 2 moved point(s) within 1e-09 relative (largest 1.29e-14)).
Search method: hybrid.
R4-9 gate (Cm_q held at 1) at h_ft=13000 mach=0.45 cg_pct_mac=20: passed (value 0.05376429546 unchanged at 2 moved point(s) within 1e-09 relative (largest 1.29e-14)).
Decided by stage 2 (R4-8): the judged CSR is NOT_ASSESSABLE for budget reasons: the box R(0.3377) is not decided (alpha* in [0, 0.3477]): FC-901: the local stage (Nelder-Mead) did not converge (start 2 exit flag 0 (Exiting: Maximum number of function evaluations has been exceeded - increase MaxFunEvals option. Current function value: 0.001365)) and no counterexample was found.
stage-1 result (re-run at the full budget): verdict NOT_ROBUST; 2 candidate condition(s); CSR judged NOT_ASSESSABLE in [0, 0.3477]; x1 bound-worst -0.0962928 (VIOLATED).

| width | bound-worst | status | label | arg-min theta | condition | record | confirmation | rounds | Mahalanobis D (tail) | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | box verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x1 | -0.0962928 | VIOLATED | search estimate (hybrid: differential evolution + Nelder-Mead) | [1 1.152 0.8483 0.6965 0.6965 1.152 1.152] | h_ft=13000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.3.1.1-zeta_d-L1-CatA-COGA | OK -0.09629 | 1 | 7.43 (4.1e-10, dof 6) | 1, 0 | 485 | 197/200 | 0 | 3 | 0.9617 | NOT_ROBUST |

- x1: counterexample: margin -0.0962928 < reserve 0 at h_ft=13000 mach=0.45 cg_pct_mac=20 (MIL-F-8785C-3.3.1.1-zeta_d-L1-CatA-COGA), theta [1.15174 0.848257 0.696515 0.696515 1.15174 1.15174]; 376 of 485 evaluated points violate; definitive although the optimizer did not converge. Verdict reason: bound-worst margin -0.09629 < reserve 0 (VIOLATED): a counterexample inside the box.
  - round 1: 4 candidate condition(s) (h_ft=13000 mach=0.45 cg_pct_mac=20; h_ft=13000 mach=0.45 cg_pct_mac=25; h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.5 cg_pct_mac=20); search value -0.0962928 at h_ft=13000 mach=0.45 cg_pct_mac=20, theta [1 1.152 0.8483 0.6965 0.6965 1.152 1.152]; confirmation OK -0.0962928 at h_ft=13000 mach=0.45 cg_pct_mac=20 (did not move)
  - stages: centre 1 points (converged -); corner 64 points (converged -); lhs 32 points (converged -); de 128 points (converged no); local 260 points (converged no)

Critical Similitude Ratio over Cm_basic, Cm_de, Cl_p, Cn_r, Cl_table, Cnt_table; R4 verdict **NOT_ROBUST**: alpha*(judged) < 1: a confirmed CPV at scaled norm 0.3477 <= 1 lies inside the judged box (CSR NOT_ASSESSABLE, alpha* NaN).
- judged shape (m = [0.1517 0.1517 0.3035 0.3035 0.1517 0.1517]): status NOT_ASSESSABLE, alpha* NaN, bracket [0, 0.3477]; parametric safety margin [0 NaN NaN NaN NaN NaN NaN]; CPV [1 1.0528 0.94725 0.89449 0.89449 1.0528 1.0528] at h_ft=13000 mach=0.45 cg_pct_mac=20 (margin -0.00016541, MIL-F-8785C-3.3.1.1-zeta_d-L1-CatA-COGA), confirmation  NaN at ; the box R(0.3377) is not decided (alpha* in [0, 0.3477]): FC-901: the local stage (Nelder-Mead) did not converge (start 2 exit flag 0 (Exiting: Maximum number of function evaluations has been exceeded - increase MaxFunEvals option. Current function value: 0.001365)) and no counterexample was found
  - lower end (R5-2): R(0) certified 1: only the nominal point (R(0)) is known clean
  - box search alpha 0.3377 (optimistic): NOT_ASSESSABLE, value 0.00136011 at h_ft=13000 mach=0.45 cg_pct_mac=20, 473 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - ray (prior): failing at scaled norm 0.3477 (t in [0.3438, 0.3477]), margin -0.00016541 at h_ft=13000 mach=0.45 cg_pct_mac=20
- equal shape (m = [0.1 0.1 0.1 0.1 0.1 0.1]): status NOT_ASSESSABLE, alpha* NaN, bracket [0, 0.7389]; parametric safety margin [0 NaN NaN NaN NaN NaN NaN]; CPV [1 1.0739 0.92611 0.92611 0.92611 1.0739 1.0739] at h_ft=13000 mach=0.45 cg_pct_mac=20 (margin -0.000217094, MIL-F-8785C-3.3.1.1-zeta_d-L1-CatA-COGA), confirmation  NaN at ; the box R(0.7289) is not decided (alpha* in [0, 0.7389]): FC-901: the local stage (Nelder-Mead) did not converge (start 2 exit flag 0 (Exiting: Maximum number of function evaluations has been exceeded - increase MaxFunEvals option. Current function value: 0.000500)) and no counterexample was found
  - lower end (R5-2): R(0) certified 1: only the nominal point (R(0)) is known clean
  - box search alpha 1.045 (optimistic): VIOLATED, value -0.0217001 at h_ft=13000 mach=0.45 cg_pct_mac=20, 481 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - box search alpha 0.7289 (optimistic): NOT_ASSESSABLE, value 0.000492887 at h_ft=13000 mach=0.45 cg_pct_mac=20, 484 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - ray (prior): failing at scaled norm 1.055 (t in [0.9961, 1.0000]), margin -0.00016541 at h_ft=13000 mach=0.45 cg_pct_mac=20
  - ray (optimistic): failing at scaled norm 0.7389 (t in [0.7031, 0.7070]), margin -0.000217094 at h_ft=13000 mach=0.45 cg_pct_mac=20

### 3.3.1.1-CatA-other
Nominal Level 1, margin 1.21845, critical MIL-F-8785C-3.3.1.1-zeta_d-L1-CatA-other at h_ft=13000 mach=0.45 cg_pct_mac=20.
Candidates: h_ft=13000 mach=0.45 cg_pct_mac=20 (1.218); h_ft=13000 mach=0.45 cg_pct_mac=25 (1.231); h_ft=13000 mach=0.45 cg_pct_mac=30 (1.246); h_ft=13000 mach=0.5 cg_pct_mac=20 (1.499).
Search (lateral; margin to the nominal Level (minimized)): all parameters (the margin depends on the whole box); R4-9: lateral group, Cm_q is not searched (held at 1): it acts only through the pitch rate, zero at the wings-level trim, so it cannot change a lateral metric (gated); the R4-9 gate passed (value 1.218451148 unchanged at 2 moved point(s) within 1e-09 relative (largest 1.28e-15)).
Search method: hybrid.
R4-9 gate (Cm_q held at 1) at h_ft=13000 mach=0.45 cg_pct_mac=20: passed (value 1.218451148 unchanged at 2 moved point(s) within 1e-09 relative (largest 1.28e-15)).
Decided by stage 2 (R4-8): the judged CSR bracket [0, 2.76] (NOT_ASSESSABLE) overlaps [0.8, 1.2].
stage-1 result (re-run at the full budget): verdict NOT_ASSESSABLE; 2 candidate condition(s); CSR judged NOT_ASSESSABLE in [0, 2.76]; x1 bound-worst 0.902542 (NOT_ASSESSABLE).

| width | bound-worst | status | label | arg-min theta | condition | record | confirmation | rounds | Mahalanobis D (tail) | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | box verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x1 | 0.902542 | NOT_ASSESSABLE | search estimate (hybrid: differential evolution + Nelder-Mead) | [1 1.152 0.8483 0.6965 0.6965 1.152 1.152] | h_ft=13000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.3.1.1-zeta_d-L1-CatA-other | OK 0.9025 | 1 | 7.43 (4.1e-10, dof 6) | 1, 0 | 485 | 200/200 | 0 | 0 | 0.9851 | NOT_ASSESSABLE |

- x1: FC-901: the local stage (Nelder-Mead) did not converge (start 2 exit flag 0 (Exiting: Maximum number of function evaluations has been exceeded - increase MaxFunEvals option. Current function value: 0.902604)) and no counterexample was found. Verdict reason: bound-worst status NOT_ASSESSABLE (no counterexample) with Clopper-Pearson lower bound 0.9851 >= 0.95.
  - round 1: 4 candidate condition(s) (h_ft=13000 mach=0.45 cg_pct_mac=20; h_ft=13000 mach=0.45 cg_pct_mac=25; h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.5 cg_pct_mac=20); search value 0.902542 at h_ft=13000 mach=0.45 cg_pct_mac=20, theta [1 1.152 0.8483 0.6965 0.6965 1.152 1.152]; confirmation OK 0.902542 at h_ft=13000 mach=0.45 cg_pct_mac=20 (did not move)
  - stages: centre 1 points (converged -); corner 64 points (converged -); lhs 32 points (converged -); de 128 points (converged no); local 260 points (converged no)

Critical Similitude Ratio over Cm_basic, Cm_de, Cl_p, Cn_r, Cl_table, Cnt_table; R4 verdict **NOT_ASSESSABLE**: CSR status NOT_ASSESSABLE (alpha* in [0, 2.76], R(alphaLo) certified 1: only the nominal point (R(0)) is known clean; CPV confirmed 1): neither the judged box R(1) certified nor a confirmed CPV inside it; Clopper-Pearson lower bound 0.9851.
- judged shape (m = [0.1517 0.1517 0.3035 0.3035 0.1517 0.1517]): status NOT_ASSESSABLE, alpha* NaN, bracket [0, 2.76]; parametric safety margin [0 NaN NaN NaN NaN NaN NaN]; CPV [1 1.4188 0.58123 0.16245 0.16245 1.4188 0.58123] at h_ft=13000 mach=0.45 cg_pct_mac=30 (margin -0.00247598, MIL-F-8785C-3.3.1.1-zeta_d_omega_nd_rad_s-L1-CatA-other), confirmation  NaN at ; the box R(2.75) is not decided (alpha* in [0, 2.76]): FC-901: the local stage (Nelder-Mead) did not converge (start 2 exit flag 0 (Exiting: Maximum number of function evaluations has been exceeded - increase MaxFunEvals option. Current function value: 0.013009)) and no counterexample was found
  - lower end (R5-2): R(0) certified 1: only the nominal point (R(0)) is known clean
  - box search alpha 3 (cap): VIOLATED, value -0.304464 at h_ft=13000 mach=0.45 cg_pct_mac=30, 467 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - box search alpha 2.75 (optimistic): NOT_ASSESSABLE, value 0.00959812 at h_ft=13000 mach=0.45 cg_pct_mac=30, 464 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - ray (cap): failing at scaled norm 2.76 (t in [0.9189, 0.9199]), margin -0.00247598 at h_ft=13000 mach=0.45 cg_pct_mac=30
- equal shape (m = [0.1 0.1 0.1 0.1 0.1 0.1]): status NOT_ASSESSABLE, alpha* NaN, bracket [0, Inf]; parametric safety margin [0 NaN NaN NaN NaN NaN NaN]; CPV [1 NaN NaN NaN NaN NaN NaN] at  (margin NaN, ), confirmation  NaN at ; the cap box R(3) is not decided: FC-901: the local stage (Nelder-Mead) did not converge (start 2 exit flag 0 (Exiting: Maximum number of function evaluations has been exceeded - increase MaxFunEvals option. Current function value: 0.790880)) and no counterexample was found
  - lower end (R5-2): R(0) certified 1: only the nominal point (R(0)) is known clean
  - box search alpha 3 (cap): NOT_ASSESSABLE, value 0.790694 at h_ft=13000 mach=0.45 cg_pct_mac=25, 478 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - ray (prior): failing at scaled norm 8.371 (t in [0.9990, 0.9995]), margin -0.000846714 at h_ft=13000 mach=0.45 cg_pct_mac=30

### 3.3.1.1-CatB
Nominal Level 1, margin 4.26882, critical MIL-F-8785C-3.3.1.1-zeta_d-L1-CatB at h_ft=13000 mach=0.45 cg_pct_mac=20.
Candidates: h_ft=13000 mach=0.45 cg_pct_mac=20 (4.269); h_ft=13000 mach=0.45 cg_pct_mac=25 (4.298); h_ft=13000 mach=0.45 cg_pct_mac=30 (4.335); h_ft=13000 mach=0.5 cg_pct_mac=20 (4.935).
Search (lateral; margin to the nominal Level (minimized)): all parameters (the margin depends on the whole box); R4-9: lateral group, Cm_q is not searched (held at 1): it acts only through the pitch rate, zero at the wings-level trim, so it cannot change a lateral metric (gated); the R4-9 gate passed (value 4.268821477 unchanged at 2 moved point(s) within 1e-09 relative (largest 8.32e-16)).
Search method: hybrid.
R4-9 gate (Cm_q held at 1) at h_ft=13000 mach=0.45 cg_pct_mac=20: passed (value 4.268821477 unchanged at 2 moved point(s) within 1e-09 relative (largest 8.32e-16)).
Decided by stage 2 (R4-8): the judged CSR bracket [0, Inf] (NOT_ASSESSABLE) overlaps [0.8, 1.2].
stage-1 result (re-run at the full budget): verdict NOT_ASSESSABLE; 2 candidate condition(s); CSR judged NOT_ASSESSABLE in [0, Inf]; x1 bound-worst 3.51854 (NOT_ASSESSABLE).

| width | bound-worst | status | label | arg-min theta | condition | record | confirmation | rounds | Mahalanobis D (tail) | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | box verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x1 | 3.51854 | NOT_ASSESSABLE | search estimate (hybrid: differential evolution + Nelder-Mead) | [1 1.152 0.8483 0.6965 0.6965 1.152 1.152] | h_ft=13000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.3.1.1-zeta_d-L1-CatB | OK 3.519 | 1 | 7.43 (4.1e-10, dof 6) | 1, 0 | 485 | 200/200 | 0 | 0 | 0.9851 | NOT_ASSESSABLE |

- x1: FC-901: the local stage (Nelder-Mead) did not converge (start 2 exit flag 0 (Exiting: Maximum number of function evaluations has been exceeded - increase MaxFunEvals option. Current function value: 3.518684)) and no counterexample was found. Verdict reason: bound-worst status NOT_ASSESSABLE (no counterexample) with Clopper-Pearson lower bound 0.9851 >= 0.95.
  - round 1: 4 candidate condition(s) (h_ft=13000 mach=0.45 cg_pct_mac=20; h_ft=13000 mach=0.45 cg_pct_mac=25; h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.5 cg_pct_mac=20); search value 3.51854 at h_ft=13000 mach=0.45 cg_pct_mac=20, theta [1 1.152 0.8483 0.6965 0.6965 1.152 1.152]; confirmation OK 3.51854 at h_ft=13000 mach=0.45 cg_pct_mac=20 (did not move)
  - stages: centre 1 points (converged -); corner 64 points (converged -); lhs 32 points (converged -); de 128 points (converged no); local 260 points (converged no)

Critical Similitude Ratio over Cm_basic, Cm_de, Cl_p, Cn_r, Cl_table, Cnt_table; R4 verdict **NOT_ASSESSABLE**: CSR status NOT_ASSESSABLE (alpha* in [0, Inf], R(alphaLo) certified 1: only the nominal point (R(0)) is known clean; CPV confirmed 0): neither the judged box R(1) certified nor a confirmed CPV inside it; Clopper-Pearson lower bound 0.9851.
- judged shape (m = [0.1517 0.1517 0.3035 0.3035 0.1517 0.1517]): status NOT_ASSESSABLE, alpha* NaN, bracket [0, Inf]; parametric safety margin [0 NaN NaN NaN NaN NaN NaN]; CPV [1 NaN NaN NaN NaN NaN NaN] at  (margin NaN, ), confirmation  NaN at ; the cap box R(3) is not decided: FC-901: the local stage (Nelder-Mead) did not converge (start 2 exit flag 0 (Exiting: Maximum number of function evaluations has been exceeded - increase MaxFunEvals option. Current function value: 0.624033)) and no counterexample was found
  - lower end (R5-2): R(0) certified 1: only the nominal point (R(0)) is known clean
  - box search alpha 3 (cap): NOT_ASSESSABLE, value 0.622917 at h_ft=13000 mach=0.45 cg_pct_mac=30, 467 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - box search alpha 1 (decide): NOT_ASSESSABLE, value 3.51854 at h_ft=13000 mach=0.45 cg_pct_mac=20, 485 points (search estimate (hybrid: differential evolution + Nelder-Mead))
- equal shape (m = [0.1 0.1 0.1 0.1 0.1 0.1]): status NOT_ASSESSABLE, alpha* NaN, bracket [0, Inf]; parametric safety margin [0 NaN NaN NaN NaN NaN NaN]; CPV [1 NaN NaN NaN NaN NaN NaN] at  (margin NaN, ), confirmation  NaN at ; the cap box R(3) is not decided: FC-901: the local stage (Nelder-Mead) did not converge (start 2 exit flag 0 (Exiting: Maximum number of function evaluations has been exceeded - increase MaxFunEvals option. Current function value: 3.253340)) and no counterexample was found
  - lower end (R5-2): R(0) certified 1: only the nominal point (R(0)) is known clean
  - box search alpha 3 (cap): NOT_ASSESSABLE, value 3.2529 at h_ft=13000 mach=0.45 cg_pct_mac=25, 478 points (search estimate (hybrid: differential evolution + Nelder-Mead))

### 3.3.1.2-CatA
Nominal Level 1, margin 0.539424, critical MIL-F-8785C-3.3.1.2-tau_R_s-L1-CatA at h_ft=13000 mach=0.45 cg_pct_mac=20.
Candidates: h_ft=13000 mach=0.45 cg_pct_mac=20 (0.5394); h_ft=13000 mach=0.45 cg_pct_mac=25 (0.5408); h_ft=13000 mach=0.45 cg_pct_mac=30 (0.542); h_ft=13000 mach=0.5 cg_pct_mac=20 (0.593).
Search (lateral; margin to the nominal Level (minimized)): all parameters (the margin depends on the whole box); R4-9: lateral group, Cm_q is not searched (held at 1): it acts only through the pitch rate, zero at the wings-level trim, so it cannot change a lateral metric (gated); the R4-9 gate passed (value 0.5394242882 unchanged at 2 moved point(s) within 1e-09 relative (largest 1.03e-15)).
Search method: hybrid.
R4-9 gate (Cm_q held at 1) at h_ft=13000 mach=0.45 cg_pct_mac=20: passed (value 0.5394242882 unchanged at 2 moved point(s) within 1e-09 relative (largest 1.03e-15)).
Decided by stage 2 (R4-8): the judged CSR bracket [0, 1.836] (NOT_ASSESSABLE) overlaps [0.8, 1.2].
stage-1 result (re-run at the full budget): verdict NOT_ASSESSABLE; 2 candidate condition(s); CSR judged NOT_ASSESSABLE in [0, 1.836]; x1 bound-worst 0.347404 (NOT_ASSESSABLE).

| width | bound-worst | status | label | arg-min theta | condition | record | confirmation | rounds | Mahalanobis D (tail) | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | box verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x1 | 0.347404 | NOT_ASSESSABLE | search estimate (hybrid: differential evolution + Nelder-Mead) | [1 1.152 0.8483 0.6965 0.6965 0.8483 1.152] | h_ft=13000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.3.1.2-tau_R_s-L1-CatA | OK 0.3474 | 1 | 7.43 (4.1e-10, dof 6) | 1, 0 | 480 | 200/200 | 0 | 0 | 0.9851 | NOT_ASSESSABLE |

- x1: FC-901: the local stage (Nelder-Mead) did not converge (start 2 exit flag 0 (budget of 150 evaluations exhausted)) and no counterexample was found. Verdict reason: bound-worst status NOT_ASSESSABLE (no counterexample) with Clopper-Pearson lower bound 0.9851 >= 0.95.
  - round 1: 4 candidate condition(s) (h_ft=13000 mach=0.45 cg_pct_mac=20; h_ft=13000 mach=0.45 cg_pct_mac=25; h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.5 cg_pct_mac=20); search value 0.347404 at h_ft=13000 mach=0.45 cg_pct_mac=20, theta [1 1.152 0.8483 0.6965 0.6965 0.8483 1.152]; confirmation OK 0.347404 at h_ft=13000 mach=0.45 cg_pct_mac=20 (did not move)
  - stages: centre 1 points (converged -); corner 64 points (converged -); lhs 32 points (converged -); de 128 points (converged no); local 255 points (converged no)

Critical Similitude Ratio over Cm_basic, Cm_de, Cl_p, Cn_r, Cl_table, Cnt_table; R4 verdict **NOT_ASSESSABLE**: CSR status NOT_ASSESSABLE (alpha* in [0, 1.837], R(alphaLo) certified 1: only the nominal point (R(0)) is known clean; CPV confirmed 1): neither the judged box R(1) certified nor a confirmed CPV inside it; Clopper-Pearson lower bound 0.9851.
- judged shape (m = [0.1517 0.1517 0.3035 0.3035 0.1517 0.1517]): status NOT_ASSESSABLE, alpha* NaN, bracket [0, 1.837]; parametric safety margin [0 NaN NaN NaN NaN NaN NaN]; CPV [1 1.2787 0.72131 0.44261 0.44261 0.72131 1.2787] at h_ft=13000 mach=0.45 cg_pct_mac=20 (margin -0.00202674, MIL-F-8785C-3.3.1.2-tau_R_s-L1-CatA), confirmation  NaN at ; the box R(1.827) is not decided (alpha* in [0, 1.837]): FC-901: the local stage (Nelder-Mead) did not converge (start 2 exit flag 0 (Exiting: Maximum number of function evaluations has been exceeded - increase MaxFunEvals option. Current function value: 0.004262)) and no counterexample was found
  - lower end (R5-2): R(0) certified 1: only the nominal point (R(0)) is known clean
  - box search alpha 3 (cap): VIOLATED, value -2.39447 at h_ft=13000 mach=0.5 cg_pct_mac=30, 225 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - box search alpha 1.919 (optimistic): VIOLATED, value -0.0562581 at h_ft=13000 mach=0.45 cg_pct_mac=20, 467 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - box search alpha 1.827 (optimistic): NOT_ASSESSABLE, value 0.00420649 at h_ft=13000 mach=0.45 cg_pct_mac=20, 472 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - ray (cap): failing at scaled norm 1.929 (t in [0.6846, 0.6855]), margin -0.000238196 at h_ft=13000 mach=0.45 cg_pct_mac=20
  - ray (optimistic): failing at scaled norm 1.837 (t in [0.9551, 0.9570]), margin -0.00202674 at h_ft=13000 mach=0.45 cg_pct_mac=20
- equal shape (m = [0.1 0.1 0.1 0.1 0.1 0.1]): status NOT_ASSESSABLE, alpha* NaN, bracket [0, Inf]; parametric safety margin [0 NaN NaN NaN NaN NaN NaN]; CPV [1 NaN NaN NaN NaN NaN NaN] at  (margin NaN, ), confirmation  NaN at ; the cap box R(3) is not decided: FC-901: the local stage (Nelder-Mead) did not converge (start 2 exit flag 0 (budget of 150 evaluations exhausted)) and no counterexample was found
  - lower end (R5-2): R(0) certified 1: only the nominal point (R(0)) is known clean
  - box search alpha 3 (cap): NOT_ASSESSABLE, value 0.325462 at h_ft=13000 mach=0.45 cg_pct_mac=20, 466 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - ray (prior): failing at scaled norm 5.566 (t in [0.9980, 0.9985]), margin -0.000342776 at h_ft=13000 mach=0.45 cg_pct_mac=20

### 3.3.1.2-CatB
Nominal Level 1, margin 0.671017, critical MIL-F-8785C-3.3.1.2-tau_R_s-L1-CatB at h_ft=13000 mach=0.45 cg_pct_mac=20.
Candidates: h_ft=13000 mach=0.45 cg_pct_mac=20 (0.671); h_ft=13000 mach=0.45 cg_pct_mac=25 (0.672); h_ft=13000 mach=0.45 cg_pct_mac=30 (0.6729); h_ft=13000 mach=0.5 cg_pct_mac=20 (0.7093).
Search (lateral; margin to the nominal Level (minimized)): all parameters (the margin depends on the whole box); R4-9: lateral group, Cm_q is not searched (held at 1): it acts only through the pitch rate, zero at the wings-level trim, so it cannot change a lateral metric (gated); the R4-9 gate passed (value 0.6710173487 unchanged at 2 moved point(s) within 1e-09 relative (largest 6.62e-16)).
Search method: hybrid.
R4-9 gate (Cm_q held at 1) at h_ft=13000 mach=0.45 cg_pct_mac=20: passed (value 0.6710173487 unchanged at 2 moved point(s) within 1e-09 relative (largest 6.62e-16)).
Decided by stage 2 (R4-8): the judged CSR bracket [0, 2.312] (NOT_ASSESSABLE) overlaps [0.8, 1.2].
stage-1 result (re-run at the full budget): verdict NOT_ASSESSABLE; 2 candidate condition(s); CSR judged NOT_ASSESSABLE in [0, 2.312]; x1 bound-worst 0.53386 (NOT_ASSESSABLE).

| width | bound-worst | status | label | arg-min theta | condition | record | confirmation | rounds | Mahalanobis D (tail) | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | box verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x1 | 0.53386 | NOT_ASSESSABLE | search estimate (hybrid: differential evolution + Nelder-Mead) | [1 1.152 0.8483 0.6965 0.6965 0.8483 1.152] | h_ft=13000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.3.1.2-tau_R_s-L1-CatB | OK 0.5339 | 1 | 7.43 (4.1e-10, dof 6) | 1, 0 | 480 | 200/200 | 0 | 0 | 0.9851 | NOT_ASSESSABLE |

- x1: FC-901: the local stage (Nelder-Mead) did not converge (start 2 exit flag 0 (budget of 150 evaluations exhausted)) and no counterexample was found. Verdict reason: bound-worst status NOT_ASSESSABLE (no counterexample) with Clopper-Pearson lower bound 0.9851 >= 0.95.
  - round 1: 4 candidate condition(s) (h_ft=13000 mach=0.45 cg_pct_mac=20; h_ft=13000 mach=0.45 cg_pct_mac=25; h_ft=13000 mach=0.45 cg_pct_mac=30; h_ft=13000 mach=0.5 cg_pct_mac=20); search value 0.53386 at h_ft=13000 mach=0.45 cg_pct_mac=20, theta [1 1.152 0.8483 0.6965 0.6965 0.8483 1.152]; confirmation OK 0.53386 at h_ft=13000 mach=0.45 cg_pct_mac=20 (did not move)
  - stages: centre 1 points (converged -); corner 64 points (converged -); lhs 32 points (converged -); de 128 points (converged no); local 255 points (converged no)

Critical Similitude Ratio over Cm_basic, Cm_de, Cl_p, Cn_r, Cl_table, Cnt_table; R4 verdict **NOT_ASSESSABLE**: CSR status NOT_ASSESSABLE (alpha* in [0, 2.27], R(alphaLo) certified 1: only the nominal point (R(0)) is known clean; CPV confirmed 1): neither the judged box R(1) certified nor a confirmed CPV inside it; Clopper-Pearson lower bound 0.9851.
- judged shape (m = [0.1517 0.1517 0.3035 0.3035 0.1517 0.1517]): status NOT_ASSESSABLE, alpha* NaN, bracket [0, 2.27]; parametric safety margin [0 NaN NaN NaN NaN NaN NaN]; CPV [1 0.96849 0.7217 0.31094 1.4075 0.9103 0.70075] at h_ft=13000 mach=0.5 cg_pct_mac=30 (margin -0.0157318, MIL-F-8785C-3.3.1.2-tau_R_s-L1-CatB), confirmation  NaN at ; the box R(1.135) is not decided (alpha* in [0, 2.27]): FC-901: the local stage (Nelder-Mead) did not converge (start 2 exit flag 0 (budget of 150 evaluations exhausted)) and no counterexample was found
  - lower end (R5-2): R(0) certified 1: only the nominal point (R(0)) is known clean
  - box search alpha 3 (cap): VIOLATED, value -1.42462 at h_ft=13000 mach=0.5 cg_pct_mac=30, 225 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - box search alpha 2.348 (optimistic): VIOLATED, value -0.313584 at h_ft=13000 mach=0.5 cg_pct_mac=30, 525 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - box search alpha 2.283 (optimistic): VIOLATED, value -0.126561 at h_ft=13000 mach=0.5 cg_pct_mac=30, 455 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - box search alpha 1.135 (bisection): NOT_ASSESSABLE, value 0.505782 at h_ft=13000 mach=0.45 cg_pct_mac=20, 468 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - ray (cap): failing at scaled norm 2.358 (t in [0.8369, 0.8379]), margin -0.00106023 at h_ft=13000 mach=0.45 cg_pct_mac=30
  - ray (optimistic): failing at scaled norm 2.293 (t in [0.9746, 0.9766]), margin -0.00123203 at h_ft=13000 mach=0.5 cg_pct_mac=30
  - ray (optimistic): failing at scaled norm 2.27 (t in [0.9941, 0.9961]), margin -0.0157318 at h_ft=13000 mach=0.5 cg_pct_mac=30
- equal shape (m = [0.1 0.1 0.1 0.1 0.1 0.1]): status NOT_ASSESSABLE, alpha* NaN, bracket [0, Inf]; parametric safety margin [0 NaN NaN NaN NaN NaN NaN]; CPV [1 NaN NaN NaN NaN NaN NaN] at  (margin NaN, ), confirmation  NaN at ; the cap box R(3) is not decided: FC-901: the local stage (Nelder-Mead) did not converge (start 2 exit flag 0 (budget of 150 evaluations exhausted)) and no counterexample was found
  - lower end (R5-2): R(0) certified 1: only the nominal point (R(0)) is known clean
  - box search alpha 3 (cap): NOT_ASSESSABLE, value 0.518187 at h_ft=13000 mach=0.45 cg_pct_mac=20, 466 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - ray (prior): failing at scaled norm 6.891 (t in [0.0000, 1.0000]), margin -0.0157318 at 

### 3.3.1.3-CatA
Nominal Level 1, margin Inf, critical MIL-F-8785C-3.3.1.3-spiral_T2_s-L1-CatA at h_ft=5000 mach=0.55 cg_pct_mac=20.
Candidates: h_ft=5000 mach=0.55 cg_pct_mac=20 (margin Inf, spiral Re -0.04412 1/s); h_ft=13000 mach=0.63 cg_pct_mac=20 (margin Inf, spiral Re -0.0448 1/s); h_ft=8000 mach=0.55 cg_pct_mac=20 (margin Inf, spiral Re -0.04856 1/s); h_ft=5000 mach=0.55 cg_pct_mac=25 (margin Inf, spiral Re -0.05044 1/s).
Search (surrogate; spiral root real part (1/s), maximized): the nominal margin is +Inf (a stable spiral: T2 infinite), which an optimizer cannot move; the box is searched on the smooth surrogate Re(spiral root) (maximized) over all parameters, and the candidate conditions are ranked by it; R4-9: lateral group, Cm_q is not searched (held at 1): it acts only through the pitch rate, zero at the wings-level trim, so it cannot change a lateral metric (gated); the R4-9 gate passed (value -0.04412244592 unchanged at 2 moved point(s) within 1e-09 relative (largest 2.2e-15)).
Search method: hybrid.
R4-9 gate (Cm_q held at 1) at h_ft=5000 mach=0.55 cg_pct_mac=20: passed (value -0.04412244592 unchanged at 2 moved point(s) within 1e-09 relative (largest 2.2e-15)).
Decided by stage 2 (R4-8): the judged CSR bracket [0, 1.808] (NOT_ASSESSABLE) overlaps [0.8, 1.2].
stage-1 result (re-run at the full budget): verdict NOT_ASSESSABLE; 2 candidate condition(s); CSR judged NOT_ASSESSABLE in [0, 1.808]; x1 bound-worst Inf (NOT_ASSESSABLE).

| width | bound-worst | status | label | arg-min theta | condition | record | confirmation | rounds | Mahalanobis D (tail) | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | box verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x1 | Inf | NOT_ASSESSABLE | search estimate (hybrid: differential evolution + Nelder-Mead) | [1 0.8483 1.152 1.303 0.6965 0.8483 1.152] | h_ft=5000 mach=0.55 cg_pct_mac=20 |  | OK 0.0003457 | 1 | 7.43 (4.1e-10, dof 6) | 1, 0 | 466 | 200/200 | 0 | 0 | 0.9851 | NOT_ASSESSABLE |

- x1: surrogate search on -spiral root real part (1/s) (its margins and reserve are in those terms): FC-901: the local stage (Nelder-Mead) did not converge (start 2 exit flag 0 (budget of 150 evaluations exhausted)) and no counterexample was found; the largest spiral root real part (1/s) found is -0.000345723 <= 0 at h_ft=5000 mach=0.55 cg_pct_mac=20, theta [0.848257 1.15174 1.30349 0.696515 0.848257 1.15174]. Verdict reason: bound-worst status NOT_ASSESSABLE (no counterexample) with Clopper-Pearson lower bound 0.9851 >= 0.95.
  - surrogate: largest spiral root real part (1/s) found -0.000345723 (surrogate search NOT_ASSESSABLE).
  - round 1: 4 candidate condition(s) (h_ft=5000 mach=0.55 cg_pct_mac=20; h_ft=13000 mach=0.63 cg_pct_mac=20; h_ft=8000 mach=0.55 cg_pct_mac=20; h_ft=5000 mach=0.55 cg_pct_mac=25); surrogate search value (-spiral root real part (1/s)) 0.000345723 at h_ft=5000 mach=0.55 cg_pct_mac=20, theta [1 0.8483 1.152 1.303 0.6965 0.8483 1.152]; confirmation OK 0.000345723 at h_ft=5000 mach=0.55 cg_pct_mac=20 (did not move)
  - stages: centre 1 points (converged -); corner 64 points (converged -); lhs 32 points (converged -); de 128 points (converged no); local 241 points (converged no)

Critical Similitude Ratio over Cm_basic, Cm_de, Cl_p, Cn_r, Cl_table, Cnt_table; R4 verdict **NOT_ASSESSABLE**: CSR status NOT_ASSESSABLE (alpha* in [0, 1.808], R(alphaLo) certified 1: only the nominal point (R(0)) is known clean; CPV confirmed 1): neither the judged box R(1) certified nor a confirmed CPV inside it; Clopper-Pearson lower bound 0.9851.
- judged shape (m = [0.1517 0.1517 0.3035 0.3035 0.1517 0.1517]): status NOT_ASSESSABLE, alpha* NaN, bracket [0, 1.808]; parametric safety margin [0 NaN NaN NaN NaN NaN NaN]; CPV [1 0.72571 1.2743 0.45141 0.45141 0.72571 1.2743] at h_ft=5000 mach=0.55 cg_pct_mac=20 (margin -0.00275092, MIL-F-8785C-3.3.1.3-spiral_T2_s-L1-CatA), confirmation  NaN at ; the box R(1.798) is not decided (alpha* in [0, 1.808]): the largest spiral root real part (1/s) found is 0.0568796 > 0 at h_ft=5000 mach=0.55 cg_pct_mac=20, theta [0.727225 1.27278 0.454449 0.454449 0.727225 1.27278]: margin there 0.0155186 (MIL-F-8785C-3.3.1.3-spiral_T2_s-L1-CatA), the bound-worst (the margin decreases as the surrogate grows); surrogate search on -spiral root real part (1/s) (its margins and reserve are in those terms): FC-901: the local stage (Nelder-Mead) did not converge (start 2 exit flag 0 (Exiting: Maximum number of function evaluations has been exceeded - increase MaxFunEvals option. Current function value: -0.056879)) and no counterexample was found
  - lower end (R5-2): R(0) certified 1: only the nominal point (R(0)) is known clean
  - box search alpha 3 (cap): VIOLATED, value -0.839306 at h_ft=5000 mach=0.55 cg_pct_mac=20, 481 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - box search alpha 1.798 (optimistic): NOT_ASSESSABLE, value 0.0155186 at h_ft=5000 mach=0.55 cg_pct_mac=20, 478 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - ray (cap): failing at scaled norm 1.808 (t in [0.6016, 0.6025]), margin -0.00275092 at h_ft=5000 mach=0.55 cg_pct_mac=20
- equal shape (m = [0.1 0.1 0.1 0.1 0.1 0.1]): status NOT_ASSESSABLE, alpha* NaN, bracket [0, Inf]; parametric safety margin [0 NaN NaN NaN NaN NaN NaN]; CPV [1 NaN NaN NaN NaN NaN NaN] at  (margin NaN, ), confirmation  NaN at ; the cap box R(3) is not decided: the largest spiral root real part (1/s) found is 0.0415687 > 0 at h_ft=5000 mach=0.55 cg_pct_mac=20, theta [0.7 1.3 0.7 0.7 0.7 1.3]: margin there 0.38956 (MIL-F-8785C-3.3.1.3-spiral_T2_s-L1-CatA), the bound-worst (the margin decreases as the surrogate grows); surrogate search on -spiral root real part (1/s) (its margins and reserve are in those terms): FC-901: the local stage (Nelder-Mead) did not converge (start 2 exit flag 0 (Exiting: Maximum number of function evaluations has been exceeded - increase MaxFunEvals option. Current function value: -0.041562)) and no counterexample was found
  - lower end (R5-2): R(0) certified 1: only the nominal point (R(0)) is known clean
  - box search alpha 3 (cap): NOT_ASSESSABLE, value 0.38956 at h_ft=5000 mach=0.55 cg_pct_mac=20, 482 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - ray (prior): failing at scaled norm 5.483 (t in [0.9990, 0.9995]), margin -0.00115722 at h_ft=5000 mach=0.55 cg_pct_mac=20

### 3.3.1.3-CatB
Nominal Level 1, margin Inf, critical MIL-F-8785C-3.3.1.3-spiral_T2_s-L1-CatB at h_ft=5000 mach=0.55 cg_pct_mac=20.
Candidates: h_ft=5000 mach=0.55 cg_pct_mac=20 (margin Inf, spiral Re -0.04412 1/s); h_ft=13000 mach=0.63 cg_pct_mac=20 (margin Inf, spiral Re -0.0448 1/s); h_ft=8000 mach=0.55 cg_pct_mac=20 (margin Inf, spiral Re -0.04856 1/s); h_ft=5000 mach=0.55 cg_pct_mac=25 (margin Inf, spiral Re -0.05044 1/s).
Search (surrogate; spiral root real part (1/s), maximized): the nominal margin is +Inf (a stable spiral: T2 infinite), which an optimizer cannot move; the box is searched on the smooth surrogate Re(spiral root) (maximized) over all parameters, and the candidate conditions are ranked by it; R4-9: lateral group, Cm_q is not searched (held at 1): it acts only through the pitch rate, zero at the wings-level trim, so it cannot change a lateral metric (gated); the R4-9 gate passed (value -0.04412244592 unchanged at 2 moved point(s) within 1e-09 relative (largest 2.2e-15)).
Search method: hybrid.
R4-9 gate (Cm_q held at 1) at h_ft=5000 mach=0.55 cg_pct_mac=20: passed (value -0.04412244592 unchanged at 2 moved point(s) within 1e-09 relative (largest 2.2e-15)).
Decided by stage 2 (R4-8): the judged CSR bracket [0, 1.559] (NOT_ASSESSABLE) overlaps [0.8, 1.2].
stage-1 result (re-run at the full budget): verdict NOT_ASSESSABLE; 2 candidate condition(s); CSR judged NOT_ASSESSABLE in [0, 1.559]; x1 bound-worst Inf (NOT_ASSESSABLE).

| width | bound-worst | status | label | arg-min theta | condition | record | confirmation | rounds | Mahalanobis D (tail) | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | box verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x1 | Inf | NOT_ASSESSABLE | search estimate (hybrid: differential evolution + Nelder-Mead) | [1 0.8483 1.152 1.303 0.6965 0.8483 1.152] | h_ft=5000 mach=0.55 cg_pct_mac=20 |  | OK 0.0003457 | 1 | 7.43 (4.1e-10, dof 6) | 1, 0 | 466 | 200/200 | 0 | 0 | 0.9851 | NOT_ASSESSABLE |

- x1: surrogate search on -spiral root real part (1/s) (its margins and reserve are in those terms): FC-901: the local stage (Nelder-Mead) did not converge (start 2 exit flag 0 (budget of 150 evaluations exhausted)) and no counterexample was found; the largest spiral root real part (1/s) found is -0.000345723 <= 0 at h_ft=5000 mach=0.55 cg_pct_mac=20, theta [0.848257 1.15174 1.30349 0.696515 0.848257 1.15174]. Verdict reason: bound-worst status NOT_ASSESSABLE (no counterexample) with Clopper-Pearson lower bound 0.9851 >= 0.95.
  - surrogate: largest spiral root real part (1/s) found -0.000345723 (surrogate search NOT_ASSESSABLE).
  - round 1: 4 candidate condition(s) (h_ft=5000 mach=0.55 cg_pct_mac=20; h_ft=13000 mach=0.63 cg_pct_mac=20; h_ft=8000 mach=0.55 cg_pct_mac=20; h_ft=5000 mach=0.55 cg_pct_mac=25); surrogate search value (-spiral root real part (1/s)) 0.000345723 at h_ft=5000 mach=0.55 cg_pct_mac=20, theta [1 0.8483 1.152 1.303 0.6965 0.8483 1.152]; confirmation OK 0.000345723 at h_ft=5000 mach=0.55 cg_pct_mac=20 (did not move)
  - stages: centre 1 points (converged -); corner 64 points (converged -); lhs 32 points (converged -); de 128 points (converged no); local 241 points (converged no)

Critical Similitude Ratio over Cm_basic, Cm_de, Cl_p, Cn_r, Cl_table, Cnt_table; R4 verdict **NOT_ASSESSABLE**: CSR status NOT_ASSESSABLE (alpha* in [0, 1.559], R(alphaLo) certified 1: only the nominal point (R(0)) is known clean; CPV confirmed 1): neither the judged box R(1) certified nor a confirmed CPV inside it; Clopper-Pearson lower bound 0.9851.
- judged shape (m = [0.1517 0.1517 0.3035 0.3035 0.1517 0.1517]): status NOT_ASSESSABLE, alpha* NaN, bracket [0, 1.559]; parametric safety margin [0 NaN NaN NaN NaN NaN NaN]; CPV [1 0.76349 1.2365 0.52699 0.52699 0.76349 1.2365] at h_ft=5000 mach=0.55 cg_pct_mac=20 (margin -0.0057901, MIL-F-8785C-3.3.1.3-spiral_T2_s-L1-CatB), confirmation  NaN at ; the box R(1.549) is not decided (alpha* in [0, 1.559]): the largest spiral root real part (1/s) found is 0.0340431 > 0 at h_ft=5000 mach=0.55 cg_pct_mac=20, theta [0.765012 1.23499 0.530024 0.530024 0.765012 1.23499]: margin there 0.0180431 (MIL-F-8785C-3.3.1.3-spiral_T2_s-L1-CatB), the bound-worst (the margin decreases as the surrogate grows); surrogate search on -spiral root real part (1/s) (its margins and reserve are in those terms): FC-901: the local stage (Nelder-Mead) did not converge (start 2 exit flag 0 (budget of 150 evaluations exhausted)) and no counterexample was found
  - lower end (R5-2): R(0) certified 1: only the nominal point (R(0)) is known clean
  - box search alpha 3 (cap): VIOLATED, value -0.903584 at h_ft=5000 mach=0.55 cg_pct_mac=20, 481 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - box search alpha 1.549 (optimistic): NOT_ASSESSABLE, value 0.0180431 at h_ft=5000 mach=0.55 cg_pct_mac=20, 464 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - ray (cap): failing at scaled norm 1.559 (t in [0.5186, 0.5195]), margin -0.0057901 at h_ft=5000 mach=0.55 cg_pct_mac=20
- equal shape (m = [0.1 0.1 0.1 0.1 0.1 0.1]): status NOT_ASSESSABLE, alpha* NaN, bracket [0, 2.792]; parametric safety margin [0 NaN NaN NaN NaN NaN NaN]; CPV [1 0.7208 1.2792 0.7208 0.7208 0.7208 1.2792] at h_ft=5000 mach=0.55 cg_pct_mac=20 (margin -0.000157459, MIL-F-8785C-3.3.1.3-spiral_T2_s-L1-CatB), confirmation  NaN at ; the box R(2.782) is not decided (alpha* in [0, 2.792]): the largest spiral root real part (1/s) found is 0.0343364 > 0 at h_ft=5000 mach=0.55 cg_pct_mac=20, theta [0.721801 1.2782 0.721801 0.721801 0.721801 1.2782]: margin there 0.00934767 (MIL-F-8785C-3.3.1.3-spiral_T2_s-L1-CatB), the bound-worst (the margin decreases as the surrogate grows); surrogate search on -spiral root real part (1/s) (its margins and reserve are in those terms): FC-901: the local stage (Nelder-Mead) did not converge (start 2 exit flag 0 (budget of 150 evaluations exhausted)) and no counterexample was found
  - lower end (R5-2): R(0) certified 1: only the nominal point (R(0)) is known clean
  - box search alpha 3 (cap): VIOLATED, value -0.166264 at h_ft=5000 mach=0.55 cg_pct_mac=20, 482 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - box search alpha 2.782 (optimistic): NOT_ASSESSABLE, value 0.00934767 at h_ft=5000 mach=0.55 cg_pct_mac=20, 484 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - ray (prior): failing at scaled norm 4.725 (t in [0.9980, 0.9990]), margin -0.00222105 at h_ft=5000 mach=0.55 cg_pct_mac=20
  - ray (cap): failing at scaled norm 2.792 (t in [0.9297, 0.9307]), margin -0.000157459 at h_ft=5000 mach=0.55 cg_pct_mac=20

### 3.3.1.4-CatA-COGA
Nominal Level 1, margin 0, critical MIL-F-8785C-3.3.1.4-coupled_roll_spiral_present-L1-CatA-COGA at h_ft=5000 mach=0.45 cg_pct_mac=20.
Candidates: h_ft=5000 mach=0.45 cg_pct_mac=20 (0); h_ft=8000 mach=0.45 cg_pct_mac=20 (0).
Search (lateral; margin to the nominal Level (minimized)): all parameters (the margin depends on the whole box); R4-9: lateral group, Cm_q is not searched (held at 1): it acts only through the pitch rate, zero at the wings-level trim, so it cannot change a lateral metric (gated); the R4-9 gate passed (value 0 unchanged at 2 moved point(s) within 1e-09 relative (largest 0)).
**Sampled only:** binary metric (coupled_roll_spiral_present, 0/1): the margin is flat or jumps, so the optimizer's convergence means nothing; the bound-worst rests on the sampled points only.
Search method: hybrid.
R4-9 gate (Cm_q held at 1) at h_ft=5000 mach=0.45 cg_pct_mac=20: passed (value 0 unchanged at 2 moved point(s) within 1e-09 relative (largest 0)).
Decided by stage 1 (R4-8): the judged CSR bracket [2.153, 2.163] (OK) does not overlap [0.8, 1.2] and is not NOT_ASSESSABLE for budget reasons.

| width | bound-worst | status | label | arg-min theta | condition | record | confirmation | rounds | Mahalanobis D (tail) | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | box verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x1 | 0 | OK | search estimate (hybrid: differential evolution + Nelder-Mead) | [1 1 1 1 1 1 1] | h_ft=5000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.3.1.4-coupled_roll_spiral_present-L1-CatA-COGA | OK 0 | 1 | 0 (1, dof 6) | 1, 1 | 199 | 200/200 | 0 | 0 | 0.9851 | ROBUST |

- x1: every evaluated point OK (199), every Nelder-Mead start of the local stage converged; bound-worst 0 >= reserve 0; 1 round(s), the final confirmation did not move. Verdict reason: bound-worst margin 0 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
  - round 1: 2 candidate condition(s) (h_ft=5000 mach=0.45 cg_pct_mac=20; h_ft=8000 mach=0.45 cg_pct_mac=20); search value 0 at h_ft=5000 mach=0.45 cg_pct_mac=20, theta [1 1 1 1 1 1 1]; confirmation OK 0 at h_ft=5000 mach=0.45 cg_pct_mac=20 (did not move)
  - stages: centre 1 points (converged -); corner 64 points (converged -); lhs 32 points (converged -); de 32 points (converged no); local 70 points (converged yes)

Critical Similitude Ratio over Cm_basic, Cm_de, Cl_p, Cn_r, Cl_table, Cnt_table; R4 verdict **ROBUST**: the judged box R(1) is certified: alphaLo = 2.153 >= 1 (alpha* in [2.153, 2.163], CSR OK; the box R(2.153) was searched clean over the final candidates) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- judged shape (m = [0.1517 0.1517 0.3035 0.3035 0.1517 0.1517]): status OK, alpha* 2.153, bracket [2.153, 2.163]; parametric safety margin [0 0.3267 0.3267 0.6534 0.6534 0.3267 0.3267]; CPV [1 0.67179 1.3282 0.34357 1.6564 1.3282 0.67179] at h_ft=5000 mach=0.45 cg_pct_mac=20 (margin -1, MIL-F-8785C-3.3.1.4-coupled_roll_spiral_present-L1-CatA-COGA), confirmation OK -1 at h_ft=5000 mach=0.45 cg_pct_mac=20; alpha* in [2.153, 2.163] (resolution 0.01): the box R(2.153) was searched clean and the CPV at scaled norm 2.163 fails (margin -1 at h_ft=5000 mach=0.45 cg_pct_mac=20, MIL-F-8785C-3.3.1.4-coupled_roll_spiral_present-L1-CatA-COGA), confirmed by a fresh assessment
  - lower end (R5-2): R(2.153) certified 1: the box R(2.153) was searched clean over the final candidates
  - box search alpha 3 (cap): VIOLATED, value -1 at h_ft=5000 mach=0.45 cg_pct_mac=20, 207 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - box search alpha 2.838 (optimistic): VIOLATED, value -1 at h_ft=5000 mach=0.45 cg_pct_mac=20, 223 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - box search alpha 2.589 (optimistic): VIOLATED, value -1 at h_ft=8000 mach=0.45 cg_pct_mac=20, 223 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - box search alpha 1.787 (bisection): OK, value 0 at h_ft=5000 mach=0.45 cg_pct_mac=20, 199 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - box search alpha 2.564 (optimistic): VIOLATED, value -1 at h_ft=5000 mach=0.45 cg_pct_mac=20, 223 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - box search alpha 2.334 (optimistic): VIOLATED, value -1 at h_ft=5000 mach=0.45 cg_pct_mac=20, 223 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - box search alpha 2.022 (bisection): OK, value 0 at h_ft=5000 mach=0.45 cg_pct_mac=20, 199 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - box search alpha 2.246 (optimistic): VIOLATED, value -1 at h_ft=5000 mach=0.45 cg_pct_mac=20, 223 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - box search alpha 2.153 (optimistic): OK, value 0 at h_ft=5000 mach=0.45 cg_pct_mac=20, 199 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - ray (cap): failing at scaled norm 2.848 (t in [0.9482, 0.9492]), margin -1 at h_ft=8000 mach=0.45 cg_pct_mac=20
  - ray (optimistic): failing at scaled norm 2.599 (t in [0.9150, 0.9160]), margin -1 at h_ft=8000 mach=0.45 cg_pct_mac=20
  - ray (optimistic): failing at scaled norm 2.574 (t in [0.9932, 0.9941]), margin -1 at h_ft=8000 mach=0.45 cg_pct_mac=20
  - ray (optimistic): failing at scaled norm 2.344 (t in [0.9131, 0.9141]), margin -1 at h_ft=5000 mach=0.45 cg_pct_mac=20
  - ray (optimistic): failing at scaled norm 2.256 (t in [0.9648, 0.9668]), margin -1 at h_ft=5000 mach=0.45 cg_pct_mac=20
  - ray (optimistic): failing at scaled norm 2.163 (t in [0.9609, 0.9629]), margin -1 at h_ft=5000 mach=0.45 cg_pct_mac=20
- equal shape (m = [0.1 0.1 0.1 0.1 0.1 0.1]): status ROBUST_TO_CAP, alpha* 3, bracket [3, Inf]; parametric safety margin [0 0.3 0.3 0.3 0.3 0.3 0.3]; CPV [1 NaN NaN NaN NaN NaN NaN] at  (margin NaN, ), confirmation  NaN at ; a box searched clean contains the cap box R(3): no failure up to AlphaMax
  - lower end (R5-2): R(3) certified 1: the cap box R(3) is clean (a box searched clean contains the cap box R(3): no failure up to AlphaMax)
  - ray (prior): failing at scaled norm 6.555 (t in [0.9980, 0.9985]), margin -1 at h_ft=5000 mach=0.45 cg_pct_mac=20

### 3.3.1.4-CatA-other
Nominal Level 1, margin 0, critical MIL-F-8785C-3.3.1.4-coupled_roll_spiral_present-L1-CatA-other at h_ft=5000 mach=0.45 cg_pct_mac=20.
Candidates: h_ft=5000 mach=0.45 cg_pct_mac=20 (0); h_ft=8000 mach=0.45 cg_pct_mac=20 (0).
Search (lateral; margin to the nominal Level (minimized)): all parameters (the margin depends on the whole box); R4-9: lateral group, Cm_q is not searched (held at 1): it acts only through the pitch rate, zero at the wings-level trim, so it cannot change a lateral metric (gated); the R4-9 gate passed (value 0 unchanged at 2 moved point(s) within 1e-09 relative (largest 0)).
**Sampled only:** binary metric (coupled_roll_spiral_present, 0/1): the margin is flat or jumps, so the optimizer's convergence means nothing; the bound-worst rests on the sampled points only.
Search method: hybrid.
R4-9 gate (Cm_q held at 1) at h_ft=5000 mach=0.45 cg_pct_mac=20: passed (value 0 unchanged at 2 moved point(s) within 1e-09 relative (largest 0)).
Decided by stage 1 (R4-8): the judged CSR bracket [2.153, 2.163] (OK) does not overlap [0.8, 1.2] and is not NOT_ASSESSABLE for budget reasons.

| width | bound-worst | status | label | arg-min theta | condition | record | confirmation | rounds | Mahalanobis D (tail) | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | box verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x1 | 0 | OK | search estimate (hybrid: differential evolution + Nelder-Mead) | [1 1 1 1 1 1 1] | h_ft=5000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.3.1.4-coupled_roll_spiral_present-L1-CatA-other | OK 0 | 1 | 0 (1, dof 6) | 1, 1 | 199 | 200/200 | 0 | 0 | 0.9851 | ROBUST |

- x1: every evaluated point OK (199), every Nelder-Mead start of the local stage converged; bound-worst 0 >= reserve 0; 1 round(s), the final confirmation did not move. Verdict reason: bound-worst margin 0 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
  - round 1: 2 candidate condition(s) (h_ft=5000 mach=0.45 cg_pct_mac=20; h_ft=8000 mach=0.45 cg_pct_mac=20); search value 0 at h_ft=5000 mach=0.45 cg_pct_mac=20, theta [1 1 1 1 1 1 1]; confirmation OK 0 at h_ft=5000 mach=0.45 cg_pct_mac=20 (did not move)
  - stages: centre 1 points (converged -); corner 64 points (converged -); lhs 32 points (converged -); de 32 points (converged no); local 70 points (converged yes)

Critical Similitude Ratio over Cm_basic, Cm_de, Cl_p, Cn_r, Cl_table, Cnt_table; R4 verdict **ROBUST**: the judged box R(1) is certified: alphaLo = 2.153 >= 1 (alpha* in [2.153, 2.163], CSR OK; the box R(2.153) was searched clean over the final candidates) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- judged shape (m = [0.1517 0.1517 0.3035 0.3035 0.1517 0.1517]): status OK, alpha* 2.153, bracket [2.153, 2.163]; parametric safety margin [0 0.3267 0.3267 0.6534 0.6534 0.3267 0.3267]; CPV [1 0.67179 1.3282 0.34357 1.6564 1.3282 0.67179] at h_ft=5000 mach=0.45 cg_pct_mac=20 (margin -1, MIL-F-8785C-3.3.1.4-coupled_roll_spiral_present-L1-CatA-other), confirmation OK -1 at h_ft=5000 mach=0.45 cg_pct_mac=20; alpha* in [2.153, 2.163] (resolution 0.01): the box R(2.153) was searched clean and the CPV at scaled norm 2.163 fails (margin -1 at h_ft=5000 mach=0.45 cg_pct_mac=20, MIL-F-8785C-3.3.1.4-coupled_roll_spiral_present-L1-CatA-other), confirmed by a fresh assessment
  - lower end (R5-2): R(2.153) certified 1: the box R(2.153) was searched clean over the final candidates
  - box search alpha 3 (cap): VIOLATED, value -1 at h_ft=5000 mach=0.45 cg_pct_mac=20, 207 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - box search alpha 2.838 (optimistic): VIOLATED, value -1 at h_ft=5000 mach=0.45 cg_pct_mac=20, 223 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - box search alpha 2.589 (optimistic): VIOLATED, value -1 at h_ft=8000 mach=0.45 cg_pct_mac=20, 223 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - box search alpha 1.787 (bisection): OK, value 0 at h_ft=5000 mach=0.45 cg_pct_mac=20, 199 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - box search alpha 2.564 (optimistic): VIOLATED, value -1 at h_ft=5000 mach=0.45 cg_pct_mac=20, 223 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - box search alpha 2.334 (optimistic): VIOLATED, value -1 at h_ft=5000 mach=0.45 cg_pct_mac=20, 223 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - box search alpha 2.022 (bisection): OK, value 0 at h_ft=5000 mach=0.45 cg_pct_mac=20, 199 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - box search alpha 2.246 (optimistic): VIOLATED, value -1 at h_ft=5000 mach=0.45 cg_pct_mac=20, 223 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - box search alpha 2.153 (optimistic): OK, value 0 at h_ft=5000 mach=0.45 cg_pct_mac=20, 199 points (search estimate (hybrid: differential evolution + Nelder-Mead))
  - ray (cap): failing at scaled norm 2.848 (t in [0.9482, 0.9492]), margin -1 at h_ft=8000 mach=0.45 cg_pct_mac=20
  - ray (optimistic): failing at scaled norm 2.599 (t in [0.9150, 0.9160]), margin -1 at h_ft=8000 mach=0.45 cg_pct_mac=20
  - ray (optimistic): failing at scaled norm 2.574 (t in [0.9932, 0.9941]), margin -1 at h_ft=8000 mach=0.45 cg_pct_mac=20
  - ray (optimistic): failing at scaled norm 2.344 (t in [0.9131, 0.9141]), margin -1 at h_ft=5000 mach=0.45 cg_pct_mac=20
  - ray (optimistic): failing at scaled norm 2.256 (t in [0.9648, 0.9668]), margin -1 at h_ft=5000 mach=0.45 cg_pct_mac=20
  - ray (optimistic): failing at scaled norm 2.163 (t in [0.9609, 0.9629]), margin -1 at h_ft=5000 mach=0.45 cg_pct_mac=20
- equal shape (m = [0.1 0.1 0.1 0.1 0.1 0.1]): status ROBUST_TO_CAP, alpha* 3, bracket [3, Inf]; parametric safety margin [0 0.3 0.3 0.3 0.3 0.3 0.3]; CPV [1 NaN NaN NaN NaN NaN NaN] at  (margin NaN, ), confirmation  NaN at ; a box searched clean contains the cap box R(3): no failure up to AlphaMax
  - lower end (R5-2): R(3) certified 1: the cap box R(3) is clean (a box searched clean contains the cap box R(3): no failure up to AlphaMax)
  - ray (prior): failing at scaled norm 6.555 (t in [0.9980, 0.9985]), margin -1 at h_ft=5000 mach=0.45 cg_pct_mac=20

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
