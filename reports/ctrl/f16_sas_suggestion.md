# Design feedback: pitch SAS and yaw damper gains for the NESC F-16

vital.ctrl.suggestGains; every Level is a REG result of the VITAL chain (no published F-16 Level exists).
Only in-envelope points count (NESC validity envelope, a stated judgment; conditions_f16.json).

**Status: TARGET_REACHED.** confirmed by re-assessment with Kq = 0.02, Ka = 0.14, Kr = 0.82

## Proposed gains (rounded to 0.01; confirmed by a fresh vital.fq.assess)
| gain | value | unit | search box |
|---|---|---|---|
| Kq | 0.02 | s | [0, 0.4] |
| Ka | 0.14 | rad/rad | [0, 1] |
| Kr | 0.82 | s | [0, 1.5] |

## Targets (in-envelope headline Levels)
| group | target | bare Level | bare margin | bare critical | augmented Level (confirmed) | margin | critical | reached |
|---|---|---|---|---|---|---|---|---|
| 3.2.2.1.1-CatA | 1 | 2 | -0.2799 | MIL-F-8785C-3.2.2.1.1-CAP-L1-CatA at h_ft=13000 mach=0.63 cg_pct_mac=30 | 1 | 0.05125 | MIL-F-8785C-3.2.2.1.1-CAP-L1-CatA at h_ft=13000 mach=0.45 cg_pct_mac=30 | 1 |
| 3.3.1.1-CatA-other | 1 | 2 | -0.4285 | MIL-F-8785C-3.3.1.1-zeta_d-L1-CatA-other at h_ft=13000 mach=0.63 cg_pct_mac=20 | 1 | 1.218 | MIL-F-8785C-3.3.1.1-zeta_d-L1-CatA-other at h_ft=13000 mach=0.45 cg_pct_mac=20 | 1 |
| 3.3.1.1-CatA-COGA | 1 | 2 | -0.7285 | MIL-F-8785C-3.3.1.1-zeta_d-L1-CatA-COGA at h_ft=13000 mach=0.63 cg_pct_mac=20 | 1 | 0.05376 | MIL-F-8785C-3.3.1.1-zeta_d-L1-CatA-COGA at h_ft=13000 mach=0.45 cg_pct_mac=20 | 1 |

## Protected groups (must keep their bare Level)
| group | bare Level | augmented Level | regressed |
|---|---|---|---|
| 3.2.1.1-CatA | 1 | 1 | 0 |
| 3.2.1.1-CatB | 1 | 1 | 0 |
| 3.2.1.2-CatA | 1 | 1 | 0 |
| 3.2.1.2-CatB | 1 | 1 | 0 |
| 3.2.2.1.1-CatB | 1 | 1 | 0 |
| 3.2.2.1.2-CatA | 1 | 1 | 0 |
| 3.2.2.1.2-CatB | 1 | 1 | 0 |
| 3.2.2.2-CatA | 1 | 1 | 0 |
| 3.2.2.2-CatB | 1 | 1 | 0 |
| 3.3.1.1-CatB | 1 | 1 | 0 |
| 3.3.1.2-CatA | 1 | 1 | 0 |
| 3.3.1.2-CatB | 1 | 1 | 0 |
| 3.3.1.3-CatA | 1 | 1 | 0 |
| 3.3.1.3-CatB | 1 | 1 | 0 |
| 3.3.1.4-CatA-COGA | 1 | 1 | 0 |
| 3.3.1.4-CatA-other | 1 | 1 | 0 |

## Sensitivities (forward differences through the whole chain; d margin / d gain)

Iteration 1 at [0 0 0]

| constraint | margin | req | d/dKq | d/dKa | d/dKr | critical (record at condition) | switches with |
|---|---|---|---|---|---|---|---|
| target:3.2.2.1.1-CatA | -0.2799 | 0.05 | 1.667 | 2.173 | -3.331e-14 | MIL-F-8785C-3.2.2.1.1-CAP-L1-CatA at h_ft=13000 mach=0.63 cg_pct_mac=30 | Kq |
| target:3.3.1.1-CatA-other | -0.4285 | 0.05 | -2.706e-13 | -1.665e-14 | 3.188 | MIL-F-8785C-3.3.1.1-zeta_d-L1-CatA-other at h_ft=13000 mach=0.63 cg_pct_mac=20 | Kr |
| target:3.3.1.1-CatA-COGA | -0.7285 | 0.05 | -1.388e-13 | -5.551e-15 | 1.514 | MIL-F-8785C-3.3.1.1-zeta_d-L1-CatA-COGA at h_ft=13000 mach=0.63 cg_pct_mac=20 | Kr |
| protect:3.2.1.1-CatA | 0.0111 | 0.005552 | -8.881e-06 | 4.789e-06 | 0 | MIL-F-8785C-3.2.1.1-speed_divergence_rate_1_s-L1-CatA at h_ft=13000 mach=0.45 cg_pct_mac=30 |  |
| protect:3.2.1.1-CatB | 0.0111 | 0.005552 | -8.881e-06 | 4.789e-06 | 0 | MIL-F-8785C-3.2.1.1-speed_divergence_rate_1_s-L1-CatB at h_ft=13000 mach=0.45 cg_pct_mac=30 |  |
| protect:3.2.1.2-CatA | 0.3691 | 0.025 | 0.7396 | 1.004 | -5.089e-13 | MIL-F-8785C-3.2.1.2-zeta_p-L1-CatA at h_ft=13000 mach=0.45 cg_pct_mac=30 |  |
| protect:3.2.1.2-CatB | 0.3691 | 0.025 | 0.7396 | 1.004 | -5.089e-13 | MIL-F-8785C-3.2.1.2-zeta_p-L1-CatB at h_ft=13000 mach=0.45 cg_pct_mac=30 |  |
| protect:3.2.2.1.1-CatB | 1.372 | 0.025 | 5.492 | 7.159 | -1.036e-13 | MIL-F-8785C-3.2.2.1.1-CAP-L1-CatB at h_ft=13000 mach=0.63 cg_pct_mac=30 | Kq |
| protect:3.2.2.1.2-CatA | 0.09977 | 0.025 | 3.483 | -0.4946 | -2.637e-14 | MIL-F-8785C-3.2.2.1.2-zeta_sp-L1-CatA at h_ft=13000 mach=0.45 cg_pct_mac=20 |  |
| protect:3.2.2.1.2-CatB | 0.2831 | 0.025 | 4.064 | -0.577 | -2.961e-14 | MIL-F-8785C-3.2.2.1.2-zeta_sp-L1-CatB at h_ft=13000 mach=0.45 cg_pct_mac=20 |  |
| protect:3.2.2.2-CatA | 0.0111 | 0.005552 | -8.881e-06 | 4.789e-06 | 0 | MIL-F-8785C-3.2.2.2-lon_divergence_rate_1_s-L1-CatA at h_ft=13000 mach=0.45 cg_pct_mac=30 |  |
| protect:3.2.2.2-CatB | 0.0111 | 0.005552 | -8.881e-06 | 4.789e-06 | 0 | MIL-F-8785C-3.2.2.2-lon_divergence_rate_1_s-L1-CatB at h_ft=13000 mach=0.45 cg_pct_mac=30 |  |
| protect:3.3.1.1-CatB | 0.3573 | 0.025 | -6.453e-13 | -4.163e-14 | 7.57 | MIL-F-8785C-3.3.1.1-zeta_d-L1-CatB at h_ft=13000 mach=0.63 cg_pct_mac=20 | Kr |
| protect:3.3.1.2-CatA | 0.5333 | 0.025 | -4.163e-14 | -2.22e-14 | 0.005242 | MIL-F-8785C-3.3.1.2-tau_R_s-L1-CatA at h_ft=13000 mach=0.45 cg_pct_mac=20 |  |
| protect:3.3.1.2-CatB | 0.6666 | 0.025 | -4.163e-14 | -1.665e-14 | 0.003744 | MIL-F-8785C-3.3.1.2-tau_R_s-L1-CatB at h_ft=13000 mach=0.45 cg_pct_mac=20 |  |
| protect:3.3.1.3-CatA | Inf | 0.025 | NaN | NaN | NaN | MIL-F-8785C-3.3.1.3-spiral_T2_s-L1-CatA at h_ft=5000 mach=0.45 cg_pct_mac=20 |  |
| protect:3.3.1.3-CatB | Inf | 0.025 | NaN | NaN | NaN | MIL-F-8785C-3.3.1.3-spiral_T2_s-L1-CatB at h_ft=5000 mach=0.45 cg_pct_mac=20 |  |
| protect:3.3.1.4-CatA-COGA | 0 | 0 | 0 | 0 | 0 | MIL-F-8785C-3.3.1.4-coupled_roll_spiral_present-L1-CatA-COGA at h_ft=5000 mach=0.45 cg_pct_mac=20 |  |
| protect:3.3.1.4-CatA-other | 0 | 0 | 0 | 0 | 0 | MIL-F-8785C-3.3.1.4-coupled_roll_spiral_present-L1-CatA-other at h_ft=5000 mach=0.45 cg_pct_mac=20 |  |

Iteration 2 at [0.01703 0.1387 0.5142]

| constraint | margin | req | d/dKq | d/dKa | d/dKr | critical (record at condition) | switches with |
|---|---|---|---|---|---|---|---|
| target:3.2.2.1.1-CatA | 0.04413 | 0.05 | 1.464 | 2.146 | -3.955e-14 | MIL-F-8785C-3.2.2.1.1-CAP-L1-CatA at h_ft=13000 mach=0.45 cg_pct_mac=30 |  |
| target:3.3.1.1-CatA-other | 0.6276 | 0.05 | 1.11e-13 | -1.277e-13 | 1.943 | MIL-F-8785C-3.3.1.1-zeta_d-L1-CatA-other at h_ft=13000 mach=0.45 cg_pct_mac=20 |  |
| target:3.3.1.1-CatA-COGA | -0.2269 | 0.05 | 5.204e-14 | -6.245e-14 | 0.923 | MIL-F-8785C-3.3.1.1-zeta_d-L1-CatA-COGA at h_ft=13000 mach=0.45 cg_pct_mac=20 |  |
| protect:3.2.1.1-CatA | 0.0111 | 0.005552 | -5.634e-06 | 2.224e-06 | -2.486e-15 | MIL-F-8785C-3.2.1.1-speed_divergence_rate_1_s-L1-CatA at h_ft=13000 mach=0.45 cg_pct_mac=30 |  |
| protect:3.2.1.1-CatB | 0.0111 | 0.005552 | -5.634e-06 | 2.224e-06 | -2.486e-15 | MIL-F-8785C-3.2.1.1-speed_divergence_rate_1_s-L1-CatB at h_ft=13000 mach=0.45 cg_pct_mac=30 |  |
| protect:3.2.1.2-CatA | 0.49 | 0.025 | -0.05007 | 0.6672 | 5.607e-13 | MIL-F-8785C-3.2.1.2-zeta_p-L1-CatA at h_ft=13000 mach=0.45 cg_pct_mac=30 |  |
| protect:3.2.1.2-CatB | 0.49 | 0.025 | -0.05007 | 0.6672 | 5.607e-13 | MIL-F-8785C-3.2.1.2-zeta_p-L1-CatB at h_ft=13000 mach=0.45 cg_pct_mac=30 |  |
| protect:3.2.2.1.1-CatB | 2.439 | 0.025 | 4.821 | 7.069 | -1.332e-13 | MIL-F-8785C-3.2.2.1.1-CAP-L1-CatB at h_ft=13000 mach=0.45 cg_pct_mac=30 |  |
| protect:3.2.2.1.2-CatA | 0.09287 | 0.025 | 3.275 | -0.4259 | -2.082e-14 | MIL-F-8785C-3.2.2.1.2-zeta_sp-L1-CatA at h_ft=13000 mach=0.45 cg_pct_mac=20 |  |
| protect:3.2.2.1.2-CatB | 0.275 | 0.025 | 3.821 | -0.4969 | -2.591e-14 | MIL-F-8785C-3.2.2.1.2-zeta_sp-L1-CatB at h_ft=13000 mach=0.45 cg_pct_mac=20 |  |
| protect:3.2.2.2-CatA | 0.0111 | 0.005552 | -5.634e-06 | 2.224e-06 | -2.486e-15 | MIL-F-8785C-3.2.2.2-lon_divergence_rate_1_s-L1-CatA at h_ft=13000 mach=0.45 cg_pct_mac=30 |  |
| protect:3.2.2.2-CatB | 0.0111 | 0.005552 | -5.634e-06 | 2.224e-06 | -2.486e-15 | MIL-F-8785C-3.2.2.2-lon_divergence_rate_1_s-L1-CatB at h_ft=13000 mach=0.45 cg_pct_mac=30 |  |
| protect:3.3.1.1-CatB | 2.865 | 0.025 | 2.776e-13 | -3.109e-13 | 4.615 | MIL-F-8785C-3.3.1.1-zeta_d-L1-CatB at h_ft=13000 mach=0.45 cg_pct_mac=20 |  |
| protect:3.3.1.2-CatA | 0.5366 | 0.025 | 6.939e-14 | -2.22e-14 | 0.008082 | MIL-F-8785C-3.3.1.2-tau_R_s-L1-CatA at h_ft=13000 mach=0.45 cg_pct_mac=20 |  |
| protect:3.3.1.2-CatB | 0.669 | 0.025 | 5.551e-14 | -1.665e-14 | 0.005773 | MIL-F-8785C-3.3.1.2-tau_R_s-L1-CatB at h_ft=13000 mach=0.45 cg_pct_mac=20 |  |
| protect:3.3.1.3-CatA | Inf | 0.025 | NaN | NaN | NaN | MIL-F-8785C-3.3.1.3-spiral_T2_s-L1-CatA at h_ft=5000 mach=0.45 cg_pct_mac=20 |  |
| protect:3.3.1.3-CatB | Inf | 0.025 | NaN | NaN | NaN | MIL-F-8785C-3.3.1.3-spiral_T2_s-L1-CatB at h_ft=5000 mach=0.45 cg_pct_mac=20 |  |
| protect:3.3.1.4-CatA-COGA | 0 | 0 | 0 | 0 | 0 | MIL-F-8785C-3.3.1.4-coupled_roll_spiral_present-L1-CatA-COGA at h_ft=5000 mach=0.45 cg_pct_mac=20 |  |
| protect:3.3.1.4-CatA-other | 0 | 0 | 0 | 0 | 0 | MIL-F-8785C-3.3.1.4-coupled_roll_spiral_present-L1-CatA-other at h_ft=5000 mach=0.45 cg_pct_mac=20 |  |

Iteration 3 at [0.0173 0.1413 0.8142]

| constraint | margin | req | d/dKq | d/dKa | d/dKr | critical (record at condition) | switches with |
|---|---|---|---|---|---|---|---|
| target:3.2.2.1.1-CatA | 0.05 | 0.05 | 1.464 | 2.146 | -6.592e-14 | MIL-F-8785C-3.2.2.1.1-CAP-L1-CatA at h_ft=13000 mach=0.45 cg_pct_mac=30 |  |
| target:3.3.1.1-CatA-other | 1.207 | 0.05 | -2.776e-14 | 1.221e-13 | 1.922 | MIL-F-8785C-3.3.1.1-zeta_d-L1-CatA-other at h_ft=13000 mach=0.45 cg_pct_mac=20 |  |
| target:3.3.1.1-CatA-COGA | 0.04849 | 0.05 | -1.735e-14 | 5.551e-14 | 0.9128 | MIL-F-8785C-3.3.1.1-zeta_d-L1-CatA-COGA at h_ft=13000 mach=0.45 cg_pct_mac=20 |  |
| protect:3.2.1.1-CatA | 0.0111 | 0.005552 | -5.596e-06 | 2.199e-06 | 6.476e-15 | MIL-F-8785C-3.2.1.1-speed_divergence_rate_1_s-L1-CatA at h_ft=13000 mach=0.45 cg_pct_mac=30 |  |
| protect:3.2.1.1-CatB | 0.0111 | 0.005552 | -5.596e-06 | 2.199e-06 | 6.476e-15 | MIL-F-8785C-3.2.1.1-speed_divergence_rate_1_s-L1-CatB at h_ft=13000 mach=0.45 cg_pct_mac=30 |  |
| protect:3.2.1.2-CatA | 0.4917 | 0.025 | -0.05721 | 0.6624 | -7.92e-13 | MIL-F-8785C-3.2.1.2-zeta_p-L1-CatA at h_ft=13000 mach=0.45 cg_pct_mac=30 |  |
| protect:3.2.1.2-CatB | 0.4917 | 0.025 | -0.05721 | 0.6624 | -7.92e-13 | MIL-F-8785C-3.2.1.2-zeta_p-L1-CatB at h_ft=13000 mach=0.45 cg_pct_mac=30 |  |
| protect:3.2.2.1.1-CatB | 2.459 | 0.025 | 4.821 | 7.069 | -2.22e-13 | MIL-F-8785C-3.2.2.1.1-CAP-L1-CatB at h_ft=13000 mach=0.45 cg_pct_mac=30 |  |
| protect:3.2.2.1.2-CatA | 0.09268 | 0.025 | 3.271 | -0.4248 | -2.128e-14 | MIL-F-8785C-3.2.2.1.2-zeta_sp-L1-CatA at h_ft=13000 mach=0.45 cg_pct_mac=20 |  |
| protect:3.2.2.1.2-CatB | 0.2748 | 0.025 | 3.817 | -0.4956 | -2.405e-14 | MIL-F-8785C-3.2.2.1.2-zeta_sp-L1-CatB at h_ft=13000 mach=0.45 cg_pct_mac=20 |  |
| protect:3.2.2.2-CatA | 0.0111 | 0.005552 | -5.596e-06 | 2.199e-06 | 6.476e-15 | MIL-F-8785C-3.2.2.2-lon_divergence_rate_1_s-L1-CatA at h_ft=13000 mach=0.45 cg_pct_mac=30 |  |
| protect:3.2.2.2-CatB | 0.0111 | 0.005552 | -5.596e-06 | 2.199e-06 | 6.476e-15 | MIL-F-8785C-3.2.2.2-lon_divergence_rate_1_s-L1-CatB at h_ft=13000 mach=0.45 cg_pct_mac=30 |  |
| protect:3.3.1.1-CatB | 4.242 | 0.025 | -1.11e-13 | 2.665e-13 | 4.564 | MIL-F-8785C-3.3.1.1-zeta_d-L1-CatB at h_ft=13000 mach=0.45 cg_pct_mac=20 |  |
| protect:3.3.1.2-CatA | 0.5394 | 0.025 | 5.551e-14 | 5.551e-15 | 0.01099 | MIL-F-8785C-3.3.1.2-tau_R_s-L1-CatA at h_ft=13000 mach=0.45 cg_pct_mac=20 |  |
| protect:3.3.1.2-CatB | 0.671 | 0.025 | 2.776e-14 | 0 | 0.007849 | MIL-F-8785C-3.3.1.2-tau_R_s-L1-CatB at h_ft=13000 mach=0.45 cg_pct_mac=20 |  |
| protect:3.3.1.3-CatA | Inf | 0.025 | NaN | NaN | NaN | MIL-F-8785C-3.3.1.3-spiral_T2_s-L1-CatA at h_ft=5000 mach=0.45 cg_pct_mac=20 |  |
| protect:3.3.1.3-CatB | Inf | 0.025 | NaN | NaN | NaN | MIL-F-8785C-3.3.1.3-spiral_T2_s-L1-CatB at h_ft=5000 mach=0.45 cg_pct_mac=20 |  |
| protect:3.3.1.4-CatA-COGA | 0 | 0 | 0 | 0 | 0 | MIL-F-8785C-3.3.1.4-coupled_roll_spiral_present-L1-CatA-COGA at h_ft=5000 mach=0.45 cg_pct_mac=20 |  |
| protect:3.3.1.4-CatA-other | 0 | 0 | 0 | 0 | 0 | MIL-F-8785C-3.3.1.4-coupled_roll_spiral_present-L1-CatA-other at h_ft=5000 mach=0.45 cg_pct_mac=20 |  |

## Search history
| k | merit | accepted | note |
|---|---|---|---|
| [0 0 0] | 1.587 | 1 | start |
| [0.01703 0.1387 0.5142] | 0.2828 | 1 | iteration 1, step fraction 1 |
| [0.0173 0.1413 0.8142] | 0.001512 | 1 | iteration 2, step fraction 1 |
| [0.01731 0.1413 0.8159] | 0 | 1 | iteration 3, step fraction 1 |

## Equivalent-system flags (MIL-F-8785C 3.1.12)
None: at every confirmed point the closed-loop modes are the five classical modes, all OK.

search: every constraint holds after 3 iterations
