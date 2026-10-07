# VITAL conventions

This is the single most important document in VITAL. Every function header refers to it. A convention changes only through an ADR in `DECISIONS.md` and a matching change to the unit tests that encode it.

## 1. Units
- **Internal units are SI only:** m, kg, s, N, N·m, rad, K, Pa.
- Degrees, feet, knots, slugs and lbf appear **only** at import/export boundaries and in reports.
- Conversion factors are exact, defined once in `vital.units`:

| Quantity | Factor | Status |
|---|---|---|
| ft → m | 0.3048 | exact (international foot) |
| lbm → kg | 0.45359237 | exact |
| g0 | 9.80665 m/s² | exact, standard gravity |
| lbf → N | 0.45359237 × 9.80665 = 4.4482216152605 | exact |
| slug → kg | lbf·s²/ft = 4.4482216152605 / 0.3048 = 14.593902937206 | derived |
| slug·ft² → kg·m² | 14.593902937206 × 0.3048² = 1.3558179483314 | derived |
| °R → K | × 5/9 | exact |
| kt → m/s | 1852/3600 | exact |

- NESC reference data are in English units (NASA/TM-2015-218675 Vol II p.92). They are converted at load and compared in the TM's own units, so that no second conversion error enters a comparison.

## 2. Frames
| Symbol | Frame | Origin | Axes |
|---|---|---|---|
| I | Earth-centred inertial (ECI) | Earth centre | z = spin axis. For NESC atmospheric cases, ECI and ECEF coincide at t = 0 (TM Vol II p.603) |
| E | Earth-centred Earth-fixed (ECEF) | Earth centre | z = spin axis, x through lat 0 / lon 0 |
| N | local North-East-Down | point on the reference surface | x north, y east, z down along the **geodetic** normal (TM Vol II p.601) |
| R | BFRP (body-fixed reference point) | chosen geometry datum | **parallel to body axes** |
| B | body | **instantaneous CG** | x forward, y right, z down |
| S | stability | CG | B rotated by α about y |
| W | wind | CG | x along the air-relative velocity |
| Ck | component k | its mount point | component-specific |

- A position in BFRP coordinates becomes a body lever arm by one subtraction: `r_b = r_R − r_cg,R`.
- Station data (x aft, z up) are converted **once**, at import: `r_R = diag(-1,1,-1)(r_S − r_S,BFRP)` and `I_R = T I_S Tᵀ` with `T = diag(-1,1,-1)`. Under this transform Ixz keeps its sign, and Ixy and Iyz flip.

## 3. Rotations
- **DCM naming:** `C_ba` maps components from frame a to frame b: `v_b = C_ba v_a`, and `C_ab = C_baᵀ`.
- **Euler sequence 3-2-1:** ψ yaw, θ pitch, φ roll. `C_bn = R1(φ) R2(θ) R3(ψ)` (passive rotations), which equals `angle2dcm(ψ, θ, φ, 'ZYX')`.
- **Euler extraction:** `φ = atan2(C23, C33)`, `θ = −asin(C13)`, `ψ = atan2(C12, C11)`.
  - **Gimbal convention at |θ| = 90°:** φ is set to 0 and ψ carries the combined angle, `ψ = atan2(−C21, C22)`.
  - Euler angles are for input, output and linearization only. They are never integrated.
- **Quaternion:**
  - Scalar-first `q = [q0 q1 q2 q3]`, representing the N→B rotation (Hamilton convention, as in the Aerospace Toolbox).
  - Kinematics: `q̇ = ½ Ω(ω) q`, with `Ω = [0 −p −q −r; p 0 r −q; q −r 0 p; r q −p 0]`.
  - Constraint stabilization: `+ k(1 − qᵀq) q`, with k = 1 s⁻¹.
  - Inputs with |q| ≠ 1 by more than 1e-12 are normalized with warning `vital:frames:quatNotUnit`.
  - A zero quaternion is an error (`vital:badInput`).

## 4. Earth, gravity, altitude
- **Two Earth models, one body-dynamics core** (see ADR-006):
  - `flat`: NED inertial, constant g0.
  - `wgs84`: rotating ECEF, J2 gravitation.
- **NESC atmospheric constants (TM Table 73, Vol II p.93).** These take precedence over the Initial_Conditions.xlsx constants, which are truncated (ADR-008).

| Constant | Value |
|---|---|
| a (equatorial radius) | 6378137.0 m |
| 1/f | 298.257223563 |
| μ | 3.986004418e14 m³/s² |
| ω_E | 7.292115e-5 rad/s |
| J2 | 0.00108262982 |
| sphere radius | 6371007.1809 m |

- **Gravitation** is mass attraction. **Gravity** is gravitation plus the centrifugal acceleration of Earth rotation.
  - The flat, non-rotating EOM uses *gravity*.
  - The rotating ECEF EOM uses *gravitation*, because the EOM produces the centrifugal term itself. Mixing the two double-counts about 0.034 m/s² at the equator.
  - NESC `localGravity_ft_s2` is gravitation magnitude, positive down, without the centrifugal term (verified against the CSV: 32.10654 ft/s² at case 1 t = 0).
- **Altitude:**
  - Position altitude is geometric height above the reference ellipsoid or sphere (TM Vol II p.604).
  - US 1976 is evaluated at **geopotential** height `H = R0 h / (R0 + h)`, with R0 = 6356766 m (US 1976, NASA-TM-X-74335).
  - An altitude outside the model's range is an **error** (`vital:env:altitudeOutOfRange`), never a silent clamp. AAMF `isa1976` clamped to [−5, 47] km without warning.
- **Latitude** is geodetic unless it is explicitly labelled geocentric.
- **Level-flight gravity (ADR-017):** a flat-earth trim that must reproduce steady level flight over the rotating Earth uses `vital.geo.levelFlightGravity`. That is the down component of gravitation + centrifugal + Coriolis (Eötvös) + path curvature. Using gravity alone leaves an error of about 0.2% of weight, which is 0.0076° of F-16 pitch at NESC case 11.

## 5. Air data
- Air-relative velocity: `v_air = v_b − C_bn w_n − v_turb`. Wind is defined in NED, Earth-fixed.
- α = atan2(w, u), β = asin(v/V), q̄ = ½ρV², M = V/a.
- Non-dimensional rates: p̂ = pb/(2V), q̂ = qc̄/(2V), r̂ = rb/(2V), unless a data source declares otherwise.
- V = 0 is an error (`vital:airdata:zeroAirspeed`). Components that must work in hover use local velocities, never α/β.
- **Vane positions** (x_v forward of the CG, z_v below it, both in body axes):
  - VITAL computes vane angles **exactly**, from the local velocity `v_air + ω × r_v` (`vital.airdata.vaneAngles`).
  - The familiar linear forms below are the first-order expansion **about α = β = 0**:
    - `α_v = α − q x_v / V`
    - `β_v = β + r x_v / V − p z_v / V`
  - Away from α = β = 0 the linear forms leave out terms of order α·q·z_v/V. This was found in M1: about 4e-5 rad at α = 3°.
- **Airspeeds:** CAS/EAS/TAS follow the Aerospace Toolbox `correctairspeed` definitions (subsonic compressible). At sea level ISA, CAS = EAS = TAS.

## 6. Loads and inertia
- Every load carries the point it is about and the axes it is expressed in. The runtime standard is **body axes, about the BFRP**.
- **Transfer:** `F_B = F`, `M_B = M_A + (r_A − r_B) × F`.
- **Sum at the CG:** `M_cg = ΣM_R − r_cg × ΣF_R`. Gravity is `m C_bn g_n`, acting at the CG with zero moment.
- d'Alembert terms (−m a, −ω × Iω) are **never** added as loads; the EOM already contains them.
- Published aero moments are transferred from their MRP. The hand-applied Stevens-style "CG correction" terms are then **not** applied as well.
- **Inertia tensor:** `J = [Ixx −Ixy −Ixz; −Ixy Iyy −Iyz; −Ixz −Iyz Izz]`, with the products defined as positive integrals (`Ixz = ∫xz dm`).
- **Rotor angular momentum:** h_rot and ḣ_rot are kept separately from J.

## 7. Control sign conventions
Etkin/Nelson: **a positive deflection produces a negative moment about its axis.**

| Control | Positive direction | Moment |
|---|---|---|
| δe | trailing edge down | nose-down (Cm_δe < 0) |
| δa | right trailing edge down | roll left (Cl_δa < 0) |
| δr | trailing edge left | nose-left (Cn_δr < 0) |
| throttle | 0 idle … 1 maximum | — |

Each source's convention is mapped to this one at import, and the mapping is unit-tested. The NESC F-16 conventions are recorded when the DAVE-ML model is imported (M2).

## 8. Aerodynamic tables
Every coefficient table **declares its axes** (body / stability / wind) and its reference point (MRP). The runtime rotates with:
- `C_bs(α)` for stability-axis data
- `C_bw(α, β)` for wind-axis data

The v2 guide's formula (§10.2A) is exact only for stability-axis data.

## 9. Trim
- **Squareness:** the number of unknowns must equal the number of residuals, and the solver refuses anything else. An over-actuated trim needs an explicit secondary objective.
- **Asymmetric aircraft:** wings-level trim frees φ (or β). With 6 residuals, the aileron and rudder alone give 5 unknowns, which is not square.
- **θ = α + γ only when φ = 0 and β = 0.** Otherwise the general γ constraint is used.
- **Flight-path angle:**
  - `γ_air = asin(−ż_air / V_air)`
  - `γ_inertial = asin(−ż / |ṗ_n|)`
  - Each rule declares which one it uses.
- **Status codes:**

| Status | Meaning |
|---|---|
| OK | residual < tolerance, unknowns inside bounds |
| INFEASIBLE | converged to a limit with residual > tolerance; includes "stall-limited" (α beyond the data's α_max, or CL beyond CLmax) |
| NOT_CONVERGED | residual > tolerance away from any limit |
| OUT_OF_DATA_ENVELOPE | a table lookup was clipped |
| ERROR | exception or non-finite value |

**Only OK can produce a margin.**

## 10. Numerical integration
- Fixed-step RK4 on a **continuous** plant.
- Discrete elements (controller, sensors, logging) are zero-order-held across RK4 stages.
- A step-size study is registered per model:
  - a smooth analytic model must show error ratio ≈ 16 per halving of dt
  - table-interpolated and contact models get a registered lower order

## 11. Errors and identifiers
- Every error raised by VITAL has an identifier `vital:<area>:<condition>`. Tests assert the **exact identifier**.
- `vital:notImplemented` is reserved for stubs. Only it makes a RED test "RED for the right reason".
- `docs/FAILURE_CATALOGUE.md` lists every failure mode, its identifier or status, and the test that proves it is detected.

## 12. Test evidence tags
| Tag | Meaning |
|---|---|
| PUB | a published value; the citation gives document and page |
| INDEP | an independent implementation (e.g. the Aerospace Toolbox) |
| ANALYTIC | closed-form in the test |
| REG | a pre-registered expectation (mutation tests); registered before the run |

## 13. Corrections to earlier documents
| ID | Earlier statement | Correction |
|---|---|---|
| E1 | Setup guide v2 §17: `α_v ≈ α + q x_v/V`, `β_v ≈ β − r x_v/V + p z_v/V` | Signs reversed under x-forward/z-down. Correct forms are in §5 (verified against exact kinematics, `verify_vital.py`) |
| E2 | Guide §15.2: asymmetric wings-level trim with +δa, δr | Not square; free φ or β (§9) |
| E3 | Guide §10.2A force transform | Exact only for stability-axis CD/CL; tables declare axes (§8) |
| E4 | Guide §14.1: ground contact at a "faster rate" | Nothing runs faster than the base step; stiffness is handled by reducing dt |
| E5 | Guide §19.4 cites 14 CFR 23.149 | Removed by Amendment 23-64. Current rules are §23.2135 + ASTM F3173; the MoC notice covers Amdt 23-65 |
| E6 | Guide §15.2: γ from airspeed | Both γ definitions are declared (§9) |
| E7 | Guide §9.2/§8 box-inertia check at 0.1% with midpoint point masses | Midpoint point masses are 1% short for 10³ cells. Sub-cell self-inertia must be included |
| E8 | AAMF `isa1976` | Silent altitude clamp and no geopotential conversion; both fixed (§4) |
