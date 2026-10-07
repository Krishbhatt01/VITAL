# NASA/TM-2015-218675 — Atmospheric check-cases 1–10: verification specification extract

Sources (read-only):
- **V1** = Vol I, `NASA-TM-2015-218675-EOM_checkcase_summary.pdf` (31 PDF pages)
- **V2** = Vol II, `NASA-TM-2015-218675-EOM_checkcase_appendices.pdf` (614 PDF pages)
- **XLSX** = `Initial_Conditions.xlsx`, sheet `Atmos` (columns E..N = scenarios 1..10; row 1 holds the scenario number)
- **CSV** = `Atmospheric_checkcases/Atmos_NN_*/Atmos_NN_sim_KK.csv`
- **DML** = `Atmospheric_models/*.dml`

**Page citation convention.** `V2 p.57 (PDF 61 / idx 60)` means printed page "57 of 609", 1-based PDF page 61, 0-based PyMuPDF index 60. In both volumes, printed page P = PDF page P+4 = index P+3. I checked this on every numbered page of V2 (pmap.txt) and on V1 pages 5–30.

Tags: **[DOC]** = stated in the report. **[XLSX]** / **[CSV]** / **[DML]** = read from those files. **[DERIVED]** = my own calculation from the cited values. Anything missing from all sources is marked **NOT FOUND**.

---

## 0. General conventions (apply to all of cases 1–10)

### 0.1 Units and time base
- Atmospheric results use English units [DOC V2 p.92 (PDF 96 / idx 95)].
- Output parameter definitions (S-119 names, units, frames) are in Table 75 [DOC V2 p.96 (PDF 100 / idx 99)]. The key ones are listed in §0.6.
- Time base: CSV column `time` in seconds, starting at t = 0 [CSV]. For atmospheric cases the published ECI initial conditions assume "ECEF and ECI coordinate systems were coincident at t = 0" [DOC V2 p.603 (PDF 607 / idx 606)]. XLSX row 15 "Earth rotation angle, deg" is 0 for every scenario [XLSX E15:N15]. The ECI X axis passes through lat 0 / lon 0 at t = 0 for atmospheric cases [DOC V2 p.8 (PDF 12 / idx 11), symbol list].
- No calendar epoch is needed or given for cases 1–10. **NOT FOUND** (not required).

### 0.2 Frames and initial-condition conventions [DOC V2 p.56 (PDF 60 / idx 59)]
- **Position**: CM position as geodetic latitude, longitude and height, in deg / deg / ft "above reference ellipsoid or sphere". The IC tables label this column "(deg, deg, ft MSL)", e.g. V2 p.57. E.2.3 says the intended altitude was geometric height above the reference ellipsoid or sphere [DOC V2 p.604 (PDF 608 / idx 607)].
- **Velocity**: initial Earth-relative velocity in local NED axes, ft/s, order x-y-z (N, E, D).
- **Attitude**: 3-2-1 (yaw, pitch, roll) Euler angles from geodetic NED axes, listed as [roll, pitch, yaw] in deg.
- **Rate**: the text says the rate is "relative to the inertial frame", in body axes, [roll, pitch, yaw] deg/s. **This conflicts with the tables.** The table values are Earth-relative (see §0.8 item 2).
- 3-2-1 Euler angles were standardized for both initial conditions and outputs [DOC V2 p.600 (PDF 604 / idx 603)].
- Atmospheric local vertical is perpendicular to the Earth's surface (geodetic) [DOC V2 p.601 (PDF 605 / idx 604)].
- ECI/ECEF relationship: a single rotation about the shared polar axis at ω, coincident at a predefined time, typically t = 0 [DOC V2 p.42–43 (PDF 46–47)].
- Body axes: x forward, y right, z down [DOC V2 p.43 (PDF 47 / idx 46)].

### 0.3 Geodetic vs geocentric latitude
- Latitude φ is the angle between the surface normal ν and the equatorial plane, so it is geodetic on the ellipsoid. Altitude is measured along ν. East longitude and north latitude are positive [DOC V2 p.37 (PDF 41 / idx 40)].
- Spherical Earth: ECEF = (h + r2)[cosφ cosλ, cosφ sinλ, sinφ] (eq. 10). Inverse: eq. 11 [DOC V2 p.39 (PDF 43 / idx 42)].
- WGS-84: geodetic → ECEF by eq. 14, with ε = sqrt(1 − (rp/re)²) (eq. 13) [DOC V2 p.40 (PDF 44 / idx 43)].
- The inverse (ECEF → geodetic) needs a quartic, an iteration or an approximation. See Borkowski [ref 8] [DOC V2 p.40, p.43].
- The XLSX computes ECI from geodetic LLA "via Burtch [1]" [XLSX A119, A208].
- The CSV `latitude_deg` is geodetic latitude [DOC Table 75, V2 p.96].
- Case 10 split the sims into two groups: some aligned NED with the geocentric rather than geodetic normal. SIM 4 and SIM 5 used the geodetic normal (see §10) [DOC V2 p.215 (PDF 219 / idx 218)].

### 0.4 Earth, gravity and constants — Table 73, "Atmospheric check-cases" [DOC V2 p.93 (PDF 97 / idx 96)]
| Parameter | SI | English |
|---|---|---|
| Equatorial radius | 6378137.0 m | 20925646.32546 ft |
| Radius of the sphere Earth model | 6371007.1809 m | 20902254.5305 ft |
| Gravitational constant μ | 3.986004418 × 10^14 m³/s² | 1.407644175720511 × 10^16 ft³/s² |
| Rotation rate ω | 7.292115 × 10^-5 rad/s | — |
| J2 | 0.00108262982 | |
| Flattening 1/f | 298.257223563 | |
| m → ft | exact 1/0.3048 = 3.28083989501312336 | |

- ω = 7,292,115.0 × 10^-11 rad/s. The report says it corresponds to a sidereal period of "23.9345 hours" [DOC V2 p.42 (PDF 46 / idx 45)].
- r2 is the radius of the sphere with the same surface area as the WGS-84 ellipsoid [DOC V2 p.38 (PDF 42 / idx 41)].
- Constant gravity (B.4.1): 9.80665 m/s², or 32.174 ft/s² as the truncated English value [DOC V2 p.44 (PDF 48 / idx 47)]. **None of cases 1–10 uses constant gravity.**
- **Gravitation vs gravity** [DOC V2 p.44 (PDF 48 / idx 47)]: "gravitation" is the mass attraction. "Gravity" is gravitation plus centrifugal acceleration from Earth rotation.
- Inverse square (eq. 27): **A** = −μ[x, y, z]/(x² + y² + z²)^(3/2), in ECI [DOC V2 p.47 (PDF 51 / idx 50)].
- J2 (eqs. 29–31), in ECI, with re = WGS-84 equatorial radius [DOC V2 p.47]:
  - ẍ = −μx/r³ · [1 − 3J2re²(5z² − r²)/(2r⁴)]
  - ÿ = same with y
  - z̈ = −μz/r³ · [1 − 3J2re²(5z² − 3r²)/(2r⁴)]
  - Potential (eq. 24): U = μ/r · [1 − (J2/2)(3sin²φ − 1)] [DOC V2 p.46 (PDF 50 / idx 49)].
  - When integrating in ECI, the centrifugal contribution "is not explicitly included" [DOC V2 p.47].
- Pairing used in the report: spheroidal Earth with inverse-square gravitation, WGS-84 with harmonic (J2) gravitation [DOC V2 p.37]. V1 states the atmospheric WGS-84 cases include J2 [DOC V1 p.12 (PDF 16 / idx 15)].
- Gravity direction: V1 records that one sim "incorrectly aligned gravitational attraction along the geocentric radius axis, not the geodetic nadir" [DOC V1 p.19 (PDF 23 / idx 22)]. The rotation of the geocentric J2 vector into geodetic NED is discussed in D.1.11 [DOC V2 p.228 (PDF 232 / idx 231)].
- CSV `localGravity_ft_s2` is labelled "Gravitational acceleration of the vehicle's CM in the local 'down' direction" [DOC Table 75, V2 p.96].
  - [DERIVED] Case 1 at t = 0 (r = re + 30000 ft, equator): μ/r²·(1 + 1.5J2(re/r)²) = 32.10653595 ft/s². The CSVs report 32.1065359519 (sim 4/5/6).
  - Subtracting centrifugal ω²r would give 31.99510.
  - **So the reference `localGravity` is gravitation magnitude (positive down) without centrifugal.**
  - Post-processing compared gravitation magnitudes across sims [DOC V2 p.606 (PDF 610 / idx 609)].

### 0.5 Atmosphere
- US Standard Atmosphere 1976 (NASA-TM-X-74335) [DOC V1 p.12 (PDF 16 / idx 15); V2 p.48 (PDF 52 / idx 51)].
- It may be implemented as linear interpolation of the 1D tables, or as the non-linear equations (more accurate), "as a function of either geometric altitude (h) or geopotential height (Z)" [DOC V2 p.48].
- Which input (h or Z) participants must use is **NOT FOUND**. The consensus group (SIM 3, 4, 5, 6) solved the equations. SIM 1 used a table with 1,000-m breakpoints and SIM 2 one with 500-m breakpoints [DOC V2 p.97 (PDF 101 / idx 100)]. Later: SIM 2 used 1,000 m for the first breakpoint, then 500 m [DOC V2 p.202 (PDF 206 / idx 205)].
- Winds: see cases 7 and 8.

### 0.6 CSV signals → Table 75 [DOC V2 p.96 (PDF 100 / idx 99)]
CSV names are S-119 names with a units suffix and an axis suffix [DOC V2 p.95].

| CSV column(s) | Table 75 label | Units | Meaning |
|---|---|---|---|
| `time` | (plots: `c_deltaTime_s`) | s | simulation time |
| `gePosition_ft_X/Y/Z` | gePosition | ft | CM position w.r.t. ECEF, ECEF X-Y-Z axes |
| `eiPosition_ft_X/Y/Z` | eiPosition | ft | CM position w.r.t. ECI, ECI axes |
| `eiVelocity_ft_s_X/Y/Z` | eiVelocityWrtEi or eiVelocity | ft/s | CM velocity w.r.t. ECI, ECI axes |
| `feVelocity_ft_s_X/Y/Z` | feVelocity | ft/s | CM velocity w.r.t. Earth, N-E-D axes |
| `altitudeMsl_ft` | altitudeMsl | ft | geometric altitude above reference ellipsoid / sphere |
| `latitude_deg`, `longitude_deg` | latitude, longitude | deg | geodetic |
| `localGravity_ft_s2` | localGravity | ft/s² | gravitation, local "down" (see §0.4) |
| `eulerAngle_deg_Yaw/Pitch/Roll` | eulerAngle | deg | 3-2-1 attitude w.r.t. NED |
| `bodyAngularRateWrtEi_deg_s_Roll/Pitch/Yaw` | bodyAngularRateWrtEi | deg/s | body rates w.r.t. ECI, body axes |
| `altitudeRateWrtMsl_ft_min` | altitudeRateWrtMsl | ft/min | climb rate, + up |
| `speedOfSound_ft_s` | speedOfSound | ft/s | |
| `airDensity_slug_ft3` | airDensity | slug/ft³ | |
| `ambientPressure_lbf_ft2` | ambientPressure | lbf/ft² | |
| `ambientTemperature_dgR` | ambientTemperature | °R | |
| `aero_bodyForce_lbf_X/Y/Z` | aero bodyForce | lbf | body axes |
| `aero_bodyMoment_ftlbf_L/M/N` | aero bodyMoment | ft-lbf | about CM, body axes |
| `mach` | mach | – | |
| `dynamicPressure_lbf_ft2` | dynamicPressure | lbf/ft² | |
| `trueAirspeed_nmi_h` | trueAirspeed | kt | airmass-relative speed |

Figure captions (q)/(r) read "Body-axis Angular Rates (w.r.t. NED Frame)", e.g. V2 p.106 (PDF 110). The variable, however, is `bodyAngularRateWrtEi`, and the case 1 CSV values are 0, which only fits inertial rates. See Open Questions.

**Exact CSV header rows.** I checked with a script that each sim's header is byte-identical across cases 1–10.
- **H1** `Atmos_NN_sim_01.csv` (31 cols):
  `time,gePosition_ft_X,gePosition_ft_Y,gePosition_ft_Z,feVelocity_ft_s_X,feVelocity_ft_s_Y,feVelocity_ft_s_Z,altitudeMsl_ft,longitude_deg,latitude_deg,localGravity_ft_s2,eulerAngle_deg_Yaw,eulerAngle_deg_Pitch,eulerAngle_deg_Roll,bodyAngularRateWrtEi_deg_s_Roll,bodyAngularRateWrtEi_deg_s_Pitch,bodyAngularRateWrtEi_deg_s_Yaw,altitudeRateWrtMsl_ft_min,speedOfSound_ft_s,airDensity_slug_ft3,ambientPressure_lbf_ft2,ambientTemperature_dgR,aero_bodyForce_lbf_X,aero_bodyForce_lbf_Y,aero_bodyForce_lbf_Z,aero_bodyMoment_ftlbf_L,aero_bodyMoment_ftlbf_M,aero_bodyMoment_ftlbf_N,mach,dynamicPressure_lbf_ft2,trueAirspeed_nmi_h`
- **H2** `sim_02` (27 cols):
  `time,feVelocity_ft_s_X,feVelocity_ft_s_Y,feVelocity_ft_s_Z,altitudeMsl_ft,longitude_deg,latitude_deg,localGravity_ft_s2,eulerAngle_deg_Yaw,eulerAngle_deg_Pitch,eulerAngle_deg_Roll,bodyAngularRateWrtEi_deg_s_Roll,bodyAngularRateWrtEi_deg_s_Pitch,bodyAngularRateWrtEi_deg_s_Yaw,altitudeRateWrtMsl_ft_min,speedOfSound_ft_s,airDensity_slug_ft3,ambientPressure_lbf_ft2,ambientTemperature_dgR,aero_bodyForce_lbf_X,aero_bodyForce_lbf_Y,aero_bodyForce_lbf_Z,aero_bodyMoment_ftlbf_L,aero_bodyMoment_ftlbf_M,aero_bodyMoment_ftlbf_N,mach,trueAirspeed_nmi_h`
- **H3** `sim_03` (22 cols; no Euler angles, no rates):
  `time,gePosition_ft_X,gePosition_ft_Y,gePosition_ft_Z,feVelocity_ft_s_X,feVelocity_ft_s_Y,feVelocity_ft_s_Z,altitudeMsl_ft,longitude_deg,latitude_deg,localGravity_ft_s2,altitudeRateWrtMsl_ft_min,speedOfSound_ft_s,airDensity_slug_ft3,ambientPressure_lbf_ft2,ambientTemperature_dgR,aero_bodyForce_lbf_X,aero_bodyForce_lbf_Y,aero_bodyForce_lbf_Z,aero_bodyMoment_ftlbf_L,aero_bodyMoment_ftlbf_M,aero_bodyMoment_ftlbf_N`
- **H4** `sim_04` (32 cols):
  `time,eiPosition_ft_X,eiPosition_ft_Y,eiPosition_ft_Z,eiVelocity_ft_s_X,eiVelocity_ft_s_Y,eiVelocity_ft_s_Z,feVelocity_ft_s_X,feVelocity_ft_s_Y,feVelocity_ft_s_Z,altitudeMsl_ft,longitude_deg,latitude_deg,localGravity_ft_s2,eulerAngle_deg_Yaw,eulerAngle_deg_Pitch,eulerAngle_deg_Roll,bodyAngularRateWrtEi_deg_s_Roll,bodyAngularRateWrtEi_deg_s_Pitch,bodyAngularRateWrtEi_deg_s_Yaw,speedOfSound_ft_s,airDensity_slug_ft3,ambientPressure_lbf_ft2,ambientTemperature_dgR,aero_bodyForce_lbf_X,aero_bodyForce_lbf_Y,aero_bodyForce_lbf_Z,aero_bodyMoment_ftlbf_L,aero_bodyMoment_ftlbf_M,aero_bodyMoment_ftlbf_N,mach,dynamicPressure_lbf_ft2`
- **H5** `sim_05` (38 cols). **The last column duplicates `feVelocity_ft_s_Z`**; pandas renames it `feVelocity_ft_s_Z.1`.
  `time,eiPosition_ft_X,eiPosition_ft_Y,eiPosition_ft_Z,gePosition_ft_X,gePosition_ft_Y,gePosition_ft_Z,eiVelocity_ft_s_X,eiVelocity_ft_s_Y,eiVelocity_ft_s_Z,feVelocity_ft_s_X,feVelocity_ft_s_Y,feVelocity_ft_s_Z,altitudeMsl_ft,longitude_deg,latitude_deg,localGravity_ft_s2,eulerAngle_deg_Yaw,eulerAngle_deg_Pitch,eulerAngle_deg_Roll,bodyAngularRateWrtEi_deg_s_Roll,bodyAngularRateWrtEi_deg_s_Pitch,bodyAngularRateWrtEi_deg_s_Yaw,altitudeRateWrtMsl_ft_min,speedOfSound_ft_s,airDensity_slug_ft3,ambientPressure_lbf_ft2,ambientTemperature_dgR,aero_bodyForce_lbf_X,aero_bodyForce_lbf_Y,aero_bodyForce_lbf_Z,aero_bodyMoment_ftlbf_L,aero_bodyMoment_ftlbf_M,aero_bodyMoment_ftlbf_N,mach,dynamicPressure_lbf_ft2,trueAirspeed_nmi_h,feVelocity_ft_s_Z`
- **H6** `sim_06` (37 cols): same as H5 without the trailing duplicate.

**CSV sample rates** [CSV]:
- sims 1, 2, 3, 4, 6: 301 rows, uniform 0.1 s, t = 0 to 30 s. Sim 6 ends at 30.00000000001368.
- sim 5: 3001 rows at about 0.01 s, with non-uniform steps (12 distinct dt values, e.g. 0.00999832).
- The report says only "A recording rate was agreed to for each check-case" [DOC V2 p.605 (PDF 609 / idx 608)]. The agreed rate itself is **NOT FOUND** in the documents.

### 0.7 Participating simulations
- V1 lists seven tools [DOC V1 p.13 (PDF 17 / idx 16)]: Core (AFRC), JEOD (JSC), JSBSim, LaSRS++ (LaRC), MAVERIC (MSFC), POST-II (LaRC), VMSRTE (ARC).
- V1 also says: "In total, seven simulation tools were exercised" [DOC V1 p.8 (PDF 12 / idx 11)].
- JEOD was used for the orbital cases only [DOC V2 p.50 (PDF 54 / idx 53)]. The other six are described as running atmospheric cases. Integration details from B.6:

| Tool | Atmospheric use | Integration / rate | Cite |
|---|---|---|---|
| LaSRS++ | atmospheric and orbital | Translational velocity: 2nd-order Adams-Bashforth. Position: 2nd-order Taylor. Angular velocity: AB2. Quaternion: local linearization. **500 Hz for atmospheric cases 1–10** (Table 21) | V2 p.50–51 (PDF 54–55) |
| MAVERIC | "some but not all" atmospheric and orbital | RK4, 0.1 s | V2 p.51 (PDF 55) |
| POST II | "most" atmospheric and orbital | RK4; **atmospheric cases 100 Hz** (Table 22) | V2 p.52 (PDF 56) |
| VMSRTE | "some" atmospheric | AB2, 0.01 s | V2 p.52 (PDF 56) |
| Core | "some" atmospheric | RK4, 0.01 s | V2 p.53 (PDF 57) |
| JSBSim | atmospheric | "higher-order" Adams-Bashforth, 120 frames/s | V2 p.53 (PDF 57) |

- **Mapping SIM 1..6 to tool names: NOT FOUND, masked by design.** "The identities of the various tools were masked to encourage participation", and atmospheric cases used SIM 1, SIM 2, ... [DOC V2 p.92–95 (PDF 96–99)].
- The only in-text clue: SIM 2 is described as "one frame in a 100-Hz simulation" [DOC V2 p.162 (PDF 166 / idx 165)].
- Developers chose their own integration step and method [DOC V2 p.95 (PDF 99 / idx 98)]. V1 says no specification of integration techniques was available [DOC V1 p.19 (PDF 23 / idx 22)].

### 0.8 How differences were interpreted (general)
- Approach: no single "known good" tool, and no requirement that trajectories match within a predefined tolerance. Comparison plots of all tools were presented instead. Acceptable agreement makes the set a verification guide; otherwise the cause is sought and the trajectories stand as a family of solutions [DOC V1 p.10 (PDF 14 / idx 13)].
- Inclusion rule: at least three data sets per check-case [DOC V1 p.13 (PDF 17); p.18 (PDF 22)].
- Main atmospheric difference sources [DOC V1 p.18–19 (PDF 22–23)]:
  - table vs equation US1976 implementations;
  - geodetic vs geocentric geometry;
  - gravitation implementation and geodetic→geocentric IC conversion;
  - numerical integration.
- Differences were plotted against the ensemble average. For wrapped angles (Euler, lat, lon), eq. 37 (arctan angle difference) was used against SIM 5 as reference [DOC V2 p.95 (PDF 99 / idx 98); p.588 (PDF 592 / idx 591)].
- **Quantitative metric** (E.1.1, eq. 38) [DOC V2 p.588 (PDF 592 / idx 591)]:
  δu_pct = 100 · max|u(t) − u_ref(t)| / max over 0≤t≤t_end of |u_ref|
  - u_ref = ensemble average (or analytic solution); SIM 5 for angles.
  - Allowances: known-incorrect signals are excluded, and signals where no sim exceeds 0.001 are ignored.
  - Per-case results are in Table 77 [DOC V2 p.591 (PDF 595 / idx 594)]; per-signal results for cases 1–10 in Table 78 [DOC V2 p.592 (PDF 596 / idx 595)].
  - Excluded for cases 1–10 [DOC V2 p.589 (PDF 593 / idx 592)]:
    - SIM 2 Euler angles (all cases);
    - SIM 2 X-body force and local gravity (cases 4 and 5);
    - SIM 3 Y-body force (cases 6, 7, 8);
    - SIM 2 aero moments (reported at the MRC, not the CM) [DOC V2 p.590 (PDF 594 / idx 593)].
- **Pass/fail tolerance for any case: none stated.** Table 77 and eq. 38 report the achieved mismatch; they are not acceptance criteria.
- Identified atmospheric differences are listed in E.1.2 [DOC V2 p.589 (PDF 593)]:
  - integration methods;
  - tabular atmosphere;
  - SIM 2 wrong initial velocity in some cases;
  - SIM 2 truncated gravitational constant in inverse-square gravitation;
  - SIM 2 recording aero force and gravity one frame late;
  - SIM 3 treating initial rates as Earth-relative;
  - SIM 3 reporting zero aero force in the first frame;
  - case 10 local-vertical disagreement;
  - case 10 likely incorrect SIM 2 geodetic conversion.
- Unidentified: a bias in SIM 1 translational forces in case 9 [DOC V2 p.589].
- Corrections made before the final runs are in E.2 [DOC V2 p.599–606 (PDF 603–610)]:
  - E.2.1: an early case-1 run showed up to 0.7 ft ECEF X difference from a truncated m→ft conversion of re. Eventually all tools used Tables 73/74.
  - E.2.3: IC ambiguity (inertial vs Earth-relative rates; altitude reference).
  - E.2.4: recording precision, lags and first/last-frame artifacts. At least six digits were required; six significant digits cannot resolve <20 ft in longitude at the Equator.

---

## Case 1 — Dragless sphere

1. **ID/title.**
   - V2 C.1.1 "Check-case 1 – dragless sphere" [V2 p.56 (PDF 60 / idx 59)].
   - Table 25 scenario: "1: Dragless sphere" [V2 p.57 (PDF 61 / idx 60)].
   - V1 Table 6.3-1: "Dragless sphere with no drag"; verifies "Gravitation, translational EOM" [V1 p.15 (PDF 19 / idx 18)].
   - XLSX E2 "Dragless sphere". CSV dir `Atmos_01_DroppedSphere`.
2. **Vehicle.** Atmospheric spheroid, B.1.1 Tables 1–2 [V2 p.12 (PDF 16 / idx 15)].
   - Mass/inertia: m = 1.0 slug; Ixx = Iyy = Izz = 3.6 slug-ft²; Ixy = Iyz = Izx = 0; CM offset 0, measured from the CM.
   - Aero: S = 0.1963495 ft², CD = 0.1, all other coefficients 0.
   - Files: `cannonball_inertia.dml` (XIXX/XIYY/XIZZ = 3.6 slugft2, XMASS = 1.0 slug, "1-slug, 6" diameter cannonball") and `cannonball_aero.dml` (SWING = 0.1963495 ft², CD = 0.1, Revision E 2013-04-19) [DML].
   - **Case 1 sets CD to zero** (Table 25 note "CD set to zero"; text p.56). All CSV aero forces and moments are exactly 0 for all six sims [CSV].
3. **Earth.**
   - WGS-84 ellipsoid, rotating (Table 25) [V2 p.57], ω = 7.292115e-5 rad/s (Table 73) [V2 p.93].
   - Gravitation J2 (eqs. 29–31) [V2 p.47], using Table 73 μ, re, J2.
   - The model is gravitation only; centrifugal effects come from the rotating-Earth EOM. CSV localGravity = gravitation (§0.4).
4. **Atmosphere.** "US 1976 STD; no wind" [V2 p.57]. Wind: none. V1: "Still air"; V2 Table 23: "N.A." [V2 p.54 (PDF 58)].
5. **Initial conditions.**
   - Table 25 [V2 p.57]: Geodetic [0, 0, 30000] (deg, deg, ft MSL); velocity local-relative [0, 0, 0] ft/s; attitude [0, 0, 0] deg; rate body axes [-0.004178073, 0, 0] deg/s.
   - Text [V2 p.56]:
     - 30,000 ft over the Equator/Prime Meridian;
     - initially motionless relative to the atmosphere;
     - "zero inertial rotation";
     - body x north, y east, z down.
     - The table rate is therefore Earth-relative.
   - XLSX column E:
     - E33 lat = 0, E34 lon = 0, E35 alt = 30000 ft;
     - E36–E38 Vn/Ve/Vd = 0/0/0;
     - E39–E41 pitch/roll/yaw = 0/0/0;
     - E18–E20 "Rates w.r.t. local frame in body axis" = −0.004178073/0/0;
     - E23–E25 "Inertial rotation components in body axis" = 0/0/0;
     - E122 ECI X = 20955646.99508 ft;
     - E50/E129 inertial Veast = 1528.1094637639699 ft/s;
     - E133 J2 radial gravitation −32.10653698553324; E136 with centrifugal −31.995105516307152 ft/s².
   - CSV row 0 (sim 5): eiPosition_X = 20955646.32545932 ft; eiVelocity_Y = 1528.1098290457676 ft/s; bodyAngularRateWrtEi = 0/0/0; localGravity = 32.10653595191867.
   - XLSX ECI values use re = 6378137 × 3.28084 ft; the CSVs use Table 73 (see OQ-3).
6. **Timing.** Duration 30 s [V2 p.57; XLSX E195]. Participant integration: §0.7. Output: CSV 0.1 s (sim 5 about 0.01 s), t = 0–30 s [CSV].
7. **Outputs.** Fig. 16 (a)–(x), V2 p.98–109 (PDF 102–113):
   - aero forces/moments; alt/lat/lon; Euler angles; gravity/climb rate/speed of sound; Mach/q̄/TAS;
   - NED velocities; inertial velocities; body rates; atmosphere properties; ECEF positions; ECI positions.
   - Header of `Atmos_01_sim_05.csv` = H5 exactly (§0.6). Sims 1, 2, 3, 4, 6 use H1, H2, H3, H4, H6.
8. **Sims.**
   - CSVs present: sims 01–06 [CSV]. D.1.1: "six of the selected simulation tools" [V2 p.97 (PDF 101)].
   - Coverage by plot: Euler and body-rate plots SIM 1, 2, 4, 5, 6 (SIM 3 has no angles); inertial velocity and ECI plots SIM 4, 5, 6 only; ECEF plots SIM 1, 3, 5, 6 [V2 p.101–109, legends].
   - Notes [V2 p.97]:
     - translation differences "less than 0.01 inches in position and 0.01 in/s in velocity", attributed to integration;
     - density and pressure consensus only among SIM 3, 4, 5, 6;
     - SIM 1 and SIM 2 used table look-up with hill-and-valley residuals.
9. **Criterion.** None stated. Achieved (Table 77, largest % of reference) [V2 p.591 (PDF 595)]: SIM 1 0.139, SIM 2 0.027, SIM 3 0.030, SIM 4 0.029, SIM 5 0.030, SIM 6 0.029; largest 0.139.
   - Reference end state (CSV sim 5, t = 30 s): altitudeMsl 15598.90435 ft; longitude 5.745522e-5 deg; feVelocity E/D 2.101011 / 960.2930645 ft/s; roll −0.1253996792 deg [CSV, DERIVED lookup].

## Case 2 — Tumbling brick, no damping, no drag

1. **ID/title.**
   - V2 C.1.2 "Check-case 2 – dragless tumbling brick" [V2 p.57 (PDF 61)].
   - Table 26: "2: Tumbling brick with no damping or drag" [V2 p.58 (PDF 62 / idx 61)].
   - V1: "Tumbling brick with no damping, no drag"; verifies "Rotational EOM" [V1 p.15 (PDF 19)].
   - XLSX F2; CSV dir `Atmos_02_TumblingBrickNoDamping`.
2. **Vehicle.** Brick, B.1.3 Tables 4–5 [V2 p.13 (PDF 17 / idx 16)]. Size 8 × 4 × 2.25 in along x, y, z; axes originate at the CM.
   - Mass/inertia: m = 0.155404754 slug; Ixx = 0.001894220, Iyy = 0.006211019, Izz = 0.007194665 slug-ft²; products 0.
   - Aero: S = 0.22222 ft², b = 0.33333 ft, c̄ = 0.66667 ft; CD = 0.01; Clp = −1.0, Cmq = −1.0, Cnr = −1.0; Clr = Cnp = 0; CL = CY = Cl = Cm = Cn = 0.
   - Files: `brick_inertia.dml` (XIXX = 0.00189422, XIYY = 0.006211019, XIZZ = 0.007194665, XMASS = 0.155404754 "5 lbm") and `brick_aero.dml` (Mod C 2013-04-19) [DML].
     - Cl = Clp·pb/2V + Clr·rb/2V; Cm = Cmq·qc̄/2V; Cn = Cnp·pb/2V + Cnr·rb/2V.
     - Damping units per rad; VRW `minValue="0.5"` ft/s.
   - **Case 2 zeroes all aero.** Table note: "Clp, Cmq, Cnr set to zero". Text: "setting all the aerodynamic coefficient values in Table 5 to zero" [V2 p.57]. CSV aero forces and moments are 0 for all sims [CSV].
3. **Earth.** WGS-84 rotating, J2 [V2 p.58], constants as case 1.
4. **Atmosphere.** US 1976; no wind [V2 p.58].
5. **Initial conditions.**
   - Table 26 [V2 p.58]: **Geodetic [0, 0, 0]**; velocity [0, 0, 0]; attitude [0, 0, 0]; rate body axes [9.995821927, 20, 30] deg/s.
   - Text [V2 p.57]: "dropped from the same initial position as ... scenario 1 (30,000 ft ...)"; inertial rates 10, 20, 30 deg/s; the table gives Earth-relative values. Body x north (longest dimension), z down (shortest).
   - XLSX F: F35 alt = **0** ft; F18–F20 = 9.995821927/20/30 (local-relative); F23–F25 = 10/20/30 (inertial, body); F28–F30 inertial axes = −30/20/10.000000000000002; F122 = 20925646.99508 ft.
   - **CSV: all sims start at altitudeMsl = 30000 ft.** Sim 5 eiPosition_X = 20955646.32545932; bodyAngularRateWrtEi = 10/20/30.000000000000004 [CSV].
   - **Conflict: the table and XLSX say 0 ft; the text and data say 30,000 ft (OQ-1).**
6. **Timing.** 30 s [V2 p.58]. Output 0.1 s (sim 5 about 0.01 s) [CSV].
7. **Outputs.** Fig. 17 (a)–(x), V2 p.111–122 (PDF 115–126). Header of `Atmos_02_sim_05.csv` = H5 exactly.
8. **Sims.**
   - CSVs: 01, 02, 04, 05, 06 (no sim 03) [CSV]. D.1.2: "five" tools [V2 p.110 (PDF 114)]. ECEF plots SIM 1, 5, 6; ECI plots SIM 4, 5, 6.
   - Notes [V2 p.110]: translation identical to case 1; rates agree "to within 0.004 deg/s". SIM 2 Euler angles diverge up to "±4 degrees" by t = 30 s (its integration method). SIM 2 Euler angles are excluded from the metrics [V2 p.589].
9. **Criterion.** None stated. Table 77: SIM 1 0.133, SIM 2 0.033, SIM 3 no data, SIM 4 0.035, SIM 5 0.036, SIM 6 0.035; largest 0.133 [V2 p.591].
   - Reference end state (sim 5, t = 30 s): roll/pitch/yaw = −56.15127539 / −3.819633201 / −4.289288509 deg; inertial p/q/r = 12.61842377 / −17.3974441 / 31.11960301 deg/s [CSV].

## Case 3 — Tumbling brick with dynamic (aerodynamic) damping, no drag

1. **ID/title.**
   - V2 C.1.3 "Check-case 3 – dragless tumbling brick with aerodynamic damping" [V2 p.58 (PDF 62)].
   - Table 27: "3: Tumbling brick with damping but no drag" [V2 p.58].
   - V1: "Tumbling brick with dynamic damping, no drag"; verifies "Inertial coupling" [V1 p.15].
   - XLSX G2; CSV dir `Atmos_03_TumblingBrickDamping`.
2. **Vehicle.** Brick (same files and values as case 2) with damping on: Clp = Cmq = Cnr = −1.0.
   - Table 27 note "CD set to zero"; text: "still no lift, drag or sideforce" [V2 p.58].
   - Table 27 vehicle row reads "Dragless rotating sphere with aero damping". This is a typo: the text says brick, and XLSX G198 repeats the typo.
   - CSV: aero forces 0; aero moments non-zero (max |L| ≈ 6.6e-5, |M| ≈ 5.0e-4, |N| ≈ 3.6e-4 ft-lbf) [CSV].
3. **Earth.** WGS-84 rotating, J2 [V2 p.58].
4. **Atmosphere.** US 1976; no wind. V2 Table 23 Winds column: "none" [V2 p.54].
5. **Initial conditions.**
   - Table 27 [V2 p.58]: **Geodetic [0, 0, 0]**; velocity [0, 0, 0]; attitude [0, 0, 0]; rate [9.995821927, 20, 30].
   - XLSX G: G35 = **0** ft; G18–G20 = 9.995821927/20/30; G23–G25 = 10/20/30.
   - CSV: all sims start at 30000 ft; inertial rates 10/20/30 [CSV]. D.1.3 text says the results for translational states are identical to cases 1–2 [V2 p.123 (PDF 127)]. **Same altitude conflict as case 2 (OQ-1).**
6. **Timing.** 30 s [V2 p.58]. Output 0.1 s (sim 5 about 0.01 s) [CSV].
7. **Outputs.** Fig. 18 (a)–(x), V2 p.124–135 (PDF 128–139). Header of `Atmos_03_sim_05.csv` = H5 exactly.
8. **Sims.**
   - CSVs: 01, 02, 04, 05, 06 [CSV]. D.1.3: "five" [V2 p.123].
   - Notes [V2 p.123]:
     - SIM 1/SIM 2 aero moments differ by less than ±3.5e-6 lbf-ft (density);
     - inertial rate differences smaller than ±0.06 deg/s, confined to the first 20 s;
     - yaw: SIM 4, 5, 6 within 0.05 deg; SIM 2 about −0.15 deg (peak −0.35 at about 9 s); SIM 1 about −0.32 deg;
     - pitch: SIM 1, 4, 5, 6 within about 0.1 deg; SIM 2 down to −0.65 deg;
     - roll: all within 0.1 deg by end of run (SIM 2 peak about 0.5 deg at about 7.5 s).
9. **Criterion.** None stated. Table 77: SIM 1 0.972, SIM 2 0.065, SIM 3 no data, SIM 4 0.264, SIM 5 0.067, SIM 6 0.072; largest 0.972 [V2 p.591].
   - Reference end state (sim 5, t = 30 s): Euler R/P/Y = −5.152247846 / −38.69966908 / −111.3557517 deg [CSV].

## Case 4 — Dropped sphere, constant CD, round non-rotating Earth

1. **ID/title.**
   - V2 C.1.4 "Check-case 4 – sphere dropping over non-rotating, spherical Earth" [V2 p.58 (PDF 62)].
   - Table 28: "4: Sphere with round non-rotating Earth" [V2 p.59 (PDF 63 / idx 62)].
   - V1: "Dropped sphere with constant CD, no wind"; verifies "Gravitation, integration"; 1/R², "Round fixed" [V1 p.15].
   - XLSX H2; CSV dir `Atmos_04_DroppedSphereRoundNonRotation`.
2. **Vehicle.** Sphere with nominal CD = 0.1 (Table 2) [V2 p.58–59]. Files: `cannonball_inertia.dml` and `cannonball_aero.dml` (values as case 1).
3. **Earth.**
   - Round, non-rotating [V2 p.59]. Radius r2 = 20902254.5305 ft (6371007.1809 m) [Table 73, V2 p.93]; ω = 0.
   - Gravitation inverse square (B.4.2, eq. 27) with μ = 1.407644175720511e16 ft³/s² [V2 p.47, p.93].
   - Spherical geodesy per eqs. 10–11 [V2 p.39].
   - E.2.3 warns that cases 4–5 use a radius different from the WGS-84 equatorial radius [V2 p.603 (PDF 607)].
   - XLSX H5 = 20902255.199 ft, H8/H9 ω = 0, H10–H12 f/J2/e² = 0.
4. **Atmosphere.** US 1976; no wind; "still air" [V2 p.59, p.54].
5. **Initial conditions.**
   - Table 28 [V2 p.59]: Geodetic [0, 0, 30000]; velocity [0, 0, 0]; attitude [0, 0, 0]; rate body axes [10, 20, 30] deg/s. Text: rotating "relative to the Earth at 10, 20, and 30 deg/s" [V2 p.58].
   - XLSX H: H35 = 30000; H18–H20 = 10/20/30; H23–H25 = 10/20/30; H115–H117 = 0.
     - H44/H122 = 20955646.99508 ft; H48 "Radius to vehicle" = 20932255.199 ft.
     - H50/H129 inertial Veast = 1528.1094637639699 ft/s, **even though ω = 0** (see OQ-4).
   - CSV sim 4/5/6 row 0: eiPosition_X = 20932254.5305 ft (= r2 + 30000, Table 73); eiVelocity_Y = 0; localGravity = 32.12631207 ft/s² ([DERIVED] μ/r² = 32.12631207055766).
6. **Timing.** 30 s [V2 p.59]. Output 0.1 s (sim 5 about 0.01 s) [CSV].
7. **Outputs.** Fig. 19 (a)–(x), V2 p.137–148 (PDF 141–152). Header of `Atmos_04_sim_05.csv` = H5 exactly.
8. **Sims.**
   - CSVs: 02, 04, 05, 06 [CSV]. D.1.4: "four" [V2 p.136 (PDF 140)]. ECEF plot SIM 5, 6 only; ECI plot SIM 4, 5, 6.
   - Notes [V2 p.136]:
     - SIM 4, 5, 6 agree;
     - SIM 2 has initial north velocity 0.01 ft/s (CSV confirms feVelocity_X = 0.01 at t = 0), giving about 8e-7 deg latitude by the end;
     - SIM 2 gravity about 0.05 ft/s² low (truncated μ, per E.1.2 [V2 p.589]), plus table atmosphere;
     - SIM 2 Euler differences come from its integration.
   - The SIM 2 CSV has localGravity = 0.0 at t = 0 [CSV]. Its X-body force and local gravity are excluded from metrics [V2 p.589].
9. **Criterion.** None stated. Table 77: SIM 1 no data, SIM 2 9.998, SIM 3 no data, SIM 4/5/6 3.333; largest 9.998 [V2 p.591].
   - Table 78 shows the 3.3%-class values are in aero body forces [V2 p.592]. I have not verified the cause.
   - Reference end state (sim 5, t = 30 s): alt 16231.30691 ft; Vd 867.1047769 ft/s; Euler R/P/Y 17.92530217 / 17.74663279 / 37.4532208 deg [CSV].

## Case 5 — Dropped sphere, constant CD, round rotating Earth

1. **ID/title.**
   - V2 C.1.5 "Check-case 5 – sphere dropping over rotating, spherical Earth" [V2 p.59 (PDF 63)].
   - Table 29: "5: Sphere with round rotating Earth" [V2 p.59].
   - V1: verifies "Earth rotation"; 1/R², "Round rotating" [V1 p.15].
   - XLSX I2; CSV dir `Atmos_05_DroppedSphereRoundRotation`.
2. **Vehicle.** Sphere, CD = 0.1; cannonball DMLs.
3. **Earth.** Round, rotating, r2 = 20902254.5305 ft, ω = 7.292115e-5 rad/s; inverse-square gravitation [V2 p.59, p.93]. XLSX I5 = 20902255.199 ft, I8 = 0.004178073 deg/s, I11 J2 = 0.
4. **Atmosphere.** US 1976; no wind [V2 p.59].
5. **Initial conditions.**
   - Table 29 [V2 p.59]: Geodetic [0, 0, 30000]; velocity [0, 0, 0]; attitude [0, 0, 0]; rate body axes [9.995821927, 20, 30].
   - Text: same inertial rate as case 4, with an Earth-relative roll bias.
   - XLSX I: I18–I20 = 9.995821927/20/30; I23–I25 = 10/20/30; I50 = 1528.1094637639699 ft/s (computed with I122 = 20955646.99508 ft, a WGS radius; OQ-4).
   - CSV sim 5: eiPosition_X = 20932254.53051181; eiVelocity_Y = 1526.4040724576314 ft/s ([DERIVED] ω(r2 + 30000) = 1526.40407246); inertial rates 10/20/30 [CSV].
6. **Timing.** 30 s. Output 0.1 s (sim 5 about 0.01 s).
7. **Outputs.** Fig. 20 (a)–(x), V2 p.150–161 (PDF 154–165). Header of `Atmos_05_sim_05.csv` = H5 exactly.
8. **Sims.**
   - CSVs: 02, 04, 05, 06 [CSV]. D.1.5: "four" [V2 p.149 (PDF 153)].
   - Notes: same SIM 2 issues as case 4 (0.01 ft/s initial north velocity, about −0.05 ft/s² gravitation, tables). With rotation, there is also a "negligible" SIM 2 longitude difference via Coriolis [V2 p.149].
9. **Criterion.** None stated. Table 77: SIM 2 10.011; SIM 4/5/6 3.337; SIM 1 and SIM 3 no data; largest 10.011 [V2 p.591].
   - Reference end state (sim 5): alt 16276.38553 ft; lon 5.346997709e-5 deg; Ve 1.843897957; Vd 864.4800352 ft/s [CSV].

## Case 6 — Dropped sphere, constant CD, WGS-84 rotating Earth, no wind

1. **ID/title.**
   - V2 C.1.6 "Check-case 6 – sphere dropping over rotating, ellipsoidal Earth" [V2 p.59 (PDF 63)].
   - Table 30: "6: Sphere with ellipsoidal rotating Earth" [V2 p.60 (PDF 64 / idx 63)].
   - V1: verifies "Ellipsoidal Earth" [V1 p.15].
   - XLSX J2; CSV dir `Atmos_06_DroppedSphereEllipsoidalNoWind`.
2. **Vehicle.** Sphere, CD = 0.1 ("repeat of the first check-case ... except ... non-zero drag") [V2 p.59]. Cannonball DMLs.
3. **Earth.** WGS-84 rotating; J2 [V2 p.60]. Table 73 constants.
4. **Atmosphere.** US 1976; no wind.
5. **Initial conditions.**
   - Table 30 [V2 p.60]: [0, 0, 30000]; [0, 0, 0]; [0, 0, 0]; rate [-0.004178073, 0, 0].
   - XLSX J: J35 = 30000; J18 = −0.004178073; J23–J25 = 0/0/0; J50 = 1528.1094637639699.
   - CSV sim 5 row 0 is identical to case 1 [CSV].
6. **Timing.** 30 s [V2 p.60]. Output 0.1 s (sim 5 about 0.01 s).
7. **Outputs.** Fig. 21 (a)–(x), V2 p.163–174 (PDF 167–178). Header of `Atmos_06_sim_05.csv` = H5 exactly.
8. **Sims.**
   - CSVs: 01–06 [CSV]. D.1.6: "six" [V2 p.162 (PDF 166)].
   - Notes [V2 p.162]:
     - SIM 2 aero force lags one frame (0.01 s, recording only);
     - SIM 3 aero Y/Z differences are reproducible if its initial Earth-relative rate were zero (the others use zero inertial rate);
     - downward velocity differences span −0.07 to 0.010 ft/s and altitude −0.6 to 0.4 ft.
   - SIM 3 Y-body force is excluded from metrics [V2 p.589].
9. **Criterion.** None stated. Table 77: SIM 1 0.142, SIM 2 0.080, SIM 3 0.029, SIM 4 0.030, SIM 5 0.031, SIM 6 0.030; largest 0.142 [V2 p.591].
   - Reference end state (sim 5): alt 16284.44475 ft; lon 5.337981987e-5 deg; Ve 1.842930477; Vd 864.0107594 ft/s [CSV].

## Case 7 — Dropped sphere, constant CD, steady wind

1. **ID/title.**
   - V2 C.1.7 "Check-case 7 – sphere dropping through a steady wind field" [V2 p.60 (PDF 64)].
   - Table 31: "7: Sphere with steady wind" [V2 p.60].
   - V1: verifies "Wind effects"; "Steady wind" [V1 p.15].
   - XLSX K2; CSV dir `Atmos_07_DroppedSphereSteadyWind`.
2. **Vehicle.** Sphere, CD = 0.1; cannonball DMLs.
3. **Earth.** WGS-84 rotating; J2 [V2 p.60].
4. **Atmosphere/wind.**
   - "US 1976 STD; steady 20 ft/s wind from due west" [Table 31, V2 p.60]. Text: "constant 20 ft/s wind coming from the west", i.e. the airmass moves eastward, producing an eastward force [V2 p.60]. XLSX K197 has the same text.
   - Vertical wind component: **NOT FOUND** (implicitly horizontal only).
   - Whether the wind is defined in Earth-fixed NED (vs inertial): **NOT FOUND** explicitly. "Atmosphere moving eastward at a constant linear rate" relative to the Earth's surface is implied [V2 p.60].
5. **Initial conditions.**
   - Table 31 [V2 p.60]: [0, 0, 30000]; [0, 0, 0]; [0, 0, 0]; rate [-0.004178073, 0, 0]. XLSX K identical to J.
   - CSV t = 0: TAS = 11.849676 kt (= 20 ft/s) and aero_bodyForce_Y = 0.0034977 lbf (sim 4/5). SIM 6 records 0 at t = 0 (recording artifact, cf. case 8 text) [CSV].
6. **Timing.** 30 s. Output 0.1 s (sim 5 about 0.01 s).
7. **Outputs.** Fig. 22 (a)–(x), V2 p.176–187 (PDF 180–191). Header of `Atmos_07_sim_05.csv` = H5 exactly.
8. **Sims.**
   - CSVs: 01–06 [CSV]. D.1.7: "six" [V2 p.175 (PDF 179)].
   - Notes [V2 p.175]: the listed causes are tables vs formulas, integration, SIM 2's 0.01-s aero recording lag, and SIM 3 initialized with zero Earth-relative rate.
   - E.2.3: cases 7–8 were most prone to the "initial states not realized at t = 0" problem (wind drag at t = 0) [V2 p.604 (PDF 608)].
9. **Criterion.** None stated. Table 77: SIM 1 0.142, SIM 2 0.079, SIM 3 0.044, SIM 4 0.030, SIM 5 0.031, SIM 6 0.030; largest 0.142 [V2 p.591].
   - Reference end state (sim 5): alt 16285.16222; lon 1.285418332e-4 deg; Ve 4.708379684; Vd 863.9668306 ft/s [CSV].

## Case 8 — Dropped sphere, constant CD, 2-D wind shear

1. **ID/title.**
   - V2 C.1.8 "Check-case 8 – sphere dropping through a varying wind field" [V2 p.60 (PDF 64)].
   - Table 32: "8: Sphere with wind shear" [V2 p.61 (PDF 65 / idx 64)].
   - V1: "Dropped sphere with constant CD + wind shear"; verifies "2 dimensional wind"; Winds "f(h)" [V1 p.15].
   - XLSX L2; CSV dir `Atmos_08_DroppedSphere2DWindShear`.
2. **Vehicle.** Sphere, CD = 0.1 (B.1.1); cannonball DMLs.
3. **Earth.** WGS-84 rotating; J2 [V2 p.61].
4. **Atmosphere/wind.**
   - "US 1976 STD; wind varies linearly with altitude". Note: "Vwind = (0.003h − 20) ft/s from west; h is height MSL in ft." [Table 32, V2 p.61; XLSX L199 identical].
   - Text: "from the west at 70 ft/s at 30,000 ft, tapering to 20 ft/s from the east at the surface" [V2 p.60].
   - [DERIVED] 0.003·30000 − 20 = 70 ft/s. D.1.8 text: "initial winds were higher (70 ft/s versus 20 ft/s)" [V2 p.188 (PDF 192)].
   - CSV t = 0: TAS = 41.473866 kt (= 70 ft/s), aero_bodyForce_Y ≈ 0.04285 lbf (sim 1/2/4/5) [CSV].
   - Vertical component and height reference (MSL vs ellipsoid): the table says "height MSL"; the geoid is not modelled. See OQ-8.
5. **Initial conditions.** Table 32 [V2 p.61]: [0, 0, 30000]; [0, 0, 0]; [0, 0, 0]; rate [-0.004178073, 0, 0]. XLSX L identical to J.
6. **Timing.** 30 s. The text says the "scenario ended before reaching the surface" [V2 p.60]. Output 0.1 s (sim 5 about 0.01 s).
7. **Outputs.** Fig. 23 (a)–(x), V2 p.189–200 (PDF 193–204). Header of `Atmos_08_sim_05.csv` = H5 exactly.
8. **Sims.**
   - CSVs: 01–06 [CSV]. D.1.8: "six" [V2 p.188].
   - Notes [V2 p.188]:
     - SIM 6 and SIM 3 recorded zero Y aero force at t = 0.
     - For SIM 6 this is a recording artifact only (it also shows 0 TAS and q̄ at t = 0).
     - SIM 3 showed a real initial eastward-velocity jump, which grows its longitude and ECEF-Y differences.
9. **Criterion.** None stated. Table 77: SIM 1 0.142, SIM 2 0.153, SIM 3 0.076, SIM 4 0.077, SIM 5 0.076, SIM 6 0.068; largest 0.153 [V2 p.591].
   - Reference end state (sim 5): alt 16290.99886; lon 2.73579961e-4; Ve 8.731009259; Vd 863.6941069 [CSV].

## Case 9 — Sphere launched ballistically eastward along the Equator

1. **ID/title.**
   - V2 C.1.9 "Check-case 9 – eastward ballistic flight of a sphere" [V2 p.61 (PDF 65)].
   - Table 33: "9: Sphere launched ballistically eastward along Equator" [V2 p.61].
   - V1: verifies "Translational EOM" [V1 p.15].
   - XLSX M2; CSV dir `Atmos_09_EastwardCannonball`.
2. **Vehicle.** Sphere, CD = 0.1; cannonball DMLs.
3. **Earth.** WGS-84 rotating; J2 [V2 p.61].
4. **Atmosphere.** US 1976; no wind.
5. **Initial conditions.**
   - Table 33 [V2 p.61]: Geodetic [0, 0, 0]; velocity NED [0, 1000, -1000] ft/s; attitude [0, 0, 90] deg (roll, pitch, yaw → yaw 90 = nose east); rate [0, 0, 0].
   - Note: "Initial velocity is √2, 000 ft/s aligned 45° from vertical, heading east; zero angular rate relative to launch platform". [DERIVED] |V| = 1414.2136 ft/s = √2 × 1000; see OQ-6.
   - XLSX M:
     - M33–M35 = 0/0/0; M36–M38 = 0/1000/−1000; M41 yaw = 90;
     - M18–M20 = 0/0/0 (local-relative); M23–M25 inertial body = 2.56e-19 / −0.004178073 / 0;
     - M50 inertial Veast = 2525.9218298568094; M122 X = 20925646.99508 ft.
   - CSV sim 5: bodyAngularRateWrtEi pitch = −0.004178074; eiVelocity = [1000, 2525.922194546, 0]; eiPosition_X = 20925646.32545932 [CSV].
6. **Timing.** 30 s. Output 0.1 s (sim 5 about 0.01 s).
7. **Outputs.** Fig. 24 (a)–(x), V2 p.203–214 (PDF 207–218). Header of `Atmos_09_sim_05.csv` = H5 exactly.
8. **Sims.**
   - CSVs: 01–06 [CSV]. D.1.9: "six" [V2 p.201 (PDF 205)].
   - Notes [V2 p.201–202]:
     - The pitch change should equal the longitude change; all sims agree except SIM 2.
     - Sims differ "by nearly 5 ft" in east/up travel at t = 30 s.
     - SIM 4, 5, 6 were used as the basis, with the caveat "This was not an endorsement ...".
     - SIM 1/SIM 2 gravitation jumps look like recording delays (0.004 s / 0.01 s).
     - SIM 2 density table: first breakpoint 1,000 m, then 500 m.
     - SIM 1 aero accounts for only part of its differences; the remainder is unidentified.
     - SIM 3 initial roll −6.4e-6 deg. SIM 3 total differences at 30 s: −0.16 ft/s east, −1.4e-5 deg lon, +0.14 ft/s down, −4.3 ft alt; cause unidentified.
9. **Criterion.** None stated. Table 77: SIM 1 0.106, SIM 2 0.144, SIM 3 0.049, SIM 4 0.039, SIM 5 0.039, SIM 6 0.042; largest 0.144 [V2 p.591].
   - Reference end state (sim 5): alt 10160.97931 ft; lon 0.06164781332 deg; pitch 0.0616478133 deg; Ve 610.7459749; Vd 181.7485866 ft/s [CSV].

## Case 10 — Sphere launched ballistically northward along the Prime Meridian

1. **ID/title.**
   - V2 C.1.10 "Check-case 10 – northward ballistic flight of a sphere" [V2 p.61 (PDF 65)].
   - Table 34: "10: Sphere launched ballistically northward along Prime Meridian" [V2 p.62 (PDF 66 / idx 65)].
   - V1: verifies "Coriolis" [V1 p.15].
   - XLSX N2; CSV dir `Atmos_10_NorthwardCannonball`.
   - D.1.10 text says "northward along the Equator" [V2 p.215], a wording slip.
2. **Vehicle.** Sphere, CD = 0.1; cannonball DMLs.
3. **Earth.** WGS-84 rotating; J2 [V2 p.62].
4. **Atmosphere.** US 1976; no wind.
5. **Initial conditions.**
   - Table 34 [V2 p.62]: Geodetic [0, 0, 0]; velocity [1000, 0, -1000]; attitude [0, 0, 0] (x north); rate [0, 0, 0] (Earth-relative). Note: "√2, 000 ft/s ... heading north; zero angular rate relative to launch platform".
   - XLSX N: N36–N38 = 1000/0/−1000; N41 = 0; N23–N25 inertial body = 0.004178073/0/0; N50 = 1525.9218298568096; N128–N130 ECI Xdot/Ydot/Zdot = 1000 / 1525.92 / 1000.
   - CSV sim 5: bodyAngularRateWrtEi roll = 0.004178074; eiVelocity = [1000, 1525.922194546, 1000] [CSV].
6. **Timing.** 30 s. Output 0.1 s (sim 5 about 0.01 s).
7. **Outputs.** Fig. 25 (a)–(x), V2 p.216–227 (PDF 220–231). Header of `Atmos_10_sim_05.csv` = H5 exactly.
8. **Sims.**
   - CSVs: 01–06 [CSV]. D.1.10: "six" [V2 p.215 (PDF 219)].
   - Notes [V2 p.215]:
     - Coriolis drifts the trajectory west.
     - Pitch differences split the sims into two camps: SIM 4 and SIM 5 use geodetic-normal NED; SIM 1, 2, 6 use geocentric, differing by up to 4.2e-4 deg.
     - The SIM 2 latitude difference of −2.4e-4 deg (about −90 ft) is a geodetic-conversion accuracy issue, not a position difference. Geocentric latitudes differ by only −4.6e-6 deg (−1.7 ft).
   - CSV confirms: at t = 30 s, SIM 6 pitch 0.06171898 vs SIM 5 0.06213559 deg [CSV].
9. **Criterion.** None stated. Table 77: SIM 1 0.106, SIM 2 0.281, SIM 3 0.069, SIM 4 0.048, SIM 5 0.048, SIM 6 0.047; largest 0.281 [V2 p.591].
   - Reference end state (sim 5): alt 10114.79509 ft; lat 0.06213558892; lon −7.847582758e-5 deg; Vn 611.5350065; Ve −1.063770485; Vd 184.4468395 ft/s [CSV].

---

## JSON summary

```json
[
 {"id":1,"title":"Dragless sphere","earth":"WGS-84 ellipsoid (re=20925646.32546 ft, 1/f=298.257223563)","rotation":"yes, 7.292115e-5 rad/s","gravity":"J2 gravitation (eqs 29-31), mu=1.407644175720511e16 ft3/s2, J2=0.00108262982; CSV localGravity excludes centrifugal","atmosphere":"US Standard Atmosphere 1976","wind":"none","vehicle_files":["cannonball_inertia.dml","cannonball_aero.dml (CD forced to 0)"],"ic":{"lat_deg":0,"lon_deg":0,"alt_ft":30000,"v_ned_ft_s":[0,0,0],"euler_rpy_deg":[0,0,0],"rate_earth_rel_body_deg_s":[-0.004178073,0,0],"rate_inertial_body_deg_s":[0,0,0]},"duration_s":30,"csv_columns":"H1..H6 per sim (see section 0.6); sim_05 = H5","sims":[1,2,3,4,5,6],"criterion":"none stated (Table 77 achieved max 0.139%)","pages":"V2 p.12 (PDF16), p.56-57 (PDF60-61), p.93 (PDF97), p.97-109 (PDF101-113), p.591 (PDF595); V1 p.15 (PDF19)"},
 {"id":2,"title":"Tumbling brick with no damping or drag","earth":"WGS-84 ellipsoid","rotation":"yes, 7.292115e-5 rad/s","gravity":"J2 gravitation","atmosphere":"US Standard Atmosphere 1976","wind":"none","vehicle_files":["brick_inertia.dml","brick_aero.dml (all coefficients forced to 0)"],"ic":{"lat_deg":0,"lon_deg":0,"alt_ft":"CONFLICT: Table 26 and XLSX = 0; text and all CSVs = 30000","v_ned_ft_s":[0,0,0],"euler_rpy_deg":[0,0,0],"rate_earth_rel_body_deg_s":[9.995821927,20,30],"rate_inertial_body_deg_s":[10,20,30]},"duration_s":30,"csv_columns":"sim_05 = H5","sims":[1,2,4,5,6],"criterion":"none stated (Table 77 max 0.133%)","pages":"V2 p.13 (PDF17), p.57-58 (PDF61-62), p.110-122 (PDF114-126), p.591"},
 {"id":3,"title":"Tumbling brick with damping but no drag","earth":"WGS-84 ellipsoid","rotation":"yes, 7.292115e-5 rad/s","gravity":"J2 gravitation","atmosphere":"US Standard Atmosphere 1976","wind":"none","vehicle_files":["brick_inertia.dml","brick_aero.dml (CD forced to 0; Clp=Cmq=Cnr=-1)"],"ic":{"lat_deg":0,"lon_deg":0,"alt_ft":"CONFLICT: Table 27 and XLSX = 0; CSVs = 30000","v_ned_ft_s":[0,0,0],"euler_rpy_deg":[0,0,0],"rate_earth_rel_body_deg_s":[9.995821927,20,30],"rate_inertial_body_deg_s":[10,20,30]},"duration_s":30,"csv_columns":"sim_05 = H5","sims":[1,2,4,5,6],"criterion":"none stated (Table 77 max 0.972%)","pages":"V2 p.13, p.58 (PDF62), p.123-135 (PDF127-139), p.591"},
 {"id":4,"title":"Sphere with round non-rotating Earth","earth":"sphere r2=20902254.5305 ft","rotation":"no","gravity":"inverse square, mu=1.407644175720511e16 ft3/s2","atmosphere":"US Standard Atmosphere 1976","wind":"none","vehicle_files":["cannonball_inertia.dml","cannonball_aero.dml (CD=0.1)"],"ic":{"lat_deg":0,"lon_deg":0,"alt_ft":30000,"v_ned_ft_s":[0,0,0],"euler_rpy_deg":[0,0,0],"rate_earth_rel_body_deg_s":[10,20,30],"rate_inertial_body_deg_s":[10,20,30]},"duration_s":30,"csv_columns":"sim_05 = H5","sims":[2,4,5,6],"criterion":"none stated (Table 77 max 9.998%, SIM 2)","pages":"V2 p.38-39 (PDF42-43), p.47 (PDF51), p.58-59 (PDF62-63), p.93, p.136-148 (PDF140-152), p.591"},
 {"id":5,"title":"Sphere with round rotating Earth","earth":"sphere r2=20902254.5305 ft","rotation":"yes, 7.292115e-5 rad/s","gravity":"inverse square","atmosphere":"US Standard Atmosphere 1976","wind":"none","vehicle_files":["cannonball_inertia.dml","cannonball_aero.dml (CD=0.1)"],"ic":{"lat_deg":0,"lon_deg":0,"alt_ft":30000,"v_ned_ft_s":[0,0,0],"euler_rpy_deg":[0,0,0],"rate_earth_rel_body_deg_s":[9.995821927,20,30],"rate_inertial_body_deg_s":[10,20,30]},"duration_s":30,"csv_columns":"sim_05 = H5","sims":[2,4,5,6],"criterion":"none stated (Table 77 max 10.011%, SIM 2)","pages":"V2 p.59 (PDF63), p.149-161 (PDF153-165), p.591"},
 {"id":6,"title":"Sphere with ellipsoidal rotating Earth","earth":"WGS-84 ellipsoid","rotation":"yes, 7.292115e-5 rad/s","gravity":"J2 gravitation","atmosphere":"US Standard Atmosphere 1976","wind":"none","vehicle_files":["cannonball_inertia.dml","cannonball_aero.dml (CD=0.1)"],"ic":{"lat_deg":0,"lon_deg":0,"alt_ft":30000,"v_ned_ft_s":[0,0,0],"euler_rpy_deg":[0,0,0],"rate_earth_rel_body_deg_s":[-0.004178073,0,0],"rate_inertial_body_deg_s":[0,0,0]},"duration_s":30,"csv_columns":"sim_05 = H5","sims":[1,2,3,4,5,6],"criterion":"none stated (Table 77 max 0.142%)","pages":"V2 p.59-60 (PDF63-64), p.162-174 (PDF166-178), p.591"},
 {"id":7,"title":"Sphere with steady wind","earth":"WGS-84 ellipsoid","rotation":"yes, 7.292115e-5 rad/s","gravity":"J2 gravitation","atmosphere":"US Standard Atmosphere 1976","wind":"steady 20 ft/s from due west (airmass moving east); vertical component NOT FOUND","vehicle_files":["cannonball_inertia.dml","cannonball_aero.dml (CD=0.1)"],"ic":{"lat_deg":0,"lon_deg":0,"alt_ft":30000,"v_ned_ft_s":[0,0,0],"euler_rpy_deg":[0,0,0],"rate_earth_rel_body_deg_s":[-0.004178073,0,0],"rate_inertial_body_deg_s":[0,0,0]},"duration_s":30,"csv_columns":"sim_05 = H5","sims":[1,2,3,4,5,6],"criterion":"none stated (Table 77 max 0.142%)","pages":"V2 p.60 (PDF64), p.175-187 (PDF179-191), p.591, p.604"},
 {"id":8,"title":"Sphere with wind shear","earth":"WGS-84 ellipsoid","rotation":"yes, 7.292115e-5 rad/s","gravity":"J2 gravitation","atmosphere":"US Standard Atmosphere 1976","wind":"Vwind = (0.003*h - 20) ft/s from west, h = height MSL in ft (70 ft/s at 30000 ft)","vehicle_files":["cannonball_inertia.dml","cannonball_aero.dml (CD=0.1)"],"ic":{"lat_deg":0,"lon_deg":0,"alt_ft":30000,"v_ned_ft_s":[0,0,0],"euler_rpy_deg":[0,0,0],"rate_earth_rel_body_deg_s":[-0.004178073,0,0],"rate_inertial_body_deg_s":[0,0,0]},"duration_s":30,"csv_columns":"sim_05 = H5","sims":[1,2,3,4,5,6],"criterion":"none stated (Table 77 max 0.153%)","pages":"V2 p.60-61 (PDF64-65), p.188-200 (PDF192-204), p.591"},
 {"id":9,"title":"Sphere launched ballistically eastward along Equator","earth":"WGS-84 ellipsoid","rotation":"yes, 7.292115e-5 rad/s","gravity":"J2 gravitation","atmosphere":"US Standard Atmosphere 1976","wind":"none","vehicle_files":["cannonball_inertia.dml","cannonball_aero.dml (CD=0.1)"],"ic":{"lat_deg":0,"lon_deg":0,"alt_ft":0,"v_ned_ft_s":[0,1000,-1000],"euler_rpy_deg":[0,0,90],"rate_earth_rel_body_deg_s":[0,0,0],"rate_inertial_body_deg_s":[0,-0.004178073,0]},"duration_s":30,"csv_columns":"sim_05 = H5","sims":[1,2,3,4,5,6],"criterion":"none stated (Table 77 max 0.144%)","pages":"V2 p.61 (PDF65), p.201-214 (PDF205-218), p.591"},
 {"id":10,"title":"Sphere launched ballistically northward along Prime Meridian","earth":"WGS-84 ellipsoid","rotation":"yes, 7.292115e-5 rad/s","gravity":"J2 gravitation","atmosphere":"US Standard Atmosphere 1976","wind":"none","vehicle_files":["cannonball_inertia.dml","cannonball_aero.dml (CD=0.1)"],"ic":{"lat_deg":0,"lon_deg":0,"alt_ft":0,"v_ned_ft_s":[1000,0,-1000],"euler_rpy_deg":[0,0,0],"rate_earth_rel_body_deg_s":[0,0,0],"rate_inertial_body_deg_s":[0.004178073,0,0]},"duration_s":30,"csv_columns":"sim_05 = H5","sims":[1,2,3,4,5,6],"criterion":"none stated (Table 77 max 0.281%)","pages":"V2 p.61-62 (PDF65-66), p.215-227 (PDF219-231), p.591"}
]
```

---

## Open questions / discrepancies found

1. **OQ-1: case 2/3 initial altitude.**
   - Tables 26/27 [V2 p.58] and XLSX F35/G35 give 0 ft. The XLSX ECI and gravity rows for F/G are also computed at 0 ft (F122 = 20925646.99508 ft; F133 = −32.1988 ft/s²).
   - The text [V2 p.57, p.110] says 30,000 ft, and **every** case 2/3 CSV starts at 30,000 ft with localGravity 32.10654.
   - **Recommendation: use 30,000 ft (matches the reference data).**
2. **OQ-2: rate frame.**
   - C.1 says table rates are "relative to the inertial frame" [V2 p.56]. However, the case 1/2/3/5/6/7/8 table values are Earth-relative: XLSX row 17 "Rates w.r.t. local frame in body axis"; row 22 "Inertial rotation components" shows the inertial values; CSV bodyAngularRateWrtEi matches the XLSX inertial row.
   - Initialize from the XLSX inertial rows 23–25 (or the Earth-relative rows 18–20 transformed consistently).
   - Figure captions say "(w.r.t. NED Frame)" while the variable name says WrtEi. The data is inertial.
3. **OQ-3: constants mismatch between the XLSX and Table 73.**
   - XLSX Re = `=6378137*3.28084` = 20925646.99508 ft vs Table 73 20925646.32546 ft (= 6378137/0.3048).
   - XLSX μ = 1.407644311e16 vs 1.407644175720511e16 ft³/s².
   - XLSX ω = 0.004178073 deg/s → 7.292113023867704e-5 vs 7.292115e-5 rad/s.
   - XLSX sphere radius 20902255.199 vs 20902254.5305 ft.
   - All CSVs match Table 73 (e.g. eiPosition_X = 20955646.32546; eiVelocity_Y = 1528.10982905). E.2.1 says all tools eventually used Tables 73/74 [V2 p.599].
   - **Use Table 73; treat XLSX derived ECI/gravity numbers as approximate.**
4. **OQ-4: XLSX internal inconsistencies for cases 4/5.**
   - H50/I50 inertial east velocity uses the global `omega` even though H8 = 0 (case 4 non-rotating). The CSV case 4 eiVelocity_Y = 0.
   - H44/H122/I44/I122 use WGS Re + h (20955646.99508) while H48/I48 use the sphere radius (20932255.199).
5. **OQ-5: SIM ↔ tool mapping.** Masked by design (NOT FOUND). V2 p.95 says "Two of these simulation tools are represented in both atmospheric and orbital results", but B.6 describes three tools (LaSRS++, MAVERIC, POST II) as used for both. Unresolved.
6. **OQ-6: "√2, 000 ft/s" (Tables 33/34, XLSX M199/N199).** The NED components [0, 1000, −1000] / [1000, 0, −1000] give 1414.21 ft/s = √2·1000, and CSV TAS 837.8986 kt equals 1414.21 ft/s. Treat as √2 × 1,000 ft/s.
7. **OQ-7: recording/output rate.** The agreed rate is not stated in the documents (V2 p.605 only says one was agreed). CSVs are 0.1 s for sims 1, 2, 3, 4, 6 and about 0.01 s non-uniform for sim 5. Sim 5 files contain a duplicated `feVelocity_ft_s_Z` column.
8. **OQ-8: altitude reference for wind shear and atmosphere.**
   - Case 8 uses "height MSL". C.1/E.2.3 say altitude is geometric above the reference ellipsoid, and no geoid is modelled.
   - Whether US1976 is to be evaluated at geometric h or geopotential Z is not specified (NOT FOUND). The consensus sims used the equations.
   - Wind vertical component and wind reference frame: NOT FOUND (assume horizontal, Earth-fixed).
9. **OQ-9: brick damping rate.** `brick_aero.dml` uses body angular rates PB/QB/RB without saying whether they are inertial, Earth-relative or airmass-relative (NOT FOUND). VRW has minValue 0.5 ft/s, which matters at t = 0 when airspeed is 0.
10. **OQ-10: Case 3 vehicle label.** Table 27 and XLSX G198 say "Dragless rotating sphere with aero damping"; the text (C.1.3, D.1.3) and data are the brick.
11. **OQ-11: Case 2 notes vs text.** The Table 26 note zeroes only Clp, Cmq, Cnr, but the text zeroes all Table 5 coefficients, including CD = 0.01. The CSV shows all aero forces are 0, so use CD = 0 as well.
12. **OQ-12: Gravity direction and localGravity.** The CSV localGravity is J2 gravitation magnitude without centrifugal (verified numerically). The XLSX rows 136/181 give "gr"/"gamma_r" including centrifugal (−31.995 ft/s²). A framework comparing to `localGravity_ft_s2` must output gravitation magnitude, not gravity. The report [V2 p.228, V1 p.19] implies the EOM should resolve J2 gravitation (with centrifugal handled by the rotating-frame EOM) along the geodetic normal.
13. **OQ-13: Case 4/5 SIM 2 data.** It has a 0.01 ft/s initial north velocity, localGravity = 0 at t = 0 and truncated μ. The report recommends excluding its X-force and gravity [V2 p.589]. SIM 2 Euler angles should be excluded in all cases, and SIM 2 aero moments are at the MRC.
