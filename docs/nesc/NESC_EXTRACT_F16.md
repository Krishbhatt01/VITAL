# NESC F-16 check-cases (atmospheric 11, 12, 13.1-13.4, 15, 16): verification specification

Source extraction for a new MATLAB framework. All sources were read-only; nothing under C:\VITAL was modified.

## Citation conventions

- **V1 p.N / PDF k**: Vol I, NASA-TM-2015-218675 summary (`...EOM_checkcase_summary.pdf`). N is the printed "Page # N of 26"; k is the 1-based PDF page index.
- **V2 p.N / PDF k**: Vol II, appendices (`...EOM_checkcase_appendices.pdf`). N is the printed "N of 609"; k is the 1-based PDF index. For Vol II, k = N + 4.
- **XLSX Atmos!Cell**: `C:\VITAL\data\nesc\original\Initial_Conditions.xlsx`, sheet `Atmos`. The F-16 columns are O=11, P=12, Q=13.1, R=13.2, S=13.3, T=13.4, U=14, V=15, W=16.
- **file:line**: line numbers in the DML, .m and README files. README.html line numbers are the raw HTML source lines.
- Package root `PKG` = `C:\VITAL\data\nesc\extracted\Atmospheric_models\F16_package\F16_package\`
- CSV root `CSV` = `C:\VITAL\data\nesc\extracted\Atmospheric_checkcases\Atmospheric_checkcases\`
- Scratch scripts used for this extraction are in `scratchpad\f16work\`: `pg.py`, `dml.py`, `infix.py`, `evalchk.py`, `cmpchk.py`.

---

## Common environment for all F-16 cases

| Item | Value | Source |
|---|---|---|
| Geodesy | WGS-84, rotating | V2 Table 23 p.54/PDF 58; per-case tables 35-43 (V2 pp.62-67/PDF 66-71); XLSX Atmos!O194:W194 |
| Gravitation | J2 | Same tables; XLSX Atmos!O196:W196 |
| J2 equations (ECI) | ẍ = -μx/r³·[1 - 3J2·re²(5z²-r²)/(2r⁴)]; ÿ likewise with y; z̈ = -μz/r³·[1 - 3J2·re²(5z²-3r²)/(2r⁴)] | V2 eqs 29-31, p.47/PDF 51 |
| Atmosphere | US Standard 1976 | Tables 35-43; V2 B.5.1 p.48/PDF 52 |
| Wind | None, "still air" / "no wind" | V2 Table 23 p.54/PDF 58; Tables 35-43 |
| Normative constants (Table 73, "Atmospheric check-cases") | re = 6378137.0 m = 20925646.32546 ft; μ = 3.986004418e14 m³/s² = 1.407644175720511e16 ft³/s²; ωE = 7.292115e-5 rad/s; J2 = 0.00108262982; 1/f = 298.257223563. Sphere radius 6371007.1809 m is used only for the round-Earth cases, not the F-16 cases. | V2 Table 73 p.93/PDF 97. Text at V2 p.92/PDF 96 says Table 73 values "should be used in attempting to replicating the check-case results". |
| Unit conversions | m→ft = 1/0.3048; ft/s→kt = 1097.28/1852 | V2 Table 73 p.93/PDF 97 |
| Constants in the spreadsheet (they differ from Table 73) | Re = 20925646.99508 ft; μ = 1.407644311e16 ft³/s²; ω = 0.004178073 deg/s = 7.292113023867704e-5 rad/s; J2 = 0.00108262982; 1/f = 298.257223563; b = 20855487.262668155 ft | XLSX Atmos!D5:D13 (same values in every column O-W) |
| Altitude definition | Geometric height above the reference ellipsoid | V2 p.56/PDF 60; V2 p.604/PDF 608 |
| IC conventions | Position is geodetic lat/lon (deg) and alt (ft). Velocity is Earth-relative, in NED axes, ft/s. Attitude is 3-2-1 Euler angles from geodetic NED, listed as roll, pitch, yaw (deg). "Rate is initial rotation rate presented in body-axis quantities relative to the inertial frame" (deg/s). | V2 p.56/PDF 60 |
| CM location | Fixed by consensus at 25% MAC. The DML default is 35%. | V2 p.604/PDF 608; README.html:1234-1235, 1259-1260; F16_inertia.dml:44 |
| Aero/propulsion moment reference | MRC at 35% MAC. Transfer to the CM must be done externally. | F16_aero.dml:170-175 (mod O); README.html:1829-1832 |
| Recording | All CSVs are at Δt = 0.1 s (computed from files). V2 says only "A recording rate was agreed to for each check-case". | V2 p.605/PDF 609 |
| Integration rates of the tools | Free choice ("free to pick the numerical integration time step sizes"). LaSRS++ ran cases 11 and 13-16 at 100 Hz and case 12 at 200 Hz; POST II ran atmospheric cases at 100 Hz RK4; VMSRTE AB2 0.01 s; Core RK4 0.01 s; JSBSim AB 120 Hz; MAVERIC RK4 0.1 s. SIM numbers are anonymized, so the tool-to-SIM mapping is NOT FOUND. | V2 p.95/PDF 99; Table 21 p.51/PDF 55; Table 22 p.52/PDF 56; B.6.5-B.6.7 pp.52-53; SIM anonymized: V2 p.10/PDF 14 and p.94/PDF 98 |
| Sims that supplied F-16 data | SIM 2, SIM 4, SIM 5 for every F-16 case (files `*_sim_02/04/05.csv`) | CSV dirs; V2 Table 79 p.593/PDF 597 |

### CSV header rows (verbatim; identical across all 8 cases for a given sim number)

- **sim_02** (27 columns):
  `time,feVelocity_ft_s_X,feVelocity_ft_s_Y,feVelocity_ft_s_Z,altitudeMsl_ft,longitude_deg,latitude_deg,localGravity_ft_s2,eulerAngle_deg_Yaw,eulerAngle_deg_Pitch,eulerAngle_deg_Roll,bodyAngularRateWrtEi_deg_s_Roll,bodyAngularRateWrtEi_deg_s_Pitch,bodyAngularRateWrtEi_deg_s_Yaw,altitudeRateWrtMsl_ft_min,speedOfSound_ft_s,airDensity_slug_ft3,ambientPressure_lbf_ft2,ambientTemperature_dgR,aero_bodyForce_lbf_X,aero_bodyForce_lbf_Y,aero_bodyForce_lbf_Z,aero_bodyMoment_ftlbf_L,aero_bodyMoment_ftlbf_M,aero_bodyMoment_ftlbf_N,mach,trueAirspeed_nmi_h`
- **sim_04** (32 columns):
  `time,eiPosition_ft_X,eiPosition_ft_Y,eiPosition_ft_Z,eiVelocity_ft_s_X,eiVelocity_ft_s_Y,eiVelocity_ft_s_Z,feVelocity_ft_s_X,feVelocity_ft_s_Y,feVelocity_ft_s_Z,altitudeMsl_ft,longitude_deg,latitude_deg,localGravity_ft_s2,eulerAngle_deg_Yaw,eulerAngle_deg_Pitch,eulerAngle_deg_Roll,bodyAngularRateWrtEi_deg_s_Roll,bodyAngularRateWrtEi_deg_s_Pitch,bodyAngularRateWrtEi_deg_s_Yaw,speedOfSound_ft_s,airDensity_slug_ft3,ambientPressure_lbf_ft2,ambientTemperature_dgR,aero_bodyForce_lbf_X,aero_bodyForce_lbf_Y,aero_bodyForce_lbf_Z,aero_bodyMoment_ftlbf_L,aero_bodyMoment_ftlbf_M,aero_bodyMoment_ftlbf_N,mach,dynamicPressure_lbf_ft2`
- **sim_05** (38 columns; `feVelocity_ft_s_Z` appears twice, at columns 12 and 37 zero-based, and the two copies are bit-identical in all 8 files):
  `time,eiPosition_ft_X,eiPosition_ft_Y,eiPosition_ft_Z,gePosition_ft_X,gePosition_ft_Y,gePosition_ft_Z,eiVelocity_ft_s_X,eiVelocity_ft_s_Y,eiVelocity_ft_s_Z,feVelocity_ft_s_X,feVelocity_ft_s_Y,feVelocity_ft_s_Z,altitudeMsl_ft,longitude_deg,latitude_deg,localGravity_ft_s2,eulerAngle_deg_Yaw,eulerAngle_deg_Pitch,eulerAngle_deg_Roll,bodyAngularRateWrtEi_deg_s_Roll,bodyAngularRateWrtEi_deg_s_Pitch,bodyAngularRateWrtEi_deg_s_Yaw,altitudeRateWrtMsl_ft_min,speedOfSound_ft_s,airDensity_slug_ft3,ambientPressure_lbf_ft2,ambientTemperature_dgR,aero_bodyForce_lbf_X,aero_bodyForce_lbf_Y,aero_bodyForce_lbf_Z,aero_bodyMoment_ftlbf_L,aero_bodyMoment_ftlbf_M,aero_bodyMoment_ftlbf_N,mach,dynamicPressure_lbf_ft2,trueAirspeed_nmi_h,feVelocity_ft_s_Z`

Signal definitions are in V2 Table 75, p.96/PDF 100:
- `aero_bodyMoment` is defined "about the CM". SIM 2 nevertheless recorded moments at the MRC (V2 p.229/PDF 233).
- `bodyAngularRateWrtEi` is the body rate with respect to ECI.
- `feVelocity` is the velocity with respect to the (flat-)Earth frame, in N-E-D axes.
- `localGravity` is gravitational acceleration in the local down direction.
- `eulerAngle` is 3-2-1 relative to NED.

### CSV extents (computed; all at Δt = 0.1 s)

| Case | sim_02 t_end | sim_04 t_end | sim_05 t_end | Spec duration |
|---|---|---|---|---|
| 11 | 200.0 (2001 rows) | 180.0 | 180.0 | 180 |
| 12 | 200.0 | 180.0 | 180.0 | 180 |
| 13.1 | 20.0 | 20.0 | **60.0** | 20 |
| 13.2 | 20.0 | 20.0 | **60.0** | 20 |
| 13.3 | 30.0 | 30.0 | **239.9** (float32 time: 239.89999389648438) | 30 |
| 13.4 | 60.0 | 60.0 | **239.9** | 60 |
| 15 | 180.0 | 180.0 | 180.0 | 180 |
| 16 | 180.0 | 180.0 | 180.0 | 180 |

---

## A. Per-case specifications

### Case 11: Subsonic F-16 trimmed flight

- **Title.** Three forms appear:
  - "Subsonic F-16 trimmed flight across planet" (V2 Table 23 p.54/PDF 58; V1 Table 6.3-1 p.16/PDF 20)
  - Section heading "Check-case 11 – steady flight of a subsonic aircraft" (V2 C.1.11 p.62/PDF 66)
  - Table 35 scenario name "11: Subsonic winged flight (trimmed straight & level)" (V2 p.62/PDF 66; XLSX Atmos!O2)
- **Verifies.** "Atmosphere, air-data calculations" (V2 Table 23).
- **Earth / gravity / atmosphere / wind.** WGS-84 rotating; J2; US 1976; no wind. See the common table.
- **Initial conditions** (V2 Table 35 p.62/PDF 66):
  - Geodetic position [36.01916667, -75.67444444, 10013] deg, deg, ft MSL
  - Local-relative velocity [400, 400, 0] ft/s (NED)
  - Attitude [0, 0, 45] deg (roll, pitch, yaw)
  - Body rates [0, 0, 0] deg/s
  - Notes: "Initial position is 10,000 ft above KFFA airport on a 45° true course. 335.15 KTAS. Stability augmentation off. Test of trim solution."
- **Spreadsheet cross-check** (XLSX Atmos col O):
  - O33 = 36.01916666666666, O34 = -75.67444444444445, O35 = 10013
  - O36/O37/O38 = 400/400/0; O41 (yaw) = 45; O39 and O40 (pitch, roll) = 0
  - O18:O20 (rates w.r.t. local frame, body axes) = 0
  - O23:O25 (inertial rates, body axes) = [0.0029543437505924223, -0.002954343750592422, 0] deg/s
  - O199 notes say "True airspeed 335.15 knots"; O195 duration = 180 s
  - Everything matches V2 Table 35.
- **Speed.**
  - |V| = 565.685 ft/s, which is 335.16 KTAS (computed).
  - The C.1.11 text says "400 KTAS relative to the still atmosphere" (V2 p.62/PDF 66). That contradicts the table (335.15 KTAS) and is a text error: 400 is the per-axis ft/s value.
  - Mach ≈ 0.525 (CSV sim_05 t=0: mach 0.52507).
  - KEAS is not given in Table 35. Using sim_05 t=0 density 0.001754839 slug/ft³ gives ≈ 287.98 KEAS (computed). V2 p.256/PDF 260 states the "trim solver's speed of 287.98 KEAS".
- **Trim.**
  - The trim solver solves for zero linear and angular accelerations at 10,013 ft MSL "by varying pitch attitude, elevator position, and throttle setting" (V2 p.62/PDF 66).
  - Trim is done with stabilityAugmentationOn_disc and autopilotOn_disc both false. Trim should adjust trimmedPilotControl_throttle / trimmedPilotControl_long. If the tool's trim adjusts pilotControl_* instead, set the trimmed* inputs to 0 (V2 p.16/PDF 20; README.html:1363-1370).
  - The trimmed rotational rate definition differed between tools (V2 p.228/PDF 232):
    - SIM 2: zero inertial rate.
    - SIM 4: pitch rate that holds pitch angle.
    - SIM 5: three-axis rate that holds all Euler angles relative to local level.
- **README reference trim** (constant-g Simulink sim, *not* the NESC environment; README.html:1821-1824, 1854-1891):
  - alt 10,013 ft; TAS 565.6854 ft/s; CM 25%
  - θ 2.6538°; stick 12.96% aft; elevator -3.2410° TED
  - throttle and PLA 13.9019%
- **CSV t=0 values** (computed):
  - θ: sim_02 2.64333°, sim_04 2.63873°, sim_05 2.63893°
  - φ: sim_02 -0.17183° (from its geocentric-gravity trim, V2 p.228-229/PDF 232-233); sim_04 and sim_05 0°
- **Controller.** Uncontrolled / "Unaugmented F-16". SAS off (Table 35 notes; XLSX O198). "No pilot inputs were used in any of the check-cases" (V2 p.16/PDF 20). If F16_control.dml is used with sasOn = apOn = 0, the surfaces are simply the trimmed values (see C).
- **Duration.** 180 s (Table 35; XLSX O195).
- **Sims.** 02, 04, 05. The D.1.11 text says "two of the selected simulation tools" yet discusses three (V2 p.228/PDF 232).
- **Criterion.** None stated (see Section A.9).
  - Reported end-state separations: SIM 2 vs SIM 4/5 ≈ 666 ft after 180 s; SIM 4 vs SIM 5 ≈ 4 ft (V2 p.229/PDF 233).
  - Appendix E worst-case % difference (SIM 4/5, first 8 s excluded, SIM 2 excluded) = 2.786% (V2 Table 79 p.593/PDF 597).

### Case 12: Supersonic F-16 trimmed flight

- **Title.**
  - "Supersonic F-16 trimmed flight across planet" (V2 Table 23 p.54/PDF 58)
  - Section heading "Check-case 12 – steady flight of a supersonic aircraft" (V2 C.1.12 p.63/PDF 67)
  - Table 36 name "12: Supersonic winged flight (trimmed straight & level)" (XLSX Atmos!P2)
- **Verifies.** "Supersonic air-data calculations".
- **Environment.** Same as case 11.
- **Initial conditions** (V2 Table 36 p.63/PDF 67):
  - Position [36.01916667, -75.67444444, 30013]
  - Velocity [1414.213562, 1414.213562, 0] ft/s
  - Attitude [0, 0, 45]; rates [0, 0, 0]
  - Notes: "Initial position is 30,000 ft above KFFA airport on a 45° true course. True airspeed 2,000 ft/s. Stability augmentation off. Test of trim solution."
- **Spreadsheet cross-check.** XLSX P33:P41 match (P36 = P37 = 1414.2135623730949; P35 = 30013); P195 = 180.
- **Speed.**
  - 2000 ft/s TAS. The C.1.12 text says "(Mach 20)", a typo for about Mach 2.0 (V2 p.63/PDF 67).
  - CSV sim_05 t=0 mach = 2.01047.
  - KEAS: NOT FOUND.
- **Trim.** Trimmed "by varying pitch attitude, elevator position, and throttle setting" before open-loop flight for 180 s (V2 p.63/PDF 67). CSV t=0 θ: sim_02 -0.736595°, sim_04 -0.741575°, sim_05 -0.741576°.
- **Controller.** None ("Unaugmented F-16", SAS off).
- **Duration.** 180 s.
- **Sims.** 02, 04, 05 ("two of the selected simulation tools" in the D.1.12 text, V2 p.242/PDF 246).
- **Criterion.** None stated.
  - Reported separations: SIM 4 vs SIM 5 = 7.5 ft; SIM 2 vs others 760 ft (V2 p.242/PDF 246).
  - Appendix E: 0.631% (Table 79). Note: "Tiny differences in vertical velocity for supersonic trim fly-out case 12 that led to large percentage errors" were excluded (V2 p.590/PDF 594).

### Case 13.1: Subsonic altitude change

- **Title.**
  - "Check-case 13.1 – altitude change of a subsonic aircraft" (V2 C.1.13 p.63/PDF 67)
  - Table 37 name "13.1: Maneuvering flight of 6-DOF rigid aircraft with non-linear aerodynamics (subsonic): Altitude change" (V2 p.64/PDF 68)
  - Group name in Table 23: "Subsonic F-16 maneuvering flight", verifies "Multidimensional table look-up"
- **Environment.** Same as case 11.
- **Initial conditions.** Identical to case 11 (Table 37; XLSX Q33:Q41). Notes: "Initially straight & level. t = 5 sec: command altitude 100-ft increase."
- **Controller.**
  - F16_control autopilot engaged: autopilotOn_disc and stabilityAugmentationOn_disc both > 0.5 (V2 p.63/PDF 67).
  - At t = +5.0 s, altitudeMslCommand is stepped up by 100 ft (V2 p.63/PDF 67; README.html:1955-1958).
  - Baseline command values: the altitude command is implicitly the trimmed 10,013 ft and the speed command the trimmed ≈ 287.98 KEAS (V2 p.256/PDF 260, p.269/PDF 273). The baseline altitude value itself is NOT FOUND explicitly.
  - The autopilot heading command "attempted to maintain ground track at 45°" (V2 p.255/PDF 259), so trueBaseCourseCommand = 45° and lateralDeviationError = 0.
- **Duration.** 20 s (Table 37; XLSX Q195). The sim_05 file runs to 60 s.
- **CSV check** (computed): altitude goes from 10013 to about 10112.6 ft at t = 20 s in all three sims.
- **Sims.** 02, 04, 05 (D.1.13 "three of the selected simulation tools", V2 p.255/PDF 259).
- **Criterion.** None stated.
  - Reported: SIM 4 vs SIM 5 horizontal difference 2.5 ft at 20 s; SIM 2 vs SIM 5 19 ft (V2 p.256/PDF 260).
  - Appendix E: 1.080%, with a footnote on mismatched moment/X-force transient timing (Table 79).

### Case 13.2: Subsonic airspeed change

- **Title.**
  - "Check-case 13.2 – velocity change of a subsonic aircraft" (V2 C.1.14 p.64/PDF 68)
  - Table 38 name "...(subsonic): Velocity change"
- **Initial conditions.** Same as case 11 (Table 38; XLSX R).
- **Controller.** F16_control autopilot plus SAS. At t = +5.0 s, equivalentAirspeedCommand drops 5 kt (V2 p.64/PDF 68, "decrease commanded 5 KEAS"). V2 p.269/PDF 273 gives the target: "decrease speed 5 kt to 282.98 KEAS".
- **Command-size conflict.**
  - README.html:1967-1970 describes a **10-kt** reduction.
  - V2 p.269/PDF 273: "SIM 2 results have not been updated" from an earlier, twice-as-large change.
  - CSV check (computed): |V_NED| falls by about 21.6 ft/s in sim_02 versus about 9.8 ft/s in sim_04/05, consistent with SIM 2 using 10 kt.
- **Duration.** 20 s (the sim_05 file runs to 60 s).
- **Sims.** 02, 04, 05. SIM 2 used the wrong step size.
- **Criterion.** None stated.
  - Reported end separations: SIM 4 vs SIM 5 2.2 ft; SIM 2 vs 4/5 135 and 137 ft (V2 p.269/PDF 273).
  - Appendix E: 0.218%.

### Case 13.3: Subsonic heading change

- **Title.**
  - "Check-case 13.3 – course change of a subsonic aircraft" (V2 C.1.15 p.64/PDF 68)
  - Table 39 name "...(subsonic): Heading change" (V2 p.65/PDF 69)
- **Initial conditions.** Same as case 11 (XLSX S).
- **Controller.** At t = +15.0 s, trueBaseCourseCommand changes 15° to the right (V2 pp.64-65/PDF 68-69), from 45° to 60°. lateralDeviationError is held at 0, so this is a heading change, not tracking (README.html:1979-1984).
- **CSV check** (computed): ψ goes from 45° to about 59.9° at 30 s, with φ reaching the +30° bank limit.
- **Duration.** 30 s (the sim_05 file runs to 239.9 s).
- **Sims.** 02, 04, 05.
- **Criterion.** None stated.
  - End separations: SIM 4-5 5.4 ft, SIM 5-2 14.3 ft, SIM 2-4 19.1 ft (V2 p.282/PDF 286).
  - The same page repeats contradictory 135/137-ft figures, apparently copied from 13.2.
  - Appendix E: 14.947% (Table 79).

### Case 13.4: Subsonic lateral side-step

- **Title.**
  - "Check-case 13.4 – lateral offset maneuver of a subsonic aircraft" (V2 C.1.16 p.65/PDF 69)
  - Table 40 name "...(subsonic): Lateral course offset"
- **Initial conditions.** Same as case 11 (XLSX T).
- **Controller.**
  - At t = +20.0 s a 2,000-ft lateral offset is commanded to the right through lateralDeviationError.
  - lateralDeviationError must be recomputed every step "by additional user-supplied logic, based on the aircraft's position relative to the new offset course" (V2 p.65/PDF 69).
  - Sign: +right of course (F16_control.dml:152). The aircraft starts 2,000 ft left of the new course, so the error begins at -2,000 ft, matching README.html:2003-2004 "initially in the amount -2,000 ft".
- **Direction conflict in the README.** README.html:2001-2007 says both "2,000 ft to the left of the original course" and "2,000 to the right of and parallel", and uses trueBaseCourseCommand = 90° (East), not 45°. The TM is normative: right offset, 45° base course.
- **CSV check** (computed): φ goes to about +29.5° at 20.5 s, ψ peaks near 57.9° at 30 s, and returns to about 45.2° at 60 s. That is a right side-step, consistent with the TM.
- **How to compute the offset.** The formula is NOT FOUND. The TM notes the tools differed in "methods used by each simulation to estimate the current lateral offset" (V2 p.296/PDF 300).
- **Duration.** 60 s (the sim_05 file runs to 239.9 s).
- **Sims.** 02, 04, 05.
- **Criterion.** None stated.
  - End separations: SIM 4-5 11.6 ft, SIM 5-2 40.3 ft, SIM 2-4 31.8 ft (V2 p.296/PDF 300).
  - Appendix E: 16.312%.

### Case 15: Circle the North Pole

- **Title.**
  - "Circular F-16 flight around North pole" (V2 Table 23 p.54/PDF 58), verifies "Propagation, geodetic transforms"
  - Section heading "Check-case 15 – circumnavigation of the North pole" (V2 C.1.18 p.66/PDF 70)
  - Table 42 name "15: Circular flight around North Pole" (V2 p.67/PDF 71)
- **Environment.** WGS-84 rotating; J2; US 1976; no wind.
- **Initial conditions** (V2 Table 42):
  - Position [89.95, -45, 10000]
  - Velocity [0, 563.643, 0] ft/s (due east)
  - Attitude [0, 0, 90]; rates [0, 0, 0]
  - Notes: "Initial conditions trimmed straight and level; engage autopilot at first time step."
- **Spreadsheet cross-check.** XLSX V33 = 89.95, V34 = -45, V35 = 10000, V36 = 0, V37 = 563.643, V41 = 90, V195 = 180. All match.
- **Speed.**
  - 563.643 ft/s TAS. CSV sim_02 t=0 trueAirspeed = 333.9455 kt; mach 0.523143 to 0.523149.
  - KEAS not stated. From CSV density it is ≈ 287.0 KEAS (computed).
- **Controller.**
  - F16_gnc.dml with selectCircumnavigator_disc = 1.0; autopilotOn and stabilityAugmentationOn = 1.0. The tool must feed geodetic lat/lon into geLatitude/geLongitude. The TM text misspells the latter as "gnLongitude" (V2 p.66/PDF 70).
  - Target is a 3-nm counter-clockwise circle around the pole. "The vehicle turned left from the original heading, flew to and intercepted the desired circular track" (V2 p.66/PDF 70).
  - altitudeMslCommand and equivalentAirspeedCommand values: NOT FOUND. The CSVs settle near 9994-9996 ft, the Type-0 offset below 10,000.
- **README description.** README.html:2061-2070 describes a different demonstration: start at 89.95°, lon 0°, heading 100°, 360 s. It is not the NESC case.
- **Duration.** 180 s (the README says circles take about 3.5 min, README.html:1583; V2 p.26/PDF 30).
- **Sims.** 02, 04, 05. D.1.17 says "two of the selected simulation tools" but plots three (V2 p.309/PDF 313).
- **Criterion.** None stated.
  - Reported: SIM 4 vs SIM 5 longitude difference 0.0639° (21 ft) after 180 s; SIM 2 leads by 0.93° (300 ft) (V2 p.311/PDF 315).
  - Appendix E: 11.845%.
- **Trim notes.**
  - SIM 5 started with Earth-relative roll rate 0.0828 deg/s and a large yaw rate. The CSV sim_05 bodyAngularRateWrtEi at t=0 is [0.0827914, -0.00154103, -1.76395] deg/s.
  - SIM 4 was not trimmed at t=0: PLA 6.32% vs SIM 5 13.86%; elevator +1.09° vs -3.26° (V2 pp.310-311/PDF 314-315).

### Case 16: Circle the Equator / date-line intersection

- **Title.**
  - "Circular F-16 flight around Equator/dateline intersection" (V2 Table 23), verifies "Sign changes in lat. & long."
  - Section heading "Check-case 16 – circular flight around the Equator-IDL intersection" (V2 C.1.19 p.67/PDF 71)
  - Table 43 name "16: Circular flight around Equator/IDL intersection"
- **Initial conditions** (Table 43, V2 p.67/PDF 71):
  - Position [0, -179.95, 10000]
  - Velocity [563.643, 0, 0] (due north)
  - Attitude [0, 0, 0]; rates [0, 0, 0]
  - Same notes as case 15
- **Spreadsheet cross-check.** XLSX W33 = 0, W34 = -179.95, W35 = 10000, W36 = 563.643, W37 = 0, W41 = 0, W195 = 180. All match.
- **Controller.** F16_gnc with selectCircumnavigator_disc = 0, AP and SAS = 1.0. Flies a 3-nm CCW circle about (0°, ±180°) (V2 p.67/PDF 71). Command values: NOT FOUND.
- **README description.** README.html:2039-2046 describes a different start (heading 45°, 360 s run).
- **Duration.** 180 s.
- **Sims.** 02, 04, 05 ("three", V2 p.324/PDF 328).
- **Criterion.** None stated.
  - Reported: SIM 4 lags SIM 5 by 16.8 ft; circle perimeters differ (V2 p.325/PDF 329).
  - Appendix E: 19.513%, the largest of all F-16 cases, driven by a 0.4-s difference in the time the track was intercepted (V2 p.590/PDF 594).
  - Unexplained: "An anomaly appears in rolling moment for case 16 results recorded by SIM 4" (V2 p.589/PDF 593).

### A.9 Agreement criterion (all cases)

**No pass/fail tolerance is defined for any F-16 case.**

- V1 p.10/PDF 14: the team chose not to require "all trajectories match within a predefined tolerance", and instead presented comparison plots.
- V1 p.21/PDF 25: F-16 cases "provide some remaining disagreements on precise numbers, but do indicate a family of solutions".
- V2 E.1.1, eq. 38, p.588/PDF 592 defines the only quantitative measure:
  - δu_pct = 100·max|u(t) - u_ref(t)| / max|u_ref|
  - u_ref is the ensemble average. For Euler angles and lat/lon, SIM 5 is used as the reference, with an angle-difference formula (V2 eq. 37, p.95/PDF 99).
  - Values under 0.001 are ignored.
- Exclusions for the F-16 cases (V2 pp.589-590/PDF 593-594):
  - SIM 2 is dropped entirely "due to large trim differences".
  - The first 8 s are ignored "due to initial transients".
  - SIM 2 moments are excluded because they were recorded at the MRC.
- Results are in V2 Table 79 (by case) and Table 80 (by signal), pp.593-594/PDF 597-598.

---

## B. F-16 model definition (DAVE-ML 2.0 files)

All five files use DOCTYPE `-//AIAA//DTD for Flight Dynamic Models - Functions 2.0//EN`, `http://www.daveml.org/DTDs/2p0/DAVEfunc.dtd`, with `xmlns="http://daveml.org/2010/DAVEML"`. MathML is `xmlns="http://www.w3.org/1998/Math/MathML"`.

**Features common to all five files:**
- **Absent everywhere:** `<ungriddedTableDef>`, `<uncertainty>`, `<isState>`, `<isStateDeriv>`, and any `interpolate=` attribute.
- **Present everywhere:** `minValue`/`maxValue` attributes on variableDefs.
- **Every `<independentVarRef>`** uses `extrapolate="neither"` plus explicit `min`/`max`.

### B.1 F16_aero.dml

- **Header.** "F-16 Subsonic Aerodynamics Model (a la Garza)", Mod P 2013-10-21 (F16_aero.dml:6-9); 16 modificationRecords A-P. Based on Garza & Morelli NASA TM-2003-212145 / Stevens & Lewis (F16_aero.dml:10-12).
- **Purpose.** Non-dimensional body-axis force and moment coefficients about the MRC at 35% MAC. Moment transfer to the CM is external (mod O, F16_aero.dml:170-175).
- **No Mach input**, so the model is subsonic-only.

**Inputs** (9):

| varID | name | units | notes |
|---|---|---|---|
| vt | trueAirspeed | ft_s | minValue = 0.1 |
| alpha | angleOfAttack | deg | |
| beta | angleOfSideslip | deg | sign "wind in right ear" |
| p | bodyAngularRate_Roll | rad_s | |
| q | bodyAngularRate_Pitch | rad_s | |
| r | bodyAngularRate_Yaw | rad_s | |
| el | elevatorDeflection | deg | trailing edge down |
| ail | aileronDeflection | deg | "left roll" / +LWD |
| rdr | rudderDeflection | deg | TEL |

Lines F16_aero.dml:292-345.

**Outputs** (9):

| varID | name | units | value / notes |
|---|---|---|---|
| cbar | referenceWingChord | ft | 11.32 |
| bspan | referenceWingSpan | ft | 30 |
| sref | referenceWingArea | ft2 | 300 |
| cx | aeroBodyForceCoefficient_X | nd | +FWD |
| cy | aeroBodyForceCoefficient_Y | nd | +RIGHT |
| cz | aeroBodyForceCoefficient_Z | nd | +DOWN |
| cl | aeroBodyMomentCoefficient_Roll | nd | RWD |
| cm | aeroBodyMomentCoefficient_Pitch | nd | ANU |
| cn | aeroBodyMomentCoefficient_Yaw | nd | ANR |

Lines F16_aero.dml:368-380, 784-905.

**Breakpoint sets** (4), F16_aero.dml:952-967:
- ALPHA1 (deg, 12 points): -10 -5 0 5 10 15 20 25 30 35 40 45
- BETA1 (deg, 7 points): 0 5 10 15 20 25 30
- BETA2 (deg, 7 points): -30 -20 -10 0 10 20 30
- DE1 (deg, 5 points): -24 -12 0 12 24

**Gridded tables** (18, all inline `<griddedTableDef>` inside `<functionDefn>`; 0 ungridded), F16_aero.dml:976-1560:

| Table | Breakpoints | Points |
|---|---|---|
| CX | DE1 × ALPHA1 | 60 |
| CZ0 | ALPHA1 | 12 |
| Cm0 | DE1 × ALPHA1 | 60 |
| Cl0 | BETA1(\|β\|) × ALPHA1 | 84 |
| Cn0 | BETA1(\|β\|) × ALPHA1 | 84 |
| CXq, CYr, CYp, CZq, Clr, Clp, Cmq, Cnr, Cnp | ALPHA1 | 12 each |
| dlda, dldr, dnda, dndr | BETA2 × ALPHA1 | 84 each |

- The 18 `<function>`s carry `<independentVarRef ... min max extrapolate="neither">`. Example: `el` min -24, max 24; `alpha` -10 to 45.
- Breakpoint order in `<breakpointRefs>`: the last breakpoint varies fastest. The prop file states this explicitly in a comment (F16_prop.dml:270).

**Calculations** (20), rendered to infix by `infix.py`:
- `rtd = 180/3.14159265` (truncated π, F16_aero.dml:355)
- `del = el/25`, `dail = ail/20`, `drdr = rdr/30`
- `cy0 = -0.02β + 0.021·dail + 0.086·drdr`
- `cz1 = czt·(1 - (β/rtd)²) - 0.19·del`. Encoded as plus + unary minus + power (F16_aero.dml:479-532).
- `tvt = 2vt`, `b2v = bspan/tvt`, `cq2v = cbar·q/tvt`
- `absbeta = |β|`
- `clt = piecewise(β<0 ? -absCl0 : absCl0)`; `cnt` likewise
- `cl1 = clt + dclda·dail + dcldr·drdr`; `cn1` likewise
- `cx = cxt + cq2v·cxq`
- `cy = cy0 + b2v(cyp·p + cyr·r)`
- `cz = cz1 + cq2v·czq`
- `cl = cl1 + b2v(clp·p + clr·r)`
- `cm = cmt + cq2v·cmq`
- `cn = cn1 + b2v(cnp·p + cnr·r)`

**MathML elements used** (counts): math 20, apply 53, ci 60, cn 14, plus 14, minus 3 (including 1 unary), times 23, divide 7, power 1 (F16_aero.dml:504), abs 1 (:590), piecewise 2, piece 2, lt 2, otherwise 2. No csymbol.

**Other DAVE-ML elements:**
- provenance 18, documentRef 54
- reference 5; modificationRecord 16
- isStdAIAA 18
- A large MATLAB listing of the original f16_aero.m is embedded in an XML comment (F16_aero.dml:190 onward)

**checkData.**
- 16 `<staticShot>`, F16_aero.dml:1563-4076: Nominal; ±sideslip; ±roll rate; ±pitch rate; ±yaw rate; ±elevator; ±aileron; ±rudder; Skewed inputs (F16_aero.dml:3919).
- Each shot has 9 checkOutputs with `<tol>0.000001</tol>` and a full `<internalValues>` block (all 50 variables).
- Independent re-implementation (`evalchk.py`: multilinear interpolation, clamping, min/max limits) passes all 16 shots. The worst error is 8.2e-6 of the tolerance, and internal values match to within 1e-9.

### B.2 F16_prop.dml

- **Header.** "F-16 propulsion model (a la Stevens & Lewis)", "Initial version", 2012-08-07 (F16_prop.dml:8-16).
- **Inputs.**
  - PWR, powerLeverAngle [pct], +INCR (F16_prop.dml:44)
  - ALT, altitudeMSL [ft] (:51)
  - RMACH, mach [nd] (:59)
- **Internal constants and table outputs.**
  - MIL_PWR = 50 [nd] (:72)
  - T_IDLE, T_MIL, T_MAX [lb] (:83-96)
- **Outputs.**
  - FEX, thrustBodyForce_X [lbf], calculated (:107)
  - FEY, FEZ [lbf] = 0 (:179, :188)
  - TEL, TEM, TEN [ftlbf] = 0 (:197, :206, :215)
- **Breakpoints** (F16_prop.dml:228-237):
  - ALT_PTS (ft): 0 10000 20000 30000 40000 50000
  - MACH_PTS (nd): 0 0.2 0.4 0.6 0.8 1.0
- **Gridded tables.** 3, each MACH_PTS × ALT_PTS, 36 points, defined standalone and referenced via `<griddedTableRef>`: T_IDLE_table :257, T_MIL_table :281, T_MAX_table :305.
  - Each carries `<provenance>`. Note the T_MAX table's description says "Idle thrust table", a copy-paste slip (:305-308).
- **Functions** T_IDLE_fn/T_MIL_fn/T_MAX_fn (:333-368): RMACH min 0 / max 1.0 and ALT min 0 / max 50000, all `extrapolate="neither"`.
- **Calculation.**
  `FEX = piecewise( PWR < MIL_PWR ? T_IDLE + PWR·(T_MIL - T_IDLE)/MIL_PWR : T_MIL + (PWR - MIL_PWR)·(T_MAX - T_MIL)/(100 - MIL_PWR) )` (F16_prop.dml:117-173)
- **MathML elements used.** math 1, apply 12, piecewise/piece/otherwise 1 each, lt 1, plus 2, minus 4, times 2, divide 2, ci 13, cn 1.
- **checkData.** 9 staticShots (F16_prop.dml:369-928):
  - 7 envelope corners at idle/mil/max
  - "middle of envelope, less than mil power" (:802): PLA 42.3, alt 23507, M 0.625, FEX 5319.3491 with tol 0.001
  - "middle ... greater than mil power" (:874): PLA 88.3, alt 33537, M 0.895, FEX 9298.8926 with tol 0.0006
  - All other outputs have tol 0.00001
  - internalValues are present in 3 shots (:730, :802, :874)
- **Independent evaluation.** Passes. Worst margin is 0.948 of tolerance, in shot 9: internal FEX 9298.892031 vs expected 9298.8926, tol 0.0006.

**Example check case**, verbatim excerpt from F16_prop.dml:370-426 (repeated output signals elided):

```xml
    <staticShot name="lower left corner of envelope, idle">
      <checkInputs>
	<signal>
	  <signalName>powerLeverAngle</signalName>
	  <signalUnits>pct</signalUnits>
	  <signalValue>0.0</signalValue>
	</signal>
	<signal>
	  <signalName>altitudeMSL</signalName>
	  <signalUnits>ft</signalUnits>
	  <signalValue>0.0</signalValue>
	</signal>
	<signal>
	  <signalName>mach</signalName>
	  <signalUnits>nd</signalUnits>
	  <signalValue>0.0</signalValue>
	</signal>
      </checkInputs>
      <checkOutputs>
	<signal>
	  <signalName>thrustBodyForce_X</signalName>
	  <signalUnits>lbf</signalUnits>
	  <signalValue>1060.0</signalValue>
	  <tol>0.00001</tol>
	</signal>
	...   (FEY, FEZ, TEL, TEM, TEN each 0.0 with <tol>0.00001</tol>)
      </checkOutputs>
    </staticShot>
```

- **Meaning of `<tol>`.** The package applies it as an absolute, strictly-less-than bound: `outcome(i) = (length(y_good) == sum(abs(y-y_good)<y_tol));` (F16_aero_verify.m:686; F16_prop_verify.m:291). The TM gives no definition: NOT FOUND in the TM.

### B.3 F16_inertia.dml

- **Header.** "F-16 inertia model (a la Stevens & Lewis)", 2012-08-07. "A simple constant mass matrix" (F16_inertia.dml:11-22).
- **Input.** CG_PCT_MAC, vrsPositionOfCM [pct], +AFT, initialValue 35.0 (:44). The tests use 25.0.
- **Constant.** CBAR 11.32 ft (:56).
- **Outputs.**

| varID | name | value |
|---|---|---|
| XIXX | bodyMomentOfInertia_Roll | 9496.0 slugft2 (:63) |
| XIYY | bodyMomentOfInertia_Pitch | 55814.0 (:71) |
| XIZZ | bodyMomentOfInertia_Yaw | 63100.0 (:79) |
| XIZX | bodyProductOfInertia_ZX | 982.0 (:87) |
| XIXY | | 0 (:95) |
| XIYZ | | 0 (:103) |
| XMASS | totalMass | 637.1595 slug, "(20,500 lbm)" (:111-113) |
| DYCG | | 0 ft, RT (:119) |
| DZCG | | 0 ft, DOWN (:128) |
| DXCG | bodyPositionOfCmWrtMrc_X | ft, +FWD, calculated (:141) |

- **Calculation.** `DXCG = 0.01·CBAR·(35 - CG_PCT_MAC)` (F16_inertia.dml:141-160). At 25% this is +1.132 ft (CM forward of the MRC).
- **MathML elements used.** math, apply 2, times 1, minus 1, ci 2, cn 2.
- **No tables, no checkData, no provenance.**

### B.4 F16_control.dml

Header: "F-16 simple control system", Revision F 2013-10-22 (F16_control.dml:6-8). See Section C for the law.

- 81 variableDefs; 22 isInput; 4 isOutput (el, ail, rdr, PWR); 37 calculations.
- No tables, no functions, no checkData.
- MathML elements used: math 37, apply 76, ci 102, cn 29, plus 14, minus 11 (unary minus in the LQR sums), times 24, piecewise 13, piece 13, otherwise 13, gt 9, lt 4, abs 1 (:438).
- Limits via `minValue`/`maxValue` on 11 variables:
  - pilot inputs, :100-122
  - deltaThetaCmd ±5, :285
  - deltaChiCmd ±30, :354
  - phiCmd ±30, :454
  - totLongStk, totLatStk, totPedal ±1, :1042-1078
  - totThrottle [0, 1], :1094

### B.5 F16_gnc.dml

Header: "Example F-16 guidance, navigation and control system", Revision C 2013-10-22, "a modified version of Rev E of the F16_control.dml file" (F16_gnc.dml:6-22).

- 94 variableDefs; 23 isInput; 4 isOutput; 48 calculations.
- No tables, no checkData.
- MathML elements used: all those in control, plus cos (:415), divide 2, power 1 (:436, square root via exponent 0.5), and one csymbol: `<csymbol definitionURL="http://daveml.org/function_spaces.html#atan2" encoding="text">atan2</csymbol>` (F16_gnc.dml:466).
- Limits are the same 11 as control (:77-99, :269, :577, :677, :1265-1318).

### B.6 DAVE-ML features beyond basic tables

| Feature | Where | Implementation note |
|---|---|---|
| `<independentVarRef min max extrapolate="neither">` | All 21 functions (aero 18, prop 3) | Clamp the inputs. NASA's Simulink equivalents use `ExtrapMethod 'clip'` / "None - Clip" (F16_aero_create.m:95-123; F16_prop_create.m:49-53). |
| `minValue` / `maxValue` on variableDef | aero vt (:292); control and gnc (listed above) | These are **saturations**, not documentation. DAVE2SL emits `built-in/Saturate` blocks, e.g. `autopilotCommandedBankAngle_unlim_limiter` -30/+30 (F16_control_create.m:35) and `trueAirspeed_unlim_limiter` 0.1/Inf. |
| `<calculation>` with MathML-2 content | All files | Operators are listed per file above. |
| `piecewise` / `piece` / `otherwise` | aero, prop, control, gnc | Includes a nested piecewise for ±360 wrapping (F16_control.dml:403-452). |
| `csymbol` atan2 | gnc :466 | Argument order is atan2(ownshipN_ft, ownshipE_ft). The inline comment says "atan2(E, N)", which is wrong. |
| `<provenance>`, `<documentRef>` | aero 18, prop 3 | Metadata only. |
| `<checkData>/<staticShot>/<internalValues>` | aero 16 shots, prop 9 shots | Use as unit tests. |
| Interpolation type | No `interpolate=` attribute anywhere | Linear per the DAVE2SL output ('Linear', F16_prop_create.m:49). The TM describes "linear function interpolations" (V2 p.53/PDF 57). |
| `<uncertainty>`, `<isState>`, `<isStateDeriv>`, `<ungriddedTableDef>` | Absent | |

---

## C. Control (F16_control.dml) and GNC (F16_gnc.dml) laws

### C.1 Inputs and outputs

**Control inputs** (F16_control.dml:100-231):

| varID | name | units | range / sign / default |
|---|---|---|---|
| throttle | pilotControl_throttle | frac | 0-1 |
| longStk | pilotControl_long | frac | ±1, +AFT |
| latStk | pilotControl_lat | frac | ±1, +RWD |
| pedal | pilotControl_yaw | frac | ±1, +ANR |
| sasOn | stabilityAugmentationOn_disc | nd | |
| apOn | autopilotOn_disc | nd | |
| keasCmd | equivalentAirspeedCommand | nmi_h | |
| altCmd | altitudeMslCommand | ft | |
| latOffset | lateralDeviationError | ft | +RT |
| baseChiCmd | trueBaseCourseCommand | deg | sign attribute "+CCFN", but description says "+clockwise from north" (:157-158) |
| altMsl | altitudeMsl | ft | |
| Vequiv | equivalentAirspeed | nmi_h | |
| alpha | | deg | |
| beta | | deg | +RT |
| phi | | deg | |
| theta | | deg | |
| psi | | deg | |
| pb, qb, rb | | rad_s | |
| throttleTrim | trimmedPilotControl_throttle | frac | init 0.1390191130965607 |
| longStkTrim | trimmedPilotControl_long | frac | init 0.1296382327486013 |

**GNC inputs** (F16_gnc.dml:77-215): the same, except baseChiCmd and latOffset are internal, and three are added:
- circlePoleSW = selectCircumnavigator_disc (:117)
- ownshipN_deg = geLatitude (:124)
- ownshipE_deg = geLongitude (:129)

**Outputs (both files):**
- `el` = elevatorDeflection [deg, TED]
- `ail` = aileronDeflection [deg, "left roll"]
- `rdr` = rudderDeflection [deg, TEL]
- `PWR` = powerLeverAngle [pct]

Lines: F16_control.dml:1117-1171; F16_gnc.dml:1340-1394. The TM versions are V2 Tables 8-11, pp.17, 20, 27, 30 (PDF 21, 24, 31, 34).

### C.2 Law (F16_control.dml; GNC identical downstream)

Line numbers are for F16_control.dml. GNC is offset by +223 after the navigator block.

**Autopilot outer loops**
- `fsasOn = sasOn + apOn` (:242). SAS counts as on if fsasOn > 0.5. Mod F calls this an "OR function".
- Altitude:
  - `altErr = altMsl - altCmd`
  - `deltaThetaCmd = altErr·(-0.05 deg/ft)`, clamped to ±5 deg
  - `thetaCmd = deltaThetaCmd + trimmedTheta` (:260-301)
- Lateral / course:
  - `chiEst = beta + psi` (a "quick-and-dirty" track estimate, :319-333)
  - `deltaChiCmd = -0.01 deg/ft · latOffset`, clamped to ±30
  - `chiCmd = deltaChiCmd + baseChiCmd`
  - `chiErrUnwrapped = chiEst - chiCmd`
  - `chiErr` = wrap to ±180 (if |x| > 180 then x ∓ 360)
  - `phiCmd = -10 deg/deg · chiErr`, clamped to ±30 (:335-470)

**Reference selection**
- If apOn > 0.5, use (keasCmd, thetaCmd, phiCmd).
- Otherwise use (trimmedKEAS, trimmedTheta, 0) (:488-570).
- Design constants (:471-486):
  - trimmedAlpha = trimmedTheta = 2.653813535191715 deg
  - trimmedKEAS = 287.8088596053291 kt. The units attribute has the typo "nim_h" (:481).

**LQR** (gains at :574-651). These are pure static full-state feedback:

| Gain | Values |
|---|---|
| Longitudinal row 1 (longLQR11..14) | -0.063009074230494 [h/nmi], 0.113230403179271 [/deg], 10.113432224566077 [s/rad], 3.154983341632913 [/deg] |
| Longitudinal row 2 (longLQR21..24) | 0.997260602961658, -0.025467711176391, 1.213308488207827, 0.208744369535208 |
| Lateral-directional row 1 (latdLQR11..14) | 3.078043941515770 [/deg], 0.032365863044163 [/deg], 4.557858908828332 [s/rad], 0.589443156647647 [s/rad] |
| Lateral-directional row 2 (latdLQR21..24) | -0.705817452754520, -0.256362860634868, -1.073666149713151, 0.822114635953878 |

Error signals (:660-712):
- `dV = Vequiv - keasCmdSw`
- `dα = alpha - trimmedAlpha`
- `dφ = phi - phiCmdSw`
- `dθ = theta - thetaCmdSw`

Commands (:714-852):
- `longLQR = -(K11·dV + K12·dα + K13·qb + K14·dθ)`
- `throttleLQR = -(K21·dV + ... + K24·dθ)`
- `latLQR = -(L11·dφ + L12·beta + L13·pb + L14·rb)`
- `dirLQR = -(L21·dφ + ... + L24·rb)`

**Engage logic** (:854-1040)
- LQR terms pass through when fsasOn > 0.5, otherwise 0.
- Pilot inputs pass through when apOn < 0.5, otherwise 0.

**Mixer and limits** (:1042-1115)
- `totLongStk = longStkTrim + longStkSw + longLQRsw`, clamped to ±1
- `totLatStk = latStkSw + latLQRsw`, clamped to ±1
- `totPedal = pedalSw + dirLQRsw`, clamped to ±1
- `totThrottle = throttleTrim + throttleSw + throttleLQRsw`, clamped to [0, 1]

**Scaling** (:1117-1185)
- `el = -25·totLongStk`
- `ail = -21.5·totLatStk`
- `rdr = -30·totPedal + 0.008·ail` (aileron-rudder interconnect)
- `PWR = 100·totThrottle`

**Consistency check** (computed): el = -25 × 0.12964 = -3.241° and PWR = 13.9019%, matching the README trim table (README.html:1879-1891).

### C.3 GNC circumnavigator (F16_gnc.dml:300-540)

- Constants:
  - `deg_to_ft = 60·6076.12` (spherical, 1 nm per arc-minute)
  - `circleRadius_ft = 3·6076.12`
- Polar mode:
  - `latOffsetPolar = deg_to_ft·(90 - lat) - circleRadius_ft`
  - `baseChiCmdPolar = 90` (constant)
- Equator/IDL mode:
  - `degEFromTgt = lon > 0 ? lon - 180 : lon + 180`
  - `ownshipN_ft = lat·deg_to_ft`
  - `ownshipE_ft = degEFromTgt·deg_to_ft·cos(lat·3.14159265/180)`
  - `ftFromTgt = (E² + N²)^0.5`
  - `baseChiCmdEquatorIDL = atan2(N_ft, E_ft)·(-180)/3.14159265`. This variable also has initialValue 90.0 alongside its calculation (:456).
  - `latOffsetEquatorIDL = ftFromTgt - circleRadius_ft`
- Mode switch: `latOffset` and `baseChiCmd` choose polar if circlePoleSW > 0.5, otherwise Equator/IDL (:494-540). They then feed the same lateral autopilot.
- TM prose (V2 p.26/PDF 30) calls the distance "the sum of the squares". The DML takes the square root. The DML is normative (V2 p.26/PDF 30).

### C.4 Dynamic states, sample rate, and what the TM says

- **No dynamic states.** Neither file has `<isState>`/`<isStateDeriv>`, integrators, filters or delays.
  - README.html:1910-1912: "perfect state feedback is assumed ... and the control system has no integrated states". Consequences include saturation-prone responses and "Type 0 response" steady offsets (README.html:1916-1927).
  - "No actuator dynamics were modeled" (V2 p.16/PDF 20).
- **Sample rate.** NOT FOUND in the DML, README or TM. The TM cites a possible "different execution rate for the control law" as a difference source (V2 p.282/PDF 286; p.296/PDF 300). The discrete command steps at t = 5, 15 and 20 s produced timing mismatches between tools (V2 p.589/PDF 593; p.590/PDF 594).
- **Gains are point designs.** LQR gains are for 10,000 ft / 287 KEAS (Mach 0.5). Operation elsewhere "was sub-optimal or even unstable" (V2 p.16/PDF 20; p.21/PDF 25; README.html:1353-1355).
- **Trim procedure.** Trim with SAS and AP off, adjusting the trimmed* inputs (V2 p.16/PDF 20).
- **LQR reference states.** The tools differed in whether they replaced the internal LQR reference states (trimmedAlpha, trimmedTheta, trimmedKEAS) with the tool's own trim. Only SIM 5 did so (V2 p.256/PDF 260).
  - The resulting difference between 287.8 and 287.98 KEAS caused a -0.11 ft/s speed bias in SIM 4 (V2 p.256/PDF 260).
  - The TM does not say which choice is correct. It is a documented source of spread.
- **Normative source.** The S-119 files are normative over the block diagrams (V2 p.16/PDF 20; p.26/PDF 30).

---

## D. Mass, inertia, geometry and engine

| Quantity | TM value (V2 Table 7, p.15/PDF 19) | DML value | Notes |
|---|---|---|---|
| S | 300.0 ft² | sref 300 (F16_aero.dml:380) | |
| b | 30.0 ft | bspan 30 (:374) | |
| c̄ | 11.32 ft | cbar 11.32 (aero :368; inertia :56) | |
| Ixx | 9,496.0 slug-ft² | 9496.0 (F16_inertia.dml:63) | |
| Iyy | 55,814.0 | 55814.0 (:71) | |
| Izz | 63,100.0 | 63100.0 (:79) | |
| Ixz (Izx) | 982.0 | XIZX 982.0 (:87), "no sign reversal" (README.html:1306) | |
| Ixy, Iyz | 0 | 0 (:95, :103) | |
| m | **637.26 slug** | **637.1595 slug**, "(20,500 lbm)" (F16_inertia.dml:111-113) | **Discrepancy.** 20,500/32.174 = 637.16. The TM also says "the 20,500 lb F-16" (V2 p.229/PDF 233). |
| x̄ (CM) | 25% MAC | Input CG_PCT_MAC, default 35 (:44); MRC at 35% MAC | Use 25 (README.html:1234; V2 p.604/PDF 608). DXCG = +1.132 ft forward of the MRC. |
| ȳ, z̄ | 0, 0 | DYCG = DZCG = 0 | |
| Engine angular momentum | NOT FOUND | Not present in any DML | See Section F. |

**Engine model** (F16_prop.dml):
- Thrust = f(Mach, alt, PLA) using the three 6×6 tables (idle / mil / max) with the piecewise PLA blend (Section B.2).
- PLA 0-100; 50 = MIL; 100 = MAX/afterburner (README.html:1130-1131, 1155).
- Throttle mapping: `PWR = 100·totThrottle`, with totThrottle clamped to [0, 1] in the control law (F16_control.dml:1094-1185).
- **No power lag.** Outputs are "Steady-state thrust" (README.html:1195). The file has no spool or engine state.
- Thrust acts along body +X only. FEY, FEZ and all thrust moments are 0 (F16_prop.dml:179-222; README.html:1198-1225).
- The thrust line location is NOT FOUND. Because the thrust is purely X-axis and DZCG = DYCG = 0, placing it through the MRC gives no transfer moment.
- The table envelope is Mach 0-1 and alt 0-50,000 ft with clamping. **Case 12 at Mach ≈ 2.01 therefore evaluates thrust at the Mach 1.0 row.** The TM does not comment on this: NOT FOUND.

---

## E. README.html and the NASA verify scripts

**README.html (version 6, 2013-10-22; README.html:734-738)**

- **Goal and envelope.** "Flight envelope is limited to the vicinity of 10,000 ft MSL and 287.8 knots equivalent airspeed (around Mach 0.5)" (:910-911).
- **File versions listed** (:927-948). These are older than the shipped files:
  - aero "mod O, 2013-09-11" (shipped: Mod P)
  - control "rev E, 2013-09-12" (shipped: Rev F)
  - gnc "rev B" (shipped: Rev C)
- **Model use.** Use either F16_control or F16_gnc; always include aero, prop and inertia (:952-954).
- **Self-verification.** "S-119 models may also contain their own self-verification check-cases ... At present, the aero (F16_aero.dml) and propulsion (F16_prop.dml) models contain verification checkcase definitions and data" (:1811-1813). DAVE-ML parsers are listed at daveml.org (:1805-1810).
- **CM.** Set the CM input to 25% (:1234-1235, :1259-1260, change log v5 :2123).
- **Moment transfer.** Aero plus propulsion forces and moments must be transferred from the MRC (35% MAC) to the CM for proper trim (:1829-1832).
- **Trim recipe.** Wings-level, un-accelerated flight using elevator, throttle and pitch attitude (:1833-1835). Reference trim table at :1854-1891.
- **Caution on the README results.** They come from a Simulink model with an oblate rotating Earth but **constant 32.174 ft/s² gravity** and a **tabular US 1976 atmosphere** (:1821-1823). They are not the NESC J2 setup and should not be used as reference data.
- **How to run.** No run instructions beyond the above: NOT FOUND.

**F16_aero_verify.m / F16_prop_verify.m** (generated "02-MAR-04 by DAVE2SL")

- Both run `sim('F16_aero'|'F16_prop',[0 0],options,UT)` with a FixedStepDiscrete, 1-s step (F16_aero_verify.m:13, 685; F16_prop_verify.m:13).
- Each case passes if every output satisfies `abs(y - y_good) < y_tol` (F16_aero_verify.m:686; F16_prop_verify.m:291). The script prints "All cases passed: model ... verified" (F16_aero_verify.m:695-697).
- **Aero:** 16 cases, all tolerances 1.0E-6 (e.g. F16_aero_verify.m:47-57), num_cases = 16 (:675).
- **Prop:** 9 cases, tolerances 1.0E-5 except FEX 1.0E-3 (case 8) and 6.0E-4 (case 9) (F16_prop_verify.m:38-45 and onward).
- **Comparison with the DML** (`cmpchk.py`): all inputs, expected outputs and tolerances are **identical** to the DML `<checkData>`. Zero differences.
- **No verify scripts** exist for inertia, control or gnc.

---

## F. Engine gyroscopics and constant mass

- **Gyroscopic effects: not included.**
  - F16_prop.dml defines no engine angular momentum variable.
  - Thrust moments TEL/TEM/TEN are the constant 0 (F16_prop.dml:197-222).
  - No DML input or output carries rotor momentum.
  - V2 contains no mention of gyroscopic or engine angular momentum (search: NOT FOUND).
  - Caution, background knowledge **not** from these sources: the Stevens & Lewis F-16 original carries an engine angular momentum term (about 160 slug-ft²/s) and a first-order power lag. The NESC DML omits both, so do not add them.
- **Mass is constant.**
  - "the mass properties were fixed constants given in Table 7" (V2 p.14/PDF 18).
  - "A simple constant mass matrix" (F16_inertia.dml:21).
  - "simple constant-mass condition" (README.html:1233).
  - There is no fuel-burn input.

---

## JSON summary

```json
{
  "common": {
    "earth": "WGS-84 ellipsoid, rotating; re=6378137.0 m (20925646.32546 ft), 1/f=298.257223563, omegaE=7.292115e-5 rad/s (V2 Table 73 p.93/PDF97). XLSX uses Re=20925646.99508 ft, omega=7.292113023867704e-5 rad/s, mu=1.407644311e16 ft3/s2 (Atmos!D5:D9)",
    "gravity": "J2: mu=3.986004418e14 m3/s2 (1.407644175720511e16 ft3/s2), J2=0.00108262982, eqs 29-31 V2 p.47/PDF51",
    "atmosphere": "US Standard 1976 (V2 B.5.1 p.48/PDF52)",
    "wind": "none (still air)",
    "cm": "25% MAC (V2 p.604/PDF608; README.html:1234); MRC 35% MAC",
    "record_dt_s": 0.1,
    "csv_header_sim_02": "time,feVelocity_ft_s_X,feVelocity_ft_s_Y,feVelocity_ft_s_Z,altitudeMsl_ft,longitude_deg,latitude_deg,localGravity_ft_s2,eulerAngle_deg_Yaw,eulerAngle_deg_Pitch,eulerAngle_deg_Roll,bodyAngularRateWrtEi_deg_s_Roll,bodyAngularRateWrtEi_deg_s_Pitch,bodyAngularRateWrtEi_deg_s_Yaw,altitudeRateWrtMsl_ft_min,speedOfSound_ft_s,airDensity_slug_ft3,ambientPressure_lbf_ft2,ambientTemperature_dgR,aero_bodyForce_lbf_X,aero_bodyForce_lbf_Y,aero_bodyForce_lbf_Z,aero_bodyMoment_ftlbf_L,aero_bodyMoment_ftlbf_M,aero_bodyMoment_ftlbf_N,mach,trueAirspeed_nmi_h",
    "csv_header_sim_04": "time,eiPosition_ft_X,eiPosition_ft_Y,eiPosition_ft_Z,eiVelocity_ft_s_X,eiVelocity_ft_s_Y,eiVelocity_ft_s_Z,feVelocity_ft_s_X,feVelocity_ft_s_Y,feVelocity_ft_s_Z,altitudeMsl_ft,longitude_deg,latitude_deg,localGravity_ft_s2,eulerAngle_deg_Yaw,eulerAngle_deg_Pitch,eulerAngle_deg_Roll,bodyAngularRateWrtEi_deg_s_Roll,bodyAngularRateWrtEi_deg_s_Pitch,bodyAngularRateWrtEi_deg_s_Yaw,speedOfSound_ft_s,airDensity_slug_ft3,ambientPressure_lbf_ft2,ambientTemperature_dgR,aero_bodyForce_lbf_X,aero_bodyForce_lbf_Y,aero_bodyForce_lbf_Z,aero_bodyMoment_ftlbf_L,aero_bodyMoment_ftlbf_M,aero_bodyMoment_ftlbf_N,mach,dynamicPressure_lbf_ft2",
    "csv_header_sim_05": "time,eiPosition_ft_X,eiPosition_ft_Y,eiPosition_ft_Z,gePosition_ft_X,gePosition_ft_Y,gePosition_ft_Z,eiVelocity_ft_s_X,eiVelocity_ft_s_Y,eiVelocity_ft_s_Z,feVelocity_ft_s_X,feVelocity_ft_s_Y,feVelocity_ft_s_Z,altitudeMsl_ft,longitude_deg,latitude_deg,localGravity_ft_s2,eulerAngle_deg_Yaw,eulerAngle_deg_Pitch,eulerAngle_deg_Roll,bodyAngularRateWrtEi_deg_s_Roll,bodyAngularRateWrtEi_deg_s_Pitch,bodyAngularRateWrtEi_deg_s_Yaw,altitudeRateWrtMsl_ft_min,speedOfSound_ft_s,airDensity_slug_ft3,ambientPressure_lbf_ft2,ambientTemperature_dgR,aero_bodyForce_lbf_X,aero_bodyForce_lbf_Y,aero_bodyForce_lbf_Z,aero_bodyMoment_ftlbf_L,aero_bodyMoment_ftlbf_M,aero_bodyMoment_ftlbf_N,mach,dynamicPressure_lbf_ft2,trueAirspeed_nmi_h,feVelocity_ft_s_Z",
    "criterion_global": "none (V1 p.10/PDF14); Appendix E eq.38 max % diff vs ensemble avg, first 8 s ignored, SIM 2 excluded (V2 pp.588-590/PDF592-594)"
  },
  "cases": [
    {"id": "11", "title": "Subsonic F-16 trimmed flight across planet / Check-case 11 – steady flight of a subsonic aircraft / 11: Subsonic winged flight (trimmed straight & level)",
     "earth": "WGS-84 rotating", "gravity": "J2", "atmosphere": "US 1976", "wind": "none",
     "ic": {"lat_deg": 36.01916667, "lon_deg": -75.67444444, "alt_ft_msl": 10013, "v_ned_ft_s": [400, 400, 0], "tas_ft_s": 565.685, "ktas": 335.15, "mach_approx": 0.525, "keas_approx": 287.98, "euler_deg_rpy": [0, 0, 45], "body_rate_deg_s": [0, 0, 0], "trim": "straight & level; vary pitch, elevator, throttle; SAS/AP off during trim", "xlsx_col": "O"},
     "controller": "none (unaugmented, SAS off, no pilot inputs)", "duration_s": 180,
     "csv_columns": "see common.csv_header_sim_0X (identical)", "csv_files": ["Atmos_11_sim_02.csv (to 200 s)", "Atmos_11_sim_04.csv", "Atmos_11_sim_05.csv"],
     "sims": ["SIM 2", "SIM 4", "SIM 5"], "criterion": "none stated; Table 79 worst 2.786 %",
     "pages": "V2 p.62/PDF66 (C.1.11, Table 35); V2 pp.228-229/PDF232-233 (D.1.11); V2 Table 79 p.593/PDF597; V1 Table 6.3-1 p.16/PDF20"},
    {"id": "12", "title": "Supersonic F-16 trimmed flight across planet / Check-case 12 – steady flight of a supersonic aircraft",
     "earth": "WGS-84 rotating", "gravity": "J2", "atmosphere": "US 1976", "wind": "none",
     "ic": {"lat_deg": 36.01916667, "lon_deg": -75.67444444, "alt_ft_msl": 30013, "v_ned_ft_s": [1414.213562, 1414.213562, 0], "tas_ft_s": 2000, "mach_approx": 2.01, "keas": "NOT FOUND", "euler_deg_rpy": [0, 0, 45], "body_rate_deg_s": [0, 0, 0], "trim": "straight & level; vary pitch, elevator, throttle", "xlsx_col": "P"},
     "controller": "none (unaugmented, SAS off)", "duration_s": 180,
     "csv_columns": "see common", "csv_files": ["Atmos_12_sim_02.csv (to 200 s)", "Atmos_12_sim_04.csv", "Atmos_12_sim_05.csv"],
     "sims": ["SIM 2", "SIM 4", "SIM 5"], "criterion": "none stated; Table 79 worst 0.631 % (vertical velocity excluded)",
     "pages": "V2 p.63/PDF67 (C.1.12, Table 36); V2 p.242/PDF246 (D.1.12)"},
    {"id": "13.1", "title": "Check-case 13.1 – altitude change of a subsonic aircraft",
     "earth": "WGS-84 rotating", "gravity": "J2", "atmosphere": "US 1976", "wind": "none",
     "ic": "same as case 11 (XLSX col Q)",
     "controller": "F16_control.dml, apOn=1, sasOn=1; t=5 s altitudeMslCommand +100 ft; trueBaseCourseCommand 45 deg, lateralDeviationError 0; KEAS cmd ~287.98 (implied)", "duration_s": 20,
     "csv_columns": "see common", "csv_files": ["Atmos_13p1_sim_02.csv", "Atmos_13p1_sim_04.csv", "Atmos_13p1_sim_05.csv (to 60 s)"],
     "sims": ["SIM 2", "SIM 4", "SIM 5"], "criterion": "none stated; Table 79 worst 1.080 %",
     "pages": "V2 pp.63-64/PDF67-68 (C.1.13, Table 37); V2 pp.255-256/PDF259-260 (D.1.13)"},
    {"id": "13.2", "title": "Check-case 13.2 – velocity change of a subsonic aircraft",
     "earth": "WGS-84 rotating", "gravity": "J2", "atmosphere": "US 1976", "wind": "none",
     "ic": "same as case 11 (XLSX col R)",
     "controller": "F16_control.dml AP+SAS; t=5 s equivalentAirspeedCommand -5 kt (to 282.98 KEAS); SIM 2 used -10 kt (README also says 10 kt)", "duration_s": 20,
     "csv_columns": "see common", "csv_files": ["Atmos_13p2_sim_02.csv", "Atmos_13p2_sim_04.csv", "Atmos_13p2_sim_05.csv (to 60 s)"],
     "sims": ["SIM 2", "SIM 4", "SIM 5"], "criterion": "none stated; Table 79 worst 0.218 %",
     "pages": "V2 p.64/PDF68 (C.1.14, Table 38); V2 p.269/PDF273 (D.1.14); README.html:1967-1970"},
    {"id": "13.3", "title": "Check-case 13.3 – course change of a subsonic aircraft",
     "earth": "WGS-84 rotating", "gravity": "J2", "atmosphere": "US 1976", "wind": "none",
     "ic": "same as case 11 (XLSX col S)",
     "controller": "F16_control.dml AP+SAS; t=15 s trueBaseCourseCommand +15 deg (45->60), lateralDeviationError=0", "duration_s": 30,
     "csv_columns": "see common", "csv_files": ["Atmos_13p3_sim_02.csv", "Atmos_13p3_sim_04.csv", "Atmos_13p3_sim_05.csv (to 239.9 s)"],
     "sims": ["SIM 2", "SIM 4", "SIM 5"], "criterion": "none stated; Table 79 worst 14.947 %",
     "pages": "V2 pp.64-65/PDF68-69 (C.1.15, Table 39); V2 p.282/PDF286 (D.1.15)"},
    {"id": "13.4", "title": "Check-case 13.4 – lateral offset maneuver of a subsonic aircraft",
     "earth": "WGS-84 rotating", "gravity": "J2", "atmosphere": "US 1976", "wind": "none",
     "ic": "same as case 11 (XLSX col T)",
     "controller": "F16_control.dml AP+SAS; t=20 s 2,000-ft lateral course offset to the right via lateralDeviationError (+right), recomputed each step by user logic (initial -2000 ft); base course 45 deg", "duration_s": 60,
     "csv_columns": "see common", "csv_files": ["Atmos_13p4_sim_02.csv", "Atmos_13p4_sim_04.csv", "Atmos_13p4_sim_05.csv (to 239.9 s)"],
     "sims": ["SIM 2", "SIM 4", "SIM 5"], "criterion": "none stated; Table 79 worst 16.312 %",
     "pages": "V2 p.65/PDF69 (C.1.16, Table 40); V2 pp.295-296/PDF299-300 (D.1.16)"},
    {"id": "15", "title": "Circular F-16 flight around North pole / Check-case 15 – circumnavigation of the North pole",
     "earth": "WGS-84 rotating", "gravity": "J2", "atmosphere": "US 1976", "wind": "none",
     "ic": {"lat_deg": 89.95, "lon_deg": -45, "alt_ft_msl": 10000, "v_ned_ft_s": [0, 563.643, 0], "ktas_approx": 333.95, "mach_approx": 0.523, "keas_approx_computed": 287.0, "euler_deg_rpy": [0, 0, 90], "body_rate_deg_s": [0, 0, 0], "trim": "trimmed straight and level", "xlsx_col": "V"},
     "controller": "F16_gnc.dml, selectCircumnavigator_disc=1, apOn=sasOn=1 from first time step; 3-nm CCW circle around N pole; geLatitude/geLongitude fed back; alt/KEAS command values NOT FOUND", "duration_s": 180,
     "csv_columns": "see common", "csv_files": ["Atmos_15_sim_02.csv", "Atmos_15_sim_04.csv", "Atmos_15_sim_05.csv"],
     "sims": ["SIM 2", "SIM 4", "SIM 5"], "criterion": "none stated; Table 79 worst 11.845 %",
     "pages": "V2 pp.66-67/PDF70-71 (C.1.18, Table 42); V2 pp.309-311/PDF313-315 (D.1.17); V2 p.26/PDF30"},
    {"id": "16", "title": "Circular F-16 flight around Equator/dateline intersection / Check-case 16 – circular flight around the Equator-IDL intersection",
     "earth": "WGS-84 rotating", "gravity": "J2", "atmosphere": "US 1976", "wind": "none",
     "ic": {"lat_deg": 0, "lon_deg": -179.95, "alt_ft_msl": 10000, "v_ned_ft_s": [563.643, 0, 0], "ktas_approx": 333.95, "mach_approx": 0.523, "euler_deg_rpy": [0, 0, 0], "body_rate_deg_s": [0, 0, 0], "trim": "trimmed straight and level", "xlsx_col": "W"},
     "controller": "F16_gnc.dml, selectCircumnavigator_disc=0, apOn=sasOn=1 from first step; 3-nm CCW circle around (0, +/-180); alt/KEAS command values NOT FOUND", "duration_s": 180,
     "csv_columns": "see common", "csv_files": ["Atmos_16_sim_02.csv", "Atmos_16_sim_04.csv", "Atmos_16_sim_05.csv"],
     "sims": ["SIM 2", "SIM 4", "SIM 5"], "criterion": "none stated; Table 79 worst 19.513 %",
     "pages": "V2 p.67/PDF71 (C.1.19, Table 43); V2 pp.324-325/PDF328-329 (D.1.18); V2 p.590/PDF594"}
  ]
}
```

---

## Open questions and implementation risks

### Open questions

1. **Autopilot baseline commands.**
   - Cases 13.x: the explicit altitudeMslCommand, equivalentAirspeedCommand and trueBaseCourseCommand values are not tabulated. Implied: 10013 ft, 287.98 KEAS, 45°.
   - Cases 15 and 16: NOT FOUND. Also NOT FOUND: whether the tools replaced trimmedAlpha, trimmedTheta and trimmedKEAS (only SIM 5 did).
   - Decide per framework and document the choice, since it causes known ~0.1 ft/s speed biases (V2 p.256/PDF 260).
2. **KEAS formula** (reference density, compressibility): NOT FOUND in any source. The DML inputs are in "nmi_h".
3. **Case 13.4 lateral-offset formula**: NOT FOUND. The TM says it is user-supplied (V2 p.65/PDF 69).
4. **Control law execution rate and ordering** relative to integration: NOT FOUND.
5. **Mass**: 637.26 slug (TM Table 7) vs 637.1595 slug (DML). Which one the sims used is NOT FOUND. The DML value is consistent with 20,500 lbm.
6. **Initial body rates.**
   - The tables give [0,0,0] "relative to the inertial frame" (V2 p.56/PDF 60), which contradicts the trim discussion.
   - XLSX Atmos!O23:O25 inertial rates [0.0029543, -0.0029543, 0] deg/s equal ωE·cos45° with no latitude dependence. At 36° latitude the expected Earth-rate projection is ≈ [0.00239, -0.00239, -0.00246] deg/s (computed). This looks like a spreadsheet error.
   - The CSV t=0 rates differ per sim (SIM 2 zero; SIM 4/5 include transport rate).
   - Recommend trimming and comparing after t = 8 s, as Appendix E does.
7. **Earth constants.**
   - XLSX Re = 20925646.99508 ft vs 6378137/0.3048 = 20925646.32546 ft (0.67 ft different).
   - μ = 1.407644311e16 vs 1.4076441757e16.
   - ω = 7.2921130e-5 vs 7.292115e-5.
   - Table 73 is designated for replication (V2 p.92/PDF 96).

### Implementation risks

8. **`minValue`/`maxValue` are saturations.**
   - Includes the ±30° bank limit, the ±5° pitch-delta limit, ±1 stick totals, the [0,1] throttle limit, and vt ≥ 0.1 ft/s in aero.
   - A naive DAVE-ML parser that ignores them will fail 13.3, 13.4, 15 and 16 (CSV φ sits at 30.00°).
   - NASA's DAVE2SL implements them as Saturate blocks (F16_control_create.m:35 etc.).
9. **`extrapolate="neither"` means clamp.**
   - Case 12 (Mach 2.01) evaluates the subsonic aero model, which has no Mach input.
   - Thrust tables are clamped at Mach 1.0.
   - Both are intentional per the files but undocumented in the TM.
10. **MathML subtleties.**
    - Unary `<minus/>` (aero cz1; LQR sums).
    - `<power/>` with exponent 0.5 used as square root.
    - Nested `piecewise` for angle wrapping.
    - `csymbol` atan2 via `definitionURL` with argument order (y=N, x=E). The adjacent XML comment wrongly says atan2(E,N).
    - Truncated π = 3.14159265 in aero `rtd` and in the GNC.
    - Implement `piecewise` as first-true-piece, else `otherwise`.
11. **Comparisons are "> 0.5"** on floating discretes. `fsasOn = sasOn + apOn` is a sum, not a logical OR.
12. **Sign-attribute typos.**
    - `baseChiCmd` sign="+CCFN" while the description says clockwise (F16_control.dml:157).
    - `trimmedKEAS` units="nim_h" (:481).
    - The prop README table lists thrustBodyMoment_Roll twice and Pitch as "+RWD" (README.html:1210-1225).
    - `baseChiCmdEquatorIDL` has both initialValue and a calculation (F16_gnc.dml:456).
    - A strict units/sign validator may reject these.
13. **Moment reference.** Aero and propulsion moments are about the MRC (35% MAC) and must be transferred to the CM (25% MAC, DXCG = +1.132 ft). The CSV `aero_bodyMoment` is about the CM for SIM 4/5 but about the MRC for SIM 2 (V2 p.229/PDF 233). Compare moments only against SIM 4/5.
14. **SIM 2 is a known outlier.**
    - It used geocentric "down" for gravity, giving roll ≈ -0.17° at trim (V2 p.228/PDF 232).
    - It used the wrong speed step in 13.2 (V2 p.269/PDF 273).
    - Appendix E excludes it entirely (V2 p.589/PDF 593). Use SIM 4/5 as the reference pair.
15. **CSV quirks.**
    - sim_05 has a duplicate `feVelocity_ft_s_Z` column. A MATLAB `readtable` will rename it (`feVelocity_ft_s_Z_1`).
    - sim_05 13.x files extend past the specified duration (60 and 239.9 s), with float32 time stamps (239.89999389648438).
    - sim_02 cases 11 and 12 run to 200 s.
    - Column sets differ by sim: sim_02 has no ECI/ECEF position; sim_04 has no trueAirspeed or altitudeRate.
    - Truncate to the spec durations and align by time with tolerance.
16. **Discrete command timing.** Step times at 5, 15 and 20 s cause the largest percentage mismatches (V2 p.590/PDF 594). Apply steps at an exactly defined frame (t ≥ t_step) and document it.
17. **README reference results are not the NESC environment** (constant 32.174 ft/s² gravity, tabular atmosphere; README.html:1821-1823). The README maneuvers also differ from the TM: a 10-kt step, a left offset with a 90° base course, and different circumnavigation start points and durations. Treat the TM plus the CSVs as authoritative.
18. **Table orientation.** Gridded tables are row-major with the **last** breakpoint varying fastest (F16_prop.dml:270 comment). For example, CX_table is DE1 (5) × ALPHA1 (12). A MATLAB `reshape` must be `reshape(data, [12 5])'` or equivalent. A wrong orientation still "works" but fails the checkData; the implementation passed only with the correct order (`evalchk.py`).
