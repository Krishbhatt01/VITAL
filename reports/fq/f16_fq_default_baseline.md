# MIL-F-8785C flying-qualities assessment
NESC F-16 bare airframe, MIL-F-8785C Class IV. REG: no published F-16 Level exists; these Levels are regression results only. AeroScale: none (baseline)

Condition space `F16-NESC-OFE-PROXY-2`, grid `default`: 229 points evaluated (103 refinement), 55.2 s, 0.229 s per point.
- axis `h_ft`: [5000 8000 13000 21000 29000 37000]
- axis `mach`: [0.3 0.37 0.45 0.5 0.55 0.63 0.76]
- axis `cg_pct_mac`: [20 25 30]
- Category A: assessed. Category A (CO, GA, WD, AR, RC, RR, TF, AS, FF; MIL-F-8785C 1.4): nonterminal phases flown in the clean configuration, which is the only configuration of the NESC model
- Category B: assessed. Category B (CL, CR, LO, RT, D, ED, DE, AD): nonterminal phases flown in the clean configuration
- Category C: NOT ASSESSED. Category C (terminal phases TO, CT, PA, WO, L) is NOT_ASSESSABLE for this model: the NESC F-16 has no landing configuration (no gear, flap or speed-brake terms in F16_aero.dml), and a clean configuration at low speed is not an approach configuration (proposed ADR, reports/fragments/fq/DECISIONS.md)
- Validity envelope: NESC F16_package README (data/nesc/extracted/Atmospheric_models/F16_package/F16_package/README/README.html, line 910, Assumptions and Limitations): "Flight envelope is limited to the vicinity of 10,000 ft MSL and 287.8 knots equivalent airspeed"; the LQR section adds that flight at other speed/altitude combinations may be sub-optimal or even unstable.
  - JUDGMENT (agent fq, 2026-10-05; the README gives no radius): IN = |h - 10,000 ft| <= 5,000 ft and |KEAS - 287.8| <= 20 % (230.24-345.36 KEAS), CG not restricted (20-30 % MAC accepted). Points outside are EXTRAPOLATED: their Levels are reported separately and are indicative only (review R2 M8).
  - h_ft in [5000, 15000]
  - keas in [230.24, 345.36]
- Points IN the envelope: 30; EXTRAPOLATED: 199.

Level: the best Level whose boundaries all hold (MIL-F-8785C 6.7.1); 4 = worse than Level 3. Worst Level over the rated points. "or worse (k of n points unrated)": k points could not be rated (trim, linearization or mode not OK), so the Level is not established (review R2 B2). Margin: normalized margin to the boundary of the Level achieved at the critical condition (m > 0 satisfies); one scale per record, so the upper side of a two-sided bound is also divided by the lower bound's magnitude. A DIVERGENT point (an unstable real root where an oscillation is required) fails every Level.
Interpretations: Table VI Category A, CO/GA use the "A (CO and GA)" row only, other Category A phases the "A" row (extract 6.2 item 8; the stricter both-rows reading is not encoded); 3.3.1.4 also prohibits a coupled roll-spiral mode in Category A phases other than CO/GA; see the records' source.interpretation.

## HEADLINE: points inside the NESC model validity envelope
| group | paragraph | Cat | metrics | Level | margin | critical condition | status | unrated (excluded) |
|---|---|---|---|---|---|---|---|---|
| 3.2.1.1-CatA | 3.2.1.1 | A | T2_speed_divergence_s, speed_divergence_rate_1_s | Level 1 | 0.0111 | h_ft=13000 mach=0.45 cg_pct_mac=30 | ASSESSED | 0 |
| 3.2.1.1-CatB | 3.2.1.1 | B | T2_speed_divergence_s, speed_divergence_rate_1_s | Level 1 | 0.0111 | h_ft=13000 mach=0.45 cg_pct_mac=30 | ASSESSED | 0 |
| 3.2.1.1-CatC | 3.2.1.1 | C | T2_speed_divergence_s, speed_divergence_rate_1_s | - | - | - | NOT_ASSESSABLE | 0 |
| 3.2.1.2-CatA | 3.2.1.2 | A | T2_phugoid_s, zeta_p | Level 1 | 0.3691 | h_ft=13000 mach=0.45 cg_pct_mac=30 | ASSESSED | 0 |
| 3.2.1.2-CatB | 3.2.1.2 | B | T2_phugoid_s, zeta_p | Level 1 | 0.3691 | h_ft=13000 mach=0.45 cg_pct_mac=30 | ASSESSED | 0 |
| 3.2.1.2-CatC | 3.2.1.2 | C | T2_phugoid_s, zeta_p | - | - | - | NOT_ASSESSABLE | 0 |
| 3.2.2.1.1-CatA | 3.2.2.1.1 | A | CAP, omega_nsp_rad_s | Level 2 | 0.2603 | h_ft=13000 mach=0.63 cg_pct_mac=30 | ASSESSED | 0 |
| 3.2.2.1.1-CatB | 3.2.2.1.1 | B | CAP | Level 1 | 1.372 | h_ft=13000 mach=0.63 cg_pct_mac=30 | ASSESSED | 0 |
| 3.2.2.1.1-CatC | 3.2.2.1.1 | C | CAP, n_alpha_g_per_rad, omega_nsp_rad_s | - | - | - | NOT_ASSESSABLE | 0 |
| 3.2.2.1.2-CatA | 3.2.2.1.2 | A | zeta_sp | Level 1 | 0.09977 | h_ft=13000 mach=0.45 cg_pct_mac=20 | ASSESSED | 0 |
| 3.2.2.1.2-CatB | 3.2.2.1.2 | B | zeta_sp | Level 1 | 0.2831 | h_ft=13000 mach=0.45 cg_pct_mac=20 | ASSESSED | 0 |
| 3.2.2.1.2-CatC | 3.2.2.1.2 | C | zeta_sp | - | - | - | NOT_ASSESSABLE | 0 |
| 3.2.2.2-CatA | 3.2.2.2 | A | lon_divergence_rate_1_s | Level 1 | 0.0111 | h_ft=13000 mach=0.45 cg_pct_mac=30 | ASSESSED | 0 |
| 3.2.2.2-CatB | 3.2.2.2 | B | lon_divergence_rate_1_s | Level 1 | 0.0111 | h_ft=13000 mach=0.45 cg_pct_mac=30 | ASSESSED | 0 |
| 3.2.2.2-CatC | 3.2.2.2 | C | lon_divergence_rate_1_s | - | - | - | NOT_ASSESSABLE | 0 |
| 3.3.1.1-CatA-COGA | 3.3.1.1 | A | omega_nd_rad_s, zeta_d, zeta_d_omega_nd_rad_s | Level 2 | 4.429 | h_ft=13000 mach=0.63 cg_pct_mac=20 | ASSESSED | 0 |
| 3.3.1.1-CatA-other | 3.3.1.1 | A | omega_nd_rad_s, zeta_d, zeta_d_omega_nd_rad_s | Level 2 | 4.429 | h_ft=13000 mach=0.63 cg_pct_mac=20 | ASSESSED | 0 |
| 3.3.1.1-CatB | 3.3.1.1 | B | omega_nd_rad_s, zeta_d, zeta_d_omega_nd_rad_s | Level 1 | 0.3573 | h_ft=13000 mach=0.63 cg_pct_mac=20 | ASSESSED | 0 |
| 3.3.1.1-CatC | 3.3.1.1 | C | omega_nd_rad_s, zeta_d, zeta_d_omega_nd_rad_s | - | - | - | NOT_ASSESSABLE | 0 |
| 3.3.1.2-CatA | 3.3.1.2 | A | tau_R_s | Level 1 | 0.5333 | h_ft=13000 mach=0.45 cg_pct_mac=20 | ASSESSED | 0 |
| 3.3.1.2-CatB | 3.3.1.2 | B | tau_R_s | Level 1 | 0.6666 | h_ft=13000 mach=0.45 cg_pct_mac=20 | ASSESSED | 0 |
| 3.3.1.2-CatC | 3.3.1.2 | C | tau_R_s | - | - | - | NOT_ASSESSABLE | 0 |
| 3.3.1.3-CatA | 3.3.1.3 | A | spiral_T2_s | Level 1 | Inf | h_ft=5000 mach=0.45 cg_pct_mac=20 | ASSESSED | 0 |
| 3.3.1.3-CatB | 3.3.1.3 | B | spiral_T2_s | Level 1 | Inf | h_ft=5000 mach=0.45 cg_pct_mac=20 | ASSESSED | 0 |
| 3.3.1.3-CatC | 3.3.1.3 | C | spiral_T2_s | - | - | - | NOT_ASSESSABLE | 0 |
| 3.3.1.4-CatA-COGA | 3.3.1.4 | A | coupled_roll_spiral_present | Level 1 | 0 | h_ft=5000 mach=0.45 cg_pct_mac=20 | ASSESSED | 0 |
| 3.3.1.4-CatA-other | 3.3.1.4 | A | coupled_roll_spiral_present | Level 1 | 0 | h_ft=5000 mach=0.45 cg_pct_mac=20 | ASSESSED | 0 |
| 3.3.1.4-CatB | 3.3.1.4 | B | zeta_RS_omega_nRS_rad_s | - | - | - | NOT_APPLICABLE | 0 |
| 3.3.1.4-CatC | 3.3.1.4 | C | zeta_RS_omega_nRS_rad_s | - | - | - | NOT_ASSESSABLE | 0 |

## EXTRAPOLATED: points outside the NESC model validity envelope (indicative only)
| group | paragraph | Cat | metrics | Level | margin | critical condition | status | unrated (excluded) |
|---|---|---|---|---|---|---|---|---|
| 3.2.1.1-CatA | 3.2.1.1 | A | T2_speed_divergence_s, speed_divergence_rate_1_s | worse than Level 3 (10 of 199 points unrated) | -0.3894 | h_ft=29000 mach=0.45 cg_pct_mac=30 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.2.1.1-CatB | 3.2.1.1 | B | T2_speed_divergence_s, speed_divergence_rate_1_s | worse than Level 3 (10 of 199 points unrated) | -0.3894 | h_ft=29000 mach=0.45 cg_pct_mac=30 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.2.1.1-CatC | 3.2.1.1 | C | T2_speed_divergence_s, speed_divergence_rate_1_s | - | - | - | NOT_ASSESSABLE | 0 |
| 3.2.1.2-CatA | 3.2.1.2 | A | T2_phugoid_s, zeta_p | Level 2 or worse (10 of 199 points unrated) | 0.4515 | h_ft=37000 mach=0.475 cg_pct_mac=25 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.2.1.2-CatB | 3.2.1.2 | B | T2_phugoid_s, zeta_p | Level 2 or worse (10 of 199 points unrated) | 0.4515 | h_ft=37000 mach=0.475 cg_pct_mac=25 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.2.1.2-CatC | 3.2.1.2 | C | T2_phugoid_s, zeta_p | - | - | - | NOT_ASSESSABLE | 0 |
| 3.2.2.1.1-CatA | 3.2.2.1.1 | A | CAP, omega_nsp_rad_s | worse than Level 3 (10 of 199 points unrated) | -Inf | h_ft=13000 mach=0.3 cg_pct_mac=30 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.2.2.1.1-CatB | 3.2.2.1.1 | B | CAP | worse than Level 3 (10 of 199 points unrated) | -Inf | h_ft=13000 mach=0.3 cg_pct_mac=30 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.2.2.1.1-CatC | 3.2.2.1.1 | C | CAP, n_alpha_g_per_rad, omega_nsp_rad_s | - | - | - | NOT_ASSESSABLE | 0 |
| 3.2.2.1.2-CatA | 3.2.2.1.2 | A | zeta_sp | worse than Level 3 (10 of 199 points unrated) | -Inf | h_ft=13000 mach=0.3 cg_pct_mac=30 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.2.2.1.2-CatB | 3.2.2.1.2 | B | zeta_sp | worse than Level 3 (10 of 199 points unrated) | -Inf | h_ft=13000 mach=0.3 cg_pct_mac=30 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.2.2.1.2-CatC | 3.2.2.1.2 | C | zeta_sp | - | - | - | NOT_ASSESSABLE | 0 |
| 3.2.2.2-CatA | 3.2.2.2 | A | lon_divergence_rate_1_s | worse than Level 3 (10 of 199 points unrated) | -1.977 | h_ft=37000 mach=0.55 cg_pct_mac=30 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.2.2.2-CatB | 3.2.2.2 | B | lon_divergence_rate_1_s | worse than Level 3 (10 of 199 points unrated) | -1.977 | h_ft=37000 mach=0.55 cg_pct_mac=30 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.2.2.2-CatC | 3.2.2.2 | C | lon_divergence_rate_1_s | - | - | - | NOT_ASSESSABLE | 0 |
| 3.3.1.1-CatA-COGA | 3.3.1.1 | A | omega_nd_rad_s, zeta_d, zeta_d_omega_nd_rad_s | Level 2 or worse (10 of 199 points unrated) | 2.898 | h_ft=37000 mach=0.76 cg_pct_mac=20 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.3.1.1-CatA-other | 3.3.1.1 | A | omega_nd_rad_s, zeta_d, zeta_d_omega_nd_rad_s | Level 2 or worse (10 of 199 points unrated) | 2.898 | h_ft=37000 mach=0.76 cg_pct_mac=20 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.3.1.1-CatB | 3.3.1.1 | B | omega_nd_rad_s, zeta_d, zeta_d_omega_nd_rad_s | Level 2 or worse (10 of 199 points unrated) | 2.898 | h_ft=37000 mach=0.76 cg_pct_mac=20 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.3.1.1-CatC | 3.3.1.1 | C | omega_nd_rad_s, zeta_d, zeta_d_omega_nd_rad_s | - | - | - | NOT_ASSESSABLE | 0 |
| 3.3.1.2-CatA | 3.3.1.2 | A | tau_R_s | Level 3 or worse (10 of 199 points unrated) | 0.5319 | h_ft=29000 mach=0.3 cg_pct_mac=22.5 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.3.1.2-CatB | 3.3.1.2 | B | tau_R_s | Level 3 or worse (10 of 199 points unrated) | 0.5319 | h_ft=29000 mach=0.3 cg_pct_mac=22.5 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.3.1.2-CatC | 3.3.1.2 | C | tau_R_s | - | - | - | NOT_ASSESSABLE | 0 |
| 3.3.1.3-CatA | 3.3.1.3 | A | spiral_T2_s | Level 1 or worse (10 of 199 points unrated) | 199.5 | h_ft=6500 mach=0.3 cg_pct_mac=20 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.3.1.3-CatB | 3.3.1.3 | B | spiral_T2_s | Level 1 or worse (10 of 199 points unrated) | 119.3 | h_ft=6500 mach=0.3 cg_pct_mac=20 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.3.1.3-CatC | 3.3.1.3 | C | spiral_T2_s | - | - | - | NOT_ASSESSABLE | 0 |
| 3.3.1.4-CatA-COGA | 3.3.1.4 | A | coupled_roll_spiral_present | Level 1 or worse (10 of 199 points unrated) | 0 | h_ft=5000 mach=0.3 cg_pct_mac=20 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.3.1.4-CatA-other | 3.3.1.4 | A | coupled_roll_spiral_present | Level 1 or worse (10 of 199 points unrated) | 0 | h_ft=5000 mach=0.3 cg_pct_mac=20 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.3.1.4-CatB | 3.3.1.4 | B | zeta_RS_omega_nRS_rad_s | - | - | - | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.3.1.4-CatC | 3.3.1.4 | C | zeta_RS_omega_nRS_rad_s | - | - | - | NOT_ASSESSABLE | 0 |

## All points (inside and outside the envelope)
| group | paragraph | Cat | metrics | Level | margin | critical condition | status | unrated (excluded) |
|---|---|---|---|---|---|---|---|---|
| 3.2.1.1-CatA | 3.2.1.1 | A | T2_speed_divergence_s, speed_divergence_rate_1_s | worse than Level 3 (10 of 229 points unrated) | -0.3894 | h_ft=29000 mach=0.45 cg_pct_mac=30 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.2.1.1-CatB | 3.2.1.1 | B | T2_speed_divergence_s, speed_divergence_rate_1_s | worse than Level 3 (10 of 229 points unrated) | -0.3894 | h_ft=29000 mach=0.45 cg_pct_mac=30 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.2.1.1-CatC | 3.2.1.1 | C | T2_speed_divergence_s, speed_divergence_rate_1_s | - | - | - | NOT_ASSESSABLE | 0 |
| 3.2.1.2-CatA | 3.2.1.2 | A | T2_phugoid_s, zeta_p | Level 2 or worse (10 of 229 points unrated) | 0.4515 | h_ft=37000 mach=0.475 cg_pct_mac=25 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.2.1.2-CatB | 3.2.1.2 | B | T2_phugoid_s, zeta_p | Level 2 or worse (10 of 229 points unrated) | 0.4515 | h_ft=37000 mach=0.475 cg_pct_mac=25 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.2.1.2-CatC | 3.2.1.2 | C | T2_phugoid_s, zeta_p | - | - | - | NOT_ASSESSABLE | 0 |
| 3.2.2.1.1-CatA | 3.2.2.1.1 | A | CAP, omega_nsp_rad_s | worse than Level 3 (10 of 229 points unrated) | -Inf | h_ft=13000 mach=0.3 cg_pct_mac=30 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.2.2.1.1-CatB | 3.2.2.1.1 | B | CAP | worse than Level 3 (10 of 229 points unrated) | -Inf | h_ft=13000 mach=0.3 cg_pct_mac=30 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.2.2.1.1-CatC | 3.2.2.1.1 | C | CAP, n_alpha_g_per_rad, omega_nsp_rad_s | - | - | - | NOT_ASSESSABLE | 0 |
| 3.2.2.1.2-CatA | 3.2.2.1.2 | A | zeta_sp | worse than Level 3 (10 of 229 points unrated) | -Inf | h_ft=13000 mach=0.3 cg_pct_mac=30 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.2.2.1.2-CatB | 3.2.2.1.2 | B | zeta_sp | worse than Level 3 (10 of 229 points unrated) | -Inf | h_ft=13000 mach=0.3 cg_pct_mac=30 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.2.2.1.2-CatC | 3.2.2.1.2 | C | zeta_sp | - | - | - | NOT_ASSESSABLE | 0 |
| 3.2.2.2-CatA | 3.2.2.2 | A | lon_divergence_rate_1_s | worse than Level 3 (10 of 229 points unrated) | -1.977 | h_ft=37000 mach=0.55 cg_pct_mac=30 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.2.2.2-CatB | 3.2.2.2 | B | lon_divergence_rate_1_s | worse than Level 3 (10 of 229 points unrated) | -1.977 | h_ft=37000 mach=0.55 cg_pct_mac=30 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.2.2.2-CatC | 3.2.2.2 | C | lon_divergence_rate_1_s | - | - | - | NOT_ASSESSABLE | 0 |
| 3.3.1.1-CatA-COGA | 3.3.1.1 | A | omega_nd_rad_s, zeta_d, zeta_d_omega_nd_rad_s | Level 2 or worse (10 of 229 points unrated) | 2.898 | h_ft=37000 mach=0.76 cg_pct_mac=20 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.3.1.1-CatA-other | 3.3.1.1 | A | omega_nd_rad_s, zeta_d, zeta_d_omega_nd_rad_s | Level 2 or worse (10 of 229 points unrated) | 2.898 | h_ft=37000 mach=0.76 cg_pct_mac=20 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.3.1.1-CatB | 3.3.1.1 | B | omega_nd_rad_s, zeta_d, zeta_d_omega_nd_rad_s | Level 2 or worse (10 of 229 points unrated) | 2.898 | h_ft=37000 mach=0.76 cg_pct_mac=20 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.3.1.1-CatC | 3.3.1.1 | C | omega_nd_rad_s, zeta_d, zeta_d_omega_nd_rad_s | - | - | - | NOT_ASSESSABLE | 0 |
| 3.3.1.2-CatA | 3.3.1.2 | A | tau_R_s | Level 3 or worse (10 of 229 points unrated) | 0.5319 | h_ft=29000 mach=0.3 cg_pct_mac=22.5 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.3.1.2-CatB | 3.3.1.2 | B | tau_R_s | Level 3 or worse (10 of 229 points unrated) | 0.5319 | h_ft=29000 mach=0.3 cg_pct_mac=22.5 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.3.1.2-CatC | 3.3.1.2 | C | tau_R_s | - | - | - | NOT_ASSESSABLE | 0 |
| 3.3.1.3-CatA | 3.3.1.3 | A | spiral_T2_s | Level 1 or worse (10 of 229 points unrated) | 199.5 | h_ft=6500 mach=0.3 cg_pct_mac=20 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.3.1.3-CatB | 3.3.1.3 | B | spiral_T2_s | Level 1 or worse (10 of 229 points unrated) | 119.3 | h_ft=6500 mach=0.3 cg_pct_mac=20 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.3.1.3-CatC | 3.3.1.3 | C | spiral_T2_s | - | - | - | NOT_ASSESSABLE | 0 |
| 3.3.1.4-CatA-COGA | 3.3.1.4 | A | coupled_roll_spiral_present | Level 1 or worse (10 of 229 points unrated) | 0 | h_ft=5000 mach=0.3 cg_pct_mac=20 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.3.1.4-CatA-other | 3.3.1.4 | A | coupled_roll_spiral_present | Level 1 or worse (10 of 229 points unrated) | 0 | h_ft=5000 mach=0.3 cg_pct_mac=20 | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.3.1.4-CatB | 3.3.1.4 | B | zeta_RS_omega_nRS_rad_s | - | - | - | PARTIAL | trim:INFEASIBLE x9; trim:NOT_CONVERGED x1 |
| 3.3.1.4-CatC | 3.3.1.4 | C | zeta_RS_omega_nRS_rad_s | - | - | - | NOT_ASSESSABLE | 0 |

## Records (one Level boundary each), all points
| id | Level | metric | bounds | critical value | min margin | verdict | critical condition | envelope | status | used/excl/n.a. |
|---|---|---|---|---|---|---|---|---|---|---|
| MIL-F-8785C-3.2.1.1-T2_speed_divergence_s-L3-CatA | 3 | T2_speed_divergence_s | [6, Inf] | 3.663 | -0.3894 | FAIL | h_ft=29000 mach=0.45 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.2.1.1-T2_speed_divergence_s-L3-CatB | 3 | T2_speed_divergence_s | [6, Inf] | 3.663 | -0.3894 | FAIL | h_ft=29000 mach=0.45 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.2.1.1-T2_speed_divergence_s-L3-CatC | 3 | T2_speed_divergence_s | [6, Inf] | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |
| MIL-F-8785C-3.2.1.1-speed_divergence_rate_1_s-L1-CatA | 1 | speed_divergence_rate_1_s | [-Inf, 0] | 0.1892 | -1.638 | FAIL | h_ft=29000 mach=0.45 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.2.1.1-speed_divergence_rate_1_s-L1-CatB | 1 | speed_divergence_rate_1_s | [-Inf, 0] | 0.1892 | -1.638 | FAIL | h_ft=29000 mach=0.45 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.2.1.1-speed_divergence_rate_1_s-L1-CatC | 1 | speed_divergence_rate_1_s | [-Inf, 0] | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |
| MIL-F-8785C-3.2.1.1-speed_divergence_rate_1_s-L2-CatA | 2 | speed_divergence_rate_1_s | [-Inf, 0] | 0.1892 | -1.638 | FAIL | h_ft=29000 mach=0.45 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.2.1.1-speed_divergence_rate_1_s-L2-CatB | 2 | speed_divergence_rate_1_s | [-Inf, 0] | 0.1892 | -1.638 | FAIL | h_ft=29000 mach=0.45 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.2.1.1-speed_divergence_rate_1_s-L2-CatC | 2 | speed_divergence_rate_1_s | [-Inf, 0] | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |
| MIL-F-8785C-3.2.1.2-T2_phugoid_s-L3-CatA | 3 | T2_phugoid_s | [55, Inf] | Inf | Inf | PASS (partial) | h_ft=5000 mach=0.3 cg_pct_mac=20 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.2.1.2-T2_phugoid_s-L3-CatB | 3 | T2_phugoid_s | [55, Inf] | Inf | Inf | PASS (partial) | h_ft=5000 mach=0.3 cg_pct_mac=20 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.2.1.2-T2_phugoid_s-L3-CatC | 3 | T2_phugoid_s | [55, Inf] | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |
| MIL-F-8785C-3.2.1.2-zeta_p-L1-CatA | 1 | zeta_p | [0.04, Inf] | 0.01806 | -0.5485 | FAIL | h_ft=37000 mach=0.475 cg_pct_mac=25 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.2.1.2-zeta_p-L1-CatB | 1 | zeta_p | [0.04, Inf] | 0.01806 | -0.5485 | FAIL | h_ft=37000 mach=0.475 cg_pct_mac=25 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.2.1.2-zeta_p-L1-CatC | 1 | zeta_p | [0.04, Inf] | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |
| MIL-F-8785C-3.2.1.2-zeta_p-L2-CatA | 2 | zeta_p | [0, Inf] | 0.01806 | 0.4515 | PASS (partial) | h_ft=37000 mach=0.475 cg_pct_mac=25 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.2.1.2-zeta_p-L2-CatB | 2 | zeta_p | [0, Inf] | 0.01806 | 0.4515 | PASS (partial) | h_ft=37000 mach=0.475 cg_pct_mac=25 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.2.1.2-zeta_p-L2-CatC | 2 | zeta_p | [0, Inf] | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |
| MIL-F-8785C-3.2.2.1.1-CAP-L1-CatA | 1 | CAP | [0.28, 3.6] | - | -Inf | FAIL | h_ft=13000 mach=0.3 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.2.2.1.1-CAP-L1-CatB | 1 | CAP | [0.085, 3.6] | - | -Inf | FAIL | h_ft=13000 mach=0.3 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.2.2.1.1-CAP-L1-CatC | 1 | CAP | [0.16, 3.6] | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |
| MIL-F-8785C-3.2.2.1.1-CAP-L2-CatA | 2 | CAP | [0.16, 10] | - | -Inf | FAIL | h_ft=13000 mach=0.3 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.2.2.1.1-CAP-L2-CatB | 2 | CAP | [0.038, 10] | - | -Inf | FAIL | h_ft=13000 mach=0.3 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.2.2.1.1-CAP-L2-CatC | 2 | CAP | [0.096, 10] | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |
| MIL-F-8785C-3.2.2.1.1-CAP-L3-CatA | 3 | CAP | [0.16, Inf] | - | -Inf | FAIL | h_ft=13000 mach=0.3 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.2.2.1.1-CAP-L3-CatB | 3 | CAP | [0.038, Inf] | - | -Inf | FAIL | h_ft=13000 mach=0.3 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.2.2.1.1-CAP-L3-CatC | 3 | CAP | [0.096, Inf] | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |
| MIL-F-8785C-3.2.2.1.1-n_alpha_g_per_rad-L1-CatC | 1 | n_alpha_g_per_rad | [2.7, Inf] | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |
| MIL-F-8785C-3.2.2.1.1-n_alpha_g_per_rad-L2-CatC | 2 | n_alpha_g_per_rad | [1.7, Inf] | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |
| MIL-F-8785C-3.2.2.1.1-omega_nsp_rad_s-L1-CatA | 1 | omega_nsp_rad_s | [1, Inf] | - | -Inf | FAIL | h_ft=13000 mach=0.3 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.2.2.1.1-omega_nsp_rad_s-L1-CatC | 1 | omega_nsp_rad_s | [0.86, Inf] | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |
| MIL-F-8785C-3.2.2.1.1-omega_nsp_rad_s-L2-CatA | 2 | omega_nsp_rad_s | [0.6, Inf] | - | -Inf | FAIL | h_ft=13000 mach=0.3 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.2.2.1.1-omega_nsp_rad_s-L2-CatC | 2 | omega_nsp_rad_s | [0.6, Inf] | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |
| MIL-F-8785C-3.2.2.1.1-omega_nsp_rad_s-L3-CatC | 3 | omega_nsp_rad_s | [0.6, Inf] strict | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |
| MIL-F-8785C-3.2.2.1.2-zeta_sp-L1-CatA | 1 | zeta_sp | [0.35, 1.3] | - | -Inf | FAIL | h_ft=13000 mach=0.3 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.2.2.1.2-zeta_sp-L1-CatB | 1 | zeta_sp | [0.3, 2] | - | -Inf | FAIL | h_ft=13000 mach=0.3 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.2.2.1.2-zeta_sp-L1-CatC | 1 | zeta_sp | [0.35, 1.3] | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |
| MIL-F-8785C-3.2.2.1.2-zeta_sp-L2-CatA | 2 | zeta_sp | [0.25, 2] | - | -Inf | FAIL | h_ft=13000 mach=0.3 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.2.2.1.2-zeta_sp-L2-CatB | 2 | zeta_sp | [0.2, 2] | - | -Inf | FAIL | h_ft=13000 mach=0.3 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.2.2.1.2-zeta_sp-L2-CatC | 2 | zeta_sp | [0.25, 2] | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |
| MIL-F-8785C-3.2.2.1.2-zeta_sp-L3-CatA | 3 | zeta_sp | [0.15, Inf] | - | -Inf | FAIL | h_ft=13000 mach=0.3 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.2.2.1.2-zeta_sp-L3-CatB | 3 | zeta_sp | [0.15, Inf] | - | -Inf | FAIL | h_ft=13000 mach=0.3 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.2.2.1.2-zeta_sp-L3-CatC | 3 | zeta_sp | [0.15, Inf] | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |
| MIL-F-8785C-3.2.2.2-lon_divergence_rate_1_s-L1-CatA | 1 | lon_divergence_rate_1_s | [-Inf, 0] | 0.2284 | -1.977 | FAIL | h_ft=37000 mach=0.55 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.2.2.2-lon_divergence_rate_1_s-L1-CatB | 1 | lon_divergence_rate_1_s | [-Inf, 0] | 0.2284 | -1.977 | FAIL | h_ft=37000 mach=0.55 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.2.2.2-lon_divergence_rate_1_s-L1-CatC | 1 | lon_divergence_rate_1_s | [-Inf, 0] | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |
| MIL-F-8785C-3.2.2.2-lon_divergence_rate_1_s-L2-CatA | 2 | lon_divergence_rate_1_s | [-Inf, 0] | 0.2284 | -1.977 | FAIL | h_ft=37000 mach=0.55 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.2.2.2-lon_divergence_rate_1_s-L2-CatB | 2 | lon_divergence_rate_1_s | [-Inf, 0] | 0.2284 | -1.977 | FAIL | h_ft=37000 mach=0.55 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.2.2.2-lon_divergence_rate_1_s-L2-CatC | 2 | lon_divergence_rate_1_s | [-Inf, 0] | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |
| MIL-F-8785C-3.2.2.2-lon_divergence_rate_1_s-L3-CatA | 3 | lon_divergence_rate_1_s | [-Inf, 0] | 0.2284 | -1.977 | FAIL | h_ft=37000 mach=0.55 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.2.2.2-lon_divergence_rate_1_s-L3-CatB | 3 | lon_divergence_rate_1_s | [-Inf, 0] | 0.2284 | -1.977 | FAIL | h_ft=37000 mach=0.55 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.2.2.2-lon_divergence_rate_1_s-L3-CatC | 3 | lon_divergence_rate_1_s | [-Inf, 0] | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |
| MIL-F-8785C-3.3.1.1-omega_nd_rad_s-L1-CatA-COGA | 1 | omega_nd_rad_s | [1, Inf] strict | 2.071 | 1.071 | PASS (partial) | h_ft=29000 mach=0.3 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.1-omega_nd_rad_s-L1-CatA-other | 1 | omega_nd_rad_s | [1, Inf] strict | 2.071 | 1.071 | PASS (partial) | h_ft=29000 mach=0.3 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.1-omega_nd_rad_s-L1-CatB | 1 | omega_nd_rad_s | [0.4, Inf] strict | 2.071 | 4.177 | PASS (partial) | h_ft=29000 mach=0.3 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.1-omega_nd_rad_s-L1-CatC | 1 | omega_nd_rad_s | [1, Inf] strict | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |
| MIL-F-8785C-3.3.1.1-omega_nd_rad_s-L2-CatA-COGA | 2 | omega_nd_rad_s | [0.4, Inf] strict | 2.071 | 4.177 | PASS (partial) | h_ft=29000 mach=0.3 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.1-omega_nd_rad_s-L2-CatA-other | 2 | omega_nd_rad_s | [0.4, Inf] strict | 2.071 | 4.177 | PASS (partial) | h_ft=29000 mach=0.3 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.1-omega_nd_rad_s-L2-CatB | 2 | omega_nd_rad_s | [0.4, Inf] strict | 2.071 | 4.177 | PASS (partial) | h_ft=29000 mach=0.3 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.1-omega_nd_rad_s-L2-CatC | 2 | omega_nd_rad_s | [0.4, Inf] strict | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |
| MIL-F-8785C-3.3.1.1-omega_nd_rad_s-L3-CatA-COGA | 3 | omega_nd_rad_s | [0.4, Inf] strict | 2.071 | 4.177 | PASS (partial) | h_ft=29000 mach=0.3 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.1-omega_nd_rad_s-L3-CatA-other | 3 | omega_nd_rad_s | [0.4, Inf] strict | 2.071 | 4.177 | PASS (partial) | h_ft=29000 mach=0.3 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.1-omega_nd_rad_s-L3-CatB | 3 | omega_nd_rad_s | [0.4, Inf] strict | 2.071 | 4.177 | PASS (partial) | h_ft=29000 mach=0.3 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.1-omega_nd_rad_s-L3-CatC | 3 | omega_nd_rad_s | [0.4, Inf] strict | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |
| MIL-F-8785C-3.3.1.1-zeta_d-L1-CatA-COGA | 1 | zeta_d | [0.4, Inf] strict | 0.07797 | -0.8051 | FAIL | h_ft=37000 mach=0.76 cg_pct_mac=20 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.1-zeta_d-L1-CatA-other | 1 | zeta_d | [0.19, Inf] strict | 0.07797 | -0.5896 | FAIL | h_ft=37000 mach=0.76 cg_pct_mac=20 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.1-zeta_d-L1-CatB | 1 | zeta_d | [0.08, Inf] strict | 0.07797 | -0.02541 | FAIL | h_ft=37000 mach=0.76 cg_pct_mac=20 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.1-zeta_d-L1-CatC | 1 | zeta_d | [0.08, Inf] strict | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |
| MIL-F-8785C-3.3.1.1-zeta_d-L2-CatA-COGA | 2 | zeta_d | [0.02, Inf] strict | 0.07797 | 2.898 | PASS (partial) | h_ft=37000 mach=0.76 cg_pct_mac=20 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.1-zeta_d-L2-CatA-other | 2 | zeta_d | [0.02, Inf] strict | 0.07797 | 2.898 | PASS (partial) | h_ft=37000 mach=0.76 cg_pct_mac=20 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.1-zeta_d-L2-CatB | 2 | zeta_d | [0.02, Inf] strict | 0.07797 | 2.898 | PASS (partial) | h_ft=37000 mach=0.76 cg_pct_mac=20 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.1-zeta_d-L2-CatC | 2 | zeta_d | [0.02, Inf] strict | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |
| MIL-F-8785C-3.3.1.1-zeta_d-L3-CatA-COGA | 3 | zeta_d | [0, Inf] strict | 0.07797 | 3.898 | PASS (partial) | h_ft=37000 mach=0.76 cg_pct_mac=20 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.1-zeta_d-L3-CatA-other | 3 | zeta_d | [0, Inf] strict | 0.07797 | 3.898 | PASS (partial) | h_ft=37000 mach=0.76 cg_pct_mac=20 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.1-zeta_d-L3-CatB | 3 | zeta_d | [0, Inf] strict | 0.07797 | 3.898 | PASS (partial) | h_ft=37000 mach=0.76 cg_pct_mac=20 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.1-zeta_d-L3-CatC | 3 | zeta_d | [0, Inf] strict | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |
| MIL-F-8785C-3.3.1.1-zeta_d_omega_nd_rad_s-L1-CatA-COGA | 1 | zeta_d_omega_nd_rad_s | [0, Inf] strict | 0.3084 | 4.322 | PASS (partial) | h_ft=25000 mach=0.76 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.1-zeta_d_omega_nd_rad_s-L1-CatA-other | 1 | zeta_d_omega_nd_rad_s | [0.35, Inf] strict | 0.3084 | -0.3826 | FAIL | h_ft=25000 mach=0.76 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.1-zeta_d_omega_nd_rad_s-L1-CatB | 1 | zeta_d_omega_nd_rad_s | [0.15, Inf] strict | 0.3084 | 0.4407 | PASS (partial) | h_ft=25000 mach=0.76 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.1-zeta_d_omega_nd_rad_s-L1-CatC | 1 | zeta_d_omega_nd_rad_s | [0.15, Inf] strict | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |
| MIL-F-8785C-3.3.1.1-zeta_d_omega_nd_rad_s-L2-CatA-COGA | 2 | zeta_d_omega_nd_rad_s | [0.05, Inf] strict | 0.2225 | 3.408 | PASS (partial) | h_ft=37000 mach=0.76 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.1-zeta_d_omega_nd_rad_s-L2-CatA-other | 2 | zeta_d_omega_nd_rad_s | [0.05, Inf] strict | 0.2225 | 3.408 | PASS (partial) | h_ft=37000 mach=0.76 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.1-zeta_d_omega_nd_rad_s-L2-CatB | 2 | zeta_d_omega_nd_rad_s | [0.05, Inf] strict | 0.2225 | 3.408 | PASS (partial) | h_ft=37000 mach=0.76 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.1-zeta_d_omega_nd_rad_s-L2-CatC | 2 | zeta_d_omega_nd_rad_s | [0.05, Inf] strict | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |
| MIL-F-8785C-3.3.1.1-zeta_d_omega_nd_rad_s-L3-CatA-COGA | 3 | zeta_d_omega_nd_rad_s | [0, Inf] strict | 0.2225 | 4.427 | PASS (partial) | h_ft=37000 mach=0.76 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.1-zeta_d_omega_nd_rad_s-L3-CatA-other | 3 | zeta_d_omega_nd_rad_s | [0, Inf] strict | 0.2225 | 4.427 | PASS (partial) | h_ft=37000 mach=0.76 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.1-zeta_d_omega_nd_rad_s-L3-CatB | 3 | zeta_d_omega_nd_rad_s | [0, Inf] strict | 0.2225 | 4.427 | PASS (partial) | h_ft=37000 mach=0.76 cg_pct_mac=30 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.1-zeta_d_omega_nd_rad_s-L3-CatC | 3 | zeta_d_omega_nd_rad_s | [0, Inf] strict | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |
| MIL-F-8785C-3.3.1.2-tau_R_s-L1-CatA | 1 | tau_R_s | [-Inf, 1] | 4.681 | -3.681 | FAIL | h_ft=29000 mach=0.3 cg_pct_mac=22.5 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.2-tau_R_s-L1-CatB | 1 | tau_R_s | [-Inf, 1.4] | 4.681 | -2.344 | FAIL | h_ft=29000 mach=0.3 cg_pct_mac=22.5 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.2-tau_R_s-L1-CatC | 1 | tau_R_s | [-Inf, 1] | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |
| MIL-F-8785C-3.3.1.2-tau_R_s-L2-CatA | 2 | tau_R_s | [-Inf, 1.4] | 4.681 | -2.344 | FAIL | h_ft=29000 mach=0.3 cg_pct_mac=22.5 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.2-tau_R_s-L2-CatB | 2 | tau_R_s | [-Inf, 3] | 4.681 | -0.5604 | FAIL | h_ft=29000 mach=0.3 cg_pct_mac=22.5 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.2-tau_R_s-L2-CatC | 2 | tau_R_s | [-Inf, 1.4] | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |
| MIL-F-8785C-3.3.1.2-tau_R_s-L3-CatA | 3 | tau_R_s | [-Inf, 10] | 4.681 | 0.5319 | PASS (partial) | h_ft=29000 mach=0.3 cg_pct_mac=22.5 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.2-tau_R_s-L3-CatB | 3 | tau_R_s | [-Inf, 10] | 4.681 | 0.5319 | PASS (partial) | h_ft=29000 mach=0.3 cg_pct_mac=22.5 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.2-tau_R_s-L3-CatC | 3 | tau_R_s | [-Inf, 10] | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |
| MIL-F-8785C-3.3.1.3-spiral_T2_s-L1-CatA | 1 | spiral_T2_s | [12, Inf] strict | 2406 | 199.5 | PASS (partial) | h_ft=6500 mach=0.3 cg_pct_mac=20 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.3-spiral_T2_s-L1-CatB | 1 | spiral_T2_s | [20, Inf] strict | 2406 | 119.3 | PASS (partial) | h_ft=6500 mach=0.3 cg_pct_mac=20 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.3-spiral_T2_s-L1-CatC | 1 | spiral_T2_s | [12, Inf] strict | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |
| MIL-F-8785C-3.3.1.3-spiral_T2_s-L2-CatA | 2 | spiral_T2_s | [8, Inf] strict | 2406 | 299.7 | PASS (partial) | h_ft=6500 mach=0.3 cg_pct_mac=20 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.3-spiral_T2_s-L2-CatB | 2 | spiral_T2_s | [8, Inf] strict | 2406 | 299.7 | PASS (partial) | h_ft=6500 mach=0.3 cg_pct_mac=20 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.3-spiral_T2_s-L2-CatC | 2 | spiral_T2_s | [8, Inf] strict | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |
| MIL-F-8785C-3.3.1.3-spiral_T2_s-L3-CatA | 3 | spiral_T2_s | [4, Inf] strict | 2406 | 600.4 | PASS (partial) | h_ft=6500 mach=0.3 cg_pct_mac=20 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.3-spiral_T2_s-L3-CatB | 3 | spiral_T2_s | [4, Inf] strict | 2406 | 600.4 | PASS (partial) | h_ft=6500 mach=0.3 cg_pct_mac=20 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.3-spiral_T2_s-L3-CatC | 3 | spiral_T2_s | [4, Inf] strict | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |
| MIL-F-8785C-3.3.1.4-coupled_roll_spiral_present-L1-CatA-COGA | 1 | coupled_roll_spiral_present | [-Inf, 0] | 0 | 0 | PASS (partial) | h_ft=5000 mach=0.3 cg_pct_mac=20 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.4-coupled_roll_spiral_present-L1-CatA-other | 1 | coupled_roll_spiral_present | [-Inf, 0] | 0 | 0 | PASS (partial) | h_ft=5000 mach=0.3 cg_pct_mac=20 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.4-coupled_roll_spiral_present-L2-CatA-COGA | 2 | coupled_roll_spiral_present | [-Inf, 0] | 0 | 0 | PASS (partial) | h_ft=5000 mach=0.3 cg_pct_mac=20 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.4-coupled_roll_spiral_present-L2-CatA-other | 2 | coupled_roll_spiral_present | [-Inf, 0] | 0 | 0 | PASS (partial) | h_ft=5000 mach=0.3 cg_pct_mac=20 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.4-coupled_roll_spiral_present-L3-CatA-COGA | 3 | coupled_roll_spiral_present | [-Inf, 0] | 0 | 0 | PASS (partial) | h_ft=5000 mach=0.3 cg_pct_mac=20 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.4-coupled_roll_spiral_present-L3-CatA-other | 3 | coupled_roll_spiral_present | [-Inf, 0] | 0 | 0 | PASS (partial) | h_ft=5000 mach=0.3 cg_pct_mac=20 | EXTRAPOLATED | PARTIAL | 219/10/0 |
| MIL-F-8785C-3.3.1.4-zeta_RS_omega_nRS_rad_s-L1-CatB | 1 | zeta_RS_omega_nRS_rad_s | [0.5, Inf] strict | - | - |  | - | - | PARTIAL | 0/10/219 |
| MIL-F-8785C-3.3.1.4-zeta_RS_omega_nRS_rad_s-L1-CatC | 1 | zeta_RS_omega_nRS_rad_s | [0.5, Inf] strict | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |
| MIL-F-8785C-3.3.1.4-zeta_RS_omega_nRS_rad_s-L2-CatB | 2 | zeta_RS_omega_nRS_rad_s | [0.3, Inf] strict | - | - |  | - | - | PARTIAL | 0/10/219 |
| MIL-F-8785C-3.3.1.4-zeta_RS_omega_nRS_rad_s-L2-CatC | 2 | zeta_RS_omega_nRS_rad_s | [0.3, Inf] strict | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |
| MIL-F-8785C-3.3.1.4-zeta_RS_omega_nRS_rad_s-L3-CatB | 3 | zeta_RS_omega_nRS_rad_s | [0.15, Inf] strict | - | - |  | - | - | PARTIAL | 0/10/219 |
| MIL-F-8785C-3.3.1.4-zeta_RS_omega_nRS_rad_s-L3-CatC | 3 | zeta_RS_omega_nRS_rad_s | [0.15, Inf] strict | - | - |  | - | - | NOT_ASSESSABLE | 0/0/0 |

## Criteria not assessed (coverage)
| class | paragraph | metric | reason | candidates |
|---|---|---|---|---|
| OUT-OF-SIM | 3.2.1.1 | speed_stability_local_gradient_stable | The pitch-force and pitch-position gradients with airspeed (a sufficient demonstration of the Levels 1-2 requirement) and the controls-FREE half: the NESC F-16 model has no cockpit controller, feel system or force gradients, so no stick or pedal force exists in the simulation. The operative controls-FIXED requirement "no tendency for airspeed to diverge aperiodically" IS curated (speed_divergence_rate_1_s <= 0, Levels 1-2; review R2 M1), as is the Level 3 T2 >= 6 s (T2_speed_divergence_s). The position-gradient half is computable from trims but not implemented. | 2 |
| OUT-OF-SIM | 3.2.1.1.1 | transonic_unstable_force_gradient_centerstick_lb_per_0.01M | transonic stick-force gradient and force change: the NESC F-16 model has no cockpit controller, feel system or force gradients, so no stick or pedal force exists in the simulation; the NESC aero tables also have no Mach dependence. | 3 |
| OUT-OF-SIM | 3.2.1.1.1 | transonic_unstable_force_change_centerstick_lb | transonic stick-force gradient and force change: the NESC F-16 model has no cockpit controller, feel system or force gradients, so no stick or pedal force exists in the simulation; the NESC aero tables also have no Mach dependence. | 3 |
| OUT-OF-SIM | 3.2.1.3 | dgamma_dV_at_Vomin_deg_per_kt | landing approach (Category C, PA) flight-path stability needs the approach configuration (gear, flaps, approach speed); the NESC F-16 has no landing configuration (proposed ADR, Category C policy). | 3 |
| OUT-OF-SIM | 3.2.1.3 | dgamma_dV_slope_increase_5kt_below_Vomin_deg_per_kt | landing approach (Category C, PA) flight-path stability needs the approach configuration (gear, flaps, approach speed); the NESC F-16 has no landing configuration (proposed ADR, Category C policy). | 3 |
| NO-REQUIREMENT | 3.2.2.1.1 | omega_nsp_rad_s | Figure 1 has no Level 3 omega_nsp floor (only the CAP 0.16 line); no bound to encode. | 1 |
| NO-REQUIREMENT | 3.2.2.1.1 | n_alpha_g_per_rad | Figure 3 has no Level 3 n/alpha edge (the CAP 0.096 line extends below n/alpha = 1); no bound to encode. | 1 |
| NOT-IMPLEMENTED | 3.2.2.1.3 | residual_nz_osc_pilot_station_g | residual oscillations in calm air (nz at the pilot station, pitch attitude in mils) need a time simulation with a pilot-station output and a limit-cycle criterion; the bare-airframe linear model has no sustained oscillation where its modes are damped. Not implemented in M6. | 2 |
| NOT-IMPLEMENTED | 3.2.2.1.3 | residual_pitch_attitude_osc_mils | residual oscillations in calm air (nz at the pilot station, pitch attitude in mils) need a time simulation with a pilot-station output and a limit-cycle criterion; the bare-airframe linear model has no sustained oscillation where its modes are damped. Not implemented in M6. | 2 |
| OUT-OF-SIM | 3.2.2.2.1 | Fs_per_n_centerstick_lb_per_g | stick force per g (Table V, center stick and wheel; the F-16 side stick has no numbers in the spec): the NESC F-16 model has no cockpit controller, feel system or force gradients, so no stick or pedal force exists in the simulation. | 3 |
| OUT-OF-SIM | 3.2.2.2.1 | Fs_per_n_wheel_lb_per_g | stick force per g (Table V, center stick and wheel; the F-16 side stick has no numbers in the spec): the NESC F-16 model has no cockpit controller, feel system or force gradients, so no stick or pedal force exists in the simulation. | 3 |
| OUT-OF-SIM | 3.2.2.2.1 | Fs_vs_n_linearity_range_n_g | stick force per g (Table V, center stick and wheel; the F-16 side stick has no numbers in the spec): the NESC F-16 model has no cockpit controller, feel system or force gradients, so no stick or pedal force exists in the simulation. | 3 |
| OUT-OF-SIM | 3.2.2.2.2 | Fs_per_delta_s_centerstick_lb_per_in | pitch force per stick deflection: the NESC F-16 model has no cockpit controller, feel system or force gradients, so no stick or pedal force exists in the simulation. | 2 |
| OUT-OF-SIM | 3.2.2.2.2 | Fs_per_delta_s_sidestick_lb_per_deg | pitch force per stick deflection: the NESC F-16 model has no cockpit controller, feel system or force gradients, so no stick or pedal force exists in the simulation. | 2 |
| OUT-OF-SIM | 3.2.2.3.1 | Fs_over_nz_inverse_amplitude_onehanded_lb_per_g | inverse amplitude of nz per pitch force (dynamic control forces): the NESC F-16 model has no cockpit controller, feel system or force gradients, so no stick or pedal force exists in the simulation. | 3 |
| NOT-IMPLEMENTED | 3.3.2.2 | p_min1_over_p_peak1_percent | roll-rate oscillation ratio after a step roll command: needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6. | 4 |
| NOT-IMPLEMENTED | 3.3.2.2.1 | p_osc_over_p_av | p_osc/p_av against psi_beta (Figure 4): needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6. | 4 |
| NOT-IMPLEMENTED | 3.3.2.3 | phi_osc_over_phi_av | phi_osc/phi_av against psi_beta (Figure 5): needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6. | 4 |
| NOT-IMPLEMENTED | 3.3.2.4 | dbeta_over_k_adverse_deg | sideslip excursion per k (k needs the Table IX roll requirement): needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6. | 3 |
| NOT-IMPLEMENTED | 3.3.2.4 | dbeta_over_k_proverse_deg | sideslip excursion per k (k needs the Table IX roll requirement): needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6. | 3 |
| NOT-IMPLEMENTED | 3.3.2.4.1 | dbeta_over_k_deg_vs_psi_beta | sideslip excursion against psi_beta (Figure 6): needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6. | 3 |
| OUT-OF-SIM | 3.3.2.5 | pedal_force_zero_sideslip_lb | pedal force to hold zero sideslip in rolls: the NESC F-16 model has no cockpit controller, feel system or force gradients, so no stick or pedal force exists in the simulation. | 9 |
| OUT-OF-SIM | 3.3.2.6 | turn_coord_pedal_force_lb | turn-coordination pedal and roll-stick forces: the NESC F-16 model has no cockpit controller, feel system or force gradients, so no stick or pedal force exists in the simulation. | 2 |
| OUT-OF-SIM | 3.3.2.6 | turn_coord_roll_stick_force_lb | turn-coordination pedal and roll-stick forces: the NESC F-16 model has no cockpit controller, feel system or force gradients, so no stick or pedal force exists in the simulation. | 2 |
| NOT-IMPLEMENTED | 3.3.4.1 | t_bank30_VL_s | roll performance (bank angle in a given time, Table IXb): needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6; the speed ranges need V_min, V_max, V_o_min and V_o_max, which the NESC model does not define. | 6 |
| NOT-IMPLEMENTED | 3.3.4.1 | t_bank30_L_s | roll performance (bank angle in a given time, Table IXb): needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6; the speed ranges need V_min, V_max, V_o_min and V_o_max, which the NESC model does not define. | 6 |
| NOT-IMPLEMENTED | 3.3.4.1 | t_bank90_M_s | roll performance (bank angle in a given time, Table IXb): needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6; the speed ranges need V_min, V_max, V_o_min and V_o_max, which the NESC model does not define. | 6 |
| NOT-IMPLEMENTED | 3.3.4.1 | t_bank50_H_s | roll performance (bank angle in a given time, Table IXb): needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6; the speed ranges need V_min, V_max, V_o_min and V_o_max, which the NESC model does not define. | 3 |
| NOT-IMPLEMENTED | 3.3.4.1 | t_bank90_VL_s | roll performance (bank angle in a given time, Table IXb): needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6; the speed ranges need V_min, V_max, V_o_min and V_o_max, which the NESC model does not define. | 3 |
| NOT-IMPLEMENTED | 3.3.4.1 | t_bank90_L_s | roll performance (bank angle in a given time, Table IXb): needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6; the speed ranges need V_min, V_max, V_o_min and V_o_max, which the NESC model does not define. | 3 |
| NOT-IMPLEMENTED | 3.3.4.1 | t_bank90_H_s | roll performance (bank angle in a given time, Table IXb): needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6; the speed ranges need V_min, V_max, V_o_min and V_o_max, which the NESC model does not define. | 3 |
| NOT-IMPLEMENTED | 3.3.4.1 | t_bank30_M_s | roll performance (bank angle in a given time, Table IXb): needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6; the speed ranges need V_min, V_max, V_o_min and V_o_max, which the NESC model does not define. | 3 |
| NOT-IMPLEMENTED | 3.3.4.1 | t_bank30_H_s | roll performance (bank angle in a given time, Table IXb): needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6; the speed ranges need V_min, V_max, V_o_min and V_o_max, which the NESC model does not define. | 3 |
| NOT-IMPLEMENTED | 3.3.4.1.1 | t_bank30_VL_s | roll performance in Flight Phase CO (Tables IXc, IXd; row assignment partly ambiguous, extract 6.2 items 6-7): needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6. | 3 |
| NOT-IMPLEMENTED | 3.3.4.1.1 | t_bank90_L_s | roll performance in Flight Phase CO (Tables IXc, IXd; row assignment partly ambiguous, extract 6.2 items 6-7): needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6. | 1 |
| NOT-IMPLEMENTED | 3.3.4.1.1 | t_bank180_L_s | roll performance in Flight Phase CO (Tables IXc, IXd; row assignment partly ambiguous, extract 6.2 items 6-7): needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6. | 1 |
| NOT-IMPLEMENTED | 3.3.4.1.1 | t_bank360_L_s | roll performance in Flight Phase CO (Tables IXc, IXd; row assignment partly ambiguous, extract 6.2 items 6-7): needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6. | 1 |
| NOT-IMPLEMENTED | 3.3.4.1.1 | t_bank90_M_s | roll performance in Flight Phase CO (Tables IXc, IXd; row assignment partly ambiguous, extract 6.2 items 6-7): needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6. | 3 |
| NOT-IMPLEMENTED | 3.3.4.1.1 | t_bank180_M_s | roll performance in Flight Phase CO (Tables IXc, IXd; row assignment partly ambiguous, extract 6.2 items 6-7): needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6. | 3 |
| NOT-IMPLEMENTED | 3.3.4.1.1 | t_bank360_M_s | roll performance in Flight Phase CO (Tables IXc, IXd; row assignment partly ambiguous, extract 6.2 items 6-7): needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6. | 2 |
| NOT-IMPLEMENTED | 3.3.4.1.1 | t_bank90_H_s | roll performance in Flight Phase CO (Tables IXc, IXd; row assignment partly ambiguous, extract 6.2 items 6-7): needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6. | 3 |
| NOT-IMPLEMENTED | 3.3.4.1.1 | t_bank180_H_s | roll performance in Flight Phase CO (Tables IXc, IXd; row assignment partly ambiguous, extract 6.2 items 6-7): needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6. | 2 |
| NOT-IMPLEMENTED | 3.3.4.1.1 | t_bank360_H_s | roll performance in Flight Phase CO (Tables IXc, IXd; row assignment partly ambiguous, extract 6.2 items 6-7): needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6. | 2 |
| NOT-IMPLEMENTED | 3.3.4.1.1 | t_bank30_L_s | roll performance in Flight Phase CO (Tables IXc, IXd; row assignment partly ambiguous, extract 6.2 items 6-7): needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6. | 2 |
| NOT-IMPLEMENTED | 3.3.4.1.1 | t_bank_loaded30_VL_s | roll performance in Flight Phase CO (Tables IXc, IXd; row assignment partly ambiguous, extract 6.2 items 6-7): needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6. | 3 |
| NOT-IMPLEMENTED | 3.3.4.1.1 | t_bank_loaded50_L_s | roll performance in Flight Phase CO (Tables IXc, IXd; row assignment partly ambiguous, extract 6.2 items 6-7): needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6. | 1 |
| NOT-IMPLEMENTED | 3.3.4.1.1 | t_bank_loaded90_M_s | roll performance in Flight Phase CO (Tables IXc, IXd; row assignment partly ambiguous, extract 6.2 items 6-7): needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6. | 3 |
| NOT-IMPLEMENTED | 3.3.4.1.1 | t_bank_loaded180_M_s | roll performance in Flight Phase CO (Tables IXc, IXd; row assignment partly ambiguous, extract 6.2 items 6-7): needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6. | 3 |
| NOT-IMPLEMENTED | 3.3.4.1.1 | t_bank_loaded50_H_s | roll performance in Flight Phase CO (Tables IXc, IXd; row assignment partly ambiguous, extract 6.2 items 6-7): needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6. | 3 |
| NOT-IMPLEMENTED | 3.3.4.1.1 | t_bank_loaded30_L_s | roll performance in Flight Phase CO (Tables IXc, IXd; row assignment partly ambiguous, extract 6.2 items 6-7): needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6. | 2 |
| NOT-IMPLEMENTED | 3.3.4.1.2 | t_bank_loaded30_VL_s | roll performance in Flight Phase GA with stores (Table IXe): needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6. | 3 |
| NOT-IMPLEMENTED | 3.3.4.1.2 | t_bank_loaded50_L_s | roll performance in Flight Phase GA with stores (Table IXe): needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6. | 1 |
| NOT-IMPLEMENTED | 3.3.4.1.2 | t_bank_loaded90_M_s | roll performance in Flight Phase GA with stores (Table IXe): needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6. | 3 |
| NOT-IMPLEMENTED | 3.3.4.1.2 | t_bank_loaded180_M_s | roll performance in Flight Phase GA with stores (Table IXe): needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6. | 3 |
| NOT-IMPLEMENTED | 3.3.4.1.2 | t_bank_loaded50_H_s | roll performance in Flight Phase GA with stores (Table IXe): needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6. | 3 |
| NOT-IMPLEMENTED | 3.3.4.1.2 | t_bank_loaded30_L_s | roll performance in Flight Phase GA with stores (Table IXe): needs time histories of the response to roll commands (M5-B vital.sim.run exists), plus the command definitions, peak/phase extraction and speed ranges; not implemented in M6. | 2 |
| OUT-OF-SIM | 3.3.4.1.3 | roll_sensitivity_deg_per_s_per_lb | roll sensitivity in deg per second per pound of stick force: the NESC F-16 model has no cockpit controller, feel system or force gradients, so no stick or pedal force exists in the simulation. | 4 |
| OUT-OF-SIM | 3.3.4.3 | roll_stick_force_max_lb | roll stick forces (Table X): the NESC F-16 model has no cockpit controller, feel system or force gradients, so no stick or pedal force exists in the simulation. | 7 |
| PILOT | 3.2.1.1.2 | (qualitative) | trim changes during rapid speed changes must not make the load factor hard to hold (qualitative); no candidate record exists (extract 6.3 H); needs pilot evaluation or an interpretation policy. | 0 |
| PILOT | 3.2.2.3 | (qualitative) | longitudinal pilot-induced oscillation tendency (qualitative, pilot-in-the-loop); no candidate record exists (extract 6.3 H); needs pilot evaluation or an interpretation policy. | 0 |
| PILOT | 3.3.2.1 | (qualitative) | lateral-directional response in atmospheric disturbances must be considered (qualitative); no candidate record exists (extract 6.3 H); needs pilot evaluation or an interpretation policy. | 0 |
| PILOT | 3.3.3 | (qualitative) | lateral-directional pilot-induced oscillation tendency (qualitative, pilot-in-the-loop); no candidate record exists (extract 6.3 H); needs pilot evaluation or an interpretation policy. | 0 |
| PILOT | 3.3.4.4 | (qualitative) | linearity of roll response to roll control (qualitative); no candidate record exists (extract 6.3 H); needs pilot evaluation or an interpretation policy. | 0 |
| OUT-OF-SIM | 3.2.2.2 | (controls free; force and deflection sense) | 3.2.2.2 (p.13): the controls-FIXED "no tendency ... to diverge aperiodically" is curated (lon_divergence_rate_1_s <= 0 at every Level; review R2 B1). Not assessed: the controls-FREE case and "the incremental control force and control deflection ... in the same sense": the NESC F-16 model has no cockpit controller, feel system or force gradients, so no stick or pedal force exists in the simulation. | 0 |
| OUT-OF-SIM | Category C (all curated paragraphs) | (all) | the curated Category C records (terminal phases TO, CT, PA, WO, L) are loaded but reported NOT_ASSESSABLE: the NESC F-16 has no gear, flap or speed-brake configuration, and a clean configuration is not an approach configuration (proposed ADR). | 0 |

## Points
| # | condition | envelope | refine | status | reason | notes (3.1.12 equivalent-system doubts) |
|---|---|---|---|---|---|---|
| 1 | h_ft=5000 mach=0.3 cg_pct_mac=20 | EXTRAPOLATED | 0 | OK |  |  |
| 2 | h_ft=8000 mach=0.3 cg_pct_mac=20 | EXTRAPOLATED | 0 | OK |  |  |
| 3 | h_ft=13000 mach=0.3 cg_pct_mac=20 | EXTRAPOLATED | 0 | OK |  |  |
| 4 | h_ft=21000 mach=0.3 cg_pct_mac=20 | EXTRAPOLATED | 0 | OK |  |  |
| 5 | h_ft=29000 mach=0.3 cg_pct_mac=20 | EXTRAPOLATED | 0 | OK |  | other (UNCLASSIFIED): roll signature failed (largest participation phi) / roll mode: fallback: roll = fastest lateral real root -0.2187 1/s, spiral = slowest -0.08541 1/s; the classifier named them other / spiral (; no roll mode; roll signature failed (largest participation phi)) |
| 6 | h_ft=37000 mach=0.3 cg_pct_mac=20 | EXTRAPOLATED | 0 | INFEASIBLE | not trimmable (residual 0.179): de at lower bound -24 deg; throttle at upper bound 1  |  |
| 7 | h_ft=5000 mach=0.37 cg_pct_mac=20 | EXTRAPOLATED | 0 | OK |  |  |
| 8 | h_ft=8000 mach=0.37 cg_pct_mac=20 | EXTRAPOLATED | 0 | OK |  |  |
| 9 | h_ft=13000 mach=0.37 cg_pct_mac=20 | EXTRAPOLATED | 0 | OK |  |  |
| 10 | h_ft=21000 mach=0.37 cg_pct_mac=20 | EXTRAPOLATED | 0 | OK |  |  |
| 11 | h_ft=29000 mach=0.37 cg_pct_mac=20 | EXTRAPOLATED | 0 | OK |  |  |
| 12 | h_ft=37000 mach=0.37 cg_pct_mac=20 | EXTRAPOLATED | 0 | INFEASIBLE | not trimmable (residual 0.0428): throttle at upper bound 1  |  |
| 13 | h_ft=5000 mach=0.45 cg_pct_mac=20 | IN | 0 | OK |  |  |
| 14 | h_ft=8000 mach=0.45 cg_pct_mac=20 | IN | 0 | OK |  |  |
| 15 | h_ft=13000 mach=0.45 cg_pct_mac=20 | IN | 0 | OK |  |  |
| 16 | h_ft=21000 mach=0.45 cg_pct_mac=20 | EXTRAPOLATED | 0 | OK |  |  |
| 17 | h_ft=29000 mach=0.45 cg_pct_mac=20 | EXTRAPOLATED | 0 | OK |  |  |
| 18 | h_ft=37000 mach=0.45 cg_pct_mac=20 | EXTRAPOLATED | 0 | OK |  |  |
| 19 | h_ft=5000 mach=0.5 cg_pct_mac=20 | IN | 0 | OK |  |  |
| 20 | h_ft=8000 mach=0.5 cg_pct_mac=20 | IN | 0 | OK |  |  |
| 21 | h_ft=13000 mach=0.5 cg_pct_mac=20 | IN | 0 | OK |  |  |
| 22 | h_ft=21000 mach=0.5 cg_pct_mac=20 | EXTRAPOLATED | 0 | OK |  |  |
| 23 | h_ft=29000 mach=0.5 cg_pct_mac=20 | EXTRAPOLATED | 0 | OK |  |  |
| 24 | h_ft=37000 mach=0.5 cg_pct_mac=20 | EXTRAPOLATED | 0 | OK |  |  |
| 25 | h_ft=5000 mach=0.55 cg_pct_mac=20 | IN | 0 | OK |  |  |
| 26 | h_ft=8000 mach=0.55 cg_pct_mac=20 | IN | 0 | OK |  |  |
| 27 | h_ft=13000 mach=0.55 cg_pct_mac=20 | IN | 0 | OK |  |  |
| 28 | h_ft=21000 mach=0.55 cg_pct_mac=20 | EXTRAPOLATED | 0 | OK |  |  |
| 29 | h_ft=29000 mach=0.55 cg_pct_mac=20 | EXTRAPOLATED | 0 | OK |  |  |
| 30 | h_ft=37000 mach=0.55 cg_pct_mac=20 | EXTRAPOLATED | 0 | OK |  |  |
| 31 | h_ft=5000 mach=0.63 cg_pct_mac=20 | EXTRAPOLATED | 0 | OK |  |  |
| 32 | h_ft=8000 mach=0.63 cg_pct_mac=20 | EXTRAPOLATED | 0 | OK |  |  |
| 33 | h_ft=13000 mach=0.63 cg_pct_mac=20 | IN | 0 | OK |  |  |
| 34 | h_ft=21000 mach=0.63 cg_pct_mac=20 | EXTRAPOLATED | 0 | OK |  |  |
| 35 | h_ft=29000 mach=0.63 cg_pct_mac=20 | EXTRAPOLATED | 0 | OK |  |  |
| 36 | h_ft=37000 mach=0.63 cg_pct_mac=20 | EXTRAPOLATED | 0 | OK |  |  |
| 37 | h_ft=5000 mach=0.76 cg_pct_mac=20 | EXTRAPOLATED | 0 | OK |  |  |
| 38 | h_ft=8000 mach=0.76 cg_pct_mac=20 | EXTRAPOLATED | 0 | OK |  |  |
| 39 | h_ft=13000 mach=0.76 cg_pct_mac=20 | EXTRAPOLATED | 0 | OK |  |  |
| 40 | h_ft=21000 mach=0.76 cg_pct_mac=20 | EXTRAPOLATED | 0 | OK |  |  |
| 41 | h_ft=29000 mach=0.76 cg_pct_mac=20 | EXTRAPOLATED | 0 | OK |  |  |
| 42 | h_ft=37000 mach=0.76 cg_pct_mac=20 | EXTRAPOLATED | 0 | OK |  |  |
| 43 | h_ft=5000 mach=0.3 cg_pct_mac=25 | EXTRAPOLATED | 0 | OK |  |  |
| 44 | h_ft=8000 mach=0.3 cg_pct_mac=25 | EXTRAPOLATED | 0 | OK |  |  |
| 45 | h_ft=13000 mach=0.3 cg_pct_mac=25 | EXTRAPOLATED | 0 | OK |  |  |
| 46 | h_ft=21000 mach=0.3 cg_pct_mac=25 | EXTRAPOLATED | 0 | OK |  | other (UNCLASSIFIED): roll signature failed (largest participation phi) / roll mode: fallback: roll = fastest lateral real root -0.6059 1/s, spiral = slowest -0.03179 1/s; the classifier named them other / spiral (; no roll mode; roll signature failed (largest participation phi)) |
| 47 | h_ft=29000 mach=0.3 cg_pct_mac=25 | EXTRAPOLATED | 0 | OK |  | other (UNCLASSIFIED): roll signature failed (largest participation phi) / roll mode: fallback: roll = fastest lateral real root -0.2198 1/s, spiral = slowest -0.09936 1/s; the classifier named them other / spiral (; no roll mode; roll signature failed (largest participation phi)) |
| 48 | h_ft=37000 mach=0.3 cg_pct_mac=25 | EXTRAPOLATED | 0 | INFEASIBLE | not trimmable (residual 0.167): throttle at upper bound 1  |  |
| 49 | h_ft=5000 mach=0.37 cg_pct_mac=25 | EXTRAPOLATED | 0 | OK |  |  |
| 50 | h_ft=8000 mach=0.37 cg_pct_mac=25 | EXTRAPOLATED | 0 | OK |  |  |
| 51 | h_ft=13000 mach=0.37 cg_pct_mac=25 | EXTRAPOLATED | 0 | OK |  |  |
| 52 | h_ft=21000 mach=0.37 cg_pct_mac=25 | EXTRAPOLATED | 0 | OK |  |  |
| 53 | h_ft=29000 mach=0.37 cg_pct_mac=25 | EXTRAPOLATED | 0 | OK |  |  |
| 54 | h_ft=37000 mach=0.37 cg_pct_mac=25 | EXTRAPOLATED | 0 | INFEASIBLE | not trimmable (residual 0.0243): throttle at upper bound 1  |  |
| 55 | h_ft=5000 mach=0.45 cg_pct_mac=25 | IN | 0 | OK |  |  |
| 56 | h_ft=8000 mach=0.45 cg_pct_mac=25 | IN | 0 | OK |  |  |
| 57 | h_ft=13000 mach=0.45 cg_pct_mac=25 | IN | 0 | OK |  |  |
| 58 | h_ft=21000 mach=0.45 cg_pct_mac=25 | EXTRAPOLATED | 0 | OK |  |  |
| 59 | h_ft=29000 mach=0.45 cg_pct_mac=25 | EXTRAPOLATED | 0 | OK |  |  |
| 60 | h_ft=37000 mach=0.45 cg_pct_mac=25 | EXTRAPOLATED | 0 | OK |  |  |
| 61 | h_ft=5000 mach=0.5 cg_pct_mac=25 | IN | 0 | OK |  |  |
| 62 | h_ft=8000 mach=0.5 cg_pct_mac=25 | IN | 0 | OK |  |  |
| 63 | h_ft=13000 mach=0.5 cg_pct_mac=25 | IN | 0 | OK |  |  |
| 64 | h_ft=21000 mach=0.5 cg_pct_mac=25 | EXTRAPOLATED | 0 | OK |  |  |
| 65 | h_ft=29000 mach=0.5 cg_pct_mac=25 | EXTRAPOLATED | 0 | OK |  |  |
| 66 | h_ft=37000 mach=0.5 cg_pct_mac=25 | EXTRAPOLATED | 0 | OK |  |  |
| 67 | h_ft=5000 mach=0.55 cg_pct_mac=25 | IN | 0 | OK |  |  |
| 68 | h_ft=8000 mach=0.55 cg_pct_mac=25 | IN | 0 | OK |  |  |
| 69 | h_ft=13000 mach=0.55 cg_pct_mac=25 | IN | 0 | OK |  |  |
| 70 | h_ft=21000 mach=0.55 cg_pct_mac=25 | EXTRAPOLATED | 0 | OK |  |  |
| 71 | h_ft=29000 mach=0.55 cg_pct_mac=25 | EXTRAPOLATED | 0 | OK |  |  |
| 72 | h_ft=37000 mach=0.55 cg_pct_mac=25 | EXTRAPOLATED | 0 | OK |  |  |
| 73 | h_ft=5000 mach=0.63 cg_pct_mac=25 | EXTRAPOLATED | 0 | OK |  |  |
| 74 | h_ft=8000 mach=0.63 cg_pct_mac=25 | EXTRAPOLATED | 0 | OK |  |  |
| 75 | h_ft=13000 mach=0.63 cg_pct_mac=25 | IN | 0 | OK |  |  |
| 76 | h_ft=21000 mach=0.63 cg_pct_mac=25 | EXTRAPOLATED | 0 | OK |  |  |
| 77 | h_ft=29000 mach=0.63 cg_pct_mac=25 | EXTRAPOLATED | 0 | OK |  |  |
| 78 | h_ft=37000 mach=0.63 cg_pct_mac=25 | EXTRAPOLATED | 0 | OK |  |  |
| 79 | h_ft=5000 mach=0.76 cg_pct_mac=25 | EXTRAPOLATED | 0 | OK |  |  |
| 80 | h_ft=8000 mach=0.76 cg_pct_mac=25 | EXTRAPOLATED | 0 | OK |  |  |
| 81 | h_ft=13000 mach=0.76 cg_pct_mac=25 | EXTRAPOLATED | 0 | OK |  |  |
| 82 | h_ft=21000 mach=0.76 cg_pct_mac=25 | EXTRAPOLATED | 0 | OK |  |  |
| 83 | h_ft=29000 mach=0.76 cg_pct_mac=25 | EXTRAPOLATED | 0 | OK |  |  |
| 84 | h_ft=37000 mach=0.76 cg_pct_mac=25 | EXTRAPOLATED | 0 | OK |  |  |
| 85 | h_ft=5000 mach=0.3 cg_pct_mac=30 | EXTRAPOLATED | 0 | OK |  |  |
| 86 | h_ft=8000 mach=0.3 cg_pct_mac=30 | EXTRAPOLATED | 0 | OK |  |  |
| 87 | h_ft=13000 mach=0.3 cg_pct_mac=30 | EXTRAPOLATED | 0 | OK |  | short_period (NOT_OSCILLATORY): short_period is not oscillatory: real root -1.10255 1/s (no frequency or damping) / short_period (NOT_OSCILLATORY): short_period is not oscillatory: real root 0.142923 1/s (no frequency or damping) / phugoid (OK): the short period is split and this pair has p_w + p_q = 0.39: it may be the coupled "third oscillatory" mode rather than a classical phugoid |
| 88 | h_ft=21000 mach=0.3 cg_pct_mac=30 | EXTRAPOLATED | 0 | OK |  | other (UNCLASSIFIED): roll signature failed (largest participation phi) / roll mode: fallback: roll = fastest lateral real root -0.6205 1/s, spiral = slowest -0.0333 1/s; the classifier named them other / spiral (; no roll mode; roll signature failed (largest participation phi)) |
| 89 | h_ft=29000 mach=0.3 cg_pct_mac=30 | EXTRAPOLATED | 0 | OK |  | other (UNCLASSIFIED): roll signature failed (largest participation phi) / roll mode: fallback: roll = fastest lateral real root -0.2333 1/s, spiral = slowest -0.1027 1/s; the classifier named them other / spiral (; no roll mode; roll signature failed (largest participation phi)) |
| 90 | h_ft=37000 mach=0.3 cg_pct_mac=30 | EXTRAPOLATED | 0 | NOT_CONVERGED | residual 0.159 after 4 attempt(s) is above the tolerance 1e-09, with no unknown on a bound |  |
| 91 | h_ft=5000 mach=0.37 cg_pct_mac=30 | EXTRAPOLATED | 0 | OK |  |  |
| 92 | h_ft=8000 mach=0.37 cg_pct_mac=30 | EXTRAPOLATED | 0 | OK |  |  |
| 93 | h_ft=13000 mach=0.37 cg_pct_mac=30 | EXTRAPOLATED | 0 | OK |  |  |
| 94 | h_ft=21000 mach=0.37 cg_pct_mac=30 | EXTRAPOLATED | 0 | OK |  | short_period (NOT_OSCILLATORY): short_period is not oscillatory: real root -1.08164 1/s (no frequency or damping) / short_period (NOT_OSCILLATORY): short_period is not oscillatory: real root 0.159867 1/s (no frequency or damping) / phugoid (OK): the short period is split and this pair has p_w + p_q = 0.33: it may be the coupled "third oscillatory" mode rather than a classical phugoid |
| 95 | h_ft=29000 mach=0.37 cg_pct_mac=30 | EXTRAPOLATED | 0 | OK |  |  |
| 96 | h_ft=37000 mach=0.37 cg_pct_mac=30 | EXTRAPOLATED | 0 | INFEASIBLE | not trimmable (residual 0.012): throttle at upper bound 1  |  |
| 97 | h_ft=5000 mach=0.45 cg_pct_mac=30 | IN | 0 | OK |  |  |
| 98 | h_ft=8000 mach=0.45 cg_pct_mac=30 | IN | 0 | OK |  |  |
| 99 | h_ft=13000 mach=0.45 cg_pct_mac=30 | IN | 0 | OK |  |  |
| 100 | h_ft=21000 mach=0.45 cg_pct_mac=30 | EXTRAPOLATED | 0 | OK |  |  |
| 101 | h_ft=29000 mach=0.45 cg_pct_mac=30 | EXTRAPOLATED | 0 | OK |  | short_period (NOT_OSCILLATORY): short_period is not oscillatory: real root -1.03698 1/s (no frequency or damping) / short_period (NOT_OSCILLATORY): short_period is not oscillatory: real root 0.186232 1/s (no frequency or damping) / phugoid (OK): the short period is split and this pair has p_w + p_q = 0.27: it may be the coupled "third oscillatory" mode rather than a classical phugoid |
| 102 | h_ft=37000 mach=0.45 cg_pct_mac=30 | EXTRAPOLATED | 0 | OK |  |  |
| 103 | h_ft=5000 mach=0.5 cg_pct_mac=30 | IN | 0 | OK |  |  |
| 104 | h_ft=8000 mach=0.5 cg_pct_mac=30 | IN | 0 | OK |  |  |
| 105 | h_ft=13000 mach=0.5 cg_pct_mac=30 | IN | 0 | OK |  |  |
| 106 | h_ft=21000 mach=0.5 cg_pct_mac=30 | EXTRAPOLATED | 0 | OK |  |  |
| 107 | h_ft=29000 mach=0.5 cg_pct_mac=30 | EXTRAPOLATED | 0 | OK |  |  |
| 108 | h_ft=37000 mach=0.5 cg_pct_mac=30 | EXTRAPOLATED | 0 | OK |  | short_period (NOT_OSCILLATORY): short_period is not oscillatory: real root -0.892098 1/s (no frequency or damping) / short_period (NOT_OSCILLATORY): short_period is not oscillatory: real root 0.202912 1/s (no frequency or damping) / phugoid (OK): the short period is split and this pair has p_w + p_q = 0.24: it may be the coupled "third oscillatory" mode rather than a classical phugoid |
| 109 | h_ft=5000 mach=0.55 cg_pct_mac=30 | IN | 0 | OK |  |  |
| 110 | h_ft=8000 mach=0.55 cg_pct_mac=30 | IN | 0 | OK |  |  |
| 111 | h_ft=13000 mach=0.55 cg_pct_mac=30 | IN | 0 | OK |  |  |
| 112 | h_ft=21000 mach=0.55 cg_pct_mac=30 | EXTRAPOLATED | 0 | OK |  |  |
| 113 | h_ft=29000 mach=0.55 cg_pct_mac=30 | EXTRAPOLATED | 0 | OK |  |  |
| 114 | h_ft=37000 mach=0.55 cg_pct_mac=30 | EXTRAPOLATED | 0 | OK |  | short_period (NOT_OSCILLATORY): short_period is not oscillatory: real root -0.986755 1/s (no frequency or damping) / short_period (NOT_OSCILLATORY): short_period is not oscillatory: real root 0.225063 1/s (no frequency or damping) / phugoid (OK): the short period is split and this pair has p_w + p_q = 0.21: it may be the coupled "third oscillatory" mode rather than a classical phugoid |
| 115 | h_ft=5000 mach=0.63 cg_pct_mac=30 | EXTRAPOLATED | 0 | OK |  |  |
| 116 | h_ft=8000 mach=0.63 cg_pct_mac=30 | EXTRAPOLATED | 0 | OK |  |  |
| 117 | h_ft=13000 mach=0.63 cg_pct_mac=30 | IN | 0 | OK |  |  |
| 118 | h_ft=21000 mach=0.63 cg_pct_mac=30 | EXTRAPOLATED | 0 | OK |  |  |
| 119 | h_ft=29000 mach=0.63 cg_pct_mac=30 | EXTRAPOLATED | 0 | OK |  |  |
| 120 | h_ft=37000 mach=0.63 cg_pct_mac=30 | EXTRAPOLATED | 0 | OK |  |  |
| 121 | h_ft=5000 mach=0.76 cg_pct_mac=30 | EXTRAPOLATED | 0 | OK |  |  |
| 122 | h_ft=8000 mach=0.76 cg_pct_mac=30 | EXTRAPOLATED | 0 | OK |  |  |
| 123 | h_ft=13000 mach=0.76 cg_pct_mac=30 | EXTRAPOLATED | 0 | OK |  |  |
| 124 | h_ft=21000 mach=0.76 cg_pct_mac=30 | EXTRAPOLATED | 0 | OK |  |  |
| 125 | h_ft=29000 mach=0.76 cg_pct_mac=30 | EXTRAPOLATED | 0 | OK |  |  |
| 126 | h_ft=37000 mach=0.76 cg_pct_mac=30 | EXTRAPOLATED | 0 | OK |  |  |
| 127 | h_ft=6500 mach=0.3 cg_pct_mac=20 | EXTRAPOLATED | 1 | OK |  |  |
| 128 | h_ft=5000 mach=0.335 cg_pct_mac=20 | EXTRAPOLATED | 1 | OK |  |  |
| 129 | h_ft=6500 mach=0.335 cg_pct_mac=20 | EXTRAPOLATED | 1 | OK |  |  |
| 130 | h_ft=5000 mach=0.3 cg_pct_mac=22.5 | EXTRAPOLATED | 1 | OK |  |  |
| 131 | h_ft=6500 mach=0.3 cg_pct_mac=22.5 | EXTRAPOLATED | 1 | OK |  |  |
| 132 | h_ft=5000 mach=0.335 cg_pct_mac=22.5 | EXTRAPOLATED | 1 | OK |  |  |
| 133 | h_ft=6500 mach=0.335 cg_pct_mac=22.5 | EXTRAPOLATED | 1 | OK |  |  |
| 134 | h_ft=25000 mach=0.3 cg_pct_mac=20 | EXTRAPOLATED | 1 | OK |  | other (UNCLASSIFIED): roll signature failed (largest participation phi) / roll mode: fallback: roll = fastest lateral real root -0.3963 1/s, spiral = slowest -0.04737 1/s; the classifier named them other / spiral (; no roll mode; roll signature failed (largest participation phi)) |
| 135 | h_ft=33000 mach=0.3 cg_pct_mac=20 | EXTRAPOLATED | 1 | INFEASIBLE | not trimmable (residual 0.0797): throttle at upper bound 1  |  |
| 136 | h_ft=25000 mach=0.335 cg_pct_mac=20 | EXTRAPOLATED | 1 | OK |  |  |
| 137 | h_ft=29000 mach=0.335 cg_pct_mac=20 | EXTRAPOLATED | 1 | OK |  | other (UNCLASSIFIED): roll signature failed (largest participation phi) / roll mode: fallback: roll = fastest lateral real root -0.4081 1/s, spiral = slowest -0.03923 1/s; the classifier named them other / spiral (; no roll mode; roll signature failed (largest participation phi)) |
| 138 | h_ft=33000 mach=0.335 cg_pct_mac=20 | EXTRAPOLATED | 1 | OK |  | other (UNCLASSIFIED): roll signature failed (largest participation phi) / roll mode: fallback: roll = fastest lateral real root -0.2283 1/s, spiral = slowest -0.07014 1/s; the classifier named them other / spiral (; no roll mode; roll signature failed (largest participation phi)) |
| 139 | h_ft=25000 mach=0.3 cg_pct_mac=22.5 | EXTRAPOLATED | 1 | OK |  | other (UNCLASSIFIED): roll signature failed (largest participation phi) / roll mode: fallback: roll = fastest lateral real root -0.4048 1/s, spiral = slowest -0.04934 1/s; the classifier named them other / spiral (; no roll mode; roll signature failed (largest participation phi)) |
| 140 | h_ft=29000 mach=0.3 cg_pct_mac=22.5 | EXTRAPOLATED | 1 | OK |  | other (UNCLASSIFIED): roll signature failed (largest participation phi) / roll mode: fallback: roll = fastest lateral real root -0.2136 1/s, spiral = slowest -0.09713 1/s; the classifier named them other / spiral (; no roll mode; roll signature failed (largest participation phi)) |
| 141 | h_ft=33000 mach=0.3 cg_pct_mac=22.5 | EXTRAPOLATED | 1 | INFEASIBLE | not trimmable (residual 0.0722): throttle at upper bound 1  |  |
| 142 | h_ft=25000 mach=0.335 cg_pct_mac=22.5 | EXTRAPOLATED | 1 | OK |  |  |
| 143 | h_ft=29000 mach=0.335 cg_pct_mac=22.5 | EXTRAPOLATED | 1 | OK |  | other (UNCLASSIFIED): roll signature failed (largest participation phi) / roll mode: fallback: roll = fastest lateral real root -0.4148 1/s, spiral = slowest -0.04056 1/s; the classifier named them other / spiral (; no roll mode; roll signature failed (largest participation phi)) |
| 144 | h_ft=33000 mach=0.335 cg_pct_mac=22.5 | EXTRAPOLATED | 1 | OK |  | other (UNCLASSIFIED): roll signature failed (largest participation phi) / roll mode: fallback: roll = fastest lateral real root -0.2339 1/s, spiral = slowest -0.07247 1/s; the classifier named them other / spiral (; no roll mode; roll signature failed (largest participation phi)) |
| 145 | h_ft=33000 mach=0.695 cg_pct_mac=20 | EXTRAPOLATED | 1 | OK |  |  |
| 146 | h_ft=37000 mach=0.695 cg_pct_mac=20 | EXTRAPOLATED | 1 | OK |  |  |
| 147 | h_ft=33000 mach=0.76 cg_pct_mac=20 | EXTRAPOLATED | 1 | OK |  |  |
| 148 | h_ft=33000 mach=0.695 cg_pct_mac=22.5 | EXTRAPOLATED | 1 | OK |  |  |
| 149 | h_ft=37000 mach=0.695 cg_pct_mac=22.5 | EXTRAPOLATED | 1 | OK |  |  |
| 150 | h_ft=33000 mach=0.76 cg_pct_mac=22.5 | EXTRAPOLATED | 1 | OK |  |  |
| 151 | h_ft=37000 mach=0.76 cg_pct_mac=22.5 | EXTRAPOLATED | 1 | OK |  |  |
| 152 | h_ft=33000 mach=0.475 cg_pct_mac=22.5 | EXTRAPOLATED | 1 | OK |  |  |
| 153 | h_ft=37000 mach=0.475 cg_pct_mac=22.5 | EXTRAPOLATED | 1 | OK |  |  |
| 154 | h_ft=33000 mach=0.5 cg_pct_mac=22.5 | EXTRAPOLATED | 1 | OK |  |  |
| 155 | h_ft=37000 mach=0.5 cg_pct_mac=22.5 | EXTRAPOLATED | 1 | OK |  |  |
| 156 | h_ft=33000 mach=0.525 cg_pct_mac=22.5 | EXTRAPOLATED | 1 | OK |  |  |
| 157 | h_ft=37000 mach=0.525 cg_pct_mac=22.5 | EXTRAPOLATED | 1 | OK |  |  |
| 158 | h_ft=33000 mach=0.475 cg_pct_mac=25 | EXTRAPOLATED | 1 | OK |  |  |
| 159 | h_ft=37000 mach=0.475 cg_pct_mac=25 | EXTRAPOLATED | 1 | OK |  |  |
| 160 | h_ft=33000 mach=0.5 cg_pct_mac=25 | EXTRAPOLATED | 1 | OK |  |  |
| 161 | h_ft=33000 mach=0.525 cg_pct_mac=25 | EXTRAPOLATED | 1 | OK |  |  |
| 162 | h_ft=37000 mach=0.525 cg_pct_mac=25 | EXTRAPOLATED | 1 | OK |  |  |
| 163 | h_ft=33000 mach=0.475 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | OK |  |  |
| 164 | h_ft=37000 mach=0.475 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | OK |  |  |
| 165 | h_ft=33000 mach=0.5 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | OK |  |  |
| 166 | h_ft=37000 mach=0.5 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | OK |  |  |
| 167 | h_ft=33000 mach=0.525 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | OK |  |  |
| 168 | h_ft=37000 mach=0.525 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | OK |  |  |
| 169 | h_ft=10500 mach=0.3 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | OK |  |  |
| 170 | h_ft=13000 mach=0.3 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | OK |  |  |
| 171 | h_ft=17000 mach=0.3 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | OK |  |  |
| 172 | h_ft=10500 mach=0.335 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | OK |  |  |
| 173 | h_ft=13000 mach=0.335 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | OK |  |  |
| 174 | h_ft=17000 mach=0.335 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | OK |  |  |
| 175 | h_ft=10500 mach=0.3 cg_pct_mac=30 | EXTRAPOLATED | 1 | OK |  | short_period (NOT_OSCILLATORY): short_period is not oscillatory: real root -1.18112 1/s (no frequency or damping) / short_period (NOT_OSCILLATORY): short_period is not oscillatory: real root 0.139576 1/s (no frequency or damping) / phugoid (OK): the short period is split and this pair has p_w + p_q = 0.39: it may be the coupled "third oscillatory" mode rather than a classical phugoid |
| 176 | h_ft=17000 mach=0.3 cg_pct_mac=30 | EXTRAPOLATED | 1 | OK |  | short_period (NOT_OSCILLATORY): short_period is not oscillatory: real root -0.985275 1/s (no frequency or damping) / short_period (NOT_OSCILLATORY): short_period is not oscillatory: real root 0.146776 1/s (no frequency or damping) / phugoid (OK): the short period is split and this pair has p_w + p_q = 0.38: it may be the coupled "third oscillatory" mode rather than a classical phugoid |
| 177 | h_ft=10500 mach=0.335 cg_pct_mac=30 | EXTRAPOLATED | 1 | OK |  |  |
| 178 | h_ft=13000 mach=0.335 cg_pct_mac=30 | EXTRAPOLATED | 1 | OK |  |  |
| 179 | h_ft=17000 mach=0.335 cg_pct_mac=30 | EXTRAPOLATED | 1 | OK |  | short_period (NOT_OSCILLATORY): short_period is not oscillatory: real root -1.09908 1/s (no frequency or damping) / short_period (NOT_OSCILLATORY): short_period is not oscillatory: real root 0.150412 1/s (no frequency or damping) / phugoid (OK): the short period is split and this pair has p_w + p_q = 0.36: it may be the coupled "third oscillatory" mode rather than a classical phugoid |
| 180 | h_ft=25000 mach=0.3 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | OK |  | other (UNCLASSIFIED): roll signature failed (largest participation phi) / roll mode: fallback: roll = fastest lateral real root -0.4222 1/s, spiral = slowest -0.05275 1/s; the classifier named them other / spiral (; no roll mode; roll signature failed (largest participation phi)) |
| 181 | h_ft=29000 mach=0.3 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | OK |  | other (UNCLASSIFIED): roll signature failed (largest participation phi) / roll mode: fallback: roll = fastest lateral real root -0.2264 1/s, spiral = slowest -0.1012 1/s; the classifier named them other / spiral (; no roll mode; roll signature failed (largest participation phi)) |
| 182 | h_ft=33000 mach=0.3 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | INFEASIBLE | not trimmable (residual 0.057): throttle at upper bound 1  |  |
| 183 | h_ft=25000 mach=0.335 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | OK |  |  |
| 184 | h_ft=29000 mach=0.335 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | OK |  | other (UNCLASSIFIED): roll signature failed (largest participation phi) / roll mode: fallback: roll = fastest lateral real root -0.4253 1/s, spiral = slowest -0.04237 1/s; the classifier named them other / spiral (; no roll mode; roll signature failed (largest participation phi)) |
| 185 | h_ft=33000 mach=0.335 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | OK |  | other (UNCLASSIFIED): roll signature failed (largest participation phi) / roll mode: fallback: roll = fastest lateral real root -0.2462 1/s, spiral = slowest -0.07626 1/s; the classifier named them other / spiral (; no roll mode; roll signature failed (largest participation phi)) |
| 186 | h_ft=25000 mach=0.3 cg_pct_mac=30 | EXTRAPOLATED | 1 | OK |  | other (UNCLASSIFIED): roll signature failed (largest participation phi) / roll mode: fallback: roll = fastest lateral real root -0.4277 1/s, spiral = slowest -0.05373 1/s; the classifier named them other / spiral (; no roll mode; roll signature failed (largest participation phi)) |
| 187 | h_ft=33000 mach=0.3 cg_pct_mac=30 | EXTRAPOLATED | 1 | INFEASIBLE | not trimmable (residual 0.053): throttle at upper bound 1  |  |
| 188 | h_ft=25000 mach=0.335 cg_pct_mac=30 | EXTRAPOLATED | 1 | OK |  |  |
| 189 | h_ft=29000 mach=0.335 cg_pct_mac=30 | EXTRAPOLATED | 1 | OK |  | other (UNCLASSIFIED): roll signature failed (largest participation phi) / roll mode: fallback: roll = fastest lateral real root -0.4306 1/s, spiral = slowest -0.04321 1/s; the classifier named them other / spiral (; no roll mode; roll signature failed (largest participation phi)) |
| 190 | h_ft=33000 mach=0.335 cg_pct_mac=30 | EXTRAPOLATED | 1 | OK |  | other (UNCLASSIFIED): roll signature failed (largest participation phi) / roll mode: fallback: roll = fastest lateral real root -0.2526 1/s, spiral = slowest -0.07781 1/s; the classifier named them other / spiral (; no roll mode; roll signature failed (largest participation phi)) |
| 191 | h_ft=25000 mach=0.41 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | OK |  |  |
| 192 | h_ft=29000 mach=0.41 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | OK |  |  |
| 193 | h_ft=33000 mach=0.41 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | OK |  |  |
| 194 | h_ft=25000 mach=0.45 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | OK |  |  |
| 195 | h_ft=29000 mach=0.45 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | OK |  |  |
| 196 | h_ft=33000 mach=0.45 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | OK |  |  |
| 197 | h_ft=25000 mach=0.475 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | OK |  |  |
| 198 | h_ft=29000 mach=0.475 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | OK |  |  |
| 199 | h_ft=25000 mach=0.41 cg_pct_mac=30 | EXTRAPOLATED | 1 | OK |  | short_period (NOT_OSCILLATORY): short_period is not oscillatory: real root -1.06565 1/s (no frequency or damping) / short_period (NOT_OSCILLATORY): short_period is not oscillatory: real root 0.172056 1/s (no frequency or damping) / phugoid (OK): the short period is split and this pair has p_w + p_q = 0.30: it may be the coupled "third oscillatory" mode rather than a classical phugoid |
| 200 | h_ft=29000 mach=0.41 cg_pct_mac=30 | EXTRAPOLATED | 1 | OK |  | short_period (NOT_OSCILLATORY): short_period is not oscillatory: real root -0.941878 1/s (no frequency or damping) / short_period (NOT_OSCILLATORY): short_period is not oscillatory: real root 0.17426 1/s (no frequency or damping) / phugoid (OK): the short period is split and this pair has p_w + p_q = 0.30: it may be the coupled "third oscillatory" mode rather than a classical phugoid |
| 201 | h_ft=33000 mach=0.41 cg_pct_mac=30 | EXTRAPOLATED | 1 | OK |  | short_period (NOT_OSCILLATORY): short_period is not oscillatory: real root -0.829138 1/s (no frequency or damping) / short_period (NOT_OSCILLATORY): short_period is not oscillatory: real root 0.173495 1/s (no frequency or damping) / phugoid (OK): the short period is split and this pair has p_w + p_q = 0.30: it may be the coupled "third oscillatory" mode rather than a classical phugoid |
| 202 | h_ft=25000 mach=0.45 cg_pct_mac=30 | EXTRAPOLATED | 1 | OK |  |  |
| 203 | h_ft=33000 mach=0.45 cg_pct_mac=30 | EXTRAPOLATED | 1 | OK |  | short_period (NOT_OSCILLATORY): short_period is not oscillatory: real root -0.912875 1/s (no frequency or damping) / short_period (NOT_OSCILLATORY): short_period is not oscillatory: real root 0.186328 1/s (no frequency or damping) / phugoid (OK): the short period is split and this pair has p_w + p_q = 0.27: it may be the coupled "third oscillatory" mode rather than a classical phugoid |
| 204 | h_ft=25000 mach=0.475 cg_pct_mac=30 | EXTRAPOLATED | 1 | OK |  |  |
| 205 | h_ft=29000 mach=0.475 cg_pct_mac=30 | EXTRAPOLATED | 1 | OK |  |  |
| 206 | h_ft=33000 mach=0.475 cg_pct_mac=30 | EXTRAPOLATED | 1 | OK |  | short_period (NOT_OSCILLATORY): short_period is not oscillatory: real root -0.965851 1/s (no frequency or damping) / short_period (NOT_OSCILLATORY): short_period is not oscillatory: real root 0.195262 1/s (no frequency or damping) / phugoid (OK): the short period is split and this pair has p_w + p_q = 0.25: it may be the coupled "third oscillatory" mode rather than a classical phugoid |
| 207 | h_ft=33000 mach=0.55 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | OK |  |  |
| 208 | h_ft=37000 mach=0.55 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | OK |  |  |
| 209 | h_ft=33000 mach=0.59 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | OK |  |  |
| 210 | h_ft=37000 mach=0.59 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | OK |  |  |
| 211 | h_ft=33000 mach=0.525 cg_pct_mac=30 | EXTRAPOLATED | 1 | OK |  |  |
| 212 | h_ft=37000 mach=0.525 cg_pct_mac=30 | EXTRAPOLATED | 1 | OK |  | short_period (NOT_OSCILLATORY): short_period is not oscillatory: real root -0.939295 1/s (no frequency or damping) / short_period (NOT_OSCILLATORY): short_period is not oscillatory: real root 0.213604 1/s (no frequency or damping) / phugoid (OK): the short period is split and this pair has p_w + p_q = 0.22: it may be the coupled "third oscillatory" mode rather than a classical phugoid |
| 213 | h_ft=33000 mach=0.55 cg_pct_mac=30 | EXTRAPOLATED | 1 | OK |  |  |
| 214 | h_ft=33000 mach=0.59 cg_pct_mac=30 | EXTRAPOLATED | 1 | OK |  |  |
| 215 | h_ft=37000 mach=0.59 cg_pct_mac=30 | EXTRAPOLATED | 1 | OK |  |  |
| 216 | h_ft=25000 mach=0.695 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | OK |  |  |
| 217 | h_ft=29000 mach=0.695 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | OK |  |  |
| 218 | h_ft=33000 mach=0.695 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | OK |  |  |
| 219 | h_ft=25000 mach=0.76 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | OK |  |  |
| 220 | h_ft=29000 mach=0.76 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | OK |  |  |
| 221 | h_ft=33000 mach=0.76 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | OK |  |  |
| 222 | h_ft=25000 mach=0.695 cg_pct_mac=30 | EXTRAPOLATED | 1 | OK |  |  |
| 223 | h_ft=29000 mach=0.695 cg_pct_mac=30 | EXTRAPOLATED | 1 | OK |  |  |
| 224 | h_ft=33000 mach=0.695 cg_pct_mac=30 | EXTRAPOLATED | 1 | OK |  |  |
| 225 | h_ft=25000 mach=0.76 cg_pct_mac=30 | EXTRAPOLATED | 1 | OK |  |  |
| 226 | h_ft=33000 mach=0.76 cg_pct_mac=30 | EXTRAPOLATED | 1 | OK |  |  |
| 227 | h_ft=37000 mach=0.695 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | OK |  |  |
| 228 | h_ft=37000 mach=0.76 cg_pct_mac=27.5 | EXTRAPOLATED | 1 | OK |  |  |
| 229 | h_ft=37000 mach=0.695 cg_pct_mac=30 | EXTRAPOLATED | 1 | OK |  |  |
