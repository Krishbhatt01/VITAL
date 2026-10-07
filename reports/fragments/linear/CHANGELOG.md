## M5-A increment: linearization and flight modes (agent `linear`, 2026-09-29)

| Step | Result | Evidence |
|---|---|---|
| RED increment | 28 new tests (tLinearJacobian 6, tF16Linearize 9, tModes 6, tF16Modes 7), all RED_EXPECTED; 217 earlier tests PASS; 0 regression, 0 vacuous, 0 excluded | `reports/work/linear/M5_red_linear.txt` |
| GREEN | 245/245 pass (M0-M4 + M5-A), 0 excluded, 148 s; the M5-A classes take about 9 s in total | `reports/work/linear/M5_green_linear.txt` |
| Sabotage | S5L-1..5 all DETECTED (every listed target failed), tree unchanged | `reports/work/linear/M5_sabotage_linear.txt` |
| Extra sabotages (proposed, not registered: 2-5 rule) | S5LX-1 kink check skipped, S5LX-2 raw eigenvector magnitude instead of participation, S5LX-3 n_alpha without sin(gamma0): all DETECTED | `reports/work/linear/M5_sabotage_linearextra.txt` |

New:
- `vital.linear.jacobian`: the step study (FC-506), with breakpoint/kink detection (proposed FC-510).
- `vital.linear.linearize`: provides
  - A and B for 12 states and 4 inputs, with the lon/lat partitions
  - the [V alpha q theta] and [beta p r phi] forms
  - n_alpha and inputRange.
- `vital.linear.modes`: the participation-factor classifier (FC-507).
- `vital.linear.modeTable`.
- `run_f16_modes`.

Changed: `vital.aircraft.f16.config` now sets `limits.da_deg = [-21.5 21.5]` and `limits.dr_deg = [-30 30]`, from the NESC control-law scaling (F16_control.dml:1117-1185). No M3/M4 test changed result (the trim does not use da or dr).

**F-16 flight modes** (REG: no published F-16 eigenvalues are available to VITAL). Conditions: 10,013 ft, g = 32.174 ft/s^2, flat Earth, zero wind.

| Condition | Short period wn / zeta | Phugoid period / zeta | Dutch roll wn / zeta | Roll tau | Spiral lambda | n_alpha |
|---|---|---|---|---|---|---|
| 565.6854 ft/s, CG 25 % (README trim) | 2.503 rad/s / 0.452 (-1.1313 +/- 2.2332i) | 84.38 s / 0.095 (-0.0071 +/- 0.0745i) | 3.318 rad/s / 0.117 (-0.3887 +/- 3.2955i) | 0.338 s (-2.9564) | -0.0101 (stable, t_half 68.5 s) | 14.90 g/rad |
| 565.6854 ft/s, CG 30 % | 1.777 / 0.564 | 91.33 s / 0.091 | 3.171 / 0.118 | 0.337 s | -0.0113 | 14.90 |
| 700 ft/s, CG 25 % | 3.095 / 0.449 | 104.99 s / 0.148 | 3.957 / 0.113 | 0.264 s | -0.0089 | 22.80 |

Participation at the README trim:
- short period: w + q = 0.999
- phugoid: u + theta = 0.988
- Dutch roll: (v + r) - (p + phi) = 0.88
- roll: largest participation in p
- spiral: largest participation in phi

**Pre-registered trends held:**
- CG aft (25 to 30 %) lowers the short-period wn, from 2.50 to 1.78 rad/s.
- 700 ft/s raises it, from 2.50 to 3.09 rad/s.
- The hand estimates in the tF16Modes header predicted: short period 2.6 rad/s with zeta 0.35, Dutch roll 2.9 rad/s, roll tau 0.33 s, phugoid 78 s.

## M5-X increment: linear vs nonlinear cross-check and closed-loop linearization (agent `linear`, 2026-09-29)

| Step | Result | Evidence |
|---|---|---|
| RED increment | 11 new tests (tLinearVsNonlinear 4, tClosedLoopLinearize 7), all RED_EXPECTED; 275 PASS; 0 regression, 0 vacuous, 0 excluded | `reports/work/linear/M5_red_linear2.txt` |
| GREEN | 286/286 pass, 0 excluded (Baseline: the M5-A classes plus tSimCore, tSimGuards, tF16Sim) | `reports/work/linear/M5_green_linear2.txt` |
| Sabotage | S5L-1..8 all DETECTED; every listed target failed. "Tree unchanged: 0" is from parallel agents editing. | `reports/work/linear/M5_sabotage_linear.txt` |

**New code:**
- `vital.linear.toPlantState`, `fromPlantState` (maps between x_lin and the plant state) and `response` (expm propagation).
- `modes(..., 'IncludeHeight', true)`: 9 states with h; adds a 'height' mode.
- `linearize(..., 'Controller', c)`: closed loop with a static controller (K, Kref, open).

**Linear vs nonlinear** at the README trim. Nonlinear: vital.sim.run with RK4. Linear: expm(A t).

| Case | Perturbation | Window | Relative discrepancy (base amplitude) | Ratio rel(a)/rel(a/2) | Registered ratio band |
|---|---|---|---|---|---|
| SP | dw = -1.5 m/s (d alpha -0.5 deg) | 6 s, dt 0.01 | w 3.0e-4, q 7.9e-4, theta 2.2e-3 | 1.960, 1.974, 1.997 | [1.6, 2.4] |
| PH | du = +1 m/s | 90 s, dt 0.05 | u 1.6e-3, theta 2.4e-3, h 1.4e-3 | 1.999, 2.000, 2.001 | [1.6, 2.4] |
| LAT | dv = 1.5 m/s, dp = 2 deg/s | 10 s, dt 0.01 | v 9.9e-5, p 1.6e-4, r 1.3e-4, phi 1.8e-4 | 4.003, 4.003, 4.003, 4.002 | [3.2, 4.8] |

- **Lateral ratio of 4:** predicted before running. The NESC model is mirror-symmetric, so the lateral remainder is third order.
- **Symmetry:** the SP case keeps v, p, r and phi exactly 0.

**Dominant mode of the nonlinear signal** (matrix pencil) vs vital.linear.modes:

| Mode | Signal | Nonlinear estimate | modes() eigenvalue | Error in wd | Error in sigma |
|---|---|---|---|---|---|
| SP | q | -1.13039 + 2.23051i | -1.1313 + 2.2332i | -0.12 % | -0.08 % |
| PH | u | -0.006259 + 0.080094i | -0.0062405 + 0.080081i (IncludeHeight) | +0.016 % | +0.3 % |
| DR | v | -0.388758 + 3.29558i | -0.38875 + 3.2955i | 0.003 % | 0.002 % |

- The DR wd from zero crossings of v is 3.2993 rad/s (+0.12 %).
- The 8-state phugoid wd (0.0745) is 7.03 % below the nonlinear value. This is the registered height-coupling bias (band 5-10 %).

**Closed loop** at the README trim:

| Check | Result |
|---|---|
| State feedback: A_cl vs A + B K | max error / tolerance 0.039 |
| State feedback: K and Kref | K exact to 1e-8; Kref = I |
| State feedback: B_cl vs B | equal |
| y-path alpha feedback: K(de, u), K(de, w) | -Ka w0/V^2, Ka u0/V^2 to 1e-8; A_cl error / tolerance 5.3e-4 |
| Inert controller | K = 0 exactly; A_cl = A_open exactly |
| Pitch damper de = +Kq q | see below |

Pitch damper short period by gain:

| Kq | Short-period eigenvalue | wn (rad/s) | zeta |
|---|---|---|---|
| -0.2 | -0.1141 + 2.1535i | 2.157 | 0.053 |
| 0 | -1.1313 + 2.2332i | 2.503 | 0.452 |
| +0.2 | -2.1478 + 1.8087i | 2.808 | 0.765 |

The damping moves in the registered direction (CONVENTIONS 7).

Refusals: `vital:linear:dynamicController`, `vital:linear:controllerNotAtTrim`, `vital:badInput`.

## Review R1 fixes (agent `linear`, 2026-09-30)

| Step | Result | Evidence |
|---|---|---|
| RED | gateOK. 3 RED_EXPECTED (new functions eulerRates and nAlphaSteady); 11 RED_SUSPICIOUS (bug-fix tests of existing functions, each failing on the registered check that shows the defect); 28 VACUOUS (guards of existing behaviour that R1's escaped mutations showed were untested, plus the unchanged tests of the two modified classes); 0 regression, 0 excluded | `reports/work/linear/M5_red_linear3.txt` |
| GREEN | 328/328 pass, 0 excluded. Increment: tLinearizeR1, tJacobianR1, tModesR1, tClosedLoopR1, tClosedLoopSimAgreement, tF16Linearize, tF16Modes. Baseline: tLinearJacobian, tModes, tLinearVsNonlinear, tClosedLoopLinearize, tSimCore, tSimGuards, tF16Sim, tSimR1 | `reports/work/linear/M5_green_linear3.txt` |
| Sabotage | parts linear (8) + linearR1 (22): 30/30 DETECTED, tree unchanged 1 (quiet tree) | `reports/work/linear/M5_sabotage_linear_linearR1.txt` |

**Measured values:**
- **Equilibrium residual** at the README trim: 3.2e-16. A trim made at CG 25 % and linearized with the CG 30 % aircraft, or with g = 9.80665, is refused.
- **n_alpha_ss** (MIL n/alpha):

| Condition | n_alpha_ss | vital.fq.metrics | Difference |
|---|---|---|---|
| README trim | 14.76587 g/rad | same | < 1.5e-9 relative |
| CG 30 % | 15.36679 g/rad | same | < 1.5e-9 relative |

  R1's independent value at the README trim is 14.766. The alpha partial n_alpha is 14.9009.
- **Euler rates** at phi 30 deg, theta 10 deg, w = [.3 -.2 .1]: [0.2976377 -0.2232051 -0.01360414], matching the quaternion-derived rates within 1e-8. The Jacobian matches the analytic partials within 1e-8.
- **20,000 ft:** only column 12 is KINK. The 8-state modes are OK and IncludeHeight is refused.
- **Roll:** tau / (-1/L_p') = 1.0292 (registered band 5 %).
- **Spiral:** tau / (a1/a0) = 0.9959 (band 2 %).
- **README mode table** locked to 1e-6 relative.
- **Closed loop:**
  - Prefilter: Kref = 2I; B_cl error / tolerance 4.9e-9.
  - nz feedback: Kref(de,de) = 1.09825 = 1/(1 - Knz g_de). The pre-ADR-026 semantics gave K 9 % low (0.0621 vs 0.0682 in the RED run).
  - Sim vs linearization, nz controller:

| Channel | e(dt = 0.005) | e(0.01) / e(0.005) |
|---|---|---|
| w | 3.6e-3 | 2.011 |
| q | 5.5e-3 | 1.994 |

    The ratio of 2 shows the difference is first order in dt, i.e. from sampling.
- **Wind converters:** match the finite difference within 7e-9.
- **gamma0 fallback:** 5 deg to 1e-9.
- **Lon/lat cross blocks:** exactly 0.
