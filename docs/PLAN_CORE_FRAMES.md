# Plan: object-oriented core: Axis, Vector, Point, Loads, MassProperties, Component, AircraftModel

Status: DRAFT plan by the coordinator (2026-10-26), from the user's whiteboard design. Implemented red-green like every milestone. The version will be 0.9.1-CORE. M8 stays paused and M9-A is finished. Nothing here changes an existing answer.

## 1. The idea (the user's whiteboard)
For a state x̄ and controls ū, the simulator needs **the total loads about the BFRP** (body-fixed reference point). Every contribution is built from three small, general objects:
- `axis_le = Axis([translation], [orientation], parent)`: the axis of the left engine, placed relative to another axis (the nose, the BFRP, ...).
- `force_thrust_le = Vector([T 0 0], axis_le)`: a vector expressed in that axis.
- `loads_aero = Loads(force_aero, moment_aero)`, `loads_aero.transform(axis_bfrp)`, `Loads.aggregate([loads_aero, loads_le, loads_re, ...], axis_bfrp)`.
- Later: `MassProperties(m, axis_cg, inertia)` with inertia a tensor tied to an axis, and the gravity loads from the mass properties.

Nothing in these classes knows it is an F-16, so the same code serves any aircraft.

## 2. What the whiteboard needs that it does not show yet (design decisions)
1. **Three different kinds of 3-vector.**
   - **Point** (a position): changing axis rotates AND translates.
   - **Vector** (a free vector: force, moment, velocity, rate): changing axis only rotates.
   - **Loads** (force plus moment about a point, a "wrench"): changing axis rotates, and the moment also picks up r × F.
   - Mixing these up is the classic frame bug. So `Vector([T 0 0], axis_le)` is a direction and magnitude; the point where the thrust acts is the origin of the `Loads` reference axis.
2. **A moment depends on the point it is taken about.**
   - `Loads` always records its reference axis: its origin is the moment point, and its orientation gives the components.
   - `plus` on two Loads is allowed only if both have the same reference axis. Otherwise it raises an error; it never silently transfers.
   - `aggregate` transfers each load explicitly.
3. **One rotation convention, stated once and enforced.** VITAL's convention (CONVENTIONS 3) is the passive DCM: `C_child_parent` maps parent components to child components. Orientation input is unambiguous:
   - a 3x3 DCM (checked orthonormal, det +1);
   - or 3-2-1 Euler `[phi theta psi]` in radians (`'Units','deg'` allowed);
   - or a MATLAB `quaternion` / `so3`.
   - Anything else is `vital:badInput`.
   - Translation is in metres (`'Units','ft'` allowed, converted once).
4. **The station ("nose") frame is just another axis.** Station data use x aft, y right, z up. That frame is right-handed: it is body rotated 180° about y. So `axis_nose_station = Axis(r_nose, [0 pi 0], axis_bfrp)`, and the existing station-to-body rule `diag(-1,1,-1)` falls out of the class instead of being a special case. The Ixy/Iyz sign flip under that rotation must also fall out of the tensor class. That is tested.
5. **Rigid geometry versus state-dependent axes.**
   - The aircraft's own axes (nose, CG, MRC, engines, surfaces) form a fixed tree rooted at the BFRP. They are built once.
   - Axes that depend on the state are built from (x, α, β) for each evaluation and are never stored or mutated:
     - body in NED (from the attitude quaternion and position);
     - wind (α, β);
     - stability (α).
   - Expressing anything in NED takes the body pose explicitly.
   - Value classes, no hidden mutation, so the objects are safe in loops, parfor and tests.
6. **Axis identity.**
   - Every axis has a unique name inside an aircraft; the model checks this.
   - Transforms between two axes walk both chains to their common root.
   - A different root raises `vital:axis:noCommonRoot`; a cycle is impossible by construction.
7. **Inertia is not just a matrix.**
   - An inertia tensor is about a point and in an axis. The parallel-axis theorem is valid only to or from the CG.
   - So the tensor lives inside `MassProperties` (which knows m and the CG), with:
     - `expressIn(axis)`, which rotates as C J Cᵀ and shifts through the CG;
     - `about(axis)`;
     - `combine([mp1 mp2 ...])`: sums the masses, gives the composite CG, and adds the inertias by the parallel-axis theorem. This is the basis for component build-up, fuel burn and CG travel.
   - It keeps VITAL's product-of-inertia sign convention (CONVENTIONS 6).
8. **"Inertial loads": an important correction to the whiteboard.**
   - The load that comes from mass properties is the **weight**, m·g at the CG; that is `mp.weightLoads(C_bn, g)`.
   - The d'Alembert terms (−m·a, −ω×Iω) must **not** be aggregated into `loads_total`: the equations of motion already contain them, so adding them would count them twice (CONVENTIONS 6).
   - A separate `mp.dAlembertLoads(a, ω, ω̇)` may exist for static-balance checks only. It is never summed in the plant, and a test guards that.
9. **Components and controls.**
   - A component (aero database, engine, propeller, motor, landing gear later) implements one interface: `loads = component.loads(flight)`, returning `Loads` in its own axis.
   - `flight` is computed ONCE per evaluation (state, controls by name, air data, atmosphere) and shared by all components.
   - Controls are named (de, da, dr, throttle_le, throttle_re, ...). Each component reads its own channels, which makes multi-engine and engine-out natural: a failed engine is `enabled = false` or zero thrust, with no special code.
10. **Performance.**
    - The plant is called about 10^5–10^6 times per uncertainty run.
    - MATLAB object method calls cost microseconds, so the static frame chains are **compiled once** (`model.compile()`) into numeric DCMs and offsets; the per-call path is short.
    - The object path is the definition and the reference. A numeric fast path is allowed only if a test shows it equal to the object path.
    - Measured and reported: target ≤ 1.25 × today's plant time per call.
11. **Batches.** Vectors, points and loads accept 3xN data (time histories), with the same axis for all columns.
12. **Readability.** Each class has a `disp` (name, axis, values with units), `plot`/`triad` to draw axes on the 3-D figure (reusing `vital.viz.displayMap`), and `toStruct`.
13. **MATLAB built-ins.** These are used as **independent checks**: they measured 6–64x slower and some use the active (point) convention, so they are not used in the hot path.
    - `quaternion` (rotateframe), `so3`/`se3`, `rigidtform3d`, `transformTree` (UAV Toolbox: a named frame tree);
    - `angle2dcm`, `dcmbody2wind`, `dcm2alphabeta`.
    - Conversions are offered at the boundary: `axis.toSe3()`, `axis.toQuaternion()`, `Axis(..., quaternionObject)`.

## 3. Classes (value classes, package `vital`)
| Class | Holds | Main methods |
|---|---|---|
| `vital.Axis` | name, origin (3x1, m, in the parent), C (parent→this), parent (Axis or empty) | `Axis(t, orient, parent, Name=)`, `Axis.root(name)`, `dcmTo(b)`, `originIn(b)`, `poseIn(b)`, `chain()`, `isSame(b)`; factories `Axis.station(...)`, `Axis.wind(alpha, beta, body)`, `Axis.stability(alpha, body)`, `Axis.bodyInNed(x, ned)` |
| `vital.Point` | r (3xN), axis | `expressIn(b)` (rotate + translate), `minus` gives a Vector |
| `vital.Vector` | v (3xN), axis, quantity (force / moment / velocity / rate / generic) | `expressIn(b)` (rotate only), `plus`/`minus` (same axis and quantity only), `cross`, `dot`, `norm` |
| `vital.Loads` | force, moment (Vectors), refAxis | `Loads(F, M)`, `transform(b)` (= `vital.loads.transferLoad`), `Loads.aggregate(list, b)`, `plus` (same reference only) |
| `vital.InertiaTensor` | J (3x3, about the CG, in an axis) | `expressIn(b)` (rotation only) |
| `vital.MassProperties` | m, axis_cg, InertiaTensor | `about(b)` (parallel axis through the CG), `combine(list)`, `weightLoads(C_bn, g)`, `dAlembertLoads(...)` (checks only) |
| `vital.Component` (abstract) | name, axis, enabled, controls it reads, MassProperties (optional) | `loads(flight)` returns Loads in its own axis |
| `vital.AeroTableComponent` | wraps a compiled DAVE-ML aero model about its MRC axis | `loads(flight)` |
| `vital.PropulsorComponent` | thrust along its axis' +x, optional torque, throttle channel | `loads(flight)` |
| `vital.FlightCondition`-like evaluation context (`vital.FlightContext`) | x, u by name, air data, atmosphere, computed once | |
| `vital.AircraftModel` | axes (bfrp root, nose, cg, mrc, ...), components, mass properties, control list, limits | `loadsTotal(x, u, env, axis)`, `derivatives(x, u, env)`, `compile()`, `validate()` |

## 4. The F-16 rebuilt with it (the equivalence proof)
```
axis_bfrp  = Axis.root('bfrp');                       % = the NESC MRC (35 % MAC), as today
axis_mrc   = Axis([0 0 0], eye(3), axis_bfrp, Name='mrc');
axis_cg    = Axis(r_cg, eye(3), axis_bfrp, Name='cg');   % from F16_inertia.dml (DXCG...)
axis_eng   = Axis([0 0 0], eye(3), axis_bfrp, Name='engine');
aero       = AeroTableComponent('aero', axis_mrc, @vital.models.f16.aero, ...)
engine     = PropulsorComponent('engine', axis_eng, @vital.models.f16.prop, 'throttle')
mp         = MassProperties(m, axis_cg, InertiaTensor(J, axis_cg))
f16        = AircraftModel(axes, {aero, engine}, mp, controls {de da dr throttle})
```
**Gate:** `f16.derivatives(x, u, env)` equals `vital.plant.derivatives(x, u, AC, env)` within 1e-12 relative over at least 1,000 seeded states and controls (including out-of-envelope points and every AeroScale multiplier), and the trim of the README condition is unchanged.

**Hypothetical twin** (the user's engine-out example, now with real components): two PropulsorComponents at y = ±d. Right engine out gives dN = +d·T/2, nose right. This uses the same numbers as `run_force_moment_audit`, now computed by the model itself.

## 5. Tests (written FIRST; tests/M9/core, tags {'M9','CORE'})
- **Axis:**
  - constructor validation (non-orthonormal or left-handed DCM, bad Euler, NaN: `vital:badInput`);
  - DCM / Euler / quaternion input agree;
  - chains of depth 1–5 resolve correctly in both directions; A→B→A is the identity;
  - no common root gives an error; duplicate names in a model give an error;
  - the station frame equals diag(-1,1,-1);
  - wind and stability axes equal `dcmbody2wind` / the analytic C_sb;
  - bodyInNed equals `angle2dcm`;
  - INDEP: composition against `se3` and against `transformTree` on a random tree.
- **Point / Vector:**
  - a Point translates and a Vector does not;
  - length is invariant;
  - mixed-axis or mixed-quantity `plus` raises an error;
  - 3xN batches.
- **Loads:**
  - `transform` equals `vital.loads.transferLoad`;
  - `aggregate` equals `vital.loads.sumLoadsAtCG` without gravity;
  - **power invariance:** F·v_P + M_P·ω is the same about every point (an independent physical check);
  - a pure couple is invariant;
  - mismatched-reference `plus` raises an error.
- **MassProperties:**
  - parallel axis through the CG only;
  - `combine` reproduces the M1 1,000-sub-box test exactly;
  - the F-16 values match NASA;
  - the Ixy/Iyz sign flip under the station rotation;
  - `weightLoads` equals today's gravity term;
  - `dAlembertLoads` is never part of `loadsTotal` (guard test).
- **AircraftModel:**
  - the F-16 equivalence gate above;
  - the README trim is unchanged;
  - the force audit's checks hold through the model;
  - twin engine-out dN = +d·T/2;
  - a model with an unknown control channel, or an axis outside the tree, raises an error.
- **Performance:** per-call time of `f16.derivatives` (compiled) against `vital.plant.derivatives` in the same run. The target is ≤ 1.25×, reported in the gate.
- **Sabotages** (must be detected):
  - passive/active convention swapped in `Axis`;
  - Point transform dropping the translation;
  - Vector transform adding a translation;
  - the r×F sign flipped in `Loads.transform`;
  - parallel axis applied about a non-CG point;
  - d'Alembert loads added to the total;
  - a component reading the wrong control channel;
  - `compile()` caching a stale chain.

## 6. Order and what stays the same
1. Write this plan, the tests and the stubs, then the RED run.
2. Implement: Axis/Point/Vector, then Loads, then MassProperties, then Component/AircraftModel with the F-16.
3. Full GREEN gate M0–M9, sabotages, fragments (ADR-040; FC-1015 onward), guide chapter.
4. **Not in this increment** (the next ones, after the user approves):
   - switching trim, linearize, sim, fq and uq to take an `AircraftModel` directly (today they take the AC struct, which the model's `compile()` can produce, so nothing breaks);
   - fuel and CG travel through `MassProperties.combine` over time;
   - landing gear;
   - the X-57 as a second aircraft.
