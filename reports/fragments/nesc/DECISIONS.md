# Proposed ADRs (agent `nesc`, M5-C: rotating Earth and the NESC atmospheric check-cases)

Written on 2026-09-29 **before any NESC comparison run** (the only data looked at beforehand were the CSV t = 0 rows and the headers, to check the definitions cited below). None of these changes a band, a tolerance or an expected value of `docs/NESC_CASE_MATRIX.json`.

## ADR-N1: Rotating-Earth state and equations (ECEF formulation)
- **State** of `vital.plant.derivativesRotating` (13): `x = [r_e (3) m; v_e (3) m/s; q_be (4); w_bi (3) rad/s]`
  - `r_e` CM position in ECEF; `v_e` CM velocity **relative to ECEF**, ECEF axes
  - `q_be` scalar-first quaternion ECEF -> body (C_be = quat2dcm(q_be))
  - `w_bi` body angular rate **relative to inertial space**, body axes
- **Equations** (`vital.eom.rotatingRigidBody`):
  - `rdot_e = v_e`
  - `vdot_e = C_eb F_b/m + g(r_e) - 2 w x v_e - w x (w x r_e)` with `w = [0 0 omega_E]`
  - `qdot_be = 1/2 Omega(w_be) q_be + k (1 - q'q) q_be`, `w_be = w_bi - C_be w`, k = 1 1/s (CONVENTIONS 3)
  - `J wdot_bi = M_cg - w_bi x J w_bi`
- **Why:** no explicit time dependence, so the plant keeps the M3 signature `[xdot, y] = f(x, u, AC, env)` and runs unchanged through `vital.sim.run`. ECI is recovered as `C_ei(t) = R3(omega t)`: ECI and ECEF coincide at t = 0 (TM Vol II p.603).
- **Environment** `env`: `earth` ('wgs84' | 'sphere' | a constants struct), `rotation` (logical), `gravity` ('J2' | 'central'), `wind_n`, `windGradient_n`, `deltaT`. Every field is required; a missing one is `vital:badInput` (no silent default).

## ADR-N2: Gravitation in the EOM; localGravity is its magnitude
- The rotating EOM uses **gravitation** (J2 for WGS-84, inverse square for the sphere); the centrifugal and Coriolis terms come from the EOM (CONVENTIONS 4).
- The NESC output `localGravity_ft_s2` is the **magnitude** of the gravitation vector. Checked at t = 0 against the CSVs before registration: case 11 SIM 4/5 32.1885754492 ft/s^2 equals |g| to 2e-11, while the geodetic-down component is 32.1885318 (4.4e-5 lower); case 1 and case 10 agree with both.

## ADR-N3: Rates used by the aerodynamics
- Aerodynamic damping (brick Clp/Cmq/Cnr; F-16 rate derivatives) uses the body rate **relative to the Earth-fixed airmass**, `w_be = w_bi - C_be w_ie`. The atmosphere rotates with the Earth; rotation relative to the air is what the damping physics needs.
- Consistency check made before registration: SIM 5's case-11 yaw moment at t = 0 (0.388 ft lbf) is of the size of Cnr times the Earth-relative yaw rate (about 0.3 ft lbf with rough coefficients); the inertial rate would give about 1.3 ft lbf and local-level rates 0.

## ADR-N4: Initial body rates
- Cases 1-10: the matrix field `rate_inertial_body_deg_s` (XLSX rows 23-25), which the CSVs report at t = 0 (`bodyAngularRateWrtEi`).
- F-16 cases: `w_bi = C_bn (w_ie^n + w_en^n)` with the transport rate `w_en^n = [v_E/(R_N+h), -v_N/(R_M+h), -v_E tan(lat)/(R_N+h)]`: the aircraft holds its Euler angles relative to local level. This is SIM 5's definition (TM Vol II p.228); it reproduces SIM 5's t = 0 rates to 10 digits in cases 11, 15 and 16 (checked with an independent Python evaluation).

## ADR-N5: NESC-environment trim of the F-16 (`vital.nesc.f16Trim`)
1. `vital.trim.solve` (alpha, de, throttle; wings level, beta = 0) with `env.g = vital.geo.levelFlightGravity(lat, lon, h, v_ned)` (proven for case 11 by `tF16Trim/rotatingEarthExplainsNescTrim`).
2. Map to the rotating state: position (lat, lon, h), NED velocity from the case, Euler (0, theta, course), rates per N4.
3. Polish (theta, de, throttle) by Newton iterations on the rotating plant until the NED-frame acceleration `dv_n/dt = C_ne vdot_e - w_en x v_n` has zero body-x and body-z components and the body pitch acceleration is zero (scaled residual < 1e-10: g and rad/s^2). Aileron and rudder stay 0 (the TM varies "pitch attitude, elevator position, and throttle setting", V2 p.62).
- Status: OK, NOT_CONVERGED, or OUT_OF_DATA_ENVELOPE when a table input is clamped. **Case 12 is accepted with OUT_OF_DATA_ENVELOPE** because the model is run as published on the subsonic tables (ADR-014); no other case may be.
- Why polish: the rate terms of N3/N4 give pitching moments of ~1 ft lbf that a flat trim ignores; SIM 5's case-11 pitching moment at t = 0 is -0.0019 ft lbf.

## ADR-N6: Execution of the NESC control laws (`vital.nesc.f16Controller`)
- **Rate (first choice, SUPERSEDED by ADR-N6r below):** 50 Hz, zero-order hold (the rate is NOT FOUND in the TM, which lists "a different execution rate for the control law" as a source of spread, V2 p.282/p.296). 50 Hz is a typical digital flight-control rate and lets every F-16 case run at dt = 0.02 s with one sample per step (runtime budget, N11).
- **Command timing:** a step at t_s takes effect at the first sample with t >= t_s (the sample at t_s itself), within 1e-9 s.
- **LQR reference states:** replaced by VITAL's trim, as SIM 5 did (TM V2 p.256). The DML constants cannot be inputs, so the substitution is implemented as exact input shifts: `alpha_in = alpha - alpha_trim + trimmedAlpha`, `theta_in = theta - theta_trim + trimmedTheta`, and (AP off only) `Vequiv_in = Vequiv - KEAS_trim + trimmedKEAS`. `trimmedPilotControl_long = -de_trim/25 deg`, `trimmedPilotControl_throttle = throttle_trim`.
- **KEAS:** `EAS = TAS sqrt(rho/rho0)`, rho0 = US 1976 sea-level density; in knots (kt = 1852/3600 m/s). It gives 287.98 KEAS at the case-11 IC, the TM's "trim solver's speed of 287.98 KEAS" (V2 p.256).
- **Rates fed to the law (first choice, SUPERSEDED by ADR-N6c):** body rates relative to the local NED frame, `w_bn = w_bi - C_bn (w_ie + w_en)`. The LQR was designed on a flat-earth model, whose body rates are relative to local level ("perfect state feedback", README). With inertial rates, the steady 3-nm circle of case 15 (inertial yaw rate 1.76 deg/s from the transport rate alone) would carry a spurious rudder and aileron bias.
- **Baseline commands:** altitude = trim altitude; KEAS = trim KEAS; course 45 deg with lateralDeviationError 0 (13.1-13.3). 13.1: +100 ft at 5 s. 13.2: -5 KEAS at 5 s (TM value; SIM 2 used -10 but is excluded). 13.3: course 60 deg from 15 s.
- **ADR-N6b (cases 15/16):** alt/KEAS commands are NOT FOUND in the TM; per ADR-014 they are recovered from the initial condition (10,000 ft, trim KEAS) and labelled `recovered`. AP and SAS on from the first sample.

## ADR-N7: Case 13.4 lateral-offset logic
- `lateralDeviationError = 0` for t < 20 s; for t >= 20 s it is `d - 2000 ft`, where `d` is the cross-track distance (+right) of the aircraft from the **rhumb line** through the initial position at the 45 deg base course.
- `d` is computed exactly in Mercator coordinates of the ellipsoid (longitude, isometric latitude): the perpendicular offset of the point from the straight line, times the local scale `(N + h) cos(lat)` evaluated at the latitude midway between the point and the foot of the perpendicular (`vital.nesc.crossTrack`).
- **Why a rhumb line:** before 20 s the autopilot holds the true course `chi = beta + psi` = 45 deg, i.e. it flies a loxodrome; the "original course" is therefore the loxodrome. A local tangent-plane line would drift from it by ~2 m over 10 km, and a spherical flat-plane approximation (the GNC's `deg_to_ft`) mis-states a 45 deg course by 0.13 deg on the ellipsoid.

## ADR-N8: Comparison mechanics (`vital.nesc.compare`)
- Reference samples are truncated to [0, duration] (sim 5 13.x files run to 60 / 239.9 s with float32 time stamps; sim 2 cases 11/12 to 200 s).
- VITAL is linearly interpolated onto each simulation's own time stamps; the residual `ref_s - VITAL` goes to `vital.verify.envelopeCheck` with the band exactly as in the JSON, `tBase` = the first included simulation's times, `refScale` = max |ref| over the included simulations.
- Angle residuals (Euler angles, longitude) are wrapped to (-180, 180] deg (TM eq. 37 does the same). 179.9 vs -179.9 deg is a 0.2 deg difference.
- A simulation without the column is skipped; if no included simulation records a band signal, the signal is `NOT_ASSESSABLE` with its reason, and the test **fails** on it (it is never skipped).
- A VITAL run that stopped before the duration fails every signal.

## ADR-N9: Vehicles and coefficient overrides (cases 1-10)
- Cannonball and brick masses, inertias and aero from `cannonball_*.dml` and `brick_*.dml`, compiled by `vital.nesc.generateModels` into `+vital/+models/+nesc`.
- Case 1: CD = 0. Case 2: CD = Cl = Cm = Cn = 0 (TM: "all the aerodynamic coefficient values in Table 5 to zero"; every CSV force and moment is 0). Case 3: CD = 0 with the published damping. Cases 4-10: as published (CD = 0.1).
- Drag acts along -v_air: `F_b = -qbar S CD v_air/|v_air|`, zero at zero airspeed. The brick's VRW is clamped at 0.5 ft/s by its own `minValue` (compiled as a saturation); `qbar` uses the true airspeed.
- Cases 2/3 start at 30,000 ft (ADR-008).

## ADR-N10: Wind (cases 7 and 8)
- Earth-fixed, horizontal, expressed in local NED: `w_n = wind_n + windGradient_n h`, h geometric height above the ellipsoid (no geoid is modelled).
- Case 7: 20 ft/s from the west, `wind_n = [0 +20 0] ft/s`. Case 8: East = (0.003 h_ft - 20) ft/s, so `wind_n = [0 -20 0] ft/s` and `windGradient_n = [0 0.003 0] 1/s`.
- `v_air = C_bn (v_n - w_n)`.

## ADR-N11: Step sizes and step-size study
- Cases 1-10: RK4 dt = 0.01 s. F-16: dt = 0.02 s, control law every step (50 Hz).
- **Registered criterion:** `max_t |VITAL(dt) - VITAL(dt')| / delta(t) <= 0.1` at every compared reference time, for every band signal:
  - cases 1-10: dt' = 0.02 s, full 30 s
  - cases 11, 12: dt' = 0.04 s, full 180 s
  - autopilot cases 13.x, 15, 16: dt' = 0.01 s (control law still 50 Hz, two steps per sample), over min(30 s, duration), which holds every commanded step
- Why: runtime. The rotating F-16 plant costs about 1.1 ms per call. The full F-16 set is 850 s of simulated time, and the study has to fit in the ~8-minute M5-C budget. With dt' = 2 dt and an integrator of order >= 1, the dt error is at most the measured change; with dt' = dt/2 it is at most the change times 2^p/(2^p - 1).

## ADR-N6r: The NESC control law is evaluated as a continuous-time static feedback (supersedes the 50 Hz rate of N6)
- **What happened:** with the 50 Hz ZOH of N6, cases 13.1-13.4, 15 and 16 fell outside their bands in 7-19 signals each, always in the transients after a command step or at engagement. Before and after the transients VITAL tracked SIM 4/5 closely (e.g. case 13.3 roll 30.0 deg, heading 59.92 deg at 30 s; case 15 L(0) = -225.8298 vs SIM 5 -225.8300 ft lbf).
- **Diagnosis (13.3, the rate is the only change; dt = 1/rate):** worst roll excess 2.60 deg at 50 Hz, 1.28 at 100 Hz, 0.30 at 200 Hz, 0.10 at 500 Hz; pitch-rate excess falls similarly. The response converges monotonically towards SIM 4/5 as the law is sampled faster: SIM 4 and 5 behave like the continuous-time limit. The transient is a saturated, high-gain roll loop (full aileron, |p| ~ 150 deg/s), where a sample-and-hold delay changes the overshoot.
- **Signs, units and definitions checked and not the cause** (NESC_EXTRACT_F16.md risks 8-16): the steady states agree (bank limit +30 deg, final course, Type-0 altitude offset), which rules out sign errors in ail ("left roll" = VITAL da, tF16Plant), rdr (TEL), baseChiCmd, latOffset or chiEst; the trim references, KEAS and "> 0.5" logic are hand-tested (tF16ControlLaw).
- **Decision:** the law has no dynamic states, so it is evaluated at every plant evaluation (every RK4 stage) through `AC.stageControl` of `vital.plant.derivativesRotating`. Commands enter as plant inputs `[altCmd_ft; keasCmd; baseChiCmd_deg; sidestepOn]`, stepped by `vital.sim.stepInput` exactly at t_step (a step boundary). The sampled form (vital.sim.run Controller, 50 Hz) remains available and tested.
- **Disclosure:** this is a modelling choice the TM leaves open (NOT FOUND), changed **after** the first comparison run on the evidence above. No band, tolerance or expected value was changed. The first-run failures are recorded in reports/fragments/nesc/NOTES.md.
- dt stays 0.02 s; the step-size study (N11, dt' = 0.01 s over min(30 s, duration)) decides whether that is enough.

## ADR-N11r: Revised F-16 step sizes and studies (supersedes the F-16 part of N11)
- **What happened:** (a) cases 11/12 at dt = 0.02 s failed the registered study against dt' = 0.04 s (ratio 0.39 for the case-12 aero roll moment, 0.22 for the case-11 side force; the transients are 1e-8 of the load scale); (b) with the stage-evaluated law of N6r, 13.3 at dt = 0.02 s gave study ratio 82. A dt scan of 13.3 gave ratios of 6.5 (0.01 vs 0.005) and 0.23 (0.005 vs 0.0025). The closed-loop rate feedback puts a pole near -40 1/s, and the aileron and rudder switch between their limits (|p| up to 150 deg/s), so RK4 converges slowly.
- **Decision:** the autopilot cases (13.x, 15, 16) run at dt = 0.005 s and are studied against dt' = 0.0025 s over min(30 s, duration). Cases 11/12 stay at dt = 0.02 s and are studied against dt' = 0.01 s over the first 30 s, which holds their only transient (engagement of the lateral residual, < 10 s).
- The criterion is unchanged: ratio <= 0.1. Where it still fails, the failure is reported. The study now brackets finer steps, so the dt error is bounded by the measured change times 16/15 for a 4th-order method.
- **Disclosure:** chosen after the first runs; no band or expected value changed. **Runtime** exceeds the ~8-minute target (numbers in NOTES.md).

## ADR-N6c: The control law receives Earth-relative body rates (supersedes the w_bn choice of N6)
- **What happened:** with w_bn (rates relative to local NED), case 15 left the 30 deg bank about 3 s before SIM 4/5 (roll excess 38 delta, latitude 18 delta) and held a steady bank bias (-29.99934 deg against -29.99554).
- **Diagnosis** (case 15, stage law, dt 0.005 s, first 40 s; the rate frame is the only change):
  - w_bn: roll -29.999339 deg at 20 s, capture at ~28 s
  - w_be: roll -29.995536 deg at 20-29 s (SIM 5 -29.995536, SIM 4 -29.995538), latitude 89.948753 deg at 20 s (SIM 5 89.948755), capture at 33 s as in SIM 4/5
  - w_bi: -29.995527 deg, slightly further from SIM 5
- **Decision:** `pb, qb, rb` of F16_control/F16_gnc are the body rates relative to the Earth, `w_be`, the same `bodyAngularRate_*` signal the aero model receives (ADR N3). The DML uses one S-119 name for both. The option `cd.controller.rateFrame` stays for diagnostics.
- **Disclosure:** changed after a comparison run, on the evidence above; no band or expected value changed. The rationale registered for w_bn ("LQR design model states") was wrong for the NESC tools.
