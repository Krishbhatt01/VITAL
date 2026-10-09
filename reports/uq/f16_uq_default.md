# M8 uncertainty: does the augmented F-16's in-envelope MIL-F-8785C Level hold?

**The 1-sigma widths are JUDGMENT (engineering judgment, docs/PLAN_M5_M8.md M8), not published values.** Every Level is a REG result of the VITAL chain; only in-envelope points count.

Aircraft: bare NESC F-16 + pitch SAS Kq = 0.02 s, Ka = 0.14 + yaw damper Kr = 0.82 s (reports/ctrl/f16_sas_suggestion.md (vital.ctrl.suggestGains, TARGET_REACHED, confirmed)).
Conditions `F16-NESC-OFE-PROXY-2` grid `user`: h_ft [5000 8000 13000], mach [0.45 0.5 0.55 0.63], cg_pct_mac [20 25 30].
Search: centre + 2^d corners + 32 LHS points (seed 2026) + fmincon sqp from 2 best points x 60 evaluations, 4 candidate conditions; Monte Carlo N = 200 (seed 2026); reserve 0; required CP lower bound 0.95. Runtime 5379 s; 9583 single-point assessments, 31301 cache hits, 58 full assessments.

## Uncertain parameters (JUDGMENT; spec `f16_uncertainty_v1`)

| parameter | AeroScale field | NASA term | group | sigma | d | k_g | half-width x0.5 | half-width x1 | half-width x1.5 |
|---|---|---|---|---|---|---|---|---|---|
| Cm_q | Cm_q | cmq | pitchDamping | 0.1 | 1 | 2.5758 | 0.1288 | 0.2576 | 0.3864 |
| Cm_table | Cm_table | cmt | pitchStatic | 0.05 | 1 | 2.5758 | 0.0644 | 0.1288 | 0.1932 |
| Cl_p | Cl_p | clp | latDamping | 0.1 | 2 | 3.0349 | 0.1517 | 0.3035 | 0.4552 |
| Cn_r | Cnr_table | cnr | latDamping | 0.1 | 2 | 3.0349 | 0.1517 | 0.3035 | 0.4552 |
| Cl_table | Cl_table | clt | latStatic | 0.05 | 2 | 3.0349 | 0.0759 | 0.1517 | 0.2276 |
| Cnt_table | Cnt_table | cnt | latStatic | 0.05 | 2 | 3.0349 | 0.0759 | 0.1517 | 0.2276 |

## Headline

Widths are JUDGMENT multiples of the 1-sigma judgment widths (x1 = headline).

| group | nominal Level | nominal margin | x0.5 bound-worst (status) | x0.5 MC (CP lower) | x0.5 verdict | x1 bound-worst (status) | x1 MC (CP lower) | x1 verdict | x1.5 bound-worst (status) | x1.5 MC (CP lower) | x1.5 verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 3.2.1.1-CatA | 1 | 0.0111 | 0.01104 (OK) | 200/200 (0.9851) | **ROBUST** | 0.01099 (OK) | 200/200 (0.9851) | **ROBUST** | 0.01094 (OK) | 200/200 (0.9851) | **ROBUST** |
| 3.2.1.1-CatB | 1 | 0.0111 | 0.01104 (OK) | 200/200 (0.9851) | **ROBUST** | 0.01099 (OK) | 200/200 (0.9851) | **ROBUST** | 0.01094 (OK) | 200/200 (0.9851) | **ROBUST** |
| 3.2.1.2-CatA | 1 | 0.4906 | 0.4836 (OK) | 200/200 (0.9851) | **ROBUST** | 0.4786 (OK) | 200/200 (0.9851) | **ROBUST** | 0.4754 (OK) | 200/200 (0.9851) | **ROBUST** |
| 3.2.1.2-CatB | 1 | 0.4906 | 0.4836 (OK) | 200/200 (0.9851) | **ROBUST** | 0.4786 (OK) | 200/200 (0.9851) | **ROBUST** | 0.4754 (OK) | 200/200 (0.9851) | **ROBUST** |
| 3.2.2.1.1-CatA | 1 | 0.05125 | 0.02259 (OK) | 200/200 (0.9851) | **ROBUST** | -0.005879 (VIOLATED) | 200/200 (0.9851) | **NOT_ROBUST** | -0.03413 (VIOLATED) | 195/200 (0.9482) | **NOT_ROBUST** |
| 3.2.2.1.1-CatB | 1 | 2.463 | 2.369 (OK) | 200/200 (0.9851) | **ROBUST** | 2.275 (OK) | 200/200 (0.9851) | **ROBUST** | 2.182 (OK) | 200/200 (0.9851) | **ROBUST** |
| 3.2.2.1.2-CatA | 1 | 0.1021 | 0.05896 (OK) | 200/200 (0.9851) | **ROBUST** | 0.01643 (NOT_ASSESSABLE) | 200/200 (0.9851) | **NOT_ASSESSABLE** | -0.02627 (VIOLATED) | 197/200 (0.9617) | **NOT_ROBUST** |
| 3.2.2.1.2-CatB | 1 | 0.2857 | 0.2355 (OK) | 200/200 (0.9851) | **ROBUST** | 0.1858 (NOT_ASSESSABLE) | 200/200 (0.9851) | **NOT_ASSESSABLE** | 0.136 (NOT_ASSESSABLE) | 200/200 (0.9851) | **NOT_ASSESSABLE** |
| 3.2.2.2-CatA | 1 | 0.0111 | 0.01104 (OK) | 200/200 (0.9851) | **ROBUST** | 0.01099 (OK) | 200/200 (0.9851) | **ROBUST** | 0.01094 (OK) | 200/200 (0.9851) | **ROBUST** |
| 3.2.2.2-CatB | 1 | 0.0111 | 0.01104 (OK) | 200/200 (0.9851) | **ROBUST** | 0.01099 (OK) | 200/200 (0.9851) | **ROBUST** | 0.01094 (OK) | 200/200 (0.9851) | **ROBUST** |
| 3.3.1.1-CatA-COGA | 1 | 0.05376 | -0.02274 (VIOLATED) | 200/200 (0.9851) | **NOT_ROBUST** | -0.09506 (VIOLATED) | 196/200 (0.9548) | **NOT_ROBUST** | -0.1648 (VIOLATED) | 186/200 (0.8927) | **NOT_ROBUST** |
| 3.3.1.1-CatA-other | 1 | 1.218 | 1.057 (OK) | 200/200 (0.9851) | **ROBUST** | 0.9051 (OK) | 200/200 (0.9851) | **ROBUST** | 0.7583 (OK) | 200/200 (0.9851) | **ROBUST** |
| 3.3.1.1-CatB | 1 | 4.269 | 3.886 (OK) | 200/200 (0.9851) | **ROBUST** | 3.525 (OK) | 200/200 (0.9851) | **ROBUST** | 3.176 (OK) | 200/200 (0.9851) | **ROBUST** |
| 3.3.1.2-CatA | 1 | 0.5394 | 0.4608 (OK) | 200/200 (0.9851) | **ROBUST** | 0.3485 (OK) | 200/200 (0.9851) | **ROBUST** | 0.1767 (OK) | 200/200 (0.9851) | **ROBUST** |
| 3.3.1.2-CatB | 1 | 0.671 | 0.6148 (OK) | 200/200 (0.9851) | **ROBUST** | 0.5346 (OK) | 200/200 (0.9851) | **ROBUST** | 0.4119 (OK) | 200/200 (0.9851) | **ROBUST** |
| 3.3.1.3-CatA | 1 | Inf | Inf (NOT_ASSESSABLE) | 200/200 (0.9851) | **NOT_ASSESSABLE** | Inf (NOT_ASSESSABLE) | 200/200 (0.9851) | **NOT_ASSESSABLE** | 0.953 (OK) | 200/200 (0.9851) | **ROBUST** |
| 3.3.1.3-CatB | 1 | Inf | Inf (NOT_ASSESSABLE) | 200/200 (0.9851) | **NOT_ASSESSABLE** | Inf (NOT_ASSESSABLE) | 200/200 (0.9851) | **NOT_ASSESSABLE** | 0.1718 (OK) | 200/200 (0.9851) | **ROBUST** |
| 3.3.1.4-CatA-COGA | 1 | 0 | 0 (OK) | 200/200 (0.9851) | **ROBUST** | 0 (OK) | 200/200 (0.9851) | **ROBUST** | 0 (OK) | 200/200 (0.9851) | **ROBUST** |
| 3.3.1.4-CatA-other | 1 | 0 | 0 (OK) | 200/200 (0.9851) | **ROBUST** | 0 (OK) | 200/200 (0.9851) | **ROBUST** | 0 (OK) | 200/200 (0.9851) | **ROBUST** |

Verdict: ROBUST = bound-worst status OK with margin >= reserve AND Clopper-Pearson one-sided 95 % lower bound >= required; NOT_ROBUST = a counterexample in the box OR the lower bound below required; NOT_ASSESSABLE = anything else (e.g. the optimizer did not converge, FC-901, or a point in the box is not OK).

## Details per group

### 3.2.1.1-CatA
Nominal Level 1, margin 0.0111042, critical MIL-F-8785C-3.2.1.1-speed_divergence_rate_1_s-L1-CatA at h_ft=13000 mach=0.45 cg_pct_mac=30.
Candidates: h_ft=13000 mach=0.45 cg_pct_mac=30 (0.0111); h_ft=13000 mach=0.45 cg_pct_mac=25 (0.01211); h_ft=13000 mach=0.5 cg_pct_mac=30 (0.01244); h_ft=13000 mach=0.45 cg_pct_mac=20 (0.01306).

| width | bound-worst | status | arg-min theta | condition | record | confirmation | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x0.5 | 0.011043 | OK | [1.129 1.064 0.8483 1.152 1.076 0.9241] | h_ft=13000 mach=0.45 cg_pct_mac=30 | MIL-F-8785C-3.2.1.1-speed_divergence_rate_1_s-L1-CatA | OK 0.01104 | 1, 1 | 125 | 200/200 | 0 | 0 | 0.9851 | ROBUST |
| x1 | 0.0109888 | OK | [1.258 1.129 1.303 1.302 0.8483 0.8483] | h_ft=13000 mach=0.45 cg_pct_mac=30 | MIL-F-8785C-3.2.1.1-speed_divergence_rate_1_s-L1-CatA | OK 0.01099 | 1, 1 | 125 | 200/200 | 0 | 0 | 0.9851 | ROBUST |
| x1.5 | 0.0109405 | OK | [1.386 1.193 0.5448 1.455 0.7724 0.7724] | h_ft=13000 mach=0.45 cg_pct_mac=30 | MIL-F-8785C-3.2.1.1-speed_divergence_rate_1_s-L1-CatA | OK 0.01094 | 1, 1 | 123 | 200/200 | 0 | 0 | 0.9851 | ROBUST |

- x0.5: every evaluated point OK (125), every optimizer start converged; bound-worst 0.011043 >= reserve 0. Verdict reason: bound-worst margin 0.01104 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- x1: every evaluated point OK (125), every optimizer start converged; bound-worst 0.0109888 >= reserve 0. Verdict reason: bound-worst margin 0.01099 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- x1.5: every evaluated point OK (123), every optimizer start converged; bound-worst 0.0109405 >= reserve 0. Verdict reason: bound-worst margin 0.01094 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.

### 3.2.1.1-CatB
Nominal Level 1, margin 0.0111042, critical MIL-F-8785C-3.2.1.1-speed_divergence_rate_1_s-L1-CatB at h_ft=13000 mach=0.45 cg_pct_mac=30.
Candidates: h_ft=13000 mach=0.45 cg_pct_mac=30 (0.0111); h_ft=13000 mach=0.45 cg_pct_mac=25 (0.01211); h_ft=13000 mach=0.5 cg_pct_mac=30 (0.01244); h_ft=13000 mach=0.45 cg_pct_mac=20 (0.01306).

| width | bound-worst | status | arg-min theta | condition | record | confirmation | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x0.5 | 0.011043 | OK | [1.129 1.064 0.8483 1.152 1.076 0.9241] | h_ft=13000 mach=0.45 cg_pct_mac=30 | MIL-F-8785C-3.2.1.1-speed_divergence_rate_1_s-L1-CatB | OK 0.01104 | 1, 1 | 125 | 200/200 | 0 | 0 | 0.9851 | ROBUST |
| x1 | 0.0109888 | OK | [1.258 1.129 1.303 1.302 0.8483 0.8483] | h_ft=13000 mach=0.45 cg_pct_mac=30 | MIL-F-8785C-3.2.1.1-speed_divergence_rate_1_s-L1-CatB | OK 0.01099 | 1, 1 | 125 | 200/200 | 0 | 0 | 0.9851 | ROBUST |
| x1.5 | 0.0109405 | OK | [1.386 1.193 0.5448 1.455 0.7724 0.7724] | h_ft=13000 mach=0.45 cg_pct_mac=30 | MIL-F-8785C-3.2.1.1-speed_divergence_rate_1_s-L1-CatB | OK 0.01094 | 1, 1 | 123 | 200/200 | 0 | 0 | 0.9851 | ROBUST |

- x0.5: every evaluated point OK (125), every optimizer start converged; bound-worst 0.011043 >= reserve 0. Verdict reason: bound-worst margin 0.01104 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- x1: every evaluated point OK (125), every optimizer start converged; bound-worst 0.0109888 >= reserve 0. Verdict reason: bound-worst margin 0.01099 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- x1.5: every evaluated point OK (123), every optimizer start converged; bound-worst 0.0109405 >= reserve 0. Verdict reason: bound-worst margin 0.01094 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.

### 3.2.1.2-CatA
Nominal Level 1, margin 0.490645, critical MIL-F-8785C-3.2.1.2-zeta_p-L1-CatA at h_ft=13000 mach=0.45 cg_pct_mac=30.
Candidates: h_ft=13000 mach=0.45 cg_pct_mac=30 (0.4906); h_ft=13000 mach=0.5 cg_pct_mac=30 (0.6058); h_ft=8000 mach=0.45 cg_pct_mac=30 (0.6379); h_ft=13000 mach=0.45 cg_pct_mac=25 (0.7387).

| width | bound-worst | status | arg-min theta | condition | record | confirmation | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x0.5 | 0.483624 | OK | [0.8712 1.064 1.152 0.8483 1.076 1.076] | h_ft=13000 mach=0.45 cg_pct_mac=30 | MIL-F-8785C-3.2.1.2-zeta_p-L1-CatA | OK 0.4836 | 1, 1 | 125 | 200/200 | 0 | 0 | 0.9851 | ROBUST |
| x1 | 0.478636 | OK | [0.7424 1.129 1.303 0.6965 1.152 0.8483] | h_ft=13000 mach=0.45 cg_pct_mac=30 | MIL-F-8785C-3.2.1.2-zeta_p-L1-CatA | OK 0.4786 | 1, 1 | 125 | 200/200 | 0 | 0 | 0.9851 | ROBUST |
| x1.5 | 0.475384 | OK | [0.6902 1.193 1.232 0.919 1.18 1.102] | h_ft=13000 mach=0.45 cg_pct_mac=30 | MIL-F-8785C-3.2.1.2-zeta_p-L1-CatA | OK 0.4754 | 1, 1 | 181 | 200/200 | 0 | 0 | 0.9851 | ROBUST |

- x0.5: every evaluated point OK (125), every optimizer start converged; bound-worst 0.483624 >= reserve 0. Verdict reason: bound-worst margin 0.4836 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- x1: every evaluated point OK (125), every optimizer start converged; bound-worst 0.478636 >= reserve 0. Verdict reason: bound-worst margin 0.4786 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- x1.5: every evaluated point OK (181), every optimizer start converged; bound-worst 0.475384 >= reserve 0. Verdict reason: bound-worst margin 0.4754 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.

### 3.2.1.2-CatB
Nominal Level 1, margin 0.490645, critical MIL-F-8785C-3.2.1.2-zeta_p-L1-CatB at h_ft=13000 mach=0.45 cg_pct_mac=30.
Candidates: h_ft=13000 mach=0.45 cg_pct_mac=30 (0.4906); h_ft=13000 mach=0.5 cg_pct_mac=30 (0.6058); h_ft=8000 mach=0.45 cg_pct_mac=30 (0.6379); h_ft=13000 mach=0.45 cg_pct_mac=25 (0.7387).

| width | bound-worst | status | arg-min theta | condition | record | confirmation | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x0.5 | 0.483624 | OK | [0.8712 1.064 1.152 0.8483 1.076 1.076] | h_ft=13000 mach=0.45 cg_pct_mac=30 | MIL-F-8785C-3.2.1.2-zeta_p-L1-CatB | OK 0.4836 | 1, 1 | 125 | 200/200 | 0 | 0 | 0.9851 | ROBUST |
| x1 | 0.478636 | OK | [0.7424 1.129 1.303 0.6965 1.152 0.8483] | h_ft=13000 mach=0.45 cg_pct_mac=30 | MIL-F-8785C-3.2.1.2-zeta_p-L1-CatB | OK 0.4786 | 1, 1 | 125 | 200/200 | 0 | 0 | 0.9851 | ROBUST |
| x1.5 | 0.475384 | OK | [0.6902 1.193 1.232 0.919 1.18 1.102] | h_ft=13000 mach=0.45 cg_pct_mac=30 | MIL-F-8785C-3.2.1.2-zeta_p-L1-CatB | OK 0.4754 | 1, 1 | 181 | 200/200 | 0 | 0 | 0.9851 | ROBUST |

- x0.5: every evaluated point OK (125), every optimizer start converged; bound-worst 0.483624 >= reserve 0. Verdict reason: bound-worst margin 0.4836 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- x1: every evaluated point OK (125), every optimizer start converged; bound-worst 0.478636 >= reserve 0. Verdict reason: bound-worst margin 0.4786 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- x1.5: every evaluated point OK (181), every optimizer start converged; bound-worst 0.475384 >= reserve 0. Verdict reason: bound-worst margin 0.4754 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.

### 3.2.2.1.1-CatA
Nominal Level 1, margin 0.0512487, critical MIL-F-8785C-3.2.2.1.1-CAP-L1-CatA at h_ft=13000 mach=0.45 cg_pct_mac=30.
Candidates: h_ft=13000 mach=0.45 cg_pct_mac=30 (0.05125); h_ft=13000 mach=0.5 cg_pct_mac=30 (0.05524); h_ft=13000 mach=0.55 cg_pct_mac=30 (0.05916); h_ft=13000 mach=0.63 cg_pct_mac=30 (0.06526).

| width | bound-worst | status | arg-min theta | condition | record | confirmation | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x0.5 | 0.0225941 | OK | [0.8712 0.9356 1.152 0.8493 0.9241 0.9241] | h_ft=13000 mach=0.45 cg_pct_mac=30 | MIL-F-8785C-3.2.2.1.1-CAP-L1-CatA | OK 0.02259 | 1, 1 | 125 | 200/200 | 0 | 0 | 0.9851 | ROBUST |
| x1 | -0.00587928 | VIOLATED | [0.7424 0.8712 1.303 0.6965 1.152 0.8483] | h_ft=13000 mach=0.45 cg_pct_mac=30 | MIL-F-8785C-3.2.2.1.1-CAP-L1-CatA | OK -0.005879 | 1, 1 | 119 | 200/200 | 0 | 0 | 0.9851 | NOT_ROBUST |
| x1.5 | -0.0341273 | VIOLATED | [0.6136 0.8068 1.455 1.455 1.228 0.7724] | h_ft=13000 mach=0.45 cg_pct_mac=30 | MIL-F-8785C-3.2.2.1.1-CAP-L1-CatA | OK -0.03413 | 1, 1 | 123 | 195/200 | 0 | 5 | 0.9482 | NOT_ROBUST |

- x0.5: every evaluated point OK (125), every optimizer start converged; bound-worst 0.0225941 >= reserve 0. Verdict reason: bound-worst margin 0.02259 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- x1: counterexample: margin -0.00587928 < reserve 0 at h_ft=13000 mach=0.45 cg_pct_mac=30 (MIL-F-8785C-3.2.2.1.1-CAP-L1-CatA), theta [0.742417 0.871209 1.30349 0.696515 1.15174 0.848257]; 39 of 119 evaluated points violate. Verdict reason: bound-worst margin -0.005879 < reserve 0 (VIOLATED): a counterexample inside the box.
- x1.5: counterexample: margin -0.0341273 < reserve 0 at h_ft=13000 mach=0.45 cg_pct_mac=30 (MIL-F-8785C-3.2.2.1.1-CAP-L1-CatA), theta [0.613626 0.806813 1.45523 1.45523 1.22761 0.772386]; 46 of 123 evaluated points violate. Verdict reason: bound-worst margin -0.03413 < reserve 0 (VIOLATED): a counterexample inside the box; Clopper-Pearson lower bound 0.9482 < 0.95.

### 3.2.2.1.1-CatB
Nominal Level 1, margin 2.46294, critical MIL-F-8785C-3.2.2.1.1-CAP-L1-CatB at h_ft=13000 mach=0.45 cg_pct_mac=30.
Candidates: h_ft=13000 mach=0.45 cg_pct_mac=30 (2.463); h_ft=13000 mach=0.5 cg_pct_mac=30 (2.476); h_ft=13000 mach=0.55 cg_pct_mac=30 (2.489); h_ft=13000 mach=0.63 cg_pct_mac=30 (2.509).

| width | bound-worst | status | arg-min theta | condition | record | confirmation | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x0.5 | 2.36855 | OK | [0.8712 0.9356 1.152 0.8493 0.9241 0.9241] | h_ft=13000 mach=0.45 cg_pct_mac=30 | MIL-F-8785C-3.2.2.1.1-CAP-L1-CatB | OK 2.369 | 1, 1 | 125 | 200/200 | 0 | 0 | 0.9851 | ROBUST |
| x1 | 2.27475 | OK | [0.7424 0.8712 1.303 0.6965 1.152 0.8483] | h_ft=13000 mach=0.45 cg_pct_mac=30 | MIL-F-8785C-3.2.2.1.1-CAP-L1-CatB | OK 2.275 | 1, 1 | 119 | 200/200 | 0 | 0 | 0.9851 | ROBUST |
| x1.5 | 2.1817 | OK | [0.6136 0.8068 1.455 1.455 1.228 0.7724] | h_ft=13000 mach=0.45 cg_pct_mac=30 | MIL-F-8785C-3.2.2.1.1-CAP-L1-CatB | OK 2.182 | 1, 1 | 123 | 200/200 | 0 | 0 | 0.9851 | ROBUST |

- x0.5: every evaluated point OK (125), every optimizer start converged; bound-worst 2.36855 >= reserve 0. Verdict reason: bound-worst margin 2.369 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- x1: every evaluated point OK (119), every optimizer start converged; bound-worst 2.27475 >= reserve 0. Verdict reason: bound-worst margin 2.275 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- x1.5: every evaluated point OK (123), every optimizer start converged; bound-worst 2.1817 >= reserve 0. Verdict reason: bound-worst margin 2.182 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.

### 3.2.2.1.2-CatA
Nominal Level 1, margin 0.102065, critical MIL-F-8785C-3.2.2.1.2-zeta_sp-L1-CatA at h_ft=13000 mach=0.45 cg_pct_mac=20.
Candidates: h_ft=13000 mach=0.45 cg_pct_mac=20 (0.1021); h_ft=13000 mach=0.5 cg_pct_mac=20 (0.1373); h_ft=13000 mach=0.55 cg_pct_mac=20 (0.1397); h_ft=13000 mach=0.63 cg_pct_mac=20 (0.1459).

| width | bound-worst | status | arg-min theta | condition | record | confirmation | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x0.5 | 0.0589588 | OK | [0.8712 1.064 0.8483 1.152 0.9251 0.9241] | h_ft=13000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.2.2.1.2-zeta_sp-L1-CatA | OK 0.05896 | 1, 1 | 125 | 200/200 | 0 | 0 | 0.9851 | ROBUST |
| x1 | 0.0164317 | NOT_ASSESSABLE | [0.7424 1.077 0.6965 0.6975 0.8483 0.8483] | h_ft=13000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.2.2.1.2-zeta_sp-L1-CatA | OK 0.01643 | 0, 0 | 217 | 200/200 | 0 | 0 | 0.9851 | NOT_ASSESSABLE |
| x1.5 | -0.026274 | VIOLATED | [0.6136 1.078 1.454 1.455 0.7724 0.7724] | h_ft=13000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.2.2.1.2-zeta_sp-L1-CatA | OK -0.02627 | 0, 0 | 217 | 197/200 | 0 | 3 | 0.9617 | NOT_ROBUST |

- x0.5: every evaluated point OK (125), every optimizer start converged; bound-worst 0.0589588 >= reserve 0. Verdict reason: bound-worst margin 0.05896 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- x1: FC-901: the optimizer did not converge (start 1 exit flag 0 (Solver stopped prematurely. fmincon stopped because it exceeded the function evaluation limit, options.MaxFunctionEvaluations = 6.000000e+01.); start 2 exit flag 0 (Solver stopped prematurely. fmincon stopped because it exceeded the function evaluation limit, options.MaxFunctionEvaluations = 6.000000e+01.)) and no counterexample was found. Verdict reason: bound-worst status NOT_ASSESSABLE (no counterexample) with Clopper-Pearson lower bound 0.9851 >= 0.95.
- x1.5: counterexample: margin -0.026274 < reserve 0 at h_ft=13000 mach=0.45 cg_pct_mac=20 (MIL-F-8785C-3.2.2.1.2-zeta_sp-L1-CatA), theta [0.613626 1.07785 1.45353 1.45499 0.772386 0.772386]; 96 of 217 evaluated points violate; definitive although the optimizer did not converge. Verdict reason: bound-worst margin -0.02627 < reserve 0 (VIOLATED): a counterexample inside the box.

### 3.2.2.1.2-CatB
Nominal Level 1, margin 0.285742, critical MIL-F-8785C-3.2.2.1.2-zeta_sp-L1-CatB at h_ft=13000 mach=0.45 cg_pct_mac=20.
Candidates: h_ft=13000 mach=0.45 cg_pct_mac=20 (0.2857); h_ft=13000 mach=0.5 cg_pct_mac=20 (0.3268); h_ft=13000 mach=0.55 cg_pct_mac=20 (0.3296); h_ft=13000 mach=0.63 cg_pct_mac=20 (0.3369).

| width | bound-worst | status | arg-min theta | condition | record | confirmation | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x0.5 | 0.235452 | OK | [0.8712 1.064 0.8483 1.152 0.9251 0.9241] | h_ft=13000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.2.2.1.2-zeta_sp-L1-CatB | OK 0.2355 | 1, 1 | 125 | 200/200 | 0 | 0 | 0.9851 | ROBUST |
| x1 | 0.185834 | NOT_ASSESSABLE | [0.7424 1.077 0.6965 0.6975 0.8483 0.8483] | h_ft=13000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.2.2.1.2-zeta_sp-L1-CatB | OK 0.1858 | 0, 0 | 217 | 200/200 | 0 | 0 | 0.9851 | NOT_ASSESSABLE |
| x1.5 | 0.136017 | NOT_ASSESSABLE | [0.6136 1.077 1.455 1.455 0.7724 0.7724] | h_ft=13000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.2.2.1.2-zeta_sp-L1-CatB | OK 0.136 | 0, 0 | 217 | 200/200 | 0 | 0 | 0.9851 | NOT_ASSESSABLE |

- x0.5: every evaluated point OK (125), every optimizer start converged; bound-worst 0.235452 >= reserve 0. Verdict reason: bound-worst margin 0.2355 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- x1: 2 of 217 evaluated points are not OK inside the box, e.g. EXCLUDED (h_ft=13000 mach=0.45 cg_pct_mac=20: point NOT_CONVERGED at stage linearize: open loop: column 3 (w): no step plateau - successive central-difference estimates never agreed within RelTol 1e-06 over steps 1..1e-06 (noise or non-smooth function) | closed loop: column 3 (w): no step plateau - successive central-difference estimates never agreed within RelTol 1e-06 over steps 1..1e-06 (noise or non-smooth function)) at theta [0.742417 1.07809 1.30336 1.30336 1.15162 0.848257]; FC-901: the optimizer did not converge (start 1 exit flag 0 (Solver stopped prematurely. fmincon stopped because it exceeded the function evaluation limit, options.MaxFunctionEvaluations = 6.000000e+01.); start 2 exit flag 0 (Solver stopped prematurely. fmincon stopped because it exceeded the function evaluation limit, options.MaxFunctionEvaluations = 6.000000e+01.)) and no counterexample was found. Verdict reason: bound-worst status NOT_ASSESSABLE (no counterexample) with Clopper-Pearson lower bound 0.9851 >= 0.95.
- x1.5: FC-901: the optimizer did not converge (start 1 exit flag 0 (Solver stopped prematurely. fmincon stopped because it exceeded the function evaluation limit, options.MaxFunctionEvaluations = 6.000000e+01.); start 2 exit flag 0 (Solver stopped prematurely. fmincon stopped because it exceeded the function evaluation limit, options.MaxFunctionEvaluations = 6.000000e+01.)) and no counterexample was found. Verdict reason: bound-worst status NOT_ASSESSABLE (no counterexample) with Clopper-Pearson lower bound 0.9851 >= 0.95.

### 3.2.2.2-CatA
Nominal Level 1, margin 0.0111042, critical MIL-F-8785C-3.2.2.2-lon_divergence_rate_1_s-L1-CatA at h_ft=13000 mach=0.45 cg_pct_mac=30.
Candidates: h_ft=13000 mach=0.45 cg_pct_mac=30 (0.0111); h_ft=13000 mach=0.45 cg_pct_mac=25 (0.01211); h_ft=13000 mach=0.5 cg_pct_mac=30 (0.01244); h_ft=13000 mach=0.45 cg_pct_mac=20 (0.01306).

| width | bound-worst | status | arg-min theta | condition | record | confirmation | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x0.5 | 0.011043 | OK | [1.129 1.064 0.8483 1.152 1.076 0.9241] | h_ft=13000 mach=0.45 cg_pct_mac=30 | MIL-F-8785C-3.2.2.2-lon_divergence_rate_1_s-L1-CatA | OK 0.01104 | 1, 1 | 125 | 200/200 | 0 | 0 | 0.9851 | ROBUST |
| x1 | 0.0109888 | OK | [1.258 1.129 1.303 1.302 0.8483 0.8483] | h_ft=13000 mach=0.45 cg_pct_mac=30 | MIL-F-8785C-3.2.2.2-lon_divergence_rate_1_s-L1-CatA | OK 0.01099 | 1, 1 | 125 | 200/200 | 0 | 0 | 0.9851 | ROBUST |
| x1.5 | 0.0109405 | OK | [1.386 1.193 0.5448 1.455 0.7724 0.7724] | h_ft=13000 mach=0.45 cg_pct_mac=30 | MIL-F-8785C-3.2.2.2-lon_divergence_rate_1_s-L1-CatA | OK 0.01094 | 1, 1 | 123 | 200/200 | 0 | 0 | 0.9851 | ROBUST |

- x0.5: every evaluated point OK (125), every optimizer start converged; bound-worst 0.011043 >= reserve 0. Verdict reason: bound-worst margin 0.01104 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- x1: every evaluated point OK (125), every optimizer start converged; bound-worst 0.0109888 >= reserve 0. Verdict reason: bound-worst margin 0.01099 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- x1.5: every evaluated point OK (123), every optimizer start converged; bound-worst 0.0109405 >= reserve 0. Verdict reason: bound-worst margin 0.01094 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.

### 3.2.2.2-CatB
Nominal Level 1, margin 0.0111042, critical MIL-F-8785C-3.2.2.2-lon_divergence_rate_1_s-L1-CatB at h_ft=13000 mach=0.45 cg_pct_mac=30.
Candidates: h_ft=13000 mach=0.45 cg_pct_mac=30 (0.0111); h_ft=13000 mach=0.45 cg_pct_mac=25 (0.01211); h_ft=13000 mach=0.5 cg_pct_mac=30 (0.01244); h_ft=13000 mach=0.45 cg_pct_mac=20 (0.01306).

| width | bound-worst | status | arg-min theta | condition | record | confirmation | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x0.5 | 0.011043 | OK | [1.129 1.064 0.8483 1.152 1.076 0.9241] | h_ft=13000 mach=0.45 cg_pct_mac=30 | MIL-F-8785C-3.2.2.2-lon_divergence_rate_1_s-L1-CatB | OK 0.01104 | 1, 1 | 125 | 200/200 | 0 | 0 | 0.9851 | ROBUST |
| x1 | 0.0109888 | OK | [1.258 1.129 1.303 1.302 0.8483 0.8483] | h_ft=13000 mach=0.45 cg_pct_mac=30 | MIL-F-8785C-3.2.2.2-lon_divergence_rate_1_s-L1-CatB | OK 0.01099 | 1, 1 | 125 | 200/200 | 0 | 0 | 0.9851 | ROBUST |
| x1.5 | 0.0109405 | OK | [1.386 1.193 0.5448 1.455 0.7724 0.7724] | h_ft=13000 mach=0.45 cg_pct_mac=30 | MIL-F-8785C-3.2.2.2-lon_divergence_rate_1_s-L1-CatB | OK 0.01094 | 1, 1 | 123 | 200/200 | 0 | 0 | 0.9851 | ROBUST |

- x0.5: every evaluated point OK (125), every optimizer start converged; bound-worst 0.011043 >= reserve 0. Verdict reason: bound-worst margin 0.01104 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- x1: every evaluated point OK (125), every optimizer start converged; bound-worst 0.0109888 >= reserve 0. Verdict reason: bound-worst margin 0.01099 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- x1.5: every evaluated point OK (123), every optimizer start converged; bound-worst 0.0109405 >= reserve 0. Verdict reason: bound-worst margin 0.01094 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.

### 3.3.1.1-CatA-COGA
Nominal Level 1, margin 0.0537644, critical MIL-F-8785C-3.3.1.1-zeta_d-L1-CatA-COGA at h_ft=13000 mach=0.45 cg_pct_mac=20.
Candidates: h_ft=13000 mach=0.45 cg_pct_mac=20 (0.05376); h_ft=13000 mach=0.45 cg_pct_mac=25 (0.05951); h_ft=13000 mach=0.45 cg_pct_mac=30 (0.06708); h_ft=13000 mach=0.5 cg_pct_mac=20 (0.187).

| width | bound-worst | status | arg-min theta | condition | record | confirmation | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x0.5 | -0.0227394 | VIOLATED | [0.8722 0.9356 0.8483 0.8483 1.076 1.076] | h_ft=13000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.3.1.1-zeta_d-L1-CatA-COGA | OK -0.02274 | 1, 1 | 125 | 200/200 | 0 | 0 | 0.9851 | NOT_ROBUST |
| x1 | -0.0950557 | VIOLATED | [1.258 0.8712 0.6965 0.6965 1.152 1.152] | h_ft=13000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.3.1.1-zeta_d-L1-CatA-COGA | OK -0.09506 | 1, 1 | 125 | 196/200 | 0 | 4 | 0.9548 | NOT_ROBUST |
| x1.5 | -0.164793 | VIOLATED | [1.386 0.8068 0.5448 0.5448 1.228 1.228] | h_ft=13000 mach=0.45 cg_pct_mac=25 | MIL-F-8785C-3.3.1.1-zeta_d-L1-CatA-COGA | OK -0.1648 | 1, 1 | 123 | 186/200 | 0 | 14 | 0.8927 | NOT_ROBUST |

- x0.5: counterexample: margin -0.0227394 < reserve 0 at h_ft=13000 mach=0.45 cg_pct_mac=20 (MIL-F-8785C-3.3.1.1-zeta_d-L1-CatA-COGA), theta [0.872209 0.935604 0.848257 0.848257 1.07587 1.07587]; 32 of 125 evaluated points violate. Verdict reason: bound-worst margin -0.02274 < reserve 0 (VIOLATED): a counterexample inside the box.
- x1: counterexample: margin -0.0950557 < reserve 0 at h_ft=13000 mach=0.45 cg_pct_mac=20 (MIL-F-8785C-3.3.1.1-zeta_d-L1-CatA-COGA), theta [1.25758 0.871209 0.696515 0.696515 1.15174 1.15174]; 48 of 125 evaluated points violate. Verdict reason: bound-worst margin -0.09506 < reserve 0 (VIOLATED): a counterexample inside the box.
- x1.5: counterexample: margin -0.164793 < reserve 0 at h_ft=13000 mach=0.45 cg_pct_mac=25 (MIL-F-8785C-3.3.1.1-zeta_d-L1-CatA-COGA), theta [1.38637 0.806813 0.544772 0.544772 1.22761 1.22761]; 55 of 123 evaluated points violate. Verdict reason: bound-worst margin -0.1648 < reserve 0 (VIOLATED): a counterexample inside the box; Clopper-Pearson lower bound 0.8927 < 0.95.

### 3.3.1.1-CatA-other
Nominal Level 1, margin 1.21845, critical MIL-F-8785C-3.3.1.1-zeta_d-L1-CatA-other at h_ft=13000 mach=0.45 cg_pct_mac=20.
Candidates: h_ft=13000 mach=0.45 cg_pct_mac=20 (1.218); h_ft=13000 mach=0.45 cg_pct_mac=25 (1.231); h_ft=13000 mach=0.45 cg_pct_mac=30 (1.246); h_ft=13000 mach=0.5 cg_pct_mac=20 (1.499).

| width | bound-worst | status | arg-min theta | condition | record | confirmation | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x0.5 | 1.05739 | OK | [0.8722 0.9356 0.8483 0.8483 1.076 1.076] | h_ft=13000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.3.1.1-zeta_d-L1-CatA-other | OK 1.057 | 1, 1 | 125 | 200/200 | 0 | 0 | 0.9851 | ROBUST |
| x1 | 0.905146 | OK | [1.258 0.8712 0.6965 0.6965 1.152 1.152] | h_ft=13000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.3.1.1-zeta_d-L1-CatA-other | OK 0.9051 | 1, 1 | 125 | 200/200 | 0 | 0 | 0.9851 | ROBUST |
| x1.5 | 0.75833 | OK | [1.386 0.8068 0.5448 0.5448 1.228 1.228] | h_ft=13000 mach=0.45 cg_pct_mac=25 | MIL-F-8785C-3.3.1.1-zeta_d-L1-CatA-other | OK 0.7583 | 1, 1 | 123 | 200/200 | 0 | 0 | 0.9851 | ROBUST |

- x0.5: every evaluated point OK (125), every optimizer start converged; bound-worst 1.05739 >= reserve 0. Verdict reason: bound-worst margin 1.057 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- x1: every evaluated point OK (125), every optimizer start converged; bound-worst 0.905146 >= reserve 0. Verdict reason: bound-worst margin 0.9051 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- x1.5: every evaluated point OK (123), every optimizer start converged; bound-worst 0.75833 >= reserve 0. Verdict reason: bound-worst margin 0.7583 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.

### 3.3.1.1-CatB
Nominal Level 1, margin 4.26882, critical MIL-F-8785C-3.3.1.1-zeta_d-L1-CatB at h_ft=13000 mach=0.45 cg_pct_mac=20.
Candidates: h_ft=13000 mach=0.45 cg_pct_mac=20 (4.269); h_ft=13000 mach=0.45 cg_pct_mac=25 (4.298); h_ft=13000 mach=0.45 cg_pct_mac=30 (4.335); h_ft=13000 mach=0.5 cg_pct_mac=20 (4.935).

| width | bound-worst | status | arg-min theta | condition | record | confirmation | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x0.5 | 3.8863 | OK | [0.8722 0.9356 0.8483 0.8483 1.076 1.076] | h_ft=13000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.3.1.1-zeta_d-L1-CatB | OK 3.886 | 1, 1 | 125 | 200/200 | 0 | 0 | 0.9851 | ROBUST |
| x1 | 3.52472 | OK | [1.258 0.8712 0.6965 0.6965 1.152 1.152] | h_ft=13000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.3.1.1-zeta_d-L1-CatB | OK 3.525 | 1, 1 | 125 | 200/200 | 0 | 0 | 0.9851 | ROBUST |
| x1.5 | 3.17603 | OK | [1.386 0.8068 0.5448 0.5448 1.228 1.228] | h_ft=13000 mach=0.45 cg_pct_mac=25 | MIL-F-8785C-3.3.1.1-zeta_d-L1-CatB | OK 3.176 | 1, 1 | 123 | 200/200 | 0 | 0 | 0.9851 | ROBUST |

- x0.5: every evaluated point OK (125), every optimizer start converged; bound-worst 3.8863 >= reserve 0. Verdict reason: bound-worst margin 3.886 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- x1: every evaluated point OK (125), every optimizer start converged; bound-worst 3.52472 >= reserve 0. Verdict reason: bound-worst margin 3.525 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- x1.5: every evaluated point OK (123), every optimizer start converged; bound-worst 3.17603 >= reserve 0. Verdict reason: bound-worst margin 3.176 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.

### 3.3.1.2-CatA
Nominal Level 1, margin 0.539424, critical MIL-F-8785C-3.3.1.2-tau_R_s-L1-CatA at h_ft=13000 mach=0.45 cg_pct_mac=20.
Candidates: h_ft=13000 mach=0.45 cg_pct_mac=20 (0.5394); h_ft=13000 mach=0.45 cg_pct_mac=25 (0.5408); h_ft=13000 mach=0.45 cg_pct_mac=30 (0.542); h_ft=13000 mach=0.5 cg_pct_mac=20 (0.593).

| width | bound-worst | status | arg-min theta | condition | record | confirmation | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x0.5 | 0.460782 | OK | [0.8712 0.9356 0.8483 0.8483 0.9241 1.076] | h_ft=13000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.3.1.2-tau_R_s-L1-CatA | OK 0.4608 | 1, 1 | 125 | 200/200 | 0 | 0 | 0.9851 | ROBUST |
| x1 | 0.34846 | OK | [0.7434 0.8712 0.6965 0.6965 0.8483 1.152] | h_ft=13000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.3.1.2-tau_R_s-L1-CatA | OK 0.3485 | 1, 1 | 125 | 200/200 | 0 | 0 | 0.9851 | ROBUST |
| x1.5 | 0.176675 | OK | [1.386 0.8068 0.5448 0.5448 0.7724 1.228] | h_ft=13000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.3.1.2-tau_R_s-L1-CatA | OK 0.1767 | 1, 1 | 123 | 200/200 | 0 | 0 | 0.9851 | ROBUST |

- x0.5: every evaluated point OK (125), every optimizer start converged; bound-worst 0.460782 >= reserve 0. Verdict reason: bound-worst margin 0.4608 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- x1: every evaluated point OK (125), every optimizer start converged; bound-worst 0.34846 >= reserve 0. Verdict reason: bound-worst margin 0.3485 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- x1.5: every evaluated point OK (123), every optimizer start converged; bound-worst 0.176675 >= reserve 0. Verdict reason: bound-worst margin 0.1767 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.

### 3.3.1.2-CatB
Nominal Level 1, margin 0.671017, critical MIL-F-8785C-3.3.1.2-tau_R_s-L1-CatB at h_ft=13000 mach=0.45 cg_pct_mac=20.
Candidates: h_ft=13000 mach=0.45 cg_pct_mac=20 (0.671); h_ft=13000 mach=0.45 cg_pct_mac=25 (0.672); h_ft=13000 mach=0.45 cg_pct_mac=30 (0.6729); h_ft=13000 mach=0.5 cg_pct_mac=20 (0.7093).

| width | bound-worst | status | arg-min theta | condition | record | confirmation | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x0.5 | 0.614844 | OK | [0.8712 0.9356 0.8483 0.8483 0.9241 1.076] | h_ft=13000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.3.1.2-tau_R_s-L1-CatB | OK 0.6148 | 1, 1 | 125 | 200/200 | 0 | 0 | 0.9851 | ROBUST |
| x1 | 0.534615 | OK | [0.7434 0.8712 0.6965 0.6965 0.8483 1.152] | h_ft=13000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.3.1.2-tau_R_s-L1-CatB | OK 0.5346 | 1, 1 | 125 | 200/200 | 0 | 0 | 0.9851 | ROBUST |
| x1.5 | 0.411911 | OK | [1.386 0.8068 0.5448 0.5448 0.7724 1.228] | h_ft=13000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.3.1.2-tau_R_s-L1-CatB | OK 0.4119 | 1, 1 | 123 | 200/200 | 0 | 0 | 0.9851 | ROBUST |

- x0.5: every evaluated point OK (125), every optimizer start converged; bound-worst 0.614844 >= reserve 0. Verdict reason: bound-worst margin 0.6148 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- x1: every evaluated point OK (125), every optimizer start converged; bound-worst 0.534615 >= reserve 0. Verdict reason: bound-worst margin 0.5346 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- x1.5: every evaluated point OK (123), every optimizer start converged; bound-worst 0.411911 >= reserve 0. Verdict reason: bound-worst margin 0.4119 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.

### 3.3.1.3-CatA
Nominal Level 1, margin Inf, critical MIL-F-8785C-3.3.1.3-spiral_T2_s-L1-CatA at h_ft=5000 mach=0.45 cg_pct_mac=20.
Candidates: h_ft=5000 mach=0.45 cg_pct_mac=20 (Inf); h_ft=8000 mach=0.45 cg_pct_mac=20 (Inf); h_ft=13000 mach=0.45 cg_pct_mac=20 (Inf); h_ft=5000 mach=0.5 cg_pct_mac=20 (Inf).

| width | bound-worst | status | arg-min theta | condition | record | confirmation | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x0.5 | Inf | NOT_ASSESSABLE | [1 1 1 1 1 1] | h_ft=5000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.3.1.3-spiral_T2_s-L1-CatA | OK Inf | NaN, NaN | 97 | 200/200 | 0 | 0 | 0.9851 | NOT_ASSESSABLE |
| x1 | Inf | NOT_ASSESSABLE | [1 1 1 1 1 1] | h_ft=5000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.3.1.3-spiral_T2_s-L1-CatA | OK Inf | NaN, NaN | 97 | 200/200 | 0 | 0 | 0.9851 | NOT_ASSESSABLE |
| x1.5 | 0.95298 | OK | [0.6136 1.193 0.5448 0.5448 0.7724 1.228] | h_ft=5000 mach=0.55 cg_pct_mac=20 | MIL-F-8785C-3.3.1.3-spiral_T2_s-L1-CatA | MOVING LIMIT: 0.953 at h_ft=5000 mach=0.55 cg_pct_mac=20 (search 1.792) | 1, 1 | 123 | 200/200 | 0 | 0 | 0.9851 | ROBUST |

- x0.5: FC-901: the optimizer did not converge (start 1 exit flag NaN (objective not finite or not OK at the start (margin Inf, OK): fmincon cannot run); start 2 exit flag NaN (objective not finite or not OK at the start (margin Inf, OK): fmincon cannot run)) and no counterexample was found. Verdict reason: bound-worst status NOT_ASSESSABLE (no counterexample) with Clopper-Pearson lower bound 0.9851 >= 0.95.
- x1: FC-901: the optimizer did not converge (start 1 exit flag NaN (objective not finite or not OK at the start (margin Inf, OK): fmincon cannot run); start 2 exit flag NaN (objective not finite or not OK at the start (margin Inf, OK): fmincon cannot run)) and no counterexample was found. Verdict reason: bound-worst status NOT_ASSESSABLE (no counterexample) with Clopper-Pearson lower bound 0.9851 >= 0.95.
- x1.5: every evaluated point OK (123), every optimizer start converged; bound-worst 0.95298 >= reserve 0. Verdict reason: bound-worst margin 0.953 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.

### 3.3.1.3-CatB
Nominal Level 1, margin Inf, critical MIL-F-8785C-3.3.1.3-spiral_T2_s-L1-CatB at h_ft=5000 mach=0.45 cg_pct_mac=20.
Candidates: h_ft=5000 mach=0.45 cg_pct_mac=20 (Inf); h_ft=8000 mach=0.45 cg_pct_mac=20 (Inf); h_ft=13000 mach=0.45 cg_pct_mac=20 (Inf); h_ft=5000 mach=0.5 cg_pct_mac=20 (Inf).

| width | bound-worst | status | arg-min theta | condition | record | confirmation | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x0.5 | Inf | NOT_ASSESSABLE | [1 1 1 1 1 1] | h_ft=5000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.3.1.3-spiral_T2_s-L1-CatB | OK Inf | NaN, NaN | 97 | 200/200 | 0 | 0 | 0.9851 | NOT_ASSESSABLE |
| x1 | Inf | NOT_ASSESSABLE | [1 1 1 1 1 1] | h_ft=5000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.3.1.3-spiral_T2_s-L1-CatB | OK Inf | NaN, NaN | 97 | 200/200 | 0 | 0 | 0.9851 | NOT_ASSESSABLE |
| x1.5 | 0.171788 | OK | [0.6136 1.193 0.5448 0.5448 0.7724 1.228] | h_ft=5000 mach=0.55 cg_pct_mac=20 | MIL-F-8785C-3.3.1.3-spiral_T2_s-L1-CatB | MOVING LIMIT: 0.1718 at h_ft=5000 mach=0.55 cg_pct_mac=20 (search 0.6754) | 1, 1 | 123 | 200/200 | 0 | 0 | 0.9851 | ROBUST |

- x0.5: FC-901: the optimizer did not converge (start 1 exit flag NaN (objective not finite or not OK at the start (margin Inf, OK): fmincon cannot run); start 2 exit flag NaN (objective not finite or not OK at the start (margin Inf, OK): fmincon cannot run)) and no counterexample was found. Verdict reason: bound-worst status NOT_ASSESSABLE (no counterexample) with Clopper-Pearson lower bound 0.9851 >= 0.95.
- x1: FC-901: the optimizer did not converge (start 1 exit flag NaN (objective not finite or not OK at the start (margin Inf, OK): fmincon cannot run); start 2 exit flag NaN (objective not finite or not OK at the start (margin Inf, OK): fmincon cannot run)) and no counterexample was found. Verdict reason: bound-worst status NOT_ASSESSABLE (no counterexample) with Clopper-Pearson lower bound 0.9851 >= 0.95.
- x1.5: every evaluated point OK (123), every optimizer start converged; bound-worst 0.171788 >= reserve 0. Verdict reason: bound-worst margin 0.1718 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.

### 3.3.1.4-CatA-COGA
Nominal Level 1, margin 0, critical MIL-F-8785C-3.3.1.4-coupled_roll_spiral_present-L1-CatA-COGA at h_ft=5000 mach=0.45 cg_pct_mac=20.
Candidates: h_ft=5000 mach=0.45 cg_pct_mac=20 (0); h_ft=8000 mach=0.45 cg_pct_mac=20 (0); h_ft=13000 mach=0.45 cg_pct_mac=20 (0); h_ft=5000 mach=0.5 cg_pct_mac=20 (0).

| width | bound-worst | status | arg-min theta | condition | record | confirmation | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x0.5 | 0 | OK | [1 1 1 1 1 1] | h_ft=5000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.3.1.4-coupled_roll_spiral_present-L1-CatA-COGA | OK 0 | 1, 1 | 111 | 200/200 | 0 | 0 | 0.9851 | ROBUST |
| x1 | 0 | OK | [1 1 1 1 1 1] | h_ft=5000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.3.1.4-coupled_roll_spiral_present-L1-CatA-COGA | OK 0 | 1, 1 | 111 | 200/200 | 0 | 0 | 0.9851 | ROBUST |
| x1.5 | 0 | OK | [1 1 1 1 1 1] | h_ft=5000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.3.1.4-coupled_roll_spiral_present-L1-CatA-COGA | OK 0 | 1, 1 | 111 | 200/200 | 0 | 0 | 0.9851 | ROBUST |

- x0.5: every evaluated point OK (111), every optimizer start converged; bound-worst 0 >= reserve 0. Verdict reason: bound-worst margin 0 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- x1: every evaluated point OK (111), every optimizer start converged; bound-worst 0 >= reserve 0. Verdict reason: bound-worst margin 0 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- x1.5: every evaluated point OK (111), every optimizer start converged; bound-worst 0 >= reserve 0. Verdict reason: bound-worst margin 0 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.

### 3.3.1.4-CatA-other
Nominal Level 1, margin 0, critical MIL-F-8785C-3.3.1.4-coupled_roll_spiral_present-L1-CatA-other at h_ft=5000 mach=0.45 cg_pct_mac=20.
Candidates: h_ft=5000 mach=0.45 cg_pct_mac=20 (0); h_ft=8000 mach=0.45 cg_pct_mac=20 (0); h_ft=13000 mach=0.45 cg_pct_mac=20 (0); h_ft=5000 mach=0.5 cg_pct_mac=20 (0).

| width | bound-worst | status | arg-min theta | condition | record | confirmation | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x0.5 | 0 | OK | [1 1 1 1 1 1] | h_ft=5000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.3.1.4-coupled_roll_spiral_present-L1-CatA-other | OK 0 | 1, 1 | 111 | 200/200 | 0 | 0 | 0.9851 | ROBUST |
| x1 | 0 | OK | [1 1 1 1 1 1] | h_ft=5000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.3.1.4-coupled_roll_spiral_present-L1-CatA-other | OK 0 | 1, 1 | 111 | 200/200 | 0 | 0 | 0.9851 | ROBUST |
| x1.5 | 0 | OK | [1 1 1 1 1 1] | h_ft=5000 mach=0.45 cg_pct_mac=20 | MIL-F-8785C-3.3.1.4-coupled_roll_spiral_present-L1-CatA-other | OK 0 | 1, 1 | 111 | 200/200 | 0 | 0 | 0.9851 | ROBUST |

- x0.5: every evaluated point OK (111), every optimizer start converged; bound-worst 0 >= reserve 0. Verdict reason: bound-worst margin 0 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- x1: every evaluated point OK (111), every optimizer start converged; bound-worst 0 >= reserve 0. Verdict reason: bound-worst margin 0 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.
- x1.5: every evaluated point OK (111), every optimizer start converged; bound-worst 0 >= reserve 0. Verdict reason: bound-worst margin 0 >= reserve 0 (search OK) and Clopper-Pearson lower bound 0.9851 >= 0.95.

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
