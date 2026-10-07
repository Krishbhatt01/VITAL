# NESC check-case matrix (VITAL verification targets)

- **Machine-readable version:** `NESC_CASE_MATRIX.json`. That file is what the tests read.
- **Full cited extracts:** `nesc/NESC_EXTRACT_CASES_01_10.md` and `nesc/NESC_EXTRACT_F16.md`.
- **Page convention:** "V2 p.57 (PDF 61)" means printed page 57 of Vol II, which is PDF page 61. In both volumes the printed page is the PDF page minus 4.
- **Sources:** NASA/TM-2015-218675 Vols I–II, `Initial_Conditions.xlsx`, the reference CSVs and the DAVE-ML files, all hashed in `data/MANIFEST.json`.

## Common to every case
- **Earth constants:** TM Vol II Table 73 (p.93). See ADR-008. The spreadsheet's constants are truncated; for example its equatorial radius is 0.67 ft too large.
- **Atmosphere:** US Standard Atmosphere 1976 (V2 p.48). The TM does not say whether participants evaluated it at geometric or geopotential height (NOT FOUND). VITAL uses geopotential, per the US 1976 definition.
- **Gravity output:** the reference `localGravity_ft_s2` is gravitation magnitude, positive down, with **no** centrifugal term. This was checked numerically: 32.10654 ft/s² at case 1, t = 0.
- **Initial rates:** the TM tables list Earth-relative body rates, although the text calls them inertial. Every CSV reports inertial rates (`bodyAngularRateWrtEi`). VITAL initializes from the inertial values (spreadsheet rows 23–25).
- **Pass criterion:** the TM states **none**. It deliberately rejected a predefined tolerance (V1 p.10) and reports achieved mismatch only (eq. 38, Tables 77–79). VITAL therefore uses the pre-registered band below (ADR-009).
- **Reference sims:**
  - SIM identities are masked by design.
  - Cases 1–10 have 4–6 sims each.
  - F-16 cases have SIM 2, 4 and 5. SIM 2 is excluded from F-16 envelopes, as in the TM's own metrics (V2 p.588–590).

## Cases
| Case | Title | Vehicle | Earth / gravity | Wind | Initial condition (lat, lon, alt; V_NED) | Controller | Duration | Sims |
|---|---|---|---|---|---|---|---|---|
| 1 | Dragless sphere | sphere, CD = 0 | WGS-84 rotating / J2 | none | 0, 0, 30000 ft; 0 | none | 30 s | 1–6 |
| 2 | Tumbling brick, no damping, no drag | brick, all aero 0 | WGS-84 / J2 | none | 0, 0, **30000 ft** (tables say 0; data say 30000; ADR-008); ω_I = 10/20/30 deg/s | none | 30 s | 1,2,4,5,6 |
| 3 | Tumbling brick with damping | brick, Clp = Cmq = Cnr = −1 | WGS-84 / J2 | none | as case 2 | none | 30 s | 1,2,4,5,6 |
| 4 | Sphere, round non-rotating Earth | sphere, CD = 0.1 | sphere r = 6371007.1809 m, ω = 0 / inverse square | none | 0, 0, 30000 ft; ω = 10/20/30 | none | 30 s | 2,4,5,6 |
| 5 | Sphere, round rotating Earth | sphere | sphere, rotating / inverse square | none | 0, 0, 30000 ft | none | 30 s | 2,4,5,6 |
| 6 | Sphere, WGS-84 rotating | sphere | WGS-84 / J2 | none | 0, 0, 30000 ft | none | 30 s | 1–6 |
| 7 | Sphere, steady wind | sphere | WGS-84 / J2 | 20 ft/s from the west | 0, 0, 30000 ft | none | 30 s | 1–6 |
| 8 | Sphere, 2-D wind shear | sphere | WGS-84 / J2 | (0.003 h − 20) ft/s from the west, h in ft MSL | 0, 0, 30000 ft | none | 30 s | 1–6 |
| 9 | Eastward cannonball | sphere | WGS-84 / J2 | none | 0, 0, 0; [0, 1000, −1000] ft/s, yaw 90° | none | 30 s | 1–6 |
| 10 | Northward cannonball | sphere | WGS-84 / J2 | none | 0, 0, 0; [1000, 0, −1000] ft/s | none | 30 s | 1–6 |
| 11 | F-16 subsonic trimmed flight | F-16 | WGS-84 / J2 | none | 36.01916667, −75.67444444, 10013 ft; [400, 400, 0] ft/s, heading 45° | none (trim flyout) | 180 s | 2,4,5 |
| 12 | F-16 supersonic trimmed flight | F-16 (subsonic aero data; thrust clamps at the Mach-1 row) | WGS-84 / J2 | none | same, 30013 ft, 2000 ft/s | none | 180 s | 2,4,5 |
| 13.1 | F-16 altitude change | F-16 | WGS-84 / J2 | none | as case 11 | F16_control, +100 ft at 5 s | 20 s | 2,4,5 |
| 13.2 | F-16 airspeed change | F-16 | WGS-84 / J2 | none | as case 11 | −5 KEAS at 5 s (SIM 2 used −10) | 20 s | 2,4,5 |
| 13.3 | F-16 heading change | F-16 | WGS-84 / J2 | none | as case 11 | +15° course at 15 s | 30 s | 2,4,5 |
| 13.4 | F-16 lateral offset | F-16 | WGS-84 / J2 | none | as case 11 | 2000 ft right offset at 20 s | 60 s | 2,4,5 |
| 15 | F-16 circling the North Pole | F-16 | WGS-84 / J2 | none | 89.95, −45, 10000 ft; 563.643 ft/s east | F16_gnc (circumnavigator = 1) | 180 s | 2,4,5 |
| 16 | F-16 circling Equator/date line | F-16 | WGS-84 / J2 | none | 0, −179.95, 10000 ft; 563.643 ft/s north | F16_gnc (circumnavigator = 0) | 180 s | 2,4,5 |

Cases 14 and 17 are outside VITAL's scope: case 14 does not exist in the atmospheric set, and case 17 is a two-stage rocket.

## Band criterion (pre-registered; ADR-009)
For each signal s and each reference time t, VITAL passes if

  VITAL(t) ∈ [min over sims of ref(t) − δ(t),  max over sims of ref(t) + δ(t)]

with

  δ(t) = max( floor,  rel_floor · max over t of |ref|,  k · spread(t) )

- VITAL's output is linearly interpolated onto each reference time base.
- The sims used are those that supplied the signal and are not excluded for it.
- **Values are fixed in `NESC_CASE_MATRIX.json` before any VITAL run**, and changing them requires an ADR. For all signals k = 0.5.

| Signal class | Absolute floor | Relative floor | Reason for the floor |
|---|---|---|---|
| altitude | 1 ft | — | TM D.1.6 reports a −0.6 to +0.4 ft spread among NASA tools |
| latitude, longitude | 3e-6 deg (≈1 ft) | — | consistent with the altitude floor |
| NED velocity | 0.05 ft/s | — | TM D.1.6: down-velocity spread −0.07 to +0.01 ft/s |
| local gravitation | 1e-4 ft/s² | — | six significant digits in the reference data |
| Euler angles | 0.05 deg | — | TM D.1.3: angle agreement 0.05–0.1 deg; SIM 2 excluded |
| body rates (w.r.t. inertial) | 0.01 deg/s | — | TM D.1.2: rate agreement 0.004 deg/s |
| density, pressure | — | 1e-4 | table-vs-equation US 1976 differences (TM D.1.1) |
| temperature / speed of sound | 0.01 °R / 0.01 ft/s | — | recording precision |
| aero forces | 1e-6 lbf | 1e-3 | tiny sphere forces; F-16 forces use the relative floor |
| aero moments | 1e-6 ft·lbf | 1e-3 | SIM 2 excluded: its moments are about the MRC, not the CM |
| Mach / TAS | 1e-4 / 0.05 kt | — | recording precision |

Case-specific exclusions follow the TM (Vol II p.589):
- SIM 2 X-force and gravity in cases 4–5.
- SIM 3 Y-force in cases 6–8.
- SIM 2 is excluded throughout the F-16 cases.

## Facts that change the implementation plan
1. **The NESC F-16 has no engine power lag and no engine gyroscopic term** (F16_prop.dml; TM). The M4 "NESC configuration" therefore disables both. A power-lag model is added only if a traceable source is registered (e.g. Stevens & Lewis pages).
2. **The CG is at 25% MAC.** The model's aero and thrust moments are about the 35% MAC reference point and must be transferred to the CG (V2 p.604). The mass is 637.1595 slug in the DML and 637.26 slug in TM Table 7. VITAL uses the DML value; the discrepancy is noted.
3. **The control laws are static** (LQR gain matrices plus proportional outer loops). They have no integrators, and their limits exist only as `minValue`/`maxValue` attributes, which must be honoured as saturations.
4. **Every table uses `extrapolate="neither"`** (clamp), and **the last breakpoint varies fastest** in the table data, so a MATLAB reshape must be transposed.
5. **The supersonic case (12) runs the subsonic aero tables**, with thrust clamped at the Mach-1 row. VITAL reproduces the model as published and flags OUT_OF_DATA_ENVELOPE.
6. **Autopilot baseline commands for cases 15 and 16 are NOT FOUND in the TM.** They have to be recovered from the reference data at t = 0 and are labelled as such.
